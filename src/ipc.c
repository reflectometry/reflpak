#include <stdio.h>
#include <errno.h>
#include <string.h>
#include "genmulti.h"
#include "ipc.h"
#include "cdata.h"
#include "clista.h"
#include "genpsd.h"
#include "genpsi.h"
#include "genpsr.h"
#include "genpsc.h"
#include "genmem.h"
#include "glayi.h"
#include "glayd.h"
#include "genvac.h"
#include "dlconstrain.h"
#include "constraincpp.h"
#include "queryString.h"
#include "caps.h"
#include "loadData.h"
#include "extres.h"
#include "genderiv.h"

void sendpars()
{
  FILE *fp;
  double t;
  int i;

  fp = fopen("mltmp.pars","wb");
  t = ntlayer+nmlayer+nblayer+1; fwrite(&t, sizeof(t), 1, fp);

  t = ntlayer; fwrite(&t, sizeof(t), 1, fp);
  t = nmlayer; fwrite(&t, sizeof(t), 1, fp);
  t = nblayer; fwrite(&t, sizeof(t), 1, fp);
  t = nrepeat; fwrite(&t, sizeof(t), 1, fp);

  fwrite(&bmintns, sizeof(bmintns), 1, fp);
  fwrite(&bki, sizeof(bki), 1, fp);
  fwrite(&thedel, sizeof(thedel), 1, fp);
  fwrite(&lamdel, sizeof(lamdel), 1, fp);
  fwrite(&lambda, sizeof(lambda), 1, fp);

  t = 0.0;
  for (i=0; i < nrough; i++) t += 0.5*zint[i];
  fwrite(&t, sizeof(t), 1, fp);
  t = nrough; fwrite(&t, sizeof(t), 1, fp);

  for (i=0; i <= ntlayer; i++) {
    fwrite(tqcsq+i, sizeof(double), 1, fp);
    fwrite(tmu+i, sizeof(double), 1, fp);
    fwrite(trough+i, sizeof(double), 1, fp);
    fwrite(td+i, sizeof(double), 1, fp);
  }
  for (i=1; i <= nmlayer; i++) {
    fwrite(mqcsq+i, sizeof(double), 1, fp);
    fwrite(mmu+i, sizeof(double), 1, fp);
    fwrite(mrough+i, sizeof(double), 1, fp);
    fwrite(md+i, sizeof(double), 1, fp);
  }
  for (i=1; i <= nblayer; i++) {
    fwrite(bqcsq+i, sizeof(double), 1, fp);
    fwrite(bmu+i, sizeof(double), 1, fp);
    fwrite(brough+i, sizeof(double), 1, fp);
    fwrite(bd+i, sizeof(double), 1, fp);
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
  fread(&t, sizeof(t), 1, fp);
  fread(&t, sizeof(t), 1, fp);  ntlayer = (int)rint(t);
  fread(&t, sizeof(t), 1, fp);  nmlayer = (int)rint(t);
  fread(&t, sizeof(t), 1, fp);  nblayer = (int)rint(t);
  fread(&t, sizeof(t), 1, fp);  nrepeat = (int)rint(t);
  fread(&bmintns, sizeof(bmintns), 1, fp);
  fread(&bki, sizeof(bki), 1, fp);
  fread(&thedel, sizeof(thedel), 1, fp);
  fread(&lamdel, sizeof(lamdel), 1, fp);
  fread(&lambda, sizeof(lambda), 1, fp);
  fread(&t, sizeof(t), 1, fp); /* ignore roughwidth */

  for (i=0; i <= ntlayer; i++) {
    fread(tqcsq+i, sizeof(double), 1, fp);
    fread(tmu+i, sizeof(double), 1, fp);
    fread(trough+i, sizeof(double), 1, fp);
    fread(td+i, sizeof(double), 1, fp);
  }
  for (i=1; i <= nmlayer; i++) {
    fread(mqcsq+i, sizeof(double), 1, fp);
    fread(mmu+i, sizeof(double), 1, fp);
    fread(mrough+i, sizeof(double), 1, fp);
    fread(md+i, sizeof(double), 1, fp);
  }
  for (i=1; i <= nblayer; i++) {
    fread(bqcsq+i, sizeof(double), 1, fp);
    fread(bmu+i, sizeof(double), 1, fp);
    fread(brough+i, sizeof(double), 1, fp);
    fread(bd+i, sizeof(double), 1, fp);
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


  fd = fopen("mltmp.d", "wb");
  if (fd == NULL) {
    printf("\nprofile error %s\n", strerror(errno));
    return;
  }
  fmu = fopen("mltmp.mu", "wb");
  if (fmu == NULL) {
    printf("\nprofile error %s\n", strerror(errno));
    fclose(fd);
    return;
  }
  fqcsq = fopen("mltmp.qcsq", "wb");
  if (fqcsq == NULL) {
    printf("\nprofile error %s\n", strerror(errno));
    fclose(fd);
    fclose(fmu);
    return;
  }
  thick = -vacThick(trough,zint,nrough);
  for (j = 0; j < nglay; j++) {
    fwrite(&thick, sizeof(thick), 1, fd);
    fwrite(gmu+j, sizeof(gmu[j]), 1, fmu);
    fwrite(gqcsq+j, sizeof(gqcsq[j]), 1, fqcsq);
    thick += gd[j];
    fwrite(&thick, sizeof(thick), 1, fd);
    fwrite(gmu+j, sizeof(gmu[j]), 1, fmu);
    fwrite(gqcsq+j, sizeof(gqcsq[j]), 1, fqcsq);
  }
  fclose(fd);
  fclose(fmu);
  fclose(fqcsq);
  printf("\nprofile written\n"); fflush(stdout);
}

void sendreflect(double *x, double *y)
{
  FILE *fq, *fr;
  int j;
  double chisq;
  fq = fopen("mltmp.q","wb");
  fr = fopen("mltmp.r","wb");
  /*  for (j=0; j<npnts; j++) { printf("%f %f\n", xtemp[j], yfit[j]); } */
  fwrite(x,sizeof(x[0]), npnts, fq);
  fwrite(y,sizeof(y[0]), npnts, fr);
  fclose(fq);
  fclose(fr);
  /*  printf("\nreflectivity written\n"); fflush(stdout); */
  if (loaded) {
    /* XXX FIXME XXX - this code taken from calcChiSq(); make it a function */
    chisq = 0.;
    for (j = 0; j < npnts; j++) {
      register double chi;
      if (srvar[j] < 1.e-10) srvar[j] = 1.e-10;
      chi = (ydat[j] - y[j]) / srvar[j];
      chisq += chi * chi;
    }
    /* XXX FIXME XXX - during fitting uses chisq/(npnts-mfit), so make sure
     * the documentation makes this distinction clear.  Hah! What docs?
     */
    chisq = chisq / (double) (npnts-1);
    printf("chisq=%f\n",chisq); fflush(stdout);
  } else {
    printf("chisq=1.0\n"); fflush(stdout);
  }

}

void senddata()
{
  FILE *fq, *fr, *fd;
  loadData(infile);
  /* XXX FIXME XXX if the load fails, do we really have to create
     empty files? */
  fq = fopen("mltmp.q","wb");
  fr = fopen("mltmp.r","wb");
  fd = fopen("mltmp.e","wb");
  if (loaded) {
    fwrite(xdat,sizeof(xdat[0]), npnts, fq);
    fwrite(ydat,sizeof(ydat[0]), npnts, fr);
    fwrite(srvar,sizeof(srvar[0]), npnts, fd);
  }
  fclose(fq);
  fclose(fr);
  fclose(fd);
  printf("\ndata written\n"); fflush(stdout);
}

void old_ipc_fitupdate(void)
{
  sendpars();
  sendprofile();
  sendreflect(xdat,ymod);
}

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
    genmulti(tqcsq, mqcsq, bqcsq, tqcmsq, mqcmsq, bqcmsq,
	     td, md, bd,
	     trough, mrough, brough, tmu, mmu, bmu,
	     nrough, ntlayer, nmlayer, nblayer, nrepeat, proftyp);

    /* Send profile to GUI */
    sendprofile();

  } else if (strcmp(what, "REFL") == 0) {
    if (loaded) {
      extend(xdat, npnts, lambda, lamdel, thedel);
      genderiv(xdat, yfit, npnts, 0);
      sendreflect(xdat,yfit);
    } else {
      /* Send calculated reflectivity to GUI */
      double qstep;
      int j;

      qstep = (qmax - qmin) / (double) (npnts - 1);
      for (j = 0; j < npnts; j++)
	xtemp[j] = (double) j * qstep + qmin;

      /* XXX FIXME XXX - not checking for memory allocation failure */
      extend(xtemp, npnts, lambda, lamdel, thedel);
      genderiv(xtemp, yfit, npnts, 0);

      sendreflect(xtemp,yfit);
    }

  } else if (strcmp(what, "DATA") == 0) {
    /* Send reflectivity data to GUI */
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
