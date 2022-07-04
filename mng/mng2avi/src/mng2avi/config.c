#include <stdarg.h>
#include <ctype.h>
#include <time.h>
#include "options.h"
#include "rc.h"

struct rc_struct *rc;

static char *debugres;
extern struct _options options;
static int argindex=0;

int parse_config (const char* filename);
//struct rc_struct *cli_rc_create(void);
int cli_frontend_init (int argc, char **argv);
static char *win_basename(char *filename);
static char *win_dirname(char *filename);
static char *win_strip_extension(char *filename);
static int config_handle_arg(char *arg);
void fprint_colums(FILE *f, const char *text1, const char *text2);

static int config_handle_arg(char *arg)
{
   //printf("config_handle_arg(%s)\n",arg);
   switch (argindex)
   {
      case 0: options.mng_name=arg; break;
      case 1: options.avi_name=arg; break;
      case 2: options.wav_name=arg; break;
      default: break;
   }
   argindex++;
   return 0;
}

/* struct definitions */
static struct rc_option opts[] = {
	/* name, shortname, type, dest, deflt, min, max, func, help */
        //{ "mng_directory", NULL, rc_string, &options.mng_directory, ".", 0, 0, NULL, "set directory to find mng file" },
        { "png_directory", NULL, rc_string, &options.png_directory, "pngs", 0, 0, NULL, "set directory to find png snapshots" },
        { "mng_name", NULL, rc_string, &options.mng_name, NULL, 0, 0, NULL, "name of mng input file" },
        { "wav_name", NULL, rc_string, &options.wav_name, NULL, 0, 0, NULL, "name of wav input file" },
        { "verbose", "v", rc_bool, &options.verbose, "0", 0, 0, NULL, "verbose output" },
        { "debug", "d", rc_bool, &options.debug, "0", 0, 0, NULL, "debug output" },
        { "log_name", NULL, rc_string, &options.log_name, "mng2avi.log", 0, 0, NULL, "name of log file" },
        { "log", NULL, rc_bool, &options.log, "0", 0, 0, NULL, "send stdout to file" },
        
        { "showusage","su",rc_set_int,&options.showusage,NULL,1,0,NULL,"show this help" },
        { "showversion","sv",rc_set_int,&options.showversion,NULL,1,0,NULL,"show version information" },

        { "minmoviestart", NULL, rc_int, &options.minmoviestart, "200", 0, 99999, NULL, "Lowest possible start frame of movie" },
        { "minmovielength", NULL, rc_int, &options.minmovielength, "800", 0, 99999, NULL, "Lowest possible movie length (in frames)" },
        { "maxmovielength", NULL, rc_int, &options.maxmovielength, "10000", 0, 99999, NULL, "Highest possible movie length (in frames)" },
        { "moviethreshold", NULL, rc_int, &options.moviethreshold, "2", 0, 255, NULL, "Lowest 8-bit value for non-black pixel" },
        { "movieaudio", NULL, rc_int, &options.movieaudio, "1", 0, 3, NULL, "Movie audio compression type 0=none, 1=mp3, 2=custom, 3=disable audio" },  
        { "movievideo", NULL, rc_int, &options.movievideo, "3", 0, 4, NULL, "Movie video compression type 0=none, 1=divx, 2=cvid, 3=xvid, 4=custom" },  
        { "movieloops", NULL, rc_int, &options.movieloops, "1", 0, 4, NULL, "detect attract mode loops in movies, 0=disable, 1=duplicate frames, 2=fixed frame numbers, 3=debug, 4=start loop in middle" }, 
        { "moviesquare", NULL, rc_int, &options.moviesquare, "0", 0, 512, NULL, "resize movies to specified square size" }, 
        { "moviestartframe", NULL, rc_int, &options.moviestartframe, "0", 0, 0, NULL, "starting frame of movie (must use movieloops 2)" }, 
        { "movieendframe", NULL, rc_int, &options.movieendframe, "0", 0, 0, NULL, "ending frame of movie (must use movieloops 2)" }, 
        { "moviematchlength", NULL, rc_int, &options.moviematchlength, "10", 1, 99, NULL, "number of consecutive matched frames which determine a loop" }, 
        { "movieskipblack", NULL, rc_int, &options.movieskipblack, "1", 0, 2, NULL, "0=don't skip black frames 1=skip black frames 2=skip monochromatic frames (slower)" }, 
        { "movieskipframes", NULL, rc_int, &options.movieskipframes, "0", 0, 99999, NULL, "number of frames to skip at beginning of loop" }, 
        { "moviesyncframes", NULL, rc_int, &options.moviesyncframes, "0", -99999,99999, NULL, "add this many frame to sync audio" }, 
        { NULL, NULL, rc_end, NULL, NULL, 0, 0, NULL, NULL }
};

int cli_frontend_init (int argc, char **argv)
{
   char buffer[128];

   rc = rc_create();
   if (!rc)
   {
      fprintf(stderr,"error in rc_create\n");
      return -1;
   }

   if (rc_register(rc, opts))
   {
      fprintf(stderr,"error in rc_register\n");
      rc_destroy(rc);
      return -2;
   }

   /* parse the commandline, use priority 3 */
   if (rc_parse_commandline(rc, argc, argv, 3, config_handle_arg))
   {
      //fprintf (stderr, "error in rc_parse_commandline\n");
      return -3;
   }

   /* parse mng2avi.ini at priority 1 */
   strcpy(buffer,"mng2avi.ini");
   if (rc_load(rc,buffer,1,1))
   {
      fprintf(stderr,"error in rc_load\n");
      return -4;
   }

   if (options.showusage)
   {
      fprintf(stdout,"Options:\n");
      rc_print_help(rc,stdout);
      exit(0);
   }

   if (options.showversion)
   {
      fprintf(stdout,"mng2avi version 2007.0215\n");
      fprintf(stdout,"Created by Buddabing (buddabing AT houston DOT rr DOT com)\n");
      fprintf(stdout,"usage: mng2avi [name of input MNG file] [options]\n");
      fprintf(stdout,"mng2avi -showusage for a full list of options\n\n");
      exit(0);
   }

   if (options.mng_name==NULL)
   {
      fprintf(stdout,"usage: mng2avi [name of input MNG file] [options]\n");
      fprintf(stdout,"mng2avi -showusage for a full list of options\n\n");
      exit(0);
   }

   if (options.debug)
      rc_write(rc,stdout,buffer);
   return 0;
}



void fprint_colums(FILE *f, const char *text1, const char *text2)
{
   const char *text[2];
   int i, j, cols, width[2], done = 0;

   char *e_cols = (char *)getenv("COLUMNS");

   cols = e_cols? atoi(e_cols):80;
   if ( cols < 6 ) cols = 6;  /* minimum must be 6 */
   cols--;

   /* initialize our arrays */
   text[0] = text1;
   text[1] = text2;
   width[0] = cols * 0.4;
   width[1] = cols - width[0];

   while(!done)
   {
      done = 1;
      for(i = 0; i < 2; i++)
      {
         int to_print = width[i]-1; /* always leave one space open */

         /* we don't want to print more then we have */
         j = strlen(text[i]);
         if (to_print > j)
           to_print = j;

         /* if they have preffered breaks, try to give them to them */
         for(j=0; j<to_print; j++)
            if(text[i][j] == '\n')
            {
               to_print = j;
               break;
            }

         /* if we don't have enough space, break at the first ' ' or '\n' */
         if(to_print < strlen(text[i]))
         {
           while(to_print && (text[i][to_print] != ' ') &&
              (text[i][to_print] != '\n'))
              to_print--;

           /* if it didn't work, just print the columnwidth */
           if(!to_print)
              to_print = width[i]-1;
         }
         fprintf(f, "%-*.*s", width[i], to_print, text[i]);

         /* adjust ptr */
         text[i] += to_print;

         /* skip ' ' and '\n' */
         while((text[i][0] == ' ') || (text[i][0] == '\n'))
            text[i]++;

         /* do we still have text to print */
         if(text[i][0])
            done = 0;
      }
      fprintf(f, "\n");
   }
}

