/*
        See linebuf.h for description

	Copyright (C) 9/30/94, 7/15/95, 10/8/96, 5/30/97
                        by Kevin V. O'Donovan

*/


/* Include files */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <linebuf.h>

#ifndef MALLOC
#define MALLOC malloc
#else
extern void* MALLOC(size_t);
#endif
#ifndef FREE
#define FREE free
#else
extern void FREE(void *);
#endif


/* SCCS Version info */
char *lineBuf_SCCS_VerInfo = 
                       "@(#)Linebuf\tVersion 1.21\t9/12/00\n"
                       "@(#)openBuf\tVersion 1.11\t9/12/97\n"
                       "@(#)closeBuf\tVersion 1.10\t8/18/97\n"
                       "@(#)rewindable\tVersion 1.00\t5/30/97\n"
                       "@(#)getNextLine\tVersion 2.03\t9/12/00\n"
                       "@(#)setNextLine\tVersion 2.00\t5/30/97\n"
                       "@(#)rewindBuf\tVersion 2.00\t5/30/97\n"
                       "@(#)parseComment\tVersion 1.10\t10/8/96\n"
                       "@(#)countData\tVersion 2.00\t5/30/97\n"
                       "@(#)flushLine\tVersion 1.00\t3/7/00\n"
                       "@(#)linkBuf\tVersion 1.00\t4/24/01\n"
                       ;

/* Function Definitions */
char *lineBufVersionAnnounce(void)
{
   return lineBuf_SCCS_VerInfo;
}



FILE *linkBuf(FILE *stream, LINEBUF *IFS, size_t size)
{
   if (stream != NULL) {
      if (IFS == NULL)
         stream = NULL;
      else {
         if (IFS->stream != NULL && closeBuf(IFS, 1))
            stream = NULL;
         else {
            IFS->stream = NULL;
            if (size != 0 && size != IFS->lineLength) {
               if (IFS->buffer != NULL)
                  FREE(IFS->buffer);
               IFS->buffer = MALLOC(size);
               IFS->lineLength = size;
            }
            IFS->stream = stream;
            IFS->norewind=!rewindable(IFS->stream);
            IFS->fullLineRead = 1;
            IFS->isComment = 0;
            IFS->commentChar = '#';
            IFS->bufferOffset = ftell(stream);
         }
      }
   }
   return stream;
}


FILE *openBuf(const char *path, const char *mode, LINEBUF *IFS, size_t size)
{
   if (size != 0) {
      IFS->buffer = MALLOC(size);
      IFS->lineLength = size;
      IFS->stream = NULL;
   }
   if (size == 0 || IFS->buffer != NULL) {
      IFS->stream=fopen(path, mode);
      IFS->norewind=!rewindable(IFS->stream);
      IFS->fullLineRead = 1;
      IFS->isComment = 0;
      IFS->commentChar = '#';
      IFS->bufferOffset = (IFS->stream == NULL) ? 0 : ftell(IFS->stream);
   }

   return IFS->stream;
}



int closeBuf(LINEBUF *IFS, size_t size)
{
   if (size == 0 && IFS->buffer != NULL) {
      FREE(IFS->buffer);
      IFS->buffer = NULL;
      IFS->lineLength = 0;
   }

   IFS->fullLineRead = 1;
   IFS->isComment = 0;
   IFS->bufferOffset = 0;
   IFS->norewind = 1;
   
   return fclose(IFS->stream);
}



int rewindable(FILE *stream)
{
   return !(
              stream == NULL || 
              isatty(fileno(stream)) ||
              fseek(stream,0,SEEK_CUR)
            );
}



char *getNextLine(LINEBUF *IFS)
{
   char *ReturnValue=NULL;

   if (IFS != NULL && IFS->stream != NULL) {
      if (IFS->fullLineRead) IFS->bufferOffset = ftell(IFS->stream);
      ReturnValue = fgets(IFS->buffer,IFS->lineLength,IFS->stream);
      if (ReturnValue != NULL) {
         if (IFS->fullLineRead) IFS->isComment = (IFS->buffer[0] == IFS->commentChar) || (IFS->buffer[0] == '\n');
         IFS->fullLineRead = ((int) strlen(IFS->buffer) < IFS->lineLength-1 ||
                             *(IFS->buffer+IFS->lineLength-2) == '\n');
      } else {
         IFS->fullLineRead = 1;
         IFS->isComment = 0;
      }
   }

   return(ReturnValue);
}



int setNextLine(LINEBUF *IFS, long Offset)
{
   register int ReturnValue;

   rewind(IFS->stream);
   ReturnValue = fseek(IFS->stream,Offset,SEEK_SET);
   IFS->fullLineRead = 1;
   IFS->isComment = 0;
   IFS->bufferOffset = (IFS->stream == NULL) ? 0 : ftell(IFS->stream);

   return(ReturnValue);
}



void rewindBuf(LINEBUF *IFS)
{
   if (!IFS->norewind) rewind(IFS->stream);
   IFS->fullLineRead = 1;
   IFS->isComment = 0;
   IFS->bufferOffset = (IFS->stream == NULL) ? 0 : ftell(IFS->stream);
}



char *flushLine(LINEBUF *IFS, FILE *stream)
{
   char *returnValue = IFS->buffer;

   if (!IFS->fullLineRead) do {
      returnValue = getNextLine(IFS);
      if (stream != NULL && returnValue != NULL) fputs(IFS->buffer, stream);
   } while (!IFS->fullLineRead);
   return returnValue;
}



long countData(LINEBUF *IFS)
{
   register long numDataLines = 0L;

   /* I don't recommend counting a non-rewindable stream! */
   if (IFS->norewind) return -1L; 

   rewindBuf(IFS);
   while (getNextLine(IFS) != NULL) {
      if (! IFS->isComment) ++numDataLines;
      while (!IFS->fullLineRead)
         getNextLine(IFS);
   }
   rewindBuf(IFS);

   return numDataLines;
}



void parseComment(char *(*allowedComment)[2], char *comment)
{
   char *scanfMark;
   register int scanfArg;
   size_t identifierLength;

   while ((*allowedComment)[0] != NULL) {
      identifierLength = strlen((*allowedComment)[0]);
      scanfMark = (*allowedComment)[0] + identifierLength;
      if (strncmp((*allowedComment)[0], comment, identifierLength) == 0) {
         scanfArg = 0;
         do *(scanfMark+scanfArg) = *(scanfMark+scanfArg+1);
         while (*(scanfMark+scanfArg++) != '\0');

         sscanf(comment, (*allowedComment)[0], (*allowedComment)[1]);

         for (--scanfArg; scanfArg > 0; scanfArg--)
           *(scanfMark+scanfArg) = *(scanfMark+scanfArg-1);
         *scanfMark = '\0';

      }
      allowedComment++;
   }
}
