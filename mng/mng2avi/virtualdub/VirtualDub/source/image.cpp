//	VirtualDub - Video processing and capture application
//	Copyright (C) 1998-2002 Avery Lee
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
#include "VBitmap.h"
#include <vd2/system/error.h>
#include <vd2/system/vdalloc.h>
#include <vd2/Kasumi/pixmap.h>
#include <vd2/Kasumi/pixmapops.h>
#include <vd2/Meia/decode_png.h>
#include "imagejpegdec.h"

void ConvertOldHeader(BITMAPINFOHEADER& newhdr, const BITMAPCOREHEADER& oldhdr) {
	newhdr.biSize			= sizeof(BITMAPINFOHEADER);
	newhdr.biWidth			= oldhdr.bcWidth;
	newhdr.biHeight			= oldhdr.bcHeight;
	newhdr.biPlanes			= oldhdr.bcPlanes;
	newhdr.biCompression	= BI_RGB;
	newhdr.biBitCount		= oldhdr.bcBitCount;
	newhdr.biSizeImage		= ((newhdr.biWidth * newhdr.biBitCount + 31)>>5)*4 * abs(newhdr.biHeight);
	newhdr.biXPelsPerMeter	= 0;
	newhdr.biYPelsPerMeter	= 0;
	newhdr.biClrUsed		= 0;		// wrong for paletted, but we don't support that anyway
	newhdr.biClrImportant	= 0;
}

bool DecodeBMPHeader(const void *pBuffer, long cbBuffer, int& w, int& h, bool& bHasAlpha) {
	const BITMAPFILEHEADER *pbfh = (const BITMAPFILEHEADER *)pBuffer;

	// Check file header.

	if (cbBuffer < sizeof(BITMAPFILEHEADER) + sizeof(DWORD) || pbfh->bfType != 'MB')
		return false;

	if (pbfh->bfSize > cbBuffer || pbfh->bfOffBits > cbBuffer)
		throw MyError("Image file is too short.");

	const BITMAPINFOHEADER *pbih = (const BITMAPINFOHEADER *)((char *)pBuffer + sizeof(BITMAPFILEHEADER));

	if (pbih->biSize + sizeof(BITMAPFILEHEADER) > cbBuffer)
		throw MyError("Image file is too short.");

	BITMAPINFOHEADER bihTemp;

	if (pbih->biSize == sizeof(BITMAPCOREHEADER)) {
		const BITMAPCOREHEADER *pbch = (const BITMAPCOREHEADER *)pbih;

		ConvertOldHeader(bihTemp, *pbch);
		pbih = &bihTemp;
	}

	if (pbih->biSize < sizeof(BITMAPINFOHEADER) || pbih->biPlanes > 1 || pbih->biCompression != BI_RGB || (pbih->biBitCount != 16 && pbih->biBitCount != 24 && pbih->biBitCount != 32))
		throw MyError("Image file is in an unsupported format.");

	// Verify that the image is all there.

	if (pbfh->bfOffBits + ((pbih->biWidth*pbih->biBitCount+31)>>5)*4*pbih->biHeight > cbBuffer)
		throw MyError("Image file is too short.");

	w = pbih->biWidth;
	h = pbih->biHeight;
	bHasAlpha = false;

	return true;
}

void DecodeBMP(const void *pBuffer, long cbBuffer, VBitmap& vb) {
	// Blit the image to the framebuffer.

	const BITMAPFILEHEADER *pbfh = (const BITMAPFILEHEADER *)pBuffer;
	const BITMAPINFOHEADER *pbih = (const BITMAPINFOHEADER *)((char *)pBuffer + sizeof(BITMAPFILEHEADER));

	BITMAPINFOHEADER bihTemp;

	if (pbih->biSize == sizeof(BITMAPCOREHEADER)) {
		const BITMAPCOREHEADER *pbch = (const BITMAPCOREHEADER *)pbih;

		ConvertOldHeader(bihTemp, *pbch);
		pbih = &bihTemp;
	}

	VBitmap src((char *)pBuffer + pbfh->bfOffBits, (BITMAPINFOHEADER *)pbih);
	vb.BitBlt(0, 0, &src, 0, 0, -1, -1);
}

struct TGAHeader {
	unsigned char	IDLength;
	unsigned char	CoMapType;
	unsigned char	ImgType;
	unsigned char	IndexLo, IndexHi;
	unsigned char	LengthLo, LengthHi;
	unsigned char	CoSize;
	unsigned char	X_OrgLo, X_OrgHi;
	unsigned char	Y_OrgLo, Y_OrgHi;
	unsigned char	WidthLo, WidthHi;
	unsigned char	HeightLo, HeightHi;
	unsigned char	PixelSize;
	unsigned char	AttBits;
};

bool DecodeTGAHeader(const void *pBuffer, long cbBuffer, int& w, int& h, bool& bHasAlpha) {
	const TGAHeader& hdr = *(const TGAHeader *)pBuffer;

	if (cbBuffer < sizeof(TGAHeader))
		return false;		// too short

	// Look for the TARGA signature at the end of the file.  If we
	// find this we know the file is TARGA and can apply strict
	// checks.  Otherwise, assume old TARGA and apply loose checks.
	bool bVerified = (!memcmp((const char *)pBuffer + cbBuffer - 18, "TRUEVISION-XFILE.", 18));

	if (hdr.ImgType != 2 && hdr.ImgType != 10) {
		if (bVerified)
			throw MyError("TARGA file must be true-color or RLE true-color.");
		return false;		// not true-color
	}

	if (hdr.PixelSize != 16 && hdr.PixelSize != 24 && hdr.PixelSize != 32) {
		if (bVerified)
			throw MyError("TARGA file must be 16-bit, 24-bit, or 32-bit.");
		return false;		// not 24-bit pixels
	}

	if (hdr.AttBits & 0x10) {
		if (bVerified)
			throw MyError("Right-to-left TARGA files not supported.");
		return false;		// right-to-left not supported
	}

	switch(hdr.AttBits & 0xf) {
	case 0:		// Zero alpha bits is always valid.
		break;
	case 1:		// One alpha bit is permitted for 16-bit.
		if (hdr.PixelSize != 16)
			throw MyError("TARGA decoder: 1-bit alpha supported only with 16-bit RGB.");
		break;
	case 8:		// 8-bit alpha is permitted for 32-bit.
		if (hdr.PixelSize != 32)
			throw MyError("TARGA decoder: 8-bit alpha supported only with 32-bit RGB.");
		break;
	}

	w = hdr.WidthLo + (hdr.WidthHi << 8);
	h = hdr.HeightLo + (hdr.HeightHi << 8);
	bHasAlpha = (hdr.AttBits & 0xf) > 0;

	return true;
}

static void BitBltAlpha(VBitmap *dst, int dx, int dy, VBitmap *src, int sx, int sy, int w, int h, bool bSrcHasAlpha) {
	if (src->depth == 16 && dst->depth==32 && bSrcHasAlpha) {
		typedef unsigned short Pixel16;

		const Pixel16 *psrc = (const Pixel16 *)src->Address16(sx, sy);
		Pixel32 *pdst = dst->Address32(dx, dy);

		if (w&&h) do {
			for(int x=0; x<w; ++x) {
				Pixel32 px = psrc[x];
				Pixel32 px2 = ((px & 0x7c00) << 9) + ((px & 0x03e0) << 6) + ((px & 0x001f) << 3);

				pdst[x] = px2 + ((px2 & 0xe0e0e0)>>5) + (px&0x8000?0xff000000:0);
			}

			psrc = (const Pixel16 *)((char *)psrc - src->pitch);
			pdst = (Pixel32 *)((char *)pdst - dst->pitch);

		} while(--h);
	} else
		dst->BitBlt(dx, dy, src, sx, sy, w, h);
}

void DecodeTGA(const void *pBuffer, long cbBuffer, VBitmap& vb) {
	const TGAHeader& hdr = *(const TGAHeader *)pBuffer;
	const unsigned char *src = (const unsigned char *)pBuffer + sizeof(hdr) + hdr.IDLength;
	const unsigned char *srcLimit = (const unsigned char *)pBuffer + cbBuffer;
	const int w = hdr.WidthLo + (hdr.WidthHi << 8);
	const int h = hdr.HeightLo + (hdr.HeightHi << 8);

	VBitmap vbSrc;
	int bpp = (hdr.PixelSize+7) >> 3;		// TARGA doesn't have a 565 mode, only 555 and 1555
	bool bSrcHasAlpha = (hdr.AttBits&0xf) != 0;

	if (hdr.ImgType == 2) {
		vbSrc.data = (Pixel32 *)src;
		vbSrc.w = w;
		vbSrc.h = h;
		vbSrc.depth = bpp<<3;
		vbSrc.pitch = bpp*vbSrc.w;
		vbSrc.modulo = vbSrc.pitch & 1;
		vbSrc.pitch = (vbSrc.pitch + 1) & ~1;

		if (hdr.AttBits & 0x20) {
			vbSrc.data = (Pixel32 *)(src + vbSrc.pitch * (h-1));
			vbSrc.modulo = -bpp*vbSrc.w - vbSrc.pitch;
			vbSrc.pitch = -vbSrc.pitch;
		}

		// arrgh... 1555 is a special case.

		BitBltAlpha(&vb, 0, 0, &vbSrc, 0, 0, w, h, bSrcHasAlpha);

	} else if (hdr.ImgType == 10) {
		unsigned char *rowbuf = (unsigned char *)malloc(bpp * w + 1);
		vbSrc.data = (Pixel32 *)rowbuf;
		vbSrc.w = w;
		vbSrc.h = 1;
		vbSrc.depth = bpp<<3;
		vbSrc.pitch = vbSrc.modulo = 0;

#if 0	// This version allows RLE packets to span rows (illegal).
		unsigned char *dst = rowbuf;
		unsigned char *dstEnd = rowbuf + bpp*w;

		for(int y=0; y<h; ) {
			if (src >= srcLimit)
				throw MyError("TARGA RLE decoding error");
			unsigned c = *src++;
			const unsigned char *copysrc;

			// we always copy one pixel
			dst[0] = src[0];
			dst[1] = src[1];
			src += 2;
			dst += 2;
			for(int k=0; k<bpp-2; ++k)
				*dst++ = *src++;

			if (c & 0x80)				// run
				copysrc = dst - bpp;
			else {						// lit
				copysrc = src;
				src += bpp * c;
			}

			if (dst == dstEnd) {
				if (hdr.AttBits & 0x20)
					BitBltAlpha(&vb, 0, y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
				else
					BitBltAlpha(&vb, 0, h-1-y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
				dst = rowbuf;
				if (++y >= h)
					break;
			}

			if (c &= 0x7f) {
				c *= bpp;
//				if (dst + c > dstEnd)
//					throw MyError("TARGA RLE decoding error");

				do {
					*dst++ = *copysrc++;
					if (copysrc == dstEnd)
						copysrc = rowbuf;
					if (dst == dstEnd) {
						if (hdr.AttBits & 0x20)
							BitBltAlpha(&vb, 0, y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
						else
							BitBltAlpha(&vb, 0, h-1-y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
						dst = rowbuf;
						if (++y >= h)
							break;
					}
				} while(--c);
			}
		}
#else
		for(int y=0; y<h; ++y) {
			unsigned char *dst = rowbuf;
			unsigned char *dstEnd = rowbuf + bpp*w;

			while(dst < dstEnd) {
				if (src >= srcLimit)
					throw MyError("TARGA RLE decoding error");
				unsigned c = *src++;
				const unsigned char *copysrc;

				// we always copy one pixel
				dst[0] = src[0];
				dst[1] = src[1];
				src += 2;
				dst += 2;
				for(int k=0; k<bpp-2; ++k)
					*dst++ = *src++;

				if (c & 0x80)				// run
					copysrc = dst - bpp;
				else {						// lit
					copysrc = src;
					src += bpp * c;
				}

				if (c &= 0x7f) {
					c *= bpp;
					if (dst + c > dstEnd)
						throw MyError("TARGA RLE decoding error");

					do {
						*dst++ = *copysrc++;
					} while(--c);
				}
			}

			if (hdr.AttBits & 0x20)
				BitBltAlpha(&vb, 0, y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
			else
				BitBltAlpha(&vb, 0, h-1-y, &vbSrc, 0, 0, w, 1, bSrcHasAlpha);
		}
#endif
		free(rowbuf);
	}
}

///////////////////////////////////////////////////////////////////////////

bool IsJPEGHeader(const void *pv, uint32 len) {
	const uint8 *buf = (const uint8 *)pv;

	if (len >= 32 && buf[0] == 0xFF && buf[1] == 0xD8) {	// x'FF' SOI
		if (buf[2] == 0xFF && buf[3] == 0xE0) {		// x'FF' APP0
			// Hmm... might be a JPEG image.  Check for JFIF tag.
			if (buf[6] == 'J' && buf[7] == 'F' && buf[8] == 'I' && buf[9] == 'F')
				return true;
		}
		if (buf[2] == 0xFF && buf[3] == 0xE1) {		// x'FF' APP1
			// Hmm... might be a JPEG image.  Check for JFIF tag.
			if (buf[6] == 'E' && buf[7] == 'x' && buf[8] == 'i' && buf[9] == 'f')
				return true;
		}
	}
	return false;
}

void DecodeImage(const void *pBuffer, long cbBuffer, VBitmap& vb, int desired_depth, bool& bHasAlpha) {
	int w, h;

	bool bIsPNG = false;
	bool bIsJPG = false;
	bool bIsBMP = false;
	bool bIsTGA = false;

	bIsPNG = VDDecodePNGHeader(pBuffer, cbBuffer, w, h, bHasAlpha);
	if (!bIsPNG) {
		bIsJPG = IsJPEGHeader(pBuffer, cbBuffer);
		if (!bIsJPG) {
			bIsBMP = DecodeBMPHeader(pBuffer, cbBuffer, w, h, bHasAlpha);
			if (!bIsBMP) {
				bIsTGA = DecodeTGAHeader(pBuffer, cbBuffer, w, h, bHasAlpha);
			}
		}
	}

	if (!bIsBMP && !bIsTGA && !bIsJPG && !bIsPNG)
		throw MyError("Image file must be in PNG, Windows BMP, truecolor TARGA format, or sequential JPEG format.");

	vdautoptr<IVDJPEGDecoder> pDecoder;

	if (bIsJPG) {
		pDecoder = VDCreateJPEGDecoder();
		pDecoder->Begin(pBuffer, cbBuffer);
		pDecoder->DecodeHeader(w, h);
	}

	vb.init(new Pixel32[(((w*desired_depth+31)>>5)<<2) * h], w, h, desired_depth);
	if (!vb.data)
		throw MyMemoryError();

	if (bIsJPG) {
		int format;

		switch(vb.depth) {
		case 16:	format = IVDJPEGDecoder::kFormatXRGB1555;	break;
		case 24:	format = IVDJPEGDecoder::kFormatRGB888;		break;
		case 32:	format = IVDJPEGDecoder::kFormatXRGB8888;	break;
		}

		pDecoder->DecodeImage((char *)vb.data + vb.pitch * (vb.h - 1), -vb.pitch, format);
		pDecoder->End();
	}
	if (bIsBMP)
		DecodeBMP(pBuffer, cbBuffer, vb);
	if (bIsTGA)
		DecodeTGA(pBuffer, cbBuffer, vb);
	if (bIsPNG) {
		vdautoptr<IVDImageDecoderPNG> pPNGDecoder(VDCreateImageDecoderPNG());

		pPNGDecoder->Decode(pBuffer, cbBuffer);

		VDPixmapBlt(VDAsPixmap(vb), pPNGDecoder->GetFrameBuffer());
	}
}

void DecodeImage(const char *pszFile, VBitmap& vb, int desired_depth, bool& bHasAlpha) {
	HANDLE h = INVALID_HANDLE_VALUE;
	void *pBuffer = NULL;
	long cbBuffer;

	try {
		h = CreateFile(pszFile, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
		if (h == INVALID_HANDLE_VALUE) {
fail_read:
			throw MyWin32Error("Failure reading image file \"%s\": %%s", GetLastError(), pszFile);
		}

		DWORD dwSizeHi, dwSizeLo, dwActual;
		dwSizeLo = GetFileSize(h, &dwSizeHi);
		if (dwSizeLo == 0xFFFFFFFFUL && GetLastError() != NO_ERROR)
			goto fail_read;

		if (dwSizeLo > 0x7FFFFFFF || dwSizeHi) {
			throw MyError("Image file \"%s\" is too large to read (>2GB!).\n");
		}

		cbBuffer = dwSizeLo;
		pBuffer = malloc(cbBuffer);
		if (!pBuffer)
			throw MyMemoryError();
		
		if (!ReadFile(h, pBuffer, dwSizeLo, &dwActual, NULL) || dwActual != dwSizeLo)
			goto fail_read;

		CloseHandle(h);
		h = INVALID_HANDLE_VALUE;

		DecodeImage(pBuffer, cbBuffer, vb, desired_depth, bHasAlpha);

		free(pBuffer);
	} catch(...) {
		free(pBuffer);
		if (h != INVALID_HANDLE_VALUE)
			CloseHandle(h);
		throw;
	}
}
