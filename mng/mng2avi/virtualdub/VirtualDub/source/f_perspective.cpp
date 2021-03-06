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
#include <windowsx.h>
#include <commctrl.h>

#include <vd2/system/vdtypes.h>
#include <vd2/system/vectors.h>

#include "ScriptInterpreter.h"
#include "ScriptValue.h"
#include "ScriptError.h"

#include "misc.h"
#include <vd2/Kasumi/pixmap.h>
#include <vd2/Kasumi/triblt.h>
#include <vd2/Kasumi/resample.h>
#include "resource.h"
#include "gui.h"
#include "filter.h"
#include "vbitmap.h"

extern HINSTANCE g_hInst;

///////////////////////

vdmatrix3f MapQuadToUnitSquare(const vdvector2f src[4]) {
	double m[8][8] = {
		{	-src[0][0],	-src[0][1],	-1,		+src[0][0],	+src[0][1],	+1,		0,			0,			},
		{	-src[0][0],	-src[0][1],	-1,		0,			0,			0,		-src[0][0],	-src[0][1],	},
		{	+src[1][0],	+src[1][1],	+1,		+src[1][0],	+src[1][1],	+1,		0,			0,			},
		{	+src[1][0],	+src[1][1],	+1,		0,			0,			0,		-src[1][0],	-src[1][1],	},
		{	-src[2][0],	-src[2][1],	-1,		-src[2][0],	-src[2][1],	-1,		0,			0,			},
		{	-src[2][0],	-src[2][1],	-1,		0,			0,			0,		-src[2][0],	-src[2][1],	},
		{	+src[3][0],	+src[3][1],	+1,		-src[3][0],	-src[3][1],	-1,		0,			0,			},
		{	+src[3][0],	+src[3][1],	+1,		0,			0,			0,		-src[3][0],	-src[3][1],	},
	};

	double b[8]={
		0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0,
	};

	VDSolveLinearEquation(&m[0][0], 8, 8, b);

	vdmatrix3f mx;

	mx[0] = vdvector3f((float)b[0], (float)b[1], (float)b[2]);
	mx[1] = vdvector3f((float)b[3], (float)b[4], (float)b[5]);
	mx[2] = vdvector3f((float)b[6], (float)b[7], 1);

	return mx;
}

///////////////////////

namespace {
	const char *const g_filterModes[]={
		"Point sampling",
		"Bilinear",
		"Trilinear"
	};
};

///////////////////////

struct PerspectiveFilterData {
	long new_x, new_y;
#if 0
	int hrot, vrot, roll, nearpt, zoom;
#else
	vdvector2f src[4];
#endif

	int filtermode;
	bool unproject;
	IFilterPreview *ifp;
};

////////////////////

namespace {
	void rotate(float& v1, float& v2, float& v3, float& v4, double ang) {
		float c = (float)cos(ang);
		float s = (float)sin(ang);

		float y1 = v1*c-v3*s;
		float y2 = v2*c-v4*s;
		float y3 = v1*s+v3*c;
		float y4 = v2*s+v4*c;

		v1 = y1;
		v2 = y2;
		v3 = y3;
		v4 = y4;
	}
}

static int perspective_init(FilterActivation *fa, const FilterFunctions *ff) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;

#if 0
	mfd->zoom = 100;
#else
	mfd->src[0] = vdvector2f(-1, -1);
	mfd->src[1] = vdvector2f(+1, -1);
	mfd->src[2] = vdvector2f(-1, +1);
	mfd->src[3] = vdvector2f(+1, +1);
#endif
	return 0;
}

static int perspective_run(const FilterActivation *fa, const FilterFunctions *ff) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;
	VDPixmap pxsrc = {0};
	VDPixmap pxdst = {0};

	pxsrc.data		= (char *)fa->src.data + fa->src.pitch * (fa->src.h-1);
	pxsrc.pitch		= -fa->src.pitch;
	pxsrc.format	= nsVDPixmap::kPixFormat_XRGB8888;
	pxsrc.w			= fa->src.w;
	pxsrc.h			= fa->src.h;

	pxdst.data		= (char *)fa->dst.data + fa->dst.pitch * (fa->dst.h-1);
	pxdst.pitch		= -fa->dst.pitch;
	pxdst.format	= nsVDPixmap::kPixFormat_XRGB8888;
	pxdst.w			= fa->dst.w;
	pxdst.h			= fa->dst.h;

	VDPixmapTextureMipmapChain	mipmaps(pxsrc, false, mfd->filtermode ? 16 : 1);

	VDTriBltVertex trivx[8]={
		{ -1, -1, 0, 0, 0 },
		{ +1, -1, 0, (float)pxsrc.w, 0 },
		{ +1, +1, 0, (float)pxsrc.w, (float)pxsrc.h },
		{ -1, +1, 0, 0, (float)pxsrc.h },
	};

	static const int indices[6]={0,1,2,0,2,3};

	vdmatrix3f temp(MapQuadToUnitSquare(mfd->src));

	if (!mfd->unproject)
		temp = ~temp;

	vdmatrix4f mx;

	mx[0][0] = temp[0][0];
	mx[0][1] = temp[0][1];
	mx[0][2] = 0;
	mx[0][3] = temp[0][2];
	mx[1][0] = temp[1][0];
	mx[1][1] = temp[1][1];
	mx[1][2] = 0;
	mx[1][3] = temp[1][2];
	mx[2][0] = 0;
	mx[2][1] = 0;
	mx[2][3] = 0;
	mx[2][2] = 0;
	mx[3][0] = temp[2][0];
	mx[3][1] = temp[2][1];
	mx[3][2] = 0;
	mx[3][3] = temp[2][2];

	// manually transform corners and form fill mesh
	for(int i=0; i<4; ++i) {
		vdvector3f xfv((mx*vdvector4f(trivx[i].x, trivx[i].y, trivx[i].z, 1.0f)).project());

		trivx[i+4].x = xfv[0];
		trivx[i+4].y = xfv[1];
		trivx[i+4].z = xfv[2];
	}

	static const int fillmesh[24]={
		0,1,5,5,4,0,
		1,2,6,6,5,1,
		2,3,7,7,6,2,
		3,0,4,4,7,3
	};

	VDPixmapTriFill(pxdst, 0, trivx, 8, fillmesh, 24, NULL);

	// texture image
	VDPixmapTriBlt(pxdst, mipmaps.Mips(), mipmaps.Levels(), trivx, 4, indices, 6, (VDTriBltFilterMode)mfd->filtermode, true, mx.data());

	return 0;
}

static long perspective_param(FilterActivation *fa, const FilterFunctions *ff) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;

	fa->dst.w		= mfd->new_x;
	fa->dst.h		= mfd->new_y;

	fa->dst.AlignTo8();

	return FILTERPARAM_SWAP_BUFFERS;
}

namespace {
	struct PerspectiveFilterDialog : public VDDialogBaseW32 {
	public:
		static bool Activate(HWND hwndBase, PerspectiveFilterData *pfd) {
			return 0 != PerspectiveFilterDialog(pfd).ActivateDialog((VDGUIHandle)hwndBase);
		}

	protected:
		PerspectiveFilterDialog(PerspectiveFilterData *pfd) : VDDialogBaseW32(IDD_FILTER_PERSPECTIVE), mfd(pfd) {}
		INT_PTR DlgProc(UINT msg, WPARAM wParam, LPARAM lParam);

		static void __cdecl ButtonCallback(bool bNewState, void *p);
		static void __cdecl SampleCallback(VFBitmap *pf, long lFrame, long lCount, void *pData);

		PerspectiveFilterData *const mfd;
		int dragpip, dragoffsetx, dragoffsety;

		std::vector<uint32>	mFrameBuffer;
		RECT mFrame;
	};

	INT_PTR PerspectiveFilterDialog::DlgProc(UINT msg, WPARAM wParam, LPARAM lParam) {
		switch (msg)
		{
			case WM_INITDIALOG:
				{
					SetDlgItemInt(mhdlg, IDC_WIDTH, mfd->new_x, FALSE);
					SetDlgItemInt(mhdlg, IDC_HEIGHT, mfd->new_y, FALSE);
					CheckDlgButton(mhdlg, IDC_UNPROJECT, mfd->unproject);

					HWND hwndCombo = GetDlgItem(mhdlg, IDC_FILTER);
					for(int i=0; i<sizeof g_filterModes / sizeof g_filterModes[0]; ++i)
						SendMessage(hwndCombo, CB_ADDSTRING, 0, (LPARAM)g_filterModes[i]);

					SendMessage(hwndCombo, CB_SETCURSEL, mfd->filtermode, 0);

					if (mfd->ifp) {
						mfd->ifp->InitButton(GetDlgItem(mhdlg, IDC_PREVIEW));
						mfd->ifp->SetButtonCallback(ButtonCallback, this);
						mfd->ifp->SetSampleCallback(SampleCallback, this);
					}

					HWND hwndItem = GetDlgItem(mhdlg, IDC_FIELD);
					ShowWindow(hwndItem, SW_HIDE);

					dragpip = -1;

					RECT r;
					GetWindowRect(GetDlgItem(mhdlg, IDC_FIELD), &r);
					MapWindowPoints(NULL, mhdlg, (LPPOINT)&r, 2);

					mFrame.left		= r.left + VDRoundToInt(1.00 * (r.right - r.left) / 4.0);
					mFrame.right	= r.left + VDRoundToInt(3.00 * (r.right - r.left) / 4.0);
					mFrame.top		= r.top + VDRoundToInt(1.00 * (r.bottom - r.top) / 4.0) + 1;
					mFrame.bottom	= r.top + VDRoundToInt(3.00 * (r.bottom - r.top) / 4.0) + 1;

					mFrameBuffer.resize((mFrame.right - mFrame.left) * (mFrame.bottom - mFrame.top));
				}
				return (TRUE);

			case WM_PAINT:
				{
					PAINTSTRUCT ps;				
					RECT r;
					GetWindowRect(GetDlgItem(mhdlg, IDC_FIELD), &r);
					MapWindowPoints(NULL, mhdlg, (LPPOINT)&r, 2);

					if (HDC hdc = BeginPaint(mhdlg, &ps)) {
						POINT pt[5];

						FillRect(hdc, &r, (HBRUSH)GetStockObject(BLACK_BRUSH));

						BITMAPINFOHEADER bih;

						bih.biSize			= sizeof(BITMAPINFOHEADER);
						bih.biWidth			= mFrame.right - mFrame.left;
						bih.biHeight		= mFrame.bottom - mFrame.top;
						bih.biPlanes		= 1;
						bih.biCompression	= BI_RGB;
						bih.biBitCount		= 32;
						bih.biSizeImage		= 0;
						bih.biXPelsPerMeter	= 0;
						bih.biYPelsPerMeter	= 0;
						bih.biClrUsed		= 0;
						bih.biClrImportant	= 0;

						SetDIBitsToDevice(hdc, mFrame.left, mFrame.top, bih.biWidth, bih.biHeight, 0, 0, 0, bih.biHeight, &mFrameBuffer[0], (const BITMAPINFO *)&bih, DIB_RGB_COLORS);

						HGDIOBJ hOldPen = SelectObject(hdc, GetStockObject(WHITE_PEN));

						for(int i=0; i<4; ++i) {
							int j = "\0\1\3\2"[i];
							pt[i].x = r.left + VDRoundToInt((mfd->src[j][0] + 2.0) * (r.right  - r.left) / 4.0);
							pt[i].y = r.top + VDRoundToInt((mfd->src[j][1] + 2.0) * (r.bottom - r.top ) / 4.0);

							RECT rPip = { pt[i].x-2, pt[i].y-2, pt[i].x+3, pt[i].y+3 };
							FillRect(hdc, &rPip, (HBRUSH)GetStockObject(WHITE_BRUSH));
						}

						pt[4] = pt[0];
						Polyline(hdc, pt, 5);

						SelectObject(hdc, hOldPen);

						EndPaint(mhdlg, &ps);
					}
				}
				break;

			case WM_LBUTTONDOWN:
				{
					RECT r;
					GetWindowRect(GetDlgItem(mhdlg, IDC_FIELD), &r);
					MapWindowPoints(NULL, mhdlg, (LPPOINT)&r, 2);

					int x = GET_X_LPARAM(lParam);
					int y = GET_Y_LPARAM(lParam);
					int i;

					for(i=0; i<4; ++i) {
						int px = r.left + VDRoundToInt((mfd->src[i][0] + 2.0) * (r.right  - r.left) / 4.0);
						int py = r.top + VDRoundToInt((mfd->src[i][1] + 2.0) * (r.bottom - r.top ) / 4.0);

						if (abs(px-x)<=2 && abs(py-y)<=2) {
							dragpip = i;
							dragoffsetx = x - px;
							dragoffsety = y - py;
							break;
						}
					}

					SetCapture(mhdlg);
				}
				break;

			case WM_MOUSEMOVE:
				if (dragpip >= 0) {
					RECT r;
					GetWindowRect(GetDlgItem(mhdlg, IDC_FIELD), &r);
					MapWindowPoints(NULL, mhdlg, (LPPOINT)&r, 2);

					int x = GET_X_LPARAM(lParam) - dragoffsetx;
					int y = GET_Y_LPARAM(lParam) - dragoffsety;
					float px = (x - r.left) / (float)(r.right - r.left) * 4.0f - 2.0f;
					float py = (y - r.top) / (float)(r.bottom - r.top) * 4.0f - 2.0f;

					if (px < -2) px=-2; else if (px > +2) px=+2;
					if (py < -2) py=-2; else if (py > +2) py=+2;

					mfd->src[dragpip][0] = px;
					mfd->src[dragpip][1] = py;
					InvalidateRect(mhdlg, &r, FALSE);
				}
				break;

			case WM_LBUTTONUP:
				ReleaseCapture();
				dragpip = -1;
				if (mfd->ifp)
					mfd->ifp->RedoFrame();
				break;

			case WM_COMMAND:                      
				switch(LOWORD(wParam)) {
				case IDOK:
					if (mfd->ifp)
						mfd->ifp->Close();
					End(0);
					return TRUE;

				case IDCANCEL:
					if (mfd->ifp)
						mfd->ifp->Close();
					End(1);
					return TRUE;

				case IDC_WIDTH:
					if (HIWORD(wParam) == EN_KILLFOCUS) {
						long new_x;
						BOOL success;

						new_x = GetDlgItemInt(mhdlg, IDC_WIDTH, &success, FALSE);
						if (!success || new_x < 16) {
							SetFocus((HWND)lParam);
							MessageBeep(MB_ICONQUESTION);
							return TRUE;
						}

						if (mfd->ifp)
							mfd->ifp->UndoSystem();
						mfd->new_x = new_x;
						if (mfd->ifp)
							mfd->ifp->RedoSystem();
					}
					return TRUE;

				case IDC_HEIGHT:
					if (HIWORD(wParam) == EN_KILLFOCUS) {
						long new_y;
						BOOL success;

						new_y = GetDlgItemInt(mhdlg, IDC_HEIGHT, &success, FALSE);
						if (!success || new_y < 16) {
							SetFocus((HWND)lParam);
							MessageBeep(MB_ICONQUESTION);
							return TRUE;
						}

						if (mfd->ifp)
							mfd->ifp->UndoSystem();
						mfd->new_y = new_y;
						if (mfd->ifp)
							mfd->ifp->RedoSystem();
					}
					return TRUE;

				case IDC_FILTER:
					if (HIWORD(wParam) == CBN_SELCHANGE) {
						mfd->filtermode = SendMessage((HWND)lParam, CB_GETCURSEL, 0, 0);
						if (mfd->ifp)
							mfd->ifp->RedoFrame();
					}
					return TRUE;

				case IDC_UNPROJECT:
					if (HIWORD(wParam) == BN_CLICKED) {
						mfd->unproject = 0 != (SendMessage((HWND)lParam, BM_GETSTATE, 0, 0)&3);
						if (mfd->ifp)
							mfd->ifp->RedoFrame();
					}
					return TRUE;

				case IDC_PREVIEW:
					if (mfd->ifp)
						mfd->ifp->Toggle(mhdlg);
					return TRUE;

				case IDC_SAMPLE:
					if (mfd->ifp)
						mfd->ifp->SampleCurrentFrame();
					return TRUE;
				}
				break;
		}
		return FALSE;
	}

	void PerspectiveFilterDialog::ButtonCallback(bool bNewState, void *p) {
		PerspectiveFilterDialog *const pThis = (PerspectiveFilterDialog *)p;

		EnableWindow(GetDlgItem(pThis->mhdlg, IDC_SAMPLE), bNewState);
	}

	void PerspectiveFilterDialog::SampleCallback(VFBitmap *pf, long lFrame, long lCount, void *pData) {
		PerspectiveFilterDialog *const pThis = (PerspectiveFilterDialog *)pData;
		VDPixmap pxdst;

		pxdst.w			= pThis->mFrame.right - pThis->mFrame.left;
		pxdst.h			= pThis->mFrame.bottom - pThis->mFrame.top;
		pxdst.pitch		= -pxdst.w*4;
		pxdst.format	= nsVDPixmap::kPixFormat_XRGB8888;
		pxdst.data		= &pThis->mFrameBuffer[pxdst.w * (pxdst.h - 1)];

		GdiFlush();
		VDPixmapResample(pxdst, VDAsPixmap((const VBitmap&)*pf), IVDPixmapResampler::kFilterLinear);

		InvalidateRect(pThis->mhdlg, &pThis->mFrame, FALSE);
	}
};

static int perspective_config(FilterActivation *fa, const FilterFunctions *ff, HWND hWnd) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;
	PerspectiveFilterData mfd2 = *mfd;

	mfd->ifp = fa->ifp;

	if (mfd->new_x < 16)
		mfd->new_x = 320;
	if (mfd->new_y < 16)
		mfd->new_y = 240;

	if (PerspectiveFilterDialog::Activate(hWnd, mfd)) {
		*mfd = mfd2;
		return 1;
	}

	return 0;
}

static int perspective_start(FilterActivation *fa, const FilterFunctions *ff) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;
	long dstw = mfd->new_x;
	long dsth = mfd->new_y;

	if (dstw<16 || dsth<16)
		return 1;

	return 0;
}

static int perspective_stop(FilterActivation *fa, const FilterFunctions *ff) {
	return 0;
}

static void perspective_script_config(IScriptInterpreter *isi, void *lpVoid, CScriptValue *argv, int argc) {
	FilterActivation *fa = (FilterActivation *)lpVoid;

	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;

	mfd->new_x	= argv[0].asInt();
	mfd->new_y	= argv[1].asInt();
}

static ScriptFunctionDef perspective_func_defs[]={
	{ (ScriptFunctionPtr)perspective_script_config, "Config", "0ii" },
	{ NULL },
};

static CScriptObject perspective_obj={
	NULL, perspective_func_defs
};

static bool perspective_script_line(FilterActivation *fa, const FilterFunctions *ff, char *buf, int buflen) {
	PerspectiveFilterData *mfd = (PerspectiveFilterData *)fa->filter_data;

	_snprintf(buf, buflen, "Config(%d,%d)", mfd->new_x, mfd->new_y);

	return true;
}

FilterDefinition filterDef_perspective={
	0,0,NULL,
	"perspective",
	"Applies a perspective warp to an image."
			,
	NULL,NULL,
	sizeof(PerspectiveFilterData),
	perspective_init,NULL,
	perspective_run,
	perspective_param,
	perspective_config,
	NULL,
	perspective_start,
	perspective_stop,

	&perspective_obj,
	perspective_script_line,
};