// options can be filled in with command line parameters or with
// .ini file
struct _options
{
   //char *mng_directory;
   char *png_directory;
   //char *avi_directory;
   //char *vdb_directory;
   char *mng_name;
   char *avi_name;
   char *wav_name;
   char *log_name;
   int verbose;
   int debug;
   int log;
   int showusage;
   int showversion;
   int movieaudio;
   int movievideo;
   int minmovielength;
   int maxmovielength;
   int minmoviestart;
   int moviethreshold;
   int movieloops;
   int moviesquare;
   int moviestartframe;
   int movieendframe;
   int moviematchlength;
   int movieskipblack;
   int movieskipframes;
   int moviesyncframes;
} options;
