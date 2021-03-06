//	VirtualDub - Video processing and capture application
//	System library component
//	Copyright (C) 1998-2004 Avery Lee, All Rights Reserved.
//
//	Beginning with 1.6.0, the VirtualDub system library is licensed
//	differently than the remainder of VirtualDub.  This particular file is
//	thus licensed as follows (the "zlib" license):
//
//	This software is provided 'as-is', without any express or implied
//	warranty.  In no event will the authors be held liable for any
//	damages arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	1.	The origin of this software must not be misrepresented; you must
//		not claim that you wrote the original software. If you use this
//		software in a product, an acknowledgment in the product
//		documentation would be appreciated but is not required.
//	2.	Altered source versions must be plainly marked as such, and must
//		not be misrepresented as being the original software.
//	3.	This notice may not be removed or altered from any source
//		distribution.

#include <malloc.h>
#include <windows.h>
#include <vd2/system/atomic.h>
#include <vd2/system/memory.h>
#include <vd2/system/cpuaccel.h>

void *VDAlignedMalloc(size_t n, unsigned alignment) {
	return _aligned_malloc(n, alignment);
}

void VDAlignedFree(void *p) {
	_aligned_free(p);
}

void VDSwapMemory(void *p0, void *p1, unsigned bytes) {
	long *dst0 = (long *)p0;
	long *dst1 = (long *)p1;

	while(bytes >= 4) {
		long a = *dst0;
		long b = *dst1;

		*dst0++ = b;
		*dst1++ = a;

		bytes -= 4;
	}

	char *dstb0 = (char *)dst0;
	char *dstb1 = (char *)dst1;

	while(bytes--) {
		char a = *dstb0;
		char b = *dstb1;

		*dstb0++ = b;
		*dstb1++ = a;
	}
}

void VDInvertMemory(void *p, unsigned bytes) {
	char *dst = (char *)p;

	if (!bytes)
		return;

	while((int)dst & 3) {
		*dst = ~*dst;
		++dst;

		if (!--bytes)
			return;
	}

	unsigned lcount = bytes >> 2;

	if (lcount)
		do {
			*(long *)dst = ~*(long *)dst;
			dst += 4;
		} while(--lcount);

	bytes &= 3;

	while(bytes--) {
		*dst = ~*dst;
		++dst;
	}
}

namespace {
	uintptr VDGetSystemPageSizeW32() {
		SYSTEM_INFO sysInfo;
		GetSystemInfo(&sysInfo);

		return sysInfo.dwPageSize;
	}

	uintptr VDGetSystemPageSize() {
		static uintptr pageSize = VDGetSystemPageSizeW32();

		return pageSize;
	}
}

bool VDIsValidReadRegion(const void *p0, size_t bytes) {
	if (!bytes)
		return true;

	if (!p0)
		return false;

	uintptr pageSize = VDGetSystemPageSize();
	uintptr p = (uintptr)p0;
	uintptr pLimit = p + (bytes-1);

	__try {
		for(;;) {
			*(volatile char *)p;

			if (pLimit - p < pageSize)
				break;

			p += pageSize;
		}
	} __except(1) {
		return false;
	}

	return true;
}

bool VDIsValidWriteRegion(const void *p0, size_t bytes) {
	if (!bytes)
		return true;

	if (!p0)
		return false;

	// Note: Unlike IsValidWritePtr(), this is threadsafe.

	uintptr pageSize = VDGetSystemPageSize();
	uintptr p = (uintptr)p0;
	uintptr pLimit = p + (bytes-1);
	p &= ~(uintptr)3;

	__try {
		for(;;) {
			VDAtomicInt::staticCompareExchange((volatile int *)p, 0xa5, 0xa5);

			if (pLimit - p < pageSize)
				break;

			p += pageSize;
		}
	} __except(1) {
		return false;
	}

	return true;
}

void VDMemset8(void *dst, uint8 value, size_t count) {
	if (count) {
		uint8 *dst2 = (uint8 *)dst;

		do {
			*dst2++ = value;
		} while(--count);
	}
}

void VDMemset16(void *dst, uint16 value, size_t count) {
	if (count) {
		uint16 *dst2 = (uint16 *)dst;

		do {
			*dst2++ = value;
		} while(--count);
	}
}

void VDMemset32(void *dst, uint32 value, size_t count) {
	if (count) {
		uint32 *dst2 = (uint32 *)dst;

		do {
			*dst2++ = value;
		} while(--count);
	}
}

void VDMemset8Rect(void *dst, ptrdiff_t pitch, uint8 value, size_t w, size_t h) {
	if (w>0 && h>0) {
		do {
			memset(dst, value, w);
			dst = (char *)dst + pitch;
		} while(--h);
	}
}

#if defined(_WIN32) && defined(_M_IX86)
	extern "C" void __cdecl VDFastMemcpyPartialScalarAligned8(void *dst, const void *src, size_t bytes);
	extern "C" void __cdecl VDFastMemcpyPartialMMX(void *dst, const void *src, size_t bytes);
	extern "C" void __cdecl VDFastMemcpyPartialMMX2(void *dst, const void *src, size_t bytes);

	void VDFastMemcpyPartialScalar(void *dst, const void *src, size_t bytes) {
		if (!(((int)dst | (int)src | bytes) & 7))
			VDFastMemcpyPartialScalarAligned8(dst, src, bytes);
		else
			memcpy(dst, src, bytes);
	}

	void VDFastMemcpyFinishScalar() {
	}

	void __cdecl VDFastMemcpyFinishMMX() {
		__asm emms
	}

	void __cdecl VDFastMemcpyFinishMMX2() {
		__asm emms
		__asm sfence
	}

	void (__cdecl *VDFastMemcpyPartial)(void *dst, const void *src, size_t bytes) = VDFastMemcpyPartialScalar;
	void (__cdecl *VDFastMemcpyFinish)() = VDFastMemcpyFinishScalar;

	void VDFastMemcpyAutodetect() {
		long exts = CPUGetEnabledExtensions();

		if (exts & CPUF_SUPPORTS_INTEGER_SSE) {
			VDFastMemcpyPartial = VDFastMemcpyPartialMMX2;
			VDFastMemcpyFinish	= VDFastMemcpyFinishMMX2;
		} else if (exts & CPUF_SUPPORTS_MMX) {
			VDFastMemcpyPartial = VDFastMemcpyPartialMMX;
			VDFastMemcpyFinish	= VDFastMemcpyFinishMMX;
		} else {
			VDFastMemcpyPartial = VDFastMemcpyPartialScalar;
			VDFastMemcpyFinish	= VDFastMemcpyFinishScalar;
		}
	}

#else
	void VDFastMemcpyPartial(void *dst, const void *src, size_t bytes) {
		memcpy(dst, src, bytes);
	}

	void VDFastMemcpyFinish() {
	}

	void VDFastMemcpyAutodetect() {
	}
#endif

void VDMemcpyRect(void *dst, ptrdiff_t dststride, const void *src, ptrdiff_t srcstride, size_t w, size_t h) {
	if (w <= 0 || h <= 0)
		return;

	if (w == srcstride && w == dststride)
		VDFastMemcpyPartial(dst, src, w*h);
	else {
		char *dst2 = (char *)dst;
		const char *src2 = (const char *)src;

		do {
			VDFastMemcpyPartial(dst2, src2, w);
			dst2 += dststride;
			src2 += srcstride;
		} while(--h);
	}
	VDFastMemcpyFinish();
}

