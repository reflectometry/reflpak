/* This program is public domain */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#if defined(MISSING_LIBZ) 
# define gzopen fopen
# define gzclose fclose
# define gzeof feof
# define gzgetc fgetc
# define gzungetc ungetc
# define gzrewind rewind
# define gzgets(file,text,len) fgets(text,len,file)
# define gzseek fseek
# define gztell ftell
# define z_off_t off_t
#endif /* MISSING_LIBZ */
#include "icpread.h"

#define MAX_LINE 1024

/* Open the file */
gzFile icp_open(const char name[])
{
  return gzopen(name,"rb");
}

/* close the file */
void icp_close(gzFile f)
{
  gzclose(f);
}

/* Return the next token from a string.  Tokens can be quoted text, unquoted
   text or linefeed (\n).  Returns a pointer to the text after the token, or
   to NULL if the token wasn't present or was too large to fit in the space
   provided.
*/
static const char *scan_token(const char header[], int n, char token[])
{
  char *val = token;

  /* Check for immediate exit */
  *val = '\0';
  if (header == NULL || *header == '\0') return NULL;
  // printf("scanning from %p:%s\n", header,header);
  
  /* Skip spaces */
  while (*header == ' ') header++;
  
  /* Check if the next item is a string */
  if (*header == '\'') {
    /* Quoted string */
    header++;
    while (n-- && *header && *header != '\'') *val++ = *header++;
    if (*header == '\'' && n >= 0) {
      /* successfully found quoted string. */
      *val++ = '\0';
      header++;
    } else {
      /* quoted string is too long or missing close quote */
      *token = '\0';
      return NULL;
    }
    
  } else if (*header == '\r') {
    /* CR: skip it and return the next character which is presumably LF */
    *val = '\n';
    if (*++header == '\n') header++;
  } else if (*header == '\n') {
    /* LF: return the LF character as a token */
    *val++ = *header++;
  } else {
    /* text field surrounded by spaces */
    while (n-- && *header && *header != ' ') *val++ = *header++;
  }
  if (n < 0) return NULL;
  *val++ = '\0';

  // printf("token = %s\n",token);
  return header;
}

/* Scan the header text of the icp file for the number of points */
static int numpoints(const char header[])
{
  char token[80];

  header = scan_token(header, sizeof(token), token); /* Filename */
  header = scan_token(header, sizeof(token), token); /* Date */
  header = scan_token(header, sizeof(token), token); /* Scan */
  header = scan_token(header, sizeof(token), token); /* Mon */
  header = scan_token(header, sizeof(token), token); /* Prf */
  header = scan_token(header, sizeof(token), token); /* Base */
  header = scan_token(header, sizeof(token), token); /* #pts */
  
  if (header) {
    return atoi(token);
  } else {
    return 0;
  }
}


/* Convert returned error code into a string. */
const char *icp_error(int code)
{
  static const char *_errmsg[] = _ICP_ERROR_TEXT;

  if (code > _ICP_LAST_CODE_ || code < _ICP_FIRST_CODE_) {
    return _errmsg[0];
  } else {
    return _errmsg[code-_ICP_FIRST_CODE_+1];
  }
}

/* Read the header portion of the icp file, returning the raw text and
   the number of points recorded in the header.  Return ICP_GOOD on
   success, or ICP_READ_ERROR if there was a problem reading the file
   or if the header text area is too small.
 */
int icp_readheader(gzFile infile, int headersize, char header[], int *pts,
		   int *linenum)
{
  char line[MAX_LINE];
  int offset,len,seen_motor_line;

  /* Return to the start of the file */
  gzrewind(infile);
  *linenum = 0;

  /* Copy lines until one after the motor/qscan line */
  seen_motor_line = 0;
  offset = 0;
  while (!gzeof(infile)) {
    /* Read the next line */
    (*linenum)++;
    if (gzgets(infile,line,sizeof(line)-1) == NULL) return ICP_READ_ERROR;
    line[sizeof(line)-1] = '\0'; /* Guarantee zero terminator */
    // printf("%d: %s",*linenum,line);

    /* Check that the second line contains the ICP signature */
    if ((*linenum) == 2) {
      if (strncmp(line,"  Filename",10)!=0) return ICP_INVALID_FORMAT;
    }

    /* Append the next line to the header */
    len = strlen(line);
    if (len+offset > headersize) return ICP_READ_ERROR;
    strcpy(header+offset, line);
    offset += len;

    /* Stop if the previous line contained " Mot:" */
    if (seen_motor_line) break;
    seen_motor_line = (strncmp(line," Mot:",5) == 0
		       || strncmp(line,"   Q (hkl scan center)",22) == 0 );
  }

  /* Peek in the header for the stored number of points */
  *pts = numpoints(header);
  // printf("number of points: %d\n",*pts);
  return ICP_GOOD;
}

/* Scan one frame of the file to compute the frame size for each point. */
int icp_framesize(gzFile infile, int *rows, int *columns, int *values)
{
  char line[MAX_LINE], token[MAX_LINE];
  const char *pline;
  int ch, ncomma=0, nsemicolon=0, nvalues=0;
  z_off_t restore_pos;

  /* Save position */
  restore_pos = gztell(infile);

  /* Get the values line */
  if (gzgets(infile, line, sizeof(line)-1) == NULL) return ICP_READ_ERROR;
  line[sizeof(line)-1] = '\0';

  /* Scan the first detector frame */
  ch = gzgetc(infile); /* Skip format column character */
  if (ch >= 0) ch = gzgetc(infile); /* Peek at first frame character */
  if (ch == ' ' || ch == '-' || ch < 0) {
    /* Empty frame, so return size 0x0 */
    *rows = *columns = 0;
  } else {
    /* Frame isn't empty so count number of commas and semicolons in frame. */
    while (ch >= 0) {
      ch = gzgetc(infile);
      if (ch == ',') ncomma++;
      else if (ch == ';') nsemicolon++;
      else if (ch == '\r') /* ignored */ ;
      else if (ch == '\n') {
	ch = gzgetc(infile); /* Skip format column character */
	if (ch >= 0) ch = gzgetc(infile);
	if (ch==' ' || ch=='-') break;
      }
    }

    /* last row does not end in semicolon so add 1
     * last column does not end in comma so add 1
     */
    *rows = nsemicolon + 1;
    *columns = (ncomma / *rows) + 1;
  }


  /* Count the number of tokens on the line */
  // printf("line=%s\n",line);
  pline = line;
  while (pline) {
    pline = scan_token(pline, sizeof(token), token);
    if (!*token || *token == '\n') break;
    nvalues++;
  }
  *values = nvalues;
  
  /* Restore position */
  gzseek(infile, restore_pos, SEEK_SET);
  return ICP_GOOD;
}
  

/* Read the next ICP frame from the file. */
int icp_readdetector(gzFile infile, int rows, int columns, Counts frame[], int *linenum)
{
  z_off_t restore_pos;
  int c = 0, r = 0, number = 0, innumber = 0, inframe = 0;
  int ch;

  /* Don't do anything if there are no data frames */
  if (rows*columns == 0) return ICP_GOOD;

  /* Store zeros in all the values, just in case the frame
     doesn't read properly */
  // memset(frame, 0, rows*columns*sizeof(*frame));

  /* First character in a line in the table is a space and the second is
     a digit.  Note that sometimes ICP drops frames, so we need to check
     if the next line is a motor line.  Usually these start with two spaces
     so we can easily check for them, but sometimes they start with a
     space and a dash if the motor values is negative.  Even worse, for
     NG7 slit scans only!, they can start with a single character and need
     to use a different algorithm: if the first line is not a singleton integer
     or a comma separated sequence, then it is not a frame.
   */
  ch = gzgetc(infile); /* Format column character */
  if (ch < 0) return (gzeof(infile)?ICP_GOOD:ICP_READ_ERROR); 
  if (ch != ' ') return ICP_FORMAT_COLUMN_ERROR;

  /* Remember where we are in case we need the NG7 slit restore */
  restore_pos = gztell(infile);

  /* Try for a quick reject based on space-space or space-dash */
  ch = gzgetc(infile); /* Peek at next character... */
  if (ch < 0) return (gzeof(infile)?ICP_GOOD:ICP_READ_ERROR); 
  gzungetc(ch,infile); /* ...and put it back  */
  if (ch == ' ' || ch == '-') return ICP_GOOD; /* Empty frame */

  for (;;) {
    ch = gzgetc(infile);
    // printf("next char is %c\n",ch);
    switch (ch) {
    case '0': case '1': case '2': case '3': case '4': 
    case '5': case '6': case '7': case '8': case '9':
      /* Append a digit to the current number */
      number = number * 10 + ch - '0';
      innumber = 1;
      break;

    case ',':
      /* Put a comma between every column */
      if (++c >= columns) {
	return ICP_COLUMN_ERROR;
      } else {
	*frame++ = number;
      }
      // printf("Next number is %d\n",number);
      number=0;
      innumber = 0;
      inframe = 1;
      break;

    case ';':
      /* Put a semicolon between every row */
      if (++c != columns) {
	return ICP_COLUMN_ERROR;
      } else if (++r == rows) {
	return ICP_ROW_ERROR;
      } else {
	*frame++ = number;
      }
      // printf("Last number is %d\n",number);
      c = number = 0;
      innumber = 0;
      inframe = 1;
      break;

    case ' ':
      /* Shouldn't have a space between values unless the last character was punctuation, or
       * if we are not in a frame */
      if (innumber) {
        if (!inframe) {
          gzseek(infile, restore_pos, SEEK_SET);
          return ICP_GOOD;
        }
        else {
          return ICP_UNEXPECTED_CHARACTER;
        }
      }

      /* Skip spaces at the end of the line; these will be after
	 a final punctuation mark.  Move past the format column
	 of the next line.
       */
      do {
	ch = gzgetc(infile);
      } while (ch == ' ');
      if (ch == '\r') ch = gzgetc(infile);
      if (ch != '\n') return ICP_UNEXPECTED_CHARACTER;
      (*linenum)++;
      ch = gzgetc(infile);
      if (ch != ' ') return ICP_FORMAT_COLUMN_ERROR;

      /* Continue with the next character. */
      break;

    case '\r':
      break;
    case '\n':

      if (innumber) {
	// printf("ending the line inside the number %d\n",number);
	/* If line ends without punctuation, then we are at the end of the frame. */
	if (++c != columns) {
	  return ICP_COLUMN_ERROR;
	} else if (++r != rows) {
	  return ICP_ROW_ERROR;
	} else {
	  *frame++ = number;
	}
	(*linenum)++;
	return ICP_GOOD;
      } else {
	/* If line ends with punctuation, then we are still in the table and the
	   next character should be a blank in the format column.
	*/
	(*linenum)++;
	ch = gzgetc(infile);
	if (ch < 0) return ICP_READ_ERROR;
	if (ch >= 0 && ch != ' ') return ICP_UNEXPECTED_CHARACTER;
      }
      break;

    case -1:
      /* Check for error */
      if (!gzeof(infile)) return ICP_READ_ERROR;

      /* EOF should be end of frame */
      if (innumber) {
	if (++c != columns) {
	  return ICP_COLUMN_ERROR;
	} else if (++r != rows) {
	  return ICP_ROW_ERROR;
	} else {
	  *frame++ = number;
	}
      }
      return ICP_GOOD;
      break;

    default:
      /* if it isn't a digit, space, comma, semicolon or newline indicates
       * we are not in a frame.
       */
      if (inframe) {
        return ICP_UNEXPECTED_CHARACTER;
      } else {
        gzseek(infile, restore_pos, SEEK_SET);
        return ICP_GOOD;
      }
    }
  }    
}

/* Read the next set of ICP columns from the file */
int icp_readmotors(gzFile infile, int nvector, Real vector[], int *linenum)
{
  char line[MAX_LINE], token[MAX_LINE];
  const char *pline;
  int nvalues = 0;

  /* Initialize to zeros */
  /* TODO: should initialize to NaNs */
  memset(vector, 0, sizeof(*vector)*nvector);

  /* Get the vector line */
  if (gzeof(infile)) return ICP_EOF;
  if (gzgets(infile, line, sizeof(line)-1) == NULL) {
#if 1 
    /* gets failed: can't distinguish read errors from EOF */
    return ICP_EOF;
#else
    /* gets failed: are we at the end of the file? */
    if (gzeof(infile)) return ICP_EOF;
    else return ICP_READ_ERROR;
#endif
  }
  line[sizeof(line)-1]='\0';
  (*linenum)++;

  /* Tokenize and convert to numbers. */
  pline = line;
  while (pline) {
    pline = scan_token(pline, sizeof(token), token);
    if (!*token || *token == '\n') break;
    if (nvalues >= nvector) return ICP_VECTOR_ERROR;
    vector[nvalues++] = atof(token);
    // printf("linenum:%d token %d:%s value:%g\n", *linenum, nvalues, token,  atof(token));
  }
  if (nvalues < nvector) return ICP_VECTOR_ERROR;

  return ICP_GOOD;
}


#ifdef TEST
int main(int argc, char *argv[])
{
  char header[10000];
  int line, np, nr, nc, nv, framenumber;
  Real *columns;
  Counts *frame;
  int status, i;

  /* Argument processing */
  if (argc != 2) {
    printf("usage: icpread file\n");
    return 1;
  }

  /* Open the file */
  gzFile f = icp_open(argv[1]);
  if (f == NULL) {
    perror(argv[1]);
    return 1;
  }

  /* Read the header */
  status = icp_readheader(f,sizeof(header),header,&np,&line);
  if (status != ICP_GOOD) {
    printf("error line %d: %s\n",line,icp_error(status));
    return 1;
  }
  printf("<Header pts=\"%d\">%s</Header>\n",np,header);

  /* Determine the frame size */
  status = icp_framesize(f,&nr,&nc,&nv);
  //nr = 1; nc = 256; nv = 3;
  if (status != ICP_GOOD) {
    printf("could not determine frame size\n");
    return 1;
  }
  printf("<columns>%d</columns>\n<detector>%dx%d</detector>\n",nv,nr,nc);

  /* Allocate space for data */
  frame = (Counts*)malloc(nr*nc*sizeof(*frame));
  columns = (Real*)malloc(nv*sizeof(*columns));
  if (frame==NULL || columns==NULL) {
    printf("Frame size is too large!\n");
    return 1;
  }

  /* Read the frames */
  framenumber = 1;
  for(;;) {
    status = icp_readmotors(f, nv, columns, &line);
    if (status < 0) break;
    for (i=0; i < nv; i++) printf("%g ",columns[i]); printf("\n");
    status = icp_readdetector(f, nr, nc, frame, &line);
    // for (i = 0; i < nc; i++) printf(ICP_COUNT_FORMAT " ",frame[i]); printf("\n");
    if (status < 0) break;
    framenumber++;
  }
  icp_close(f);

  /* Print results */
  if (status == ICP_EOF) {
    printf("Success! %d frames read from %d lines\n", framenumber, line-1);
    printf("Final frame:\n");
    for (i = 0; i < nc; i++) printf(ICP_COUNT_FORMAT " ",frame[i]);
    printf("\n");
    return 0;
  } else {
    printf("Error line %d: %s\n",line,icp_error(status));
    return 1;
  }
}
#endif
