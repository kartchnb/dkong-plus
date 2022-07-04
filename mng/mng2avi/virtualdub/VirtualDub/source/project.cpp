//	VirtualDub - Video processing and capture application
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

#include <stdafx.h>
#include <windows.h>
#include <vd2/system/filesys.h>
#include <vd2/system/file.h>
#include <vd2/system/thread.h>
#include <vd2/system/atomic.h>
#include <vd2/system/time.h>
#include <vd2/system/VDScheduler.h>
#include <vd2/Dita/services.h>
#include <vd2/Kasumi/pixmap.h>
#include <vd2/Kasumi/pixmapops.h>
#include "project.h"
#include "VideoSource.h"
#include "AudioSource.h"
#include "InputFile.h"
#include "prefs.h"
#include "dub.h"
#include "DubOutput.h"
#include "DubStatus.h"
#include "filter.h"
#include "command.h"
#include "job.h"
#include "server.h"
#include "capture.h"
#include "script.h"
#include "SceneDetector.h"
#include "oshelper.h"
#include "resource.h"
#include "uiframe.h"

///////////////////////////////////////////////////////////////////////////

extern const char g_szError[];
extern const char g_szWarning[];

extern HINSTANCE g_hInst;

extern VDProject *g_project;
extern InputFileOptions	*g_pInputOpts;

DubSource::ErrorMode	g_videoErrorMode			= DubSource::kErrorModeReportAll;
DubSource::ErrorMode	g_audioErrorMode			= DubSource::kErrorModeReportAll;

vdrefptr<AudioSource>	inputAudio;
vdrefptr<AudioSource>	inputAudioAVI;
vdrefptr<AudioSource>	inputAudioWAV;

extern bool				g_fDropFrames;
extern bool				g_fSwapPanes;
extern bool				g_bExit;

extern bool g_fJobMode;
extern bool g_fJobAborted;

extern wchar_t g_szInputAVIFile[MAX_PATH];
extern wchar_t g_szInputWAVFile[MAX_PATH];

extern void CPUTest();
extern void PreviewAVI(HWND, DubOptions *, int iPriority=0, bool fProp=false);

///////////////////////////////////////////////////////////////////////////

namespace {

	void CopyFrameToClipboard(HWND hwnd, const VBitmap& vbm) {
		if (OpenClipboard(hwnd)) {
			if (EmptyClipboard()) {
				BITMAPINFOHEADER bih;
				long lFormatSize;
				HANDLE hMem;
				void *lpvMem;

				vbm.MakeBitmapHeaderNoPadding(&bih);
				lFormatSize = bih.biSize;

				if (hMem = GlobalAlloc(GMEM_MOVEABLE | GMEM_DDESHARE, bih.biSizeImage + lFormatSize)) {
					if (lpvMem = GlobalLock(hMem)) {
						memcpy(lpvMem, &bih, lFormatSize);

						VBitmap((char *)lpvMem + lFormatSize, &bih).BitBlt(0, 0, &vbm, 0, 0, -1, -1); 

						GlobalUnlock(lpvMem);
						SetClipboardData(CF_DIB, hMem);
						CloseClipboard();
						return;
					}
					GlobalFree(hMem);
				}
			}
			CloseClipboard();
		}
	}

	void SetAudioSource() {
		switch(audioInputMode) {
		case AUDIOIN_NONE:		inputAudio = NULL; break;
		case AUDIOIN_AVI:		inputAudio = inputAudioAVI; break;
		case AUDIOIN_WAVE:		inputAudio = inputAudioWAV; break;
		}
	}
}

///////////////////////////////////////////////////////////////////////////

class VDProjectSchedulerThread : public VDThread {
public:
	VDProjectSchedulerThread() : mbRunning(true) { }
	~VDProjectSchedulerThread() { Stop(); }

	void Start(VDScheduler *pSched, int affin) {
		mpScheduler = pSched;
		mAffinity = affin;
		ThreadStart();
	}

	void PreStop() {
		mbRunning = false;
		mpScheduler->Add(&mSpinner);
	}

	void Stop() {
		ThreadWait();
		mpScheduler->Remove(&mSpinner);
	}

	void ThreadRun() {
		while(mbRunning) {
			if (!mpScheduler->Run())
				mpScheduler->IdleWait();
		}

		mpScheduler->Ping();	// Transfer control to another scheduler thread.
	}

protected:
	VDAtomicInt	mbRunning;
	VDScheduler	*mpScheduler;
	uint32		mAffinity;
	struct spinner : public VDSchedulerNode { bool Service() { return true; } } mSpinner;
};

///////////////////////////////////////////////////////////////////////////

VDProject::VDProject()
	: mhwnd(NULL)
	, mpSceneDetector(0)
	, mSceneShuttleMode(0)
	, mSceneShuttleAdvance(0)
	, mSceneShuttleCounter(0)
	, mpDubStatus(0)
	, mposCurrentFrame(0)
	, mposSelectionStart(0)
	, mposSelectionEnd(0)
	, mDesiredInputFrame(-1)
	, mDesiredOutputFrame(-1)
	, mDesiredNextInputFrame(-1)
	, mDesiredNextOutputFrame(-1)
	, mLastDisplayedInputFrame(-1)
	, mVideoInputFrameRate(0,0)
//	, mpSchedulerThreads(NULL)
{

	// We don't need the scheduler yet.
#if 0
	DWORD_PTR myAff, sysAff;

	if (!GetProcessAffinityMask(GetCurrentProcess(), &myAff, &sysAff)) {
		myAff = sysAff = 1;
	}

	int threads = 0;
	for(DWORD t = myAff; t; t &= (t-1))
		++threads;

	mScheduler.setSignal(&mSchedulerSignal);
	mpSchedulerThreads = new VDProjectSchedulerThread[threads];
	mThreadCount = threads;

	int i=0;
	for(DWORD t2 = myAff; t2; t2 &= (t2-1))
		mpSchedulerThreads[i++].Start(&mScheduler, t2);
#endif
}

VDProject::~VDProject() {
#if 0
	// We have to issue prestops first to make sure that all threads have
	// spinners running.
	for(int i=0; i<mThreadCount; ++i)
		mpSchedulerThreads[i].PreStop();

	delete[] mpSchedulerThreads;
#endif
}

bool VDProject::Attach(VDGUIHandle hwnd) {	
	mhwnd = hwnd;
	return true;
}

void VDProject::Detach() {
	mhwnd = NULL;
}

void VDProject::EndTimelineUpdate() {
	UpdateDubParameters();
	UITimelineUpdated();
}

bool VDProject::Tick() {
	bool active = false;

	if (inputVideoAVI && mSceneShuttleMode) {
		if (!mpSceneDetector)
			mpSceneDetector = new_nothrow SceneDetector(inputVideoAVI->getImageFormat()->biWidth, inputVideoAVI->getImageFormat()->biHeight);

		if (mpSceneDetector) {
			mpSceneDetector->SetThresholds(g_prefs.scene.iCutThreshold, g_prefs.scene.iFadeThreshold);

			SceneShuttleStep();
			active = true;
		} else
			SceneShuttleStop();
	} else {
		if (mpSceneDetector) {
			delete mpSceneDetector;
			mpSceneDetector = NULL;
		}
	}

	if (UpdateFrame())
		active = true;

	return active;
}

VDPosition VDProject::GetCurrentFrame() {
	return mposCurrentFrame;
}

VDPosition VDProject::GetFrameCount() {
	return mTimeline.GetLength();
}

VDFraction VDProject::GetInputFrameRate() {
	return mVideoInputFrameRate;
}

void VDProject::ClearSelection() {
	mposSelectionStart = 0;
	mposSelectionEnd = -1;
	g_dubOpts.video.lStartOffsetMS = 0;
	g_dubOpts.video.lEndOffsetMS = 0;
	UISelectionUpdated();
}

bool VDProject::IsSelectionEmpty() {
	return mposSelectionStart >= mposSelectionEnd;
}

bool VDProject::IsSelectionPresent() {
	return mposSelectionStart <= mposSelectionEnd;
}

VDPosition VDProject::GetSelectionStartFrame() {
	return mposSelectionStart;
}

VDPosition VDProject::GetSelectionEndFrame() {
	return mposSelectionEnd;
}

bool VDProject::IsClipboardEmpty() {
	return mClipboard.empty();
}

void VDProject::Cut() {
	Copy();
	Delete();
}

void VDProject::Copy() {
	FrameSubset& s = mTimeline.GetSubset();
	mClipboard.assign(s, mposSelectionStart, mposSelectionEnd - mposSelectionStart);
}

void VDProject::Paste() {
	FrameSubset& s = mTimeline.GetSubset();

	s.insert(mposCurrentFrame, mClipboard);
	UITimelineUpdated();
	ClearSelection();
}

void VDProject::Delete() {
	VDPosition pos = GetCurrentFrame();
	VDPosition start = GetSelectionStartFrame();
	VDPosition end = GetSelectionEndFrame();

	FrameSubset& s = mTimeline.GetSubset();
	if (!IsSelectionEmpty())
		s.deleteRange(start, end-start);
	else {
		start = pos;
		s.deleteRange(pos, 1);
	}

	UITimelineUpdated();
	ClearSelection();
	MoveToFrame(start);
}

void VDProject::MaskSelection(bool bNewMode) {
	VDPosition pos = GetCurrentFrame();
	VDPosition start = GetSelectionStartFrame();
	VDPosition end = GetSelectionEndFrame();

	FrameSubset& s = mTimeline.GetSubset();
	if (!IsSelectionEmpty())
		s.setRange(start, end-start, bNewMode);
	else {
		start = pos;
		s.setRange(pos, 1, bNewMode);
	}

	UITimelineUpdated();
	ClearSelection();
	MoveToFrame(start);
}

void VDProject::DisplayFrame(bool bDispInput) {
	VDPosition pos = mposCurrentFrame;
	VDPosition original_pos = pos;

	if (!g_dubOpts.video.fShowInputFrame && !g_dubOpts.video.fShowOutputFrame)
		return;

	try {
		pos = mTimeline.TimelineToSourceFrame(pos);

		if (pos < 0)
			pos = inputVideoAVI->getEnd();

		bool bShowOutput = !mSceneShuttleMode && !g_dubber && g_dubOpts.video.fShowOutputFrame;

		if (mLastDisplayedInputFrame != pos || !inputVideoAVI->isFrameBufferValid() || (bShowOutput && !filters.isRunning())) {
			if (bDispInput)
				mLastDisplayedInputFrame = pos;

			if (pos >= inputVideoAVI->getEnd()) {
				if (g_dubOpts.video.fShowInputFrame && bDispInput)
					UIRefreshInputFrame(false);
				if (bShowOutput)
					UIRefreshOutputFrame(false);
			} else {
				if (bShowOutput && !filters.isRunning())
					CPUTest();

				if (mDesiredInputFrame < 0)
					inputVideoAVI->streamBegin(false, false);

				bool replace = true;

				if (mDesiredInputFrame >= 0) {
					inputVideoAVI->streamSetDesiredFrame(pos);
					int to_new = inputVideoAVI->streamGetRequiredCount(NULL);
					inputVideoAVI->streamSetDesiredFrame(mDesiredInputFrame);
					int to_current = inputVideoAVI->streamGetRequiredCount(NULL);

					if (to_current < to_new)
						replace = false;
				}

				if (replace) {
					inputVideoAVI->streamSetDesiredFrame(pos);
					mDesiredInputFrame	= pos;
					mDesiredOutputFrame = original_pos;
					mDesiredNextInputFrame = -1;
					mDesiredNextOutputFrame = -1;
				} else {
					mDesiredNextInputFrame	= pos;
					mDesiredNextOutputFrame = original_pos;
				}
				mbUpdateInputFrame	= bDispInput;
				mbUpdateOutputFrame	= bShowOutput;
				mbUpdateLong		= false;
				mFramesDecoded		= 0;
				mLastDecodeUpdate	= VDGetCurrentTick();

				UpdateFrame();
			}
		}

	} catch(const MyError& e) {
		const char *src = e.gets();
		char *dst = strdup(src);

		if (!dst)
			guiSetStatus("%s", 255, e.gets());
		else {
			for(char *t = dst; *t; ++t)
				if (*t == '\n')
					*t = ' ';

			guiSetStatus("%s", 255, dst);
			free(dst);
		}
		SceneShuttleStop();
	}
}

bool VDProject::UpdateFrame() {
	if (mDesiredInputFrame < 0)
		return false;

	if (!inputVideoAVI) {
		if (g_dubOpts.video.fShowInputFrame && mbUpdateInputFrame)
			UIRefreshInputFrame(false);

		if (mbUpdateOutputFrame)
			UIRefreshOutputFrame(false);

		if (mbUpdateLong)
			guiSetStatus("", 255);

		mDesiredInputFrame = -1;
		mDesiredOutputFrame = -1;
		mDesiredNextInputFrame = -1;
		mDesiredNextOutputFrame = -1;
		return false;
	}

	uint32 startTime = VDGetCurrentTick();

	try {
		for(;;) {
			bool preroll;

			VDPosition frame = inputVideoAVI->streamGetNextRequiredFrame(preroll);

			if (frame >= 0) {
				uint32 bytes, samples;

				int err = AVIERR_BUFFERTOOSMALL;
				
				if (!mVideoSampleBuffer.empty())
					err = inputVideoAVI->read(frame, 1, mVideoSampleBuffer.data(), mVideoSampleBuffer.size(), &bytes, &samples);

				if (err == AVIERR_BUFFERTOOSMALL) {
					inputVideoAVI->read(frame, 1, NULL, 0, &bytes, &samples);
					if (!bytes)
						++bytes;
					VDASSERT(bytes > mVideoSampleBuffer.size());
					mVideoSampleBuffer.resize(bytes);
					err = inputVideoAVI->read(frame, 1, mVideoSampleBuffer.data(), mVideoSampleBuffer.size(), &bytes, &samples);
				}

				if (err != AVIERR_OK)
					throw MyAVIError("Display", err);

				if (samples > 0)
					inputVideoAVI->streamGetFrame(mVideoSampleBuffer.data(), bytes, preroll, frame);

				++mFramesDecoded;

				uint32 nCurrentTime = VDGetCurrentTick();

				if (nCurrentTime - mLastDecodeUpdate > 500) {
					mLastDecodeUpdate = nCurrentTime;
					mbUpdateLong = true;

					guiSetStatus("Decoding frame %lu: preloading frame %lu", 255, (unsigned long)mDesiredInputFrame, (unsigned long)inputVideoAVI->streamToDisplayOrder(frame));
				}

				if (nCurrentTime - startTime > 100)
					break;

			} else {
				if (!mFramesDecoded)
					inputVideoAVI->streamGetFrame(NULL, 0, preroll, inputVideoAVI->displayToStreamOrder(mDesiredInputFrame));

				if (g_dubOpts.video.fShowInputFrame && mbUpdateInputFrame)
					UIRefreshInputFrame(true);

				if (mbUpdateOutputFrame) {
					RefilterFrame();

					UIRefreshOutputFrame(true);
				}

				if (mbUpdateLong)
					guiSetStatus("", 255);

				mDesiredInputFrame = mDesiredNextInputFrame;
				mDesiredOutputFrame = mDesiredNextOutputFrame;
				mDesiredNextInputFrame = -1;
				mDesiredNextOutputFrame = -1;

				if (mDesiredInputFrame >= 0)
					inputVideoAVI->streamSetDesiredFrame(mDesiredInputFrame);
				break;
			}
		}
	} catch(const MyError& e) {
		const char *src = e.gets();
		char *dst = strdup(src);

		if (!dst)
			guiSetStatus("%s", 255, e.gets());
		else {
			for(char *t = dst; *t; ++t)
				if (*t == '\n')
					*t = ' ';

			guiSetStatus("%s", 255, dst);
			free(dst);
		}
		SceneShuttleStop();
		mDesiredInputFrame = -1;
		mDesiredOutputFrame = -1;
		mDesiredNextInputFrame = -1;
		mDesiredNextOutputFrame = -1;
	}

	return mDesiredInputFrame >= 0;
}

void VDProject::RefilterFrame() {
	const VDFraction framerate(inputVideoAVI->getRate());

	mfsi.lCurrentFrame				= (long)mDesiredOutputFrame;
	mfsi.lMicrosecsPerFrame			= (long)framerate.scale64ir(1000000);
	mfsi.lCurrentSourceFrame		= (long)mDesiredInputFrame;
	mfsi.lMicrosecsPerSrcFrame		= (long)framerate.scale64ir(1000000);
	mfsi.lSourceFrameMS				= (long)framerate.scale64ir(mfsi.lCurrentSourceFrame * (sint64)1000);
	mfsi.lDestFrameMS				= (long)framerate.scale64ir(mfsi.lCurrentFrame * (sint64)1000);
	mfsi.flags						= FilterStateInfo::kStatePreview;

	BITMAPINFOHEADER *dcf = inputVideoAVI->getDecompressedFormat();

	if (!filters.isRunning()) {
		filters.initLinearChain(&g_listFA, (Pixel *)(dcf+1), dcf->biWidth, dcf->biHeight, 0);
		if (filters.ReadyFilters(&mfsi))
			throw MyError("can't initialize filters");
	}

	VDPixmapBlt(VDAsPixmap(*filters.InputBitmap()), inputVideoAVI->getTargetFormat());

	filters.RunFilters();
}

///////////////////////////////////////////////////////////////////////////

void VDProject::Quit() {
	VDUIFrame *pFrame = VDUIFrame::GetFrame((HWND)mhwnd);

	if (VDINLINEASSERT(pFrame))
		pFrame->Destroy();
}

void VDProject::Open(const wchar_t *pFilename, IVDInputDriver *pSelectedDriver, bool fExtendedOpen, bool fQuiet, bool fAutoscan, const char *pInputOpts) {
	Close();

	try {
		// attempt to determine input file type

		VDStringW filename(VDGetFullPath(pFilename));

		if (!pSelectedDriver) {
			pSelectedDriver = VDAutoselectInputDriverForFile(filename.c_str());
		}

		// open file

		inputAVI = pSelectedDriver->CreateInputFile((fQuiet?IVDInputDriver::kOF_Quiet:0) + (fAutoscan?IVDInputDriver::kOF_AutoSegmentScan:0));
		if (!inputAVI) throw MyMemoryError();

		// Extended open?

		if (fExtendedOpen)
			g_pInputOpts = inputAVI->promptForOptions((HWND)mhwnd);
		else if (pInputOpts)
			g_pInputOpts = inputAVI->createOptions(pInputOpts);

		if (g_pInputOpts)
			inputAVI->setOptions(g_pInputOpts);

		inputAVI->Init(filename.c_str());

		inputAudioAVI = inputAVI->audioSrc;
		inputVideoAVI = inputAVI->videoSrc;

		if (!inputVideoAVI->setDecompressedFormat(24))
			if (!inputVideoAVI->setDecompressedFormat(32))
				if (!inputVideoAVI->setDecompressedFormat(16))
					inputVideoAVI->setDecompressedFormat(8);

		inputVideoAVI->setDecodeErrorMode(g_videoErrorMode);

		if (inputAudioAVI)
			inputAudioAVI->setDecodeErrorMode(g_audioErrorMode);

		// How many items did we get?

		{
			InputFilenameNode *pnode = inputAVI->listFiles.AtHead();
			InputFilenameNode *pnode_next;
			int nFiles = 0;

			while(pnode_next = pnode->NextFromHead()) {
				++nFiles;
				pnode = pnode_next;
			}

			if (nFiles > 1)
				guiSetStatus("Autoloaded %d segments (last was \"%s\")", 255, nFiles, pnode->NextFromTail()->name);
		}

		// Retrieve info text

		inputAVI->GetTextInfo(mTextInfo);

		// Set current filename

		wcscpy(g_szInputAVIFile, filename.c_str());

		mTimeline.SetVideoSource(inputVideoAVI);
		mTimeline.SetFromSource();

		ClearSelection();
		g_dubOpts.video.lStartOffsetMS = g_dubOpts.video.lEndOffsetMS = 0;
		UITimelineUpdated();
		SetAudioSource();
		UpdateDubParameters();
		UISourceFileUpdated();
		UIVideoSourceUpdated();
		MoveToFrame(0);
	} catch(const MyError&) {
		Close();
		throw;
	}
}

void VDProject::OpenWAV(const wchar_t *szFile) {
	vdrefptr<AudioSourceWAV> pNewAudio(new AudioSourceWAV(szFile, g_dubOpts.perf.waveBufferSize));
	if (!pNewAudio->init())
		throw MyError("The sound file \"%s\" could not be processed. Please check that it is a valid WAV file.", VDTextWToA(szFile).c_str());

	pNewAudio->setDecodeErrorMode(g_audioErrorMode);

	wcscpy(g_szInputWAVFile, szFile);

	audioInputMode = AUDIOIN_WAVE;
	inputAudio = inputAudioWAV = pNewAudio;
}

void VDProject::CloseWAV() {
	if (inputAudioWAV) {
		if (inputAudio == inputAudioWAV) {
			inputAudio = NULL;
			audioInputMode = AUDIOIN_NONE;
		}
		inputAudioWAV = NULL;
	}
}

void VDProject::PreviewInput() {
	VDPosition start = g_project->GetCurrentFrame();
	DubOptions dubOpt(g_dubOpts);

	LONG preload = inputAudio && inputAudio->getWaveFormat()->wFormatTag != WAVE_FORMAT_PCM ? 1000 : 500;

	if (dubOpt.audio.preload > preload)
		dubOpt.audio.preload = preload;

	dubOpt.audio.enabled				= TRUE;
	dubOpt.audio.interval				= 1;
	dubOpt.audio.is_ms					= FALSE;
	dubOpt.video.lStartOffsetMS			= (long)inputVideoAVI->samplesToMs(start);

	dubOpt.audio.fStartAudio			= TRUE;
	dubOpt.audio.new_rate				= 0;
	dubOpt.audio.newPrecision			= DubAudioOptions::P_NOCHANGE;
	dubOpt.audio.newChannels			= DubAudioOptions::C_NOCHANGE;
	dubOpt.audio.volume				= 0;
	dubOpt.audio.bUseAudioFilterGraph	= false;

	switch(g_prefs.main.iPreviewDepth) {
	case PreferencesMain::DEPTH_DISPLAY:
		{
			DEVMODE dm;
			dm.dmSize = sizeof(DEVMODE);
			dm.dmDriverExtra = 0;
			if (!EnumDisplaySettings(NULL, ENUM_CURRENT_SETTINGS, &dm))
				dm.dmBitsPerPel = 16;

			switch(dm.dmBitsPerPel) {
			case 24:
				dubOpt.video.mInputFormat = nsVDPixmap::kPixFormat_RGB888;
				break;
			case 32:
				dubOpt.video.mInputFormat = nsVDPixmap::kPixFormat_XRGB8888;
				break;
			default:
				dubOpt.video.mInputFormat = nsVDPixmap::kPixFormat_XRGB1555;
				break;
			}
		}
		break;
	case PreferencesMain::DEPTH_FASTEST:
	case PreferencesMain::DEPTH_16BIT:
		dubOpt.video.mInputFormat = nsVDPixmap::kPixFormat_XRGB1555;
		break;
	case PreferencesMain::DEPTH_24BIT:
		dubOpt.video.mInputFormat = nsVDPixmap::kPixFormat_RGB888;
		break;

	// Ignore: PreferencesMain::DEPTH_OUTPUT

	};

	dubOpt.video.mOutputFormat			= dubOpt.video.mInputFormat;

	dubOpt.video.mode					= DubVideoOptions::M_SLOWREPACK;
	dubOpt.video.fShowInputFrame		= TRUE;
	dubOpt.video.fShowOutputFrame		= FALSE;
	dubOpt.video.frameRateDecimation	= 1;
	dubOpt.video.lEndOffsetMS			= 0;

	dubOpt.audio.mode					= DubAudioOptions::M_FULL;

	dubOpt.fShowStatus = false;
	dubOpt.fMoveSlider = true;

	if (start < mTimeline.GetLength())
		PreviewAVI((HWND)mhwnd, &dubOpt, g_prefs.main.iPreviewPriority);
}

void VDProject::PreviewOutput() {
	VDPosition start = g_project->GetCurrentFrame();
	DubOptions dubOpt(g_dubOpts);

	LONG preload = inputAudio && inputAudio->getWaveFormat()->wFormatTag != WAVE_FORMAT_PCM ? 1000 : 500;

	if (dubOpt.audio.preload > preload)
		dubOpt.audio.preload = preload;

	dubOpt.audio.enabled				= TRUE;
	dubOpt.audio.interval				= 1;
	dubOpt.audio.is_ms					= FALSE;
	dubOpt.video.lStartOffsetMS			= (long)inputVideoAVI->samplesToMs(start);

	dubOpt.fShowStatus = false;
	dubOpt.fMoveSlider = true;

	if (start < mTimeline.GetLength())
		PreviewAVI((HWND)mhwnd, &dubOpt, g_prefs.main.iPreviewPriority);
}

void VDProject::PreviewAll() {
	PreviewAVI((HWND)mhwnd, NULL, g_prefs.main.iPreviewPriority);
}

void VDProject::CloseAVI() {
	if (g_pInputOpts) {
		delete g_pInputOpts;
		g_pInputOpts = NULL;
	}

	if (inputAudio == inputAudioAVI)
		inputAudio = NULL;

	inputAudioAVI = NULL;
	inputVideoAVI = NULL;
	inputAVI = NULL;

	mTextInfo.clear();

	filters.DeinitFilters();
	filters.DeallocateBuffers();
}

void VDProject::Close() {
	CloseAVI();
	UIVideoSourceUpdated();
	UISourceFileUpdated();
}

void VDProject::StartServer() {
	VDGUIHandle hwnd = mhwnd;

	VDUIFrame *pFrame = VDUIFrame::GetFrame((HWND)hwnd);

	pFrame->SetNextMode(3);
	pFrame->Detach();
}

void VDProject::ShowInputInfo() {
	if (inputAVI)
		inputAVI->InfoDialog((HWND)mhwnd);
}

void VDProject::SetVideoMode(int mode) {
	g_dubOpts.video.mode = (char)mode;
}

void VDProject::CopySourceFrameToClipboard() {
	if (!inputVideoAVI || !inputVideoAVI->isFrameBufferValid())
		return;

	CopyFrameToClipboard((HWND)mhwnd, VBitmap((void *)inputVideoAVI->getFrameBuffer(), inputVideoAVI->getDecompressedFormat()));
}

void VDProject::CopyOutputFrameToClipboard() {
	if (!filters.isRunning())
		return;
	CopyFrameToClipboard((HWND)mhwnd, *filters.LastBitmap());
}

void VDProject::SetAudioSourceNone() {
	audioInputMode = AUDIOIN_NONE;
	CloseWAV();
	SetAudioSource();
}

void VDProject::SetAudioSourceNormal() {
	audioInputMode = AUDIOIN_AVI;
	CloseWAV();
	SetAudioSource();
}

void VDProject::SetAudioMode(int mode) {
	g_dubOpts.audio.mode = (char)mode;
}

void VDProject::SetSelectionStart() {
	if (inputAVI)
		SetSelectionStart(GetCurrentFrame());
}

void VDProject::SetSelectionStart(VDPosition pos) {
	if (inputAVI) {
		if (pos < 0)
			pos = 0;
		if (pos > GetFrameCount())
			pos = GetFrameCount();
		mposSelectionStart = pos;
		if (mposSelectionEnd < mposSelectionStart)
			mposSelectionEnd = mposSelectionStart;
		g_dubOpts.video.lStartOffsetMS = (long)inputVideoAVI->samplesToMs(pos);

		UISelectionUpdated();
	}
}

void VDProject::SetSelectionEnd() {
	if (inputAVI)
		SetSelectionEnd(GetCurrentFrame());
}

void VDProject::SetSelectionEnd(VDPosition pos) {
	if (inputAVI) {
		if (pos < 0)
			pos = 0;
		if (pos > GetFrameCount())
			pos = GetFrameCount();

		mposSelectionEnd = pos;
		if (mposSelectionStart > mposSelectionEnd)
			mposSelectionStart = mposSelectionEnd;
		g_dubOpts.video.lEndOffsetMS = (long)inputVideoAVI->samplesToMs(GetFrameCount() - pos);

		UISelectionUpdated();
	}
}

void VDProject::MoveToFrame(VDPosition frame) {
	if (inputVideoAVI) {
		frame = std::max<VDPosition>(0, std::min<VDPosition>(frame, mTimeline.GetLength()));

		mposCurrentFrame = frame;
		UICurrentPositionUpdated();
		DisplayFrame();
	}
}

void VDProject::MoveToStart() {
	if (inputVideoAVI)
		MoveToFrame(0);
}

void VDProject::MoveToPrevious() {
	if (inputVideoAVI)
		MoveToFrame(GetCurrentFrame() - 1);
}

void VDProject::MoveToNext() {
	if (inputVideoAVI)
		MoveToFrame(GetCurrentFrame() + 1);
}

void VDProject::MoveToEnd() {
	if (inputVideoAVI)
		MoveToFrame(mTimeline.GetEnd());
}

void VDProject::MoveToSelectionStart() {
	if (inputVideoAVI && IsSelectionPresent()) {
		VDPosition pos = GetSelectionStartFrame();

		if (pos >= 0)
			MoveToFrame(pos);
	}
}

void VDProject::MoveToSelectionEnd() {
	if (inputVideoAVI && IsSelectionPresent()) {
		VDPosition pos = GetSelectionEndFrame();

		if (pos >= 0)
			MoveToFrame(pos);
	}
}

void VDProject::MoveToNearestKey(VDPosition pos) {
	if (!inputVideoAVI)
		return;


	MoveToFrame(mTimeline.GetNearestKey(pos));
}

void VDProject::MoveToPreviousKey() {
	if (!inputVideoAVI)
		return;

	VDPosition pos = mTimeline.GetPrevKey(GetCurrentFrame());

	if (pos < 0)
		pos = 0;

	MoveToFrame(pos);
}

void VDProject::MoveToNextKey() {
	if (!inputVideoAVI)
		return;

	VDPosition pos = mTimeline.GetNextKey(GetCurrentFrame());

	if (pos < 0)
		pos = mTimeline.GetEnd();

	MoveToFrame(pos);
}

void VDProject::MoveBackSome() {
	if (inputVideoAVI)
		MoveToFrame(GetCurrentFrame() - 50);
}

void VDProject::MoveForwardSome() {
	if (inputVideoAVI)
		MoveToFrame(GetCurrentFrame() + 50);
}

void VDProject::StartSceneShuttleReverse() {
	if (!inputVideoAVI)
		return;
	mSceneShuttleMode = -1;
	UIShuttleModeUpdated();
}

void VDProject::StartSceneShuttleForward() {
	if (!inputVideoAVI)
		return;
	mSceneShuttleMode = +1;
	UIShuttleModeUpdated();
}

void VDProject::MoveToPreviousRange() {
	if (inputAVI) {
		VDPosition pos = mTimeline.GetPrevEdit(GetCurrentFrame());

		if (pos >= 0)
			MoveToFrame(pos);
	}
	guiSetStatus("No previous edit.", 255);
}

void VDProject::MoveToNextRange() {
	if (inputAVI) {
		VDPosition pos = mTimeline.GetNextEdit(GetCurrentFrame());

		if (pos >= 0)
			MoveToFrame(pos);
	}
	guiSetStatus("No next edit.", 255);
}

void VDProject::MoveToPreviousDrop() {
	if (inputAVI) {
		VDPosition pos = mTimeline.GetPrevDrop(GetCurrentFrame());

		if (pos >= 0)
			MoveToFrame(pos);
		else
			guiSetStatus("No previous dropped frame found.", 255);
	}
}

void VDProject::MoveToNextDrop() {
	if (inputAVI) {
		VDPosition pos = mTimeline.GetNextDrop(GetCurrentFrame());

		if (pos >= 0)
			MoveToFrame(pos);
		else
			guiSetStatus("No next dropped frame found.", 255);
	}
}

void VDProject::ResetTimeline() {
	if (inputAVI) {
		mTimeline.SetFromSource();
		UITimelineUpdated();
	}
}

void VDProject::ResetTimelineWithConfirmation() {
	if (inputAVI) {
		if (IDOK == MessageBox((HWND)mhwnd, "Discard edits and reset timeline?", g_szWarning, MB_OKCANCEL|MB_TASKMODAL|MB_SETFOREGROUND)) {
			ResetTimeline();
		}
	}
}

void VDProject::ScanForErrors() {
	if (inputVideoAVI) {
		ScanForUnreadableFrames(&mTimeline.GetSubset(), inputVideoAVI);
	}
}

void VDProject::RunOperation(IVDDubberOutputSystem *pOutputSystem, BOOL fAudioOnly, DubOptions *pOptions, int iPriority, bool fPropagateErrors, long lSpillThreshold, long lSpillFrameThreshold) {

	if (!inputAVI)
		throw MyError("No source has been loaded to process.");

	bool fError = false;
	MyError prop_err;
	DubOptions *opts;

	{
		const wchar_t *pOpType = pOutputSystem->IsRealTime() ? L"preview" : L"dub";
		VDLog(kVDLogMarker, VDswprintf(L"Beginning %ls operation.", 1, &pOpType));
	}

	try {
		VDAutoLogDisplay disp;

		filters.DeinitFilters();
		filters.DeallocateBuffers();

		CPUTest();

		// Create a dubber.

		if (!pOptions) {
			g_dubOpts.video.fShowDecompressedFrame = g_drawDecompressedFrame;
			g_dubOpts.fShowStatus = !!g_showStatusWindow;
		}

		opts = pOptions ? pOptions : &g_dubOpts;
		opts->perf.fDropFrames = g_fDropFrames;

		if (!(g_dubber = CreateDubber(opts)))
			throw MyMemoryError();

		// Create dub status window

		mpDubStatus = CreateDubStatusHandler();

		if (opts->fMoveSlider)
			mpDubStatus->SetPositionCallback(g_fJobMode ? JobPositionCallback : StaticPositionCallback, this);

		// Initialize the dubber.

		if (opts->audio.bUseAudioFilterGraph)
			g_dubber->SetAudioFilterGraph(g_audioFilterGraph);

		g_dubber->SetStatusHandler(mpDubStatus);
		g_dubber->SetInputFile(inputAVI);

		if (!pOutputSystem->IsRealTime() && g_ACompressionFormat)
			g_dubber->SetAudioCompression(g_ACompressionFormat, g_ACompressionFormatSize);

		// As soon as we call Init(), this value is no longer ours to free.

		UISetDubbingMode(true, pOutputSystem->IsRealTime());

		if (lSpillThreshold) {
			g_dubber->EnableSpill((__int64)(lSpillThreshold-1) << 20, lSpillFrameThreshold);
			g_dubber->Init(inputVideoAVI, inputAudio, pOutputSystem, &g_Vcompression, &mTimeline.GetSubset());
		} else if (fAudioOnly == 2) {
			g_dubber->SetPhantomVideoMode();
			g_dubber->Init(inputVideoAVI, inputAudio, pOutputSystem, &g_Vcompression, &mTimeline.GetSubset());
		} else {
			g_dubber->Init(inputVideoAVI, inputAudio, pOutputSystem, &g_Vcompression, &mTimeline.GetSubset());
		}

		_RPT0(0,"Starting dub.\n");

		if (!pOptions) RedrawWindow((HWND)mhwnd, NULL, NULL, RDW_ERASE | RDW_INVALIDATE);

		g_dubber->Go(iPriority);

		UIRunDubMessageLoop();

		g_dubber->Stop();

		if (g_dubber->isAbortedByUser()) {
			g_fJobAborted = true;
		} else if (!fPropagateErrors)
			disp.Post(mhwnd);

	} catch(char *s) {
		if (fPropagateErrors) {
			prop_err.setf(s);
			fError = true;
		} else
			MyError(s).post((HWND)mhwnd, g_szError);
	} catch(MyError& err) {
		if (fPropagateErrors) {
			prop_err.TransferFrom(err);
			fError = true;
		} else
			err.post((HWND)mhwnd,g_szError);
	}

	g_dubber->SetStatusHandler(NULL);
	delete mpDubStatus;
	mpDubStatus = NULL;

	_CrtCheckMemory();

	_RPT0(0,"Ending dub.\n");

	delete g_dubber;
	g_dubber = NULL;

	if (!inputVideoAVI->setDecompressedFormat(24))
		if (!inputVideoAVI->setDecompressedFormat(32))
			if (!inputVideoAVI->setDecompressedFormat(16))
				inputVideoAVI->setDecompressedFormat(8);

	UISetDubbingMode(false, false);

	VDLog(kVDLogMarker, VDStringW(L"Ending operation."));

	if (g_bExit)
		PostQuitMessage(0);
	else if (fError && fPropagateErrors)
		throw prop_err;
}

void VDProject::AbortOperation() {
	if (g_dubber)
		g_dubber->Abort();
}

///////////////////////////////////////////////////////////////////////////

void VDProject::SceneShuttleStop() {
	if (mSceneShuttleMode) {
		mSceneShuttleMode = 0;
		mSceneShuttleAdvance = 0;
		mSceneShuttleCounter = 0;

		UIShuttleModeUpdated();

		if (inputVideoAVI)
			MoveToFrame(GetCurrentFrame());
	}
}

void VDProject::SceneShuttleStep() {
	if (!inputVideoAVI)
		SceneShuttleStop();

	VDPosition sample = GetCurrentFrame() + mSceneShuttleMode;
	VDPosition ls2 = mTimeline.TimelineToSourceFrame(sample);

	if (!inputVideoAVI || ls2 < inputVideoAVI->getStart() || ls2 >= inputVideoAVI->getEnd()) {
		SceneShuttleStop();
		return;
	}

	if (mSceneShuttleAdvance < 1280)
		++mSceneShuttleAdvance;

	mSceneShuttleCounter += 32;

	mposCurrentFrame = sample;

	if (mSceneShuttleCounter >= mSceneShuttleAdvance) {
		mSceneShuttleCounter = 0;
		DisplayFrame(true);
	} else
		DisplayFrame(false);

	while(UpdateFrame())
		;

	UICurrentPositionUpdated();

	VBitmap framebm((void *)inputVideoAVI->getFrameBuffer(), inputVideoAVI->getDecompressedFormat());
	if (mpSceneDetector->Submit(&framebm)) {
		SceneShuttleStop();
	}
}

void VDProject::StaticPositionCallback(VDPosition start, VDPosition cur, VDPosition end, int progress, void *cookie) {
	VDProject *pthis = (VDProject *)cookie;
	VDPosition frame = std::max<VDPosition>(0, std::min<VDPosition>(cur, pthis->GetFrameCount()));

	pthis->mposCurrentFrame = frame;
	pthis->UICurrentPositionUpdated();
}

void VDProject::UpdateDubParameters() {
	if (!inputVideoAVI)
		return;

	mVideoInputFrameRate	= VDFraction(0,0);
	mVideoOutputFrameRate	= VDFraction(0,0);

	DubVideoStreamInfo vInfo;
	DubAudioStreamInfo aInfo;

	if (inputVideoAVI) {
		try {
			InitStreamValuesStatic(vInfo, aInfo, inputVideoAVI, inputAudio, &g_dubOpts, &g_project->GetTimeline().GetSubset());
			mVideoInputFrameRate	= vInfo.frameRateIn;
			mVideoOutputFrameRate	= vInfo.frameRate;
		} catch(const MyError&) {
			// The input stream may throw an error here trying to obtain the nearest key.
			// If so, bail.
		}
	}

	UIDubParametersUpdated();
}
