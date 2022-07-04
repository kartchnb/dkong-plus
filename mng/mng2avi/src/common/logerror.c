#include <stdio.h>
#include <stdarg.h>
#include "options.h"

extern struct _options options;
static FILE *logfile=NULL;


//============================================================
//	vlogerror
//============================================================

static void vlogerror(const char *text, va_list arg)
{
   static int fopen_tried=0;

   if (options.log)
   {
      if (logfile==NULL)
      {
         if (!fopen_tried)
         {
            if (options.log_name!=NULL)
               logfile=fopen(options.log_name,"w");
         }
         fopen_tried=1;
      }
      if (logfile)
      {
         vfprintf(logfile, text, arg);
         fflush(logfile);
      }
   }
}


void logerror(const char *text,...)
{
   va_list arg;

   /* standard vfprintf stuff here */
   va_start(arg, text);
   vlogerror(text, arg);
   va_end(arg);
}


