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
#include <commctrl.h>
#include <vd2/system/registry.h>
#include <vd2/system/math.h>
#include <vd2/system/w32assist.h>

#include <list>
#include <utility>

#include "optdlg.h"

#include "resource.h"
#include "helpfile.h"
#include "oshelper.h"
#include "misc.h"
#include "gui.h"

#include "AudioSource.h"
#include "VideoSource.h"
#include "Dub.h"

extern HINSTANCE g_hInst;

#define VD_FOURCC(fcc) (((fcc&0xff000000)>>24)+((fcc&0xff0000)>>8)+((fcc&0xff00)<<8)+((fcc&0xff)<<24))

///////////////////////////////////////////

void ActivateDubDialog(HINSTANCE hInst, LPCTSTR lpResource, HWND hDlg, DLGPROC dlgProc) {
	DubOptions duh;

	duh = g_dubOpts;
	if (DialogBoxParam(hInst, lpResource, hDlg, dlgProc, (LPARAM)&duh))
		g_dubOpts = duh;
}

///////////////////////////////////////////

class VDDialogAudioConversionW32 : public VDDialogBaseW32 {
public:
	inline VDDialogAudioConversionW32(DubOptions& opts, AudioSource *pSource) : VDDialogBaseW32(IDD_AUDIO_CONVERSION), mOpts(opts), mpSource(pSource) {}

	inline bool Activate(VDGUIHandle hParent) { return 0!=ActivateDialog(hParent); }

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();
	void RecomputeBandwidth();

	DubOptions& mOpts;
	AudioSource *const mpSource;
};

void VDDialogAudioConversionW32::RecomputeBandwidth() {
	long bps=0;

	if (	 IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_NOCHANGE))	bps = mpSource ? mpSource->getWaveFormat()->nSamplesPerSec : 0;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_11KHZ))		bps = 11025;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_22KHZ))		bps = 22050;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_44KHZ))		bps = 44100;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_8KHZ))		bps = 8000;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_16KHZ))		bps = 16000;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_48KHZ))		bps = 48000;
	else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_CUSTOM))
		bps = GetDlgItemInt(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL, NULL, FALSE);

	if (	 IsDlgButtonChecked(mhdlg, IDC_PRECISION_NOCHANGE))	bps *= mpSource ? mpSource->getWaveFormat()->wBitsPerSample>8 ? 2 : 1 : 1;
	else if (IsDlgButtonChecked(mhdlg, IDC_PRECISION_16BIT))		bps *= 2;

	if (	 IsDlgButtonChecked(mhdlg, IDC_CHANNELS_NOCHANGE))	bps *= mpSource ? mpSource->getWaveFormat()->nChannels>1 ? 2 : 1 : 1;
	else if (IsDlgButtonChecked(mhdlg, IDC_CHANNELS_STEREO))		bps *= 2;

	char buf[128];
	if (bps)
		wsprintf(buf, "Bandwidth required: %ldKB/s", (bps+1023)>>10);
	else
		strcpy(buf,"Bandwidth required: (unknown)");
	SetDlgItemText(mhdlg, IDC_BANDWIDTH_REQD, buf);
}

INT_PTR VDDialogAudioConversionW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
        case WM_INITDIALOG:
			ReinitDialog();
            return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDC_SAMPLINGRATE_NOCHANGE:
			case IDC_SAMPLINGRATE_8KHZ:
			case IDC_SAMPLINGRATE_11KHZ:
			case IDC_SAMPLINGRATE_16KHZ:
			case IDC_SAMPLINGRATE_22KHZ:
			case IDC_SAMPLINGRATE_44KHZ:
			case IDC_SAMPLINGRATE_48KHZ:
				if (!IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_CUSTOM))
					EnableWindow(GetDlgItem(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL), FALSE);
			case IDC_PRECISION_NOCHANGE:
			case IDC_PRECISION_8BIT:
			case IDC_PRECISION_16BIT:
			case IDC_CHANNELS_NOCHANGE:
			case IDC_CHANNELS_MONO:
			case IDC_CHANNELS_STEREO:
			case IDC_CHANNELS_LEFT:
			case IDC_CHANNELS_RIGHT:
			case IDC_SAMPLINGRATE_CUSTOM_VAL:
				RecomputeBandwidth();
				break;

			case IDC_SAMPLINGRATE_CUSTOM:
				EnableWindow(GetDlgItem(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL), TRUE);
				RecomputeBandwidth();
				break;

			case IDOK:
				if      (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_NOCHANGE)) mOpts.audio.new_rate = 0;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_8KHZ   )) mOpts.audio.new_rate = 8000;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_11KHZ   )) mOpts.audio.new_rate = 11025;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_16KHZ   )) mOpts.audio.new_rate = 16000;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_22KHZ   )) mOpts.audio.new_rate = 22050;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_44KHZ   )) mOpts.audio.new_rate = 44100;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_48KHZ   )) mOpts.audio.new_rate = 48000;
				else if (IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_CUSTOM))
					mOpts.audio.new_rate = GetDlgItemInt(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL, NULL, FALSE);

				if		(IsDlgButtonChecked(mhdlg, IDC_PRECISION_NOCHANGE)) mOpts.audio.newPrecision = DubAudioOptions::P_NOCHANGE;
				else if	(IsDlgButtonChecked(mhdlg, IDC_PRECISION_8BIT    )) mOpts.audio.newPrecision = DubAudioOptions::P_8BIT;
				else if	(IsDlgButtonChecked(mhdlg, IDC_PRECISION_16BIT   )) mOpts.audio.newPrecision = DubAudioOptions::P_16BIT;

				if		(IsDlgButtonChecked(mhdlg, IDC_CHANNELS_NOCHANGE)) mOpts.audio.newChannels = DubAudioOptions::C_NOCHANGE;
				else if	(IsDlgButtonChecked(mhdlg, IDC_CHANNELS_MONO    )) mOpts.audio.newChannels = DubAudioOptions::C_MONO;
				else if	(IsDlgButtonChecked(mhdlg, IDC_CHANNELS_STEREO  )) mOpts.audio.newChannels = DubAudioOptions::C_STEREO;
				else if	(IsDlgButtonChecked(mhdlg, IDC_CHANNELS_LEFT    )) mOpts.audio.newChannels = DubAudioOptions::C_MONOLEFT;
				else if	(IsDlgButtonChecked(mhdlg, IDC_CHANNELS_RIGHT   )) mOpts.audio.newChannels = DubAudioOptions::C_MONORIGHT;

				mOpts.audio.integral_rate = !!IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_INTEGRAL);
				mOpts.audio.fHighQuality = !!IsDlgButtonChecked(mhdlg, IDC_SAMPLINGRATE_HQ);

				End(true);
				return TRUE;
			case IDCANCEL:
				End(false);
				return TRUE;
			}
            break;

		case WM_HELP:
			{
				HELPINFO *lphi = (HELPINFO *)lParam;

				if (lphi->iContextType == HELPINFO_WINDOW)
					VDShowHelp(mhdlg, L"d-audioconversion.html");
			}
			return TRUE;
    }
    return FALSE;
}

void VDDialogAudioConversionW32::ReinitDialog() {
	if (mpSource) {
		char buf[128];

		wsprintf(buf, "No change (%ldHz)", mpSource->getWaveFormat()->nSamplesPerSec);
		SetDlgItemText(mhdlg, IDC_SAMPLINGRATE_NOCHANGE, buf);
		wsprintf(buf, "No change (%ld-bit)", mpSource->getWaveFormat()->wBitsPerSample>8 ? 16 : 8);
		SetDlgItemText(mhdlg, IDC_PRECISION_NOCHANGE, buf);
		wsprintf(buf, "No change (%s)", mpSource->getWaveFormat()->nChannels>1 ? "stereo" : "mono");
		SetDlgItemText(mhdlg, IDC_CHANNELS_NOCHANGE, buf);
	}

	switch(mOpts.audio.new_rate) {
	case 0:		CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_NOCHANGE, TRUE); break;
	case 8000:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_8KHZ, TRUE);	break;
	case 11025:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_11KHZ, TRUE);	break;
	case 16000:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_16KHZ, TRUE);	break;
	case 22050:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_22KHZ, TRUE);	break;
	case 44100:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_44KHZ, TRUE);	break;
	case 48000:	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_48KHZ, TRUE);	break;
	default:
		CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_CUSTOM, TRUE);
		EnableWindow(GetDlgItem(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL), TRUE);
		SetDlgItemInt(mhdlg, IDC_SAMPLINGRATE_CUSTOM_VAL, mOpts.audio.new_rate, FALSE);
		break;
	}
	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_INTEGRAL, !!mOpts.audio.integral_rate);
	CheckDlgButton(mhdlg, IDC_SAMPLINGRATE_HQ, !!mOpts.audio.fHighQuality);
	CheckDlgButton(mhdlg, IDC_PRECISION_NOCHANGE+mOpts.audio.newPrecision,TRUE);
	CheckDlgButton(mhdlg, IDC_CHANNELS_NOCHANGE+mOpts.audio.newChannels,TRUE);

	RecomputeBandwidth();
}

bool VDDisplayAudioConversionDialog(VDGUIHandle hParent, DubOptions& opts, AudioSource *pSource) {
	VDDialogAudioConversionW32 dlg(opts, pSource);

	return dlg.Activate(hParent);
}

///////////////////////////////////////////

void AudioInterleaveDlgEnableStuff(HWND hDlg, BOOL en) {
	EnableWindow(GetDlgItem(hDlg, IDC_PRELOAD), en);
	EnableWindow(GetDlgItem(hDlg, IDC_INTERVAL), en);
	EnableWindow(GetDlgItem(hDlg, IDC_FRAMES), en);
	EnableWindow(GetDlgItem(hDlg, IDC_MS), en);
}

INT_PTR CALLBACK AudioInterleaveDlgProc( HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	DubOptions *dopt = (DubOptions *)GetWindowLongPtr(hDlg, DWLP_USER);

    switch (message)
    {
        case WM_INITDIALOG:
			SetWindowLongPtr(hDlg, DWLP_USER, lParam);
			dopt = (DubOptions *)lParam;

			CheckDlgButton(hDlg, IDC_INTERLEAVE, dopt->audio.enabled);
			AudioInterleaveDlgEnableStuff(hDlg, dopt->audio.enabled);
//			if (dopt->audio.enabled) {
				SetDlgItemInt(hDlg, IDC_PRELOAD, dopt->audio.preload, FALSE);
				SetDlgItemInt(hDlg, IDC_INTERVAL, dopt->audio.interval, FALSE);
				CheckDlgButton(hDlg, IDC_FRAMES, !dopt->audio.is_ms);
				CheckDlgButton(hDlg, IDC_MS, dopt->audio.is_ms);
//			}
			SetDlgItemInt(hDlg, IDC_DISPLACEMENT, dopt->audio.offset, TRUE);
            return (TRUE);

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDC_INTERLEAVE:
				AudioInterleaveDlgEnableStuff(hDlg, IsDlgButtonChecked(hDlg, IDC_INTERLEAVE));
				break;

			case IDOK:
				dopt->audio.enabled = !!IsDlgButtonChecked(hDlg, IDC_INTERLEAVE);

				if (dopt->audio.enabled) {
					dopt->audio.preload = GetDlgItemInt(hDlg, IDC_PRELOAD, NULL, TRUE);
					if (dopt->audio.preload<0 || dopt->audio.preload>60000) {
						SetFocus(GetDlgItem(hDlg, IDC_PRELOAD));
						MessageBeep(MB_ICONQUESTION);
						break;
					}

					dopt->audio.interval = GetDlgItemInt(hDlg, IDC_INTERVAL, NULL, TRUE);
					if (dopt->audio.interval<=0 || dopt->audio.interval>3600000) {
						SetFocus(GetDlgItem(hDlg, IDC_INTERVAL));
						MessageBeep(MB_ICONQUESTION);
						break;
					}

					dopt->audio.is_ms = !!IsDlgButtonChecked(hDlg, IDC_MS);
				}

				dopt->audio.offset = GetDlgItemInt(hDlg, IDC_DISPLACEMENT, NULL, TRUE);

				EndDialog(hDlg, TRUE);
				return TRUE;
			case IDCANCEL:
				EndDialog(hDlg, FALSE);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

/////////////////////////////////

class VDDialogVideoDepthW32 : public VDDialogBaseW32 {
public:
	inline VDDialogVideoDepthW32(DubOptions& opts) : VDDialogBaseW32(IDD_VIDEO_DEPTH), mOpts(opts) {}

	inline bool Activate(VDGUIHandle hParent) { return 0!=ActivateDialog(hParent); }

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();
	void Commit();

	DubOptions& mOpts;
};

INT_PTR VDDialogVideoDepthW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
        case WM_INITDIALOG:
			ReinitDialog();
            return TRUE;

		case WM_HELP:
			{
				HELPINFO *lphi = (HELPINFO *)lParam;

				if (lphi->iContextType == HELPINFO_WINDOW)
					VDShowHelp(mhdlg, L"d-videodepth.html");
			}
			return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				Commit();				
				End(TRUE);
				return TRUE;
			case IDCANCEL:
				End(FALSE);
				return TRUE;
			case IDC_SAVEASDEFAULT:
				{
					VDRegistryAppKey key("Preferences");

					Commit();

					key.setInt("Input format", mOpts.video.mInputFormat);
					key.setInt("Output format", mOpts.video.mOutputFormat);

					EnableWindow(GetDlgItem(mhdlg, IDCANCEL), FALSE);
				}
				return TRUE;
			}
            break;
    }
    return FALSE;
}

void VDDialogVideoDepthW32::ReinitDialog() {
	switch(mOpts.video.mInputFormat) {
	case nsVDPixmap::kPixFormat_Null:
		CheckDlgButton(mhdlg, IDC_INPUT_AUTOSELECT, TRUE);
		break;
	case nsVDPixmap::kPixFormat_XRGB1555:
		CheckDlgButton(mhdlg, IDC_INPUT_XRGB1555, TRUE);
		break;
	case nsVDPixmap::kPixFormat_RGB565:
		CheckDlgButton(mhdlg, IDC_INPUT_RGB565, TRUE);
		break;
	case nsVDPixmap::kPixFormat_XRGB8888:
		CheckDlgButton(mhdlg, IDC_INPUT_XRGB8888, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_UYVY:
		CheckDlgButton(mhdlg, IDC_INPUT_YUV422_UYVY, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_YUYV:
		CheckDlgButton(mhdlg, IDC_INPUT_YUV422_YUY2, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_Planar:
		CheckDlgButton(mhdlg, IDC_INPUT_YUV422_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV420_Planar:
		CheckDlgButton(mhdlg, IDC_INPUT_YUV420_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV410_Planar:
		CheckDlgButton(mhdlg, IDC_INPUT_YUV410_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_Y8:
		CheckDlgButton(mhdlg, IDC_INPUT_Y8, TRUE);
		break;
	case nsVDPixmap::kPixFormat_RGB888:
	default:
		CheckDlgButton(mhdlg, IDC_INPUT_RGB888,	TRUE);
		break;
	}

	switch(mOpts.video.mOutputFormat) {
	case nsVDPixmap::kPixFormat_Null:
		CheckDlgButton(mhdlg, IDC_OUTPUT_AUTOSELECT, TRUE);
		break;
	case nsVDPixmap::kPixFormat_XRGB1555:
		CheckDlgButton(mhdlg, IDC_OUTPUT_XRGB1555, TRUE);
		break;
	case nsVDPixmap::kPixFormat_RGB565:
		CheckDlgButton(mhdlg, IDC_OUTPUT_RGB565, TRUE);
		break;
	case nsVDPixmap::kPixFormat_XRGB8888:
		CheckDlgButton(mhdlg, IDC_OUTPUT_XRGB8888, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_UYVY:
		CheckDlgButton(mhdlg, IDC_OUTPUT_YUV422_UYVY, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_YUYV:
		CheckDlgButton(mhdlg, IDC_OUTPUT_YUV422_YUY2, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV422_Planar:
		CheckDlgButton(mhdlg, IDC_OUTPUT_YUV422_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV420_Planar:
		CheckDlgButton(mhdlg, IDC_OUTPUT_YUV420_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_YUV410_Planar:
		CheckDlgButton(mhdlg, IDC_OUTPUT_YUV410_PLANAR, TRUE);
		break;
	case nsVDPixmap::kPixFormat_Y8:
		CheckDlgButton(mhdlg, IDC_OUTPUT_Y8, TRUE);
		break;
	case nsVDPixmap::kPixFormat_RGB888:
	default:
		CheckDlgButton(mhdlg, IDC_OUTPUT_RGB888,	TRUE);
		break;
	}
}

void VDDialogVideoDepthW32::Commit() {
	mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_RGB888;
	
	if (IsDlgButtonChecked(mhdlg, IDC_INPUT_AUTOSELECT))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_Null;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_XRGB1555))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_XRGB1555;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_RGB565))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_RGB565;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_XRGB8888))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_XRGB8888;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_YUV422_UYVY))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_YUV422_UYVY;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_YUV422_YUY2))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_YUV422_YUYV;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_YUV420_PLANAR))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_YUV420_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_YUV422_PLANAR))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_YUV422_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_YUV410_PLANAR))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_YUV410_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_INPUT_Y8))
		mOpts.video.mInputFormat = nsVDPixmap::kPixFormat_Y8;

	mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_RGB888;
	if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_AUTOSELECT))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_Null;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_XRGB1555))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_XRGB1555;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_RGB565))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_RGB565;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_XRGB8888))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_XRGB8888;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_YUV422_UYVY))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_YUV422_UYVY;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_YUV422_YUY2))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_YUV422_YUYV;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_YUV420_PLANAR))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_YUV420_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_YUV422_PLANAR))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_YUV422_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_YUV410_PLANAR))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_YUV410_Planar;
	else if (IsDlgButtonChecked(mhdlg, IDC_OUTPUT_Y8))
		mOpts.video.mOutputFormat = nsVDPixmap::kPixFormat_Y8;
}

bool VDDisplayVideoDepthDialog(VDGUIHandle hParent, DubOptions& opts) {
	VDDialogVideoDepthW32 dlg(opts);

	return dlg.Activate(hParent);
}

///////////////////////////////////////////////////////////////////////////
//
//	Performance dialog
//
///////////////////////////////////////////////////////////////////////////

static long outputBufferSizeArray[]={
	128*1024,
	192*1024,
	256*1024,
	512*1024,
	768*1024,
	1*1024*1024,
	2*1024*1024,
	3*1024*1024,
	4*1024*1024,
	6*1024*1024,
	8*1024*1024,
	12*1024*1024,
	16*1024*1024,
	20*1024*1024,
	24*1024*1024,
	32*1024*1024,
	48*1024*1024,
	64*1024*1024,
};

static long waveBufferSizeArray[]={
	8*1024,
	12*1024,
	16*1024,
	24*1024,
	32*1024,
	48*1024,
	64*1024,
	96*1024,
	128*1024,
	192*1024,
	256*1024,
	384*1024,
	512*1024,
	768*1024,
	1024*1024,
	1536*1024,
	2048*1024,
	3*1024*1024,
	4*1024*1024,
	6*1024*1024,
	8*1024*1024
};

static long pipeBufferCountArray[]={
	4,
	6,
	8,
	12,
	16,
	24,
	32,
	48,
	64,
	96,
	128,
	192,
	256,
};

#define ELEMENTS(x) (sizeof (x)/sizeof(x)[0])

INT_PTR CALLBACK PerformanceOptionsDlgProc( HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	DubOptions *dopt = (DubOptions *)GetWindowLongPtr(hDlg, DWLP_USER);
	LONG pos;
	HWND hWndItem;

    switch (message)
    {
        case WM_INITDIALOG:
			SetWindowLongPtr(hDlg, DWLP_USER, lParam);
			dopt = (DubOptions *)lParam;

			hWndItem = GetDlgItem(hDlg, IDC_OUTPUT_BUFFER);
			SendMessage(hWndItem, TBM_SETRANGE, FALSE, MAKELONG(0,sizeof outputBufferSizeArray / sizeof outputBufferSizeArray[0] - 1));
			SendMessage(hWndItem, TBM_SETPOS, TRUE, NearestLongValue(dopt->perf.outputBufferSize, outputBufferSizeArray, ELEMENTS(outputBufferSizeArray)));
			SendMessage(hDlg, WM_HSCROLL, 0, (LPARAM)hWndItem);
			hWndItem = GetDlgItem(hDlg, IDC_WAVE_INPUT_BUFFER);
			SendMessage(hWndItem, TBM_SETRANGE, FALSE, MAKELONG(0,sizeof waveBufferSizeArray / sizeof waveBufferSizeArray[0] - 1));
			SendMessage(hWndItem, TBM_SETPOS, TRUE, NearestLongValue(dopt->perf.waveBufferSize, waveBufferSizeArray, ELEMENTS(waveBufferSizeArray)));
			SendMessage(hDlg, WM_HSCROLL, 0, (LPARAM)hWndItem);
			hWndItem = GetDlgItem(hDlg, IDC_PIPE_BUFFERS);
			SendMessage(hWndItem, TBM_SETRANGE, FALSE, MAKELONG(0,sizeof pipeBufferCountArray / sizeof pipeBufferCountArray[0] - 1));
			SendMessage(hWndItem, TBM_SETPOS, TRUE, NearestLongValue(dopt->perf.pipeBufferCount, pipeBufferCountArray, ELEMENTS(pipeBufferCountArray)));
			SendMessage(hDlg, WM_HSCROLL, 0, (LPARAM)hWndItem);
            return (TRUE);

		case WM_HSCROLL:
			{
				char buf[128];

				pos = SendMessage((HWND)lParam, TBM_GETPOS, 0, 0);

				switch(GetWindowLongPtr((HWND)lParam, GWL_ID)) {
				case IDC_OUTPUT_BUFFER:
					if (pos >= 5)
						wsprintf(buf, "VirtualDub will use %ldMB of memory for output buffering.",outputBufferSizeArray[pos]>>20);
					else
						wsprintf(buf, "VirtualDub will use %ldKB of memory for output buffering.",outputBufferSizeArray[pos]>>10);

					SetDlgItemText(hDlg, IDC_OUTPUT_BUFFER_SIZE, buf);
					return TRUE;

				case IDC_WAVE_INPUT_BUFFER:
					if (pos >= 14)
						wsprintf(buf, "Replacement WAV audio tracks will use %ldMB of memory for input buffering.",waveBufferSizeArray[pos]>>20);
					else
						wsprintf(buf, "Replacement WAV audio tracks will use %ldKB of memory for input buffering.",waveBufferSizeArray[pos]>>10);

					SetDlgItemText(hDlg, IDC_WAVE_BUFFER_SIZE, buf);
					return TRUE;

				case IDC_PIPE_BUFFERS:
					wsprintf(buf, "Pipelining will be limited to %ld buffers.\n", pipeBufferCountArray[pos]);
					SetDlgItemText(hDlg, IDC_STATIC_PIPE_BUFFERS, buf);
					return TRUE;
				}
			}
			break;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				{
					long index;

					index = SendMessage(GetDlgItem(hDlg, IDC_OUTPUT_BUFFER), TBM_GETPOS, 0, 0);
					dopt->perf.outputBufferSize = outputBufferSizeArray[index];

					index = SendMessage(GetDlgItem(hDlg, IDC_WAVE_INPUT_BUFFER), TBM_GETPOS, 0, 0);
					dopt->perf.waveBufferSize = waveBufferSizeArray[index];

					index = SendMessage(GetDlgItem(hDlg, IDC_PIPE_BUFFERS), TBM_GETPOS, 0, 0);
					dopt->perf.pipeBufferCount = pipeBufferCountArray[index];
				}
				EndDialog(hDlg, TRUE);
				return TRUE;
			case IDCANCEL:
				EndDialog(hDlg, FALSE);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

INT_PTR CALLBACK DynamicCompileOptionsDlgProc( HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	DubOptions *dopt = (DubOptions *)GetWindowLongPtr(hDlg, DWLP_USER);

    switch (message)
    {
        case WM_INITDIALOG:
			SetWindowLongPtr(hDlg, DWLP_USER, lParam);
			dopt = (DubOptions *)lParam;

			CheckDlgButton(hDlg, IDC_ENABLE, dopt->perf.dynamicEnable);
			CheckDlgButton(hDlg, IDC_DISPLAY_CODE, dopt->perf.dynamicShowDisassembly);

            return (TRUE);

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				dopt->perf.dynamicEnable = !!IsDlgButtonChecked(hDlg, IDC_ENABLE);
				dopt->perf.dynamicShowDisassembly = !!IsDlgButtonChecked(hDlg, IDC_DISPLAY_CODE);
				EndDialog(hDlg, TRUE);
				return TRUE;
			case IDCANCEL:
				EndDialog(hDlg, FALSE);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

///////////////////////////////////////////////////////////////////////////
//
//	video frame rate dialog
//
///////////////////////////////////////////////////////////////////////////

class VDDialogVideoFrameRateW32 : public VDDialogBaseW32 {
public:
	inline VDDialogVideoFrameRateW32(DubOptions& opts, VideoSource *pVS, AudioSource *pAS) : VDDialogBaseW32(IDD_VIDEO_FRAMERATE), mOpts(opts), mpVideo(pVS), mpAudio(pAS) {}

	bool Activate(VDGUIHandle hParent) { return 0 != ActivateDialog(hParent); }

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();

	void RedoIVTCEnables();

	DubOptions& mOpts;
	VideoSource *const mpVideo;
	AudioSource *const mpAudio;
};

void VDDialogVideoFrameRateW32::RedoIVTCEnables() {
	bool f3, f4;
	BOOL e;

	f3 = !!IsDlgButtonChecked(mhdlg, IDC_IVTC_RECONFIELDSFIXED);
	f4 = !!IsDlgButtonChecked(mhdlg, IDC_IVTC_RECONFRAMESMANUAL);

	e = f3 || f4;

	EnableWindow(GetDlgItem(mhdlg, IDC_STATIC_IVTCOFFSET), e);
	EnableWindow(GetDlgItem(mhdlg, IDC_IVTCOFFSET), e);
	EnableWindow(GetDlgItem(mhdlg, IDC_INVPOLARITY), e);
}

INT_PTR VDDialogVideoFrameRateW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message)
    {
        case WM_INITDIALOG:
			ReinitDialog();
            return (TRUE);

		case WM_HELP:
			{
				HELPINFO *lphi = (HELPINFO *)lParam;

				if (lphi->iContextType == HELPINFO_WINDOW)
					VDShowHelp(mhdlg, L"d-videoframerate.html");
			}
			return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDC_DECIMATE_1:
			case IDC_DECIMATE_2:
			case IDC_DECIMATE_3:
				EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), FALSE);
				EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), FALSE);
				break;
			case IDC_DECIMATE_N:
				EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), TRUE);
				EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), FALSE);
				break;

			case IDC_DECIMATE_TARGET:
				EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), FALSE);
				EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), TRUE);
				SetFocus(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET));
				break;

			case IDC_FRAMERATE_CHANGE:
				if (SendMessage((HWND)lParam, BM_GETSTATE, 0, 0) & BST_CHECKED)
					EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE),TRUE);
				break;

			case IDC_FRAMERATE_SAMELENGTH:
			case IDC_FRAMERATE_NOCHANGE:
				if (SendMessage((HWND)lParam, BM_GETSTATE, 0, 0) & BST_CHECKED)
					EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE),FALSE);
				break;

			case IDC_IVTC_OFF:
			case IDC_IVTC_RECONFIELDS:
			case IDC_IVTC_RECONFIELDSFIXED:
			case IDC_IVTC_RECONFRAMESMANUAL:
				{
					BOOL f = IsDlgButtonChecked(mhdlg, IDC_IVTC_OFF);

					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_1), f);
					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_2), f);
					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_3), f);
					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_N), f);
					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), f && IsDlgButtonChecked(mhdlg, IDC_DECIMATE_N));
					EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_TARGET), f);
					EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), f && IsDlgButtonChecked(mhdlg, IDC_DECIMATE_N));
					RedoIVTCEnables();
				}
				break;

			case IDOK:
				{
					VDFraction newTarget(0,0);
					int newFRD;

					if (IsDlgButtonChecked(mhdlg, IDC_DECIMATE_TARGET)) {
						double newFR;
						char buf[128], tmp;

						GetDlgItemText(mhdlg, IDC_FRAMERATE_TARGET, buf, sizeof buf);

						if (1!=sscanf(buf, "%lg %c", &newFR, &tmp) || newFR<=0.0 || newFR>=200.0) {
							SetFocus(GetDlgItem(mhdlg, IDC_FRAMERATE));
							MessageBeep(MB_ICONQUESTION);
							return FALSE;
						}

						newTarget = VDFraction((uint32)(0.5 + newFR * 10000.0), 10000);

						newFRD = 1;
					} else if (IsDlgButtonChecked(mhdlg, IDC_DECIMATE_N)) {
						LONG lv = GetDlgItemInt(mhdlg, IDC_DECIMATE_VALUE, NULL, TRUE);

						if (lv<1) {
							SetFocus(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE));
							MessageBeep(MB_ICONQUESTION);
							return FALSE;
						}

						newFRD = lv;
					} else if (IsDlgButtonChecked(mhdlg, IDC_DECIMATE_1))
						newFRD = 1;
					else if (IsDlgButtonChecked(mhdlg, IDC_DECIMATE_2))
						newFRD = 2;
					else if (IsDlgButtonChecked(mhdlg, IDC_DECIMATE_3))
						newFRD = 3;

					if (IsDlgButtonChecked(mhdlg, IDC_FRAMERATE_CHANGE)) {
						double newFR;
						char buf[128], tmp;

						GetDlgItemText(mhdlg, IDC_FRAMERATE, buf, sizeof buf);

						if (1!=sscanf(buf, "%lg %c", &newFR, &tmp) || newFR<=0.0 || newFR>=200.0) {
							SetFocus(GetDlgItem(mhdlg, IDC_FRAMERATE));
							MessageBeep(MB_ICONQUESTION);
							return FALSE;
						}

						mOpts.video.frameRateNewMicroSecs = (long)(1000000.0/newFR + .5);
					} else if (IsDlgButtonChecked(mhdlg, IDC_FRAMERATE_SAMELENGTH)) {
						mOpts.video.frameRateNewMicroSecs = DubVideoOptions::FR_SAMELENGTH;
					} else mOpts.video.frameRateNewMicroSecs = 0;

					mOpts.video.frameRateDecimation = newFRD;
					mOpts.video.frameRateTargetHi = newTarget.getHi();
					mOpts.video.frameRateTargetLo = newTarget.getLo();

					if (IsDlgButtonChecked(mhdlg, IDC_IVTC_RECONFIELDS)) {
						mOpts.video.fInvTelecine = true;
						mOpts.video.fIVTCMode = false;
						mOpts.video.nIVTCOffset = -1;
						mOpts.video.frameRateDecimation = 1;
					} else if (IsDlgButtonChecked(mhdlg, IDC_IVTC_RECONFIELDSFIXED)) {
						BOOL fSuccess;
						LONG lv = GetDlgItemInt(mhdlg, IDC_IVTCOFFSET, &fSuccess, FALSE);

						mOpts.video.fInvTelecine = true;
						mOpts.video.fIVTCMode = false;
						mOpts.video.nIVTCOffset = lv % 5;
						mOpts.video.fIVTCPolarity = !!IsDlgButtonChecked(mhdlg, IDC_INVPOLARITY);
						mOpts.video.frameRateDecimation = 1;
					} else if (IsDlgButtonChecked(mhdlg, IDC_IVTC_RECONFRAMESMANUAL)) {
						BOOL fSuccess;
						LONG lv = GetDlgItemInt(mhdlg, IDC_IVTCOFFSET, &fSuccess, FALSE);

						mOpts.video.fInvTelecine = true;
						mOpts.video.fIVTCMode = true;
						mOpts.video.nIVTCOffset = lv % 5;
						mOpts.video.fIVTCPolarity = !!IsDlgButtonChecked(mhdlg, IDC_INVPOLARITY);
						mOpts.video.frameRateDecimation = 1;
					} else {
						mOpts.video.fInvTelecine = false;
					}
				}

				End(true);
				return TRUE;
			case IDCANCEL:
				End(false);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

void VDDialogVideoFrameRateW32::ReinitDialog() {
	char buf[128];

	CheckDlgButton(mhdlg, IDC_INVTELECINE, mOpts.video.fInvTelecine);

	if (mOpts.video.fInvTelecine) {
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_1), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_2), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_3), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_N), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_TARGET), FALSE);
		EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), FALSE);
	}

	if (mOpts.video.frameRateDecimation==1 && mOpts.video.frameRateTargetLo)
		CheckDlgButton(mhdlg, IDC_DECIMATE_TARGET, TRUE);
	else
		EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_TARGET), FALSE);

	CheckDlgButton(mhdlg, IDC_DECIMATE_1, mOpts.video.frameRateDecimation==1 && !mOpts.video.frameRateTargetLo);
	CheckDlgButton(mhdlg, IDC_DECIMATE_2, mOpts.video.frameRateDecimation==2);
	CheckDlgButton(mhdlg, IDC_DECIMATE_3, mOpts.video.frameRateDecimation==3);
	CheckDlgButton(mhdlg, IDC_DECIMATE_N, mOpts.video.frameRateDecimation>3);
	if (mOpts.video.frameRateDecimation>3)
		SetDlgItemInt(mhdlg, IDC_DECIMATE_VALUE, mOpts.video.frameRateDecimation, FALSE);
	else
		EnableWindow(GetDlgItem(mhdlg, IDC_DECIMATE_VALUE), FALSE);

	if (mOpts.video.frameRateTargetLo) {
		sprintf(buf, "%.4f", (double)VDFraction(mOpts.video.frameRateTargetHi, mOpts.video.frameRateTargetLo));
		SetDlgItemText(mhdlg, IDC_FRAMERATE_TARGET, buf);
	}

	if (mpVideo) {
		sprintf(buf, "No change (current: %.3f fps)", mpVideo->getRate().asDouble());
		SetDlgItemText(mhdlg, IDC_FRAMERATE_NOCHANGE, buf);

		if (mpAudio && mpAudio->getLength()) {
			sprintf(buf, "(%.3f fps)", (mpVideo->getLength()*1000.0) / mpAudio->samplesToMs(mpAudio->getLength()));
			SetDlgItemText(mhdlg, IDC_FRAMERATE_SAMELENGTH_VALUE, buf);
		} else
			EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE_SAMELENGTH), FALSE);
	}

	if (mOpts.video.frameRateNewMicroSecs == DubVideoOptions::FR_SAMELENGTH) {
		if (!mpAudio)
			CheckDlgButton(mhdlg, IDC_FRAMERATE_NOCHANGE, TRUE);
		else
			CheckDlgButton(mhdlg, IDC_FRAMERATE_SAMELENGTH, TRUE);
		EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE), FALSE);
	} else if (mOpts.video.frameRateNewMicroSecs) {
		sprintf(buf, "%.3f", 1000000.0/mOpts.video.frameRateNewMicroSecs);
		SetDlgItemText(mhdlg, IDC_FRAMERATE, buf);
		CheckDlgButton(mhdlg, IDC_FRAMERATE_CHANGE, TRUE);
	} else {
		CheckDlgButton(mhdlg, IDC_FRAMERATE_NOCHANGE, TRUE);
		EnableWindow(GetDlgItem(mhdlg, IDC_FRAMERATE), FALSE);
	}

	if (mOpts.video.fInvTelecine) {
		if (mOpts.video.fIVTCMode)
			CheckDlgButton(mhdlg, IDC_IVTC_RECONFRAMESMANUAL, TRUE);
		else if (mOpts.video.nIVTCOffset<0)
			CheckDlgButton(mhdlg, IDC_IVTC_RECONFIELDS, TRUE);
		else
			CheckDlgButton(mhdlg, IDC_IVTC_RECONFIELDSFIXED, TRUE);
	} else
		CheckDlgButton(mhdlg, IDC_IVTC_OFF, TRUE);

	SetDlgItemInt(mhdlg, IDC_IVTCOFFSET, mOpts.video.nIVTCOffset<0 ? 1 : mOpts.video.nIVTCOffset, FALSE);
	CheckDlgButton(mhdlg, IDC_INVPOLARITY, mOpts.video.fIVTCPolarity);

	RedoIVTCEnables();
}

bool VDDisplayVideoFrameRateDialog(VDGUIHandle hParent, DubOptions& opts, VideoSource *pVS, AudioSource *pAS) {
	VDDialogVideoFrameRateW32 dlg(opts, pVS, pAS);

	return dlg.Activate(hParent);
}

///////////////////////////////////////////////////////////////////////////
//
//	video range dialog
//
///////////////////////////////////////////////////////////////////////////

class VDDialogVideoRangeW32 : public VDDialogBaseW32 {
public:
	inline VDDialogVideoRangeW32(DubOptions& opts, VideoSource *pVS) : VDDialogBaseW32(IDD_VIDEO_CLIPPING), mOpts(opts), mpVideo(pVS), mbReentry(false) {}

	inline bool Activate(VDGUIHandle hParent) { return 0 != ActivateDialog(hParent); }

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();

	void MSToFrames(UINT idFrames, UINT idMS);
	void FramesToMS(UINT idMS, UINT idFrames);
	void LengthFrames();
	void LengthMS();

	DubOptions& mOpts;
	VideoSource *const mpVideo;

	bool mbReentry;
};

void VDDialogVideoRangeW32::MSToFrames(UINT idFrames, UINT idMS) {
	VDPosition frames;
	VDTime ms;
	BOOL ok;

	if (!mpVideo)
		return;

	ms = GetDlgItemInt(mhdlg, idMS, &ok, FALSE);
	if (!ok)
		return;
	mbReentry = true;
	frames = mpVideo->msToSamples(ms);
	SetDlgItemInt(mhdlg, idFrames, (UINT)frames, FALSE);
	SetDlgItemInt(mhdlg, IDC_LENGTH_MS,
				(UINT)(mpVideo->samplesToMs(mpVideo->getLength())
				-GetDlgItemInt(mhdlg, IDC_END_MS, NULL, FALSE)
				-GetDlgItemInt(mhdlg, IDC_START_MS, NULL, FALSE)), TRUE);
	SetDlgItemInt(mhdlg, IDC_LENGTH_FRAMES,
				(UINT)(mpVideo->getLength()
				-GetDlgItemInt(mhdlg, IDC_END_FRAMES, NULL, FALSE)
				-GetDlgItemInt(mhdlg, IDC_START_FRAMES, NULL, FALSE)), TRUE);
	mbReentry = false;
}

void VDDialogVideoRangeW32::FramesToMS(UINT idMS, UINT idFrames) {
	VDPosition frames;
	VDTime ms;
	BOOL ok;

	if (!mpVideo)
		return;

	frames = GetDlgItemInt(mhdlg, idFrames, &ok, FALSE);
	if (!ok) return;
	mbReentry = true;
	ms = mpVideo->samplesToMs(frames);
	SetDlgItemInt(mhdlg, idMS, (UINT)ms, FALSE);
	SetDlgItemInt(mhdlg, IDC_LENGTH_MS,
				(UINT)(mpVideo->samplesToMs(mpVideo->getLength())
				-GetDlgItemInt(mhdlg, IDC_END_MS, NULL, FALSE)
				-GetDlgItemInt(mhdlg, IDC_START_MS, NULL, FALSE)), TRUE);
	SetDlgItemInt(mhdlg, IDC_LENGTH_FRAMES,
				(UINT)(mpVideo->getLength()
				-GetDlgItemInt(mhdlg, IDC_END_FRAMES, NULL, FALSE)
				-GetDlgItemInt(mhdlg, IDC_START_FRAMES, NULL, FALSE)), TRUE);
	mbReentry = false;
}

void VDDialogVideoRangeW32::LengthFrames() {
	VDPosition frames;
	VDTime ms;
	BOOL ok;

	if (!mpVideo) return;

	frames = GetDlgItemInt(mhdlg, IDC_LENGTH_FRAMES, &ok, TRUE);
	if (!ok) return;
	mbReentry = true;
	ms = mpVideo->samplesToMs(frames);
	SetDlgItemInt(mhdlg, IDC_LENGTH_MS, (UINT)ms, FALSE);
	SetDlgItemInt(mhdlg, IDC_END_MS,
				(UINT)(mpVideo->samplesToMs(mpVideo->getLength())
				-ms
				-GetDlgItemInt(mhdlg, IDC_START_MS, NULL, TRUE)), TRUE);
	SetDlgItemInt(mhdlg, IDC_END_FRAMES,
				(UINT)(mpVideo->getLength()
				-frames
				-GetDlgItemInt(mhdlg, IDC_START_FRAMES, NULL, TRUE)), TRUE);
	mbReentry = false;
}

void VDDialogVideoRangeW32::LengthMS() {
	VDPosition frames;
	VDTime ms;
	BOOL ok;

	if (!mpVideo) return;

	ms = GetDlgItemInt(mhdlg, IDC_LENGTH_MS, &ok, TRUE);
	if (!ok) return;
	mbReentry = TRUE;
	frames = mpVideo->msToSamples(ms);
	SetDlgItemInt(mhdlg, IDC_LENGTH_FRAMES, (UINT)frames, FALSE);
	SetDlgItemInt(mhdlg, IDC_END_MS,
				(UINT)(mpVideo->samplesToMs(mpVideo->getLength())
				-ms
				-GetDlgItemInt(mhdlg, IDC_START_MS, NULL, TRUE)), TRUE);
	SetDlgItemInt(mhdlg, IDC_END_FRAMES,
				(UINT)(mpVideo->getLength()
				-frames
				-GetDlgItemInt(mhdlg, IDC_START_FRAMES, NULL, TRUE)), TRUE);
	mbReentry = FALSE;
}

INT_PTR VDDialogVideoRangeW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
        case WM_INITDIALOG:
			EnableWindow(GetDlgItem(mhdlg, IDC_LENGTH_MS), !!mpVideo);
			EnableWindow(GetDlgItem(mhdlg, IDC_START_FRAMES), !!mpVideo);
			EnableWindow(GetDlgItem(mhdlg, IDC_LENGTH_FRAMES), !!mpVideo);
			EnableWindow(GetDlgItem(mhdlg, IDC_END_FRAMES), !!mpVideo);
			SetDlgItemInt(mhdlg, IDC_START_MS, mOpts.video.lStartOffsetMS, FALSE);
			SetDlgItemInt(mhdlg, IDC_END_MS, mOpts.video.lEndOffsetMS, FALSE);
			CheckDlgButton(mhdlg, IDC_OFFSET_AUDIO, mOpts.audio.fStartAudio);
			CheckDlgButton(mhdlg, IDC_CLIP_AUDIO, mOpts.audio.fEndAudio);
            return (TRUE);

		case WM_HELP:
			{
				HELPINFO *lphi = (HELPINFO *)lParam;

				if (lphi->iContextType == HELPINFO_WINDOW)
					VDShowHelp(mhdlg, L"d-videorange.html");
			}
			return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDC_START_MS:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					MSToFrames(IDC_START_FRAMES, IDC_START_MS);
				break;
			case IDC_START_FRAMES:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					FramesToMS(IDC_START_MS, IDC_START_FRAMES);
				break;
			case IDC_END_MS:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					MSToFrames(IDC_END_FRAMES, IDC_END_MS);
				break;
			case IDC_END_FRAMES:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					FramesToMS(IDC_END_MS, IDC_END_FRAMES);
				break;
			case IDC_LENGTH_MS:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					LengthMS();
				break;
			case IDC_LENGTH_FRAMES:
				if (HIWORD(wParam)==EN_CHANGE && !mbReentry)
					LengthFrames();
				break;
			case IDOK:
				mOpts.video.lStartOffsetMS	= GetDlgItemInt(mhdlg, IDC_START_MS, NULL, FALSE);
				mOpts.video.lEndOffsetMS	= GetDlgItemInt(mhdlg, IDC_END_MS, NULL, FALSE);
				mOpts.audio.fStartAudio		= !!IsDlgButtonChecked(mhdlg, IDC_OFFSET_AUDIO);
				mOpts.audio.fEndAudio		= !!IsDlgButtonChecked(mhdlg, IDC_CLIP_AUDIO);
				End(true);
				return TRUE;
			case IDCANCEL:
				End(false);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

bool VDDisplayVideoRangeDialog(VDGUIHandle hParent, DubOptions& opts, VideoSource *pVS) {
	VDDialogVideoRangeW32 dlg(opts, pVS);

	return dlg.Activate(hParent);
}

///////////////////////////////////////////////////////////////////////////

INT_PTR CALLBACK AudioVolumeDlgProc( HWND hdlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	DubOptions *dopt = (DubOptions *)GetWindowLongPtr(hdlg, DWLP_USER);
	static const double log2 = 0.69314718055994530941723212145818;

    switch (message)
    {
        case WM_INITDIALOG:
			SetWindowLongPtr(hdlg, DWLP_USER, lParam);
			dopt = (DubOptions *)lParam;

			{
				HWND hwndSlider = GetDlgItem(hdlg, IDC_SLIDER_VOLUME);

				SendMessage(hwndSlider, TBM_SETRANGE, TRUE, MAKELONG(0, 65));

				if (dopt->audio.volume) {
					CheckDlgButton(hdlg, IDC_ADJUSTVOL, BST_CHECKED);

					SendMessage(hwndSlider, TBM_SETPOS, TRUE, (int)(32.5 - 80.0 + log((double)dopt->audio.volume)/(log2/10.0)));

					AudioVolumeDlgProc(hdlg, WM_HSCROLL, 0, (LPARAM)hwndSlider);
				} else {
					SendMessage(hwndSlider, TBM_SETPOS, TRUE, 32);
					EnableWindow(GetDlgItem(hdlg, IDC_SLIDER_VOLUME), FALSE);
					EnableWindow(GetDlgItem(hdlg, IDC_STATIC_VOLUME), FALSE);
				}
			}
            return (TRUE);

		case WM_HELP:
			{
				HELPINFO *lphi = (HELPINFO *)lParam;

				if (lphi->iContextType == HELPINFO_WINDOW)
					VDShowHelp(hdlg, L"d-audiovolume.html");
			}
			return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				if (IsDlgButtonChecked(hdlg, IDC_ADJUSTVOL)) {
					int pos = SendDlgItemMessage(hdlg, IDC_SLIDER_VOLUME, TBM_GETPOS, 0, 0);

					dopt->audio.volume = VDRoundToInt(256.0 * pow(2.0, (pos-32)/10.0));
				} else
					dopt->audio.volume = 0;

				EndDialog(hdlg, TRUE);
				return TRUE;
			case IDCANCEL:
				EndDialog(hdlg, FALSE);
				return TRUE;

			case IDC_ADJUSTVOL:
				if (HIWORD(wParam)==BN_CLICKED) {
					BOOL f = !!IsDlgButtonChecked(hdlg, IDC_ADJUSTVOL);

					EnableWindow(GetDlgItem(hdlg, IDC_SLIDER_VOLUME), f);
					EnableWindow(GetDlgItem(hdlg, IDC_STATIC_VOLUME), f);
				}
				return TRUE;
			}
            break;

		case WM_HSCROLL:
			if (lParam) {
				char buf[64];
				int pos = SendMessage((HWND)lParam, TBM_GETPOS, 0, 0);

				sprintf(buf, "%d%%", VDRoundToInt(100.0*pow(2.0, (pos-32)/10.0)));
				SetDlgItemText(hdlg, IDC_STATIC_VOLUME, buf);
			}
			break;
    }
    return FALSE;
}

///////////////////////////////////////////////////////////////////////////
//
//	jump to position dialog
//
///////////////////////////////////////////////////////////////////////////

class VDDialogJumpToPositionW32 : public VDDialogBaseW32 {
public:
	inline VDDialogJumpToPositionW32(VDPosition currentFrame, VideoSource *pVS, const VDFraction& realRate) : VDDialogBaseW32(IDD_JUMPTOFRAME), mFrame(currentFrame), mpVideo(pVS), mRealRate(realRate) {}

	VDPosition Activate(VDGUIHandle hParent) { return ActivateDialog(hParent) ? mFrame : -1; }

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();

	VDPosition mFrame;
	VideoSource *const mpVideo;
	VDFraction	mRealRate;
};

INT_PTR VDDialogJumpToPositionW32::DlgProc(UINT msg, WPARAM wParam, LPARAM lParam) {
	char buf[64];

	switch(msg) {
	case WM_INITDIALOG:
		ReinitDialog();
		return FALSE;

	case WM_COMMAND:
		switch(LOWORD(wParam)) {
		case IDCANCEL:
			End(false);
			break;
		case IDOK:
			if (IsDlgButtonChecked(mhdlg, IDC_JUMPTOFRAME)) {
				BOOL fOk;
				UINT uiFrame = GetDlgItemInt(mhdlg, IDC_FRAMENUMBER, &fOk, FALSE);

				if (!fOk) {
					SetFocus(GetDlgItem(mhdlg, IDC_FRAMENUMBER));
					MessageBeep(MB_ICONEXCLAMATION);
					return TRUE;
				}

				mFrame = uiFrame;

				End(true);
			} else {
				unsigned int hr, min;
				double sec = 0;
				int n;

				GetDlgItemText(mhdlg, IDC_FRAMETIME, buf, sizeof buf);

				n = sscanf(buf, "%u:%u:%lf", &hr, &min, &sec);

				if (n < 3) {
					hr = 0;
					n = sscanf(buf, "%u:%lf", &min, &sec);
				}

				if (n < 2) {
					min = 0;
					n = sscanf(buf, "%lf", &sec);
				}

				if (n < 1 || sec < 0) {
					SetFocus(GetDlgItem(mhdlg, IDC_FRAMETIME));
					MessageBeep(MB_ICONEXCLAMATION);
					return TRUE;
				}

				mFrame = VDRoundToInt64((double)mRealRate * (sec + min*60 + hr*3600));

				End(true);
			}
			break;
		case IDC_FRAMENUMBER:
			if (HIWORD(wParam) == EN_CHANGE) {
				CheckDlgButton(mhdlg, IDC_JUMPTOFRAME, BST_CHECKED);
				CheckDlgButton(mhdlg, IDC_JUMPTOTIME, BST_UNCHECKED);
			}
			break;
		case IDC_FRAMETIME:
			if (HIWORD(wParam) == EN_CHANGE) {
				CheckDlgButton(mhdlg, IDC_JUMPTOFRAME, BST_UNCHECKED);
				CheckDlgButton(mhdlg, IDC_JUMPTOTIME, BST_CHECKED);
			}
			break;
		}
		return TRUE;
	}
	return FALSE;
}

void VDDialogJumpToPositionW32::ReinitDialog() {
	long ticks = VDRoundToLong(mFrame * 1000.0 / (double)mRealRate);
	long ms, sec, min;
	char buf[64];

	CheckDlgButton(mhdlg, IDC_JUMPTOFRAME, BST_CHECKED);
	SendDlgItemMessage(mhdlg, IDC_FRAMETIME, EM_LIMITTEXT, 30, 0);
	SetDlgItemInt(mhdlg, IDC_FRAMENUMBER, (UINT)mFrame, FALSE);
	SetFocus(GetDlgItem(mhdlg, IDC_FRAMENUMBER));
	SendDlgItemMessage(mhdlg, IDC_FRAMENUMBER, EM_SETSEL, 0, -1);

	ms  = ticks %1000; ticks /= 1000;
	sec	= ticks %  60; ticks /=  60;
	min	= ticks %  60; ticks /=  60;

	if (ticks)
		wsprintf(buf, "%d:%02d:%02d.%03d", ticks, min, sec, ms);
	else
		wsprintf(buf, "%d:%02d.%03d", min, sec, ms);

	SetDlgItemText(mhdlg, IDC_FRAMETIME, buf);
}

VDPosition VDDisplayJumpToPositionDialog(VDGUIHandle hParent, VDPosition currentFrame, VideoSource *pVS, const VDFraction& realRate) {
	VDDialogJumpToPositionW32 dlg(currentFrame, pVS, realRate);

	return dlg.Activate(hParent);
}

///////////////////////////////////////////////////////////////////////////
//
//	error mode dialog
//
///////////////////////////////////////////////////////////////////////////

class VDDialogErrorModeW32 : public VDDialogBaseW32 {
public:
	inline VDDialogErrorModeW32(const char *pszSettingsKey, DubSource *pSource) : VDDialogBaseW32(IDD_ERRORMODE), mpszSettingsKey(pszSettingsKey), mpSource(pSource) {}

	DubSource::ErrorMode Activate(VDGUIHandle hParent, DubSource::ErrorMode oldMode);

	void ComputeMode();

protected:
	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	void ReinitDialog();

	const char *const mpszSettingsKey;
	DubSource::ErrorMode	mErrorMode;
	DubSource *const mpSource;
};

DubSource::ErrorMode VDDialogErrorModeW32::Activate(VDGUIHandle hParent, DubSource::ErrorMode oldMode) {
	mErrorMode = oldMode;
	ActivateDialog(hParent);
	return mErrorMode;
}

void VDDialogErrorModeW32::ReinitDialog() {
	EnableWindow(GetDlgItem(mhdlg, IDC_SAVEASDEFAULT), mpszSettingsKey != 0);
	EnableWindow(GetDlgItem(mhdlg, IDC_ERROR_CONCEAL), !mpSource || mpSource->isDecodeErrorModeSupported(DubSource::kErrorModeConceal));
	EnableWindow(GetDlgItem(mhdlg, IDC_ERROR_DECODE), !mpSource || mpSource->isDecodeErrorModeSupported(DubSource::kErrorModeDecodeAnyway));

	CheckDlgButton(mhdlg, IDC_ERROR_REPORTALL,	mErrorMode == DubSource::kErrorModeReportAll);
	CheckDlgButton(mhdlg, IDC_ERROR_CONCEAL,	mErrorMode == DubSource::kErrorModeConceal);
	CheckDlgButton(mhdlg, IDC_ERROR_DECODE,		mErrorMode == DubSource::kErrorModeDecodeAnyway);
}

INT_PTR VDDialogErrorModeW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message)
    {
        case WM_INITDIALOG:
			ReinitDialog();
            return TRUE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				ComputeMode();
				End(true);
				return TRUE;
			case IDCANCEL:
				End(false);
				return TRUE;
			case IDC_SAVEASDEFAULT:
				{
					VDRegistryAppKey key("Preferences");

					ComputeMode();
					key.setInt(mpszSettingsKey, mErrorMode);
				}
				return TRUE;
			}
            break;
    }
    return FALSE;
}

void VDDialogErrorModeW32::ComputeMode() {
	if (IsDlgButtonChecked(mhdlg, IDC_ERROR_REPORTALL))
		mErrorMode = DubSource::kErrorModeReportAll;
	if (IsDlgButtonChecked(mhdlg, IDC_ERROR_CONCEAL))
		mErrorMode = DubSource::kErrorModeConceal;
	if (IsDlgButtonChecked(mhdlg, IDC_ERROR_DECODE))
		mErrorMode = DubSource::kErrorModeDecodeAnyway;
}

DubSource::ErrorMode VDDisplayErrorModeDialog(VDGUIHandle hParent, DubSource::ErrorMode oldMode, const char *pszSettingsKey, DubSource *pSource) {
	VDDialogErrorModeW32 dlg(pszSettingsKey, pSource);

	return dlg.Activate(hParent, oldMode);
}

///////////////////////////////////////////////////////////////////////////
//
//	File info dialog
//
///////////////////////////////////////////////////////////////////////////

class VDDialogFileTextInfoW32 : public VDDialogBaseW32 {
public:
	typedef std::map<uint32, VDStringW> tTextInfo;
	typedef std::list<std::pair<uint32, VDStringA> > tRawTextInfo;

	VDDialogFileTextInfoW32(tRawTextInfo& info);
	void Activate(VDGUIHandle hParent);

protected:
	void Read();
	void Write();
	void ReinitDialog();
	void RedoColumnWidths();
	void BeginEdit(int index);
	void EndEdit(bool write);
	void UpdateRow(int index);

	INT_PTR DlgProc(UINT message, WPARAM wParam, LPARAM lParam);
	static LRESULT CALLBACK LVStaticWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
	LRESULT LVWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
	static LRESULT CALLBACK LVStaticEditProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
	LRESULT LVEditProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

	HWND	mhwndList;
	HWND	mhwndEdit;
	WNDPROC	mOldLVProc;
	WNDPROC	mOldEditProc;
	int		mIndex;
	uint32	mID;

	tTextInfo mTextInfo;
	tRawTextInfo& mTextInfoOrig;

	static const struct FieldEntry {
		uint32 fcc;
		const char *desc;
	} kFields[];
};

const struct VDDialogFileTextInfoW32::FieldEntry VDDialogFileTextInfoW32::kFields[]={
	{ VD_FOURCC('ISBJ'), "Subject" },
	{ VD_FOURCC('IART'), "Artist (Author)" },
	{ VD_FOURCC('ICOP'), "Copyright" },
	{ VD_FOURCC('IARL'), "Archival Location" },
	{ VD_FOURCC('ICMS'), "Commissioned" },
	{ VD_FOURCC('ICMT'), "Comments" },
	{ VD_FOURCC('ICRD'), "Creation Date" },
	{ VD_FOURCC('ICRP'), "Cropped" },
	{ VD_FOURCC('IDIM'), "Dimensions" },
	{ VD_FOURCC('IDPI'), "Dots Per Inch" },
	{ VD_FOURCC('IENG'), "Engineer" },
	{ VD_FOURCC('IGNR'), "Genre" },
	{ VD_FOURCC('IKEY'), "Keywords" },
	{ VD_FOURCC('ILGT'), "Lightness" },
	{ VD_FOURCC('IMED'), "Medium" },
	{ VD_FOURCC('INAM'), "Name" },
	{ VD_FOURCC('IPLT'), "Palette Setting" },
	{ VD_FOURCC('IPRD'), "Product" },
	{ VD_FOURCC('ISFT'), "Software" },
	{ VD_FOURCC('ISHP'), "Sharpness" },
	{ VD_FOURCC('ISRC'), "Source" },
	{ VD_FOURCC('ISRF'), "Source Form" },
	{ VD_FOURCC('ITCH'), "Technician" },
};

VDDialogFileTextInfoW32::VDDialogFileTextInfoW32(tRawTextInfo& info)
	: VDDialogBaseW32(IDD_FILE_SETTEXTINFO)
	, mhwndEdit(NULL)
	, mTextInfoOrig(info)
{
}

void VDDialogFileTextInfoW32::Activate(VDGUIHandle hParent) {
	ActivateDialogDual(hParent);
}

void VDDialogFileTextInfoW32::Read() {
	tRawTextInfo::const_iterator itSrc(mTextInfoOrig.begin()), itSrcEnd(mTextInfoOrig.end());
	for(; itSrc != itSrcEnd; ++itSrc)
		mTextInfo[(*itSrc).first] = VDTextAToW((*itSrc).second);
}

void VDDialogFileTextInfoW32::Write() {
	mTextInfoOrig.clear();

	tTextInfo::const_iterator itSrc(mTextInfo.begin()), itSrcEnd(mTextInfo.end());
	for(; itSrc != itSrcEnd; ++itSrc)
		mTextInfoOrig.push_back(tRawTextInfo::value_type((*itSrc).first, VDTextWToA((*itSrc).second)));
}

void VDDialogFileTextInfoW32::ReinitDialog() {
	HWND hwndList = GetDlgItem(mhdlg, IDC_LIST);

	mhwndList = hwndList;

	SetWindowLong(mhwndList, GWL_STYLE, GetWindowLong(mhwndList, GWL_STYLE) | WS_CLIPCHILDREN);

	union {
		LVCOLUMNA a;
		LVCOLUMNW w;
	} lvc;

	if (VDIsWindowsNT()) {
		SendMessageW(hwndList, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_FULLROWSELECT, LVS_EX_FULLROWSELECT);

		lvc.w.mask = LVCF_TEXT | LVCF_WIDTH;
		lvc.w.pszText = L"Field";
		lvc.w.cx = 50;
		SendMessageW(hwndList, LVM_INSERTCOLUMNW, 0, (LPARAM)&lvc.w);

		lvc.w.pszText = L"Text";
		lvc.w.cx = 100;
		SendMessageW(hwndList, LVM_INSERTCOLUMNW, 0, (LPARAM)&lvc.w);
	} else {
		SendMessageA(hwndList, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_FULLROWSELECT, LVS_EX_FULLROWSELECT);

		lvc.a.mask = LVCF_TEXT | LVCF_WIDTH;
		lvc.a.iSubItem = 0;
		lvc.a.pszText = "Field";
		lvc.a.cx = 50;
		SendMessageA(hwndList, LVM_INSERTCOLUMNA, 0, (LPARAM)&lvc.a);

		lvc.a.pszText = "Text";
		lvc.a.cx = 100;
		SendMessageA(hwndList, LVM_INSERTCOLUMNA, 0, (LPARAM)&lvc.a);
	}

	for(int i=0; i<sizeof kFields / sizeof kFields[0]; ++i) {
		union {
			LVITEMA a;
			LVITEMW w;
		} lvi;

		if (VDIsWindowsNT()) {
			VDStringW wtext(VDTextAToW(kFields[i].desc));
			lvi.w.mask = LVIF_TEXT | LVIF_PARAM;
			lvi.w.pszText = (LPWSTR)wtext.c_str();
			lvi.w.iItem = i;
			lvi.w.iSubItem = 0;
			lvi.w.lParam = (LPARAM)kFields[i].fcc;

			SendMessageW(hwndList, LVM_INSERTITEMW, 0, (LPARAM)&lvi.w);
		} else {
			lvi.a.mask = LVIF_TEXT | LVIF_PARAM;
			lvi.a.pszText = (LPSTR)kFields[i].desc;
			lvi.a.iItem = i;
			lvi.a.iSubItem = 0;
			lvi.a.lParam = (LPARAM)kFields[i].fcc;

			SendMessageA(hwndList, LVM_INSERTITEMA, 0, (LPARAM)&lvi.a);
		}

		UpdateRow(i);
	}

	RedoColumnWidths();

	if (VDIsWindowsNT()) {
		mOldLVProc = (WNDPROC)GetWindowLongPtrW(mhwndList, GWLP_WNDPROC);
		SetWindowLongPtrW(mhwndList, GWLP_USERDATA, (LONG_PTR)this);
		SetWindowLongPtrW(mhwndList, GWLP_WNDPROC, (LONG_PTR)LVStaticWndProc);
	} else {
		mOldLVProc = (WNDPROC)GetWindowLongPtrA(mhwndList, GWLP_WNDPROC);
		SetWindowLongPtrA(mhwndList, GWLP_USERDATA, (LONG_PTR)this);
		SetWindowLongPtrA(mhwndList, GWLP_WNDPROC, (LONG_PTR)LVStaticWndProc);
	}
}

void VDDialogFileTextInfoW32::RedoColumnWidths() {
	SendMessage(mhwndList, LVM_SETCOLUMNWIDTH, 0, LVSCW_AUTOSIZE);
	SendMessage(mhwndList, LVM_SETCOLUMNWIDTH, 1, LVSCW_AUTOSIZE_USEHEADER);
}

void VDDialogFileTextInfoW32::BeginEdit(int index) {
	RECT r;
	int w=0, w2=0;
	int i;

	ListView_EnsureVisible(mhwndList, index, FALSE);

	for(i=0; i<=1; i++)
		w2 += w = SendMessage(mhwndList, LVM_GETCOLUMNWIDTH, i, 0);

	EndEdit(true);

	r.left = LVIR_BOUNDS;

	LVITEM lvi;
	lvi.mask = LVIF_PARAM;
	lvi.iItem = index;
	lvi.iSubItem = 0;
	ListView_GetItem(mhwndList, &lvi);
	SendMessage(mhwndList, LVM_GETITEMRECT, index, (LPARAM)&r);

	mID = lvi.lParam;
	mIndex = index;

	DWORD dwEditStyle = WS_VISIBLE|WS_CHILD|WS_BORDER | ES_WANTRETURN|ES_AUTOHSCROLL;

	r.left = w2-w;
	r.right = w2;

	InflateRect(&r, GetSystemMetrics(SM_CXEDGE), GetSystemMetrics(SM_CYEDGE));

	AdjustWindowRect(&r, dwEditStyle, FALSE);

	if (VDIsWindowsNT()) {
		mhwndEdit = CreateWindowW(L"EDIT",
				NULL,
				dwEditStyle,
				r.left,
				r.top,
				r.right - r.left,
				r.bottom - r.top,
				mhwndList, (HMENU)1, g_hInst, NULL);
	} else {
		mhwndEdit = CreateWindowA("EDIT",
				NULL,
				dwEditStyle,
				r.left,
				r.top,
				r.right - r.left,
				r.bottom - r.top,
				mhwndList, (HMENU)1, g_hInst, NULL);
	}
	
	if (mhwndEdit) {
		if (VDIsWindowsNT()) {
			mOldEditProc = (WNDPROC)GetWindowLongPtrW(mhwndEdit, GWLP_WNDPROC);
			SetWindowLongPtrW(mhwndEdit, GWLP_USERDATA, (LONG_PTR)this);
			SetWindowLongPtrW(mhwndEdit, GWLP_WNDPROC, (LONG_PTR)LVStaticEditProc);
		} else {
			mOldEditProc = (WNDPROC)GetWindowLongPtrA(mhwndEdit, GWLP_WNDPROC);
			SetWindowLongPtrA(mhwndEdit, GWLP_USERDATA, (LONG_PTR)this);
			SetWindowLongPtrA(mhwndEdit, GWLP_WNDPROC, (LONG_PTR)LVStaticEditProc);
		}

		SendMessage(mhwndEdit, WM_SETFONT, SendMessage(mhwndList, WM_GETFONT, 0, 0), MAKELPARAM(FALSE,0));

		tTextInfo::iterator it(mTextInfo.find(mID));
		if (it != mTextInfo.end())
			VDSetWindowTextW32(mhwndEdit, (*it).second.c_str());

		SetFocus(mhwndEdit);
	}
}

void VDDialogFileTextInfoW32::EndEdit(bool write) {
	if (!mhwndEdit)
		return;

	if (write) {
		const VDStringW text(VDGetWindowTextW32(mhwndEdit));

		if (text.empty())
			mTextInfo.erase(mID);
		else
			mTextInfo[mID] = text;

		UpdateRow(mIndex);
	}

	DestroyWindow(mhwndEdit);
	mhwndEdit = NULL;
}

void VDDialogFileTextInfoW32::UpdateRow(int index) {
	union {
		LVITEMA a;
		LVITEMW w;
	} lvi;

	uint32 id;

	if (VDIsWindowsNT()) {
		lvi.w.mask = LVIF_PARAM;
		lvi.w.iItem = index;
		lvi.w.iSubItem = 0;
		SendMessageW(mhwndList, LVM_GETITEMW, 0, (LPARAM)&lvi.w);
		id = lvi.w.lParam;
	} else {
		lvi.a.mask = LVIF_PARAM;
		lvi.a.iItem = index;
		lvi.a.iSubItem = 0;
		SendMessageA(mhwndList, LVM_GETITEMA, 0, (LPARAM)&lvi.a);
		id = lvi.a.lParam;
	}

	const wchar_t *text = L"";

	tTextInfo::iterator it(mTextInfo.find(id));
	if (it != mTextInfo.end())
		text = (*it).second.c_str();

	if (VDIsWindowsNT()) {
		lvi.w.mask = LVIF_TEXT;
		lvi.w.iSubItem = 1;
		lvi.w.pszText = (LPWSTR)text;
		SendMessageW(mhwndList, LVM_SETITEMW, 0, (LPARAM)&lvi.w);
		id = lvi.w.lParam;
	} else {
		VDStringA textA(VDTextWToA(text));
		lvi.a.mask = LVIF_TEXT;
		lvi.a.iSubItem = 1;
		lvi.a.pszText = (LPSTR)textA.c_str();
		SendMessageA(mhwndList, LVM_SETITEMA, 0, (LPARAM)&lvi.a);
		id = lvi.a.lParam;
	}
}

INT_PTR VDDialogFileTextInfoW32::DlgProc(UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message)
    {
        case WM_INITDIALOG:
			Read();
			ReinitDialog();
			SetFocus(mhwndList);
            return FALSE;

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				EndEdit(true);
				Write();
				End(true);
				return TRUE;
			case IDCANCEL:
				EndEdit(false);
				End(false);
				return TRUE;
			}
            break;
    }
    return FALSE;
}

LRESULT CALLBACK VDDialogFileTextInfoW32::LVStaticWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
	VDDialogFileTextInfoW32 *p = (VDDialogFileTextInfoW32 *)GetWindowLongPtr(hwnd, GWLP_USERDATA);

	return p->LVWndProc(hwnd, msg, wParam, lParam);
}

LRESULT VDDialogFileTextInfoW32::LVWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
	switch(msg) {
	case WM_DESTROY:
		EndEdit(true);
		break;

	case WM_GETDLGCODE:
		if (lParam) {
			const MSG& msg = *(const MSG *)lParam;

			if (msg.message == WM_KEYDOWN && wParam == VK_RETURN)
				return DLGC_WANTMESSAGE;
		} else
			return VDDualCallWindowProcW32(mOldLVProc, hwnd, msg, wParam, lParam) | DLGC_WANTALLKEYS;

		break;

	case WM_KEYDOWN:
		if (wParam == VK_RETURN) {
			int index = VDDualCallWindowProcW32(mOldLVProc, hwnd, LVM_GETNEXTITEM, -1, MAKELPARAM(LVNI_ALL|LVNI_SELECTED,0));

			if (index>=0)
				BeginEdit(index);
		}
		break;

	case WM_LBUTTONDOWN:
		{
			LVHITTESTINFO htinfo;
			LVITEM lvi;
			int index;

			// if this isn't done, the control doesn't gain focus properly...

			VDDualCallWindowProcW32(mOldLVProc, hwnd, msg, wParam, lParam);

			htinfo.pt.x	= 2;
			htinfo.pt.y = HIWORD(lParam);

			index = VDDualCallWindowProcW32(mOldLVProc, hwnd, LVM_HITTEST, 0, (LPARAM)&htinfo);

			if (index >= 0) {
				int x = LOWORD(lParam);
				int w2=0, w;
				int i=-1;

				lvi.state = lvi.stateMask = LVIS_SELECTED | LVIS_FOCUSED;
				VDDualCallWindowProcW32(mOldLVProc, hwnd, LVM_SETITEMSTATE, index, (LPARAM)&lvi);

				for(i=0; i<3; i++) {
					w2 += w = VDDualCallWindowProcW32(mOldLVProc, hwnd, LVM_GETCOLUMNWIDTH, i, 0);
					if (x<w2) {
						BeginEdit(index);

						return 0;
					}
				}
			}
			EndEdit(true);
		}
		return 0;
	}
	return VDDualCallWindowProcW32(mOldLVProc, hwnd, msg, wParam, lParam);
}

LRESULT CALLBACK VDDialogFileTextInfoW32::LVStaticEditProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
	VDDialogFileTextInfoW32 *p = (VDDialogFileTextInfoW32 *)GetWindowLongPtr(hwnd, GWLP_USERDATA);

	return p->LVEditProc(hwnd, msg, wParam, lParam);
}

LRESULT VDDialogFileTextInfoW32::LVEditProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
	switch(msg) {
	case WM_GETDLGCODE:
		return VDDualCallWindowProcW32(mOldEditProc, hwnd, msg, wParam, lParam) | DLGC_WANTALLKEYS;
		break;
	case WM_KEYDOWN:
		if (wParam == VK_UP) {
			if (mIndex > 0) {
				ListView_SetItemState(mhwndList, -1, 0, LVIS_SELECTED|LVIS_FOCUSED);
				ListView_SetItemState(mhwndList, mIndex-1, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED);
				BeginEdit(mIndex-1);
			}
			return 0;
		} else if (wParam == VK_DOWN) {
			if (mIndex < SendMessage(mhwndList, LVM_GETITEMCOUNT, 0, 0)-1) {
				ListView_SetItemState(mhwndList, -1, 0, LVIS_SELECTED|LVIS_FOCUSED);
				ListView_SetItemState(mhwndList, mIndex+1, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED);
				BeginEdit(mIndex+1);
			}
			return 0;
		}
		break;
	case WM_CHAR:
		if (wParam == 0x0d) {
			EndEdit(true);
			return 0;
		} else if (wParam == 0x1b) {
			EndEdit(false);
			return 0;
		}
		break;
	case WM_KILLFOCUS:
		EndEdit(true);
		break;
	case WM_ACTIVATE:
		if (LOWORD(wParam) == WA_INACTIVE)
			EndEdit(true);
		break;
	}
	return VDDualCallWindowProcW32(mOldEditProc, hwnd, msg, wParam, lParam);
}

void VDDisplayFileTextInfoDialog(VDGUIHandle hParent, std::list<std::pair<uint32, VDStringA> >& info) {
	VDDialogFileTextInfoW32 dlg(info);

	dlg.Activate(hParent);
}
