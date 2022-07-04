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

#ifndef f_AVIAUDIOOUTPUT_H
#define f_AVIAUDIOOUTPUT_H

#include <windows.h>
#include <mmsystem.h>

class AVIAudioOutputBuffer {
public:
	AVIAudioOutputBuffer *next,*prev;
	WAVEHDR hdr;
	DWORD dwBytesInBuffer;

	AVIAudioOutputBuffer(long bsize);
	~AVIAudioOutputBuffer();
	BOOL init(HWAVEOUT hWaveOut);
	BOOL post(HWAVEOUT hWaveOut);
	void deinit(HWAVEOUT hWaveOut);
};

class AVIAudioOutput {
private:
	AVIAudioOutputBuffer *pending, *pending_tail, *active;
	long bufsize;
	int numbufs, maxbufs;
	HWAVEOUT hWaveOut;
	HANDLE hEventBuffersFree;
	char fill_byte;
	DWORD nSamplesPerSec;
	DWORD nAvgBytesPerSec;
	int iBuffersActive;
	long lAvailSpace;
	CRITICAL_SECTION	mcsWaveDevice;

	enum {
		STATE_NONE		= 0,
		STATE_OPENED	= 1,
		STATE_PLAYING	= 2,
		STATE_SILENT	= 10,
	} curState;

	BOOL postBuffer(AVIAudioOutputBuffer *aaob);
public:
	AVIAudioOutput(long bufsize, int maxbufs);
	~AVIAudioOutput();

	BOOL init(WAVEFORMATEX *wf);
	void go_silent();
	BOOL isSilent();
	BOOL start();
	BOOL checkBuffers();
	BOOL waitBuffers(DWORD timeout);
	long avail();
	BOOL write(void *data, long len, DWORD timeout);
	BOOL stop();
	BOOL finalize(DWORD timeout);
	void flush();
	long position();
	bool isFrozen();
};

#endif
