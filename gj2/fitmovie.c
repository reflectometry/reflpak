int fitMovie(char *command, int xspin[4], double preFit[NA])
{
   int failed = FALSE;
   int replay = TRUE;
   int frames = 0, j;
   static double orig[NA];
   char *string;
   FILE *gnuPipe;

   /* Determine reflectivities to print */
   setPspin(pspin, xspin, command + 3);

   failed = loadData(infile, xspin);
   if (failed) {
      return failed;
   }
   if (extend(q4x, n4x, lambda, lamdel, thedel) == NULL) {
      failed = TRUE;
      return failed;
   }

   gnuPipe = popen("gnuplot", "w");
   if (gnuPipe == NULL) {
      failed = TRUE;
      return failed;
   }

   string = queryString("Number of frames: ", NULL, 0);
   if (string) sscanf(string, "%d", &frames);

   for (j = 0; j < NA; j++)
      orig[j] = A[j];

   while (replay) {
      register int i;
      void (*oldhandler)(void);

      string = queryString("Specify an optional y range in format ymin:ymax ",
         NULL, 0); 
      if (string != NULL) fprintf(gnuPipe, "set yrange [%s]\n", string);

      fprintf(gnuPipe, "set title \"x = %8.6f\"\n", 0.);

      /* Calculate reflectivities and package for gnuplot */
      for (i = 0; i < NA; i++)
         A[i] = preFit[i];
      (*Constrain)(FALSE, A, nlayer);

      fprintf(gnuPipe, "set xlabel \"%s\"\n", qlabel);
      fprintf(gnuPipe, "set ylabel \"%s\"\n", rlabel);
      firstReflecFrame(gnuPipe, xspin, pspin);
      fflush(gnuPipe);

#ifndef DEBUGMALLOC
      oldhandler = signal(SIGINT, stopMovie);
#endif
      abortMovie = FALSE;

      queryString("Wait for first frame, then press enter to start movie. ",
         NULL, 0);

      for (j = frames; !abortMovie && j > 0;) {
         struct timeval now;

         gettimeofday(&now);
         for (i = 0; i < NA; i++)
            A[i] += (orig[i] - A[i]) / (double) j;

         (*Constrain)(FALSE, A, nlayer);
         genderiv4(q4x, y4x, n4x, 0);
         framePause(0.125, &now);
         fprintf(gnuPipe, "set title \"x = %8.6f\"\n", 
            1. - (double) (--j) / (double) frames);
         reflecFrame(gnuPipe, xspin, pspin);
         fputs("replot\n", gnuPipe);
         fflush(gnuPipe);
      }
      if (abortMovie) puts("Stopping the movie.");

#ifndef DEBUGMALLOC
      /* Restore signal handlers */
      signal(SIGINT, oldhandler);
#endif

      string = queryString("Input \"R\" to replay. ", NULL, 0);
      if (!string || (*string != 'r' && *string != 'R')) replay = FALSE;
   }
   fputs("quit\n", gnuPipe);
   pclose(gnuPipe);

   for (j = 0; j < NA; j++)
      A[j] = orig[j];
   (*Constrain)(FALSE, A, nlayer);
   return failed;
}

