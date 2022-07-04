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

#include <vd2/Riza/bitmap.h>
#include <vd2/Kasumi/pixmap.h>
#include <vd2/Kasumi/pixmaputils.h>

int VDBitmapFormatToPixmapFormat(const BITMAPINFOHEADER& hdr) {
	int variant;

	return VDBitmapFormatToPixmapFormat(hdr, variant);
}

int VDBitmapFormatToPixmapFormat(const BITMAPINFOHEADER& hdr, int& variant) {
	using namespace nsVDPixmap;

	variant = 1;

	switch(hdr.biCompression) {
	case BI_RGB:
		if (hdr.biPlanes == 1) {
			if (hdr.biBitCount == 16)
				return kPixFormat_XRGB1555;
			else if (hdr.biBitCount == 24)
				return kPixFormat_RGB888;
			else if (hdr.biBitCount == 32)
				return kPixFormat_XRGB8888;
		}
		break;
	case BI_BITFIELDS:
		{
			const BITMAPV4HEADER& v4hdr = (const BITMAPV4HEADER&)hdr;
			const int bits = v4hdr.bV4BitCount;
			const uint32 r = v4hdr.bV4RedMask;
			const uint32 g = v4hdr.bV4GreenMask;
			const uint32 b = v4hdr.bV4BlueMask;

			if (bits == 16 && r == 0x7c00 && g == 0x03e0 && b == 0x001f)
				return kPixFormat_XRGB1555;
			else if (bits == 16 && r == 0xf800 && g == 0x07c0 && b == 0x001f)
				return kPixFormat_RGB565;
			else if (bits == 24 && r == 0xff0000 && g == 0x00ff00 && b == 0x0000ff)
				return kPixFormat_RGB888;
			else if (bits == 32 && r == 0xff0000 && g == 0x00ff00 && b == 0x0000ff)
				return kPixFormat_XRGB8888;
		}
		break;
	case 'YVYU':
		return kPixFormat_YUV422_UYVY;
	case '2YUY':
		return kPixFormat_YUV422_YUYV;
	case '21VY':
		return kPixFormat_YUV420_Planar;
	case '024I':
		variant = 2;
		return kPixFormat_YUV420_Planar;
	case 'VUYI':
		variant = 3;
		return kPixFormat_YUV420_Planar;
	case '  8Y':
		return kPixFormat_Y8;
	}
	return 0;
}

int VDGetPixmapToBitmapVariants(int format) {
	if (format == nsVDPixmap::kPixFormat_YUV420_Planar)
		return 3;

	return 1;
}

bool VDMakeBitmapFormatFromPixmapFormat(vdstructex<BITMAPINFOHEADER>& dst, const vdstructex<BITMAPINFOHEADER>& src, int format, int variant) {
	return VDMakeBitmapFormatFromPixmapFormat(dst, src, format, variant, src->biWidth, src->biHeight);
}

bool VDMakeBitmapFormatFromPixmapFormat(vdstructex<BITMAPINFOHEADER>& dst, const vdstructex<BITMAPINFOHEADER>& src, int format, int variant, uint32 w, uint32 h) {
	using namespace nsVDPixmap;

	dst = src;
	dst->biSize				= sizeof(BITMAPINFOHEADER);
	dst->biWidth			= w;
	dst->biHeight			= h;
	dst->biPlanes			= 1;
	dst->biXPelsPerMeter	= src->biXPelsPerMeter;
	dst->biYPelsPerMeter	= src->biYPelsPerMeter;

	if (format == kPixFormat_Pal8) {
		dst->biBitCount		= 8;
		dst->biCompression	= BI_RGB;
		dst->biSizeImage	= ((w+3)&~3)*h;
		return true;
	}

	dst.resize(sizeof(BITMAPINFOHEADER));

	dst->biClrUsed			= 0;
	dst->biClrImportant		= 0;

	switch(format) {
	case kPixFormat_XRGB1555:
		dst->biCompression	= BI_RGB;
		dst->biBitCount		= 16;
		dst->biSizeImage	= ((w*2+3)&~3) * h;
		break;
	case kPixFormat_RGB565:
		dst->biCompression	= BI_BITFIELDS;
		dst->biBitCount		= 16;
		dst->biSizeImage	= ((w*2+3)&~3) * h;
		dst.resize(sizeof(BITMAPINFOHEADER) + 3*sizeof(DWORD));
		{
			DWORD *fields = (DWORD *)(dst.data() + 1);
			fields[0] = 0xf800;
			fields[1] = 0x07c0;
			fields[2] = 0x001f;
		}
		break;
	case kPixFormat_RGB888:
		dst->biCompression	= BI_RGB;
		dst->biBitCount		= 24;
		dst->biSizeImage	= ((w*3+3)&~3) * h;
		break;
	case kPixFormat_XRGB8888:
		dst->biCompression	= BI_RGB;
		dst->biBitCount		= 32;
		dst->biSizeImage	= w*4 * h;
		break;
	case kPixFormat_YUV422_UYVY:
		dst->biCompression	= 'YVYU';
		dst->biBitCount		= 16;
		dst->biSizeImage	= ((w+1)&~1)*2*h;
		break;
	case kPixFormat_YUV422_YUYV:
		dst->biCompression	= '2YUY';
		dst->biBitCount		= 16;
		dst->biSizeImage	= ((w+1)&~1)*2*h;
		break;
	case kPixFormat_YUV422_Planar:
		dst->biCompression	= '61VY';
		dst->biBitCount		= 16;
		dst->biSizeImage	= ((w+1)>>1) * h * 4;
		break;
	case kPixFormat_YUV420_Planar:
		switch(variant) {
		case 3:
			dst->biCompression	= 'VUYI';
			break;
		case 2:
			dst->biCompression	= '024I';
			break;
		case 1:
		default:
			dst->biCompression	= '21VY';
			break;
		}
		dst->biBitCount		= 12;
		dst->biSizeImage	= w*h + (w>>1)*(h>>1)*2;
		break;
	case kPixFormat_YUV410_Planar:
		dst->biCompression	= '9UVY';
		dst->biBitCount		= 9;
		dst->biSizeImage	= ((w+2)>>2) * ((h+2)>>2) * 18;
		break;
	case kPixFormat_Y8:
		dst->biCompression	= '  8Y';
		dst->biBitCount		= 8;
		dst->biSizeImage	= ((w+3) & ~3) * h;
		break;
	default:
		return false;
	};

	return true;
}

uint32 VDMakeBitmapCompatiblePixmapLayout(VDPixmapLayout& layout, uint32 w, uint32 h, int format, int variant) {
	using namespace nsVDPixmap;

	uint32 linspace = VDPixmapCreateLinearLayout(layout, format, w, h, VDPixmapGetInfo(format).auxbufs > 1 ? 1 : 4);

	switch(format) {
	case kPixFormat_Pal8:
	case kPixFormat_XRGB1555:
	case kPixFormat_RGB888:
	case kPixFormat_RGB565:
	case kPixFormat_XRGB8888:
		layout.data += layout.pitch * (h-1);
		layout.pitch = -layout.pitch;
		break;
	case kPixFormat_YUV420_Planar:
		if (variant < 2) {				// need to swap UV planes for YV12 (1)
			std::swap(layout.data2, layout.data3);
			std::swap(layout.pitch2, layout.pitch3);
		}
		break;
	}

	return linspace;
}
