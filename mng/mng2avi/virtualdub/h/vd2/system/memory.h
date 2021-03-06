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

#ifndef f_VD2_SYSTEM_MEMORY_H
#define f_VD2_SYSTEM_MEMORY_H

#include <vd2/system/vdtypes.h>

void *VDAlignedMalloc(size_t n, unsigned alignment);
void VDAlignedFree(void *p);

template<unsigned alignment>
struct VDAlignedObject {
	inline void *operator new(size_t n) { return VDAlignedMalloc(n, alignment); }
	inline void operator delete(void *p) { VDAlignedFree(p); }
};

void VDSwapMemory(void *p0, void *p1, unsigned bytes);
void VDInvertMemory(void *p, unsigned bytes);

bool VDIsValidReadRegion(const void *p, size_t bytes);
bool VDIsValidWriteRegion(void *p, size_t bytes);

void VDMemset8(void *dst, uint8 value, size_t count);
void VDMemset16(void *dst, uint16 value, size_t count);
void VDMemset32(void *dst, uint32 value, size_t count);

void VDMemset8Rect(void *dst, ptrdiff_t pitch, uint8 value, size_t w, size_t h);

#if defined(_WIN32) && defined(_M_IX86)
	extern void (__cdecl *VDFastMemcpyPartial)(void *dst, const void *src, size_t bytes);
	extern void (__cdecl *VDFastMemcpyFinish)();
	void VDFastMemcpyAutodetect();
#else
	void VDFastMemcpyPartial(void *dst, const void *src, size_t bytes);
	void VDFastMemcpyFinish();
	void VDFastMemcpyAutodetect();
#endif


void VDMemcpyRect(void *dst, ptrdiff_t dststride, const void *src, ptrdiff_t srcstride, size_t w, size_t h);

#endif
