//	VirtualDub - Video processing and capture application
//	Audio processing library
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

#include <vd2/system/cpuaccel.h>
#include <vd2/Priss/convert.h>

///////////////////////////////////////////////////////////////////////////
//
//	scalar implementations
//
///////////////////////////////////////////////////////////////////////////

void VDAPIENTRY VDConvertPCM32FToPCM8(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	uint8 *dst = (uint8 *)dst0;
	const float *src = (const float *)src0;

	do {
		const float ftmp = 98304.0f + *src++;
		sint32 v = reinterpret_cast<const sint32&>(ftmp) - 0x47bfff80;

		if ((uint32)v >= 256)
			v = (~v) >> 31;

		*dst++ = (uint8)v;
	} while(--samples);
}

void VDAPIENTRY VDConvertPCM32FToPCM16(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	sint16 *dst = (sint16 *)dst0;
	const float *src = (const float *)src0;

	do {
		const float ftmp = 384.0f + *src++;
		sint32 v = reinterpret_cast<const sint32&>(ftmp) - 0x43bf8000;

		if ((uint32)v >= 0x10000)
			v = (~v) >> 31;

		*dst++ = (sint16)(v - 0x8000);
	} while(--samples);
}

void VDAPIENTRY VDConvertPCM16ToPCM8(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	uint8 *dst = (uint8 *)dst0;
	const sint16 *src = (const sint16 *)src0;

	do {
		*dst++ = (uint8)((*src++ >> 8)^0x80);
	} while(--samples);
}

void VDAPIENTRY VDConvertPCM16ToPCM32F(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	float *dst = (float *)dst0;
	const sint16 *src = (const sint16 *)src0;

	do {
		*dst++ = (float)*src++ * (1.0f / 32768.0f);
	} while(--samples);
}

void VDAPIENTRY VDConvertPCM8ToPCM16(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	sint16 *dst = (sint16 *)dst0;
	const uint8 *src = (const uint8 *)src0;

	do {
		*dst++ = (sint16)(((int)*src++ - 0x80) << 8);
	} while(--samples);
}

void VDAPIENTRY VDConvertPCM8ToPCM32F(void *dst0, const void *src0, uint32 samples) {
	if (!samples)
		return;

	float *dst = (float *)dst0;
	const uint8 *src = (const uint8 *)src0;

	do {
		*dst++ = (float)((int)*src++ - 0x80) * (1.0f / 128.0f);
	} while(--samples);
}

sint16 VDAPIENTRY VDAudioFilterPCM16(const sint16 *src, const sint16 *filter, uint32 filterquadsize) {
	sint32 v = 0x2000;

	for(int j=0; j<filterquadsize*4; j+=4) {
		v += (sint32)filter[j  ] * (sint32)src[j  ];
		v += (sint32)filter[j+1] * (sint32)src[j+1];
		v += (sint32)filter[j+2] * (sint32)src[j+2];
		v += (sint32)filter[j+3] * (sint32)src[j+3];
	}

	v = (v>>14) + 0x8000;

	if ((uint32)v >= 0x10000)
		v = ~v >> 31;

	return (sint16)(v - 0x8000);
}

void VDAPIENTRY VDAudioFilterPCM16End() {
}

void VDAPIENTRY VDAudioFilterPCM16SymmetricArray(sint16 *dst, ptrdiff_t dst_stride, const sint16 *src, uint32 count, const sint16 *filter, uint32 filterquadsizeminus1) {
	filter += filterquadsizeminus1*4;
	src += filterquadsizeminus1*4;

	for(int i=0; i<count; ++i) {
		sint32 v = 0x2000 + (sint32)filter[0] * src[i];

		for(int j=1; j<=filterquadsizeminus1*4; j+=4) {
			int k = -j;
			v += (sint32)filter[j  ] * ((sint32)src[i+j  ] + (sint32)src[i+k  ]);
			v += (sint32)filter[j+1] * ((sint32)src[i+j+1] + (sint32)src[i+k-1]);
			v += (sint32)filter[j+2] * ((sint32)src[i+j+2] + (sint32)src[i+k-2]);
			v += (sint32)filter[j+3] * ((sint32)src[i+j+3] + (sint32)src[i+k-3]);
		}

		v = (v>>14) + 0x8000;

		if ((uint32)v >= 0x10000)
			v = ~v >> 31;

		*dst = (sint16)(v - 0x8000);
		dst += dst_stride;
	}
}


#ifdef _M_IX86

///////////////////////////////////////////////////////////////////////////
//
//	MMX implementations
//
///////////////////////////////////////////////////////////////////////////

#ifdef _MSC_VER
	#pragma warning(disable: 4799)		// warning C4799: function has no MMX instruction
#endif

namespace {
	const __int64 x80b = 0x8080808080808080;
}

void __declspec(naked) VDAPIENTRY VDConvertPCM16ToPCM8_MMX(void *dst0, const void *src0, uint32 samples) {

	__asm {
		mov			eax, [esp+12]
		mov			ecx, [esp+8]
		mov			edx, [esp+4]
		or			eax, eax
		jz			xit

		movq		mm7, x80b
		neg			eax
		add			eax, 7
		jc			nodq

		;process quads (8n samples)
dqloop:
		movq		mm0, [ecx]
		movq		mm1, [ecx+8]
		psrlw		mm0, 8
		add			edx, 8
		psrlw		mm1, 8
		add			ecx, 16
		packuswb	mm0, mm1
		pxor		mm0, mm7
		add			eax, 8
		movq		[edx-8], mm0
		ja			dqloop
nodq:
		cmp			eax, 3
		jg			noq
		add			eax, 4

		;process leftover quad (4 samples)
		movq		mm0, [ecx]
		add			edx, 4
		psrlw		mm0, 8
		packuswb	mm0, mm0
		add			ecx, 8
		pxor		mm0, mm7
		movd		[edx-4], mm0
noq:
		sub			eax, 7
		jz			xit2

		;process leftover samples
		movd		mm0, ebx
singleloop:
		mov			bl, byte ptr [ecx+1]
		add			ecx, 2
		xor			bl, 80h
		mov			byte ptr [edx], bl
		inc			edx
		inc			eax
		jne			singleloop
		movd		ebx, mm0
xit2:
		emms
xit:
		ret
	}
}

void __declspec(naked) VDAPIENTRY VDConvertPCM8ToPCM16_MMX(void *dst0, const void *src0, uint32 samples) {
	__asm {
		mov		eax, [esp+12]
		mov		ecx, [esp+8]
		mov		edx, [esp+4]
		or		eax, eax
		jz		xit

		movq		mm7, x80b
		neg			eax
		movq		mm0, mm7
		add			eax, 7
		jc			nodq

		;process quads (8n samples)
dqloop:
		pxor		mm0, [ecx]
		pxor		mm1, mm1
		add			edx, 16
		punpcklbw	mm1, mm0
		add			ecx, 8
		pxor		mm2, mm2
		punpckhbw	mm2, mm0
		add			eax, 8
		movq		[edx-16], mm1
		movq		mm0, mm7
		movq		[edx-8], mm2
		ja			dqloop
nodq:
		cmp			eax, 3
		jg			noq
		add			eax, 4

		;process leftover quad (4 samples)
		movd		mm0, [ecx]
		pxor		mm1, mm1
		pxor		mm0, mm7
		add			edx, 8
		punpcklbw	mm1, mm0
		add			ecx, 4
		movq		[edx-8], mm1
noq:
		sub			eax, 7
		jz			xit2

		;process leftover samples
		movd		mm0, ebx
singleloop:
		movzx		ebx, byte ptr [ecx]
		add			edx, 2
		shl			ebx, 8
		inc			ecx
		xor			ebx, 8000h
		inc			eax
		mov			word ptr [edx-2], bx
		jne			singleloop
		movd		ebx, mm0
xit2:
		emms
xit:
		ret
	}
}


sint16 __declspec(naked) VDAPIENTRY VDAudioFilterPCM16_MMX(const sint16 *src, const sint16 *filter, uint32 filterquadsize) {
	static const uint64 roundconst = 0x0000200000002000;

	__asm {
		mov		eax,[esp+12]
		mov		ecx,[esp+4]
		shl		eax,3
		mov		edx,[esp+8]
		movq	mm0,roundconst
		add		ecx, eax
		add		edx, eax
		neg		eax
xloop:
		movq	mm1,[ecx+eax]
		pmaddwd	mm1,[edx+eax]
		add		eax,8
		paddd	mm0,mm1
		jne		xloop

		punpckldq	mm1,mm0
		paddd		mm0,mm1
		psrad		mm0,14
		packssdw	mm0,mm0
		psrlq		mm0,48
		movd	eax, mm0
		ret
	}
}

void VDAPIENTRY VDAudioFilterPCM16End_MMX() {
	__asm emms
}

void __declspec(naked) VDAPIENTRY VDAudioFilterPCM16SymmetricArray_MMX(sint16 *dst, ptrdiff_t dst_stride, const sint16 *src_center, uint32 count, const sint16 *filter, uint32 filterquadsizeminus1) {
	static const uint64 roundconst = 0x0000200000002000;

	__asm {
		push		ebp
		push		edi
		push		esi
		push		ebx
		mov			ebx,[esp+24+16]
		mov			ecx,[esp+12+16]
		shl			ebx,4
		mov			edx,[esp+20+16]
		lea			ecx, [ecx+ebx+8]
		lea			edx, [edx+ebx+8]
		neg			ebx
		mov			esi, [esp+16+16]
		mov			edi, [esp+4+16]
		mov			ebp, [esp+8+16]
		add			ebp, ebp
yloop:
		mov			eax, ebx
		movq		mm0,roundconst
		movq		mm1,[ecx+eax-8]
		pmaddwd		mm1,[edx+eax-8]
xloop:
		movq		mm2, [ecx+eax]
		movq		mm3, [ecx+eax+8]
		pmaddwd		mm2, [edx+eax]
		pmaddwd		mm3, [edx+eax+8]
		add			eax, 16
		paddd		mm0, mm2
		paddd		mm1, mm3
		jne			xloop

		paddd		mm0, mm1
		add			ecx, 2
		punpckldq	mm1, mm0
		paddd		mm0, mm1
		psrad		mm0, 14
		packssdw	mm0, mm0
		psrlq		mm0, 48
		movd		eax, mm0
		mov			word ptr [edi], ax
		add			edi, ebp
		dec			esi
		jne			yloop
		emms
		pop			ebx
		pop			esi
		pop			edi
		pop			ebp
		ret
	}
}

///////////////////////////////////////////////////////////////////////////
//
//	SSE implementations
//
///////////////////////////////////////////////////////////////////////////

static const float __declspec(align(16)) sse_32K[4]={32768.0f, 32768.0f, 32768.0f, 32768.0f};
static const float __declspec(align(16)) sse_128[4]={128.0f, 128.0f, 128.0f, 128.0f};
static const float __declspec(align(16)) sse_inv_32K[4]={1.0f/32768.0f, 1.0f/32768.0f, 1.0f/32768.0f, 1.0f/32768.0f};
static const float __declspec(align(16)) sse_inv_128[4]={1.0f/128.0f, 1.0f/128.0f, 1.0f/128.0f, 1.0f/128.0f};

void __declspec(naked) VDAPIENTRY VDConvertPCM32FToPCM16_SSE(void *dst, const void *src, uint32 samples) {
	__asm {
		push		ebx
		mov			edx, [esp+4+4]
		mov			ecx, [esp+8+4]
		movaps		xmm1, sse_32K
		mov			ebx, [esp+12+4]

		neg			ebx
		jz			xit

		test		ecx, 15
		jz			majorloopstart
prealignloop:
		movss		xmm0, [ecx]
		add			ecx, 4
		mulss		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		packssdw	mm0, mm0
		movd		eax, mm0
		mov			word ptr [edx], ax
		add			edx, 2
		inc			ebx
		jz			xit
		test		ecx, 15
		jnz			prealignloop

majorloopstart:
		add			ebx, 3
		jc			postloopstart

majorloop:
		movaps		xmm0, [ecx]
		add			ecx, 16
		mulps		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		movhlps		xmm0, xmm0
		cvtps2pi	mm1, xmm0
		packssdw	mm0, mm1
		movq		[edx], mm0
		add			edx, 8
		add			ebx, 4
		jnc			majorloop

postloopstart:
		sub			ebx, 3
		jz			xit
postloop:
		movss		xmm0, [ecx]
		add			ecx, 4
		mulss		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		packssdw	mm0, mm0
		movd		eax, mm0
		mov			word ptr [edx], ax
		add			edx, 2
		inc			ebx
		jnz			postloop

xit:
		emms
		pop			ebx
		ret
	}
}

void __declspec(naked) VDAPIENTRY VDConvertPCM32FToPCM8_SSE(void *dst, const void *src, uint32 samples) {
	__asm {
		push		ebx
		mov			edx, [esp+4+4]
		mov			ecx, [esp+8+4]
		movaps		xmm1, sse_128
		mov			ebx, [esp+12+4]

		neg			ebx
		jz			xit

		test		ecx, 15
		jz			majorloopstart
prealignloop:
		movss		xmm0, [ecx]
		add			ecx, 4
		mulss		xmm0, xmm1
		addss		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		packssdw	mm0, mm0
		packuswb	mm0, mm0
		movd		eax, mm0
		mov			byte ptr [edx], al
		inc			edx
		inc			ebx
		jz			xit
		test		ecx, 15
		jnz			prealignloop

majorloopstart:
		add			ebx, 3
		jc			postloopstart

majorloop:
		movaps		xmm0, [ecx]
		add			ecx, 16
		mulps		xmm0, xmm1
		addps		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		movhlps		xmm0, xmm0
		cvtps2pi	mm1, xmm0
		packssdw	mm0, mm1
		packuswb	mm0, mm0
		movd		[edx], mm0
		add			edx, 4
		add			ebx, 4
		jnc			majorloop

postloopstart:
		sub			ebx, 3
		jz			xit
postloop:
		movss		xmm0, [ecx]
		add			ecx, 4
		mulss		xmm0, xmm1
		addss		xmm0, xmm1
		cvtps2pi	mm0, xmm0
		packssdw	mm0, mm0
		packuswb	mm0, mm0
		movd		eax, mm0
		mov			byte ptr [edx], al
		inc			edx
		inc			ebx
		jnz			postloop

xit:
		emms
		pop			ebx
		ret
	}
}

void __declspec(naked) VDAPIENTRY VDConvertPCM16ToPCM32F_SSE(void *dst, const void *src, uint32 samples) {
	__asm {
		movaps		xmm1, sse_inv_32K
		push		ebx
		mov			eax, [esp+12+4]
		neg			eax
		jz			xit
		mov			ecx, [esp+8+4]
		add			eax, eax
		mov			edx, [esp+4+4]
		sub			ecx, eax
lup:
		movsx		ebx, word ptr [ecx+eax]
		cvtsi2ss	xmm0, ebx
		mulss		xmm0, xmm1
		movss		[edx],xmm0
		add			edx, 4
		add			eax, 2
		jne			lup
xit:
		pop			ebx
		ret
	}
}

void __declspec(naked) VDAPIENTRY VDConvertPCM8ToPCM32F_SSE(void *dst, const void *src, uint32 samples) {
	__asm {
		movaps		xmm1, sse_inv_128
		push		ebx
		mov			eax, [esp+12+4]
		neg			eax
		jz			xit
		mov			ecx, [esp+8+4]
		mov			edx, [esp+4+4]
		sub			ecx, eax
lup:
		movzx		ebx, byte ptr [ecx+eax]
		sub			ebx, 80h
		cvtsi2ss	xmm0, ebx
		mulss		xmm0, xmm1
		movss		[edx],xmm0
		add			edx, 4
		inc			eax
		jne			lup
xit:
		pop			ebx
		ret
	}
}
#endif

///////////////////////////////////////////////////////////////////////////
//
//	vtables
//
///////////////////////////////////////////////////////////////////////////

static const tpVDConvertPCM g_VDConvertPCMTable_scalar[3][3]={
	{	0,							VDConvertPCM8ToPCM16,			VDConvertPCM8ToPCM32F		},
	{	VDConvertPCM16ToPCM8,		0,								VDConvertPCM16ToPCM32F		},
	{	VDConvertPCM32FToPCM8,		VDConvertPCM32FToPCM16,			0							},
};

#ifdef _M_IX86
static const tpVDConvertPCM g_VDConvertPCMTable_MMX[3][3]={
	{	0,							VDConvertPCM8ToPCM16_MMX,		VDConvertPCM8ToPCM32F		},
	{	VDConvertPCM16ToPCM8_MMX,	0,								VDConvertPCM16ToPCM32F		},
	{	VDConvertPCM32FToPCM8,		VDConvertPCM32FToPCM16,			0							},
};

static const tpVDConvertPCM g_VDConvertPCMTable_SSE[3][3]={
	{	0,							VDConvertPCM8ToPCM16_MMX,		VDConvertPCM8ToPCM32F_SSE	},
	{	VDConvertPCM16ToPCM8_MMX,	0,								VDConvertPCM16ToPCM32F_SSE	},
	{	VDConvertPCM32FToPCM8_SSE,	VDConvertPCM32FToPCM16_SSE,		0							},
};
#endif

tpVDConvertPCMVtbl VDGetPCMConversionVtable() {
#ifdef _M_IX86
	uint32 exts = CPUGetEnabledExtensions();

	if (exts & CPUF_SUPPORTS_MMX) {
		if (exts & CPUF_SUPPORTS_SSE)
			return g_VDConvertPCMTable_SSE;
		else
			return g_VDConvertPCMTable_MMX;
	}
#endif
	return g_VDConvertPCMTable_scalar;
}

static const VDAudioFilterVtable g_VDAudioFilterVtable_scalar = {
	VDAudioFilterPCM16,
	VDAudioFilterPCM16End,
	VDAudioFilterPCM16SymmetricArray
};

#ifdef _M_IX86
static const VDAudioFilterVtable g_VDAudioFilterVtable_MMX = {
	VDAudioFilterPCM16_MMX,
	VDAudioFilterPCM16End_MMX,
	VDAudioFilterPCM16SymmetricArray_MMX
};
#endif

const VDAudioFilterVtable *VDGetAudioFilterVtable() {
#ifdef _M_IX86
	uint32 exts = CPUGetEnabledExtensions();

	if (exts & CPUF_SUPPORTS_MMX)
		return &g_VDAudioFilterVtable_MMX;
#endif

	return &g_VDAudioFilterVtable_scalar;
}

///////////////////////////////////////////////////////////////////////////
//
//	testing code
//
///////////////////////////////////////////////////////////////////////////

#if 0 && defined(_DEBUG)

#include <stdlib.h>
#include <string.h>

namespace {
	struct Test {
		Test() {
			testint(VDConvertPCM8ToPCM16, VDConvertPCM8ToPCM16_MMX);
			testint(VDConvertPCM16ToPCM8, VDConvertPCM16ToPCM8_MMX);
			testfp1(VDConvertPCM32FToPCM16, VDConvertPCM32FToPCM16_SSE);
			testfp1(VDConvertPCM32FToPCM8, VDConvertPCM32FToPCM8_SSE);
			testfp2(VDConvertPCM16ToPCM32F, VDConvertPCM16ToPCM32F_SSE);
			testfp2(VDConvertPCM8ToPCM32F, VDConvertPCM8ToPCM32F_SSE);
		}

		void testint(tpVDConvertPCM fnScalar, tpVDConvertPCM fnMMX) {
			char buf1[256];
			char buf2[256];
			char buf3[256];
			int i;

			for(i=0; i<256; ++i)
				buf1[i] = rand();

			for(i=0; i<64; ++i) {
				memcpy(buf2, buf1, sizeof buf2);
				memcpy(buf3, buf1, sizeof buf3);

				fnScalar(buf2+16, buf1+16, i);
				fnMMX   (buf3+16, buf1+16, i);

				for(int j=0; j<256; ++j)
					VDASSERT(buf2[j] == buf3[j]);
			}
		}

		void testfp1(tpVDConvertPCM fnScalar, tpVDConvertPCM fnSSE) {
			float __declspec(align(16)) buf1[64];
			char buf2[256];
			char buf3[256];
			int i;

			for(i=0; i<64; ++i)
				buf1[i] = (((double)rand() / RAND_MAX) - 0.5) * 2.2;

			for(int o=0; o<4; ++o) {
				for(i=0; i<32; ++i) {
					memcpy(buf2, buf1, sizeof buf2);
					memcpy(buf3, buf1, sizeof buf3);

					fnScalar(buf2+4, buf1+4+o, i);
					fnSSE   (buf3+4, buf1+4+o, i);

					for(int j=0; j<256; ++j)
						VDASSERT(buf2[j] == buf3[j]);
				}
			}
		}

		void testfp2(tpVDConvertPCM fnScalar, tpVDConvertPCM fnSSE) {
			char buf1[256];
			float buf2[64];
			float buf3[64];
			int i;

			for(i=0; i<256; ++i)
				buf1[i] = rand();

			for(i=0; i<32; ++i) {
				memcpy(buf2, buf1, sizeof buf2);
				memcpy(buf3, buf1, sizeof buf3);

				fnScalar(buf2+4, buf1+4, i);
				fnSSE   (buf3+4, buf1+4, i);

				for(int j=0; j<64; ++j)
					VDASSERT(buf2[j] == buf3[j]);
			}
		}
	} g_audioConverterTests;
}

#endif
