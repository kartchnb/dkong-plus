//	VirtualDub - Video processing and capture application
//	A/V interface library
//	Copyright (C) 1998-2004 Avery Lee
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

#ifndef f_VD2_RIZA_CAPRESYNC_H
#define f_VD2_RIZA_CAPRESYNC_H

#include <vd2/Riza/capdriver.h>
#include <vd2/Priss/convert.h>

#include <vd2/system/int128.h>

/////////////////////////////////////////////////////////////////////////////

class VDCaptureAudioRateEstimator {
public:
	VDCaptureAudioRateEstimator() { Reset(); }
	void Reset();
	void AddSample(sint64 x, sint64 y);
	int GetCount() const { return mSamples; }
	bool GetSlope(double&) const;
	bool GetXIntercept(double slope, double&) const;
	bool GetYIntercept(double slope, double&) const;

protected:
	sint64		mX;
	sint64		mY;
	int128		mX2;
	int128		mXY;

	int			mSamples;
};

/////////////////////////////////////////////////////////////////////////////

struct VDCaptureResyncStatus {
	sint32		mVideoTimingAdjust;
	float		mAudioResamplingRate;
};

class VDINTERFACE IVDCaptureResyncFilter : public IVDCaptureDriverCallback {
public:
	enum Mode {
		kModeNone,
		kModeResampleVideo,
		kModeResampleAudio,

		kModeCount
	};

	virtual ~IVDCaptureResyncFilter() {}

	virtual void SetChildCallback(IVDCaptureDriverCallback *pChild) = 0;
	virtual void SetVideoRate(double fps) = 0;
	virtual void SetAudioRate(double bytesPerSec) = 0;
	virtual void SetAudioChannels(int chans) = 0;
	virtual void SetAudioFormat(VDAudioSampleType sampleType) = 0;
	virtual void SetResyncMode(Mode mode) = 0;

	virtual void GetStatus(VDCaptureResyncStatus&) = 0;
};

IVDCaptureResyncFilter *VDCreateCaptureResyncFilter();




#endif
