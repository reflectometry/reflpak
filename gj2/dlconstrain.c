/* Provides support for linking dynamic loading of constrain function */

#define COMMON

#if 0
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <string.h>
#include <dlfcn.h>
#include <constraincpp.h>
#endif

#include <dlconstrain.h>

/* Local function prototypes */
#include <static.h>

STATIC void noconstraints(int dels, double a[], int nlayer);
#if 0
STATIC void *findName(void *libhandle, char *name, size_t length);
STATIC int prepScriptfile(char *scriptfile);
STATIC int launchEditor(char *editorfullpath, char *scriptfile);
STATIC int waitChild(pid_t child);


/* Module variables */
static void *libhandle = NULL;
static char idstring[] = "mlayerid ";
static char constrainName[] = "constrain ";
static char idparam[11];
static char *makeBinaryDefault = "makeconstrain";
#endif

char *makeBinary = NULL;

#define MAJORVER(verid) ((verid) & 0xFFFF0000L)
#define MINORVER(verid) ((verid) & 0x0000FFFFL)


constrainFunc loadConstrain(char *path)
{
   constrainFunc constraints = noconstraints;
#if 0
   closeLib();
   if (path != NULL)
      constraints = findFunc(path, constrainName, sizeof(constrainName) - 1);
   else {
      constraints = noconstraints;
      puts("Relaxing all constraints");
   }
#endif
   return constraints;
}


constrainFunc findFunc(char *path, char *funcName, size_t length)
{
   constrainFunc func = noconstraints;
#if 0
   long int *version;

   libhandle = dlopen(path, RTLD_LAZY);
   if (libhandle == NULL) {
      fprintf(stderr, "Cannot find constrain module: %s\n", path);
   } else if (
      (version = (long int *)findName(libhandle, idstring, sizeof(idstring) - 1)
      ) == NULL
   ) {
      fprintf(stderr, "Cannot establish version of constrain module\n");
      closeLib();
   } else if (MAJORVER(*version) != MAJOR) {
      fprintf(stderr, "Constrain module is not designed for this program\n");
      closeLib();
   } else if (MINORVER(*version) < MINOR) {
      fprintf(stderr, "Constrain module is designed for an older version of this program\n");
      closeLib();
   } else if (
      (func = (constrainFunc) findName(libhandle, funcName, length)
      ) == NULL
   ) {
      fprintf(stderr, "Constrain module does not define constraints\n");
      func = noconstraints;
      closeLib();
   }
   if (func == noconstraints)
      fprintf(stderr, "Defaulting to no constraints\n");
#endif

   return func;
}


void closeLib(void)
{
#if 0
   if (libhandle != NULL) {
      dlclose(libhandle);
      libhandle = NULL;
   }
#endif
}


void noconstraints(int dels, double a[], int nlayer)
{
   return;
}


#if 0
STATIC void *findName(void *libhandle, char *name, size_t length)
{
#define findNameCase(func) \
   for (text = name; text < underscore; text++) \
      *text = (func)(*text); \
   libSymbol = dlsym(libhandle, name);

   char *underscore;
   register char *text;
   void *libSymbol = NULL;

   if (libhandle != NULL && name != NULL && *name != 0 && length > 1) {
      underscore = name + length - 1;

      /* Try lowercase version, no trailing underscore */
      *underscore = 0;
      findNameCase(tolower);
      if (libSymbol == NULL) {
         /* Try uppercase version, no underscore */
         findNameCase(toupper);
         if (libSymbol == NULL) {
            /* Try lowercase with trailing underscore */
            *underscore = '_';
            findNameCase(tolower);
            if (libSymbol == NULL) {
               /* Try uppercase with trailing underscore */
               findNameCase(toupper);
            }
         }
      }
   }
   return libSymbol;
}
#endif

int makeconstrain(char *scriptfile, char *objectfile)
{
   int failure = 1;
#if 0
   pid_t child;

   if (scriptfile != NULL && objectfile != NULL) {
      while (*scriptfile != 0 && isspace(*scriptfile))
         scriptfile++;
      while (*objectfile != 0 && isspace(*objectfile))
         objectfile++;
      if (*scriptfile != 0 && *objectfile != 0) {
         sprintf(idparam, "0x%08lx", MAJOR | MINOR);
	 if (makeBinary == NULL) makeBinary = getenv("MLAYER_CONSTRAINTS");
	 if (makeBinary == NULL) makeBinary = makeBinaryDefault;
         makeargv[0] = makeBinary;
         makeargv[1] = scriptfile;
         makeargv[2] = objectfile;
         makeargv[3] = idparam;
         makeargv[4] = prototype;

         child = fork();
         switch (child) {
            case 0:
               /* I am the child */
               if (execvp(makeBinary, makeargv) == -1) {
                  printf("Cannot load strain compiler %s: %s\n", makeBinary, 
                     strerror(errno));
                  exit(errno);
               }
               break; /* gratuitous */
            case -1:
               /* Failure */
               printf("Cannot load strain compiler %s: %s\n", makeBinary, 
                  strerror(errno));
               break;
            default:
               /* Success. I am the parent */
               failure = waitChild(child);
         }
      }
   }
#endif
   return failure;
}


constrainFunc newConstraints(char *scriptfile, char *objectfile)
{
   constrainFunc constraints = NULL;
#if 0
   struct stat beforeEdit, afterEdit;

   /* Make sure value is defined */
   beforeEdit.st_mtime = 0;

   if (
      /* Scriptfile is readable */
      stat(scriptfile, &beforeEdit) == 0 ||

      /* Or does not exist */
       errno == ENOENT
   ) {
      editconstraints(scriptfile);
      if (
         /* Script file exists */
         stat(scriptfile, &afterEdit) == 0 && (

            /* And was modified */
            afterEdit.st_mtime != beforeEdit.st_mtime || (

               /* Or object file exists */
               (stat(objectfile, &beforeEdit) == 0) ? 

                  /* But is out of date */
                  beforeEdit.st_mtime < afterEdit.st_mtime :

                  /* Or object file does not exist */
                  errno == ENOENT
            )
         )
      ) {
        if (makeconstrain(scriptfile, objectfile) == 0)
            constraints = loadConstrain(objectfile);
         else
            puts("Constrain module has errors.  Please correct.");
      } else puts("No new constraints added");
   }
#endif
   return constraints;
}


int editconstraints(char *scriptfile)
{
   int retvalue = 0;
#if 0
   char *editor, *defaulteditor;
   #define defaultXeditor "/usr/local/bin/nedit"
   #define defaultTeditor "/usr/bin/vi"

   if (scriptfile != NULL) {
      while (*scriptfile != 0 && isspace(*scriptfile))
         scriptfile++;
      if (*scriptfile != 0 && prepScriptfile(scriptfile)) {
         pid_t child;

         defaulteditor = (getenv("DISPLAY") == NULL) ?
                            defaultTeditor :
                            defaultXeditor;

         editor = getenv("EDITOR");
         if (editor == NULL) editor = defaulteditor;

         child = fork();
         switch (child) {
            case 0:
               /* I am the child */
               if (
                  launchEditor(editor, scriptfile) == -1 &&
                  editor != defaulteditor &&
                  launchEditor(defaulteditor, scriptfile) == -1
               ) {
                  printf("Failed to launch editor: %s: %s\n", editor,
                     strerror(errno));
                  exit(errno);
               }
               break; /* gratuitous */
            case -1:
               /* Failure */
               printf("Cannot edit %s\n", scriptfile);
               break;
            default:
               /* Success. I am the parent */
               retvalue = waitChild(child);
         }
      } else
         retvalue = 1;
   } else
      retvalue = 1;
#endif
   return retvalue;
}

#if 0
STATIC int prepScriptfile(char *scriptfile)
{
   static const char *constrainthints =
   "/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *\n"
   " *                                                           *\n"
   " * Type in your constraints below.  Parameters are specified *\n"
   " * as you would in the program.  For example: QC3 = QC4      *\n"
   " * You may also use parentheses: QC(3) = QC(j), which sug-   *\n"
   " * gests you may use variables!  Variable definitions and    *\n"
   " * operations must conform to good C language syntax.  That  *\n"
   " * unfortunately means that case is important.  However,     *\n"
   " * case does not matter for the parameter names.             *\n"
   " *                                                           *\n"
   " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */\n"
   "\n";

   FILE *stream;
   int succeeded = 1;

   stream = fopen(scriptfile, "r");
   if (stream == NULL) {
      if (errno == 2) {
         stream = fopen(scriptfile, "w");
         if (stream != NULL) {
            fputs(constrainthints, stream);
            fclose(stream);
         } else
            succeeded = 0;
      } else
         succeeded = 0;
   }
   return succeeded;
}


STATIC int launchEditor(char *editorfullpath, char *scriptfile)
{
   char *editor;

   editor = strrchr(editorfullpath,'/');
   if (editor == NULL)
      editor = editorfullpath;
   else
      editor ++;

  return execlp(editorfullpath, editor, scriptfile, NULL);
}


STATIC int waitChild(pid_t child)
{
   pid_t deceased;
   int status;
   int retvalue = 0;

   do {
      deceased = wait(&status);
   } while (
      deceased != child /* ||
      WIFSTOPPED(status) ||
      WIFCONTINUED(status) */
   );
   if (WIFEXITED(status))
      retvalue = WEXITSTATUS(status);

   return retvalue;
}
#endif
