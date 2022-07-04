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
#include <map>
#include <vector>
#include <string.h>

#define _WIN32_WINNT 0x0500

#include <windows.h>
#include <commdlg.h>
#include <objbase.h>
#include <shlobj.h>

#include <vd2/system/text.h>
#include <vd2/system/vdalloc.h>
#include <vd2/system/VDString.h>
#include <vd2/Dita/services.h>

#ifndef OPENFILENAME_SIZE_VERSION_400
#define OPENFILENAME_SIZE_VERSION_400 0x4c
#endif

#ifndef BIF_NEWDIALOGSTYLE
#define BIF_NEWDIALOGSTYLE     0x0040
#endif

///////////////////////////////////////////////////////////////////////////

#if 0
IVDUIContext *VDGetUIContext() {
	static vdautoptr<IVDUIContext> spctx(VDCreateUIContext());

	return spctx;
}
#endif

///////////////////////////////////////////////////////////////////////////

struct FilespecEntry {
	wchar_t szFile[MAX_PATH];
};

typedef std::map<long, FilespecEntry> tFilespecMap;

// Visual C++ 7.0 has a bug with lock initialization in the STL -- the lock
// code uses a normal constructor, and thus usually executes too late for
// static construction.
tFilespecMap *g_pFilespecMap;

///////////////////////////////////////////////////////////////////////////

namespace {
	int FileFilterLength(const wchar_t *pszFilter) {
		const wchar_t *s = pszFilter;

		while(*s) {
			while(*s++);
			while(*s++);
		}

		return s - pszFilter;
	}

#pragma pack(push, 1)
	struct DialogTemplateHeader {		// DLGTEMPLATEEX psuedo-struct from MSDN
		WORD		signature;			// DOCBUG: This comes first!
		WORD		dlgVer;
		DWORD		helpID;
		DWORD		exStyle;
		DWORD		style;
		WORD		cDlgItems;
		short		x;
		short		y;
		short		cx;
		short		cy;
		WORD		menu;
		WORD		windowClass;
		WCHAR		title[1];
		WORD		pointsize;
		WORD		weight;
		BYTE		italic;
		BYTE		charset;
		WCHAR		typeface[13];
	};

	struct DialogTemplateItem {
		DWORD	helpID; 
		DWORD	exStyle; 
		DWORD	style; 
		short	x; 
		short	y; 
		short	cx; 
		short	cy; 
		DWORD	id;					//DOCERR
	};
#pragma pack(pop)

	struct DialogTemplateBuilder {
		std::vector<uint8> data;
		HANDLE mhTemplate;

		DialogTemplateBuilder();
		~DialogTemplateBuilder();

		void push(const void *p, int size) {
			int pos = data.size();
			data.resize(pos + size);
			memcpy(&data[pos], p, size);
		}

		void SetRect(int x, int y, int cx, int cy);
		void AddControlBase(DWORD exStyle, DWORD style, int x, int y, int cx, int cy, int id);
		void AddLabel(int id, int x, int y, int cx, int cy, const wchar_t *text);
		void AddCheckbox(int id, int x, int y, int cx, int cy, const wchar_t *text);
		void AddNumericEdit(int id, int x, int y, int cx, int cy);

		HANDLE MakeObject();
	};

	DialogTemplateBuilder::DialogTemplateBuilder()
		: mhTemplate(0)
	{
		static const DialogTemplateHeader hdr = {
			1,
			0xFFFF,
			0,
			0,
			WS_TABSTOP | WS_VISIBLE | WS_CHILD | WS_CLIPSIBLINGS | DS_3DLOOK | DS_CONTROL | DS_SHELLFONT,
			0,
			0, 0, 0, 0,
			0,
			0,
			0,
			8,
			FW_NORMAL,
			FALSE,
			ANSI_CHARSET,
			L"MS Shell Dlg"
		};

		push(&hdr, sizeof hdr);
	}

	DialogTemplateBuilder::~DialogTemplateBuilder() {
		GlobalFree(mhTemplate);
	}

	void DialogTemplateBuilder::SetRect(int x, int y, int cx, int cy) {
		DialogTemplateHeader& hdr = (DialogTemplateHeader&)data.front();

		hdr.x = x;
		hdr.y = y;
		hdr.cx = cx;
		hdr.cy = cy;
	}

	void DialogTemplateBuilder::AddControlBase(DWORD exStyle, DWORD style, int x, int y, int cx, int cy, int id) {
		data.resize((data.size()+3)&~3, 0);

		const DialogTemplateItem item = {
			0,
			exStyle,
			style,
			x,
			y,
			cx,
			cy,
			id
		};

		push(&item, sizeof item);

		DialogTemplateHeader& hdr = (DialogTemplateHeader&)data.front();
		++hdr.cDlgItems;

		hdr.cx = std::max<int>(hdr.cx, x+cx);
		hdr.cy = std::max<int>(hdr.cy, y+cy);
	}

	void DialogTemplateBuilder::AddLabel(int id, int x, int y, int cx, int cy, const wchar_t *text) {
		AddControlBase(0, WS_CHILD | WS_VISIBLE | SS_LEFT | SS_CENTERIMAGE, x, y, cx, cy, id);

		const WORD wclass[2]={0xffff,0x0082};
		push(wclass, sizeof wclass);

		push(text, (wcslen(text)+1)*sizeof(WORD));

		const WORD extradata = 0;
		push(&extradata, sizeof(WORD));
	}

	void DialogTemplateBuilder::AddCheckbox(int id, int x, int y, int cx, int cy, const wchar_t *text) {
		AddControlBase(0, WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX | WS_TABSTOP, x, y, cx, cy, id);

		const WORD wclass[2]={0xffff,0x0080};
		push(wclass, sizeof wclass);

		push(text, (wcslen(text)+1)*sizeof(WORD));

		const WORD extradata = 0;
		push(&extradata, sizeof(WORD));
	}

	void DialogTemplateBuilder::AddNumericEdit(int id, int x, int y, int cx, int cy) {
		AddControlBase(WS_EX_CLIENTEDGE, WS_CHILD | WS_VISIBLE | ES_NUMBER | WS_TABSTOP, x, y, cx, cy, id);

		const WORD wclassandtitle[4]={0xffff,0x0081,0x0030,0x0000};
		push(wclassandtitle, sizeof wclassandtitle);

		const WORD extradata = 0;
		push(&extradata, sizeof(WORD));
	}

	HANDLE DialogTemplateBuilder::MakeObject() {
		if (!mhTemplate) {
			mhTemplate = GlobalAlloc(GMEM_MOVEABLE, data.size());
			if (mhTemplate) {
				if (void *p = GlobalLock(mhTemplate)) {
					memcpy(p, &data.front(), data.size());
					GlobalUnlock(mhTemplate);
					return mhTemplate;
				}
				GlobalFree(mhTemplate);
				mhTemplate = 0;
			}
		}

		return mhTemplate;
	}
}

#if 0
struct tester {
	static BOOL CALLBACK dlgproc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
		return FALSE;
	}
	tester() {
		DialogTemplateBuilder builder;

		builder.AddLabel(1, 7, 7, 50, 14, L"hellow");
		builder.AddLabel(1, 7, 21, 50, 14, L"byebye");

		DialogBoxIndirect(GetModuleHandle(0), (LPCDLGTEMPLATE)&builder.data.front(), NULL, dlgproc);
	}
} g;
#endif

///////////////////////////////////////////////////////////////////////////

void VDInitFilespecSystem() {
	if (!g_pFilespecMap) {
		// This ensures the filespec map will be destroyed before any global destructors.
		static vdautoptr<tFilespecMap> spFilespecMap(new tFilespecMap);
		g_pFilespecMap = spFilespecMap;
	}
}

struct VDGetFileNameHook {
	static UINT_PTR CALLBACK HookFn(HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam) {
		VDGetFileNameHook *pThis = (VDGetFileNameHook *)GetWindowLongPtr(hdlg, DWLP_USER);

		switch(uiMsg) {
		case WM_INITDIALOG:
			pThis = (VDGetFileNameHook *)(((const OPENFILENAMEA *)lParam)->lCustData);
			SetWindowLongPtr(hdlg, DWLP_USER, (LONG_PTR)pThis);
			pThis->Init(hdlg);
			return 0;

		case WM_NOTIFY:
			switch(((const NMHDR *)lParam)->code) {
			case CDN_FILEOK:
				return !pThis->Writeback(hdlg);
			}
		}

		return 0;
	}

	void Init(HWND hdlg) {
		for(int nOpts = 0; mpOpts[nOpts].mType; ++nOpts) {
			const VDFileDialogOption& opt = mpOpts[nOpts];
			const int id = 1000 + 16*nOpts;

			switch(opt.mType) {
			case VDFileDialogOption::kBool:
				CheckDlgButton(hdlg, id, !!mpOptVals[opt.mDstIdx]);
				break;
			case VDFileDialogOption::kInt:
				SetDlgItemInt(hdlg, id, mpOptVals[opt.mDstIdx], TRUE);
				break;
			case VDFileDialogOption::kEnabledInt:
				CheckDlgButton(hdlg, id, !!mpOptVals[opt.mDstIdx]);
				SetDlgItemInt(hdlg, id+1, mpOptVals[opt.mDstIdx+1], TRUE);
				break;
			}
		}
	}

	bool Writeback(HWND hdlg) {
		for(int nOpts = 0; mpOpts[nOpts].mType; ++nOpts) {
			const VDFileDialogOption& opt = mpOpts[nOpts];
			const int id = 1000 + 16*nOpts;
			BOOL bOk;
			INT v;

			switch(opt.mType) {
			case VDFileDialogOption::kBool:
				mpOptVals[opt.mDstIdx] = !!IsDlgButtonChecked(hdlg, id);
				break;
			case VDFileDialogOption::kInt:
				v = GetDlgItemInt(hdlg, id, &bOk, TRUE);
				if (!bOk) {
					MessageBeep(MB_ICONEXCLAMATION);
					SetFocus(GetDlgItem(hdlg, id));
					return false;
				}
				mpOptVals[opt.mDstIdx] = v;
				break;
			case VDFileDialogOption::kEnabledInt:
				mpOptVals[opt.mDstIdx] = !!IsDlgButtonChecked(hdlg, id);
				if (mpOptVals[opt.mDstIdx]) {
					v = GetDlgItemInt(hdlg, id+1, &bOk, TRUE);
					if (!bOk) {
						MessageBeep(MB_ICONEXCLAMATION);
						SetFocus(GetDlgItem(hdlg, id+1));
						return false;
					}
					mpOptVals[opt.mDstIdx+1] = v;
				}
				break;
			}
		}
		return true;
	}

	const VDFileDialogOption *mpOpts;
	int *mpOptVals;
};

static const VDStringW VDGetFileName(bool bSaveAs, long nKey, VDGUIHandle ctxParent, const wchar_t *pszTitle, const wchar_t *pszFilters, const wchar_t *pszExt, const VDFileDialogOption *pOptions, int *pOptVals) {
	VDInitFilespecSystem();

	tFilespecMap::iterator it = g_pFilespecMap->find(nKey);

	if (it == g_pFilespecMap->end()) {
		std::pair<tFilespecMap::iterator, bool> r = g_pFilespecMap->insert(tFilespecMap::value_type(nKey, FilespecEntry()));

		if (!r.second) {
			VDStringW empty;
			return empty;
		}

		it = r.first;

		(*it).second.szFile[0] = 0;
	}

	FilespecEntry& fsent = (*it).second;

	VDASSERTCT(sizeof(OPENFILENAMEA) == sizeof(OPENFILENAMEW));
	union {
		OPENFILENAMEA a;
		OPENFILENAMEW w;
	} ofn={0};

	// Slight annoyance: If we want to use custom templates and still keep the places
	// bar, the lStructSize parameter must be greater than OPENFILENAME_SIZE_VERSION_400.
	// But if sizeof(OPENFILENAME) is used under Windows 95/98, the open call fails.
	// Argh.

	bool bIsAtLeastWin2K = (sint32)(GetVersion() & 0x800000FF) >= 5;	// OS must be NT, major version >= 5

	ofn.w.lStructSize		= bIsAtLeastWin2K ? sizeof(OPENFILENAME) : OPENFILENAME_SIZE_VERSION_400;
	ofn.w.hwndOwner			= (HWND)ctxParent;
	ofn.w.lpstrCustomFilter	= NULL;
	ofn.w.nFilterIndex		= 0;
	ofn.w.lpstrFileTitle	= NULL;
	ofn.w.lpstrInitialDir	= NULL;
	ofn.w.Flags				= OFN_PATHMUSTEXIST|OFN_FILEMUSTEXIST|OFN_ENABLESIZING|OFN_EXPLORER|OFN_OVERWRITEPROMPT|OFN_HIDEREADONLY;

	DialogTemplateBuilder builder;
	VDGetFileNameHook hook = { pOptions, pOptVals };
	int nReadOnlyIndex = -1;
	int nSelectedFilterIndex = -1;

	if (pOptions) {
		int y = 0;

		for(int nOpts = 0; pOptions[nOpts].mType; ++nOpts) {
			const VDFileDialogOption& opt = pOptions[nOpts];
			const wchar_t *s = opt.mpLabel;
			const int id = 1000 + 16*nOpts;
			const int sw = s ? 4*wcslen(s) : 0;

			switch(pOptions[nOpts].mType) {
			case VDFileDialogOption::kBool:
				builder.AddCheckbox(id, 5, y, 10+sw, 12, s);
				y += 12;
				break;
			case VDFileDialogOption::kInt:
				builder.AddLabel(0, 5, y, sw, 12, s);
				builder.AddNumericEdit(id, 9+sw, y, 50, 12);
				y += 12;
				break;
			case VDFileDialogOption::kEnabledInt:
				builder.AddCheckbox(id, 5, y+1, 10+sw, 12, s);
				builder.AddNumericEdit(id+1, 19+sw, y+1, 50, 12);
				y += 14;
				break;
			case VDFileDialogOption::kReadOnly:
				VDASSERT(nReadOnlyIndex < 0);
				nReadOnlyIndex = opt.mDstIdx;
				ofn.w.Flags &= ~OFN_HIDEREADONLY;
				if (pOptVals[nReadOnlyIndex])
					ofn.w.Flags |= OFN_READONLY;
				break;
			case VDFileDialogOption::kSelectedFilter:
				VDASSERT(nSelectedFilterIndex < 0);
				nSelectedFilterIndex = opt.mDstIdx;
				ofn.w.nFilterIndex = pOptVals[opt.mDstIdx];
				break;
			}
		}

		if (y > 0) {
			ofn.w.Flags		|= OFN_ENABLETEMPLATEHANDLE | OFN_ENABLEHOOK;
			ofn.w.hInstance = (HINSTANCE)&builder.data.front();
			ofn.w.lpfnHook	= VDGetFileNameHook::HookFn;
			ofn.w.lCustData	= (LPARAM)&hook;
		}
	}

	VDStringW strFilename;
	bool bSuccess = false;

	if ((sint32)GetVersion() < 0) {		// Windows 95/98
		VDStringA strFilters(VDTextWToA(pszFilters, FileFilterLength(pszFilters)));
		VDStringA strDefExt(VDTextWToA(pszExt, -1));
		VDStringA strTitle(VDTextWToA(pszTitle, -1));

		char szFile[MAX_PATH];

		VDTextWToA(szFile, sizeof szFile, fsent.szFile, -1);

		ofn.a.lpstrFilter		= strFilters.c_str();
		ofn.a.lpstrFile			= szFile;
		ofn.a.nMaxFile			= sizeof(szFile) / sizeof(szFile[0]);
		ofn.a.lpstrTitle		= strTitle.c_str();
		ofn.a.lpstrDefExt		= strDefExt.c_str();

		if ((bSaveAs ? GetSaveFileNameA : GetOpenFileNameA)(&ofn.a)) {
			VDTextAToW(fsent.szFile, sizeof fsent.szFile, szFile, -1);
			bSuccess = true;
		}
	} else {
		ofn.w.lpstrFilter		= pszFilters;
		ofn.w.lpstrFile			= fsent.szFile;
		ofn.w.nMaxFile			= sizeof(fsent.szFile) / sizeof(fsent.szFile[0]);
		ofn.w.lpstrTitle		= pszTitle;
		ofn.w.lpstrDefExt		= pszExt;

		if ((bSaveAs ? GetSaveFileNameW : GetOpenFileNameW)(&ofn.w)) {
			bSuccess = true;
		}
	}

	if (bSuccess) {
		if (nReadOnlyIndex >= 0)
			pOptVals[nReadOnlyIndex] = !!(ofn.w.Flags & OFN_READONLY);

		if (nSelectedFilterIndex >= 0)
			pOptVals[nSelectedFilterIndex] = ofn.w.nFilterIndex;

		strFilename = fsent.szFile;
	}
	return strFilename;
}

const VDStringW VDGetLoadFileName(long nKey, VDGUIHandle ctxParent, const wchar_t *pszTitle, const wchar_t *pszFilters, const wchar_t *pszExt, const VDFileDialogOption *pOptions, int *pOptVals) {
	return VDGetFileName(false, nKey, ctxParent, pszTitle, pszFilters, pszExt, pOptions, pOptVals);
}

const VDStringW VDGetSaveFileName(long nKey, VDGUIHandle ctxParent, const wchar_t *pszTitle, const wchar_t *pszFilters, const wchar_t *pszExt, const VDFileDialogOption *pOptions, int *pOptVals) {
	return VDGetFileName(true, nKey, ctxParent, pszTitle, pszFilters, pszExt, pOptions, pOptVals);
}

///////////////////////////////////////////////////////////////////////////

struct DirspecEntry {
	wchar_t szFile[MAX_PATH];
};

typedef std::map<long, DirspecEntry> tDirspecMap;
tDirspecMap *g_pDirspecMap;

///////////////////////////////////////////////////////////////////////////

const VDStringW VDGetDirectory(long nKey, VDGUIHandle ctxParent, const wchar_t *pszTitle) {
	if (!g_pDirspecMap)
		g_pDirspecMap = new tDirspecMap;

	tDirspecMap::iterator it = g_pDirspecMap->find(nKey);

	if (it == g_pDirspecMap->end()) {
		std::pair<tDirspecMap::iterator, bool> r = g_pDirspecMap->insert(tDirspecMap::value_type(nKey, DirspecEntry()));

		if (!r.second) {
			VDStringW empty;
			return empty;
		}

		it = r.first;

		(*it).second.szFile[0] = 0;
	}

	DirspecEntry& fsent = (*it).second;
	bool bSuccess = false;

	if (SUCCEEDED(CoInitialize(NULL))) {
		IMalloc *pMalloc;

		if (SUCCEEDED(SHGetMalloc(&pMalloc))) {

			if ((LONG)GetVersion() < 0) {		// Windows 9x
				char *pszBuffer;

				if (pszBuffer = (char *)pMalloc->Alloc(MAX_PATH)) {
					BROWSEINFOA bi;
					ITEMIDLIST *pidlBrowse;

					bi.hwndOwner		= (HWND)ctxParent;
					bi.pidlRoot			= NULL;
					bi.pszDisplayName	= pszBuffer;
					bi.lpszTitle		= VDFastTextWToA(pszTitle);
					bi.ulFlags			= BIF_EDITBOX | /*BIF_NEWDIALOGSTYLE |*/ BIF_RETURNONLYFSDIRS | BIF_VALIDATE;
					bi.lpfn				= NULL;

					if (pidlBrowse = SHBrowseForFolderA(&bi)) {
						if (SHGetPathFromIDListA(pidlBrowse, pszBuffer)) {
							VDTextAToW(fsent.szFile, MAX_PATH, pszBuffer);
							bSuccess = true;
						}

						pMalloc->Free(pidlBrowse);
					}
					pMalloc->Free(pszBuffer);
				}
			} else {
				HMODULE hmod = GetModuleHandle("shell32.dll");		// We know shell32 is loaded because we hard link to SHBrowseForFolderA.
				typedef LPITEMIDLIST (APIENTRY *tpSHBrowseForFolderW)(LPBROWSEINFOW);
				typedef BOOL (APIENTRY *tpSHGetPathFromIDListW)(LPCITEMIDLIST pidl, LPWSTR pszPath);
				tpSHBrowseForFolderW pSHBrowseForFolderW = (tpSHBrowseForFolderW)GetProcAddress(hmod, "SHBrowseForFolderW");
				tpSHGetPathFromIDListW pSHGetPathFromIDListW = (tpSHGetPathFromIDListW)GetProcAddress(hmod, "SHGetPathFromIDListW");

				if (pSHBrowseForFolderW && pSHGetPathFromIDListW) {
					if (wchar_t *pszBuffer = (wchar_t *)pMalloc->Alloc(MAX_PATH * sizeof(wchar_t))) {
						BROWSEINFOW bi;
						ITEMIDLIST *pidlBrowse;

						bi.hwndOwner		= (HWND)ctxParent;
						bi.pidlRoot			= NULL;
						bi.pszDisplayName	= pszBuffer;
						bi.lpszTitle		= pszTitle;
						bi.ulFlags			= BIF_EDITBOX | /*BIF_NEWDIALOGSTYLE |*/ BIF_RETURNONLYFSDIRS | BIF_VALIDATE;
						bi.lpfn				= NULL;

						if (pidlBrowse = pSHBrowseForFolderW(&bi)) {
							if (pSHGetPathFromIDListW(pidlBrowse, pszBuffer)) {
								wcscpy(fsent.szFile, pszBuffer);
								bSuccess = true;
							}

							pMalloc->Free(pidlBrowse);
						}
						pMalloc->Free(pszBuffer);
					}
				}
			}
		}

		CoUninitialize();
	}

	VDStringW strDir;

	if (bSuccess)
		strDir = fsent.szFile;

	return strDir;
}