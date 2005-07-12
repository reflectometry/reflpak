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
#define COUNT_NNZ
#undef ONE_EQUALS_ZERO

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

#ifdef COUNT_NNZ
int nnz = 0;
#endif
int do_transpose;
int width, height, output;
#ifdef USE_RANGE
int xstart, xstop, ystart, ystop;
#endif
int rows, columns, points;
unsigned int bins[MAX_BIN];
char line[MAX_LINE];
FILE *infile, *outfile;

void fail(char *msg)
{
  fprintf(stderr,"%s\n",msg);
  exit(1);
}

void getline(char *line,int maxline)
{
  if (gzgets(infile,line,maxline) == NULL) {
    if (gzeof(infile)) { line[0] = '\0'; return; }
    perror("psdareaint");
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
typedef unsigned int mxtype;
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
    /* PAK: use (n!=1&&m!=1) instead of (size!=3) to avoid vector transpose */
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


mxtype matrix[MAX_BIN*MAX_BIN];
void save_row(unsigned int *v, int n, int continuation)
{
  if (do_transpose) {
    static int t=0, w=0, h=0;
    w = n; h++;
    memcpy(matrix+t,v,n*sizeof(*v));
    t += n;
    if (!continuation) {
      int i = 0;
      mx_transpose(w,h,matrix,matrix);
      n = h;
      for (v=matrix, i=0; i < w-1; i++, v+=h) {
	switch(output) {
	case VTK: vtk_save(outfile,v,n,1); break;
	case ICP: icp_save(outfile,v,n,1); break;
	}
      }
      switch (output) {
      case VTK: vtk_save(outfile,v,n,0); break;
      case ICP: icp_save(outfile,v,n,0); break;
      }
      t = w = h = 0;
    }
  } else {
    switch (output) {
    case VTK: vtk_save(outfile,v,n,continuation); break;
    case ICP: icp_save(outfile,v,n,continuation); break;
    }
  }
}

void
accumulate_bins()
{
  int b; /* bin number */
  int i; /* character number */
  int n; /* num bins */
  unsigned int s; /* current bin value */
  int r; /* row number */
  int v; /* position in vertical block */
  int h; /* position in horizontal block */
  int have_number;

#ifdef ONE_EQUALS_ZERO
# ifdef COUNT_NNZ
#  define PROCESS_S do { if (s>1) { bins[b]+=s; nnz++; } } while (0)
# else
#  define PROCESS_S do { if (s>1) { bins[b]+=s; } while (0)
# endif
#else
# ifdef COUNT_NNZ
#  define PROCESS_S do { bins[b]+=s; if (s) nnz++; } while (0)
# else
#  define PROCESS_S do { bins[b]+=s; } while (0)
# endif
#endif

  for (b=0; b < MAX_BIN; b++) bins[b] = 0.;

  getline(line,MAX_LINE);
  r = b = i = n = s = 0;
  have_number = 0;

  v = height; h = width;
  while (1) {
    if (isdigit(line[i])) {
      /* Part of a number---add it */
      s = s*10 + line[i]-'0';
      have_number = 1;
      i++;
    } else if (line[i] == ',') {
      /* Bin: accumulate it */
      PROCESS_S;
      have_number = s = 0;
      if (--h == 0) { 
	h = width; 
	if (++b >= MAX_BIN) fail("too many bins");
      }
      i++;
    } else if (line[i] == ';') {
      /* Last bin: go back to first bin, remembering how many there are */
      PROCESS_S;
      have_number = s = 0;
      b++;
      if (n == 0) n = b;
      else if (n != b) fail("uneven rows in the middle");
      if (--v == 0) {
	save_row(bins,n,1);
	for (b=0; b < n; b++) bins[b] = 0;
	v = height;
	r++;
      }
      b = 0;
      h = width;
      i++;
    } else if (line[i] == '\0') {
      /* line was too long: process it part by part */
      getline(line,MAX_LINE);
      if (gzeof(infile)) { line[0]='\0'; break; }
      i = 0;
    } else if (line[i] == '\r' || line[i] == '\n') {
      /* end of line: get the next line */
      getline(line,MAX_LINE);
      if (gzeof(infile)) { line[0]='\0'; break; }
      i = 0;
    } else if (isspace(line[i])) {
      /* Space between numbers ... must be a new point */
      /* Note that we don't save it, since the end of */
      /* the matrix was already saved by the \n */ 
      if (have_number) { have_number = 0; break; }
      i++;
    } else {
      /* Some kind of floating point character ... must be a new point */
      break;
    }
  }

  /* Finalize: if we have an uncounted bin, count it */
  if (have_number) PROCESS_S;
  b++; r++;
  if (n == 0) n = b;
  else if (n != b) fail("uneven rows");

  /* ICP error --- sometimes a histogram is missing */
  if (n == 0) {
    fprintf(stderr,"Empty histogram---filling with zeros\n");
    n = columns;
    r = rows;
  }

  /* Write data */
  save_row(bins,n,0);

  /* Make sure histogram sizes are consistent. */
  if (rows == 0) rows = r;
  else if (rows != r) fail("inconsistent rows between blocks");
  if (columns == 0) columns = n;
  else if (columns != n) fail("inconsistent columns between blocks");
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
  rows = columns = points = 0;
  getline(line,MAX_LINE);
  if (!gzeof(infile)) {
    points++;
    if (output == ICP) fputs(line,outfile);
    while (!gzeof(infile)) {
      /* process really ugly 2-D repr */
      accumulate_bins();
      
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

  infile = gzopen(file,"rb");
  if (infile == NULL) {
    perror("psdarea");
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
      fprintf(outfile,"%d %d %d",columns,rows,points);
#if 0
      fseek(outfile,space_pos,SEEK_SET);
      fprintf(outfile,"%f %f %f",1./columns,2./rows,4./points);
#endif
      fseek(outfile,numpoints_pos,SEEK_SET);
      fprintf(outfile,"%d",columns*rows*points);
    }
  }

  fprintf(stderr,"%s %d x %d x %d\n", ofile, columns, rows, points);
#ifdef COUNT_NNZ
  fprintf(stderr,"nnz = %d\n", nnz);
  nnz = 0;
#endif

  gzclose(infile);
  fclose(outfile);  
}

void range(const char *v, int *start, int *stop)
{
  if (strchr(v,'-')) sscanf(v,"%d-%d",start,stop);
  else *start = atoi(v);
  printf("for v=%s, start=%d, stop=%d\n",v,*start,*stop);  
}

int main(int argc, char *argv[])
{
  int i;

  height=1000000;
  width=1; 
  output=ICP;

  if (argc <= 1) {
    fprintf(stderr,"usage: %s [-vtk|-icp] [-w##] [-h##] f1 f2 ...\n\n",argv[0]);
    fprintf(stderr," -w##  accumulate across ## Qx bins (default 1)\n");
    fprintf(stderr," -h##  accumulate across ## Qy bins (default 1000000)\n");
#ifdef USE_RANGE
    /* Hide this feature until it is implemented */
    fprintf(stderr," -x#LO-#HI integrate Qx bins between #LO and #HI (1-origin)\n");
    fprintf(stderr," -y#LO-#HI integrate Qy bins between #LO and #HI (1-origin)\n");
#endif
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
#ifdef USE_RANGE
      case 'x': range(argv[i]+2,&xstart,&xstop); break;
      case 'y': range(argv[i]+2,&ystart,&ystop); break;
#endif
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
