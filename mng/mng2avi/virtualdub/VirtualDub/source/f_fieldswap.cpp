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

#include "resource.h"
#include "filter.h"

extern HINSTANCE g_hInst;

///////////////////////////////////

#ifdef _M_IX86
static void __declspec(naked) asm_fieldswap(void *data, int bytes4, int bytes1, int height, long pitch) {
	__asm {
		push	ebp
		push	edi
		push	esi
		push	ebx

		mov		esi,[esp+4+16]
		mov		edx,[esp+16+16]
		mov		edi,esi
		mov		ecx,[esp+12+16]
		mov		eax,[esp+20+16]
		shr		eax,1
		add		edi,eax
yloop:
		mov		ebp,[esp+8+16]
xloop:
		mov		eax,[esi+ebp]
		mov		ebx,[edi+ebp]
		mov		[esi+ebp],ebx
		mov		[edi+ebp],eax
		add		ebp,4
		jne		xloop

		or		ecx,ecx
		jz		no_extra
xloop_bytes:
		mov		al,[esi+ebp]
		mov		bl,[edi+ebp]
		mov		[esi+ebp],bl
		mov		[edi+ebp],al
		inc		ebp
		cmp		ebp,ecx
		jne		xloop_bytes

no_extra:
		add		esi,[esp+20+16]
		add		edi,[esp+20+16]
		dec		edx
		jne		yloop

		pop		ebx
		pop		esi
		pop		edi
		pop		ebp
		ret
	}
}
#else
static void asm_fieldswap(void *data, int bytes4, int bytes1, int height, long pitch) {
	uint32 *p1 = (uint32 *)data;
	uint32 *p2 = (uint32 *)((char *)data + pitch);

	if (bytes4)
		do {
			const uint32 x = *p1;
			const uint32 y = *p2;

			*p1++ = y;
			*p2++ = x;
		} while(--bytes4);

	if (bytes1) {
		uint8 *p1b = (uint8 *)p1;
		uint8 *p2b = (uint8 *)p2;

		do {
			const uint8 x = *p1b;
			const uint8 y = *p2b;

			*p1b++ = y;
			*p1b++ = x;
		} while(--bytes1);
	}
}
#endif

///////////////////////////////////

int fieldswap_run(const FilterActivation *fa, const FilterFunctions *ff) {	
	asm_fieldswap(
			fa->src.data + fa->src.w,
			-fa->src.w*4,
			0,
			fa->src.h/2,
			fa->src.pitch*2
			);

	return 0;
}

long fieldswap_param(FilterActivation *fa, const FilterFunctions *ff) {
	fa->dst.offset = fa->src.offset;
	return 0;
}

FilterDefinition filterDef_fieldswap={
	0,0,NULL,
	"field swap",
	"Swaps interlaced fields in the image.\n\n[Assembly optimized]",
	NULL,NULL,
	0,
	NULL,NULL,
	fieldswap_run,
	fieldswap_param,
	NULL,
	NULL,
};
