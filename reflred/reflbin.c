/* public domain 

jazz:
  LIBZ="-L/data/people/pkienzle/packages/zlib-1.4.4 -lz
  cc -O2 reflbin.c -o ~/bin/reflbin -lgen -lm $(LIBZ)

linux, macosx:
  gcc -Wall -O2 reflbin.c -o ~/bin/reflbin -lm -lz

MinGW:
  LIBZ="-L/usr/local/lib -lz"
  gcc -Wall -O2 -I/usr/local/include reflbin.c -o reflbin -lm $(LIBZ)

*/

/* Set the following to true to save bins at edges which don't cover 
 * the full range of the width and height accumulators.
 */
#define SAVE_PARTIAL 0 

#include <assert.h>
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <zlib.h>
#define MAX_LINE 2048
#define MAX_BIN 2048
#define ICP 1
#define VTK 2

#if defined(WIN32)
#define NEED_BASENAME
#else
#include <libgen.h>
#endif

#ifdef NEED_BASENAME
char *basename(char *file)
{
  int i = strlen(file);
  while (i--) { if (file[i]=='/' || file[i]=='\\') break; }
  return file+i+1;
}
#endif

/* Per frame data */
typedef unsigned int mxtype;
mxtype matrix[MAX_BIN*MAX_BIN];
int frame_r, frame_w, frame_h;
int rows_accumulated;

/* Per-file data */
unsigned int total_counts, recorded_counts, ignored_counts;
int nnz, rows, columns, points;
int warn_dims;
FILE *infile, *outfile;
char line[MAX_LINE];

/* options */
int do_transpose;
int width, height, output;
int xstart, xstop, ystart, ystop;

void fail(char *msg)
{
  fprintf(stderr,"%s\n",msg);
  exit(1);
}

void getline(char *line,int maxline)
{
  if (gzgets(infile,line,maxline) == NULL) {
    if (gzeof(infile)) { line[0] = '\0'; return; }
    perror("reflbin");
    exit(1); /* Read failed unexpectedly */
  }
}

int utoa(unsigned int u, char *a)
{
  int l = 0;
  /* convert number to digits in reverse order */
  while (u) {
    a[l++] = '0'+u%10;
    u = u/10;
  }
  if (l == 0) {
    /* number is 0 so no digits */
    a[l++] = '0';
  } else if (l > 1) {
    /* number has more than two digits, so reverse it */
    int i;
    for (i=l/2; i>0; i--) {
      char c = a[l-i];
      a[l-i] = a[i-1];
      a[i-1] = c;
    }
  }
  return l;
}

void icp_save(FILE *out, unsigned int v[], int n, int continuation)
{
  char line[100];
  unsigned int num;
  int c, l;
  c = 1;
  line[0] = ' ';
  while (1) {
    num = *v++;
    l = utoa(num,line+c);
    c += l;
    line[c++] = ',';
    if (--n==0) break;
    if (c > 78) {
      line[c-l-1] = '\n';
      line[c-l] = '\0';
      fputs(line,out);
      utoa(num,line+1);
      line[l+1] = ',';
      c = l+2;
    }
  }

  if (continuation) {
    /* Need a comma at the end of the set 
     * since there is another set coming.
     */
    if (c > 78) {
      line[c-l-1] = '\n';
      line[c-l] = '\0';
      fputs(line,out);
      utoa(num,line+1);
      line[l+1]=',';
      c = l+2;
    } 
    line[c] = '\n';
    line[c+1] = '\0';
  } else {
    /* No comma at the end of the set
     * since we are done with this data point.
     */
    if (c > 79) {
      line[c-l-1] = '\n';
      line[c-l] = '\0';
      fputs(line,out);
      utoa(num,line+1);
      c = l+2;
    } 
    line[c-1] = '\n';
    line[c] = '\0';
  }
  fputs(line,out);
}

void vtk_save(FILE *out, unsigned int v[], int n, int continuation)
{
  char line[1024];
  int c;
  c = 0;
  while (1) {
    int l;
    /* Logarithmic compression of 32 bits into 16: 2955 > 2^16/log(2^32) */
    unsigned int num = (unsigned int)(floor(2955.0*log((double)(*v+++1))+0.5));
    l = utoa(num,line+c);
    c += l;
    line[c++] = ' ';
    if (--n == 0) break;
    if (c > 1000) {
      line[c-1]='\n';
      line[c]='\0';
      fputs(line,out);
      c = 0;
    }
  }
  line[c-1] = '\n';
  line[c] = '\0';
  fputs(line,out);
}

/* From Robin Becker <robin@jessikat.fsnet.co.uk>
 * Posted to sci.math.num-analysis on Dec 6 2003, 2:24 pm
 * He does not remember who is the original author.
 */
void mx_transpose(int n, int m, mxtype *a, mxtype *b)
{
  int size = m*n;
  if(b!=a){ /* out of place transpose */
    mxtype *bmn, *aij, *anm;
    bmn = b + size; /*b+n*m*/
    anm = a + size;
    while(b<bmn) for(aij=a++;aij<anm; aij+=n ) *b++ = *aij;
  }
  else if(n!=1 && m!=1){ /* in place transpose */
    /* PAK: use (n!=1&&m!=1) instead of (size>3) to avoid vector transpose */
    int i,row,column,current;
    for(i=1, size -= 2;i<size;i++){
      current = i;
      do {
	/*current = row+n*column*/
	column = current/m;
	row = current%m;
	current = n*row + column;
      } while(current < i);

      if (current>i) {
	mxtype temp = a[i];
	a[i] = a[current];
	a[current] = temp;
      }
    }
  }
}

void mx_print(int n, int m, mxtype *v)
{
  int i, j;
  for (i=0; i < n; i++) {
    for (j=0; j<m; j++) printf("%d ",v[j]); 
    printf("\n");
    v += m;
  }
}

void clear_row()
{
  mxtype *row_data = matrix + frame_h*frame_w;
  int i;
  for (i=0; i < MAX_BIN; i++) row_data[i] = 0;
}

void next_row()
{
  rows_accumulated = 0;
  frame_h++;
}

void next_frame()
{
  frame_r = frame_w = frame_h = 0;
  rows_accumulated = 0;
  clear_row();
}

void write_frame()
{
  mxtype *v;
  int i;

#if SAVE_PARTIAL
  if (rows_accumulated != 0) frame_h++; /* Keep partly full row sum */
#else
  if (frame_h == 0 && rows_accumulated != 0) frame_h++; /* Collapse dimension */
#endif

  /* Check for consistent number of rows in frame */
  if (rows == 0) {
    rows = frame_h;
  } else if (frame_h == 0) {
    /* ICP dropped the frame so fill with zeros */
    for (frame_h = 0; frame_h < rows; frame_h++) clear_row();
    // printf("recover dropped frame?\n");
  } else if (rows != frame_h) {
    if (warn_dims) fprintf(stderr,"inconsistent number of rows\n");
    warn_dims = 0;
    while (frame_h < rows) { clear_row(); frame_h++; }
    frame_h = rows; /* in case it was bigger */
  }
#ifdef DEBUG
  printf("=========== %d x %d \n", frame_w, frame_h);
  mx_print(frame_h,frame_w,matrix);
  printf("===========\n");
#endif

  /* Transpose the matrix if necessary */
  if (do_transpose) {
    mx_transpose(frame_h,frame_w,matrix,matrix);
    i = frame_w; frame_w = frame_h; frame_h = i;
  }

  /* Output the rows one by one */
  v = matrix;
  for (i=0; i < frame_h-1; i++) {
    switch(output) {
    case VTK: vtk_save(outfile,v,frame_w,1); break;
    case ICP: icp_save(outfile,v,frame_w,1); break;
    }
    v += frame_w;
  }
  switch (output) {
  case VTK: vtk_save(outfile,v,frame_w,0); break;
  case ICP: icp_save(outfile,v,frame_w,0); break;
  }
}

/* Save the next row of the frame. */
/* Assumes that v is initialized to 0 beyond last column */
void save_row(mxtype *v, int n)
{
  int i, w;

  // printf("; columns=%d, n=%d\n", columns, n);
  /* Check the number of columns in the datafile. */
  if (columns == 0) { 
    columns = n; 
  } else if (warn_dims && n != columns) {
    warn_dims = 0;
    fprintf(stderr, "ignoring inconsistent number of columns\n");
    n = columns; /* Assume remainder of v is zero */
  }

  /* Add the next line of the frame to the current row */
  if (frame_r >= ystart && frame_r <= ystop) {
    mxtype *row_data = matrix + frame_h*frame_w;
    int bin;
    bin = w = 0;
    for (i = 0; i < xstart && i < n; i++) ignored_counts += v[i];
    for (i = xstart; i < n && i <= xstop; i++) {
      row_data[bin] += v[i];
      recorded_counts += v[i];
      if (++w == width) { bin++; w=0; }
    }
    for (i = xstop+1; i < n; i++) ignored_counts += v[i];
#if SAVE_PARTIAL
    if (w != 0) bin++; /* Bin only partly full --- save it anyway */
#else
    if (bin == 0 && w != 0) bin++; /* Collapse dimension */
#endif
    frame_w = bin; /* Constant since number of input columns is fixed. */

    /* Move to next row if at the end of vertical accumulation. */
    if (++rows_accumulated == height) next_row();
  } else {
    for (i = 0; i < n; i++) ignored_counts += v[i];
  }
  frame_r++;
}

void
accumulate_bins()
{
  mxtype bins[MAX_BIN+1];
  mxtype s;
  int b; /* bin number */
  int i; /* character number in line */
  int have_number; /* whether we are building a number */

#define ACCUMULATE do {				\
    /* printf("%d ",s);	*/			\
    have_number = 0;				\
    bins[b++] = s;				\
    total_counts += s;				\
    nnz += (s!=0);				\
  } while (0)

  for (b=0; b < MAX_BIN+1; b++) bins[b] = 0.;

  getline(line,MAX_LINE);
  have_number = 0;
  b = i = 0;
  while (1) {
    const char c = line[i];
    // printf("<s=%d c='%c'>",s,c);
    if (isdigit(c)) {
      if (have_number) {
	s = s*10 + c - '0';
      } else {
	have_number = 1;
	s = c - '0';
      }
      // printf("<digit %c s=%d>",c,s);
      i++;
    } else if (c==',' || c==';') {
      assert(have_number == 1);
      ACCUMULATE;
      if (c == ';') {
	save_row(bins, b);
	while (b>0) bins[--b] = 0;
      }
      i++;
    } else if (c=='\n' || c=='\r') {
      getline(line,MAX_LINE);
      if (have_number) { 
	/* End of frame if line ends in a number without punctuation */
	ACCUMULATE;
	save_row(bins, b);
	return;
      }
      if (gzeof(infile)) return;
      i = 0;
    } else if (c == '\0') {
      /* Maybe line was too long or maybe we are at the end of the file */
      getline(line,MAX_LINE);
      if (gzeof(infile)) {
	/* If at the end of the file, finish off current frame */
	if (have_number) {
	  ACCUMULATE;
	  save_row(bins,b);
	}
	return;
      }
      i = 0;
    } else if (isspace(c)) {
      /* If at a space between numbers ... must in be a new point */
      /* Note that we don't save it, since the end of */
      /* the matrix was already saved by the '\n'.  The only */
      /* way we can get here is if we have an empty frame. */ 
      i++;
      if (have_number) return;
    } else {
      /* Some kind of floating point character ... must be a new point */
      return;
    }
  }
}

void integrate_psd()
{
  /* Copy lines until Mot: line */
  while (!gzeof(infile)) {
    getline(line,MAX_LINE);
    if (output == ICP) fputs(line,outfile);
    if (strncmp(line," Mot:",5) == 0) break;
  }

  /* Copy column header line */
  getline(line,MAX_LINE);
  if (output == ICP) fputs(line,outfile);

  /* Process data */
  getline(line,MAX_LINE);
  if (!gzeof(infile)) {
    points++;
    if (output == ICP) fputs(line,outfile);
    while (!gzeof(infile)) {
      /* process really ugly 2-D repr */
      next_frame();
      accumulate_bins();
      write_frame();
      
      if (line[0] != '\0') {
	points++;
	if (output == ICP) fputs(line,outfile);
      }
    }
  }

}

void process_file(char *file)
{
  char ofile[200], *base, *ext;
  int len, gz;

  warn_dims = 1;
  rows = columns = points = 0;
  recorded_counts = ignored_counts = 0;

  infile = gzopen(file,"rb");
  if (infile == NULL) {
    perror("reflbin");
    return;
  }

  base = basename(file);
  len = strlen(base);
  gz =  (len > 3 && !strcmp(base+len-3,".gz"));
  if (len+6 > sizeof(ofile)) {
    fprintf(stderr,"file name is too long %s\n",file);
    gzclose(infile);
    return;
  }

  switch (output) {
  case ICP:
    strcat(strcpy(ofile,"I"),base);
    if (gz) ofile[len-2]='\0'; /* Chop .gz extension, +1 for leading 'I' */
    outfile = fopen(ofile,"wb");
    integrate_psd();
    break;
  case VTK:
    strcpy(ofile,base);
    if (gz) ofile[len-3]='\0'; /* Chop .gz extension. */
    ext = strrchr(ofile,'.');
    if (ext != NULL) strcpy(ext,".vtk");
    else strcat(ofile,".vtk");
    outfile = fopen(ofile,"wb");
    
    /* Write VTK header and remember where to plug in the sizes */
    {
      size_t dim_pos, numpoints_pos, space_pos;

      fprintf(outfile,"# vtk DataFile Version 2.0\n");
      fprintf(outfile,"Data from %s\n", file);
      fprintf(outfile,"ASCII\n");
      fprintf(outfile,"DATASET STRUCTURED_POINTS\n");
      fprintf(outfile,"DIMENSIONS ");
      dim_pos = ftell(outfile);
      fprintf(outfile,"                                        \n");
      fprintf(outfile,"ORIGIN 0 0 0\n");
      fprintf(outfile,"SPACING ");
      space_pos = ftell(outfile);
      fprintf(outfile,"1 1 1                                   \n");
      fprintf(outfile,"POINT_DATA ");
      numpoints_pos = ftell(outfile);
      fprintf(outfile,"                    \n");
      fprintf(outfile,"SCALARS PSD unsigned_short 1\n");
      fprintf(outfile,"LOOKUP_TABLE default\n");
      integrate_psd();
      fseek(outfile,dim_pos,SEEK_SET);
      fprintf(outfile,"%d %d %d",frame_w,frame_h,points);
#if 0
      fseek(outfile,space_pos,SEEK_SET);
      fprintf(outfile,"%f %f %f",1./frame_w,2./frame_h,4./points);
#endif
      fseek(outfile,numpoints_pos,SEEK_SET);
      fprintf(outfile,"%d",frame_w*frame_h*points);
    }
  }

  fprintf(stderr,"%s %d x %d x %d\n", ofile, frame_h, frame_w, points);
  fprintf(stderr,"number of nonzero bins = %d\n", nnz);
  fprintf(stderr,"recorded counts = %d\n", recorded_counts);
  fprintf(stderr,"ignored counts = %d\n", ignored_counts);
  if (recorded_counts + ignored_counts != total_counts) {
    fprintf(stderr,"!!!recorded+ignored != %d\n", total_counts);
  }

  gzclose(infile);
  fclose(outfile);  
}

/* Convert 1-origin ##-## string to 0-origin start-stop values */
void range(const char *v, int *start, int *stop)
{
  if (sscanf(v,"%d-%d",start,stop) != 2) {
    fprintf(stderr," -x and -y need ###-### pixel range\n");
    exit(1);
  }
  (*start)--;
  (*stop)--;
}

int main(int argc, char *argv[])
{
  int i;

  height=1000000;
  width=1; 
  xstart=ystart=0;
  xstop=ystop=1000000;
  output=ICP;

  if (argc <= 1) {
    fprintf(stderr,"usage: %s [-vtk|-icp] [-w##] [-h##] f1 f2 ...\n\n",argv[0]);
    fprintf(stderr," -w##  bin width (default 1)\n");
    fprintf(stderr," -h##  bin height (default 1000000)\n");
    fprintf(stderr," -x#LO-#HI pixel range in x (1-origin)\n");
    fprintf(stderr," -y#LO-#HI pixel range in y (1-origin)\n");
    fprintf(stderr," -vtk  use VTK format for output\n");
    fprintf(stderr," -icp  use ICP format for output\n");
    fprintf(stderr,"\nIf output is ICP, the outfile is Ixxx.cg1 in the current directory.\n");
    fprintf(stderr,"If output is VTK, the outfile is xxx.vtk in the current directory.\n");
    fprintf(stderr,"To get the bare data, use -vtk and strip the header, using e.g.,\n");
    fprintf(stderr,"    tail +11 f1.vtk > f1.raw\n");
    fprintf(stderr,"Compressed files (.gz extension) are handled directly.\n");
  }

  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-') {
      switch (argv[i][1]) {
      case 'w': width = atoi(argv[i]+2); break;
      case 'h': height = atoi(argv[i]+2); break;
      case 'x': range(argv[i]+2,&xstart,&xstop); break;
      case 'y': range(argv[i]+2,&ystart,&ystop); break;
      case 'v': output = VTK; break;
      case 'i': output = ICP; break;
      default: fprintf(stderr,"unknown option %s\n",argv[i]); exit(1);
      }
    } else {
      do_transpose=(output==ICP);
      process_file(argv[i]);
    }
  }
  exit(0);
  return 0;
}
