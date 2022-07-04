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

#ifndef f_AVIPIPE_H
#define f_AVIPIPE_H

#include <windows.h>

#include <vd2/system/thread.h>
#include <vd2/system/atomic.h>

class AVIPipe {
private:
	static char me[];

	VDSignal			msigRead, msigWrite;
	VDCriticalSection	mcsQueue;

	volatile struct AVIPipeBuffer {
		void	*data;
		long	size;
		long	len;
		VDPosition	rawFrame;
		VDPosition	displayFrame;
		VDPosition	timelineFrame;
		int		iExdata;
		int		droptype;
		bool	bFinal;
	} *pBuffers;

	int		num_buffers;
	long	round_size;

	int		mReadPt;
	int		mWritePt;
	int		mLevel;

	VDAtomicInt		mState;

	enum {
		kFlagFinalizeTriggered		= 1,
		kFlagFinalizeAcknowledged	= 2,
		kFlagAborted				= 4,
		kFlagSyncTriggered			= 8,
		kFlagSyncAcknowledged		= 16
	};

	// These are the same as in VideoSourceAVI

public:
	enum {
		kDroppable=0,
		kDependant,
		kIndependent
	};

	AVIPipe(int buffers, long roundup_size);
	~AVIPipe();

	VDSignal& getReadSignal() { return msigRead; }
	VDSignal& getWriteSignal() { return msigWrite; }

	bool isOkay();
	bool isFinalized();
	bool isFinalizeAcked();

	bool full();

	void *getWriteBuffer(long len, int *handle_ptr);
	void postBuffer(long len, VDPosition rawFrame, VDPosition displayFrame, VDPosition timelineFrame, int exdata, int droptype, int handle, bool bIsFinal);
	void *getReadBuffer(long& len, VDPosition& rawFrame, VDPosition& displayFrame, VDPosition& timelineFrame, int *exdata_ptr, int *droptype_ptr, int *handle_ptr);
	void releaseBuffer(int handle);
	void finalize();
	void finalizeAndWait();
	void finalizeAck();
	void abort();
	bool sync();
	void syncack();
	void getDropDistances(int& dependant, int& independent);
	void getQueueInfo(int& total, int& finals);
};

#endif
