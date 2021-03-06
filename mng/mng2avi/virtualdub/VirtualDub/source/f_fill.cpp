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

#include <vd2/system/refcount.h>

#include "VideoSource.h"
#include "ClippingControl.h"

#include "resource.h"
#include "filter.h"
#include "gui.h"

#include "ScriptInterpreter.h"
#include "ScriptValue.h"
#include "ScriptError.h"

extern HINSTANCE g_hInst;
extern vdrefptr<VideoSource> inputVideoAVI;

///////////////////////

typedef struct MyFilterData {
	long x1, y1, x2, y2;
	COLORREF color, color_temp;
	HBRUSH hbrColor;
} MyFilterData;

static int fill_run(const FilterActivation *fa, const FilterFunctions *ff) {
	MyFilterData *mfd = (MyFilterData *)fa->filter_data;

	unsigned long w,h;
	Pixel *dst, *dst2;
	Pixel c = (Pixel)(((mfd->color & 0xff)<<16) | (mfd->color & 0xff00) | ((mfd->color & 0xff0000)>>16));

	if (mfd->x1+mfd->x2 >= fa->dst.w) return 0;
	if (mfd->y1+mfd->y2 >= fa->dst.h) return 0;

	dst = (Pixel *)((char *)((Pixel *)fa->dst.data + mfd->x1) + mfd->y2*fa->dst.pitch);

	h = fa->dst.h - mfd->y1 - mfd->y2;
	do {
		dst2 = dst;

		w = fa->dst.w - mfd->x1 - mfd->x2;
		do {
			*dst2++ = c;
		} while(--w);

		dst = (Pixel32 *)((char *)dst + fa->dst.pitch);
	} while(--h);

	return 0;
}

static long fill_param(FilterActivation *fa, const FilterFunctions *ff) {
	fa->dst.offset = fa->src.offset;
	return 0;
}

static INT_PTR CALLBACK fillDlgProc(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam) {
	MyFilterData *mfd;

    switch (message)
    {
        case WM_INITDIALOG:
			{
				ClippingControlBounds ccb;
				LONG hborder, hspace;
				RECT rw, rc, rcok, rccancel, rcpickcolor, rccolor;
				HWND hWnd, hWndCancel, hWndPickColor, hWndColor;
				long x,y;

				mfd = (MyFilterData *)lParam;
				SetWindowLongPtr(hDlg, DWLP_USER, (LONG)mfd);

				hWnd = GetDlgItem(hDlg, IDC_BORDERS);
				ccb.x1	= mfd->x1;
				ccb.x2	= mfd->x2;
				ccb.y1	= mfd->y1;
				ccb.y2	= mfd->y2;

				mfd->color_temp = mfd->color;
				mfd->hbrColor = CreateSolidBrush(mfd->color);

				if (inputVideoAVI) {
					BITMAPINFOHEADER *bmi = inputVideoAVI->getImageFormat();
					SendMessage(hWnd, CCM_SETBITMAPSIZE, 0, MAKELONG(bmi->biWidth,bmi->biHeight));
				} else
					SendMessage(hWnd, CCM_SETBITMAPSIZE, 0, MAKELONG(320,240));

				SendMessage(hWnd, CCM_SETCLIPBOUNDS, 0, (LPARAM)&ccb);

				IVDPositionControl *pc = VDGetIPositionControlFromClippingControl((VDGUIHandle)hWnd);
				guiPositionInitFromStream(pc);

				GetWindowRect(hDlg, &rw);
				GetWindowRect(hWnd, &rc);
				hborder = rc.left - rw.left;
				ScreenToClient(hDlg, (LPPOINT)&rc.left);
				ScreenToClient(hDlg, (LPPOINT)&rc.right);

				SetWindowPos(hDlg, NULL, 0, 0, (rc.right - rc.left) + hborder*2, (rw.bottom-rw.top)+(rc.bottom-rc.top), SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOMOVE);

				hWndCancel = GetDlgItem(hDlg, IDCANCEL);
				hWnd = GetDlgItem(hDlg, IDOK);
				hWndPickColor = GetDlgItem(hDlg, IDC_PICK_COLOR);
				hWndColor = GetDlgItem(hDlg, IDC_COLOR);
				GetWindowRect(hWnd, &rcok);
				GetWindowRect(hWndCancel, &rccancel);
				GetWindowRect(hWndPickColor, &rcpickcolor);
				GetWindowRect(hWndColor, &rccolor);
				hspace = rccancel.left - rcok.right;
				ScreenToClient(hDlg, (LPPOINT)&rcok.left);
				ScreenToClient(hDlg, (LPPOINT)&rcok.right);
				ScreenToClient(hDlg, (LPPOINT)&rccancel.left);
				ScreenToClient(hDlg, (LPPOINT)&rccancel.right);
				ScreenToClient(hDlg, (LPPOINT)&rcpickcolor.left);
				ScreenToClient(hDlg, (LPPOINT)&rcpickcolor.right);
				ScreenToClient(hDlg, (LPPOINT)&rccolor.left);
				ScreenToClient(hDlg, (LPPOINT)&rccolor.right);

				x = rc.right;
				y = rc.bottom - rc.top;

				x -= (rccancel.right - rccancel.left);
				SetWindowPos(hWndCancel	, NULL, x           ,    rccancel.top + y, 0,0,SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOSIZE);

				x -= (rcok.right - rcok.left);
				SetWindowPos(hWnd		, NULL, x - hspace  ,        rcok.top + y, 0,0,SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOSIZE);

				SetWindowPos(hWndPickColor, NULL, rcpickcolor.left, rcpickcolor.top + y, 0,0,SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOSIZE);

				SetWindowPos(hWndColor	, NULL, rccolor.left,        rccolor.top + y, 0,0,SWP_NOZORDER|SWP_NOACTIVATE|SWP_NOSIZE);
			}

            return (TRUE);

        case WM_COMMAND:
			switch(LOWORD(wParam)) {
			case IDOK:
				{
					ClippingControlBounds ccb;

					mfd = (MyFilterData *)GetWindowLongPtr(hDlg, DWLP_USER);
					SendMessage(GetDlgItem(hDlg, IDC_BORDERS), CCM_GETCLIPBOUNDS, 0, (LPARAM)&ccb);
					mfd->x1 = ccb.x1;
					mfd->y1 = ccb.y1;
					mfd->x2 = ccb.x2;
					mfd->y2 = ccb.y2;
					mfd->color = mfd->color_temp;
					if (mfd->hbrColor) {
						DeleteObject(mfd->hbrColor);
						mfd->hbrColor = NULL;
					}
					EndDialog(hDlg, 0);
				}
				return TRUE;
			case IDCANCEL:
				mfd = (MyFilterData *)GetWindowLongPtr(hDlg, DWLP_USER);
				if (mfd->hbrColor) {
					DeleteObject(mfd->hbrColor);
					mfd->hbrColor = NULL;
				}
				EndDialog(hDlg, 1);
				return TRUE;
			case IDC_BORDERS:
				{
					IVDPositionControl *pc = VDGetIPositionControlFromClippingControl((VDGUIHandle)(HWND)lParam);
					guiPositionBlit((HWND)lParam, guiPositionHandleCommand(wParam, pc));
				}
				return TRUE;

			case IDC_PICK_COLOR:
				mfd = (MyFilterData *)GetWindowLongPtr(hDlg, DWLP_USER);

				if (guiChooseColor(hDlg, mfd->color_temp)) {
					DeleteObject(mfd->hbrColor);
					mfd->hbrColor = CreateSolidBrush(mfd->color_temp);
					RedrawWindow(GetDlgItem(hDlg, IDC_COLOR), NULL, NULL, RDW_ERASE|RDW_INVALIDATE|RDW_UPDATENOW);
				}

				return TRUE;
			}
            break;

		case WM_NOTIFY:
			{
				HWND hwndClipping = ((NMHDR *)lParam)->hwndFrom;
				IVDPositionControl *pc = VDGetIPositionControlFromClippingControl((VDGUIHandle)hwndClipping);
				guiPositionBlit(hwndClipping, guiPositionHandleNotify(lParam, pc));
			}
			break;

		case WM_CTLCOLORSTATIC:
			mfd = (MyFilterData *)GetWindowLongPtr(hDlg, DWLP_USER);
			return (BOOL)mfd->hbrColor;
			break;
    }
    return FALSE;
}

static int fill_config(FilterActivation *fa, const FilterFunctions *ff, HWND hWnd) {
	return DialogBoxParam(g_hInst, MAKEINTRESOURCE(IDD_FILTER_FILL), hWnd, fillDlgProc, (LONG)fa->filter_data);
}

static void fill_string(const FilterActivation *fa, const FilterFunctions *ff, char *buf) {
	MyFilterData *mfd = (MyFilterData *)fa->filter_data;

	wsprintf(buf, " (color: #%02X%02X%02X)", mfd->color&0xff, (mfd->color>>8)&0xff, (mfd->color>>16)&0xff);
}

static void fill_script_config(IScriptInterpreter *isi, void *lpVoid, CScriptValue *argv, int argc) {
	FilterActivation *fa = (FilterActivation *)lpVoid;
	MyFilterData *mfd = (MyFilterData *)fa->filter_data;

	mfd->x1		= argv[0].asInt();
	mfd->y1		= argv[1].asInt();
	mfd->x2		= argv[2].asInt();
	mfd->y2		= argv[3].asInt();
	mfd->color	= argv[4].asInt();
}

static ScriptFunctionDef fill_func_defs[]={
	{ (ScriptFunctionPtr)fill_script_config, "Config", "0iiiii" },
	{ NULL },
};

static CScriptObject fill_obj={
	NULL, fill_func_defs
};

static bool fill_script_line(FilterActivation *fa, const FilterFunctions *ff, char *buf, int buflen) {
	MyFilterData *mfd = (MyFilterData *)fa->filter_data;

	_snprintf(buf, buflen, "Config(%d,%d,%d,%d,0x%06lx)", mfd->x1, mfd->y1, mfd->x2, mfd->y2, mfd->color);

	return true;
}

FilterDefinition filterDef_fill={
	0,0,NULL,
	"fill",
	"Fills an image rectangle with a color.",
	NULL,NULL,
	sizeof(MyFilterData),
	NULL,NULL,
	fill_run,
	fill_param,
	fill_config,
	fill_string,
	NULL,
	NULL,

	&fill_obj,
	fill_script_line,
};

