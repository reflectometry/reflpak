/*
# freeWrap is Copyright (c) 1998-2001 by Dennis R. LaBelle (labelled@nycap.rr.com) 
# All Rights Reserved.
#
# This software is provided 'as-is', without any express or implied warranty. In no
# event will the authors be held #liable for any damages arising from the use of 
# this software. 
#
# Permission is granted to anyone to use this software for any purpose, including
# commercial applications, and to #alter it and redistribute it freely, subject to
# the following restrictions: 
#
# 1. The origin of this software must not be misrepresented; you must not claim 
#    that you wrote the original software. If you use this software in a product, an 
#    acknowledgment in the product documentation would be appreciated but is not
#    required. 
#
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software. 
#
# 3. This notice may not be removed or altered from any source distribution.
*/

#include <sys/types.h>
#include <stdlib.h>
#include <string.h>

#if defined(__WIN32)
#	include <windows.h>
#	include <objbase.h>
#	include <shlobj.h>
#	include <stdio.h>
#	include <sys/utime.h>
#else
#	include <utime.h>
#	include <errno.h>
#endif

#include <tcl.h>

#define KEYSIZE 9
#define KEYLEN (KEYSIZE - 1)
char ENCKEY[KEYSIZE]="alfjd304";

int FreewrapEncryptCmd(
ClientData clientData,
Tcl_Interp*interp,
int objc,
Tcl_Obj *CONST objv[]
) {
  char *zData;
  unsigned char *zNew;
  int nData;
  Tcl_Obj *valuePtr;
  int pos;
  int encPos;

  if( objc!=2 ){
    Tcl_WrongNumArgs(interp, 1, objv, "string_to_encrypt");
    return TCL_ERROR;
  }
  zData = Tcl_GetByteArrayFromObj(objv[1], &nData);
  zNew = Tcl_Alloc( nData );
  if (zNew) {
      memcpy(zNew, zData, nData);

	/* Encrypt the data */
	for (pos = 0; pos < nData; ++pos)
	    {
		encPos = pos % KEYLEN;
		zNew[pos] ^= ENCKEY[encPos];
	    }

      /* return an encrypted version of the original string */
      valuePtr = Tcl_NewByteArrayObj(zNew, nData);
      Tcl_Free(zNew);
	Tcl_SetObjResult(interp, valuePtr);
     }
  return TCL_OK;
}

int FreewrapDecryptCmd(
ClientData clientData,
Tcl_Interp*interp,
int objc,
Tcl_Obj *CONST objv[]
) {
  char *zData;
  unsigned char *zNew;
  int nData;
  Tcl_Obj *valuePtr;
  int pos;
  int encPos;

  if( objc!=2 ){
    Tcl_WrongNumArgs(interp, 1, objv, "string_to_encrypt");
    return TCL_ERROR;
  }
  zData = Tcl_GetByteArrayFromObj(objv[1], &nData);
  zNew = Tcl_Alloc( nData );
  if (zNew) {
      memcpy(zNew, zData, nData);

	/* Encrypt the data */
	for (pos = 0; pos < nData; ++pos)
	    {
		encPos = pos % KEYLEN;
		zNew[pos] ^= ENCKEY[encPos];
	    }

      /* return an encrypted version of the original string */
      valuePtr = Tcl_NewByteArrayObj(zNew, nData);
      Tcl_Free(zNew);
	Tcl_SetObjResult(interp, valuePtr);
     }
  return TCL_OK;
}

#if defined(__WIN32__)
/* Create Windows specific commands */

void CreateLink(LPCSTR lpszPathLink,
				LPCSTR lpszPathObj, 
				LPCSTR lpszDesc, 
				LPCSTR lpszWorkDir,
				LPCSTR lpszIconPath,
				int    IconIdx,
				LPCSTR lpszArgs)
{ /*	The CreateLink() function accepts three parameters. The first parameter is a pointer
	to a string defining where the link links to. The second parameter is a pointer to a
	string defining the description of the link. The third parameter is a pointer to a 
	string defining where the link will be placed, and what the name of the link is. All
	links should have the .lnk extension. 

	CoInitialize() must be called in order to initialize the Component Object Model (COM)
	library. It must be called before any COM functions are called. Similarly, 
	CoUninitialize() must be called in order to uninitialize the COM library. Each call 
	to CoInitialize() must be paired up with a call to CoUninitialize(). 

	Notes: Also link: ole32.lib 

 */
    HRESULT hres;
    IShellLink* psl;

    hres = CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, &IID_IShellLink, &psl);
    if (SUCCEEDED(hres))
    {
        IPersistFile* ppf;
        psl->lpVtbl->SetPath(psl, lpszPathObj);
        psl->lpVtbl->SetDescription(psl, lpszDesc);
		psl->lpVtbl->SetWorkingDirectory(psl, lpszWorkDir);
		psl->lpVtbl->SetIconLocation(psl, lpszIconPath, IconIdx);
		psl->lpVtbl->SetArguments(psl, lpszArgs);
        hres = psl->lpVtbl->QueryInterface(psl, &IID_IPersistFile,&ppf);
        if (SUCCEEDED(hres))
        {
            WORD wsz[MAX_PATH];
            MultiByteToWideChar(CP_ACP, 0, lpszPathLink, -1,wsz, MAX_PATH);
            hres = ppf->lpVtbl->Save(ppf, wsz, TRUE);
            ppf->lpVtbl->Release(ppf);
        }
        psl->lpVtbl->Release(psl);
    }
    return;
}

int FreewrapShortcutCmd(
ClientData clientData,
Tcl_Interp*interp,
int objc,
Tcl_Obj *CONST objv[]
) {
    /* Create Windows shortcut (shell link) */
    char objpath[200];
    char linkpath[200];
    char arglist[200];
    char desc[200];
    char workDir[200];
    char icon[200];
    long iconIdx;

    int i, index;
    Tcl_Obj *resultPtr;

    static char *switches[] = {"-objectPath", "-description", "-workingDirectory", "-icon", 
"-arguments", (char *) NULL};

    resultPtr = Tcl_GetObjResult(interp);
    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "linkPath ?options?");
	return TCL_ERROR;
    }

	/*  Initialize strings */
	objpath[0] = 0;
	linkpath[0] = 0;
	arglist[0] = 0;
	desc[0] = 0;
	workDir[0] = 0;
	icon[0] = 0;

    /* Get link path */
    strcpy(linkpath, Tcl_GetString(objv[1]));

    /* Parse arguments to retrieve information about the shortcut */
    for (i = 2; i < objc; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], switches, "option", 0, &index) != TCL_OK) {
	    return TCL_ERROR;
	   }
	switch (index) {
	    case 0:			/* -objectPath */
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,
					"\"-objectPath\" option must be followed by a file path",
					-1);
				return TCL_ERROR;
			}
			strcpy(objpath, Tcl_GetString(objv[i+1]));
			i++;
			break;
	    case 1:			/* -description */
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,"\"-description\" option must be followed by a descriptive string",
					-1);
				return TCL_ERROR;
			}
			strcpy(desc, Tcl_GetString(objv[i+1]));
			i++;
			break;
	    case 2:			/* -workingDirectory */
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,
					"\"-workingDirectory\" option must be followed by a directory path",
					-1);
				return TCL_ERROR;
			}
			strcpy(workDir, Tcl_GetString(objv[i+1]));
			i++;
			break;
	    case 3:			/* -icon */
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,
					"\"-icon\" option must be followed by an icon file path",
					-1);
				return TCL_ERROR;
			}
			strcpy(icon, Tcl_GetString(objv[i+1]));
			i++;
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,
					"Icon path must be followed by a numerical icon index (starting at 0)",
					-1);
				return TCL_ERROR;
			}
			if (Tcl_GetLongFromObj(interp, objv[i+1], &iconIdx) != TCL_OK) {
				return TCL_ERROR;
			}
			i++;
			break;
	    case 4:			/* -arguments */
			if (i == (objc-1)) {
				Tcl_AppendToObj(resultPtr,
					"\"-arguments\" option must be followed by an argument string",
					-1);
				return TCL_ERROR;
			}
			strcpy(arglist, Tcl_GetString(objv[i+1]));
			i++;
			break;
		break;
	}
    }

  CoInitialize(NULL);
  CreateLink((LPCSTR) &linkpath,
			 (LPCSTR) &objpath, 
			 (LPCSTR) &desc, 
			 (LPCSTR) &workDir,
			 (LPCSTR) &icon,
			 iconIdx,
			 (LPCSTR) &arglist);
  CoUninitialize();

  Tcl_SetObjResult(interp, resultPtr);
  return TCL_OK;
}


int FreewrapGetSpecialDirCmd(
ClientData clientData,
Tcl_Interp*interp,
int objc,
Tcl_Obj *CONST objv[]
) {
	/* Retrieve a special Windows directory path */
	int index;
	int nFolder;
    Tcl_Obj *resultPtr;
	char dirPath[MAX_PATH + 1];
    LPITEMIDLIST pidl;	/* Allocate a pointer to an Item ID list */
    LPMALLOC pMalloc;	/* Allocate a pointer to an IMalloc interface */

    static char *dirTypes[] = {
		"DESKTOP",
		"INTERNET",
		"PROGRAMS",
		"CONTROLS",
		"PRINTERS",
		"PERSONAL",
		"FAVORITES",
		"STARTUP",
		"RECENT",
		"SENDTO",
		"BITBUCKET",
		"STARTMENU",
		"DESKTOPDIRECTORY",
		"DRIVES",
		"NETWORK",
		"NETHOOD",
		"FONTS",
		"TEMPLATES",
		"COMMON_STARTMENU",
		"COMMON_PROGRAMS",
		"COMMON_STARTUP",
		"COMMON_DESKTOPDIRECTORY",
		"APPDATA",
		"PRINTHOOD",
		"ALTSTARTUP",
		"COMMON_ALTSTARTUP",
		"COMMON_FAVORITES",
		"INTERNET_CACHE",
		"COOKIES",
		"HISTORY",
		(char *) NULL};


    resultPtr = Tcl_GetObjResult(interp);
    if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "dirType");
		return TCL_ERROR;
    }

	if (Tcl_GetIndexFromObj(interp, objv[1], dirTypes, "option", 0, &index) != TCL_OK) {
	    return TCL_ERROR;
	   }
	switch (index) {
			case 0:
				 nFolder = CSIDL_DESKTOP;
				 break;
			case 1:
				 nFolder = CSIDL_INTERNET;
				 break;
			case 2:
				 nFolder = CSIDL_PROGRAMS;
				 break;
			case 3:
				 nFolder = CSIDL_CONTROLS;
				 break;
			case 4:
				 nFolder = CSIDL_PRINTERS;
				 break;
			case 5:
				 nFolder = CSIDL_PERSONAL;
				 break;
			case 6:
				 nFolder = CSIDL_FAVORITES;
				 break;
			case 7:
				 nFolder = CSIDL_STARTUP;
				 break;
			case 8:
				 nFolder = CSIDL_RECENT;
				 break;
			case 9:
				 nFolder = CSIDL_SENDTO;
				 break;
			case 10:
				 nFolder = CSIDL_BITBUCKET;
				 break;
			case 11:
				 nFolder = CSIDL_STARTMENU;
				 break;
			case 12:
				 nFolder = CSIDL_DESKTOPDIRECTORY;
				 break;
			case 13:
				 nFolder = CSIDL_DRIVES;
				 break;
			case 14:
				 nFolder = CSIDL_NETWORK;
				 break;
			case 15:
				 nFolder = CSIDL_NETHOOD;
				 break;
			case 16:
				 nFolder = CSIDL_FONTS;
				 break;
			case 17:
				 nFolder = CSIDL_TEMPLATES;
				 break;
			case 18:
				 nFolder = CSIDL_COMMON_STARTMENU;
				 break;
			case 19:
				 nFolder = CSIDL_COMMON_PROGRAMS;
				 break;
			case 20:
				 nFolder = CSIDL_COMMON_STARTUP;
				 break;
			case 21:
				 nFolder = CSIDL_COMMON_DESKTOPDIRECTORY;
				 break;
			case 22:
				 nFolder = CSIDL_APPDATA;
				 break;
			case 23:
				 nFolder = CSIDL_PRINTHOOD;
				 break;
			case 24:
				 nFolder = CSIDL_ALTSTARTUP;
				 break;
			case 25:
				 nFolder = CSIDL_COMMON_ALTSTARTUP;
				 break;
			case 26:
				 nFolder = CSIDL_COMMON_FAVORITES;
				 break;
			case 27:
				 nFolder = CSIDL_INTERNET_CACHE;
				 break;
			case 28:
				 nFolder = CSIDL_COOKIES;
				 break;
			case 29:
				 nFolder = CSIDL_HISTORY;
				 break;
		}

    // Get a pointer to an item ID list that
    // represents the path of a special folder
    SHGetSpecialFolderLocation(NULL, nFolder, &pidl);

    // Convert the item ID list's binary
    // representation into a file system path
    SHGetPathFromIDList(pidl, dirPath);

    // Get the address of our task allocator's IMalloc interface
    SHGetMalloc(&pMalloc);

    // Free the item ID list allocated by SHGetSpecialFolderLocation
    pMalloc->lpVtbl->Free(pMalloc,pidl);

    // Free our task allocator
    pMalloc->lpVtbl->Release(pMalloc);

    /* Flip path separators */
    for (index = 0; dirPath[index] != 0; ++index) {
	  if (dirPath[index] == '\\')
		  dirPath[index] = '/';
      }

    /* Return results */
    Tcl_AppendToObj(resultPtr, dirPath, -1);
    Tcl_SetObjResult(interp, resultPtr);
    return TCL_OK;
}

/* End of Windows specific commands */
#endif

/*
** Initialize the freeWrap namespace
*/
int Freewrap_Init(Tcl_Interp *interp){
    Tcl_CreateObjCommand(interp, "freewrap::encrypt", FreewrapEncryptCmd, 0, 0);
    Tcl_CreateObjCommand(interp, "freewrap::decrypt", FreewrapDecryptCmd, 0, 0);
#if defined(__WIN32)
    Tcl_CreateObjCommand(interp, "freewrap::shortcut", FreewrapShortcutCmd, 0, 0);
    Tcl_CreateObjCommand(interp, "freewrap::getSpecialDir", FreewrapGetSpecialDirCmd, 0, 0);
#endif
    return TCL_OK;
}

