#include "blt_spanutils.h"
#include "bitutils.h"

using namespace nsVDPixmapBitUtils;

namespace nsVDPixmapSpanUtils {
	void horiz_expand2x_centered(uint8 *dst, const uint8 *src, sint32 w) {
		w = -w;

		*dst++ = *src;

		if (++w) {
			if (++w) {
				do {
					dst[0] = (uint8)((3*src[0] + src[1] + 2)>>2);
					dst[1] = (uint8)((src[0] + 3*src[1] + 2)>>2);
					dst += 2;
					++src;
				} while((w+=2)<0);
			}

			if (!(w & 1)) {
				*dst = src[-1];
			}
		}
	}

	void horiz_expand2x_coaligned(uint8 *dst, const uint8 *src, sint32 w) {
		w = -w;

		if ((w+=2) < 0) {
			do {
				dst[0] = src[0];
				dst[1] = (uint8)((src[0] + src[1] + 1)>>1);
				dst += 2;
				++src;
			} while((w+=2)<0);
		}

		w -= 2;
		while(w < 0) {
			++w;
			*dst++ = src[-1];
		}
	}

	void horiz_expand4x_coaligned(uint8 *dst, const uint8 *src, sint32 w) {
		w = -w;

		if ((w+=4) < 0) {
			do {
				dst[0] = src[0];
				dst[1] = (uint8)((3*src[0] + src[1] + 2)>>2);
				dst[2] = (uint8)((src[0] + src[1] + 1)>>1);
				dst[3] = (uint8)((src[0] + 3*src[1] + 2)>>2);
				dst += 4;
				++src;
			} while((w+=4)<0);
		}

		w -= 4;
		while(w < 0) {
			++w;
			*dst++ = src[-1];
		}
	}

	void horiz_compress2x_coaligned(uint8 *dst, const uint8 *src, sint32 w) {
		if (w == 1) {
			*dst = *src;
			return;
		}

		*dst++ = (uint8)((3*src[0] + src[1] + 2) >> 2);
		++src;
		--w;

		while(w >= 3) {
			w -= 2;
			*dst++ = (uint8)((src[0] + 2*src[1] + src[2] + 2) >> 2);
			src += 2;
		}
	}

	void horiz_compress2x_centered(uint8 *dst, const uint8 *src, sint32 w) {
		if (w == 1) {
			*dst = *src;
			return;
		}

		if (w == 2) {
			*dst = (uint8)((src[0] + src[1] + 1) >> 1);
			return;
		}

		*dst++ = (uint8)((3*src[0] + src[1] + 2) >> 2);
		--w;
		++src;

		while(w >= 4) {
			w -= 2;
			*dst++ = (uint8)(((src[0] + src[3]) + 3*(src[1] + src[2]) + 4) >> 3);
			src += 2;
		}

		switch(w) {
		case 3:
			*dst++ = (uint8)((src[0] + 3*src[1] + 4*src[2] + 4) >> 3);
			break;
		}
	}

	void horiz_compress4x_coaligned(uint8 *dst, const uint8 *src, sint32 w) {
		if (w == 1) {
			*dst = *src;
			return;
		}

		if (w == 2) {
			*dst++ = (uint8)((11*src[0] + 5*src[1] + 8) >> 4);
			return;
		}

		*dst++ = (uint8)((11*src[0] + 4*src[1] + src[2] + 8) >> 4);
		src += 2;
		w -= 4;

		while(w >= 3) {
			w -= 4;
			*dst++ = (uint8)(((src[0] + src[4]) + 4*(src[1] + src[3]) + 6*src[2] + 8) >> 4);
			src += 4;
		}
	}

	void horiz_compress4x_centered(uint8 *dst, const uint8 *src, sint32 w) {
		*dst++ = (uint8)((src[3] + 6*src[2] + 15*src[1] + 42*src[0] + 32) >> 6);
		++src;
		w -= 3;

		while(w >= 4) {
			w -= 4;
			*dst++ = (uint8)(((src[0] + src[7]) + 7*(src[1] + src[6]) + 21*(src[2] + src[5]) + 35*(src[3] + src[4]) + 64) >> 7);
			src += 4;
		}

		switch(w) {
		case 3:
			*dst++ = (uint8)((src[0] + 7*src[1] + 21*src[2] + 35*src[3] + 64*src[4] + 64) >> 7);
			break;
		case 2:
			*dst++ = (uint8)((src[0] + 7*src[1] + 21*src[2] + 29*src[5] + 35*(src[3] + src[4]) + 64) >> 7);
			break;
		case 1:
			*dst++ = (uint8)((src[0] + 7*src[1] + 8*src[6] + 21*(src[2] + src[5]) + 35*(src[3] + src[4]) + 64) >> 7);
			break;
		}
	}

	void vert_expand2x_centered(uint8 *dst, const uint8 *const *srcs, sint32 w, uint8 phase) {
		const uint8 *src3 = srcs[0];
		const uint8 *src1 = srcs[1];

		if (phase >= 128)
			std::swap(src1, src3);

		sint32 w4 = w>>2;
		w &= 3;

		if (w4) {
			const uint32 *src34 = (const uint32 *)src3;
			const uint32 *src14 = (const uint32 *)src1;
			      uint32 *dst4  = (      uint32 *)dst;

			do {
				const uint32 a = *src34++;
				const uint32 b = *src14++;
				const uint32 ab = (a&b) + (((a^b)&0xfefefefe)>>1);

				*dst4++ = (a|ab) - (((a^ab)&0xfefefefe)>>1);
			} while(--w4);

			src3 = (const uint8 *)src34;
			src1 = (const uint8 *)src14;
			dst  = (      uint8 *)dst4;
		}

		if (w) {
			do {
				*dst++ = (uint8)((*src1++ + 3**src3++ + 2) >> 2);
			} while(--w);
		}
	}

	void vert_expand4x_centered(uint8 *dst, const uint8 *const *srcs, sint32 w, uint8 phase) {
		const uint8 *src3 = srcs[0];
		const uint8 *src1 = srcs[1];

		switch(phase & 0xc0) {
		case 0x00:
			do {
				*dst++ = (uint8)((1**src1++ + 7**src3++ + 4) >> 3);
			} while(--w);
			break;
		case 0x40:
			do {
				*dst++ = (uint8)((3**src1++ + 5**src3++ + 4) >> 3);
			} while(--w);
			break;
		case 0x80:
			do {
				*dst++ = (uint8)((5**src1++ + 3**src3++ + 4) >> 3);
			} while(--w);
			break;
		case 0xc0:
			do {
				*dst++ = (uint8)((7**src1++ + 1**src3++ + 4) >> 3);
			} while(--w);
			break;
		default:
			VDNEVERHERE;
		}
	}

	void vert_compress2x_centered_fast(uint8 *dst, const uint8 *const *srcarray, sint32 w, uint8 phase) {
		const uint8 *src1 = srcarray[0];
		const uint8 *src2 = srcarray[1];

		w = -w;
		w += 3;

		while(w < 0) {
			*(uint32 *)dst = avg_8888_11(*(uint32 *)src1, *(uint32 *)src2);
			dst += 4;
			src1 += 4;
			src2 += 4;
			w += 4;
		}

		w -= 3;

		while(w < 0) {
			*dst = (uint8)((*src1 + *src2 + 1)>>1);
			++dst;
			++src1;
			++src2;
			++w;
		}
	}

	void vert_compress2x_centered(uint8 *dst, const uint8 *const *srcarray, sint32 w, uint8 phase) {
		const uint8 *src1 = srcarray[0];
		const uint8 *src2 = srcarray[1];
		const uint8 *src3 = srcarray[2];
		const uint8 *src4 = srcarray[3];

		w = -w;

		while(w < 0) {
			*dst++ = (uint8)(((*src1++ + *src4++) + 3*(*src2++ + *src3++) + 4)>>3);
			++w;
		}
	}

	void vert_compress4x_centered(uint8 *dst, const uint8 *const *srcarray, sint32 w, uint8 phase) {
		const uint8 *src1 = srcarray[0];
		const uint8 *src2 = srcarray[1];
		const uint8 *src3 = srcarray[2];
		const uint8 *src4 = srcarray[3];
		const uint8 *src5 = srcarray[4];
		const uint8 *src6 = srcarray[5];
		const uint8 *src7 = srcarray[6];
		const uint8 *src8 = srcarray[7];

		w = -w;

		while(w < 0) {
			int sum18 = *src1++ + *src8++;
			int sum27 = *src2++ + *src7++;
			int sum36 = *src3++ + *src6++;
			int sum45 = *src4++ + *src5++;

			*dst++ = (uint8)((sum18 + 7*sum27 + 21*sum36 + 35*sum45 + 64) >> 7);

			++w;
		}
	}
}

