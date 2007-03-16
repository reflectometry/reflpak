/* This program is public domain. */

/* Routines to read ICP and compressed ICP formats with 0, 1 and 2D detectors.
 *
 * file = icp_open(name)
 *    Open the ICP file; may be compressed by gzip.
 *
 * status = icp_readheader(file,header_size,header,&npts,&line)
 *    Read the header string and determine the number of points.  Sets the
 *    line number to the next line after the header.
 *
 * status = icp_framesize(file,&rows,&columns,&nvalues)
 *    Determine the amount of space to allocate for each frame.  The detector
 *    frame is of size "rows x columns" and type "Counts".  There are 
 *    "nvalues" motor values stored for each point.  This should be called
 *    directly after icp_readheader().
 *
 * status = icp_readmotors(file,nvalues,values,&line)
 *    Read the next motor vector.  Vector values are of type "Real[]".
 *    Updates the line number with the new position.
 *
 * status = icp_readdetector(file,rows,columns,frame,&line)
 *    Read the next detector frame.  Frame is of type "Counts[]", and must
 *    be big enough to hold rows x columns count values.  Updates the line
 *    number with the new position.
 * 
 * icp_close(file)
 *    Close the file.
 *
 * msg = icp_error(status)
 *    Convert a status code to an error string.
 *
 * Error code defines
 *   success:      status == ICP_GOOD
 *   end of file:  status == ICP_EOF
 *   failure:      (status < 0 && status != ICP_EOF)
 *
 * Specific messages can be retrieved using 
 *   icp_error(status)
 *
 *
 *
 * TODO: consider building an index of frame locations so individual frames
 * can be randomly accessed.  For now load in the whole file.
 */
#ifndef _ICPREAD_H
#define _ICPREAD_H

#ifdef _cplusplus
# include <cstdio>
# include <cstdint>
# define EXPORT extern "C"
#else
# include <stdio.h>
# include <stdint.h>
# define EXPORT extern
#endif

/* We are reading the data into the following types.
 * Counts is for individual detector frames.
 * Real is for ICP data columns.
 */
#ifdef USE_INTCOUNTS
# define ICP_COUNT_FORMAT "%d"
  typedef uint32_t Counts;
#else
# define ICP_COUNT_FORMAT "%g"
# ifdef USE_DOUBLE
  typedef double Counts;
# else
  typedef float Counts;
# endif
#endif

#ifdef USE_DOUBLE
  typedef double Real;
#else
  typedef float Real;
#endif

#define _ICP_FIRST_CODE_ -9
#define ICP_MEMORY_ERROR -9
#define ICP_INVALID_FORMAT -8
#define ICP_FORMAT_COLUMN_ERROR -7
#define ICP_UNEXPECTED_CHARACTER -6
#define ICP_READ_ERROR -5
#define ICP_ROW_ERROR -4
#define ICP_COLUMN_ERROR -3
#define ICP_VECTOR_ERROR -2
#define ICP_EOF -1
#define ICP_GOOD 0
#define ICP_SKIP 1
#define _ICP_LAST_CODE_ 1

#define _ICP_ERROR_TEXT { \
  "unknown error", \
  "out of memory", \
  "not an ICP file", \
  "line should start with a space", \
  "unexpected character", \
  "error reading file", \
  "incorrect number of rows in frame", \
  "incorrect number of columns in frame", \
  "incorrect number of fields", \
  "end of file", \
  "good", \
  "skip item", \
}



EXPORT FILE *icp_open(const char name[]);
EXPORT void icp_close(FILE *f);
EXPORT const char *icp_error(int code);
EXPORT int icp_readheader(FILE *infile, int n, char header[], int *pts, int *linenum);
EXPORT int icp_framesize(FILE *infile, int *rows, int *columns, int *values);
EXPORT int icp_readmotors(FILE *infile, int n, Real vector[], int *linenum);
EXPORT int icp_readdetector(FILE *infile, int rows, int columns, Counts frame[], int *linenum);


#endif /* _ICPREAD_H */
