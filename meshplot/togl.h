/* $Id$ */

/*
 * Togl - a Tk OpenGL widget
 * Version 1.6
 * Copyright (C) 1996-1998  Brian Paul and Ben Bederson
 * See the LICENSE file for copyright details.
 */


#ifndef TOGL_H
#define TOGL_H

#if defined(TOGL_WGL)
#   define WIN32_LEAN_AND_MEAN
#   include <windows.h>
#   undef WIN32_LEAN_AND_MEAN
#   if defined(_MSC_VER)
#	define DllEntryPoint DllMain
#   endif
#endif

#ifdef _WIN32
#   define TOGL_EXTERN __declspec(dllexport) extern
#else
#   define TOGL_EXTERN extern
#endif /* WIN32 */

#ifdef TOGL_AGL_CLASSIC
# ifndef MAC_TCL
#   define MAC_TCL 1
# endif
#endif

#ifdef TOGL_AGL
# ifndef MAC_OSX_TCL
#  define MAC_OSX_TCL 1
# endif
# ifndef MAC_OSX_TK
#  define MAC_OSX_TK 1
# endif
#endif

#include <tcl.h>
#include <tk.h>
#if defined(TOGL_AGL) || defined(TOGL_AGL_CLASSIC)
# include <OpenGL/gl.h>
#else
# include <GL/gl.h>
#endif

#ifdef __sgi
# include <GL/glx.h>
# include <X11/extensions/SGIStereo.h>
#endif


#ifndef NULL
# define NULL    0
#endif


#ifdef __cplusplus
extern "C" {
#endif


#define TOGL_VERSION "1.7"
#define TOGL_MAJOR_VERSION 1
#define TOGL_MINOR_VERSION 7



/*
 * "Standard" fonts which can be specified to Togl_LoadBitmapFont()
 */
#define TOGL_BITMAP_8_BY_13		((char *) 1)
#define TOGL_BITMAP_9_BY_15		((char *) 2)
#define TOGL_BITMAP_TIMES_ROMAN_10	((char *) 3)
#define TOGL_BITMAP_TIMES_ROMAN_24	((char *) 4)
#define TOGL_BITMAP_HELVETICA_10	((char *) 5)
#define TOGL_BITMAP_HELVETICA_12	((char *) 6)
#define TOGL_BITMAP_HELVETICA_18	((char *) 7)
 

/*
 * Normal and overlay plane constants
 */
#define TOGL_NORMAL	1
#define TOGL_OVERLAY	2



struct Togl;


typedef void (Togl_Callback) (struct Togl *togl);
typedef int  (Togl_CmdProc) (struct Togl *togl, int argc, char *argv[]);
  
TOGL_EXTERN int Togl_Init(Tcl_Interp *interp);

/*
 * Default/initial callback setup functions
 */

TOGL_EXTERN void Togl_CreateFunc( Togl_Callback *proc );

TOGL_EXTERN void Togl_DisplayFunc( Togl_Callback *proc );

TOGL_EXTERN void Togl_ReshapeFunc( Togl_Callback *proc );

TOGL_EXTERN void Togl_DestroyFunc( Togl_Callback *proc );

TOGL_EXTERN void Togl_TimerFunc( Togl_Callback *proc );

TOGL_EXTERN void Togl_ResetDefaultCallbacks( void );


/*
 * Change callbacks for existing widget
 */

TOGL_EXTERN void Togl_SetCreateFunc( struct Togl *togl, Togl_Callback *proc );

TOGL_EXTERN void Togl_SetDisplayFunc( struct Togl *togl, Togl_Callback *proc );

TOGL_EXTERN void Togl_SetReshapeFunc( struct Togl *togl, Togl_Callback *proc );

TOGL_EXTERN void Togl_SetDestroyFunc( struct Togl *togl, Togl_Callback *proc );

TOGL_EXTERN void Togl_SetTimerFunc( struct Togl *togl, Togl_Callback *proc );


/*
 * Miscellaneous
 */

TOGL_EXTERN int Togl_Configure( Tcl_Interp *interp, struct Togl *togl, 
                           int argc, char *argv[], int flags );

TOGL_EXTERN void Togl_MakeCurrent( const struct Togl *togl );

TOGL_EXTERN void Togl_CreateCommand( char *cmd_name,
                                Togl_CmdProc *cmd_proc );

TOGL_EXTERN void Togl_PostRedisplay( struct Togl *togl );

TOGL_EXTERN void Togl_SwapBuffers( const struct Togl *togl );


/*
 * Query functions
 */

TOGL_EXTERN char *Togl_Ident( const struct Togl *togl );

TOGL_EXTERN int Togl_Width( const struct Togl *togl );

TOGL_EXTERN int Togl_Height( const struct Togl *togl );

TOGL_EXTERN Tcl_Interp *Togl_Interp( const struct Togl *togl );

TOGL_EXTERN Tk_Window Togl_TkWin( const struct Togl *togl );


/*
 * Color Index mode
 */

TOGL_EXTERN unsigned long Togl_AllocColor( const struct Togl *togl,
                                      float red, float green, float blue );

TOGL_EXTERN void Togl_FreeColor( const struct Togl *togl, unsigned long index );

TOGL_EXTERN void Togl_SetColor( const struct Togl *togl, unsigned long index,
                           float red, float green, float blue );


#ifdef TOGL_USE_FONTS
/*
 * Bitmap fonts
 */

TOGL_EXTERN GLuint Togl_LoadBitmapFont( const struct Togl *togl,
                                   const char *fontname );

TOGL_EXTERN void Togl_UnloadBitmapFont( const struct Togl *togl, GLuint fontbase );
#endif


/*
 * Overlay functions
 */

TOGL_EXTERN void Togl_UseLayer( struct Togl *togl, int layer );

TOGL_EXTERN void Togl_ShowOverlay( struct Togl *togl );

TOGL_EXTERN void Togl_HideOverlay( struct Togl *togl );

TOGL_EXTERN void Togl_PostOverlayRedisplay( struct Togl *togl );

TOGL_EXTERN void Togl_OverlayDisplayFunc( Togl_Callback *proc );

TOGL_EXTERN int Togl_ExistsOverlay( const struct Togl *togl );

TOGL_EXTERN int Togl_GetOverlayTransparentValue( const struct Togl *togl );

TOGL_EXTERN int Togl_IsMappedOverlay( const struct Togl *togl );

TOGL_EXTERN unsigned long Togl_AllocColorOverlay( const struct Togl *togl,
                                             float red, float green, 
                                             float blue );

TOGL_EXTERN void Togl_FreeColorOverlay( const struct Togl *togl, 
                                   unsigned long index );

/*
 * User client data
 */

TOGL_EXTERN void Togl_ClientData( ClientData clientData );

TOGL_EXTERN ClientData Togl_GetClientData( const struct Togl *togl );

TOGL_EXTERN void Togl_SetClientData( struct Togl *togl, ClientData clientData );


/*
 * X11-only commands.
 * Contributed by Miguel A. De Riera Pasenau (miguel@DALILA.UPC.ES)
 */

#ifdef TOGL_X11
TOGL_EXTERN Display *Togl_Display( const struct Togl *togl );
TOGL_EXTERN Screen *Togl_Screen( const struct Togl *togl );
TOGL_EXTERN int Togl_ScreenNumber( const struct Togl *togl );
TOGL_EXTERN Colormap Togl_Colormap( const struct Togl *togl );
#endif


/*
 * SGI stereo-only commands.
 * Contributed by Ben Evans (Ben.Evans@anusf.anu.edu.au)
 */

#ifdef __sgi
TOGL_EXTERN void Togl_OldStereoDrawBuffer( GLenum mode );
TOGL_EXTERN void Togl_OldStereoClear( GLbitfield mask );
#endif
TOGL_EXTERN void Togl_StereoFrustum( GLfloat left, GLfloat right,
                                GLfloat bottom, GLfloat top,
                                GLfloat near, GLfloat far,
                                GLfloat eyeDist, GLfloat eyeOffset );


/*
 * Generate EPS file.
 * Contributed by Miguel A. De Riera Pasenau (miguel@DALILA.UPC.ES)
 */

TOGL_EXTERN int Togl_DumpToEpsFile( const struct Togl *togl,
                               const char *filename,
                               int inColor,
                               void (*user_redraw)(const struct Togl *) );



/* Mac-specific setup functions */
#ifdef TOGL_AGL_CLASSIC
int Togl_MacInit(void);
int Togl_MacSetupMainInterp(Tcl_Interp *interp);
#endif

#ifdef __cplusplus
}
#endif


#endif
