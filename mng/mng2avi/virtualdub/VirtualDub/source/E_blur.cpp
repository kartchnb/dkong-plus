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

#include <vd2/system/error.h>

#include <vd2/system/cpuaccel.h>
#include "effect.h"
#include "vbitmap.h"
#include "e_blur.h"

static const __int64 mmx_offset2 = 0x0002000200020002i64;
static const __int64 mmx_offset8 = 0x0008000800080008i64;
static const __int64 mmx_by11	 = 0x000b000b000b000bi64;
static const __int64 mmx_by6	 = 0x0006000600060006i64;


///////////////////////////////////////////////////////////////////////////

class VEffectBlur : public VEffect {
public:
	VEffectBlur(const VBitmap *);
	~VEffectBlur();

	void run(const VBitmap *);
	void run(const VBitmap *, const VBitmap *);

private:
	Pixel32 *rows[3];

};

///////////////////////////////////////////////////////////////////////////

VEffect *VCreateEffectBlur(const VBitmap *vbm) {
	return new VEffectBlur(vbm);
}

VEffectBlur::VEffectBlur(const VBitmap *vbm) {
	int i;

	for(i=0; i<3; i++)
		if (!(rows[i] = new Pixel32[vbm->w])) {
			while(--i>=0)
				delete rows[i];

			throw MyMemoryError();
		}
}

VEffectBlur::~VEffectBlur() {
	int i;

	for(i=0; i<3; i++)
		delete rows[i];
}

#ifdef _M_IX86
static void __declspec(naked) dorow_MMX(Pixel32 *dst, Pixel32 *src, PixDim w) {
	__asm {
		mov		eax,[esp+8]
		mov		edx,[esp+4]
		pxor	mm7,mm7
		movq	mm3,mmx_offset2

		;first pixel

		movd		mm0,[eax]
		movd		mm6,[eax+4]
		punpcklbw	mm0,mm7
		punpcklbw	mm6,mm7
		movq		mm5,mm0
		paddw		mm0,mm0
		paddw		mm0,mm5
		paddw		mm0,mm6
		paddw		mm0,mm3
		psraw		mm0,2
		packuswb	mm0,mm0
		movd		[edx],mm0

		mov			ecx,[esp+12]
		shl			ecx,2
		neg			ecx
		add			ecx,16

		sub			eax,ecx
		sub			edx,ecx

		;on entry into pixel loop:
		;
		;	mm3		2
		;	mm5		pixel[-2]
		;	mm6		pixel[-1]
		;	mm7		zero

xloop:
		movd		mm4,[eax+ecx+8]
		punpcklbw	mm4,mm7

		paddw		mm5,mm6
		paddw		mm5,mm4
		paddw		mm5,mm6
		paddw		mm5,mm3
		psraw		mm5,2
		packuswb	mm5,mm5
		movd		[edx+ecx+4],mm5

		;	mm4		pixel[-1]
		;	mm5
		;	mm6		pixel[-2]

		movd		mm5,[eax+ecx+12]
		punpcklbw	mm5,mm7

		paddw		mm6,mm4
		paddw		mm6,mm4
		paddw		mm6,mm5
		paddw		mm6,mm3
		psraw		mm6,2
		packuswb	mm6,mm6
		movd		[edx+ecx+8],mm6

		;	mm4		pixel[-2]
		;	mm5		pixel[-1]
		;	mm6

		movd		mm6,[eax+ecx+16]
		punpcklbw	mm6,mm7

		paddw		mm4,mm5
		paddw		mm4,mm5
		paddw		mm4,mm6
		paddw		mm4,mm3
		psraw		mm4,2
		packuswb	mm4,mm4
		movd		[edx+ecx+12],mm4

		add			ecx,12
		jnc			xloop

		;last pixel
		;
		;w=5 -> ecx=+8, 1 odd left
		;w=6 -> ecx=+4, 2 odd left
		;w=7 -> ecx=0, 3 odd left

		sub			ecx,4
		jnc			odd1

		movd		mm4,[eax+8]
		punpcklbw	mm4,mm7

		paddw		mm5,mm6
		paddw		mm5,mm4
		paddw		mm5,mm6
		paddw		mm5,mm3
		psraw		mm5,2
		packuswb	mm5,mm5
		movd		[edx+4],mm5

		;	mm4		pixel[-1]
		;	mm5
		;	mm6		pixel[-2]

		movd		mm5,[eax+12]
		punpcklbw	mm5,mm7

		paddw		mm6,mm4
		paddw		mm6,mm4
		paddw		mm6,mm5
		paddw		mm6,mm3
		psraw		mm6,2
		packuswb	mm6,mm6
		movd		[edx+8],mm6

		;	mm4		pixel[-2]
		;	mm5		pixel[-1]
		;	mm6

		paddw		mm4,mm5
		paddw		mm4,mm5
		paddw		mm4,mm5
		paddw		mm4,mm3
		psraw		mm4,2
		packuswb	mm4,mm4
		movd		[edx+12],mm4

		ret
odd1:
		sub			ecx,4
		jnc			odd2

		movd		mm4,[eax+8+4]
		punpcklbw	mm4,mm7

		paddw		mm5,mm6
		paddw		mm5,mm4
		paddw		mm5,mm6
		paddw		mm5,mm3
		psraw		mm5,2
		packuswb	mm5,mm5
		movd		[edx+4+4],mm5

		;	mm4		pixel[-1]
		;	mm5
		;	mm6		pixel[-2]

		paddw		mm6,mm4
		paddw		mm6,mm4
		paddw		mm6,mm4
		paddw		mm6,mm3
		psraw		mm6,2
		packuswb	mm6,mm6
		movd		[edx+8+4],mm6
		ret
odd2:

		paddw		mm5,mm6
		paddw		mm5,mm6
		paddw		mm5,mm6
		paddw		mm5,mm3
		psraw		mm5,2
		packuswb	mm5,mm5
		movd		[edx+4+8],mm5

		ret
	}
}
#endif

static void dorow(Pixel32 *dst, Pixel32 *src, PixDim w) {
	if (w == 1) {
		*dst = *src;
		return;
	}

#ifdef _M_IX86
	if (MMX_enabled) {
		dorow_MMX(dst, src, w);
		return;
	}
#endif

	dst[0] = ((((src[0] & 0x00FF00FF)*3 + (src[1] & 0x00FF00FF) + 0x00020002)>>2) & 0x00FF00FF)
		   + ((((src[0] & 0x0000FF00)*3 + (src[1] & 0x0000FF00) + 0x00000200)>>2) & 0x0000FF00);

	++dst;

	w -= 2;
	if (w) {
		w = -w;
		src = src-w;
		dst = dst-w;
		do {
			Pixel32 s1, s2, s3;

			s1 = src[w+0];
			s2 = src[w+1];
			s3 = src[w+2];

			dst[w+0]= ((((s1&0xFF00FF) + 2*(s2&0xFF00FF) + (s3&0xFF00FF) + 0x020002)>>2) & 0xFF00FF)
					+ ((((s1&0x00FF00) + 2*(s2&0x00FF00) + (s3&0x00FF00) + 0x000200)>>2) & 0x00FF00);

		} while(++w);
	}

	dst[0] = ((((src[0] & 0x00FF00FF) + (src[1] & 0x00FF00FF)*3 + 0x00020002)>>2) & 0xFF00FF)
		   + ((((src[0] & 0x0000FF00) + (src[1] & 0x0000FF00)*3 + 0x00000200)>>2) & 0x00FF00);
}

#ifdef _M_IX86
static void __declspec(naked) docol_MMX(Pixel32 *dst, Pixel32 *src1, Pixel32 *src2, Pixel32 *src3, PixDim w) {
	__asm {
		push		ebp
		push		ebx

		mov			eax,[esp+8+8]
		mov			ebx,[esp+12+8]
		mov			ecx,[esp+16+8]
		mov			edx,[esp+4+8]
		pxor		mm7,mm7
		movq		mm6,mmx_offset2

		mov			ebp,[esp+20+8]
		shl			ebp,2
		neg			ebp

		sub			eax,ebp
		sub			ebx,ebp
		sub			ecx,ebp
		sub			edx,ebp

xloop:
		movd		mm0,[eax+ebp]
		movd		mm1,[ebx+ebp]
		movd		mm2,[ecx+ebp]
		punpcklbw	mm0,mm7
		punpcklbw	mm1,mm7
		punpcklbw	mm2,mm7
		paddw		mm0,mm2
		paddw		mm1,mm1
		paddw		mm0,mm6
		paddw		mm0,mm1
		psraw		mm0,2
		packuswb	mm0,mm0
		movd		[edx+ebp],mm0

		add			ebp,4
		jne			xloop

		pop			ebx
		pop			ebp
		ret
	}
}
#endif

static void docol(Pixel32 *dst, Pixel32 *row1, Pixel32 *row2, Pixel32 *row3, PixDim w) {
#ifdef _M_IX86
	if (MMX_enabled) {
		docol_MMX(dst, row1, row2, row3, w);
		return;
	}
#endif

	w = -w;
	row1 -= w;
	row2 -= w;
	row3 -= w;
	dst -= w;

	do {
		Pixel32 s1, s2, s3;

		s1 = row1[w];
		s2 = row2[w];
		s3 = row3[w];

		dst[w+0]= ((((s1&0xFF00FF) + 2*(s2&0xFF00FF) + (s3&0xFF00FF) + 0x020002)>>2) & 0xFF00FF)
				+ ((((s1&0x00FF00) + 2*(s2&0x00FF00) + (s3&0x00FF00) + 0x000200)>>2) & 0x00FF00);

	} while(++w);
}

void VEffectBlur::run(const VBitmap *vbm) {
	run(vbm, vbm);
}

void VEffectBlur::run(const VBitmap *vbmdst, const VBitmap *vbm) {
	Pixel32 *srcr = vbm->data;
	Pixel32 *dstr = vbmdst->data;
	PixDim h;
	int crow = 2;

	if (vbm->h == 1) {
		dorow(rows[0], srcr, vbm->w);
		memcpy(srcr, rows[0], sizeof(Pixel32)*vbm->w);
		return;
	} else if (vbm->h == 2) {
		dorow(rows[0], vbm->Address32(0, 0), vbm->w);
		dorow(rows[1], vbm->Address32(0, 1), vbm->w);
		docol(vbmdst->Address32(0,0), rows[0], rows[0], rows[1], vbm->w);
		docol(vbmdst->Address32(0,1), rows[1], rows[0], rows[0], vbm->w);
		return;

	}

	dorow(rows[0], srcr, vbm->w);
	memcpy(rows[1], rows[0], sizeof(Pixel32)*vbm->w);

	h = vbm->h;
	do {
		if (h>1)
			dorow(rows[crow], (Pixel32 *)((char *)srcr + vbm->pitch), vbm->w);
		else
			memcpy(rows[crow], rows[crow ? crow-1 : 2], vbm->w*sizeof(Pixel32));

		switch(crow) {
		case 0:	docol(dstr, rows[1], rows[2], rows[0], vbm->w); break;
		case 1:	docol(dstr, rows[2], rows[0], rows[1], vbm->w); break;
		case 2:	docol(dstr, rows[0], rows[1], rows[2], vbm->w); break;
		}

		if (++crow >= 3)
			crow = 0;

		srcr = (Pixel32 *)((char *)srcr + vbm->pitch);
		dstr = (Pixel32 *)((char *)dstr + vbmdst->pitch);
	} while(--h);

#ifdef _M_IX86
	if (MMX_enabled)
		__asm emms
#endif
}

///////////////////////////////////////////////////////////////////////////

class VEffectBlurHi : public VEffect {
public:
	VEffectBlurHi(const VBitmap *);
	~VEffectBlurHi();

	void run(const VBitmap *);
	void run(const VBitmap *, const VBitmap *);

private:
	Pixel32 *rows[5];

};

///////////////////////////////////////////////////////////////////////////

VEffect *VCreateEffectBlurHi(const VBitmap *vbm) {
	return new VEffectBlurHi(vbm);
}

VEffectBlurHi::VEffectBlurHi(const VBitmap *vbm) {
	int i;

	for(i=0; i<5; i++)
		if (!(rows[i] = new Pixel32[vbm->w])) {
			while(--i>=0)
				delete rows[i];

			throw MyMemoryError();
		}
}

VEffectBlurHi::~VEffectBlurHi() {
	int i;

	for(i=0; i<5; i++)
		delete rows[i];
}

#ifdef _M_IX86
static void __declspec(naked) dorow2_MMX(Pixel32 *dst, Pixel32 *src, PixDim w) {
	__asm {
		mov		eax,[esp+8]
		mov		edx,[esp+4]
		pxor	mm7,mm7

		;first pixel

		movd		mm2,[eax]
		movd		mm3,[eax+4]
		movd		mm4,[eax+8]
		punpcklbw	mm2,mm7
		punpcklbw	mm3,mm7
		punpcklbw	mm4,mm7

		movq		mm0,mm2
		movq		mm1,mm3
		pmullw		mm0,mmx_by11
		psllw		mm1,2
		paddw		mm1,mm4
		paddw		mm1,mmx_offset8
		paddw		mm0,mm1
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx],mm0

		movd		mm5,[eax+12]
		punpcklbw	mm5,mm7

		movq		mm0,mm2
		movq		mm1,mm3
		paddw		mm0,mm4
		pmullw		mm1,mmx_by6
		psllw		mm0,2
		paddw		mm0,mm2
		paddw		mm0,mm5
		paddw		mm0,mmx_offset8
		paddw		mm0,mm1
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+4],mm0

		;We stop when the counter overflows.  This is tricky, because we
		;have to make sure we write at least 4 border pixels.
		;
		;	 9 pixels:	w*-4=-36, ecx=-4,	end ecx=+16
		;	10 pixels:	w*-4=-40, ecx=-8,	end ecx=+12
		;	11 pixels:	w*-4=-44, ecx=-12,	end ecx=+8
		;	12 pixels:	w*-4=-48, ecx=-16,	end ecx=+4
		;	13 pixels:	w*-4=-52, ecx=-20,	end ecx=+0
		;	14 pixels:	w*-4=-56, ecx=-24,	end ecx=+16

		mov			ecx,[esp+12]
		shl			ecx,2
		neg			ecx
		add			ecx,32

		sub			eax,ecx
		sub			edx,ecx

		;	mm2		pixel[-2]
		;	mm3		pixel[-1]
		;	mm4		pixel[ 0]
		;	mm5		pixel[+1]
		;	mm6		pixel[+2]	(to be loaded)
		;	mm7		zero

xloop:
		movd		mm6,[eax+ecx+16]
		movq		mm1,mm4
		pmullw		mm1,mmx_by6
		punpcklbw	mm6,mm7
		movq		mm0,mm3
		paddw		mm2,mm6
		paddw		mm2,mmx_offset8
		paddw		mm0,mm5
		paddw		mm2,mm1
		psllw		mm0,2
		paddw		mm0,mm2
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+8],mm0

		;	mm2		pixel[+2]	(to be loaded)
		;	mm3		pixel[-2]
		;	mm4		pixel[-1]
		;	mm5		pixel[ 0]
		;	mm6		pixel[+1]
		;	mm7		zero

		movd		mm2,[eax+ecx+20]
		movq		mm1,mm5
		pmullw		mm1,mmx_by6
		punpcklbw	mm2,mm7
		movq		mm0,mm4
		paddw		mm3,mm2
		paddw		mm3,mmx_offset8
		paddw		mm0,mm6
		paddw		mm3,mm1
		psllw		mm0,2
		paddw		mm0,mm3
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+12],mm0

		;	mm2		pixel[+1]
		;	mm3		pixel[+2]	(to be loaded)
		;	mm4		pixel[-2]
		;	mm5		pixel[-1]
		;	mm6		pixel[ 0]
		;	mm7		zero

		movd		mm3,[eax+ecx+24]
		movq		mm1,mm6
		pmullw		mm1,mmx_by6
		punpcklbw	mm3,mm7
		movq		mm0,mm5
		paddw		mm4,mm3
		paddw		mm4,mmx_offset8
		paddw		mm0,mm2
		paddw		mm4,mm1
		psllw		mm0,2
		paddw		mm0,mm4
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+16],mm0

		;	mm2		pixel[ 0]
		;	mm3		pixel[+1]
		;	mm4		pixel[+2]	(to be loaded)
		;	mm5		pixel[-2]
		;	mm6		pixel[-1]
		;	mm7		zero

		movd		mm4,[eax+ecx+28]
		movq		mm1,mm2
		pmullw		mm1,mmx_by6
		punpcklbw	mm4,mm7
		movq		mm0,mm6
		paddw		mm5,mm4
		paddw		mm5,mmx_offset8
		paddw		mm0,mm3
		paddw		mm5,mm1
		psllw		mm0,2
		paddw		mm0,mm5
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+20],mm0

		;	mm2		pixel[-1]
		;	mm3		pixel[ 0]
		;	mm4		pixel[+1]
		;	mm5		pixel[+2]	(to be loaded)
		;	mm6		pixel[-2]
		;	mm7		zero

		movd		mm5,[eax+ecx+32]
		movq		mm1,mm3
		pmullw		mm1,mmx_by6
		punpcklbw	mm5,mm7
		movq		mm0,mm2
		paddw		mm6,mm5
		paddw		mm6,mmx_offset8
		paddw		mm0,mm4
		paddw		mm6,mm1
		psllw		mm0,2
		paddw		mm0,mm6
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+24],mm0

		add			ecx,20
		jnc			xloop

		;last pixel
		;
		;	mm2		pixel[-2]
		;	mm3		pixel[-1]
		;	mm4		pixel[ 0]
		;	mm5		pixel[+1]
		;	mm6		pixel[+2]	(to be loaded)
		;	mm7		zero
		;

oddloop:
		cmp			ecx,16
		jz			last2

		movq		mm6,mm2
		movq		mm2,mm3
		movq		mm3,mm4
		movq		mm4,mm5
		movd		mm5,[eax+ecx+16]
		movq		mm1,mm3
		pmullw		mm1,mmx_by6
		punpcklbw	mm5,mm7
		movq		mm0,mm2
		paddw		mm6,mm5
		paddw		mm6,mmx_offset8
		paddw		mm0,mm4
		paddw		mm6,mm1
		psllw		mm0,2
		paddw		mm0,mm6
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+ecx+8],mm0

		add			ecx,4
		jmp			short oddloop

		;	mm2		pixel[-2]
		;	mm3		pixel[-1]
		;	mm4		pixel[ 0]
		;	mm5		pixel[+1]
		;	mm7		zero
last2:
		movq		mm0,mm3
		movq		mm1,mm3
		pmullw		mm0,mmx_by6
		paddw		mm1,mm5
		paddw		mm2,mmx_offset8
		psllw		mm1,2
		paddw		mm1,mm5
		paddw		mm0,mm2
		paddw		mm0,mm1
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edx+16+8],mm0

		;	mm3		pixel[-2]
		;	mm4		pixel[-1]
		;	mm5		pixel[ 0]
		;	mm7		zero

		pmullw		mm5,mmx_by11
		psllw		mm4,2
		paddw		mm4,mm3
		paddw		mm4,mmx_offset8
		paddw		mm4,mm5
		psraw		mm4,4
		packuswb	mm4,mm4
		movd		[edx+20+8],mm0

		ret
	}
}
#endif

static void dorow2(Pixel32 *dst, Pixel32 *src, PixDim w) {
	if (w < 4) {
		dorow(dst, src, w);
		return;
	}

#ifdef _M_IX86
	if (MMX_enabled) {
		dorow2_MMX(dst, src, w);
		return;
	}
#endif

	dst[0] = ((((src[0] & 0x00FF00FF)*11 + (src[1] & 0x00FF00FF)*4 + (src[2] & 0x00FF00FF) + 0x00080008)>>4) & 0x00FF00FF)
		   + ((((src[0] & 0x0000FF00)*11 + (src[1] & 0x0000FF00)*4 + (src[2] & 0x0000FF00) + 0x00000800)>>4) & 0x0000FF00);

	dst[1] = ((((src[0] & 0x00FF00FF)*5 + (src[1] & 0x00FF00FF)*6 + (src[2] & 0x00FF00FF)*4 + (src[3] & 0x00FF00FF) + 0x00080008)>>4) & 0x00FF00FF)
		   + ((((src[0] & 0x0000FF00)*5 + (src[1] & 0x0000FF00)*6 + (src[2] & 0x0000FF00)*4 + (src[3] & 0x0000FF00) + 0x00000800)>>4) & 0x0000FF00);

	dst += 2;

	w -= 4;
	if (w) {
		w = -w;
		src = src-w;
		dst = dst-w;
		do {
			Pixel32 s1, s2, s3, s4, s5;

			s1 = src[w+0];
			s2 = src[w+1];
			s3 = src[w+2];
			s4 = src[w+3];
			s5 = src[w+4];

			dst[w+0]= ((((s1&0xFF00FF) + 4*(s2&0xFF00FF) + 6*(s3&0xFF00FF) + 4*(s4&0xFF00FF) + (s5&0xFF00FF) + 0x080008)>>4) & 0xFF00FF)
					+ ((((s1&0x00FF00) + 4*(s2&0x00FF00) + 6*(s3&0x00FF00) + 4*(s4&0x00FF00) + (s5&0x00FF00) + 0x000800)>>4) & 0x00FF00);

		} while(++w);
	}

	dst[0] = ((((src[0] & 0x00FF00FF) + (src[1] & 0x00FF00FF)*4 + (src[2] & 0x00FF00FF)*6 + (src[3] & 0x00FF00FF)*5 + 0x00080008)>>4) & 0x00FF00FF)
		   + ((((src[0] & 0x0000FF00) + (src[1] & 0x0000FF00)*4 + (src[2] & 0x0000FF00)*6 + (src[3] & 0x0000FF00)*5 + 0x00000800)>>4) & 0x0000FF00);

	dst[1] = ((((src[0] & 0x00FF00FF) + (src[1] & 0x00FF00FF)*4 + (src[2] & 0x00FF00FF)*11 + 0x00080008)>>4) & 0x00FF00FF)
		   + ((((src[0] & 0x0000FF00) + (src[1] & 0x0000FF00)*4 + (src[2] & 0x0000FF00)*11 + 0x00000800)>>4) & 0x0000FF00);
}

#ifdef _M_IX86
static void __declspec(naked) docol2_MMX(Pixel32 *dst, Pixel32 *src1, Pixel32 *src2, Pixel32 *src3, Pixel32 *src4, Pixel32 *src5, PixDim w) {
	__asm {
		push		ebp
		push		edi
		push		esi
		push		ebx

		mov			eax,[esp+8+16]
		mov			ebx,[esp+12+16]
		mov			ecx,[esp+16+16]
		mov			edx,[esp+20+16]
		mov			esi,[esp+24+16]
		mov			edi,[esp+4+16]
		pxor		mm7,mm7
		movq		mm6,mmx_offset8

		mov			ebp,[esp+28+16]
		shl			ebp,2
		neg			ebp

		sub			eax,ebp
		sub			ebx,ebp
		sub			ecx,ebp
		sub			edx,ebp
		sub			esi,ebp
		sub			edi,ebp

xloop:
		movd		mm0,[eax+ebp]
		movd		mm1,[ebx+ebp]
		movd		mm2,[ecx+ebp]
		movd		mm3,[edx+ebp]
		movd		mm4,[esi+ebp]
		punpcklbw	mm0,mm7
		punpcklbw	mm1,mm7
		punpcklbw	mm2,mm7
		punpcklbw	mm3,mm7
		punpcklbw	mm4,mm7
		paddw		mm0,mm4
		paddw		mm1,mm3
		psllw		mm1,2
		movq		mm5,mm2
		paddw		mm2,mm2
		paddw		mm2,mm5
		paddw		mm2,mm2
		paddw		mm0,mm1
		paddw		mm0,mm2
		paddw		mm0,mm6
		psraw		mm0,4
		packuswb	mm0,mm0
		movd		[edi+ebp],mm0

		add			ebp,4
		jne			xloop

		pop			ebx
		pop			esi
		pop			edi
		pop			ebp
		ret
	}
}
#endif

static void docol2(Pixel32 *dst, Pixel32 *row1, Pixel32 *row2, Pixel32 *row3, Pixel32 *row4, Pixel32 *row5, PixDim w) {
#ifdef _M_IX86
	if (MMX_enabled) {
		docol2_MMX(dst, row1, row2, row3, row4, row5, w);
		return;
	}
#endif

	w = -w;
	row1 -= w;
	row2 -= w;
	row3 -= w;
	row4 -= w;
	row5 -= w;
	dst -= w;

	do {
		Pixel32 s1, s2, s3, s4, s5;

		s1 = row1[w];
		s2 = row2[w];
		s3 = row3[w];
		s4 = row4[w];
		s5 = row5[w];

		dst[w+0]= ((((s1&0xFF00FF) + 4*(s2&0xFF00FF) + 6*(s3&0xFF00FF) + 4*(s4&0xFF00FF) + (s5&0xFF00FF) + 0x080008)>>4) & 0xFF00FF)
				+ ((((s1&0x00FF00) + 4*(s2&0x00FF00) + 6*(s3&0x00FF00) + 4*(s4&0x00FF00) + (s5&0x00FF00) + 0x000800)>>4) & 0x00FF00);

	} while(++w);
}

void VEffectBlurHi::run(const VBitmap *vbm) {
	run(vbm, vbm);
}

void VEffectBlurHi::run(const VBitmap *vbmdst, const VBitmap *vbm) {
	Pixel32 *srcr = vbm->data;
	Pixel32 *dstr = vbmdst->data;
	PixDim h;
	int crow = 4;

	if (vbm->h == 1) {
		dorow(rows[0], srcr, vbm->w);
		memcpy(srcr, rows[0], sizeof(Pixel32)*vbm->w);
		return;
	} else if (vbm->h == 2) {
		dorow(rows[0], vbm->Address32(0, 0), vbm->w);
		dorow(rows[1], vbm->Address32(0, 1), vbm->w);
		docol(vbm->Address32(0,0), rows[0], rows[0], rows[1], vbm->w);
		docol(vbm->Address32(0,1), rows[1], rows[0], rows[0], vbm->w);
		return;

	}

	dorow2(rows[0], srcr, vbm->w);
	memcpy(rows[1], rows[0], sizeof(Pixel32)*vbm->w);
	memcpy(rows[2], rows[0], sizeof(Pixel32)*vbm->w);
	dorow2(rows[3], (Pixel32 *)((char *)srcr + vbm->pitch), vbm->w);

	h = vbm->h;
	do {
		if (h>2)
			dorow2(rows[crow], (Pixel32 *)((char *)srcr + vbm->pitch*2), vbm->w);
		else
			memcpy(rows[crow], rows[crow ? crow-1 : 4], vbm->w*sizeof(Pixel32));

		switch(crow) {
		case 0:	docol2(dstr, rows[1], rows[2], rows[3], rows[4], rows[0], vbm->w); break;
		case 1:	docol2(dstr, rows[2], rows[3], rows[4], rows[0], rows[1], vbm->w); break;
		case 2:	docol2(dstr, rows[3], rows[4], rows[0], rows[1], rows[2], vbm->w); break;
		case 3:	docol2(dstr, rows[4], rows[0], rows[1], rows[2], rows[3], vbm->w); break;
		case 4:	docol2(dstr, rows[0], rows[1], rows[2], rows[3], rows[4], vbm->w); break;
		}

		if (++crow >= 5)
			crow = 0;

		srcr = (Pixel32 *)((char *)srcr + vbm->pitch);
		dstr = (Pixel32 *)((char *)dstr + vbmdst->pitch);
	} while(--h);

#ifdef _M_IX86
	if (MMX_enabled)
		__asm emms
#endif
}
