static char _senWinLink_c[] =
"$Header$";
/*
 * Copyright (C) 1997-1999 Sensus Consulting Ltd.
 * Matt Newman <matt@sensus.org>
 *
 * Adds command winlink::link to Tcl Interp.
 *
 * TODO:
 *		Handle [GS]etIDList correctly.
 *
 * 2004-02-17 Paul Kienzle <pkienzle@nist.gov>
 * * add recent and path so we have somewhere to create shortcuts
 *   (compliments of the NSIS installer (c) 1999-2004, Nullsoft, Inc.).
 */

#include "tcl.h"
#include <stdlib.h>
#include <shlobj.h>

DLLEXPORT int	Winlink_Init _ANSI_ARGS_((Tcl_Interp *));
/*
 * Internal Routines
 */
static int	LinkCmd _ANSI_ARGS_((ClientData clientData,
		    Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]));
static Tcl_Obj*	fconvert _ANSI_ARGS_((char *filename));
static Tcl_ExitProc ExitHandler;

/*
 * Convert windows filename into Tcl format
 */
static Tcl_Obj*
fconvert(filename)
    char*	filename;
{
    char buf[_MAX_PATH], *cp = buf;
    for (cp = buf;*filename;cp++,filename++) {
	if (*filename == '\\') {
	    *cp = '/';
	} else {
	    *cp = *filename;
	}
    }
    *cp = '\0';
    return Tcl_NewStringObj( buf, -1);
}

static void
tempdir(char *path, int pathlen)
{
    int i;
    i = GetTempPath(pathlen-1,path);
    if (i) path[i]='\0';
    else {
        GetWindowsDirectory(path, pathlen-5);
        lstrcat(path,"\\Temp");
    }
}

static BOOL 
getlocation(int id, char *path)
{
    IMalloc *m;
    LPITEMIDLIST idl;
    if (!SHGetSpecialFolderLocation(0, id, &idl)) {
        BOOL res = SHGetPathFromIDList(idl, path);
        SHGetMalloc(&m);
        if (m) {
            m->lpVtbl->Free(m, idl);
            m->lpVtbl->Release(m);
        }
        return res;
    }
    return FALSE;
}

#define SYSREG "Software\\Microsoft\\Windows\\CurrentVersion"
static void
regkey(HKEY root, const char *sub, const char *name, char *str, int len)
{
    HKEY hKey;
    *str = 0;
    if (RegOpenKeyEx(root,sub,0,KEY_READ,&hKey) == ERROR_SUCCESS)
    {
        DWORD l = len;
        DWORD t;
        if (RegQueryValueEx(hKey,name,NULL,&t,str,&l) != ERROR_SUCCESS
            || (t != REG_SZ && t != REG_EXPAND_SZ)) *str = 0;
        str[len-1]=0;
        RegCloseKey(hKey);
    }
}


static IShellLink* psl = NULL;

static
void ExitHandler(ClientData data)
{
    if (psl != NULL)
	psl->lpVtbl->Release(psl);
}

struct CSIDL {
    int user;
    int common;
    char *name;
} csidl[] = {
    { 0x30, 0x2f, "admintools" },
    { 0x1d, 0x1e, "altstartup" },
    { 0x1a, 0x23, "appdata" },
    { 0x1c,   -1, "appdatalocal" },
    { 0x3b,   -1, "cdburnarea" },
    { 0x2b,   -1, "commonfiles" },
    { 0x03,   -1, "controls" },
    { 0x21,   -1, "cookies" },
    { 0x10, 0x19, "desktop" },
    { 0x05, 0x2e, "documents" },
    { 0x11,   -1, "drives" },
    { 0x06, 0x1f, "favorites" },
    { 0x14,   -1, "fonts" },
    { 0x22,   -1, "history" },
    { 0x01,   -1, "internet" },
    { 0x20,   -1, "internetcache" },
    { 0x0d, 0x35, "music" },
    { 0x13,   -1, "nethood" },
    { 0x12,   -1, "network" },
    { 0x27, 0x36, "pictures" },
    { 0x04,   -1, "printers" },
    { 0x1b,   -1, "printhood" },
    { 0x28,   -1, "profile" },
    { 0x3e,   -1, "profiles" },
    { 0x26,   -1, "programfiles" },
    { 0x02, 0x17, "programsmenu" },
    { 0x08,   -1, "recent" },
    { 0x0a,   -1, "recycle" },
    { 0x38,   -1, "resources" },
    { 0x39,   -1, "resourceslocal" },
    { 0x09,   -1, "sendto" },
    { 0x0b, 0x16, "startmenu" },
    { 0x07, 0x18, "startupmenu" },
    { 0x25,   -1, "system" },
    {   -2,   -1, "temp" },
    { 0x15, 0x2d, "templates" },
    { 0x0e, 0x37, "video" },
    { 0x00,   -1, "virtualdesktop" },
    { 0x24,   -1, "windows" },
} ;

static int
LinkCmd(data, interp, objc, objv)
    ClientData data;
    Tcl_Interp *interp;
    int		objc;
    Tcl_Obj	*CONST objv[];
{
    int		index;
    static char *options[] = {
	"get", "set", "recent", "path", NULL
    };
    enum options {
	LNK_GET, LNK_SET, LNK_RECENT, LNK_PATH
    };
    HRESULT hres;
    IPersistFile* ppf = NULL;
    WORD wpath[MAX_PATH+1];

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    }    
    if (Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0,
	&index) != TCL_OK) {
	return TCL_ERROR;
    }
    if (psl == NULL) {
	HRESULT hres;

	hres = CoInitialize(NULL);
	if ( hres != S_OK ) {
	    Tcl_SetResult(interp, "failed to initialize ShellLink subsystem", TCL_STATIC);
	    return TCL_ERROR;
	}
	hres = CoCreateInstance(&CLSID_ShellLink,
				NULL, CLSCTX_INPROC_SERVER,
				&IID_IShellLink, &psl);
	if (!SUCCEEDED(hres)) {
	    Tcl_SetResult(interp, "failed to initialize ShellLink subsystem", TCL_STATIC);
	    return TCL_ERROR;
	}
    }
    switch ((enum options) index) {
    case LNK_GET: {
	/*
	 * info path
	 */
	Tcl_Obj *listPtr;
	char	*path;
	char szBuf[MAX_PATH]; 
	WIN32_FIND_DATA wfd;
	WORD	w;
	int	i;

	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "path");
	    return TCL_ERROR;
	}
	path = Tcl_GetStringFromObj(objv[2], (int *) NULL);

	/* Get Address list for Load Routine   */
	hres = psl->lpVtbl->QueryInterface(psl,&IID_IPersistFile, &ppf);
	if (!SUCCEEDED(hres)) {
	    Tcl_SetResult(interp, "failed to obtain IPersistFile routine", TCL_STATIC);
	    return TCL_ERROR;
	}
	MultiByteToWideChar(CP_ACP, 0, path, -1, wpath, MAX_PATH);

	listPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);

	hres = ppf->lpVtbl->Load(ppf, wpath, STGM_READ);
	if (!SUCCEEDED(hres)) {
err:
	    Tcl_DecrRefCount(listPtr);
	    ppf->lpVtbl->Release(ppf);
	    Tcl_AppendResult(interp, "couldn't load shortcut \"",
			    path, "\"", (char *)NULL);
	    return TCL_ERROR;
	}

        hres = psl->lpVtbl->GetPath( psl, szBuf, MAX_PATH,
				    (WIN32_FIND_DATA *)&wfd, 0 ); 
        if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-path", -1));
	Tcl_ListObjAppendElement(interp, listPtr, fconvert(szBuf));

	hres = psl->lpVtbl->GetArguments( psl, szBuf, MAX_PATH);
        if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-args", -1));
	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( szBuf, -1));

	hres = psl->lpVtbl->GetWorkingDirectory( psl, szBuf, MAX_PATH);
        if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-cwd", -1));
	Tcl_ListObjAppendElement(interp, listPtr, fconvert(szBuf));

        hres = psl->lpVtbl->GetDescription( psl, szBuf, MAX_PATH); 
	if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-desc", -1));
	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( szBuf, -1));

        hres = psl->lpVtbl->GetIconLocation( psl, szBuf, MAX_PATH, &i); 
	if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-icon", -1));
	Tcl_ListObjAppendElement(interp, listPtr, fconvert(szBuf));

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-index", -1));
	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewIntObj( i));

        hres = psl->lpVtbl->GetShowCmd( psl, &i); 
	if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-show", -1));
	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewIntObj( i));

        hres = psl->lpVtbl->GetHotkey( psl, &w); 
	if (!SUCCEEDED(hres))
	    goto err;

	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj( "-hotkey", -1));
	Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewIntObj( w));

	ppf->lpVtbl->Release(ppf);
	Tcl_SetObjResult(interp, listPtr);
	return TCL_OK;
    }	/* LNK_GET */
    case LNK_SET: {
	/*
	 * set path ?options?
	 */
	Tcl_DString	ds;
	char	*path, *opt, *val;
	char	szBuf[MAX_PATH]; 
	int	i, w;

	if (objc < 3 || (objc % 2) != 1) {
	    Tcl_WrongNumArgs(interp, 2, objv, "path ?options?");
	    return TCL_ERROR;
	}
	Tcl_DStringInit(&ds);
	path = Tcl_TranslateFileName(interp,
				Tcl_GetStringFromObj(objv[2], (int *) NULL),
				&ds);
	if (path == NULL)
	    return TCL_ERROR;

	/* Get Address list for Load Routine   */
	hres = psl->lpVtbl->QueryInterface(psl,&IID_IPersistFile, &ppf);
	if (!SUCCEEDED(hres)) {
	    Tcl_DStringFree(&ds);
	    Tcl_SetResult(interp, "failed to obtain IPersistFile routine", TCL_STATIC);
	    return TCL_ERROR;
	}
	MultiByteToWideChar(CP_ACP, 0, path, -1, wpath, MAX_PATH);
	Tcl_DStringFree(&ds);

	hres = ppf->lpVtbl->Load(ppf, wpath, STGM_CREATE|STGM_READWRITE);
	if (!SUCCEEDED(hres)) {
	    LPITEMIDLIST pidl = 0;
		
	    val = "";
	    i = 0;
	    psl->lpVtbl->SetPath(psl,(LPSTR)val);
	    psl->lpVtbl->SetArguments(psl,(LPSTR)val);
	    psl->lpVtbl->SetWorkingDirectory(psl,(LPSTR)val);
	    psl->lpVtbl->SetDescription(psl,(LPSTR)val);
	    psl->lpVtbl->SetIconLocation(psl, val, i);
	    psl->lpVtbl->SetHotkey(psl, (WORD)i);
	    psl->lpVtbl->SetShowCmd(psl, i);
	    psl->lpVtbl->SetIDList(psl, pidl);
	    /*LPITEMIDLIST*/
	}
	for (i=3;i<objc;i+=2) {
	    opt = Tcl_GetStringFromObj(objv[i], (int *) NULL);
	    val = Tcl_GetStringFromObj(objv[i+1], (int *) NULL);
	    if (strcmp(opt, "-path")==0) {
		psl->lpVtbl->SetPath(psl,(LPSTR)val);
	    } else if (strcmp(opt, "-args")==0) {
		psl->lpVtbl->SetArguments(psl,(LPSTR)val);
	    } else if (strcmp(opt, "-cwd")==0) {
		psl->lpVtbl->SetWorkingDirectory(psl,(LPSTR)val);
	    } else if (strcmp(opt, "-desc")==0) {
		psl->lpVtbl->SetDescription(psl,(LPSTR)val);
	    } else if (strcmp(opt, "-icon")==0) {
		Tcl_DString	ds;
		int	idx;

		hres = psl->lpVtbl->GetIconLocation( psl, szBuf, MAX_PATH, &idx); 
		if (!SUCCEEDED(hres)) {
		    Tcl_AppendResult(interp, "failed to get existing icon location",
				    (char *)NULL);
		    goto setErr;
		}
		Tcl_DStringInit(&ds);
		val = Tcl_TranslateFileName( interp, val, &ds);
		if (val == NULL)
		    goto setErr;
		psl->lpVtbl->SetIconLocation(psl, val, idx);
	    } else if (strcmp(opt, "-index")==0) {
		int	idx, oidx;

		if (Tcl_GetInt(interp, val, &idx)!=TCL_OK)
		    goto setErr;

		hres = psl->lpVtbl->GetIconLocation( psl, szBuf, MAX_PATH, &oidx); 
		if (!SUCCEEDED(hres)) {
		    Tcl_AppendResult(interp, "failed to get existing icon location",
				    (char *)NULL);
		    goto setErr;
		}
		psl->lpVtbl->SetIconLocation(psl, szBuf, idx);
	    } else if (strcmp(opt, "-hotkey")==0) {
		if (Tcl_GetIntFromObj(interp, objv[i+1], &w)!=TCL_OK)
		    goto setErr;
		psl->lpVtbl->SetHotkey(psl, (WORD)w);
	    } else if (strcmp(opt, "-show")==0) {
		if (Tcl_GetIntFromObj(interp, objv[i+1], &w)!=TCL_OK)
		    goto setErr;
		psl->lpVtbl->SetShowCmd(psl, w);
	    } else {
		Tcl_AppendResult(interp, "bad option \"", opt,
			"\": must be one of -args, -cwd, -desc, -hotkey, -icon, -path or -show",
				(char *)NULL);
		goto setErr;
	    }
	}
	hres = ppf->lpVtbl->Save(ppf, wpath, TRUE);
	if (!SUCCEEDED(hres)) {
	    Tcl_AppendResult(interp, "couldn't save shortcut \"",
			path, "\"", (char *)NULL);
setErr:
	    ppf->lpVtbl->Release(ppf);
	    return TCL_ERROR;
	}
	ppf->lpVtbl->Release(ppf);
	return TCL_OK;
    }	/* LNK_SET */
    case LNK_RECENT: {
        char    *path;
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "path");
	    return TCL_ERROR;
	}
	path = Tcl_GetStringFromObj(objv[2], (int *) NULL);
        if (strcmp(path,"-clear")==0) SHAddToRecentDocs(SHARD_PATH,NULL);
        else SHAddToRecentDocs(SHARD_PATH,path);
        return TCL_OK;
    }   /* LNK_RECENT */
    case LNK_PATH: {
        int     i, id, fallback;
        char	*opt;
	char	path[MAX_PATH];
        int     create = 0, common = 0;
        /* If no args, then return a list of possible names */
        if (objc == 2) {
            Tcl_Obj  *listPtr;
	    listPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);
            for (i=0; i < sizeof(csidl)/sizeof(*csidl); i++) {
                Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewStringObj(csidl[i].name, -1));
            }
            Tcl_SetObjResult(interp, listPtr);
            return TCL_OK;
	}
        /* Determine if we want -create or -common */
        for (i=2; i < objc; i++) {
            opt = Tcl_GetStringFromObj(objv[i], (int *) NULL);
            if (*opt != '-') break;
            if (!strcmp(opt, "-create")) create=1;
            else if (!strcmp(opt, "-common")) common=1;
            else {
		Tcl_AppendResult(interp, "bad option \"", opt,
			"\": must be one of -create or -common",
				(char *)NULL);
                return TCL_ERROR;
            }
        }
        /* Make sure there are some args left */
        if (i!=objc-1) {
	    Tcl_WrongNumArgs(interp, i, objv, "?path?");
	    return TCL_ERROR;
        }
        /* Check if we have a number */
        opt = Tcl_GetStringFromObj(objv[i], (int *) NULL);
        if (Tcl_GetIntFromObj(NULL, objv[i], &id) == TCL_OK) {
            fallback = -1; /* Only id, no fallback */
            if (create) id += 0x8000;
            if (common) {
                Tcl_AppendResult(interp, "can't mix -common with CSIDL value", NULL);
                return TCL_ERROR;
            }
        } else {
            /* No number, look up the string */
            id = fallback = -1;
            for (i=0; i < sizeof(csidl)/sizeof(*csidl); i++) {
                if (strcmp(opt,csidl[i].name) == 0) {
                    if (!common) id=csidl[i].user, fallback=-1;
                    else if (csidl[i].common == -1) id=csidl[i].user, fallback=-1;
                    else id = csidl[i].common, fallback=csidl[i].user;
                    break;
                }
            }
        }
        /* String or number not found --- return nice error message */
        if (id == -1) {
            Tcl_AppendResult("bad path \"", opt, "\": must be one of ", NULL);
            for (i=0; i < sizeof(csidl)/sizeof(*csidl); i++) {
                Tcl_AppendResult(interp, csidl[i].name, NULL);
            }
            return TCL_ERROR;
        }
        /* Some paths are special, the rest we look up */
        if (id == -2) /* temp */
            tempdir(path,sizeof(path));
        else if (id == 0x24) /* windows */
            GetWindowsDirectory(path, sizeof(path));
        else if (id == 0x25) /* system */
            GetSystemDirectory(path, sizeof(path));
        else if (id == 0x26) /* programfiles */
            regkey(HKEY_LOCAL_MACHINE, SYSREG, "ProgramFilesDir",path,sizeof(path));
        else if (id == 0x2b) /* commonfiles */
            regkey(HKEY_LOCAL_MACHINE, SYSREG, "CommonFilesDir",path,sizeof(path));
        else {
            while (id != -1) {
                if (getlocation(id,path)) break;
                id=fallback; 
                fallback=-1; 
            }
            if (id == -1) *path = 0;
        }
        
        Tcl_SetObjResult(interp,fconvert(path));
        
        return TCL_OK;
    }   /* LNK_PATH */
    }	/*switch*/
}

int
Winlink_Init(Tcl_Interp *interp)
{
#ifdef USE_TCL_STUBS
    Tcl_InitStubs(interp, "8.0", 0);
#endif
    
    Tcl_CreateObjCommand(interp, "winlink::link", LinkCmd,
			  (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
    Tcl_Eval(interp, "namespace eval winlink {namespace export link}");

    Tcl_CreateExitHandler(ExitHandler, NULL);

    return Tcl_PkgProvide( interp, "winlink", "1.2");
}
