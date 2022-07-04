//	VirtualDub - Video processing and capture application
//	Copyright (C) 1998-2003 Avery Lee
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
#include "InputFile.h"
#include <vd2/system/error.h>
#include <vd2/system/VDString.h>
#include <vd2/system/file.h>

/////////////////////////////////////////////////////////////////////

InputFileOptions::~InputFileOptions() {
}

/////////////////////////////////////////////////////////////////////

InputFilenameNode::InputFilenameNode(const wchar_t *_n) : name(wcsdup(_n)) {
	if (!name)
		throw MyMemoryError();
}

InputFilenameNode::~InputFilenameNode() {
	free((char *)name);
}

/////////////////////////////////////////////////////////////////////

InputFile::~InputFile() {
	InputFilenameNode *ifn;

	while(ifn = listFiles.RemoveTail())
		delete ifn;
}

void InputFile::AddFilename(const wchar_t *lpszFile) {
	InputFilenameNode *ifn = new InputFilenameNode(lpszFile);

	if (ifn)
		listFiles.AddTail(ifn);
}

bool InputFile::Append(const wchar_t *szFile) {
	return false;
}

void InputFile::setOptions(InputFileOptions *) {
}

InputFileOptions *InputFile::promptForOptions(HWND) {
	return NULL;
}

InputFileOptions *InputFile::createOptions(const char *buf) {
	return NULL;
}

void InputFile::InfoDialog(HWND hwndParent) {
}

void InputFile::setAutomated(bool) {
}

void InputFile::GetTextInfo(tFileTextInfo& info) {
	info.clear();
}

bool InputFile::isOptimizedForRealtime() {
	return false;
}

bool InputFile::isStreaming() {
	return false;
}

///////////////////////////////////////////////////////////////////////////

tVDInputDrivers g_VDInputDrivers;

extern IVDInputDriver *VDCreateInputDriverAVI1();
extern IVDInputDriver *VDCreateInputDriverAVI2();
extern IVDInputDriver *VDCreateInputDriverMPEG();
extern IVDInputDriver *VDCreateInputDriverImages();
extern IVDInputDriver *VDCreateInputDriverASF();
extern IVDInputDriver *VDCreateInputDriverANIM();

namespace {
	struct SortByRevPriority {
		bool operator()(IVDInputDriver *p1, IVDInputDriver *p2) const {
			return p1->GetDefaultPriority() > p2->GetDefaultPriority();
		}
	};
}

void VDInitInputDrivers() {

	g_VDInputDrivers.reserve(5);

	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverAVI1()));
	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverAVI2()));
	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverMPEG()));
	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverImages()));
	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverASF()));
	g_VDInputDrivers.push_back(vdrefptr<IVDInputDriver>(VDCreateInputDriverANIM()));

	std::sort(g_VDInputDrivers.begin(), g_VDInputDrivers.end(), SortByRevPriority());
}

void VDGetInputDrivers(tVDInputDrivers& l, uint32 flags) {
	for(tVDInputDrivers::const_iterator it(g_VDInputDrivers.begin()), itEnd(g_VDInputDrivers.end()); it!=itEnd; ++it)
		if ((*it)->GetFlags() & flags)
			l.push_back(*it);
}

IVDInputDriver *VDGetInputDriverByName(const wchar_t *name) {
	for(tVDInputDrivers::const_iterator it(g_VDInputDrivers.begin()), itEnd(g_VDInputDrivers.end()); it!=itEnd; ++it) {
		IVDInputDriver *pDriver = *it;

		const wchar_t *dvname = pDriver->GetSignatureName();

		if (dvname && !wcsicmp(name, dvname))
			return pDriver;
	}

	return NULL;
}

IVDInputDriver *VDGetInputDriverForLegacyIndex(int idx) {
	enum {
		FILETYPE_AUTODETECT		= 0,
		FILETYPE_AVI			= 1,
		FILETYPE_MPEG			= 2,
		FILETYPE_ASF			= 3,
		FILETYPE_STRIPEDAVI		= 4,
		FILETYPE_AVICOMPAT		= 5,
		FILETYPE_IMAGE			= 6,
		FILETYPE_AUTODETECT2	= 7,
	};

	switch(idx) {
	case FILETYPE_AVICOMPAT:	return g_VDInputDrivers[0];
	case FILETYPE_AVI:			return g_VDInputDrivers[1];
	case FILETYPE_MPEG:			return g_VDInputDrivers[2];
	case FILETYPE_IMAGE:		return g_VDInputDrivers[3];
	case FILETYPE_ASF:			return g_VDInputDrivers[4];
	}

	return NULL;
}

VDStringW VDMakeInputDriverFileFilter(const tVDInputDrivers& l, std::vector<int>& xlat) {
	VDStringW filter;
	VDStringW allspecs;

	xlat.push_back(-1);

	int nDriver = 0;
	for(tVDInputDrivers::const_iterator it(l.begin()), itEnd(l.end()); it!=itEnd; ++it, ++nDriver) {
		const wchar_t *filt = (*it)->GetFilenamePattern();

		if (filt) {
			while(*filt) {
				const wchar_t *pats = filt;
				while(*pats++);
				const wchar_t *end = pats;
				while(*end++);

				if (!allspecs.empty())
					allspecs += L';';

				filter.append(filt, end - filt);
				allspecs += pats;

				filt = end;

				xlat.push_back(nDriver);
			}
		}
	}

	xlat.push_back(-1);
	VDStringW finalfilter(L"All types (");

	for(VDStringW::const_iterator it2(allspecs.begin()), it2end(allspecs.end()); it2!=it2end; ++it2)
		if (*it2 == L';')
			finalfilter += L',';
		else
			finalfilter += *it2;

	finalfilter += L')';
	finalfilter += L'\0';
	finalfilter += allspecs;
	finalfilter += L'\0';
	finalfilter += filter;

	static const wchar_t alltypes[]=L"All types (*.*)";
	finalfilter += alltypes;
	finalfilter += L'\0';
	finalfilter += L"*.*";
	finalfilter += L'\0';

	return finalfilter;
}

IVDInputDriver *VDAutoselectInputDriverForFile(const wchar_t *fn) {
	char buf[64];
	char endbuf[64];
	DWORD dwActual;

	memset(buf, 0, sizeof buf);
	memset(endbuf, 0, sizeof endbuf);

	VDFile file(fn);

	dwActual = file.readData(buf, 64);

	if (dwActual <= 64)
		memcpy(endbuf, buf, dwActual);
	else {
		file.seek(-64, nsVDFile::kSeekEnd);
		file.read(endbuf, 64);
	}

	// The Avisynth script:
	//
	//	Version
	//
	// is only 9 bytes...

	if (!dwActual)
		throw MyError("Can't open \"%ls\": The file is empty.", fn);

	file.closeNT();

	// attempt detection

	tVDInputDrivers inputDrivers;
	VDGetInputDrivers(inputDrivers, IVDInputDriver::kF_Video);

	tVDInputDrivers::const_iterator it(inputDrivers.begin()), itEnd(inputDrivers.end());

	int fitquality = -1000;
	IVDInputDriver *pSelectedDriver = NULL;

	for(; it!=itEnd; ++it) {
		IVDInputDriver *pDriver = *it;

		int result = pDriver->DetectBySignature(buf, dwActual, endbuf, dwActual, 0);

		if (result > 0 && fitquality < 1) {
			pSelectedDriver = pDriver;
			fitquality = 1;
		} else if (!result && fitquality < 0) {
			pSelectedDriver = pDriver;
			fitquality = 0;
		} else if (fitquality < -1 && pDriver->DetectByFilename(fn)) {
			pSelectedDriver = pDriver;
			fitquality = -1;
		}
	}

	if (!pSelectedDriver)
		throw MyError("Cannot detect file type of \"%ls\".", fn);

	return pSelectedDriver;
}
