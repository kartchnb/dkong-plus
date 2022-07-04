//	VirtualDub - Video processing and capture application
//	Copyright (C) 1998-2001 Avery Lee
//
//	This program is free software; you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation; either version 2 of the License, or
//	(at your option) any later version.
//
//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program; if not, write to the Free Software
//	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

#include "stdafx.h"

#include <windows.h>

#include "gui.h"
#include "crash.h"

#include <vd2/system/error.h>
#include <vd2/system/strutil.h>
#include <vd2/system/fraction.h>
#include <vd2/Riza/w32audiocodec.h>
#include "AudioFilterSystem.h"
#include "AudioSource.h"
#include "af_sink.h"

#include "audio.h"

AudioFormatConverter AudioPickConverter(const WAVEFORMATEX *src, bool to_16bit, bool to_stereo);

//////////////// no change converters /////////////////////////////////////

static void convert_audio_nochange8(void *dest, void *src, long count) {
	memcpy(dest, src, count);
}

static void convert_audio_nochange16(void *dest, void *src, long count) {
	memcpy(dest, src, count*2);
}

static void convert_audio_nochange32(void *dest, void *src, long count) {
	memcpy(dest, src, count*4);
}

//////////////// regular converters /////////////////////////////////////

static void convert_audio_mono8_to_mono16(void *dest, void *src, long count) {
	unsigned char *s = (unsigned char *)src;
	signed short *d = (signed short *)dest;

	do {
		*d++ = (signed short)((unsigned long)(*s++-0x80)<<8);
	} while(--count);
}

static void convert_audio_mono8_to_stereo8(void *dest, void *src, long count) {
	unsigned char c,*s = (unsigned char *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		c = *s++;
		*d++ = c;
		*d++ = c;
	} while(--count);
}

static void convert_audio_mono8_to_stereo16(void *dest, void *src, long count) {
	unsigned char *s = (unsigned char *)src;
	unsigned long c, *d = (unsigned long *)dest;

	do {
		c = ((*s++-0x80)&0xff) << 8;
		*d++ = c | (c<<16);
	} while(--count);
}

static void convert_audio_mono16_to_mono8(void *dest, void *src, long count) {
	signed short *s = (signed short *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		*d++ = (unsigned char)((((unsigned long)*s++)+0x8000)>>8);
	} while(--count);
}

static void convert_audio_mono16_to_stereo8(void *dest, void *src, long count) {
	signed short *s = (signed short *)src;
	unsigned char c, *d = (unsigned char *)dest;

	do {
		c = (unsigned char)((((unsigned long)*s++)+0x8000)>>8);
		*d++ = c;
		*d++ = c;
	} while(--count);
}

static void convert_audio_mono16_to_stereo16(void *dest, void *src, long count) {
	signed short *s = (signed short *)src;
	unsigned long *d = (unsigned long *)dest, c;

	do {
		c = 0xffff & *s++;
		*d++ = (c | (c<<16));
	} while(--count);
}

static void convert_audio_stereo8_to_mono8(void *dest, void *src, long count) {
	unsigned short *s = (unsigned short *)src;
	unsigned char *d = (unsigned char *)dest;
	unsigned long c;

	do {
		c = *s++;
		*d++ = (unsigned char)(((c&0xff) + (c>>8))/2);
	} while(--count);
}

static void convert_audio_stereo8_to_mono16(void *dest, void *src, long count) {
	unsigned short *s = (unsigned short *)src;
	signed short *d = (signed short *)dest;
	unsigned long c;

	do {
		c = *s++;
		*d++ = (signed short)((((c&0xff) + (c>>8))<<7)-0x8000);
	} while(--count);
}

static void convert_audio_stereo8_to_stereo16(void *dest, void *src, long count) {
	unsigned short c,*s = (unsigned short *)src;
	unsigned long *d = (unsigned long *)dest;

	do {
		c = *s++;
		*d++ = ((unsigned long)((c-0x80)&0xff)<<8) | ((unsigned long)((c&0xff00)-0x8000)<<16);
	} while(--count);
}

static void convert_audio_stereo16_to_mono8(void *dest, void *src, long count) {
	unsigned long c, *s = (unsigned long *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		c = *s++;
		*d++ = (unsigned char)(((((c&0xffff)+0xffff8000)^0xffff8000) + ((signed long)c>>16) + 0x10000)>>9);
	} while(--count);
}

static void convert_audio_stereo16_to_mono16(void *dest, void *src, long count) {
	unsigned long c, *s = (unsigned long *)src;
	signed short *d = (signed short *)dest;

	do {
		c = *s++;
		*d++ = (signed short)(((((c&0xffff)+0xffff8000)^0xffff8000) + ((signed long)c>>16))/2);
	} while(--count);
}

static void convert_audio_stereo16_to_stereo8(void *dest, void *src, long count) {
	unsigned long c,*s = (unsigned long *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		c = *s++;
		*d++ = (unsigned char)((((unsigned long)(c & 0xffff))+0x8000)>>8);
		*d++ = (unsigned char)((((unsigned long)(c>>16))+0x8000)>>8);
	} while(--count);
}

static void convert_audio_dual8_to_mono8(void *dest, void *src, long count) {
	const unsigned char *s = (unsigned char *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		*d++ = *s;
		s+=2;
	} while(--count);
}

static void convert_audio_dual8_to_mono16(void *dest, void *src, long count) {
	unsigned char *s = (unsigned char *)src;
	signed short *d = (signed short *)dest;

	do {
		*d++ = (signed short)((unsigned long)(*s-0x80)<<8);
		s += 2;
	} while(--count);
}

static void convert_audio_dual16_to_mono8(void *dest, void *src, long count) {
	signed short *s = (signed short *)src;
	unsigned char *d = (unsigned char *)dest;

	do {
		*d++ = (unsigned char)((((unsigned long)*s)+0x8000)>>8);
		s += 2;
	} while(--count);
}

static void convert_audio_dual16_to_mono16(void *dest, void *src, long count) {
	const signed short *s = (signed short *)src;
	signed short *d = (signed short *)dest;

	do {
		*d++ = *s;
		s+=2;
	} while(--count);
}

////////////////////////////////////////////

static const AudioFormatConverter acv[]={
	convert_audio_nochange8,
	convert_audio_mono8_to_mono16,
	convert_audio_mono8_to_stereo8,
	convert_audio_mono8_to_stereo16,
	convert_audio_mono16_to_mono8,
	convert_audio_nochange16,
	convert_audio_mono16_to_stereo8,
	convert_audio_mono16_to_stereo16,
	convert_audio_stereo8_to_mono8,
	convert_audio_stereo8_to_mono16,
	convert_audio_nochange16,
	convert_audio_stereo8_to_stereo16,
	convert_audio_stereo16_to_mono8,
	convert_audio_stereo16_to_mono16,
	convert_audio_stereo16_to_stereo8,
	convert_audio_nochange32,
};

static const AudioFormatConverter acv2[]={
	convert_audio_nochange8,
	convert_audio_mono8_to_mono16,
	convert_audio_mono16_to_mono8,
	convert_audio_nochange16,
	convert_audio_dual8_to_mono8,
	convert_audio_dual8_to_mono16,
	convert_audio_dual16_to_mono8,
	convert_audio_dual16_to_mono16,
};

AudioFormatConverter AudioPickConverter(const WAVEFORMATEX *src, bool to_16bit, bool to_stereo) {
	return acv[
			  (src->nChannels>1 ? 8 : 0)
			 +(src->wBitsPerSample>8 ? 4 : 0)
			 +(to_stereo ? 2 : 0)
			 +(to_16bit ? 1 : 0)
		];
}

AudioFormatConverter AudioPickConverterSingleChannel(const WAVEFORMATEX *src, bool to_16bit) {
	return acv2[
			  (src->nChannels>1 ? 4 : 0)
			 +(src->wBitsPerSample>8 ? 2 : 0)
			 +(to_16bit ? 1 : 0)
		];
}

///////////////////////////////////

AudioStream::AudioStream() {
	format = NULL;
	format_len = 0;
	samples_read = 0;
	stream_limit = 0x7FFFFFFFFFFFFFFF;
}

AudioStream::~AudioStream() {
	freemem(format);
}

WAVEFORMATEX *AudioStream::AllocFormat(long len) {
	if (format) { freemem(format); format = 0; }

	if (!(format = (WAVEFORMATEX *)allocmem(len)))
		throw MyError("AudioStream: Out of memory");

    format_len = len;

	return format;
}

WAVEFORMATEX *AudioStream::GetFormat() {
	return format;
}

long AudioStream::GetFormatLen() {
	return format_len;
}

sint64 AudioStream::GetSampleCount() {
	return samples_read;
}

sint64 AudioStream::GetLength() {
	return stream_limit < stream_len ? stream_limit : stream_len;
}

long AudioStream::Read(void *buffer, long max_samples, long *lplBytes) {
	long actual;

	if (max_samples <= 0) {
		*lplBytes = 0;
		return 0;
	}

	if (samples_read >= stream_limit) {
		*lplBytes = 0;
		return 0;
	}

    if (samples_read + max_samples > stream_limit) {
		sint64 limit = stream_limit - samples_read;

		if (limit > 0x0fffffff)		// clamp so we don't issue a ridiculous request
			limit = 0x0fffffff;
		max_samples = (long)limit;
	}

	actual = _Read(buffer, max_samples, lplBytes);

	_ASSERT(actual >= 0 && actual <= max_samples);

	samples_read += actual;

	return actual;
}

bool AudioStream::Skip(sint64 samples) {
	return false;
}

void AudioStream::SetLimit(sint64 limit) {
	_RPT1(0,"AudioStream: limit set to %I64d\n", limit);
	stream_limit = limit;
}

void AudioStream::SetSource(AudioStream *src) {
	source = src;
	stream_len = src->GetLength();
}

bool AudioStream::isEnd() {
	return samples_read >= stream_limit || _isEnd();
}

long AudioStream::_Read(void *buffer, long max_samples, long *lplBytes) {
	*lplBytes = 0;

	return 0;
}

bool AudioStream::_isEnd() {
	return FALSE;
}

void AudioStream::Seek(VDPosition pos) {
	VDASSERT(pos >= 0);

	if (pos > 0) {
		VDASSERT(Skip(pos - GetSampleCount()));
	}
}

////////////////////

AudioStreamSource::AudioStreamSource(AudioSource *src, sint64 first_samp, sint64 max_samples, bool allow_decompression) : AudioStream() {
	WAVEFORMATEX *iFormat = src->getWaveFormat();
	WAVEFORMATEX *oFormat;

	fZeroRead = false;
	mPreskip = 0;

	if (max_samples < 0)
		max_samples = 0;

	if (iFormat->wFormatTag != WAVE_FORMAT_PCM && allow_decompression) {
		mCodec.Init(iFormat, NULL);

		const unsigned oflen = mCodec.GetOutputFormatSize();

		memcpy(AllocFormat(oflen), mCodec.GetOutputFormat(), oflen);

		oFormat = GetFormat();
	} else {

		// FIX: If we have a PCMWAVEFORMAT stream, artificially cut the format size
		//		to sizeof(PCMWAVEFORMAT).  LSX-MPEG Encoder doesn't like large PCM
		//		formats!

		if (iFormat->wFormatTag == WAVE_FORMAT_PCM) {
			oFormat = AllocFormat(sizeof(PCMWAVEFORMAT));
			memcpy(oFormat, iFormat, sizeof(PCMWAVEFORMAT));
		} else {
			oFormat = AllocFormat(src->getFormatLen());
			memcpy(oFormat, iFormat, GetFormatLen());
		}
	}

	mPrefill = 0;
	if (first_samp < 0) {
		mPrefill = -first_samp;
		first_samp = 0;
	}

	aSrc = src;
	stream_len = std::min<sint64>(max_samples, aSrc->getEnd() - first_samp);

	if (mCodec.IsInitialized()) {
		stream_len = MulDiv(stream_len, GetFormat()->nSamplesPerSec * aSrc->getWaveFormat()->nBlockAlign, aSrc->getWaveFormat()->nAvgBytesPerSec);
	}

	cur_samp = first_samp;
	end_samp = first_samp + max_samples;

}

AudioStreamSource::~AudioStreamSource() {
	mCodec.Shutdown();
}

long AudioStreamSource::_Read(void *buffer, long max_samples, long *lplBytes) {
	LONG lAddedBytes=0;
	LONG lAddedSamples=0;
	int err;
	MMRESULT res;

	// add filler samples as necessary

	if (mPrefill > 0) {
		long tc = max_samples;
		const int nBlockAlign = aSrc->getWaveFormat()->nBlockAlign;

		if (tc > mPrefill)
			tc = (long)mPrefill;

		if (GetFormat()->nChannels > 1)
			memset(buffer, 0, nBlockAlign*tc);
		else
			memset(buffer, 0x80, nBlockAlign*tc);

		buffer = (char *)buffer + nBlockAlign*tc;

		max_samples -= tc;
		lAddedBytes = tc*nBlockAlign;
		lAddedSamples = tc;
		mPrefill -= tc;
	}

	VDASSERT(cur_samp >= 0);

	// read actual samples

	if (mCodec.IsInitialized()) {
		uint32 ltActualBytes, ltActualSamples;
		LONG lBytesLeft = max_samples * GetFormat()->nBlockAlign;
		LONG lTotalBytes = lBytesLeft;
		const int nBlockAlign = aSrc->getWaveFormat()->nBlockAlign;

		while(lBytesLeft > 0) {
			// hmm... data still in the output buffer?
			if (mPreskip) {
				unsigned actual = mCodec.CopyOutput(NULL, mPreskip);

				if (actual) {
					VDASSERT(actual <= mPreskip);
					mPreskip -= actual;
					continue;
				}
			} else {
				unsigned actual = mCodec.CopyOutput(buffer, lBytesLeft);

				VDASSERT(actual <= lBytesLeft);

				if (actual) {
					buffer = (void *)((char *)buffer + actual);
					lBytesLeft -= actual;
					continue;
				}
			}

			// fill the input buffer up... if we haven't gotten a zero yet.
			if (!fZeroRead) {
				unsigned totalBytes = 0;
				unsigned bytes;
				void *dst = mCodec.LockInputBuffer(bytes);

				bool successfulRead = false;

				if (bytes > 0) {
					do {
						long to_read = bytes/nBlockAlign;

						if (to_read > end_samp - cur_samp)
							to_read = (long)(end_samp - cur_samp);

						err = aSrc->read(cur_samp, to_read, dst, bytes, &ltActualBytes, &ltActualSamples);

						if (err != AVIERR_OK && err != AVIERR_BUFFERTOOSMALL) {
							if (err == AVIERR_FILEREAD)
								throw MyError("Audio samples %lu-%lu could not be read in the source.  The file may be corrupted.", cur_samp, cur_samp+to_read-1);
							else
								throw MyAVIError("AudioStreamSource", err);
						}

						if (!ltActualBytes)
							break;

						totalBytes += ltActualBytes;
						bytes -= ltActualBytes;
						cur_samp += ltActualSamples;
						dst = (char *)dst + ltActualBytes;

						successfulRead = true;

					} while(bytes > 0 && err != AVIERR_BUFFERTOOSMALL && cur_samp < end_samp);
				}

				mCodec.UnlockInputBuffer(totalBytes);

				if (!successfulRead)
					fZeroRead = true;
			}

			if (!mCodec.Convert(fZeroRead, true))
				break;
		};

		*lplBytes = (lTotalBytes - lBytesLeft) + lAddedBytes;

		return *lplBytes / GetFormat()->nBlockAlign + lAddedSamples;
	} else {
		uint32 lSamples=0;

		if (max_samples > end_samp - cur_samp)
			max_samples = (long)(end_samp - cur_samp);

		if (max_samples > 0) {
			uint32 bytes;
			int err = aSrc->read(cur_samp, max_samples, buffer, 0x7FFFFFFFL, &bytes, &lSamples);
			*lplBytes = bytes;

			if (AVIERR_OK != err) {
				if (err == AVIERR_FILEREAD)
					throw MyError("Audio samples %lu-%lu could not be read in the source.  The file may be corrupted.", cur_samp, cur_samp+max_samples-1);
				else
					throw MyAVIError("AudioStreamSource", err);
			}

			if (!lSamples) fZeroRead = true;
		} else
			lSamples = *lplBytes = 0;

		*lplBytes += lAddedBytes;

		cur_samp += lSamples;

		return lSamples + lAddedSamples;
	}
}

bool AudioStreamSource::Skip(sint64 samples) {

	if (mPrefill > 0) {
		sint64 tc = std::min<sint64>(mPrefill, samples);

		mPrefill -= tc;
		samples -= tc;

		if (samples <= 0)
			return true;
	}

	// nBlockAlign = bytes per block.
	//
	// nAvgBytesPerSec / nBlockAlign = blocks per second.
	// nSamplesPerSec * nBlockAlign / nAvgBytesPerSec = samples per block.

	if (mCodec.IsInitialized()) {
		const WAVEFORMATEX *pwfex = aSrc->getWaveFormat();

		if (samples < MulDiv(4*pwfex->nBlockAlign, pwfex->nSamplesPerSec, pwfex->nAvgBytesPerSec)) {
			mPreskip += samples*GetFormat()->nBlockAlign;
			return true;
		}

		// Flush input and output buffers.
		mCodec.Restart();

		// Trigger a reseek.
		long new_pos = ((samples_read + samples) * (__int64)pwfex->nAvgBytesPerSec) / ((__int64)pwfex->nBlockAlign*pwfex->nSamplesPerSec);

		if (new_pos > cur_samp)
			cur_samp = new_pos;

		// Skip fractional samples.
		long samp_start = (new_pos * (__int64)pwfex->nSamplesPerSec*pwfex->nBlockAlign) / pwfex->nAvgBytesPerSec;

		mPreskip = ((samples_read + samples) - samp_start)*GetFormat()->nBlockAlign;

		samples_read = samp_start;

		return true;

	} else {
		cur_samp += samples;
		samples_read += samples;

		return true;
	}
}

bool AudioStreamSource::_isEnd() {
	return (cur_samp >= end_samp || fZeroRead) && (!mCodec.IsInitialized() || !mCodec.GetOutputLevel());
}

void AudioStreamSource::Seek(VDPosition pos) {
	mPrefill = 0;
	if (pos < 0) {
		mPrefill = -pos;
		pos = 0;
	}

	fZeroRead = false;
	mPreskip = 0;

	if (mCodec.IsInitialized()) {
		const WAVEFORMATEX *pwfex = aSrc->getWaveFormat();

		// flush decompression buffers
		mCodec.Restart();

		// recompute new position
		cur_samp = (long)(pos * (sint64)pwfex->nAvgBytesPerSec / ((sint64)pwfex->nBlockAlign*pwfex->nSamplesPerSec));

		mPreskip = pwfex->nBlockAlign * (long)(pos - cur_samp * ((sint64)pwfex->nBlockAlign*pwfex->nSamplesPerSec) / (sint64)pwfex->nAvgBytesPerSec);
	} else {
		cur_samp = pos;
	}

	if (cur_samp > end_samp)
		cur_samp = end_samp;
}



///////////////////////////////////////////////////////////////////////////
//
//		AudioStreamConverter
//
//		This audio filter handles changes in format between 8/16-bit
//		and mono/stereo.
//
///////////////////////////////////////////////////////////////////////////



AudioStreamConverter::AudioStreamConverter(AudioStream *src, bool to_16bit, bool to_stereo_or_right, bool single_only) {
	WAVEFORMATEX *iFormat = src->GetFormat();
	WAVEFORMATEX *oFormat;
	bool to_stereo = single_only ? false : to_stereo_or_right;

	memcpy(oFormat = AllocFormat(src->GetFormatLen()), iFormat, src->GetFormatLen());

	oFormat->nChannels = to_stereo ? 2 : 1;
	oFormat->wBitsPerSample = to_16bit ? 16 : 8;

	bytesPerInputSample = (iFormat->nChannels>1 ? 2 : 1)
						* (iFormat->wBitsPerSample>8 ? 2 : 1);

	bytesPerOutputSample = (to_stereo ? 2 : 1)
						 * (to_16bit ? 2 : 1);

	offset = 0;

	if (single_only) {
		convRout = AudioPickConverterSingleChannel(iFormat, to_16bit);

		if (to_stereo_or_right && iFormat->nChannels>1) {
			offset = 1;

			if (iFormat->wBitsPerSample>8)
				offset = 2;
		}
	} else
		convRout = AudioPickConverter(iFormat, to_16bit, to_stereo);
	SetSource(src);

	oFormat->nAvgBytesPerSec = oFormat->nSamplesPerSec * bytesPerOutputSample;
	oFormat->nBlockAlign = bytesPerOutputSample;


	if (!(cbuffer = allocmem(bytesPerInputSample * BUFFER_SIZE)))
		throw MyError("AudioStreamConverter: out of memory");
}

AudioStreamConverter::~AudioStreamConverter() {
	freemem(cbuffer);
}

long AudioStreamConverter::_Read(void *buffer, long samples, long *lplBytes) {
	long lActualSamples=0;

	while(samples>0) {
		long srcSamples;
		long lBytes;

		// figure out how many source samples we need

		srcSamples = samples;

		if (srcSamples > BUFFER_SIZE) srcSamples = BUFFER_SIZE;

		srcSamples = source->Read(cbuffer, srcSamples, &lBytes);

		if (!srcSamples) break;

		convRout(buffer, (char *)cbuffer + offset, srcSamples);

		buffer = (void *)((char *)buffer + bytesPerOutputSample * srcSamples);
		lActualSamples += srcSamples;
		samples -= srcSamples;

	}

	*lplBytes = lActualSamples * bytesPerOutputSample;

	return lActualSamples;
}

bool AudioStreamConverter::_isEnd() {
	return source->isEnd();
}

bool AudioStreamConverter::Skip(sint64 samples) {
	return source->Skip(samples);
}



///////////////////////////////////////////////////////////////////////////
//
//		AudioStreamResampler
//
//		This audio filter handles changes in sampling rate.
//
///////////////////////////////////////////////////////////////////////////

static long audio_pointsample_8(void *dst, void *src, long accum, long samp_frac, long cnt) {
	unsigned char *d = (unsigned char *)dst;
	unsigned char *s = (unsigned char *)src;

	do {
		*d++ = s[accum>>19];
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_pointsample_16(void *dst, void *src, long accum, long samp_frac, long cnt) {
	unsigned short *d = (unsigned short *)dst;
	unsigned short *s = (unsigned short *)src;

	do {
		*d++ = s[accum>>19];
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_pointsample_32(void *dst, void *src, long accum, long samp_frac, long cnt) {
	unsigned long *d = (unsigned long *)dst;
	unsigned long *s = (unsigned long *)src;

	do {
		*d++ = s[accum>>19];
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_downsample_mono8(void *dst, void *src, long *filter_bank, int filter_width, long accum, long samp_frac, long cnt) {
	unsigned char *d = (unsigned char *)dst;
	unsigned char *s = (unsigned char *)src;

	do {
		long sum = 0;
		int w;
		long *fb_ptr;
		unsigned char *s_ptr;

		w = filter_width;
		fb_ptr = filter_bank + filter_width * ((accum>>11)&0xff);
		s_ptr = s + (accum>>19);
		do {
			sum += *fb_ptr++ * (int)*s_ptr++;
		} while(--w);

		if (sum < 0)
			*d++ = 0;
		else if (sum > 0x3fffff)
			*d++ = 0xff;
		else
			*d++ = (unsigned char)((sum + 0x2000)>>14);

		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_downsample_mono16(void *dst, void *src, long *filter_bank, int filter_width, long accum, long samp_frac, long cnt) {
	signed short *d = (signed short *)dst;
	signed short *s = (signed short *)src;

	do {
		long sum = 0;
		int w;
		long *fb_ptr;
		signed short *s_ptr;

		w = filter_width;
		fb_ptr = filter_bank + filter_width * ((accum>>11)&0xff);
		s_ptr = s + (accum>>19);
		do {
			sum += *fb_ptr++ * (int)*s_ptr++;
		} while(--w);

		if (sum < -0x20000000)
			*d++ = -0x8000;
		else if (sum > 0x1fffffff)
			*d++ = 0x7fff;
		else
			*d++ = (signed short)((sum + 0x2000)>>14);

		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_downsample_stereo8(void *dst, void *src, long *filter_bank, int filter_width, long accum, long samp_frac, long cnt) {
	unsigned char *d = (unsigned char *)dst;
	unsigned char *s = (unsigned char *)src;

	do {
		long sum_l = 0, sum_r = 0;
		int w;
		long *fb_ptr;
		unsigned char *s_ptr;

		w = filter_width;
		fb_ptr = filter_bank + filter_width * ((accum>>11)&0xff);
		s_ptr = s + (accum>>19)*2;
		do {
			long f = *fb_ptr++;

			sum_l += f * (int)*s_ptr++;
			sum_r += f * (int)*s_ptr++;
		} while(--w);

		if (sum_l < 0)
			*d++ = 0;
		else if (sum_l > 0x3fffff)
			*d++ = 0xff;
		else
			*d++ = (unsigned char)((sum_l + 0x2000)>>14);

		if (sum_r < 0)
			*d++ = 0;
		else if (sum_r > 0x3fffff)
			*d++ = 0xff;
		else
			*d++ = (unsigned char)((sum_r + 0x2000)>>14);

		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_downsample_stereo16(void *dst, void *src, long *filter_bank, int filter_width, long accum, long samp_frac, long cnt) {
	signed short *d = (signed short *)dst;
	signed short *s = (signed short *)src;

	do {
		long sum_l = 0, sum_r = 0;
		int w;
		long *fb_ptr;
		signed short *s_ptr;

		w = filter_width;
		fb_ptr = filter_bank + filter_width * ((accum>>11)&0xff);
		s_ptr = s + (accum>>19)*2;
		do {
			long f = *fb_ptr++;

			sum_l += f * (int)*s_ptr++;
			sum_r += f * (int)*s_ptr++;
		} while(--w);

		if (sum_l < -0x20000000)
			*d++ = -0x8000;
		else if (sum_l > 0x1fffffff)
			*d++ = 0x7fff;
		else
			*d++ = (signed short)((sum_l + 0x2000)>>14);

		if (sum_r < -0x20000000)
			*d++ = -0x8000;
		else if (sum_r > 0x1fffffff)
			*d++ = 0x7fff;
		else
			*d++ = (signed short)((sum_r + 0x2000)>>14);

		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_upsample_mono8(void *dst, void *src, long accum, long samp_frac, long cnt) {
	unsigned char *d = (unsigned char *)dst;
	unsigned char *s = (unsigned char *)src;

	do {
		unsigned char *s_ptr = s + (accum>>19);
		long frac = (accum>>3) & 0xffff;

		*d++ = (unsigned char)(((int)s_ptr[0] * (0x10000 - frac) + (int)s_ptr[1] * frac) >> 16);
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_upsample_mono16(void *dst, void *src, long accum, long samp_frac, long cnt) {
	signed short *d = (signed short *)dst;
	signed short *s = (signed short *)src;

	do {
		signed short *s_ptr = s + (accum>>19);
		long frac = (accum>>3) & 0xffff;

		*d++ = (signed short)(((int)s_ptr[0] * (0x10000 - frac) + (int)s_ptr[1] * frac) >> 16);
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_upsample_stereo8(void *dst, void *src, long accum, long samp_frac, long cnt) {
	unsigned char *d = (unsigned char *)dst;
	unsigned char *s = (unsigned char *)src;

	do {
		unsigned char *s_ptr = s + (accum>>19)*2;
		long frac = (accum>>3) & 0xffff;

		*d++ = (unsigned char)(((int)s_ptr[0] * (0x10000 - frac) + (int)s_ptr[2] * frac) >> 16);
		*d++ = (unsigned char)(((int)s_ptr[1] * (0x10000 - frac) + (int)s_ptr[3] * frac) >> 16);
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static long audio_upsample_stereo16(void *dst, void *src, long accum, long samp_frac, long cnt) {
	signed short *d = (signed short *)dst;
	signed short *s = (signed short *)src;

	do {
		signed short *s_ptr = s + (accum>>19)*2;
		long frac = (accum>>3) & 0xffff;

		*d++ = (signed short)(((int)s_ptr[0] * (0x10000 - frac) + (int)s_ptr[2] * frac) >> 16);
		*d++ = (signed short)(((int)s_ptr[1] * (0x10000 - frac) + (int)s_ptr[3] * frac) >> 16);
		accum += samp_frac;
	} while(--cnt);

	return accum;
}

static int permute_index(int a, int b) {
	return (b-(a>>8)-1) + (a&255)*b;
}

static void make_downsample_filter(long *filter_bank, int filter_width, long samp_frac) {
	int i, j, v;
	double filt_max;
	double filtwidth_frac;

	filtwidth_frac = samp_frac/2048.0;

	filter_bank[filter_width-1] = 0;

	filt_max = (16384.0 * 524288.0) / samp_frac;

	for(i=0; i<128*filter_width; i++) {
		int y = 0;
		double d = i / filtwidth_frac;

		if (d<1.0)
			y = VDRoundToInt(filt_max*(1.0 - d));

		filter_bank[permute_index(128*filter_width + i, filter_width)]
			= filter_bank[permute_index(128*filter_width - i, filter_width)]
			= y;
	}

	// Normalize the filter to correct for integer roundoff errors

	for(i=0; i<256*filter_width; i+=filter_width) {
		v=0;
		for(j=0; j<filter_width; j++)
			v += filter_bank[i+j];

//		_RPT2(0,"error[%02x] = %04x\n", i/filter_width, 0x4000 - v);

		v = (0x4000 - v)/filter_width;
		for(j=0; j<filter_width; j++)
			filter_bank[i+j] += v;
	}
}

AudioStreamResampler::AudioStreamResampler(AudioStream *src, long new_rate, bool integral_conversion, bool hi_quality) : AudioStream() {
	WAVEFORMATEX *iFormat = src->GetFormat();
	WAVEFORMATEX *oFormat;

	memcpy(oFormat = AllocFormat(src->GetFormatLen()), iFormat, src->GetFormatLen());

	if (oFormat->nChannels>1)
		if (oFormat->wBitsPerSample>8) {
			ptsampleRout = audio_pointsample_32;
			upsampleRout = audio_upsample_stereo16;
			dnsampleRout = audio_downsample_stereo16;
		} else {
			ptsampleRout = audio_pointsample_16;
			upsampleRout = audio_upsample_stereo8;
			dnsampleRout = audio_downsample_stereo8;
		}
	else
		if (oFormat->wBitsPerSample>8) {
			ptsampleRout = audio_pointsample_16;
			upsampleRout = audio_upsample_mono16;
			dnsampleRout = audio_downsample_mono16;
		} else {
			ptsampleRout = audio_pointsample_8;
			upsampleRout = audio_upsample_mono8;
			dnsampleRout = audio_downsample_mono8;
		}

	SetSource(src);

	bytesPerSample = (iFormat->nChannels>1 ? 2 : 1)
						* (iFormat->wBitsPerSample>8 ? 2 : 1);

	_RPT2(0,"AudioStreamResampler: converting from %ldHz to %ldHz\n", iFormat->nSamplesPerSec, new_rate);

	if (integral_conversion)
		if (new_rate > iFormat->nSamplesPerSec)
//			samp_frac = MulDiv(0x10000, new_rate + iFormat->nSamplesPerSec/2, iFormat->nSamplesPerSec);
			samp_frac = 0x80000 / ((new_rate + iFormat->nSamplesPerSec/2) / iFormat->nSamplesPerSec); 
		else
			samp_frac = 0x80000 * ((iFormat->nSamplesPerSec + new_rate/2) / new_rate);
	else
		samp_frac = MulDiv(iFormat->nSamplesPerSec, 0x80000L, new_rate);

	stream_len = MulDiv(stream_len, 0x80000L, samp_frac);

	oFormat->nSamplesPerSec = MulDiv(iFormat->nSamplesPerSec, 0x80000L, samp_frac);
	oFormat->nAvgBytesPerSec = oFormat->nSamplesPerSec * bytesPerSample;
	oFormat->nBlockAlign = bytesPerSample;

	holdover = 0;
	filter_bank = NULL;
	filter_width = 1;
	accum=0;
	fHighQuality = hi_quality;

	if (!(cbuffer = allocmem(bytesPerSample * BUFFER_SIZE)))
		throw MyMemoryError();

	// Initialize the buffer.

	if (oFormat->wBitsPerSample>8)
		memset(cbuffer, 0x00, bytesPerSample * BUFFER_SIZE);
	else
		memset(cbuffer, 0x80, bytesPerSample * BUFFER_SIZE);

	// If this is a high-quality downsample, allocate memory for the filter bank

	if (hi_quality) {
		if (samp_frac>0x80000) {

			// HQ downsample: allocate filter bank

			filter_width = ((samp_frac + 0x7ffff)>>19)<<1;

			if (!(filter_bank = new long[filter_width * 256])) {
				freemem(cbuffer);
				throw MyMemoryError();
			}

			make_downsample_filter(filter_bank, filter_width, samp_frac);

			// Clear lower samples

			if (oFormat->wBitsPerSample>8)
				memset(cbuffer, 0, bytesPerSample*filter_width);
			else
				memset(cbuffer, 0x80, bytesPerSample*filter_width);

			holdover = filter_width/2;
		}
	}
}

AudioStreamResampler::~AudioStreamResampler() {
	freemem(cbuffer);
	delete filter_bank;
}

long AudioStreamResampler::_Read(void *buffer, long samples, long *lplBytes) {

	if (samp_frac == 0x80000)
		return source->Read(buffer, samples, lplBytes);

	if (samp_frac < 0x80000)
		return Upsample(buffer, samples, lplBytes);
	else
		return Downsample(buffer, samples, lplBytes);
}


long AudioStreamResampler::Upsample(void *buffer, long samples, long *lplBytes) {
	long lActualSamples=0;

	// Upsampling: producing more output samples than input
	//
	// There are two issues we need to watch here:
	//
	//	o  An input sample can be read more than once.  In particular, even
	//	   when point sampling, we may need the last input sample again.
	//
	//	o  When interpolating (HQ), we need one additional sample.

	while(samples>0) {
		long srcSamples, dstSamples;
		long lBytes;
		int holdover = 0;

		// A negative accum value indicates that we need to reprocess a sample.
		// The last iteration should have left it at the bottom of the buffer
		// for us.  In interpolation mode, we'll always have at least a 1
		// sample overlap.

		if (accum<0) {
			holdover = 1;
			accum += 0x80000;
		}

		if (fHighQuality)
			++holdover;

		// figure out how many source samples we need

		srcSamples = (long)(((__int64)samp_frac*(samples-1) + accum) >> 19) + 1 - holdover;

		if (fHighQuality)
			++srcSamples;

		if (srcSamples > BUFFER_SIZE-holdover) srcSamples = BUFFER_SIZE-holdover;

		srcSamples = source->Read((char *)cbuffer + holdover * bytesPerSample, srcSamples, &lBytes);

		if (!srcSamples) break;

		srcSamples += holdover;

		// figure out how many destination samples we'll get out of what we read

		if (fHighQuality)
			dstSamples = ((srcSamples<<19) - accum - 0x80001)/samp_frac + 1;
		else
			dstSamples = ((srcSamples<<19) - accum - 1)/samp_frac + 1;

		if (dstSamples > samples)
			dstSamples = samples;

		if (dstSamples>=1) {

			if (fHighQuality)
				accum = upsampleRout(buffer, cbuffer, accum, samp_frac, dstSamples);
			else
				accum = ptsampleRout(buffer, cbuffer, accum, samp_frac, dstSamples);

			buffer = (void *)((char *)buffer + bytesPerSample * dstSamples);
			lActualSamples += dstSamples;
			samples -= dstSamples;
		}

		if (fHighQuality)
			accum -= ((srcSamples-1)<<19);
		else
			accum -= (srcSamples<<19);

		// do we need to hold a sample over?

		if (fHighQuality)
			if (accum<0)
				memcpy(cbuffer, (char *)cbuffer + (srcSamples-2)*bytesPerSample, bytesPerSample*2);
			else
				memcpy(cbuffer, (char *)cbuffer + (srcSamples-1)*bytesPerSample, bytesPerSample);
		else if (accum<0)
			memcpy(cbuffer, (char *)cbuffer + (srcSamples-1)*bytesPerSample, bytesPerSample);
	}

	*lplBytes = lActualSamples * bytesPerSample;

//	_RPT2(0,"Converter: %ld samples, %ld bytes\n", lActualSamples, *lplBytes);

	return lActualSamples;
}

long AudioStreamResampler::Downsample(void *buffer, long samples, long *lplBytes) {
	long lActualSamples=0;

	// Downsampling is even worse because we have overlap to the left and to the
	// right of the interpolated point.
	//
	// We need (n/2) points to the left and (n/2-1) points to the right.

	while(samples>0) {
		long srcSamples, dstSamples;
		long lBytes;
		int nhold;

		// Figure out how many source samples we need.
		//
		// To do this, compute the highest fixed-point accumulator we'll reach.
		// Truncate that, and add the filter width.  Then subtract however many
		// samples are sitting at the bottom of the buffer.

		srcSamples = (long)(((__int64)samp_frac*(samples-1) + accum) >> 19) + filter_width - holdover;

		// Don't exceed the buffer (BUFFER_SIZE - holdover).

		if (srcSamples > BUFFER_SIZE - holdover)
			srcSamples = BUFFER_SIZE - holdover;

		// Read into buffer.

		srcSamples = source->Read((char *)cbuffer + holdover*bytesPerSample, srcSamples, &lBytes);

		if (!srcSamples) break;

		// Figure out how many destination samples we'll get out of what we
		// read.  We'll have (srcSamples+holdover) bytes, so the maximum
		// fixed-pt accumulator we can hit is
		// (srcSamples+holdover-filter_width)<<16 + 0xffff.

		dstSamples = (((srcSamples+holdover-filter_width)<<19) + 0x7ffff - accum) / samp_frac + 1;

		if (dstSamples > samples)
			dstSamples = samples;

		if (dstSamples>=1) {
			if (filter_bank)
				accum = dnsampleRout(buffer, cbuffer, filter_bank, filter_width, accum, samp_frac, dstSamples);
			else
				accum = ptsampleRout(buffer, cbuffer, accum, samp_frac, dstSamples);

			buffer = (void *)((char *)buffer + bytesPerSample * dstSamples);
			lActualSamples += dstSamples;
			samples -= dstSamples;
		}

		// We're "shifting" the new samples down to the bottom by discarding
		// all the samples in the buffer, so adjust the fixed-pt accum
		// accordingly.

		accum -= ((srcSamples+holdover)<<19);

		// Oops, did we need some of those?
		//
		// If accum=0, we need (n/2) samples back.  accum>=0x10000 is fewer,
		// accum<0 is more.

		nhold = - (accum>>19);

//		_ASSERT(nhold<=(filter_width/2));

		if (nhold>0) {
			memmove(cbuffer, (char *)cbuffer+bytesPerSample*(srcSamples+holdover-nhold), bytesPerSample*nhold);
			holdover = nhold;
			accum += nhold<<19;
		} else
			holdover = 0;

		_ASSERT(accum>=0);
	}

	*lplBytes = lActualSamples * bytesPerSample;

	return lActualSamples;
}

bool AudioStreamResampler::_isEnd() {
	return accum>=0 && source->isEnd();
}



///////////////////////////////////////////////////////////////////////////
//
//		AudioCompressor
//
//		This audio filter handles audio compression.
//
///////////////////////////////////////////////////////////////////////////

AudioCompressor::AudioCompressor(AudioStream *src, WAVEFORMATEX *dst_format, long dst_format_len) : AudioStream() {
	WAVEFORMATEX *iFormat = src->GetFormat();
	WAVEFORMATEX *oFormat = AllocFormat(dst_format_len);

	memcpy(oFormat, dst_format, dst_format_len);

	SetSource(src);

	mCodec.Init(iFormat, dst_format);

	bytesPerInputSample = iFormat->nBlockAlign;
	bytesPerOutputSample = dst_format->nBlockAlign;

	fStreamEnded = FALSE;
}

AudioCompressor::~AudioCompressor() {
}

void AudioCompressor::CompensateForMP3() {

	// Fraunhofer-IIS's MP3 codec has a compression delay that we need to
	// compensate for.  Comparison of PCM input, F-IIS output, and
	// WinAmp's Nitrane output reveals that the decompressor half of the
	// ACM codec is fine, but the compressor inserts a delay of 1373
	// (0x571) samples at the start.  This is a lag of 2 frames at
	// 30fps and 22KHz, so it's significant enough to be noticed.  At
	// 11KHz, this becomes a tenth of a second.  Needless to say, the
	// F-IIS MP3 codec is a royal piece of sh*t.
	//
	// By coincidence, the MPEGLAYER3WAVEFORMAT struct has a field
	// called nCodecDelay which is set to this value...

	if (GetFormat()->wFormatTag == WAVE_FORMAT_MPEGLAYER3) {
		long samples = ((MPEGLAYER3WAVEFORMAT *)GetFormat())->nCodecDelay;

		// Note: LameACM does not have a codec delay!

		if (samples && !source->Skip(samples)) {
			int maxRead = bytesPerInputSample > 16384 ? 1 : 16384 / bytesPerInputSample;

			vdblock<char> tempBuf(bytesPerInputSample * maxRead);
			void *dst = tempBuf.data();

			long actualBytes, actualSamples;
			do {
				long tc = samples;

				if (tc > maxRead)
					tc = maxRead;
					
				actualSamples = source->Read(dst, tc, &actualBytes);

				samples -= actualSamples;
			} while(samples>0 && actualBytes);

			if (!actualBytes || source->isEnd())
				fStreamEnded = TRUE;
		}
	}
}

long AudioCompressor::_Read(void *buffer, long samples, long *lplBytes) {
	long bytes = 0;
	long space = samples * bytesPerOutputSample;

	while(space > 0) {
		unsigned actualBytes = mCodec.CopyOutput(buffer, space);
		VDASSERT(!(actualBytes % bytesPerOutputSample));	// should always be true, since we trim runts in Process()

		if (!actualBytes) {
			if (!Process())
				break;

			continue;
		}

		buffer = (char *)buffer + actualBytes;
		space -= actualBytes;
		bytes += actualBytes;
	}

	if (lplBytes)
		*lplBytes = bytes;

	return bytes / bytesPerOutputSample;
}

bool AudioCompressor::Process() {
	if (mCodec.GetOutputLevel())
		return true;

	// fill the input buffer up!
	bool audioRead = false;

	if (!fStreamEnded) {
		unsigned inputSpace;
		char *dst0 = (char *)mCodec.LockInputBuffer(inputSpace);
		if (inputSpace >= bytesPerInputSample) {
			char *dst = dst0;

			do {
				const long samples = inputSpace / bytesPerInputSample;
				long actualBytes;

				long actualSamples = source->Read(dst, samples, &actualBytes);

				if (!actualSamples || source->isEnd()) {
					fStreamEnded = TRUE;
					break;
				}

				inputSpace -= actualBytes;
				dst += actualBytes;
			} while(inputSpace >= bytesPerInputSample);

			if (dst > dst0) {
				mCodec.UnlockInputBuffer(dst - dst0);
				audioRead = true;
			}
		}
	}

	return mCodec.Convert(fStreamEnded, !audioRead);
}

bool AudioCompressor::isEnd() {
	return fStreamEnded && !mCodec.GetOutputLevel();
}

///////////////////////////////////////////////////////////////////////////
//
//	Corrects the nAvgBytesPerFrame for that stupid Fraunhofer-IIS
//	codec.


AudioL3Corrector::AudioL3Corrector() {
	samples = frame_bytes = 0;
	read_left = 4;
	frames = 0;
	header_mode = true;
}

long AudioL3Corrector::ComputeByterate(long sample_rate) const {
	return MulDiv(frame_bytes, sample_rate, samples);
}

double AudioL3Corrector::ComputeByterateDouble(long sample_rate) const {
	return (double)frame_bytes*sample_rate/samples;
}

void AudioL3Corrector::Process(void *buffer, long bytes) {
	static const int bitrates[2][16]={
		{0, 8,16,24,32,40,48,56, 64, 80, 96,112,128,144,160,0},
		{0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0}
	};
	static const long samp_freq[4] = {44100, 48000, 32000, 0};

	int cnt=0;
	int tc;

	while(cnt < bytes) {
		tc = bytes - cnt;
		if (tc > read_left)
			tc = read_left;

		if (header_mode)
			memcpy(&hdr_buffer[4-read_left], buffer, tc);

		buffer = (char *)buffer + tc;
		cnt += tc;
		read_left -= tc;

		if (read_left <= 0)
			if (header_mode) {
				// We've got a header!  Process it...

				long hdr = *(long *)hdr_buffer;
				long samp_rate, framelen;

				if ((hdr & 0xE0FF) != 0xE0FF)
					throw MyError("MPEG audio sync error: try disabling MPEG audio time correction");

				samp_rate = samp_freq[(hdr>>18)&3];

				if (!((hdr>>11)&1)) {
					samp_rate /= 2;
					samples += 576;
				} else
					samples += 1152;

				if (!(hdr & 0x1000))
					samp_rate /= 2;

				framelen = (bitrates[(hdr>>11)&1][(hdr>>20)&15] * (((hdr>>11)&1) ? 144000 : 72000)) / samp_rate;

				if (hdr&0x20000) ++framelen;

				// update statistics

				frame_bytes += framelen;
				++frames;

				// start skipping the remainder

				read_left = framelen - 4;
				header_mode = false;

			} else {

				// Done skipping frame data; collect the next header

				read_left = 4;
				header_mode = true;
			}
	}
}

///////////////////////////////////////////////////////////////////////////

sint64 AudioTranslateVideoSubset(FrameSubset& dst, const FrameSubset& src, const VDFraction& videoFrameRate, WAVEFORMATEX *pwfex) {
	const long nBytesPerSec = pwfex->nAvgBytesPerSec;
	const int nBlockAlign = pwfex->nBlockAlign;
	sint64 total = 0;

	// I like accuracy, so let's strive for accuracy.  Accumulate errors as we go;
	// use them to offset the starting points of subsequent segments, never being
	// more than 1/2 segment off.
	//
	// The conversion equation is in units of (1000000*nBlockAlign).

	sint64 nError		= 0;
	sint64 nMultiplier	= (sint64)videoFrameRate.getLo() * nBytesPerSec;
	sint64 nDivisor		= (sint64)videoFrameRate.getHi() * nBlockAlign;
	sint64 nRound		= nDivisor/2;
	sint64 nTotalFramesAccumulated = 0;

	for(FrameSubset::const_iterator it = src.begin(), itEnd = src.end(); it != itEnd; ++it) {
		VDPosition start, end;

		// Compute error.
		//
		// Ideally, we want the audio and video streams to be of the exact length.
		//
		// Audiolen = (videolen * usPerFrame * nBytesPerSec) / (1000000*nBlockAlign);

		nError = total*nDivisor - (nTotalFramesAccumulated * nMultiplier);

		VDDEBUG("nError = %I64d\n", nError);

		// Add a block.

		start = ((__int64)it->start * nMultiplier + nRound + nError) / nDivisor;
		end = ((__int64)(it->start + it->len) * nMultiplier + nRound) / nDivisor;

		nTotalFramesAccumulated += it->len;

		dst.addRange(start, end-start, false);

		total += end-start;
	}

	return total;
}

AudioSubset::AudioSubset(AudioStream *src, const FrameSubset *pfs, const VDFraction& videoFrameRate, sint64 preskew) : AudioStream() {
	memcpy(AllocFormat(src->GetFormatLen()), src->GetFormat(), src->GetFormatLen());

	SetSource(src);

	sint64 total = AudioTranslateVideoSubset(subset, *pfs, videoFrameRate, src->GetFormat());

	const WAVEFORMATEX *pSrcFormat = src->GetFormat();

	subset.deleteRange(0, (preskew*pSrcFormat->nAvgBytesPerSec) / ((sint64)1000000*pSrcFormat->nBlockAlign));

	stream_len = total;

	SetLimit(total);

	pfsnCur = subset.begin();
	mOffset = 0;
	mSrcPos = 0;
	mSkipSize = kSkipBufferSize / pSrcFormat->nBlockAlign;
}

AudioSubset::~AudioSubset() {
}

long AudioSubset::_Read(void *buffer, long samples, long *lplBytes) {
	int actual;

	if (pfsnCur == subset.end()) {
		*lplBytes = 0;
		return 0;
	}

	const FrameSubsetNode& node = *pfsnCur;

	while (mSrcPos != node.start + mOffset) {
		sint64 offset = node.start - mSrcPos;
		long t;

		if (offset < 0) {
			source->Seek(node.start);
			mSrcPos = node.start + mOffset;
			break;
		}

		if (source->Skip(offset)) {
			mSrcPos += offset;
			break;
		}

		sint32 toskip = mSkipSize;
		if (toskip > offset) toskip = (sint32)offset;

		char skipBuffer[kSkipBufferSize];
		actual = source->Read(skipBuffer, toskip, &t);

		if (!actual) {
			*lplBytes = 0;
			return 0;
		}

		mSrcPos += actual;
	}

	if (samples > node.len - mOffset)
		samples = (long)(node.len - mOffset);

	samples = source->Read(buffer, samples, lplBytes);

	mOffset += samples;
	mSrcPos += samples;

	while (pfsnCur != subset.end() && mOffset >= pfsnCur->len) {
		mOffset -= pfsnCur->len;
		++pfsnCur;
	}

	return samples;
}

bool AudioSubset::_isEnd() {
	return pfsnCur == subset.end() || source->isEnd();
}

///////////////////////////////////////////////////////////////////////////
//
//	AudioAmplifier
//
///////////////////////////////////////////////////////////////////////////

static void amplify8(unsigned char *dst, int count, long lFactor) {
	long lBias = 0x8080 - 0x80*lFactor;

	if (count)
		do {
			int y = ((long)*dst++ * lFactor + lBias) >> 8;

			if (y<0) y=0; else if (y>255) y=255;

			dst[-1] = (unsigned char)y;
		} while(--count);
}

static void amplify16(signed short *dst, int count, long lFactor) {
	if (count)
		do {
			int y = ((long)*dst++ * lFactor + 0x80) >> 8;

			if (y<-0x7FFF) y=-0x7FFF; else if (y>0x7FFF) y=0x7FFF;

			dst[-1] = (signed short)y;
		} while(--count);
}

AudioStreamAmplifier::AudioStreamAmplifier(AudioStream *src, long _lFactor)
: lFactor(_lFactor) {

	WAVEFORMATEX *iFormat = src->GetFormat();
	WAVEFORMATEX *oFormat;

	memcpy(oFormat = AllocFormat(src->GetFormatLen()), iFormat, src->GetFormatLen());

	SetSource(src);
}

AudioStreamAmplifier::~AudioStreamAmplifier() {
}

long AudioStreamAmplifier::_Read(void *buffer, long samples, long *lplBytes) {
	long lActualSamples=0;
	long lBytes;

	lActualSamples = source->Read(buffer, samples, &lBytes);

	if (lActualSamples) {
		if (GetFormat()->wBitsPerSample > 8)
			amplify16((signed short *)buffer, lBytes/2, lFactor);
		else
			amplify8((unsigned char *)buffer, lBytes, lFactor);
	}

	if (lplBytes)
		*lplBytes = lBytes;

	return lActualSamples;
}

bool AudioStreamAmplifier::_isEnd() {
	return source->isEnd();
}

bool AudioStreamAmplifier::Skip(sint64 samples) {
	return source->Skip(samples);
}

///////////////////////////////////////////////////////////////////////////
//
//	AudioStreamL3Corrector
//
///////////////////////////////////////////////////////////////////////////

AudioStreamL3Corrector::AudioStreamL3Corrector(AudioStream *src){
	WAVEFORMATEX *iFormat = src->GetFormat();
	WAVEFORMATEX *oFormat;

	memcpy(oFormat = AllocFormat(src->GetFormatLen()), iFormat, src->GetFormatLen());

	SetSource(src);
}

AudioStreamL3Corrector::~AudioStreamL3Corrector() {
}

long AudioStreamL3Corrector::_Read(void *buffer, long samples, long *lplBytes) {
	long lActualSamples=0;
	long lBytes;

	lActualSamples = source->Read(buffer, samples, &lBytes);

	Process(buffer, lBytes);

	if (lplBytes)
		*lplBytes = lBytes;

	return lActualSamples;
}

bool AudioStreamL3Corrector::_isEnd() {
	return source->isEnd();
}

bool AudioStreamL3Corrector::Skip(sint64 samples) {
	return source->Skip(samples);
}

///////////////////////////////////////////////////////////////////////////
//
//	AudioFilterSystemStream
//
///////////////////////////////////////////////////////////////////////////

AudioFilterSystemStream::AudioFilterSystemStream(const VDAudioFilterGraph& graph, sint64 start_us) {
	int nOutputFilter = -1;

	VDAudioFilterGraph graph2(graph);
	VDAudioFilterGraph::FilterList::iterator it(graph2.mFilters.begin()), itEnd(graph2.mFilters.end());

	for(unsigned i=0; it!=itEnd; ++it, ++i) {
		if ((*it).mFilterName == L"output") {
			if (nOutputFilter >= 0)
				throw MyError("Audio filter graph contains more than one output node.");

			nOutputFilter = i;
			(*it).mFilterName = L"*sink";
		}
	}

	if (nOutputFilter < 0)
		throw MyError("Audio filter graph lacks an output node.");

	std::vector<IVDAudioFilterInstance *> filterPtrs;
	mFilterSystem.LoadFromGraph(graph2, filterPtrs);
	mFilterSystem.Start();

	mpFilterIF = VDGetAudioFilterSinkInterface(filterPtrs[nOutputFilter]->GetObject());

	mFilterSystem.Seek(start_us);

	int len = mpFilterIF->GetFormatLen();
	const WAVEFORMATEX *pFormat = (const WAVEFORMATEX *)mpFilterIF->GetFormat();

	if (pFormat->wFormatTag == WAVE_FORMAT_PCM)
		len = sizeof(PCMWAVEFORMAT);

	memcpy(AllocFormat(len), pFormat, len);

	stream_len = ((mpFilterIF->GetLength() - start_us)*pFormat->nAvgBytesPerSec) / (pFormat->nBlockAlign*(sint64)1000000);

	mStartTime = start_us;
	mSamplePos = 0;
}

AudioFilterSystemStream::~AudioFilterSystemStream() {
	mFilterSystem.Stop();
}

long AudioFilterSystemStream::_Read(void *buffer, long samples, long *lplBytes) {
	uint32 total_samples = 0;
	uint32 total_bytes = 0;

	if (samples>0) {
		char *dst = (char *)buffer;

		while(!mpFilterIF->IsEnded()) {
			uint32 actual = mpFilterIF->ReadSamples(dst, samples - total_samples);

			if (actual) {
				total_samples += actual;
				total_bytes += format->nBlockAlign*actual;
				dst += format->nBlockAlign*actual;
			}

			if (total_samples >= samples)
				break;

			if (!mFilterSystem.Run())
				break;
		}
	}

	if (lplBytes)
		*lplBytes = total_bytes;

	mSamplePos += total_samples;

	return total_samples;
}

bool AudioFilterSystemStream::_isEnd() {
	return mpFilterIF->IsEnded();
}

bool AudioFilterSystemStream::Skip(sint64 samples) {
	const WAVEFORMATEX *pFormat = GetFormat();

	// for short skips (<1 sec), just read through
	if (samples < pFormat->nAvgBytesPerSec / pFormat->nBlockAlign)
		return false;

	// reseek
	mSamplePos += samples;

	mFilterSystem.Seek(mStartTime + (mSamplePos * pFormat->nBlockAlign * 1000000) / pFormat->nAvgBytesPerSec);

	return true;
}

void AudioFilterSystemStream::Seek(VDPosition pos) {
	const WAVEFORMATEX *pFormat = GetFormat();

	// reseek
	mSamplePos = pos;

	mFilterSystem.Seek(mStartTime + (mSamplePos * pFormat->nBlockAlign * 1000000) / pFormat->nAvgBytesPerSec);
}

