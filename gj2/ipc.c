#include <stdio.h>
#include <string.h>
#include "ipc.h"
#include "cdata.h"
#include "clista.h"
#include "genmem.h"
#include "glayi.h"
#include "glayd.h"
#include "mglayd.h"
#include "glayin.h"
#include "glayim.h"
#include "dlconstrain.h"
#include "constraincpp.h"
#include "queryString.h"
#include "extres.h"
#include "genderiv4.h"
#include "loadData.h"
#include "ngenlayers.h"
#include "mgenlayers.h"
#include "genlayers.h"
#include "gmagpro4.h"
#include "caps.h"
#include "genpsc.h"
#include "genpsi.h"
#include "genpsr.h"
#include "genpsl.h"
/* genpsd.h must be last!! */
#include "genpsd.h"

void sendpars()
{
  FILE *fp;
  double t;
  int i;

  fp = fopen("mltmp.pars","wb");

  t = nlayer+1; fwrite(&t, sizeof(t), 1, fp);

  fwrite(&bmintns, sizeof(bmintns), 1, fp);
  fwrite(&bki, sizeof(bki), 1, fp);
  fwrite(&thedel, sizeof(thedel), 1, fp);
  fwrite(&lamdel, sizeof(lamdel), 1, fp);
  fwrite(&lambda, sizeof(lambda), 1, fp);

  t = vacThick(rough,zint,nrough);
  fwrite(&t, sizeof(t), 1, fp);
  /* t = vacThick(mrough,zint,nrough); */
  /* fwrite(&t, sizeof(t), 1, fp); */
  t = nrough; fwrite(&t, sizeof(t), 1, fp);

  for (i=0; i <= nlayer; i++) {
    fwrite(qcsq+i, sizeof(double), 1, fp);
    fwrite(mu+i, sizeof(double), 1, fp);
    fwrite(rough+i, sizeof(double), 1, fp);
    fwrite(d+i, sizeof(double), 1, fp);
    fwrite(qcmsq+i, sizeof(double), 1, fp);
    fwrite(the+i, sizeof(double), 1, fp);
    fwrite(mrough+i, sizeof(double), 1, fp);
    fwrite(dm+i, sizeof(double), 1, fp);
  }
  fclose(fp);

  printf("\nparameters written\n"); fflush(stdout);
}

void recvpars()
{
#if 0
  untested and unused
  FILE *fp;
  double t;
  int i;

  fp = fopen("mltmp.pars","rb");
  fread(&t, sizeof(t), 1, fp);  nlayer = (int)rint(t);
  fread(&bmintns, sizeof(bmintns), 1, fp);
  fread(&bki, sizeof(bki), 1, fp);
  fread(&thedel, sizeof(thedel), 1, fp);
  fread(&lamdel, sizeof(lamdel), 1, fp);
  fread(&lambda, sizeof(lambda), 1, fp);
  fread(&t, sizeof(t), 1, fp); /* ignore roughwidth */

  for (i=0; i <= nlayer; i++) {
    fread(qcsq+i, sizeof(double), 1, fp);
    fread(mu+i, sizeof(double), 1, fp);
    fread(rough+i, sizeof(double), 1, fp);
    fread(d+i, sizeof(double), 1, fp);
    fread(qmsq+i, sizeof(double), 1, fp);
    fread(the+i, sizeof(double), 1, fp);
    fread(mrough+i, sizeof(double), 1, fp);
    fread(dm+i, sizeof(double), 1, fp);
  }

  fclose(fp);

  printf("\nparameters read\n"); fflush(stdout);
#endif
}

void sendprofile()
{
  register int j;
  double thick;
  FILE *fd, *fmu, *fqcsq;
  FILE *fthe, *fqmsq;

  fd = fopen("mltmp.d", "wb");
  fmu = fopen("mltmp.mu", "wb");
  fqcsq = fopen("mltmp.qcsq", "wb");
  fthe = fopen("mltmp.theta", "wb");
  fqmsq = fopen("mltmp.mqcsq", "wb");
  thick = -vacThick(rough,zint,nrough);
  for (j = 0; j < nglay; j++) {
    fwrite(&thick, sizeof(thick), 1, fd);
    fwrite(gmu+j, sizeof(gmu[j]), 1, fmu);
    fwrite(gqcsq+j, sizeof(gqcsq[j]), 1, fqcsq);
    fwrite(gthe+j, sizeof(gthe[j]), 1, fthe);
    fwrite(gqmsq+j, sizeof(gqmsq[j]), 1, fqmsq);
    thick += gd[j];
    fwrite(&thick, sizeof(thick), 1, fd);
    fwrite(gmu+j, sizeof(gmu[j]), 1, fmu);
    fwrite(gqcsq+j, sizeof(gqcsq[j]), 1, fqcsq);
    fwrite(gthe+j, sizeof(gthe[j]), 1, fthe);
    fwrite(gqmsq+j, sizeof(gqmsq[j]), 1, fqmsq);
  }
  fclose(fd);
  fclose(fmu);
  fclose(fqcsq);
  fclose(fthe);
  fclose(fqmsq);
  printf("\nprofile written\n"); fflush(stdout);
}

/* XXX FIXME XXX - use this function in calcChiSq() */
/* Compute chisq for each slice, and return the overall chisq.
 * Assumes loadData has been called to load the data
 *   xdat,ydat,srvar contains the data+error
 *   xspin[i] is true for each defined section
 *   npntsx[i] is the number of points in each defined section
 *   nqx[i] lists the offsets of the q points in generated reflectivity 
 *      curve which correspond to the q points in the data
 * Assumes extend and genderiv4 have been called to generate a 
 * reflectivity curve for each defined section
 *   q4x contains the generated q points
 *   y4x contains the corresponding reflectivity value
 *   n4x is the number of points per slice
 * Returns chisq
 * If slice is not null, it must reference an array of 4 doubles, one
 * for each slice.  On return, the chisq value for each defined slice
 * will be stored in the corresponding array element.
 */
double onlyCalcChiSq(double *slice)
{
  double chisq;
  int data_offset, offset, i;
  
  chisq = 0.;
  data_offset = 0;
  offset = 0;
  for (i = 0; i < 4; i++) {
    if (xspin[i]) {
      double slice_chisq = 0.0;
      int n;
      for (n = 0; n < npntsx[i]; n++) {
	register double chi;
	if (srvar[data_offset+n] < 1.e-10) srvar[data_offset+n] = 1.e-10;
	chi = (ydat[data_offset+n] - y4x[offset+nqx[i][n]]) 
	  / srvar[data_offset+n];
	slice_chisq += chi*chi;
      }
      data_offset += n;
      offset += n4x;
      chisq += slice_chisq;
      if (slice) slice[i] = slice_chisq/(double)(n-mfit);
    }

  }
  chisq = chisq / (double) (data_offset-mfit);
  return chisq;
}

void sendreflect(void)
{
  FILE *file;
  int i, idx, offset;
  char name[] = "mltmp.r_";
  double chisq, chisq_slice[4];

  file = fopen("mltmp.q","wb");
  fwrite(q4x, sizeof(q4x[0]), n4x, file);
  fclose(file);

  chisq = onlyCalcChiSq(chisq_slice);
  idx = strlen(name)-1;
  offset = 0;
  for (i=0; i < 4; i++) {
    name[idx]='a'+i; file = fopen(name,"wb");
    if (xspin[i]) {
      fwrite(y4x+offset,sizeof(y4x[0]), n4x, file);
      /*      printf("chisq%c=%f\n",i+'a',chisq_slice[i]); */
      offset += n4x;
    }
    fclose(file);
  }
  

  printf("chisq=%f\n",chisq); fflush(stdout);

}

void senddata()
{
  FILE *fq, *fr, *fe;
  int i, idx, offset, len;
  char name[] = "mltmp.__";

  idx = strlen(name)-2;
  offset = 0;
  for (i=0; i < 4; i++) {
    name[idx]='q'; name[idx+1]='a'+i; fq = fopen(name,"wb");
    name[idx]='r'; name[idx+1]='a'+i; fr = fopen(name,"wb");
    name[idx]='e'; name[idx+1]='a'+i; fe = fopen(name,"wb");
    if (xspin[i]) {
      len = npntsx[i];
      fwrite(xdat+offset,sizeof(xdat[0]), len, fq);
      fwrite(ydat+offset,sizeof(ydat[0]), len, fr);
      fwrite(srvar+offset,sizeof(srvar[0]), len, fe);
      offset += len;
    }
    fclose(fq);
    fclose(fr);
    fclose(fe);
  }
  printf("\ndata written\n"); fflush(stdout);
}

#if 0 /* Defined by tcl interface */
void ipc_fitupdate(void)
{
  sendpars();
  sendprofile();
  sendreflect();
}
#endif

/* The following are commands to communicate with
   the GUI; they aren't meaningful if called directly */
int ipc_recv(char *command)
{
  char what[100];

  if (queryString("Receive what: ", what, sizeof(what)-1) == NULL) return -1;
  caps(what);
  
  if (strcmp(what, "PARS") == 0) {
    /* Send layers to GUI */
    recvpars();

  } else {
    /* Not a GUI command; let mlayer continue processing it */
    return -1;
  }

  return 0;
}


int ipc_send(char *command)
{
  char what[100];

  if (queryString("Send what: ", what, sizeof(what)-1) == NULL) return -1;
  caps(what);
  
  if (strcmp(what, "PROF") == 0) {
    /* Generate profile */
    ngenlayers(qcsq, d, rough, mu, nlayer, zint, rufint, nrough, proftyp);
    mgenlayers(qcmsq, dm, mrough, the, nlayer, zint, rufint, nrough, proftyp);
    gmagpro4();

    /* Send profile to GUI */
    sendprofile();

  } else if (strcmp(what, "REFL") == 0) {
    /* XXX FIXME XXX - should work without any data loaded, but lets get
       gj2.tcl working before addressing this. */
    if (loadData(infile,xspin)) { 
      printf("chisq=0.0\n"); fflush(stdout);
      return 0;
    }
    /* WARNING! Assumes "PROF" has been calculated first! */
    /* XXX FIXME XXX - not checking for memory allocation failure */
    if (extend(q4x, n4x, lambda, lamdel, thedel) != 0) {
      genderiv4(q4x, y4x, n4x, 0);
      sendreflect();
    }

  } else if (strcmp(what, "DATA") == 0) {
    /* Send reflectivity data to GUI */
    loadData(infile,xspin);
    senddata();

  } else if (strcmp(what, "PARS") == 0) {
    /* Send layers to GUI */
    sendpars();

  } else if (strcmp(what, "CONS") == 0) {
    int i;

    /* Send the name of the contraints scriptfile */
    printf("<%s>\n",constrainScript);
    /* Send the command line to invoke makeconstraints */
    /* (this must stay consistent with dlconstrain.c) */
    printf("<%s \"%s\" \"%s\" 0x%08lx \"%s\"", "makeconstrain", 
	   constrainScript, constrainModule,
	   MAJOR | MINOR, prototype);
    for (i=5; makeargv[i]; i++) printf(" \"%s\"", makeargv[i]);
    printf(">\n");

  } else {
    /* Not a GUI command; let mlayer continue processing it */
    return -1;
  }

  return 0;

}
