/*
# freeWrap is Copyright (c) 1998-2002 by Dennis R. LaBelle (labelled@nycap.rr.com) 
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

/*
** This file implements the main routine for a standalone TCL/TK shell.
   Revision history:

   Revison  Date           Author             Description
   -------  -------------  -----------------  ----------------------------------------------
     5.2    June 2, 2002   Dennis R. LaBelle  1) Changed mount of ZVFS to / instead of /zvfs
                                              2) Now appends to auto_path instead of
                                                 directly setting auto_path variable.
     5.4    Oct 16, 2002   Dennis R. LaBelle  1) Added necessary beginning space when appending
                                                 to auto_path TCL variable. This fixed problem
                                                 with locating the executable in a directory
                                                 path that included a space.
                                              2) Removed / from auto_path variable to prevent
                                                 searching of / path for libraries upon startup.
     5.5    Jan 12, 2003   Dennis R. LaBelle  1) Removed use of WinICO since Windows icon feature
                                                 is supported by "wm iconbitmap" command as of
                                                 TK 8.3.3
*/
#include <tcl.h>
/* #include <tclInt.h> */
#include <tk.h>

/* function prototypes */
extern int		isatty _ANSI_ARGS_((int fd));

/*
** We will be linking against all of these extensions.
*/
#if defined(__WIN32__)
#include <windows.h>
extern int Registry_Init(Tcl_Interp *);
extern int Dde_Init(Tcl_Interp *);
#endif

extern int Blt_Init(Tcl_Interp*);
extern int Blt_SafeInit(Tcl_Interp*);
extern int Freewrap_Init(Tcl_Interp*);
extern int Img_Init(Tcl_Interp*);
extern int Sqlite_Init(Tcl_Interp*);
extern int Tkhtml_Init(Tcl_Interp*);
extern int Tktable_Init(Tcl_Interp*);
extern int Tktable_SafeInit(Tcl_Interp*);
extern int Tlink_Init(Tcl_Interp*);
extern int Zvfs_Init(Tcl_Interp*);
extern int Zvfs_Mount(Tcl_Interp*, char*, char *);

/*
** This routine runs first.  
*/
int main(int argc, char **argv){
  Tcl_Interp *interp;
  char *args;
  char buf[100];
  int tty;

#ifdef WITHOUT_TK
    Tcl_Obj *resultPtr;
    Tcl_Obj *commandPtr = NULL;
    char buffer[1000];
    int code, gotPartial, length;
    Tcl_Channel inChannel, outChannel, errChannel;
#endif

  /* Create a Tcl interpreter
  */
  Tcl_FindExecutable(argv[0]);
  interp = Tcl_CreateInterp();
  if( Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 1)==0 ){
    return 1;
  }
  args = Tcl_Merge(argc-1, argv+1);
  Tcl_SetVar(interp, "argv", args, TCL_GLOBAL_ONLY);
  ckfree(args);
  sprintf(buf, "%d", argc-1);
  Tcl_SetVar(interp, "argc", buf, TCL_GLOBAL_ONLY);
  Tcl_SetVar(interp, "argv0", argv[0], TCL_GLOBAL_ONLY);
  tty = isatty(0);
  Tcl_SetVar(interp, "tcl_interactive", "0", TCL_GLOBAL_ONLY);

  /* We have to initialize the virtual filesystem before calling
  ** Tcl_Init().  Otherwise, Tcl_Init() will not be able to find
  ** its startup script files.
  */

  Zvfs_Init(interp);
  Tcl_SetVar(interp, "extname", "", TCL_GLOBAL_ONLY);
  Zvfs_Mount(interp, (char *)Tcl_GetNameOfExecutable(), "/");
  Tcl_SetVar2(interp, "env", "TCL_LIBRARY", "/tcl", TCL_GLOBAL_ONLY);
  Tcl_SetVar2(interp, "env", "TK_LIBRARY", "/tk", TCL_GLOBAL_ONLY);

  /* Initialize Tcl and Tk
  */
  if( Tcl_Init(interp) ) return TCL_ERROR;

  Tcl_SetVar(interp, "auto_path", " /tcl", TCL_GLOBAL_ONLY | TCL_APPEND_VALUE);
  Tcl_SetVar(interp, "tcl_libPath", "/tcl", TCL_GLOBAL_ONLY);

#ifdef WITHOUT_TK
  Tcl_SetVar(interp, "extname", "tclsh", TCL_GLOBAL_ONLY);
#else 
  Tk_InitConsoleChannels(interp);
  if ( Tk_Init(interp) ) {
       return TCL_ERROR;
    }
  Tcl_StaticPackage(interp,"Tk", Tk_Init, 0);
  Tk_CreateConsoleWindow(interp);
#endif

  /* Start up all extensions.
  */
#if defined(__WIN32__)
  /* DRL - Do the standard Windows extentions */

  if (Registry_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "registry", Registry_Init, 0);

  if (Dde_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "dde", Dde_Init, 0);
#endif

#ifndef WITHOUT_BLT
  /* set the extension name so we can correctly set the program name later. */
  Tcl_SetVar(interp, "extname", "blt", TCL_GLOBAL_ONLY);

  if (Blt_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "blt", Blt_Init, Blt_SafeInit);
#endif

#ifndef WITHOUT_IMG
  if (Img_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "img", Img_Init, Img_SafeInit);
#endif

#ifndef WITHOUT_SQLITE
  if (Sqlite_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "sqlite", Sqlite_Init, Sqlite_SafeInit);
#endif
#ifndef WITHOUT_TKHTML
  if (Tkhtml_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "tkhtml", Tkhtml_Init, Tkhtml_SafeInit);
#endif
#ifndef WITHOUT_TKTABLE
  if (Tktable_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "Tktable", Tktable_Init, Tktable_SafeInit);
#endif
#if !defined(WITHOUT_TLINK) && (defined(__WIN32__) || defined(_WIN32))
  if (Tlink_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }
  Tcl_StaticPackage(interp, "Tlink", Tlink_Init, Tlink_SafeInit);
#endif

  /* Add some freeWrap commands */
  if (Freewrap_Init(interp) == TCL_ERROR) {
      return TCL_ERROR;
     }

  /* After all extensions are registered, start up the
  ** program by running /freewrapCmds.tcl.
  */
  Tcl_Eval(interp, "source /freewrapCmds.tcl");

#ifndef WITHOUT_TK
    /*
     * Loop infinitely, waiting for commands to execute.  When there
     * are no windows left, Tk_MainLoop returns and we exit.
     */

    Tk_MainLoop();
    Tcl_DeleteInterp(interp);
    Tcl_Exit(0);
#else
    /*
     * Process commands from stdin until there's an end-of-file.  Note
     * that we need to fetch the standard channels again after every
     * eval, since they may have been changed.
     */
    commandPtr = Tcl_NewObj();
    Tcl_IncrRefCount(commandPtr);

    inChannel = Tcl_GetStdChannel(TCL_STDIN);
    outChannel = Tcl_GetStdChannel(TCL_STDOUT);
    gotPartial = 0;
    while (1) {
	if (tty) {
	    Tcl_Obj *promptCmdPtr;

	    promptCmdPtr = Tcl_GetVar2Ex(interp,
		    (gotPartial ? "tcl_prompt2" : "tcl_prompt1"),
		    NULL, TCL_GLOBAL_ONLY);
	    if (promptCmdPtr == NULL) {
                defaultPrompt:
		if (!gotPartial && outChannel) {
		    Tcl_WriteChars(outChannel, "% ", 2);
		}
	    } else {
		code = Tcl_EvalObjEx(interp, promptCmdPtr, 0);
		inChannel = Tcl_GetStdChannel(TCL_STDIN);
		outChannel = Tcl_GetStdChannel(TCL_STDOUT);
		errChannel = Tcl_GetStdChannel(TCL_STDERR);
		if (code != TCL_OK) {
		    if (errChannel) {
			Tcl_WriteObj(errChannel, Tcl_GetObjResult(interp));
			Tcl_WriteChars(errChannel, "\n", 1);
		    }
		    Tcl_AddErrorInfo(interp,
			    "\n    (script that generates prompt)");
		    goto defaultPrompt;
		}
	    }
	    if (outChannel) {
		Tcl_Flush(outChannel);
	    }
	}
	if (!inChannel) {
	    goto done;
	}
        length = Tcl_GetsObj(inChannel, commandPtr);
	if (length < 0) {
	    goto done;
	}
	if ((length == 0) && Tcl_Eof(inChannel) && (!gotPartial)) {
	    goto done;
	}

        /*
         * Add the newline removed by Tcl_GetsObj back to the string.
         */

	Tcl_AppendToObj(commandPtr, "\n", 1);
	if (!TclObjCommandComplete(commandPtr)) {
	    gotPartial = 1;
	    continue;
	}

	gotPartial = 0;
	code = Tcl_RecordAndEvalObj(interp, commandPtr, 0);
	inChannel = Tcl_GetStdChannel(TCL_STDIN);
	outChannel = Tcl_GetStdChannel(TCL_STDOUT);
	errChannel = Tcl_GetStdChannel(TCL_STDERR);
	Tcl_DecrRefCount(commandPtr);
	commandPtr = Tcl_NewObj();
	Tcl_IncrRefCount(commandPtr);
	if (code != TCL_OK) {
	    if (errChannel) {
		Tcl_WriteObj(errChannel, Tcl_GetObjResult(interp));
		Tcl_WriteChars(errChannel, "\n", 1);
	    }
	} else if (tty) {
	    resultPtr = Tcl_GetObjResult(interp);
	    Tcl_GetStringFromObj(resultPtr, &length);
	    if ((length > 0) && outChannel) {
		Tcl_WriteObj(outChannel, resultPtr);
		Tcl_WriteChars(outChannel, "\n", 1);
	    }
	}
    }

    /*
     * Rather than calling exit, invoke the "exit" command so that
     * users can replace "exit" with some other command to do additional
     * cleanup on exit.  The Tcl_Eval call should never return.
     */

    done:
    if (commandPtr != NULL) {
	Tcl_DecrRefCount(commandPtr);
    }
    sprintf(buffer, "exit %d", 0);
    Tcl_Eval(interp, buffer);
 
#endif

  return TCL_OK;
}

