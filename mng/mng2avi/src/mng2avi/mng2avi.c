#include <stdio.h>
#include "options.h"
#include "zlib.h"
#include "md5.h"

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

#define LSB_FIRST 0

#define PNG_CN_IHDR			0x49484452L
#define PNG_CN_IDAT			0x49444154L
#define PNG_CN_IEND			0x49454E44L
#define MNG_CN_MHDR			0x4D484452L
#define MNG_CN_MEND			0x4D454E44L

const unsigned char PNG_Signature[8]=
{
   0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
};

const unsigned char MNG_Signature[8]=
{
   0x8A,0x4D,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
};

/* Macros for normalizing data into big or little endian formats */
#define FLIPENDIAN_INT16(x)     (((((unsigned short) (x)) >> 8) | ((x) << 8)) & 0xffff)
#define FLIPENDIAN_INT32(x)     ((((unsigned long) (x)) << 24) | (((unsigned long) (x)) >> 24) | \
        (( ((unsigned long) (x)) & 0x0000ff00) << 8) | (( ((unsigned long) (x)) & 0x00ff0000) >> 8))
#define FLIPENDIAN_INT64(x)	\
	(												\
                (((((unsigned long long) (x)) >> 56) & ((unsigned long long) 0xFF)) <<  0)      |       \
                (((((unsigned long long) (x)) >> 48) & ((unsigned long long) 0xFF)) <<  8)      |       \
                (((((unsigned long long) (x)) >> 40) & ((unsigned long long) 0xFF)) << 16)      |       \
                (((((unsigned long long) (x)) >> 32) & ((unsigned long long) 0xFF)) << 24)      |       \
                (((((unsigned long long) (x)) >> 24) & ((unsigned long long) 0xFF)) << 32)      |       \
                (((((unsigned long long) (x)) >> 16) & ((unsigned long long) 0xFF)) << 40)      |       \
                (((((unsigned long long) (x)) >>  8) & ((unsigned long long) 0xFF)) << 48)      |       \
                (((((unsigned long long) (x)) >>  0) & ((unsigned long long) 0xFF)) << 56)              \
	)

#ifdef LSB_FIRST
#define BIG_ENDIANIZE_INT16(x)		(FLIPENDIAN_INT16(x))
#define BIG_ENDIANIZE_INT32(x)		(FLIPENDIAN_INT32(x))
#define BIG_ENDIANIZE_INT64(x)		(FLIPENDIAN_INT64(x))
#define LITTLE_ENDIANIZE_INT16(x)	(x)
#define LITTLE_ENDIANIZE_INT32(x)	(x)
#define LITTLE_ENDIANIZE_INT64(x)	(x)
#else
#define BIG_ENDIANIZE_INT16(x)		(x)
#define BIG_ENDIANIZE_INT32(x)		(x)
#define BIG_ENDIANIZE_INT64(x)		(x)
#define LITTLE_ENDIANIZE_INT16(x)	(FLIPENDIAN_INT16(x))
#define LITTLE_ENDIANIZE_INT32(x)	(FLIPENDIAN_INT32(x))
#define LITTLE_ENDIANIZE_INT64(x)	(FLIPENDIAN_INT64(x))
#endif /* LSB_FIRST */

/* PNG support */
struct _png_info
{
        unsigned long width, height;
        unsigned long xres, yres;
        //rectangle screen;
        //double xscale, yscale;
        //double source_gamma;
        //unsigned long chromaticities[8];
        //unsigned long resolution_unit, offset_unit, scale_unit;
        unsigned char bit_depth;
        //unsigned long significant_bits[4];
        //unsigned long background_color[4];
        unsigned char color_type;
        unsigned char compression_method;
        unsigned char filter_method;
        unsigned char interlace_method;
        //unsigned long num_palette;
        //unsigned char *palette;
        //unsigned long num_trans;
        //unsigned char *trans;
        unsigned char *image;
        unsigned char bpp;
        unsigned long rowbytes;
        unsigned char *zimage;
        unsigned long zlength;
        unsigned char *fimage;
};
typedef struct _png_info png_info;

typedef struct _idat
{
   struct _idat *next;
   int length;
   unsigned char *data;
} idat;

typedef struct _bucket_node
{
   int frame;
   char fname[28];
   char md5[36];
   struct _bucket_node *next;
} bucket_node;
bucket_node *bucket_list[256];

idat *ihead=NULL;
idat *pidat=NULL;

int current_frame_index=0;
int current_frame_number=1;
char dummy_pathname[4]="";
static int movie_png_width = 0;
static int movie_png_height = 0;
static int saved_start_frame = 0;
static int saved_end_frame = 0;
static int movie_start_frame = 0;
static int movie_end_frame = 0;
float refresh_rate;
int frames_to_skip=0;
int frames_to_add=0;


char buffer[1024];




inline unsigned long fetch_32bit(unsigned char *v)
{
   return BIG_ENDIANIZE_INT32(*(unsigned long *)v);
}

inline unsigned char fetch_8bit(unsigned char *v)
{
   return *v;
}

static void convert_to_network_order(unsigned long i, unsigned char *v)
{
   v[0]=i>>24;
   v[1]=(i>>16)&0xff;
   v[2]=(i>>8)&0xff;
   v[3]=i&0xff;
}

int mng_read_file(FILE *fp);
int read_chunk(FILE *fp, unsigned char **data, unsigned long *type, unsigned long *length);
int process_chunk(png_info *,unsigned char *data, unsigned long type, unsigned long length, int *keepmem);
int verify_header(FILE *fp);
int process_image(png_info *p);
static int detect_loop (png_info *);
static void calculate_md5 (png_info *, char *result);
static void free_bucket_list (void);
static int get_index (char *str);
static int snap_is_black (png_info *);
void generate_vdb_file (int, int);
int check_movie_snapshot(png_info *);
int get_image_size(png_info *,int *,int *);
void write_image(png_info *);
static int write_chunk(FILE *fp, unsigned long chunk_type, unsigned char *chunk_data, unsigned long chunk_length);
int png_write_sig(FILE *fp);
int png_write_datastream(FILE *fp, png_info *p);


main(int argc, char **argv)
{
   FILE *fp_in;

   cli_frontend_init(argc,argv);
   if (options.mng_name==NULL)
      exit(0);

   if (options.moviesyncframes)
   {
      frames_to_skip=-options.moviesyncframes;
      frames_to_add=options.moviesyncframes;
      logerror("frames_to_skip=%d, frames_to_add=%d\n",
         frames_to_skip,frames_to_add);
   }

   fp_in=fopen(options.mng_name,"rb");
   if (fp_in==NULL)                    
   {
      printf("failed to open %s\n",options.mng_name);
      exit(1);
   }

   // read the mng file
   if (mng_read_file(fp_in))
   {
      //printf("error reading file\n");
      fclose(fp_in);
      exit(1);
   }

   fclose(fp_in);

   // cleanup
   free_bucket_list();
   exit(0);
}

/*-------------------------------------------------
    mng_read_file - read a mng from a stdio stream
-------------------------------------------------*/

int mng_read_file(FILE *fp)
{
   unsigned char *chunk_data = NULL;
   unsigned long chunk_type, chunk_length;
   int keepmem;
   int error;
   png_info png;

   /* verify the signature at the start of the file */
   error = verify_header(fp);
   if (error)
   {
      printf("verify_header failed (%d)\n",error);
      goto handle_error;
   }
   else
   {
       //printf("verify_header success\n");
   }

   /* MNG files produced by MAME will have:
      MHDR chunk
      many blocks of
         IHDR
         IDAT
         IEND
      MEND chunk
    */

   /* read chunks until we hit an MEND chunk */
   for ( ; ; )
   {
      /* read a chunk */
      error = read_chunk(fp, &chunk_data, &chunk_type, &chunk_length);
      if (error)
      {
         //printf("read_chunk failed\n");
         goto handle_error;
      }

      /* stop when we hit an MEND chunk */
      if (chunk_type == MNG_CN_MEND)
         break;

      /* process the chunk */
      error = process_chunk(&png,chunk_data, chunk_type, chunk_length, &keepmem);
      if (error)
      {
         //printf("process_chunk failed\n");
         goto handle_error;
      }

      /* free memory if we didn't want to keep it */
      if (!keepmem)
         free(chunk_data);
      chunk_data = NULL;
   }


   handle_error:

   return error;
}

/*-------------------------------------------------
    read_chunk - read the next PNG chunk
-------------------------------------------------*/

int read_chunk(FILE *fp, unsigned char **data, unsigned long *type, unsigned long *length)
{
   unsigned long crc, chunk_crc;
   unsigned char tempbuff[4];
   int i;

   /* fetch the length of this chunk */
   if (fread(tempbuff, 1, 4, fp) != 4)
   {
      printf("read_chunk failed to fetch length\n");
      return 1;
   }
   //printf("Read length buffer: ");
   //for (i=0;i<4;i++)
   //{
   //   printf("%02x ",tempbuff[i]);
   //}
   //printf("\n");
   *length = fetch_32bit(tempbuff);

   /* fetch the type of this chunk */
   if (fread(tempbuff, 1, 4, fp) != 4)
   {
      printf("read_chunk failed to fetch chunk type\n");
      return 2;
   }
   //printf("Read type buffer: ");
   //for (i=0;i<4;i++)
   //{
   //   printf("%02x ",tempbuff[i]);
   //}
   //printf("\n");

   *type = fetch_32bit(tempbuff);

   /* stop when we hit a MEND chunk */
   if (*type==MNG_CN_MEND)
      return 0;

   /* start the CRC with the chunk type (but not the length) */
   crc = crc32(0, tempbuff, 4);

   /* read the chunk itself into an allocated memory buffer */
   *data = NULL;
   if (*length != 0)
   {
      /* allocate memory for this chunk */
      *data = (unsigned char *)malloc(*length);
                
      if (*data == NULL)
      {
         printf("read_chunk failed to allocate memory (%ld bytes)\n",*length);
         return 3;
      }

      /* read the data from the file */
      if (fread(*data, 1, *length, fp) != *length)
      {
         printf("read_chunk failed to read data\n");
         free(*data);
         return 4;
      }

      /* update the CRC */
      crc = crc32(crc, *data, *length);
   }

   /* read the CRC */
   if (fread(tempbuff, 1,4,fp) != 4)
   {
      printf("read_chunk failed to read crc\n");
      free(*data);
      return 5;
   }
   chunk_crc = fetch_32bit(tempbuff);

   /* validate the CRC */
   if (crc != chunk_crc)
   {
      printf("read_chunk crc mismatch\n");
      free(*data);
      return 6;
   }
   //printf("read_chunk success\n");
   return 0;
}


/*-------------------------------------------------
    process_chunk - process a PNG chunk
-------------------------------------------------*/

int process_chunk(png_info *p,unsigned char *data, unsigned long type, unsigned long length, int *keepmem)
{
   unsigned char *temp;
   int retcode=0;

   /* default to not keeping memory */
   *keepmem = FALSE;

   /* switch off of the type */
   switch (type)
   {
      /* image header */
      case PNG_CN_IHDR:
         //printf("Processing IHDR chunk\n");

         /* allocate chunk list */
         ihead=(idat *)malloc(sizeof(idat));
         if (ihead==NULL)
         {
            printf("failed to allocate memory\n");
            return 1;
         }
         pidat=ihead;

         /* initialize png info structure */
         p->zlength=0;
         p->width = fetch_32bit(data);
         p->height = fetch_32bit(data + 4);
         p->bit_depth = fetch_8bit(data + 8);
         p->color_type = fetch_8bit(data + 9);
         p->compression_method = fetch_8bit(data + 10);
         p->filter_method = fetch_8bit(data + 11);
         p->interlace_method = fetch_8bit(data + 12);
      break;

      /* image data */
      case PNG_CN_IDAT:
         /* allocate a new image data descriptor */
         //printf("Processing IDAT chunk\n");
         pidat->data=data;
         pidat->length=length;
         pidat->next=(idat *)malloc(sizeof(idat));
         if (pidat->next==NULL)
         {
            printf("failed to allocate memory\n");
            return 2;
         }
         pidat=pidat->next;
         pidat->next=NULL;
         p->zlength+=length;
         *keepmem = TRUE;
      break;

      /* end-of-image marker */
      case PNG_CN_IEND:
         //printf("Processing IEND chunk\n");
         /* allocate image memory */
         p->zimage=(unsigned char *)malloc(p->zlength);
         if (p->zimage==NULL)
         {
            printf("failed to allocate image memory\n");
            return 3;
         }

         /* traverse list of idats, copying compressed data to image */
         temp=p->zimage;
         while (ihead->next!=NULL)
         {
            pidat=ihead;
            memcpy(temp,pidat->data,pidat->length);
            free(pidat->data);
            temp+=pidat->length;
            ihead=pidat->next;
            free(pidat);
         }
         free(ihead);
         ihead=NULL;
         pidat=NULL;
         p->bpp=3;
         p->rowbytes=p->width*p->bpp;

         //printf("inflating image, width=%d, height=%d, depth=%d\n",
         //   p->width, p->height, p->bpp);
         png_inflate_image(p);        
         retcode=process_image(p);   
         if (p->fimage!=NULL)
            free(p->fimage);
         if (p->zimage!=NULL)
            free (p->zimage);
         p->fimage=NULL;
         p->zimage=NULL;

      break;

      case MNG_CN_MHDR:

         refresh_rate = (float)fetch_32bit(data+8);
         logerror("refresh rate=%f\n",refresh_rate);

      break;

      /* anything else */
      default:
         logerror("Processing default chunk\n");
      break;
   }
   return retcode;
}

// return non-zero if we want to terminate
int process_image(png_info *p)
{
   return check_movie_snapshot(p);
}

/*-------------------------------------------------
    verify_header - verify the MNG
    header at the current file location
-------------------------------------------------*/

int verify_header(FILE *fp)
{
   unsigned char signature[8];

   /* read 8 bytes */
   if (fread(signature, 1,8,fp) != 8)
      return 1;

   /* return an error if we don't match */
   if (memcmp(signature, MNG_Signature, 8) != 0)
      return 2;

   return 0;
}

int png_inflate_image (png_info *p)
{
   unsigned long fbuff_size;

   fbuff_size = p->height * (p->rowbytes + 1);

   if((p->fimage = (unsigned char *)malloc (fbuff_size))==NULL)
   {
      logerror("Out of memory\n");
      free (p->zimage);
      return 0;
   }

   if (uncompress(p->fimage, &fbuff_size, p->zimage, p->zlength) != Z_OK)
   {
      logerror("Error while inflating image\n");
      return 0;
   }

   return 1;
}



/*-------------------------------------------------
        check_movie_snapshot - save a screen snapshot
        return non-zero if we want to end the movie
-------------------------------------------------*/
int check_movie_snapshot (png_info *p)
{
   int i;

   // don't allow the movie to got past maxmovielength frames
   if (current_frame_index >= options.maxmovielength)
   {
      if (options.movieloops == 3)
      {
         logerror("max movie length reached, generating movie between frames %d and %d\n",
             saved_start_frame + options.movieskipframes, saved_end_frame);
         generate_vdb_file (saved_start_frame + options.movieskipframes,
                            saved_end_frame);
      }
      else
      {
         logerror("max movie length reached, generating movie between frames %d and %d\n",
             0, current_frame_index - 1);
         generate_vdb_file (0, current_frame_index - 1);
      }
      return 1;
   }

   // Depending on the value of options.moviesyncframes, we will either
   // delete frames from the beginning, or add extra frames at the beginning.
   
   // This is because the video can appear to be out of sync with the audio.

   if (options.moviesyncframes>0 && frames_to_add>0)
   {
      for (i=0;i<frames_to_add;i++)
      {
         write_image(p);
         current_frame_index++;
         current_frame_number++;
      }
      frames_to_add=0;
   }

   if (options.moviesyncframes<0 && frames_to_skip>0)
   {
      frames_to_skip--;
      return 0;
   }

   write_image(p);

   // don't detect a loop if the frame is black
   if (snap_is_black (p))
   {
      logerror("frame %d is black\n",current_frame_index);
      current_frame_index++;      
      current_frame_number++;
      return 0;
   }

   if (detect_loop (p))
   {
      logerror("loop detected\n");
      current_frame_index++;      
      current_frame_number++;
      return 1;
   }

   current_frame_index++;      
   current_frame_number++;

   return 0;
}

void write_image(png_info *p)
{
   FILE *fp;
   char filename[256];
   sprintf(filename,"pngs\\png%05d.png",current_frame_index);
   fp=fopen(filename,"wb");
   if (fp==NULL)
   {
      printf("failed to open %s for write\n",filename);
      return;
   }
   png_write_sig(fp);
   png_write_datastream(fp, p);
   fclose(fp);
}

static int get_index (char *str)
{
   int retval = 0;

   if (str[0] >= 'a' && str[0] <= 'f')
      retval = (str[0] - 'a' + 10) * 16;
   else if (str[0] >= 'A' && str[0] <= 'A')
      retval = (str[0] - 'A' + 10) * 16;
   else
      retval = (str[0] - '0') * 16;
   if (str[1] >= 'a' && str[1] <= 'f')
      retval += (str[1] - 'a' + 10);
   else if (str[1] >= 'A' && str[1] <= 'A')
      retval += (str[1] - 'A' + 10);
   else
      retval += (str[1] - '0');
   return retval;
}

// given a png_info structure containing image data, detect a loop
static int detect_loop (png_info *p)
{
   static char prev_md5[36] = "";
   char current_md5[36];
   int bucket_index;
   int bufframe;
   bucket_node *b;
   int found;
   static int match_in_progress = FALSE;
   static int match_count = 0;
   char pngname[256];

   sprintf(pngname,"pngs\\png%05d.png",current_frame_index);

   logerror("detect_loop(%s)\n",pngname);
   // don't detect loops if disabled
   if (!options.movieloops)
      return 0;

   if (options.movieloops == 2)
   {
      if (current_frame_index >= options.movieendframe)
      {
	 generate_vdb_file (options.moviestartframe + options.movieskipframes,
			    options.movieendframe);
	 return 1;
      }
      else
	 return 0;
   }

   calculate_md5 (p, current_md5);
   logerror("md5 for frame %d is %s\n",current_frame_index,current_md5);

   // scan the previous frames
   bucket_index = get_index (current_md5);
   b = bucket_list[bucket_index];
   found = FALSE;
   while (b != NULL && !found)
   {
      if (strcmp (b->md5, current_md5) == 0)
	 found = TRUE;
      else
         b = b->next;
   }

   // check for duplicate frame
   if (strcmp (current_md5, prev_md5) == 0)
   {
      // update the frame number
      if (found)
         b->frame = current_frame_index;
      if (match_in_progress)
         logerror ("duplicate frame, match count not incremented\n");
      return 0;
   }

   // current md5 will be prev_md5 next time
   strcpy (prev_md5, current_md5);

   // if not found
   if (!found)
   {
      b = (bucket_node *) malloc (sizeof (bucket_node));
      if (b == NULL)
      {
	 fprintf (stderr, "Bucket node allocation failure\n");
	 return 1;
      }
      b->frame = current_frame_index;
      strcpy (b->md5, current_md5);
      strcpy (b->fname, pngname);
      b->next = bucket_list[bucket_index];
      bucket_list[bucket_index] = b;
      match_in_progress = FALSE;
      return 0;
   }

   // if found
   // no loops in the first minmoviestart frames
   if (current_frame_number < options.minmoviestart)
      return 0;

   // bufframe is the frame index (not frame number) of the matching frame
   bufframe = atoi(b->fname+8);
   logerror("current_frame_index %d (frame number %d) bufframe %d\n",
      current_frame_index,current_frame_number,bufframe);

   // get "distance"
   if ((abs (current_frame_index - bufframe) + 1) < options.minmovielength)
      return 0;
   if (match_in_progress)
   {
      logerror ("%d matches in a row, need %d\n", match_count + 1,
		options.moviematchlength);
   }
   else
   {
      logerror ("beginning to detect loop between frame %d and frame %d\n",
                bufframe, current_frame_index);
      match_in_progress = TRUE;
      match_count = 0;
      movie_start_frame = bufframe;
      // current_frame_index is the first frame of the second iteration
      movie_end_frame = current_frame_index - 1;   
   }
   match_count++;
   if (match_count == options.moviematchlength)
   {
      logerror ("%d-frame match detected between frame %d and %d\n",
              options.moviematchlength, bufframe, current_frame_index);

      if (options.movieloops == 3)
      {
	 if (saved_end_frame == 0)
	 {
	    saved_start_frame = bufframe - options.moviematchlength + 1;
            saved_end_frame = current_frame_index - options.moviematchlength + 1;
            logerror ("movie will run between frames %d and %d\n",
		    saved_start_frame + options.movieskipframes,
		    saved_end_frame);
	 }
	 return 0;
      }
      else if (options.movieloops == 4)
      {
#if 1
	 if (saved_end_frame == 0)
	 {
	    saved_start_frame = bufframe - options.moviematchlength + 1;
            saved_end_frame = current_frame_index - options.moviematchlength + 1;
            logerror ("movie will run between frames %d and %d\n",
		    saved_start_frame + (saved_end_frame -
					 saved_start_frame) / 2,
		    saved_end_frame + (saved_end_frame -
				       saved_start_frame) / 2);
	 }
	 return 0;
#else
         // log the frame numbers not frame indices
         logerror ("movie will run between frames %d and %d\n",
                 movie_start_frame+1 + options.movieskipframes,
                 movie_end_frame+1);
	 rearrange_snapshots (movie_start_frame + options.movieskipframes,
			      movie_end_frame);
	 generate_vdb_file (movie_start_frame + options.movieskipframes,
			    movie_end_frame);
	 return 1;
#endif
      }
      else
      {
         logerror ("movie will run between frames %d and %d\n",
                 movie_start_frame+1 + options.movieskipframes,
                 movie_end_frame+1);

	 // don't include the overlap
	 generate_vdb_file (movie_start_frame + options.movieskipframes,
			    movie_end_frame);
	 return 1;
      }
   }
   return 0;
}

// not static, it's also called if they press ESC
void generate_vdb_file (int bufframe, int curframe)
{
   FILE *fp;
   FILE *fp2;
   char fname[32];
   char tempbuff[80];

   logerror("generate_vdb_file: bufframe=%d, curframe=%d\n",bufframe,curframe);

   // open the VirtualDub job file
   sprintf (fname, "output.vdb");
   fp = fopen (fname, "w");
   if (fp == NULL)
   {
      logerror ("Failed to open VirtualDub job file\n");
      return;
   }

   sprintf(tempbuff,"%s\\\\png00000.png",options.png_directory);

   fprintf (fp, "VirtualDub.Open(\"%s\",\"\",0);\n", tempbuff);

   // audio
   if (options.movieaudio!=3)
   {
      if (options.wav_name!=NULL)
         fprintf (fp, "VirtualDub.audio.SetSource(\"%s\");\n",options.wav_name);
      else
         logerror("no wav_name parameter set, sound disabled\n");
   }
   else
   {
      logerror("movieaudio option set to disable sound\n");
   }
   fprintf (fp, "VirtualDub.audio.SetMode(1);\n");
   fprintf (fp, "VirtualDub.audio.SetInterleave(1,500,1,0,0);\n");
   fprintf (fp, "VirtualDub.audio.SetClipMode(1,1);\n");
   fprintf (fp, "VirtualDub.audio.SetVolume();\n");
   fprintf (fp, "VirtualDub.audio.filters.Clear();\n");
   
   //fprintf(fp,"VirtualDub.audio.SetConversion(22050,2,1,0,0);\n");
   switch (options.movieaudio)
   {
      case 0:
         fprintf (fp, "VirtualDub.audio.SetConversion(0,0,0,0,0);\n");
	 fprintf (fp, "VirtualDub.audio.SetCompression();\n");
	 break;
      case 1:
         fprintf (fp, "VirtualDub.audio.SetConversion(22050,0,0,0,0);\n");
         //fprintf (fp, "VirtualDub.audio.SetConversion(0,0,0,0,0);\n");
         //fprintf (fp, "VirtualDub.audio.SetCompression(85,22050,1,0,3000,1,12,\"AQACAAAATgABAHEF\");\n");
         fprintf (fp, "VirtualDub.audio.SetCompression(85,22050,2,0,8000,1,12,\"AQACAAAATgABAHEF\");\n");
	 break;
      case 2:
	 fp2 = fopen ("acodec.dat", "rb");
	 if (fp2 == NULL)
	    break;
	 while (fread (tempbuff, 1, 1, fp2))
	    fwrite (tempbuff, 1, 1, fp);
	 fclose (fp2);
	 break;
      case 3: break;
      default:
	 break;
   }
   fprintf (fp, "VirtualDub.audio.EnableFilterGraph(0);\n");

   // now do the video
   fprintf (fp, "VirtualDub.video.SetInputFormat(0);\n");
   fprintf (fp, "VirtualDub.video.SetOutputFormat(0);\n");
   fprintf (fp, "VirtualDub.video.SetMode(3);\n");
   //fprintf (fp, "VirtualDub.video.SetFrameRate(-1,2);\n");
   if (options.movievideo!=4)
   {
      fprintf (fp, "VirtualDub.video.SetFrameRate(%d,1);\n",(int)(1000000/refresh_rate));
      fprintf (fp, "VirtualDub.video.SetTargetFrameRate(30000,1001);\n"); // 29.97 fps
   }
   fprintf (fp, "VirtualDub.video.SetIVTC(0,0,-1,0);\n");
   fprintf (fp, "VirtualDub.video.SetRange(%d,0);\n", (int) (((double) bufframe) * 33.3667));	// # frames to skip / 29.97 * 1000
   fprintf (fp, "VirtualDub.video.filters.Clear();\n");

   switch (options.movievideo)
   {
      case 0:
	 fprintf (fp, "VirtualDub.video.SetCompression();\n");
	 break;
      case 1:			// divx
	 fprintf (fp,
		  "VirtualDub.video.SetCompression(0x78766964,0,10000,0);\n");
	 fprintf (fp,
		  "VirtualDub.video.SetCompData(356,\"MAEAAAAAAAAAAAAA4OYLAM0u8kcAAAAAAAAAAAAAAAAAAAAALAEAADIAAAAACT0AAAAwAAA"
		  "AJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFAAAAAAAAAAAAAAAAAAAAAQAAAAAAAACamZmZmZnJP5qZmZmZmck/AAAAAAAAAAAAAAAAgAIAAOA"
		  "BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4D8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAABkAAAAAAAAAAAAAAABAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAD/////AQAAAAAAAAAAAAAAAgAAAGM"
		  "6XGRpdngubG9nAGM6XHRlc3QuZGl2eABjOlxtdmluZm8uYmluAGM6XG5ld3JjLnR4dAA=\");\n");
	 break;
      case 2:
	 // cvid
	 fprintf (fp,
		  "VirtualDub.video.SetCompression(0x64697663,0,10000,0);\n");
	 fprintf (fp, "VirtualDub.video.SetCompData(4,\"Y29scg==\");\n");
	 break;
      case 3:
	 // xvid
#if 0
	 // original
	 fprintf (fp,
		  "VirtualDub.video.SetCompression(0x64697678,0,10000,0);\n");
	 fprintf (fp,
		  "VirtualDub.video.SetCompData(3012,\"AAAAAHIDAAA04ggAXHZpZGVvLnBhc3MALgBwAGEAcwBzAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAEAACh1bnJlc"
		  "3RyaWN0ZWQpAABpAGMAdABlAGQAKQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAADgAAAAAAAAAIERITFRcZGxESExUXGRscFBUWFxgaHB4VFhcYGhweIBYXGBocHiAjFxgaHB4gIyYZG"
		  "hweICMmKRscHiAjJiktEBESExQVFhcREhMUFRYXGBITFBUWFxgZExQVFhcYGhsUFRYXGRobHBUWFxgaGxweFhcYGhscHh8XGBkbHB4fI"
		  "QEAAAAAAAAAAQAAAAEAAAAAAAAAAQAAAAIAAACWAAAAZAAAAAEAAAABAAAAAAAAAAQAAAADAAAAAQAAAAEAAAAAAAAAAQAAAAAAAAAAA"
		  "AAAAAAAAGQAAAD0AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAABAAAABkAAAAZAAAAAEAAAAKAAAAAQAAABQAAAAAAAAAAAAAAAUAAAAFAAAABQAAAAAoCgAAAAAAAQAAA"
		  "AEAAAAeAAAAAAAAAAIAAAAAAAAAAAAAAIAAAAAAAAAABgAAAAEAAAABAAAAAAAAAAEAAAAsAQAAAAAAAAEAAAAfAAAAAQAAAB8AAAABA"
		  "AAAHwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\");\n");
#elsif 0
	 // revised 2-20-05
	 fprintf (fp,
		  "VirtualDub.video.SetCompression(0x64697678,0,10000,0);\n");
	 fprintf (fp,
		  "VirtualDub.video.SetCompData(3012,\"AAAAALwCAACQsggAXHZpZGVvLnBhc3MALgBwAGEAcwBzAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAMAACh1bnJlc"
		  "3RyaWN0ZWQpAABpAGMAdABlAGQAKQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAADgAAAAAAAAAIERITFRcZGxESExUXGRscFBUWFxgaHB4VFhcYGhweIBYXGBocHiAjFxgaHB4gIyYZGhweICMmK"
		  "RscHiAjJiktEBESExQVFhcREhMUFRYXGBITFBUWFxgZExQVFhcYGhsUFRYXGRobHBUWFxgaGxweFhcYGhscHh8XGBkbHB4fIQEAAAAAAAA"
		  "AAQAAAAEAAAAAAAAAAQAAAAIAAACWAAAAZAAAAAEAAAABAAAAAAAAAAQAAAADAAAAAQAAAAEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAGQAA"
		  "AD0AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAABkAAAAZAAAAAEAAAAKAAAAAQAAABQAAAAAA"
		  "AAAAAAAAAUAAAAFAAAABQAAAAAoCgAAAAAAAQAAAAEAAAAeAAAAAAAAAAIAAAAAAAAAAAAAAIAAAAAAAAAABgAAAAEAAAABAAAAAAAAAAE"
		  "AAAAsAQAAAAAAAAEAAAAfAAAAAQAAAB8AAAABAAAAHwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD3AAAAAAAAAAAAAAAAAAAAA"
		  "AAAAAAAAAAAAAAAAAAAAAAAAAABAAAA\");\n");
#else
	 // revised 2-02-06
	 fprintf (fp,
		  "VirtualDub.video.SetCompression(0x64697678,0,10000,0);\n");
         fprintf (fp,
                  "VirtualDub.video.SetCompData(3532,\"AAAAALwCAACQsggAXHZpZGVvLnBhc3MALgBwAGEAcwBzAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA6AMAACh1bnJlc3Ry"
                  "aWN0ZWQpAABpAGMAdABlAGQAKQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAEgAAAEdlbmVyYWwgcHVycG9zZQBwAHUAcgBwAG8AcwBlAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAIERITFRcZGxESExUXGRscFBUWFxgaHB4VFhc"
                  "YGhweIBYXGBocHiAjFxgaHB4gIyYZGhweICMmKRscHiAjJiktEBESExQVFhcREhMUFRYXGBITFBUWFxgZExQVFhcYGhsUFRYXGRobHBUW"
                  "FxgaGxweFhcYGhscHh8XGBkbHB4fIQEAAAAAAAAAAAAAAAEAAAAAAAAAAQAAAAIAAACWAAAAZAAAAAEAAAAAAAAABAAAAAMAAAABAAAAA"
                  "QAAAAAAAAABAAAAAAAAAAAAAAAAAAAAZAAAAPQBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAABkAAAAZAAAAAEAAAAKAAAAAQAAABQAAAAAAAAAAAAAAAUAAAAFAAA"
                  "ABQAAAAAoCgAAAAAAAQAAAAEAAAAeAAAAAAAAAAIAAAAAAAAAAAAAAIAAAAAAAAAAAAAAAAYAAAABAAAAAAAAAAEAAAAAAAAALAEAAAAA"
                  "AAABAAAAHwAAAAEAAAAfAAAAAQAAAB8AAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                  "AAAAAAAAAAAAAAAAQAAAA==\");\n");

#endif
	 break;
      case 4:
	 fp2 = fopen ("vcodec.dat", "rb");
	 if (fp2 == NULL)
	    break;
	 while (fread (tempbuff, 1, 1, fp2))
	    fwrite (tempbuff, 1, 1, fp);
	 fclose (fp2);
	 break;
      default:
	 break;
   }
   // The following line caused a problem in VirtualDub 1.6.4
   //fprintf(fp,"VirtualDub.video.SetDepth(24,24);\n");
   if (options.moviesquare)
   {
      fprintf (fp, "VirtualDub.video.filters.Add(\"resize\");\n");
      fprintf (fp, "VirtualDub.video.filters.instance[0].Config(%d,%d,1);\n",
         options.moviesquare,options.moviesquare);
   }
   else if ((movie_png_width & 1) && (movie_png_height & 1))
   {
      logerror ("detected non-standard screen width=%d, height=%d\n",
	      movie_png_width, movie_png_height);
      fprintf (fp, "VirtualDub.video.filters.Add(\"null transform\");\n");
      fprintf (fp,
	       "VirtualDub.video.filters.instance[0].SetClipping(0,0,1,1);\n");
   }
   else if (movie_png_width & 1)
   {
      logerror ("detected non-standard screen width=%d, height=%d\n",
	      movie_png_width, movie_png_height);
      fprintf (fp, "VirtualDub.video.filters.Add(\"null transform\");\n");
      fprintf (fp,
	       "VirtualDub.video.filters.instance[0].SetClipping(0,0,1,0);\n");
   }
   else if (movie_png_height & 1)
   {
      logerror ("detected non-standard screen width=%d, height=%d\n",
	      movie_png_width, movie_png_height);
      fprintf (fp, "VirtualDub.video.filters.Add(\"null transform\");\n");
      fprintf (fp,
	       "VirtualDub.video.filters.instance[0].SetClipping(0,0,0,1);\n");
   }

   fprintf (fp, "VirtualDub.subset.Clear();\n");
   fprintf (fp, "VirtualDub.subset.AddRange(0,%d);\n", curframe);
   fprintf (fp, "VirtualDub.project.ClearTextInfo();\n");
   if (options.avi_name==NULL)
      fprintf (fp, "VirtualDub.SaveAVI(\"output.avi\");\n");
   else
      fprintf (fp, "VirtualDub.SaveAVI(\"%s\");\n",options.avi_name);
   if (options.movieaudio!=3)
      fprintf (fp, "VirtualDub.audio.SetSource(1);\n");

   fprintf (fp, "VirtualDub.Close();\n");
   fprintf (fp, "\n");
   fclose (fp);
}

// get the md5 checksum of the image data
static void calculate_md5 (png_info *p, char *result)
{
   struct MD5Context md5c;
   unsigned char signature[16];

   MD5Init (&md5c);
   MD5Update(&md5c, p->fimage, p->width*p->height*p->bpp);
   MD5Final (signature, &md5c);
   sprintf (result,
	    "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
	    signature[0], signature[1], signature[2], signature[3],
	    signature[4], signature[5], signature[6], signature[7],
	    signature[8], signature[9], signature[10], signature[11],
	    signature[12], signature[13], signature[14], signature[15]);

   //logerror ("calculate_md5: result=%s\n", result);
}

static void free_bucket_list (void)
{
   int i;
   bucket_node *p, *q;

   for (i = 0; i < 256; i++)
   {
      p = bucket_list[i];
      while (p != NULL)
      {
	 q = p;
	 p = p->next;
	 free (q);
      }
      bucket_list[i] = NULL;
   }
}

int snap_is_black (png_info *p) 
{
   unsigned int sig_read = 0;
   int bit_depth, color_type, interlace_type;
   int max_sampled_r = 0;
   int max_sampled_g = 0;
   int max_sampled_b = 0;
   int min_sampled_r = 256;
   int min_sampled_g = 256;
   int min_sampled_b = 256;
   int retcode = 1;
   int x,y;
   int row;
   FILE *fp;
   unsigned char *src;
   char file_name[256];

   if (options.movieskipblack == 0)
      return 0;

   // if we are not detecting loops, don't slow the program down
   // by detecting black
   if (options.movieloops == 2)
      return 0;

   for (y = 0; y < p->height; y++)
   {
      src=p->fimage+y*p->rowbytes;
      for (x = 0; x < p->width; x++, src += 3)
      {
         if (options.movieskipblack == 1)
         {
            if (src[0] >= options.moviethreshold
                || src[1] >= options.moviethreshold
                || src[2] >= options.moviethreshold)
            {
               y = p->height;
               x = p->width;
               retcode = 0;
            }
         }
         else
         {
            if (src[0] > max_sampled_r)
               max_sampled_r = src[0];
            if (src[0] < min_sampled_r)
               min_sampled_r = src[0];
            if (src[1] > max_sampled_g)
               max_sampled_g = src[1];
            if (src[1] < min_sampled_g)
               min_sampled_g = src[1];
            if (src[2] > max_sampled_b)
               max_sampled_b = src[2];
            if (src[2] < min_sampled_b)
               min_sampled_b = src[2];
          }
      }
   }

   if (options.movieskipblack == 1)
      return retcode;

   logerror ("max sampled=%d,%d,%d, min sampled=%d,%d,%d\n",
	     max_sampled_r, max_sampled_g, max_sampled_b,
	     min_sampled_r, min_sampled_g, min_sampled_b);
   if (max_sampled_r - min_sampled_r < options.moviethreshold
       && max_sampled_g - min_sampled_g < options.moviethreshold
       && max_sampled_b - min_sampled_b < options.moviethreshold)
      return TRUE;
   else
      return FALSE;

}

int get_image_size(png_info *p, int *px, int *py)
{
   *px=p->width;
   *py=p->height;

   return 0;
}

static int write_chunk(FILE *fp, unsigned long chunk_type, unsigned char *chunk_data, unsigned long chunk_length)
{
        unsigned long crc;
        unsigned char v[4];
	int written;

	/* write length */
	convert_to_network_order(chunk_length, v);
        written = fwrite(v,1,4,fp);

	/* write type */
	convert_to_network_order(chunk_type, v);
        written += fwrite(v, 1,4,fp);

	/* calculate crc */
	crc=crc32(0, v, 4);
	if (chunk_length > 0)
	{
		/* write data */
                written += fwrite(chunk_data, 1,chunk_length,fp);
		crc=crc32(crc, chunk_data, chunk_length);
	}
	convert_to_network_order(crc, v);

	/* write crc */
        written += fwrite(v, 1,4,fp);

	if (written != 3*4+chunk_length)
	{
		logerror("Chunk write failed\n");
		return 0;
	}
	return 1;
}

int png_write_sig(FILE *fp)
{
	/* PNG Signature */
        if (fwrite(PNG_Signature, 1,8,fp) != 8)
	{
		logerror("PNG sig write failed\n");
		return 0;
	}
	return 1;
}

int png_write_datastream(FILE *fp, png_info *p)
{
        unsigned char ihdr[13];
        //png_text *pt;

	/* IHDR */
	convert_to_network_order(p->width, ihdr);
	convert_to_network_order(p->height, ihdr+4);
	*(ihdr+8) = p->bit_depth;
	*(ihdr+9) = p->color_type;
	*(ihdr+10) = p->compression_method;
	*(ihdr+11) = p->filter_method;
	*(ihdr+12) = p->interlace_method;
        //logerror("Type(%d) Color Depth(%d)\n", p->color_type,p->bit_depth);
	if (write_chunk(fp, PNG_CN_IHDR, ihdr, 13)==0)
		return 0;

        #if 0
	/* PLTE */
	if (p->num_palette > 0)
		if (write_chunk(fp, PNG_CN_PLTE, p->palette, p->num_palette*3)==0)
			return 0;
        #endif

	/* IDAT */
        /* write the compressed (p->zimage) data */
	if (write_chunk(fp, PNG_CN_IDAT, p->zimage, p->zlength)==0)
		return 0;

        #if 0
	/* tEXt */
	while (png_text_list)
	{
		pt = png_text_list;
                if (write_chunk(fp, PNG_CN_tEXt, (unsigned char *)pt->data, pt->length)==0)
			return 0;
		free (pt->data);

		png_text_list = pt->next;
		free (pt);
	}
        #endif

	/* IEND */
	if (write_chunk(fp, PNG_CN_IEND, NULL, 0)==0)
		return 0;

	return 1;
}

