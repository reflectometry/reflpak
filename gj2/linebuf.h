/* Description:

        This file defines the function getNextLine which
        can be used to parse text files whose input lines
        may be longer than your buffer.  It sets two flag
        variables and one value variable after reading from
        the specified buffer.  The file is read using fgets
        and the function returns the value from that call.
        In particular, end of file is indicated with a NULL
        return value. 

        The flag fullLineRead is cleared if there are still
        more characters to read on the current text line after
        the call to getNextLine.  (i.e., your buffer was too small)
        When the end of file is encountered, fullLineRead is set.

        The flag isComment is set if the current text line
        begins with the commentChar character or if it is completely
        blank.  The commentChar character is set to # when the buffer
        is opened but can be changed at anytime afterwards.  When
        the end of file is encountered, isComment is cleared.

        The variable bufferOffset is set to the position in the
        file of the beginning of the line.  It can be used in
        fseek or setNextLine.

	The function flushLine reads until the next end of line
	or the end of file is encountered.  The return value is
	that of getNextLine with the buffer contents set to that
	of the last read for the line.  The second argument is a
	stream to which is copied the portion of the line read
	during the call to flushLine.  Use NULL if you do not
	need this capability.  There is no change in file
	position and no output to stream if the end of line has
	already been read.


        The function setNextLine repositions the file pointer to
        the specified offset from the beginning of the file.
        fullLineRead is set to 1 and isComment is set to 0.


        The function rewindBuf repositions the file pointer
        to the beginning of the file.  fullLineRead is set to 1
        and isComment is set to 0.


        The function openBuf is used to open a file an initialize
        the data.  File opening parameters are identical to those
        of fopen.  Space for the buffer is dynamically allocated
        if size is non-zero.  The buffer allocation is disabled
        if size is zero; you must allocate and initialize the
        structure yourself.  Allocation failure is indicated
        by a NULL return value when called with non-zero size.
        In this case, buffer will also be NULL and lineLength
        will be set to size.


        The function closeBuf is used to close a file and set
        the data structures to appropriate values for a closed
        file.  The buffer is deallocated (if non-NULL) if size
        is zero.  The buffer is preserved if size is non-zero.
        A subsequent openBuf can use the same buffer as a previous
        file if closeBuf is called with non-zero size and the
        subsequent openBuf is called with zero size.


	The function linkStream connects an existing open file
	with a data structure.  If the data structure has an
	open file (signified by a non-zero stream), that file is
	closed, with errors resulting in no further
	initialization and a return value of NULL.  If the
	requested size of the new buffer is non-zero and
	different from the size of the current buffer in the
	data structure, that buffer is deallocated (if non-NULL)
	and a new one allocated.  Otherwise the buffer is
	preserved (including contents).  In either case,
	fullLineRead is set to 1, isComment is set to 0, and
	commentChar is reset to the default.  The bufferOffset
	is set to the current position in the new file.


        The function countData counts the number of non-commented
        lines in the file.  It starts from the beginning of the
        file and exits with the file position pointer also at
        the beginning of the file.  The return value will be -1
        (and the file position pointer unchanged) if the file
        cannot be repositioned.


        The function parseComment attempts to match a comment
        with a predefined identifier.  If successful, the first
        field after the identifier is parsed with scanf.

        In your proogram, the declaration and definition of
        allowedComment should be like this:

           char *allowedComment[][2] =
                {{"# Identifier\0scanfarg", (char *) varptr},
                    .
                    .
                    .
                 {NULL, NULL}
                };

        parseComment will match up to the \0 in the definition,
        and if successful, shift the scanfarg left by one character
        and pass the result to the sscanf function.

        Complete example:

          int n;
          char *string;
          char *commentData[][2] = {{"# X:\0 %d", (char *)(&n)},
                                    {NULL, NULL}};

          parseComment(commentData, string);

        will attempt to match the beginning of string with
        "# X:".  If that matches, sscanf(string, "# X: %d", &n)
        will be evaluated.

        Multiple fields on a line can be parsed with multiple
        entries in allowedComment having duplicate identifiers,
        but different scanfargs contrived so that scanf will
        ignore previously read variables.  This requires that
        your scanf syntax supports specifying fields to be
        skipped in the command string.



        Copyright (C) 9/30/94, 7/15/95, 10/8/96, 5/30/97
                        by Kevin V. O'Donovan

*/


#ifndef __LINEBUF_H
#define __LINEBUF_H

typedef struct {
   FILE *stream;
   char *buffer;

   size_t lineLength;    /* Maximum size of buffer */
   int    norewind;      /* Is the stream rewindable? */
   int    fullLineRead;  /* Did the last read complete the end of the */
                         /*    current line? */
   int    isComment;     /* Is the current line a comment? */
   long   bufferOffset;  /* fseek compatible pointer to first character */
                         /*    on line */
   char   commentChar;   /* Character which begins comments */
} LINEBUF;


/* Function prototypes */
FILE *openBuf(const char *, const char *, LINEBUF *, size_t);
FILE *linkBuf(FILE *, LINEBUF *, size_t);
int   closeBuf(LINEBUF *, size_t);
int   rewindable(FILE *stream);
char *getNextLine(LINEBUF *);
int   setNextLine(LINEBUF *, long);
void  rewindBuf(LINEBUF *);
long  countData(LINEBUF *);
void  parseComment(char *(*)[2], char *);
char *lineBufVersionAnnounce(void);
char *flushLine(LINEBUF *, FILE *);

#endif /* __LINEBUF_H */
