/*
** Copyright (c) 2000 D. Richard Hipp
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public
** License as published by the Free Software Foundation; either
** version 2 of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
** General Public License for more details.
** 
** You should have received a copy of the GNU General Public
** License along with this library; if not, write to the
** Free Software Foundation, Inc., 59 Temple Place - Suite 330,
** Boston, MA  02111-1307, USA.
**
** Author contact information:
**   drh@hwaci.com
**   http://www.hwaci.com/drh/
**
*************************************************************************
** A ZIP archive virtual filesystem for Tcl.
**
** This package of routines enables Tcl to use a Zip file as
** a virtual file system.  Each of the content files of the Zip
** archive appears as a real file to Tcl.
**
** Well, almost...  Actually, the virtual file system is limited
** in a number of ways.  The only things you can do are "stat"
** and "read" file content files.  You cannot "seek", nor "cd" and
** the "glob" command doesn't work.  But it turns out that "stat"
** and "read" are sufficient for most purposes.
**
** @(#) $Id$
*/
#include "tcl.h"
#include <ctype.h>
#include <zlib.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>

/*
** Size of the decompression input buffer
*/
#define COMPR_BUF_SIZE   8192

#ifdef __WIN32__
int getgid() {return 0;}
int getuid() {return 0;}

/*     S_IFMT     0170000   bitmask for the file type bitfields
       S_IFDIR    0040000   directory
       S_IFCHR    0020000   character device
       S_IFREG    0100000   regular file
*/
#define S_IFSOCK   0140000
#define S_IFLNK    0120000
#define S_IFBLK    0060000
#define S_IFIFO    0010000
#define S_ISUID    0004000
#define S_ISGID    0002000
#define S_ISVTX    0001000
#define S_IRWXU    00700
#define S_IRUSR    00400
#define S_IWUSR    00200
#define S_IXUSR    00100
#define S_IRWXG    00070
#define S_IRGRP    00040
#define S_IWGRP    00020
#define S_IXGRP    00010
#define S_IRWXO    00007
#define S_IROTH    00004
#define S_IWOTH    00002
#define S_IXOTH    00001
#endif

/*
** All static variables are collected into a structure named "local".
** That way, it is clear in the code when we are using a static
** variable because its name begins with "local.".
*/
static struct {
  Tcl_HashTable fileHash;     /* One entry for each file in the ZVFS.  The
                              ** The key is the virtual filename.  The data
                              ** an an instance of the ZvfsFile structure. */
  Tcl_HashTable archiveHash;  /* One entry for each archive.  Key is the name. 
                              ** data is the ZvfsArchive structure */
  int isInit;                 /* True after initialization */
} local;

/*
** Each ZIP archive file that is mounted is recorded as an instance
** of this structure
*/
typedef struct ZvfsArchive {
  char *zName;              /* Name of the archive */
  char *zMountPoint;        /* Where this archive is mounted */
  struct ZvfsFile *pFiles;  /* List of files in that archive */
} ZvfsArchive;

/*
** Particulars about each virtual file are recorded in an instance
** of the following structure.
*/
typedef struct ZvfsFile {
  char *zName;              /* The full pathname of the virtual file */
  ZvfsArchive *pArchive;    /* The ZIP archive holding this file data */
  int iOffset;              /* Offset into the ZIP archive of the data */
  int nByte;                /* Uncompressed size of the virtual file */
  int nByteCompr;           /* Compressed size of the virtual file */
  time_t atime, cmtime;     /* Our value of st_[acm]time */
  struct ZvfsFile *pNext;      /* Next file in the same archive */
  struct ZvfsFile *pNextName;  /* A doubly-linked list of files with the same */
  struct ZvfsFile *pPrevName;  /*  name.  Only the first is in local.fileHash */
} ZvfsFile;


/*
** Macros to read 16-bit and 32-bit big-endian integers into the
** native format of this local processor.  B is an array of
** characters and the integer begins at the N-th character of
** the array.
*/
#define INT16(B, N) (B[N] + (B[N+1]<<8))
#define INT32(B, N) (INT16(B,N) + (B[N+2]<<16) + (B[N+3]<<24))


/*
** Concatenate zTail onto zRoot to form a pathname.  zRoot should be
** an absolute path name.  zTail is always treated as a relative
** pathname.  If zTail begins with a slash or a drive letter, they
** are stripped off before zTail is added to the end of zRoot.
**
** After concatenation, simplify the pathname 
** by removing unnecessary ".." and "." directories.
**
** Under windows, make all characters lower case and change all backslash
** characters (\) into forward slash (/).  If zTail contains a drive
** letter, it is stripped off before zTail is appended to zRoot.
**
** A pointer to the resulting pathname is returned.  Space to hold the
** returned path is obtained form Tcl_Alloc() and should be freed by 
** the calling function.
*/
static char *CanonicalPath(const char *zRoot, const char *zTail){
  char *zPath;
  int i, j, c;

#ifdef __WIN32__
  if( isalpha(zTail[0]) && zTail[1]==':' ){ zTail += 2; }
  if( zTail[0]=='\\' ){ zTail++; }
#endif
  if( zTail[0]=='/' ){ zTail++; }
  zPath = Tcl_Alloc( strlen(zRoot) + strlen(zTail) + 2 );
  if( zPath==0 ) return 0;
  sprintf(zPath, "%s/%s", zRoot, zTail);
  for(i=j=0; (c = zPath[i])!=0; i++){
#ifdef __WIN32__
    if( isupper(c) ) {
	// c = tolower(c);
	}
    else if( c=='\\' ) c = '/';
#endif
    if( c=='/' ){
      int c2 = zPath[i+1];
      if( c2=='/' ) continue;
      if( c2=='.' ){
        int c3 = zPath[i+2];
        if( c3=='/' || c3==0 ){
          i++;
          continue;
        }
        if( c3=='.' && (zPath[i+3]=='.' || zPath[i+3]==0) ){
          i += 2;
          while( j>0 && zPath[j-1]!='/' ){ j--; }
          continue;
        }
      }
    }
    zPath[j++] = c;
  }
  if( j==0 ){ zPath[j++] = '/'; }
  zPath[j] = 0;
  return zPath;
}

/*
** Construct an absolute pathname in memory obtained from Tcl_Alloc
** that means the same file as the pathname given.
**
** Under windows, all backslash (\) charaters are converted to foward
** slash (/) and all upper case letters are converted to lower case.
** The drive letter (if present) is preserved.
*/
static char *AbsolutePath(const char *z){
  Tcl_DString pwd;
  char *zResult;
  Tcl_DStringInit(&pwd);
  if( *z!='/'
#ifdef __WIN32__
    && *z!='\\' && (!isalpha(*z) || z[1]!=':')
#endif
  ){
    /* Case 1:  "z" is a relative path.  So prepend the current working
    ** directory in order to generate an absolute path.  Note that the
    ** CanonicalPath() function takes care of converting upper to lower
    ** case and (\) to (/) under windows.
    */
    Tcl_GetCwd(0, &pwd);
    zResult = CanonicalPath( Tcl_DStringValue(&pwd), z);
    Tcl_DStringFree(&pwd);
  } else {
    /* Case 2:  "z" is an absolute path already.  We just need to make
    ** a copy of it.  Under windows, we need to convert upper to lower
    ** case and (\) into (/) on the copy.
    */
    zResult = Tcl_Alloc( strlen(z) + 1 );
    if( zResult==0 ) return 0;
    strcpy(zResult, z);
#ifdef __WIN32__
    {
      int i, c;
      for(i=0; (c=zResult[i])!=0; i++){
        if( isupper(c) ) {
		// zResult[i] = tolower(c);
	    }
        else if( c=='\\' ) zResult[i] = '/';
      }
    }
#endif
  }
  return zResult;
}

/*
** Read a ZIP archive and make entries in the virutal file hash table for all
** content files of that ZIP archive.  Also initialize the ZVFS if this
** routine has not been previously called.
*/
int Zvfs_Mount(
  Tcl_Interp *interp,    /* Leave error messages in this interpreter */
  char *zArchive,        /* The ZIP archive file */
  char *zMountPoint      /* Mount contents at this directory */
){
  Tcl_Channel chan;          /* Used for reading the ZIP archive file */
  char *zArchiveName = 0;    /* A copy of zArchive */
  int nFile;                 /* Number of files in the archive */
  int iPos;                  /* Current position in the archive file */
  ZvfsArchive *pArchive;     /* The ZIP archive being mounted */
  Tcl_HashEntry *pEntry;     /* Hash table entry */
  int isNew;                 /* Flag to tell use when a hash entry is new */
  unsigned char zBuf[100];   /* Space into which to read from the ZIP archive */
  struct tm tm;              /* Vars necessary for DOS->UNIX time conversion */
  unsigned dostime;

  if( !local.isInit ) return TCL_ERROR;
  chan = Tcl_OpenFileChannel(interp, zArchive, "r", 0);
  if (!chan) {
    return TCL_ERROR;
  }
  if (Tcl_SetChannelOption(interp, chan, "-translation", "binary") != TCL_OK){
    return TCL_ERROR;
  }
  if (Tcl_SetChannelOption(interp, chan, "-encoding", "binary") != TCL_OK) {
    return TCL_ERROR;
  }

  /* Read the "End Of Central Directory" record from the end of the
  ** ZIP archive.
  */
  iPos = Tcl_Seek(chan, -22, SEEK_END);
  Tcl_Read(chan, zBuf, 22);
  if (memcmp(zBuf, "\120\113\05\06", 4)) {
    Tcl_AppendResult(interp, "not a ZIP archive", NULL);
    return TCL_ERROR;
  }

  /* Construct the archive record
  */
  zArchiveName = AbsolutePath(zArchive);
  pEntry = Tcl_CreateHashEntry(&local.archiveHash, zArchiveName, &isNew);
  if( !isNew ){
    pArchive = (ZvfsArchive *)Tcl_GetHashValue(pEntry);
    Tcl_AppendResult(interp, "already mounted at ", pArchive->zMountPoint, 0);
    Tcl_Free(zArchiveName);
    Tcl_Close(interp, chan);
    return TCL_ERROR;
  }
  pArchive = (ZvfsArchive*)Tcl_Alloc(sizeof(*pArchive) + strlen(zMountPoint)+1);
  pArchive->zName = zArchiveName;
  pArchive->zMountPoint = (char*)&pArchive[1];
  strcpy(pArchive->zMountPoint, zMountPoint);
  pArchive->pFiles = 0;
  Tcl_SetHashValue(pEntry, pArchive);

  /* Compute the starting location of the directory for the ZIP archive
  ** in iPos then seek to that location.
  */
  nFile = INT16(zBuf,8);
  iPos -= INT32(zBuf,12);
  Tcl_Seek(chan, iPos, SEEK_SET);

  while( nFile-- > 0 ){
    int lenName;            /* Length of the next filename */
    int lenExtra;           /* Length of "extra" data for next file */
    int iData;              /* Offset to start of file data */
    ZvfsFile *pZvfs;        /* A new virtual file */
    char *zFullPath;        /* Full pathname of the virtual file */
    char zName[1024];       /* Space to hold the filename */

    /* Read the next directory entry.  Extract the size of the filename,
    ** the size of the "extra" information, and the offset into the archive
    ** file of the file data.
    */
    Tcl_Read(chan, zBuf, 46);
    if (memcmp(zBuf, "\120\113\01\02", 4)) {
      Tcl_AppendResult(interp, "ill-formed central directory entry", NULL);
      return TCL_ERROR;
    }
    lenName = INT16(zBuf,28);
    lenExtra = INT16(zBuf,30) + INT16(zBuf,32);
    iData = INT32(zBuf,42);

    /* If the virtual filename is too big to fit in zName[], then skip 
    ** this file
    */
    if( lenName >= sizeof(zName) ){
      Tcl_Seek(chan, lenName + lenExtra, SEEK_CUR);
      continue;
    }

    /* Construct an entry in local.fileHash for this virtual file.
    */
    Tcl_Read(chan, zName, lenName);
    zName[lenName] = 0;
    zFullPath = CanonicalPath(zMountPoint, zName);
    pZvfs = (ZvfsFile*)Tcl_Alloc( sizeof(*pZvfs) );
    pZvfs->zName = zFullPath;
    pZvfs->pArchive = pArchive;
    pZvfs->iOffset = iData;
    pZvfs->nByte = INT32(zBuf, 24);
    pZvfs->nByteCompr = INT32(zBuf, 20);
    dostime = INT32(zBuf, 12);
    tm.tm_mon = ((dostime >> 21) & 0x0f) -1;
    tm.tm_mday = ((dostime >> 16) & 0x1f);
    tm.tm_year = ((dostime >> 25) & 0x7f) + 80;
    tm.tm_hour = ((dostime >> 11) & 0x1f);
    tm.tm_min = ((dostime >> 5) & 0x3f);
    tm.tm_sec = ((dostime << 1) & 0x3e);
    tm.tm_isdst = -1;
    pZvfs->atime = pZvfs->cmtime = mktime(&tm);
    pZvfs->pNext = pArchive->pFiles;
    pArchive->pFiles = pZvfs;
    pEntry = Tcl_CreateHashEntry(&local.fileHash, zFullPath, &isNew);
    if( isNew ){
      pZvfs->pNextName = 0;
    }else{
      ZvfsFile *pOld = (ZvfsFile*)Tcl_GetHashValue(pEntry);
      pOld->pPrevName = pZvfs;
      pZvfs->pNextName = pOld;
    }
    pZvfs->pPrevName = 0;
    Tcl_SetHashValue(pEntry, (ClientData) pZvfs);

    /* Skip over the extra information so that the next read will be from
    ** the beginning of the next directory entry.
    */
    Tcl_Seek(chan, lenExtra, SEEK_CUR);
  }
  Tcl_Close(interp, chan);
  return TCL_OK;
}

/*
** Locate the ZvfsFile structure that corresponds to the file named.
** Return NULL if there is no such ZvfsFile.
*/
static ZvfsFile *ZvfsLookup(char *zFilename){
  char *zTrueName;
  Tcl_HashEntry *pEntry;
  ZvfsFile *pFile;

  if( local.isInit==0 ) return 0;
  zTrueName = AbsolutePath(zFilename);
  pEntry = Tcl_FindHashEntry(&local.fileHash, zTrueName);
  pFile = pEntry ? (ZvfsFile *)Tcl_GetHashValue(pEntry) : 0;
  Tcl_Free(zTrueName);
  return pFile;
}

/*
** Unmount all the files in the given ZIP archive.
*/
static void Zvfs_Unmount(char *zArchive){
  char *zArchiveName;
  ZvfsArchive *pArchive;
  ZvfsFile *pFile, *pNextFile;
  Tcl_HashEntry *pEntry;

  zArchiveName = AbsolutePath(zArchive);
  pEntry = Tcl_FindHashEntry(&local.archiveHash, zArchiveName);
  Tcl_Free(zArchiveName);
  if( pEntry==0 ) return;
  pArchive = (ZvfsArchive *)Tcl_GetHashValue(pEntry);
  Tcl_DeleteHashEntry(pEntry);
  Tcl_Free(pArchive->zName);
  for(pFile=pArchive->pFiles; pFile; pFile=pNextFile){
    pNextFile = pFile->pNext;
    if( pFile->pNextName ){
      pFile->pNextName->pPrevName = pFile->pPrevName;
    }
    if( pFile->pPrevName ){
      pFile->pPrevName->pNextName = pFile->pNextName;
    }else{
      pEntry = Tcl_FindHashEntry(&local.fileHash, pFile->zName);
      if( pEntry==0 ){
        /* This should never happen */
      }else if( pFile->pNextName ){
        Tcl_SetHashValue(pEntry, pFile->pNextName);
      }else{
        Tcl_DeleteHashEntry(pEntry);
      }
    }
    Tcl_Free(pFile->zName);
    Tcl_Free((char*)pFile);
  }
}

/*
** zvfs::mount  Zip-archive-name  mount-point
**
** Create a new mount point on the given ZIP archive.  After this
** command executes, files contained in the ZIP archive will appear
** to Tcl to be regular files at the mount point.
*/
static int ZvfsMountCmd(
  void *NotUsed,             /* Client data for this command */
  Tcl_Interp *interp,        /* The interpreter used to report errors */
  int argc,                  /* Number of arguments */
  char **argv                /* Values of all arguments */
){
  if( argc!=3 ){
    Tcl_AppendResult(interp, "wrong # args: should be \"", argv[0],
       " ZIP-FILE MOUNT-POINT\"", 0);
    return TCL_ERROR;
  }
  return Zvfs_Mount(interp, argv[1], argv[2]);
}

/*
** zvfs::unmount  Zip-archive-name
**
** Undo the effects of zvfs::mount.
*/
static int ZvfsUnmountCmd(
  void *NotUsed,             /* Client data for this command */
  Tcl_Interp *interp,        /* The interpreter used to report errors */
  int argc,                  /* Number of arguments */
  char **argv                /* Values of all arguments */
){
  if( argc!=2 ){
    Tcl_AppendResult(interp, "wrong # args: should be \"", argv[0],
       " ZIP-FILE\"", 0);
    return TCL_ERROR;
  }
  Zvfs_Unmount(argv[1]);
  return TCL_OK;
}

/*
** zvfs::exists  filename
**
** Return TRUE if the given filename exists in the ZVFS and FALSE if
** it does not.
*/
static int ZvfsExistsObjCmd(
  void *NotUsed,             /* Client data for this command */
  Tcl_Interp *interp,        /* The interpreter used to report errors */
  int objc,                  /* Number of arguments */
  Tcl_Obj *const* objv       /* Values of all arguments */
){
  char *zFilename;
  if( objc!=2 ){
    Tcl_WrongNumArgs(interp, 1, objv, "FILENAME");
    return TCL_ERROR;
  }
  zFilename = Tcl_GetStringFromObj(objv[1], 0);
  Tcl_SetBooleanObj( Tcl_GetObjResult(interp), ZvfsLookup(zFilename)!=0);
  return TCL_OK;
}

/*
** zvfs::info  filename
**
** Return information about the given file in the ZVFS.  The information
** consists of (1) the name of the ZIP archive that contains the file,
** (2) the size of the file after decompressions, (3) the compressed
** size of the file, and (4) the offset of the compressed data in the archive.
*/
static int ZvfsInfoObjCmd(
  void *NotUsed,             /* Client data for this command */
  Tcl_Interp *interp,        /* The interpreter used to report errors */
  int objc,                  /* Number of arguments */
  Tcl_Obj *const* objv       /* Values of all arguments */
){
  char *zFilename;
  ZvfsFile *pFile;
  if( objc!=2 ){
    Tcl_WrongNumArgs(interp, 1, objv, "FILENAME");
    return TCL_ERROR;
  }
  zFilename = Tcl_GetStringFromObj(objv[1], 0);
  pFile = ZvfsLookup(zFilename);
  if( pFile ){
    Tcl_Obj *pResult = Tcl_GetObjResult(interp);
    Tcl_ListObjAppendElement(interp, pResult, 
       Tcl_NewStringObj(pFile->pArchive->zName, -1));
    Tcl_ListObjAppendElement(interp, pResult, Tcl_NewIntObj(pFile->nByte));
    Tcl_ListObjAppendElement(interp, pResult, Tcl_NewIntObj(pFile->nByteCompr));
    Tcl_ListObjAppendElement(interp, pResult, Tcl_NewIntObj(pFile->iOffset));
  }
  return TCL_OK;
}

/*
** zvfs::list
**
** Return a list of all files in the ZVFS.  The order of the names
** in the list is arbitrary.
*/
static int ZvfsListObjCmd(
  void *NotUsed,             /* Client data for this command */
  Tcl_Interp *interp,        /* The interpreter used to report errors */
  int objc,                  /* Number of arguments */
  Tcl_Obj *const* objv       /* Values of all arguments */
){
  char *zPattern = 0;
  Tcl_RegExp pRegexp = 0;
  Tcl_HashEntry *pEntry;
  Tcl_HashSearch sSearch;
  Tcl_Obj *pResult = Tcl_GetObjResult(interp);

  if( objc>3 ){
    Tcl_WrongNumArgs(interp, 1, objv, "?(-glob|-regexp)? ?PATTERN?");
    return TCL_ERROR;
  }
  if( local.isInit==0 ) return TCL_OK;
  if( objc==3 ){
    int n;
    char *zSwitch = Tcl_GetStringFromObj(objv[1], &n);
    if( n>=2 && strncmp(zSwitch,"-glob",n)==0 ){
      zPattern = Tcl_GetString(objv[2]);
    }else if( n>=2 && strncmp(zSwitch,"-regexp",n)==0 ){
      pRegexp = Tcl_RegExpCompile(interp, Tcl_GetString(objv[2]));
      if( pRegexp==0 ) return TCL_ERROR;
    }else{
      Tcl_AppendResult(interp, "unknown option: ", zSwitch, 0);
      return TCL_ERROR;
    }
  }else if( objc==2 ){
    zPattern = Tcl_GetStringFromObj(objv[1], 0);
  }
  if( zPattern ){
    for(pEntry = Tcl_FirstHashEntry(&local.fileHash, &sSearch);
        pEntry;
        pEntry = Tcl_NextHashEntry(&sSearch)
    ){
      ZvfsFile *pFile = (ZvfsFile *)Tcl_GetHashValue(pEntry);
      char *z = pFile->zName;
      if( Tcl_StringMatch(z, zPattern) ){
        Tcl_ListObjAppendElement(interp, pResult, Tcl_NewStringObj(z, -1));
      }
    }
  }else if( pRegexp ){
    for(pEntry = Tcl_FirstHashEntry(&local.fileHash, &sSearch);
        pEntry;
        pEntry = Tcl_NextHashEntry(&sSearch)
    ){
      ZvfsFile *pFile = (ZvfsFile *)Tcl_GetHashValue(pEntry);
      char *z = pFile->zName;
      if( Tcl_RegExpExec(interp, pRegexp, z, z) ){
        Tcl_ListObjAppendElement(interp, pResult, Tcl_NewStringObj(z, -1));
      }
    }
  }else{
    for(pEntry = Tcl_FirstHashEntry(&local.fileHash, &sSearch);
        pEntry;
        pEntry = Tcl_NextHashEntry(&sSearch)
    ){
      ZvfsFile *pFile = (ZvfsFile *)Tcl_GetHashValue(pEntry);
      char *z = pFile->zName;
      Tcl_ListObjAppendElement(interp, pResult, Tcl_NewStringObj(z, -1));
    }
  }
  return TCL_OK;
}

/*
** Whenever a ZVFS file is opened, an instance of this structure is
** attached to the open channel where it will be available to the
** ZVFS I/O routines below.  All state information about an open
** ZVFS file is held in this structure.
*/
typedef struct ZvfsChannelInfo {
  unsigned int nByte;       /* number of bytes of read uncompressed data */
  unsigned int nByteCompr;  /* number of bytes of unread compressed data */
  unsigned int nData;       /* total number of bytes of compressed data */
  int readSoFar;            /* Number of bytes read so far */
  long startOfData;         /* File position of start of data in ZIP archive */
  int isCompressed;         /* True data is compressed */
  Tcl_Channel chan;         /* Open to the archive file */
  unsigned char *zBuf;      /* buffer used by the decompressor */
  z_stream stream;          /* state of the decompressor */
  ZvfsFile *zFile;          /* link back so atime can be set */
} ZvfsChannelInfo;


/*
** This routine is called as an exit handler.  If we do not set
** ZvfsChannelInfo.chan to NULL, then Tcl_Close() will be called on
** that channel twice when Tcl_Exit runs.  This will lead to a 
** core dump.
*/
static void vfsExit(void *pArg){
  ZvfsChannelInfo *pInfo = (ZvfsChannelInfo*)pArg;
  pInfo->chan = 0;
}

/*
** This routine is called when the ZVFS channel is closed
*/
static int vfsClose(
  ClientData  instanceData,    /* A ZvfsChannelInfo structure */
  Tcl_Interp *interp           /* The TCL interpreter */
){
  ZvfsChannelInfo* pInfo = (ZvfsChannelInfo*)instanceData;

  if( pInfo->zBuf ){
    Tcl_Free(pInfo->zBuf);
    inflateEnd(&pInfo->stream);
  }
  if( pInfo->chan ){
    Tcl_Close(interp, pInfo->chan);
    Tcl_DeleteExitHandler(vfsExit, (int *)pInfo);
  }
  Tcl_Free((char*)pInfo);
  return TCL_OK;
}

/*
** The TCL I/O system calls this function to actually read information
** from a ZVFS file.
*/
static int vfsInput (
  ClientData instanceData, /* The channel to read from */
  char *buf,               /* Buffer to fill */
  unsigned int toRead,     /* Requested number of bytes */
  int *pErrorCode          /* Location of error flag */
){
  ZvfsChannelInfo* pInfo = (ZvfsChannelInfo*) instanceData;

  if( toRead > pInfo->nByte ){
    toRead = pInfo->nByte;
  }
  if( toRead == 0 ){
    return 0;
  }
  if( pInfo->isCompressed ){
    int err = Z_OK;
    z_stream *stream = &pInfo->stream;
    pInfo->zFile->atime = time(NULL);
    stream->next_out = buf;
    stream->avail_out = toRead;
    while (stream->avail_out) {
      if (!stream->avail_in) {
        int len = pInfo->nByteCompr;
        if (len > COMPR_BUF_SIZE) {
          len = COMPR_BUF_SIZE;
        }
        len = Tcl_Read(pInfo->chan, pInfo->zBuf, len);
        pInfo->nByteCompr -= len;
        stream->next_in = pInfo->zBuf;
        stream->avail_in = len;
      }
      err = inflate(stream, Z_NO_FLUSH);
      if (err) break;
    }
    if (err == Z_STREAM_END) {
      if ((stream->avail_out != 0)) {
        *pErrorCode = err; /* premature end */
        return -1;
      }
    }else if( err ){
      *pErrorCode = err; /* some other zlib error */
      return -1;
    }
  }else{
    toRead = Tcl_Read(pInfo->chan, buf, toRead);
  }
  pInfo->nByte -= toRead;
  pInfo->readSoFar += toRead;
  *pErrorCode = 0;
  return toRead;
}

/*
** Write to a ZVFS file.  ZVFS files are always read-only, so this routine
** always returns an error.
*/
static int vfsOutput(
  ClientData instanceData,   /* The channel to write to */
  char *buf,                 /* Data to be stored. */
  int toWrite,               /* Number of bytes to write. */
  int *pErrorCode            /* Location of error flag. */
){
  *pErrorCode = EINVAL;
  return -1;
}

/*
** Move the file pointer so that the next byte read will be "offset".
*/
static int vfsSeek(
  ClientData instanceData,    /* The file structure */
  long offset,                /* Offset to seek to */
  int mode,                   /* One of SEEK_CUR, SEEK_SET or SEEK_END */
  int *pErrorCode             /* Write the error code here */
){
  ZvfsChannelInfo* pInfo = (ZvfsChannelInfo*) instanceData;

  switch( mode ){
    case SEEK_CUR: {
      offset += pInfo->readSoFar;
      break;
    }
    case SEEK_END: {
      offset += pInfo->readSoFar + pInfo->nByte;
      break;
    }
    default: {
      /* Do nothing */
      break;
    }
  }
  if( !pInfo->isCompressed ){
	/* dont seek behind end of data */
	if (pInfo->nData < (unsigned long)offset)
	    return -1;

	/* do the job, save and check the result */
	offset = Tcl_Seek(pInfo->chan, offset + pInfo->startOfData, SEEK_SET);
	if (offset == -1)
	    return -1;

	 /* adjust the counters (use real offset) */
	pInfo->readSoFar = offset - pInfo->startOfData;
	pInfo->nByte = pInfo->nData - pInfo->readSoFar; 
  }else{
    if( offset<pInfo->readSoFar ){
      z_stream *stream = &pInfo->stream;
      inflateEnd(stream);
      stream->zalloc = (alloc_func)0;
      stream->zfree = (free_func)0;
      stream->opaque = (voidpf)0;
      stream->avail_in = 2;
      stream->next_in = pInfo->zBuf;
      pInfo->zBuf[0] = 0x78;
      pInfo->zBuf[1] = 0x01;
      inflateInit(&pInfo->stream);
      Tcl_Seek(pInfo->chan, pInfo->startOfData, SEEK_SET);
      pInfo->nByte += pInfo->readSoFar;
      pInfo->nByteCompr = pInfo->nData;
      pInfo->readSoFar = 0;
    }
    while( pInfo->readSoFar < offset ){
      int toRead, errCode;
      char zDiscard[100];
      toRead = offset - pInfo->readSoFar;
      if( toRead>sizeof(zDiscard) ) toRead = sizeof(zDiscard);
      vfsInput(instanceData, zDiscard, toRead, &errCode);
    }
  }
  return pInfo->readSoFar;
}

/*
** Handle events on the channel.  ZVFS files do not generate events,
** so this is a no-op.
*/
static void vfsWatchChannel(
  ClientData instanceData,   /* Channel to watch */
  int mask                   /* Events of interest */
){
  return;
}

/*
** Called to retrieve the underlying file handle for this ZVFS file.
** As the ZVFS file has no underlying file handle, this is a no-op.
*/
static int vfsGetFile(
  ClientData  instanceData,   /* Channel to query */
  int direction,              /* Direction of interest */
  ClientData* handlePtr       /* Space to the handle into */
){
  return TCL_ERROR;
}

/*
** This structure describes the channel type structure for 
** access to the ZVFS.
*/
static Tcl_ChannelType vfsChannelType = {
  "vfs",		/* Type name.                                    */
  NULL,			/* Set blocking/nonblocking behaviour. NULL'able */
  vfsClose,		/* Close channel, clean instance data            */
  (Tcl_DriverInputProc *)vfsInput,		/* Handle read request                           */
  vfsOutput,		/* Handle write request                          */
  vfsSeek,		/* Move location of access point.      NULL'able */
  NULL,			/* Set options.                        NULL'able */
  NULL,			/* Get options.                        NULL'able */
  vfsWatchChannel,	/* Initialize notifier                           */
  vfsGetFile		/* Get OS handle from the channel.               */
};

/*
** This routine attempts to do an open of a file.  Check to see
** if the file is located in the ZVFS.  If so, then open a channel
** for reading the file.  If not, return NULL.
*/
static Tcl_Channel ZvfsFileOpen(
  Tcl_Interp *interp,     /* The TCL interpreter doing the open */
  char *zFilename,        /* Name of the file to open */
  char *modeString,       /* Mode string for the open (ignored) */
  int permissions         /* Permissions for a newly created file (ignored) */
){
  ZvfsFile *pFile;
  ZvfsChannelInfo *pInfo;
  Tcl_Channel chan;
  static int count = 1;
  char zName[50];
  unsigned char zBuf[50];

  pFile = ZvfsLookup(zFilename);
  if( pFile==0 ) return NULL;
  chan = Tcl_OpenFileChannel(interp, pFile->pArchive->zName, "r", 0);
  if( chan==0 ){
    return 0;
  }
  if(  Tcl_SetChannelOption(interp, chan, "-translation", "binary")
    || Tcl_SetChannelOption(interp, chan, "-encoding", "binary")
  ){
    /* this should never happen */
    Tcl_Close(0, chan);
    return 0;
  }
  Tcl_Seek(chan, pFile->iOffset, SEEK_SET);
  Tcl_Read(chan, zBuf, 30);
  if( memcmp(zBuf, "\120\113\03\04", 4) ){
    if( interp ){
      Tcl_AppendResult(interp, "local header mismatch: ", NULL);
    }
    Tcl_Close(interp, chan);
    return 0;
  }
  pInfo = (ZvfsChannelInfo*)Tcl_Alloc( sizeof(*pInfo) );
  pInfo->zFile = pFile;
  pInfo->chan = chan;
  Tcl_CreateExitHandler(vfsExit, (int *)pInfo);
  pInfo->isCompressed = INT16(zBuf, 8);
  if( pInfo->isCompressed ){
    z_stream *stream = &pInfo->stream;
    pInfo->zBuf = Tcl_Alloc(COMPR_BUF_SIZE);
    stream->zalloc = (alloc_func)0;
    stream->zfree = (free_func)0;
    stream->opaque = (voidpf)0;
    stream->avail_in = 2;
    stream->next_in = pInfo->zBuf;
    pInfo->zBuf[0] = 0x78;
    pInfo->zBuf[1] = 0x01;
    inflateInit(&pInfo->stream);
  }else{
    pInfo->zBuf = 0;
  }
  pInfo->nByte = INT32(zBuf,22);
  pInfo->nByteCompr = pInfo->nData = INT32(zBuf,18);
  pInfo->readSoFar = 0;
  Tcl_Seek(chan, INT16(zBuf,26)+INT16(zBuf,28), SEEK_CUR);
  pInfo->startOfData = Tcl_Tell(chan);
  sprintf(zName,"vfs_%x_%x",((int)pFile)>>12,count++);
  chan = Tcl_CreateChannel(&vfsChannelType, zName, 
                           (ClientData)pInfo, TCL_READABLE);
  return chan;
}

/*
** This routine does a stat() system call for a ZVFS file.
*/
static int ZvfsFileStat(char *path, struct stat *buf){
  ZvfsFile *pFile;
  char zName[51];

  memset(buf, 0, sizeof(*buf));
  pFile = ZvfsLookup(path);
  if( pFile==0 ){
    /* Maybe its a directory (Tcl's file stat command strips any trailing slashes)
    */
    strncpy(zName,path,sizeof(zName));
    zName[sizeof(zName)-2] = '\0';
    strcat(zName,"/");
    pFile = ZvfsLookup(zName);
    if( pFile==0 ){
      return -1;
    }
    buf->st_mode = S_IFDIR | S_IXUSR|S_IRUSR | S_IXGRP|S_IRGRP | S_IXOTH|S_IROTH;
  } else
    buf->st_mode = S_IFREG |         S_IRUSR |         S_IRGRP |         S_IROTH;
  buf->st_nlink = 1;
  buf->st_uid = getuid();
  buf->st_gid = getgid();
  buf->st_atime = pFile->atime;
  buf->st_ctime =
  buf->st_mtime = pFile->cmtime;
  buf->st_size = pFile->nByte;
  return 0;
}

/*
** This routine does an access() system call for a ZVFS file.
*/
static int ZvfsFileAccess(char *path, int mode){
  ZvfsFile *pFile;

  if( mode & 3 ){
    return -1;
  }
  pFile = ZvfsLookup(path);
  if( pFile==0 ){
    return -1;
  }
  return 0; 
}

/*
** This TCL procedure can be used to copy a file.  The built-in
** "file copy" command of TCL bypasses the I/O system and does not
** work with zvfs.  You have to use a procedure like the following
** instead.
*/
static char zFileCopy[] = 
"proc zvfs::filecopy {from to} {\n"
"  set f [open $from r]\n"
"  if {[catch {\n"
"    fconfigure $f -translation binary\n"
"    set t [open $to w]\n"
"  } msg]} {\n"
"    close $f\n"
"    error $t\n"
"  }\n"
"  if {[catch {\n"
"    fconfigure $t -translation binary\n"
"    fcopy $f $t\n"
"  } msg]} {\n"
"    close $f\n"
"    close $t\n"
"    error $msg\n"
"  }\n"
"  close $f\n"
"  close $t\n"
"}\n"
;

/*
** Initialize the ZVFS system.
*/
int Zvfs_Init(Tcl_Interp *interp){
#ifdef USE_TCL_STUBS
  if( Tcl_InitStubs(interp,"8.0",0)==0 ){
    return TCL_ERROR;
  }
#endif
  Tcl_PkgProvide(interp, "zvfs", "1.0");
  Tcl_CreateCommand(interp, "zvfs::mount", ZvfsMountCmd, 0, 0);
  Tcl_CreateCommand(interp, "zvfs::unmount", ZvfsUnmountCmd, 0, 0);
  Tcl_CreateObjCommand(interp, "zvfs::exists", ZvfsExistsObjCmd, 0, 0);
  Tcl_CreateObjCommand(interp, "zvfs::info", ZvfsInfoObjCmd, 0, 0);
  Tcl_CreateObjCommand(interp, "zvfs::list", ZvfsListObjCmd, 0, 0);
  Tcl_GlobalEval(interp, zFileCopy);
  if( !local.isInit ){
    /* One-time initialization of the ZVFS */
    extern void TclAccessInsertProc();
    extern void TclStatInsertProc();
    extern void TclOpenFileChannelInsertProc();
    Tcl_InitHashTable(&local.fileHash, TCL_STRING_KEYS);
    Tcl_InitHashTable(&local.archiveHash, TCL_STRING_KEYS);
    TclAccessInsertProc(ZvfsFileAccess);
    TclStatInsertProc(ZvfsFileStat);
    TclOpenFileChannelInsertProc(ZvfsFileOpen);
    local.isInit = 1;
  }
  return TCL_OK;
}
