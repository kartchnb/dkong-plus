#include <math.h>
#include <vector>
#include <vd2/system/math.h>
#include <vd2/system/cpuaccel.h>
#include <vd2/Kasumi/pixmap.h>
#include <vd2/Kasumi/pixmaputils.h>
#include <vd2/Kasumi/pixmapops.h>
#include <vd2/Kasumi/triblt.h>

namespace {
	uint32 lerp_RGB888(sint32 a, sint32 b, sint32 x) {
		sint32 a_rb	= a & 0xff00ff;
		sint32 a_g	= a & 0x00ff00;
		sint32 b_rb	= b & 0xff00ff;
		sint32 b_g	= b & 0x00ff00;

		const uint32 top_rb = (a_rb + (((b_rb - a_rb)*x + 0x00800080) >> 8)) & 0xff00ff;
		const uint32 top_g  = (a_g  + (((b_g  - a_g )*x + 0x00008000) >> 8)) & 0x00ff00;

		return top_rb + top_g;
	}

	uint32 bilerp_RGB888(sint32 a, sint32 b, sint32 c, sint32 d, sint32 x, sint32 y) {
		sint32 a_rb	= a & 0xff00ff;
		sint32 a_g	= a & 0x00ff00;
		sint32 b_rb	= b & 0xff00ff;
		sint32 b_g	= b & 0x00ff00;
		sint32 c_rb	= c & 0xff00ff;
		sint32 c_g	= c & 0x00ff00;
		sint32 d_rb	= d & 0xff00ff;
		sint32 d_g	= d & 0x00ff00;

		const uint32 top_rb = (a_rb + (((b_rb - a_rb)*x + 0x00800080) >> 8)) & 0xff00ff;
		const uint32 top_g  = (a_g  + (((b_g  - a_g )*x + 0x00008000) >> 8)) & 0x00ff00;
		const uint32 bot_rb = (c_rb + (((d_rb - c_rb)*x + 0x00800080) >> 8)) & 0xff00ff;
		const uint32 bot_g  = (c_g  + (((d_g  - c_g )*x + 0x00008000) >> 8)) & 0x00ff00;

		const uint32 final_rb = (top_rb + (((bot_rb - top_rb)*y) >> 8)) & 0xff00ff;
		const uint32 final_g  = (top_g  + (((bot_g  - top_g )*y) >> 8)) & 0x00ff00;

		return final_rb + final_g;
	}
}

namespace {
	enum {
		kTop = 1,
		kBottom = 2,
		kLeft = 4,
		kRight = 8,
		kNear = 16,
		kFar = 32
	};

	struct VDTriBltMipInfo {
		const uint32 *mip;
		ptrdiff_t pitch;
		uint32 uvmul, _pad;
	};

	struct VDTriBltInfo {
		VDTriBltMipInfo mips[16];
		uint32 *dst;
		const uint32 *src;
		sint32 width;
		const int *cubictab;
	};

	struct VDTriBltGenInfo {
		float	u;
		float	v;
		float	rhw;
		float	dudx;
		float	dvdx;
		float	drhwdx;
	};

	typedef void (*VDTriBltSpanFunction)(const VDTriBltInfo *);
	typedef void (*VDTriBltGenFunction)(const VDTriBltGenInfo *);

	void vd_triblt_span_point(const VDTriBltInfo *pInfo) {
		sint32 w = -pInfo->width;
		uint32 *dst = pInfo->dst + pInfo->width;
		const uint32 *src = pInfo->src;
		const uint32 *texture = pInfo->mips[0].mip;
		const ptrdiff_t texpitch = pInfo->mips[0].pitch;

		do {
			dst[w] = vdptroffset(texture, texpitch * src[1])[src[0]];
			src += 2;
		} while(++w);
	}

	void vd_triblt_span_bilinear(const VDTriBltInfo *pInfo) {
		sint32 w = -pInfo->width;
		uint32 *dst = pInfo->dst + pInfo->width;
		const uint32 *src = pInfo->src;
		const uint32 *texture = pInfo->mips[0].mip;
		const ptrdiff_t texpitch = pInfo->mips[0].pitch;

		do {
			const sint32 u = src[0];
			const sint32 v = src[1];
			src += 2;
			const uint32 *src1 = vdptroffset(texture, texpitch * (v>>8)) + (u>>8);
			const uint32 *src2 = vdptroffset(src1, texpitch);

			dst[w] = bilerp_RGB888(src1[0], src1[1], src2[0], src2[1], u&255, v&255);
		} while(++w);
	}

	void vd_triblt_span_trilinear(const VDTriBltInfo *pInfo) {
		sint32 w = -pInfo->width;
		uint32 *dst = pInfo->dst + pInfo->width;
		const uint32 *src = pInfo->src;

		do {
			sint32 u = src[0];
			sint32 v = src[1];
			const sint32 lambda = src[2];
			src += 3;

			const sint32 lod = lambda >> 8;

			const uint32 *texture1 = pInfo->mips[lod].mip;
			const ptrdiff_t texpitch1 = pInfo->mips[lod].pitch;
			const uint32 *texture2 = pInfo->mips[lod+1].mip;
			const ptrdiff_t texpitch2 = pInfo->mips[lod+1].pitch;

			u >>= lod;
			v >>= lod;

			u += 128;
			v += 128;

			const uint32 *src1 = vdptroffset(texture1, texpitch1 * (v>>8)) + (u>>8);
			const uint32 *src2 = vdptroffset(src1, texpitch1);
			const uint32 p1 = bilerp_RGB888(src1[0], src1[1], src2[0], src2[1], u&255, v&255);

			u += 128;
			v += 128;

			const uint32 *src3 = vdptroffset(texture2, texpitch2 * (v>>9)) + (u>>9);
			const uint32 *src4 = vdptroffset(src3, texpitch2);
			const uint32 p2 = bilerp_RGB888(src3[0], src3[1], src4[0], src4[1], (u>>1)&255, (v>>1)&255);

			dst[w] = lerp_RGB888(p1, p2, lambda & 255);
		} while(++w);
	}

#ifdef _M_IX86
	extern "C" void vdasm_triblt_span_bilinear_mmx(const VDTriBltInfo *pInfo);
	extern "C" void vdasm_triblt_span_trilinear_mmx(const VDTriBltInfo *pInfo);
	extern "C" void vdasm_triblt_span_point(const VDTriBltInfo *pInfo);
#endif

	struct VDTriBltTransformedVertex {
		float x, y, z;
		union {
			float w;
			float rhw;
		};
		float u, v;
		int outcode;

		void interp(const VDTriBltTransformedVertex *v1, const VDTriBltTransformedVertex *v2, float alpha) {
			x = v1->x + alpha * (v2->x - v1->x);
			y = v1->y + alpha * (v2->y - v1->y);
			z = v1->z + alpha * (v2->z - v1->z);
			w = v1->w + alpha * (v2->w - v1->w);

			u = v1->u + alpha * (v2->u - v1->u);
			v = v1->v + alpha * (v2->v - v1->v);

			outcode	= (x < -w ? kLeft : 0)
					+ (x > +w ? kRight : 0)
					+ (y < -w ? kTop : 0)
					+ (y > +w ? kBottom : 0)
					+ (z < -w ? kNear : 0)
					+ (z > +w ? kFar : 0);
		}
	};

	void TransformVerts(VDTriBltTransformedVertex *dst, const VDTriBltVertex *src, int nVerts, const float xform[16], float width, float height) {
		const float xflocal[16]={
			xform[ 0],	xform[ 1],	xform[ 2],	xform[ 3],
			xform[ 4],	xform[ 5],	xform[ 6],	xform[ 7],
			xform[ 8],	xform[ 9],	xform[10],	xform[11],
			xform[12],	xform[13],	xform[14],	xform[15],
		};
		if (nVerts>0)
			do {
				const float x0 = src->x;
				const float y0 = src->y;
				const float z0 = src->z;

				const float w	= x0*xflocal[12] + y0*xflocal[13] + z0*xflocal[14] + xflocal[15];
				const float x   = x0*xflocal[ 0] + y0*xflocal[ 1] + z0*xflocal[ 2] + xflocal[ 3];
				const float y   = x0*xflocal[ 4] + y0*xflocal[ 5] + z0*xflocal[ 6] + xflocal[ 7];
				const float z   = x0*xflocal[ 8] + y0*xflocal[ 9] + z0*xflocal[10] + xflocal[11];

				int outcode = 0;

				if (x < -w)		outcode += kLeft;
				if (x > w)		outcode += kRight;
				if (y < -w)		outcode += kTop;
				if (y > w)		outcode += kBottom;
				if (z < -w)		outcode += kNear;
				if (z > w)		outcode += kFar;

				dst->x = x;
				dst->y = y;
				dst->z = z;
				dst->w = w;
				dst->u = src->u;
				dst->v = src->v;
				dst->outcode = outcode;

				++src;
				++dst;
			} while(--nVerts);
	}

	static const __int64 __declspec(align(16)) mask255 = 255;

#if 0
	static __forceinline uint32 sample_trilinear_sse2(const uint32 *p1, ptrdiff_t pitch1, const uint32 *p2, ptrdiff_t pitch2, uint32 utexel, uint32 vtexel, int lambda) {
		uint32 v;
		__asm {
			movq xmm6, mask255
			movd xmm0, utexel
			movd xmm1, vtexel
			pxor xmm7, xmm7
			pand xmm0, xmm6
			pand xmm1, xmm6
			pshuflw xmm0, xmm0, 0
			pshuflw xmm1, xmm1, 0
			pshufd xmm0, xmm0, 0
			pshufd xmm1, xmm1, 0
			psllw		xmm0, 7
			psllw		xmm1, 7

			mov ecx, p1
			mov edx, pitch1
			movq	xmm2, qword ptr [ecx]
			movq	xmm3, qword ptr [ecx+edx]
			punpcklbw	xmm2, xmm7
			punpcklbw	xmm3, xmm7
			psubw		xmm3, xmm2
			paddw		xmm3, xmm3
			pmulhw		xmm3, xmm1
			paddw		xmm2, xmm3
			movdqa		xmm3, xmm2
			psrldq		xmm3, 8
			psubw		xmm3, xmm2
			paddw		xmm3, xmm3
			pmulhw		xmm3, xmm0
			paddw		xmm2, xmm3

			movd xmm0, utexel
			movd xmm1, vtexel
			pxor xmm7, xmm7
			psrlq xmm0, 1
			psrlq xmm1, 1
			pand xmm0, xmm6
			pand xmm1, xmm6
			pshuflw xmm0, xmm0, 0
			pshuflw xmm1, xmm1, 0
			pshufd xmm0, xmm0, 0
			pshufd xmm1, xmm1, 0
			psllw		xmm0, 7
			psllw		xmm1, 7

			mov ecx, p2
			mov edx, pitch2
			movq	xmm4, qword ptr [ecx]
			movq	xmm3, qword ptr [ecx+edx]
			punpcklbw	xmm4, xmm7
			punpcklbw	xmm3, xmm7
			psubw		xmm3, xmm4
			paddw		xmm3, xmm3
			pmulhw		xmm3, xmm1
			paddw		xmm4, xmm3
			movdqa		xmm3, xmm4
			psrldq		xmm3, 8
			psubw		xmm3, xmm4
			paddw		xmm3, xmm3
			pmulhw		xmm3, xmm0
			paddw		xmm4, xmm3

			movd		xmm0, lambda
			punpcklbw	xmm0, xmm7
			pshuflw		xmm0, xmm0, 0
			psllw		xmm0, 7
			psubw		xmm4, xmm2
			paddw		xmm4, xmm4
			pmulhw		xmm4, xmm0
			paddw		xmm2, xmm4
			packuswb	xmm2, xmm2
			movd		v, xmm2							
		}
		return v;
	}
#endif

	struct VDTriangleSetupInfo {
		const VDTriBltTransformedVertex *pt, *pr, *pl;
		VDTriBltTransformedVertex tmp0, tmp1, tmp2;
	};

	void SetupTri(
			VDTriangleSetupInfo& setup,
			VDPixmap& dst,
			const VDTriBltTransformedVertex *vx0,
			const VDTriBltTransformedVertex *vx1,
			const VDTriBltTransformedVertex *vx2,
			const VDTriBltFilterMode *filterMode
			)
	{
		setup.tmp0 = *vx0;
		setup.tmp1 = *vx1;
		setup.tmp2 = *vx2;

		// adjust UVs for filter mode
		if (filterMode) {
			switch(*filterMode) {
			case kTriBltFilterBilinear:
				setup.tmp0.u += 0.5f;
				setup.tmp0.v += 0.5f;
				setup.tmp1.u += 0.5f;
				setup.tmp1.v += 0.5f;
				setup.tmp2.u += 0.5f;
				setup.tmp2.v += 0.5f;
			case kTriBltFilterTrilinear:
				setup.tmp0.u *= 256.0f;
				setup.tmp0.v *= 256.0f;
				setup.tmp1.u *= 256.0f;
				setup.tmp1.v *= 256.0f;
				setup.tmp2.u *= 256.0f;
				setup.tmp2.v *= 256.0f;
				break;
			case kTriBltFilterPoint:
				setup.tmp0.u += 1.0f;
				setup.tmp0.v += 1.0f;
				setup.tmp1.u += 1.0f;
				setup.tmp1.v += 1.0f;
				setup.tmp2.u += 1.0f;
				setup.tmp2.v += 1.0f;
				break;
			}
		}

		// do perspective divide and NDC space conversion
		const float xscale = dst.w * 0.5f;
		const float yscale = dst.h * 0.5f;

		setup.tmp0.rhw = 1.0f / setup.tmp0.w;
		setup.tmp0.x = (1.0f+setup.tmp0.x*setup.tmp0.rhw)*xscale;
		setup.tmp0.y = (1.0f+setup.tmp0.y*setup.tmp0.rhw)*yscale;
		setup.tmp0.u *= setup.tmp0.rhw;
		setup.tmp0.v *= setup.tmp0.rhw;
		setup.tmp1.rhw = 1.0f / setup.tmp1.w;
		setup.tmp1.x = (1.0f+setup.tmp1.x*setup.tmp1.rhw)*xscale;
		setup.tmp1.y = (1.0f+setup.tmp1.y*setup.tmp1.rhw)*yscale;
		setup.tmp1.u *= setup.tmp1.rhw;
		setup.tmp1.v *= setup.tmp1.rhw;
		setup.tmp2.rhw = 1.0f / setup.tmp2.w;
		setup.tmp2.x = (1.0f+setup.tmp2.x*setup.tmp2.rhw)*xscale;
		setup.tmp2.y = (1.0f+setup.tmp2.y*setup.tmp2.rhw)*yscale;
		setup.tmp2.u *= setup.tmp2.rhw;
		setup.tmp2.v *= setup.tmp2.rhw;

		// verify clipping
		VDASSERT(setup.tmp0.x >= 0 && setup.tmp0.x <= dst.w);
		VDASSERT(setup.tmp1.x >= 0 && setup.tmp1.x <= dst.w);
		VDASSERT(setup.tmp2.x >= 0 && setup.tmp2.x <= dst.w);
		VDASSERT(setup.tmp0.y >= 0 && setup.tmp0.y <= dst.h);
		VDASSERT(setup.tmp1.y >= 0 && setup.tmp1.y <= dst.h);
		VDASSERT(setup.tmp2.y >= 0 && setup.tmp2.y <= dst.h);

		vx0 = &setup.tmp0;
		vx1 = &setup.tmp1;
		vx2 = &setup.tmp2;

		const VDTriBltTransformedVertex *pt, *pl, *pr;

		// sort points
		if (vx0->y < vx1->y)		// 1 < 2
			if (vx0->y < vx2->y) {	// 1 < 2,3
				pt = vx0;
				pr = vx1;
				pl = vx2;
			} else {				// 3 < 1 < 2
				pt = vx2;
				pr = vx0;
				pl = vx1;
			}
		else						// 2 < 1
			if (vx1->y < vx2->y) {	// 2 < 1,3
				pt = vx1;
				pr = vx2;
				pl = vx0;
			} else {				// 3 < 2 < 1
				pt = vx2;
				pr = vx0;
				pl = vx1;
			}

		setup.pl = pl;
		setup.pt = pt;
		setup.pr = pr;
	}

	void RenderTri(VDPixmap& dst, const VDPixmap *const *pSources, int nMipmaps,
							const VDTriBltTransformedVertex *vx0,
							const VDTriBltTransformedVertex *vx1,
							const VDTriBltTransformedVertex *vx2,
							VDTriBltFilterMode filterMode,
							bool border)
	{

		VDTriangleSetupInfo setup;

		SetupTri(setup, dst, vx0, vx1, vx2, &filterMode);

		const VDTriBltTransformedVertex *pt = setup.pt, *pl = setup.pl, *pr = setup.pr;

		const float x10 = pl->x - pt->x;
		const float x20 = pr->x - pt->x;
		const float y10 = pl->y - pt->y;
		const float y20 = pr->y - pt->y;
		const float A = x20*y10 - x10*y20;

		if (A <= 0.f)
			return;

		float invA = 0.f;
		if (A >= 1e-5f)
			invA = 1.0f / A;

		float x10_A = x10 * invA;
		float x20_A = x20 * invA;
		float y10_A = y10 * invA;
		float y20_A = y20 * invA;

		float u10 = pl->u - pt->u;
		float u20 = pr->u - pt->u;
		float v10 = pl->v - pt->v;
		float v20 = pr->v - pt->v;
		float rhw10 = pl->rhw - pt->rhw;
		float rhw20 = pr->rhw - pt->rhw;

		float dudx = u20*y10_A - u10*y20_A;
		float dudy = u10*x20_A - u20*x10_A;
		float dvdx = v20*y10_A - v10*y20_A;
		float dvdy = v10*x20_A - v20*x10_A;
		float drhwdx = rhw20*y10_A - rhw10*y20_A;
		float drhwdy = rhw10*x20_A - rhw20*x10_A;

		// Compute edge walking parameters

		float dxl1=0, dxr1=0, dul1=0, dvl1=0, drhwl1=0;
		float dxl2=0, dxr2=0, dul2=0, dvl2=0, drhwl2=0;

		// Compute left-edge interpolation parameters for first half.

		if (pl->y != pt->y) {
			dxl1 = (pl->x - pt->x) / (pl->y - pt->y);

			dul1 = dudy + dxl1 * dudx;
			dvl1 = dvdy + dxl1 * dvdx;
			drhwl1 = drhwdy + dxl1 * drhwdx;
		}

		// Compute right-edge interpolation parameters for first half.

		if (pr->y != pt->y) {
			dxr1 = (pr->x - pt->x) / (pr->y - pt->y);
		}

		// Compute third-edge interpolation parameters.

		if (pr->y != pl->y) {
			dxl2 = (pr->x - pl->x) / (pr->y - pl->y);

			dul2 = dudy + dxl2 * dudx;
			dvl2 = dvdy + dxl2 * dvdx;
			drhwl2 = drhwdy + dxl2 * drhwdx;

			dxr2 = dxl2;
		}

		// Initialize parameters for first half.
		//
		// We place pixel centers at (x+0.5, y+0.5).

		double xl, xr, ul, vl, rhwl, yf;
		int y, y1, y2;

		// y_start < y+0.5 to include pixel y.

		y = floor(pt->y + 0.5);
		yf = (y+0.5) - pt->y;

		xl = pt->x + dxl1 * yf;
		xr = pt->x + dxr1 * yf;
		ul = pt->u + dul1 * yf;
		vl = pt->v + dvl1 * yf;
		rhwl = pt->rhw + drhwl1 * yf;

		// Initialize parameters for second half.

		double xl2, xr2, ul2, vl2, rhwl2;

		if (pl->y > pr->y) {		// Left edge is long side
			dxl2 = dxl1;
			dul2 = dul1;
			dvl2 = dvl1;
			drhwl2 = drhwl1;

			y1 = floor(pr->y + 0.5);
			y2 = floor(pl->y + 0.5);

			yf = (y1+0.5) - pr->y;

			// Step left edge.

			xl2 = xl + dxl1 * (y1 - y);
			ul2 = ul + dul1 * (y1 - y);
			vl2 = vl + dvl1 * (y1 - y);
			rhwl2 = rhwl + drhwl1 * (y1 - y);

			// Prestep right edge.

			xr2 = pr->x + dxr2 * yf;
		} else {					// Right edge is long side
			dxr2 = dxr1;

			y1 = floor(pl->y + 0.5);
			y2 = floor(pr->y + 0.5);

			yf = (y1+0.5) - pl->y;

			// Prestep left edge.

			xl2 = pl->x + dxl2 * yf;
			ul2 = pl->u + dul2 * yf;
			vl2 = pl->v + dvl2 * yf;
			rhwl2 = pl->rhw + drhwl2 * yf;

			// Step right edge.

			xr2 = xr + dxr1 * (y1 - y);
		}

		// rasterize
		const ptrdiff_t dstpitch = dst.pitch;
		uint32 *dstp = (uint32 *)((char *)dst.data + dstpitch * y);

		VDTriBltInfo texinfo;
		VDTriBltSpanFunction drawSpan;
		uint32 cpuflags = CPUGetEnabledExtensions();

		bool triBlt16 = false;

		switch(filterMode) {
		case kTriBltFilterTrilinear:
#ifdef _M_IX86
			if (cpuflags & CPUF_SUPPORTS_MMX) {
				drawSpan = vdasm_triblt_span_trilinear_mmx;
				triBlt16 = true;
			} else
#endif
				drawSpan = vd_triblt_span_trilinear;
			break;
		case kTriBltFilterBilinear:
#ifdef _M_IX86
			if (cpuflags & CPUF_SUPPORTS_MMX) {
				drawSpan = vdasm_triblt_span_bilinear_mmx;
				triBlt16 = true;
			} else
#endif
				drawSpan = vd_triblt_span_bilinear;
			break;
		case kTriBltFilterPoint:
			drawSpan = vd_triblt_span_point;
			break;
		}

		float rhobase = sqrt(std::max<float>(dudx*dudx + dvdx*dvdx, dudy*dudy + dvdy*dvdy) * (1.0f / 65536.0f));

		if (triBlt16) {
			ul *= 256.0f;
			vl *= 256.0f;
			ul2 *= 256.0f;
			vl2 *= 256.0f;
			dul1 *= 256.0f;
			dvl1 *= 256.0f;
			dul2 *= 256.0f;
			dvl2 *= 256.0f;
			dudx *= 256.0f;
			dvdx *= 256.0f;
			dudy *= 256.0f;
			dvdy *= 256.0f;
		}

		int minx1 = (int)floor(std::min<float>(std::min<float>(pl->x, pr->x), pt->x) + 0.5);
		int maxx2 = (int)floor(std::max<float>(std::max<float>(pl->x, pr->x), pt->x) + 0.5);

		uint32 *const spanptr = new uint32[3 * (maxx2 - minx1)];

		while(y < y2) {
			if (y == y1) {
				xl = xl2;
				xr = xr2;
				ul = ul2;
				vl = vl2;
				rhwl = rhwl2;
				dxl1 = dxl2;
				dxr1 = dxr2;
				dul1 = dul2;
				dvl1 = dvl2;
				drhwl1 = drhwl2;
			}

			int x1, x2;
			double xf;
			double u, v, rhw;

			// x_left must be less than (x+0.5) to include pixel x.

			x1		= (int)floor(xl + 0.5);
			x2		= (int)floor(xr + 0.5);
			xf		= (x1+0.5) - xl;
			
			u		= ul + xf * dudx;
			v		= vl + xf * dvdx;
			rhw		= rhwl + xf * drhwdx;

			int x = x1;
			uint32 *spanp = spanptr;

			float w = 1.0f / rhw;

			if (x < x2) {
				if (filterMode >= kTriBltFilterTrilinear) {
					do {
						int utexel = VDRoundToIntFastFullRange(u * w);
						int vtexel = VDRoundToIntFastFullRange(v * w);
						union{ float f; sint32 i; } rho = {rhobase * w};

						int lambda = ((rho.i - 0x3F800000) >> (23-8));
						if (lambda < 0)
							lambda = 0;
						if (lambda >= (nMipmaps<<8)-256)
							lambda = (nMipmaps<<8)-257;

						spanp[0] = utexel;
						spanp[1] = vtexel;
						spanp[2] = lambda;
						spanp += 3;

						u += dudx;
						v += dvdx;
						rhw += drhwdx;

						w *= (2.0f - w*rhw);
					} while(++x < x2);
				} else {
					do {
						int utexel = VDFloorToInt(u * w);
						int vtexel = VDFloorToInt(v * w);

						spanp[0] = utexel;
						spanp[1] = vtexel;
						spanp += 2;

						u += dudx;
						v += dvdx;
						rhw += drhwdx;

						w *= (2.0f - w*rhw);
					} while(++x < x2);
				}
			}

			for(int i=0; i<nMipmaps; ++i) {
				texinfo.mips[i].mip		= (const uint32 *)pSources[i]->data;
				texinfo.mips[i].pitch	= pSources[i]->pitch;
				texinfo.mips[i].uvmul	= (pSources[i]->pitch << 16) + 4;
			}
			texinfo.dst = dstp+x1;
			texinfo.src = spanptr;
			texinfo.width = x2-x1;

			if (texinfo.width>0)
				drawSpan(&texinfo);

			dstp = vdptroffset(dstp, dstpitch);
			xl += dxl1;
			xr += dxr1;
			ul += dul1;
			vl += dvl1;
			rhwl += drhwl1;

			++y;
		}

		delete[] spanptr;
	}

	void FillTri(VDPixmap& dst, uint32 c,
					const VDTriBltTransformedVertex *vx0,
					const VDTriBltTransformedVertex *vx1,
					const VDTriBltTransformedVertex *vx2
					)
	{

		VDTriangleSetupInfo setup;

		SetupTri(setup, dst, vx0, vx1, vx2, NULL);

		const VDTriBltTransformedVertex *pt = setup.pt, *pl = setup.pl, *pr = setup.pr;

		// Compute edge walking parameters
		float dxl1=0, dxr1=0;
		float dxl2=0, dxr2=0;

		float x_lt = pl->x - pt->x;
		float x_rt = pr->x - pt->x;
		float x_rl = pr->x - pl->x;
		float y_lt = pl->y - pt->y;
		float y_rt = pr->y - pt->y;
		float y_rl = pr->y - pl->y;

		// reject backfaces
		if (x_lt*y_rt >= x_rt*y_lt)
			return;

		// Compute left-edge interpolation parameters for first half.
		if (pl->y != pt->y)
			dxl1 = x_lt / y_lt;

		// Compute right-edge interpolation parameters for first half.
		if (pr->y != pt->y)
			dxr1 = x_rt / y_rt;

		// Compute third-edge interpolation parameters.
		if (pr->y != pl->y) {
			dxl2 = x_rl / y_rl;

			dxr2 = dxl2;
		}

		// Initialize parameters for first half.
		//
		// We place pixel centers at (x+0.5, y+0.5).

		double xl, xr, yf;
		int y, y1, y2;

		// y_start < y+0.5 to include pixel y.

		y = floor(pt->y + 0.5);
		yf = (y+0.5) - pt->y;

		xl = pt->x + dxl1 * yf;
		xr = pt->x + dxr1 * yf;

		// Initialize parameters for second half.
		double xl2, xr2;

		if (pl->y > pr->y) {		// Left edge is long side
			dxl2 = dxl1;

			y1 = floor(pr->y + 0.5);
			y2 = floor(pl->y + 0.5);

			yf = (y1+0.5) - pr->y;

			// Prestep right edge.
			xr2 = pr->x + dxr2 * yf;
		} else {					// Right edge is long side
			dxr2 = dxr1;

			y1 = floor(pl->y + 0.5);
			y2 = floor(pr->y + 0.5);

			yf = (y1+0.5) - pl->y;

			// Prestep left edge.
			xl2 = pl->x + dxl2 * yf;

			// Step right edge.
			xr2 = xr + dxr1 * (y1 - y);
		}

		// rasterize
		const ptrdiff_t dstpitch = dst.pitch;
		uint32 *dstp = (uint32 *)((char *)dst.data + dstpitch * y);

		while(y < y2) {
			if (y == y1) {
				xl = xl2;
				xr = xr2;
				dxl1 = dxl2;
				dxr1 = dxr2;
			}

			int x1, x2;
			double xf;

			// x_left must be less than (x+0.5) to include pixel x.

			x1		= (int)floor(xl + 0.5);
			x2		= (int)floor(xr + 0.5);
			xf		= (x1+0.5) - xl;
			
			while(x1 < x2)
				dstp[x1++] = c;

			dstp = vdptroffset(dstp, dstpitch);
			xl += dxl1;
			xr += dxr1;
			++y;
		}
	}

	struct VDTriClipWorkspace {
		VDTriBltTransformedVertex *vxheapptr[2][19];
		VDTriBltTransformedVertex vxheap[21];
	};

	VDTriBltTransformedVertex **VDClipTriangle(VDTriClipWorkspace& ws,
						const VDTriBltTransformedVertex *vx0,
						const VDTriBltTransformedVertex *vx1,
						const VDTriBltTransformedVertex *vx2,
						int orflags) {
		// Each line segment can intersect all six planes, meaning the maximum bound is
		// 18 vertices.  Add 3 for the original.

		VDTriBltTransformedVertex *vxheapnext;
		VDTriBltTransformedVertex **vxlastheap = ws.vxheapptr[0], **vxnextheap = ws.vxheapptr[1];

		ws.vxheap[0]	= *vx0;
		ws.vxheap[1]	= *vx1;
		ws.vxheap[2]	= *vx2;

		vxlastheap[0] = &ws.vxheap[0];
		vxlastheap[1] = &ws.vxheap[1];
		vxlastheap[2] = &ws.vxheap[2];
		vxlastheap[3] = NULL;

		vxheapnext = ws.vxheap + 3;

		//	Current		Next		Action
		//	-------		----		------
		//	Unclipped	Unclipped	Copy vertex
		//	Unclipped	Clipped		Copy vertex and add intersection
		//	Clipped		Unclipped	Add intersection
		//	Clipped		Clipped		No action

#define	DOCLIP(cliptype, _sign_, cliparg)				\
		if (orflags & k##cliptype) {					\
			VDTriBltTransformedVertex **src = vxlastheap;		\
			VDTriBltTransformedVertex **dst = vxnextheap;		\
														\
			while(*src) {								\
				VDTriBltTransformedVertex *cur = *src;			\
				VDTriBltTransformedVertex *next = src[1];		\
														\
				if (!next)								\
					next = vxlastheap[0];				\
														\
				if (!(cur->outcode & k##cliptype))	\
					*dst++ = cur;						\
														\
				if ((cur->outcode ^ next->outcode) & k##cliptype) {	\
					double alpha = (cur->w _sign_ cur->cliparg) / ((cur->w _sign_ cur->cliparg) - (next->w _sign_ next->cliparg));	\
														\
					if (alpha >= 0.0 && alpha <= 1.0) {	\
						vxheapnext->interp(cur, next, alpha);	\
						vxheapnext->cliparg = -(_sign_ vxheapnext->w);	\
						*dst++ = vxheapnext++;			\
					}									\
				}										\
				++src;									\
			}											\
			*dst = NULL;								\
			if (dst < vxnextheap+3) return NULL;		\
			src = vxlastheap; vxlastheap = vxnextheap; vxnextheap = src;	\
		}


		DOCLIP(Far, -, z);
		DOCLIP(Near, +, z);
		DOCLIP(Bottom, -, y);
		DOCLIP(Top, +, y);
		DOCLIP(Right, -, x);
		DOCLIP(Left, +, x);

#undef DOCLIP

		return vxlastheap;
	}

	void RenderClippedTri(VDPixmap& dst, const VDPixmap *const *pSources, int nMipmaps,
							const VDTriBltTransformedVertex *vx0,
							const VDTriBltTransformedVertex *vx1,
							const VDTriBltTransformedVertex *vx2,
							VDTriBltFilterMode filterMode,
							bool border,
							int orflags)
	{

		VDTriBltTransformedVertex *vxheapnext;
		VDTriBltTransformedVertex vxheap[21];

		VDTriBltTransformedVertex *vxheapptr[2][19];
		VDTriBltTransformedVertex **vxlastheap = vxheapptr[0], **vxnextheap = vxheapptr[1];

		vxheap[0]	= *vx0;
		vxheap[1]	= *vx1;
		vxheap[2]	= *vx2;

		vxlastheap[0] = &vxheap[0];
		vxlastheap[1] = &vxheap[1];
		vxlastheap[2] = &vxheap[2];
		vxlastheap[3] = NULL;

		vxheapnext = vxheap + 3;

		//	Current		Next		Action
		//	-------		----		------
		//	Unclipped	Unclipped	Copy vertex
		//	Unclipped	Clipped		Copy vertex and add intersection
		//	Clipped		Unclipped	Add intersection
		//	Clipped		Clipped		No action

#define	DOCLIP(cliptype, _sign_, cliparg)				\
		if (orflags & k##cliptype) {					\
			VDTriBltTransformedVertex **src = vxlastheap;		\
			VDTriBltTransformedVertex **dst = vxnextheap;		\
														\
			while(*src) {								\
				VDTriBltTransformedVertex *cur = *src;			\
				VDTriBltTransformedVertex *next = src[1];		\
														\
				if (!next)								\
					next = vxlastheap[0];				\
														\
				if (!(cur->outcode & k##cliptype))	\
					*dst++ = cur;						\
														\
				if ((cur->outcode ^ next->outcode) & k##cliptype) {	\
					double alpha = (cur->w _sign_ cur->cliparg) / ((cur->w _sign_ cur->cliparg) - (next->w _sign_ next->cliparg));	\
														\
					if (alpha >= 0.0 && alpha <= 1.0) {	\
						vxheapnext->interp(cur, next, alpha);	\
						vxheapnext->cliparg = -(_sign_ vxheapnext->w);	\
						*dst++ = vxheapnext++;			\
					}									\
				}										\
				++src;									\
			}											\
			*dst = NULL;								\
			if (dst < vxnextheap+3) return;				\
			src = vxlastheap; vxlastheap = vxnextheap; vxnextheap = src;	\
		}


		DOCLIP(Far, -, z);
		DOCLIP(Near, +, z);
		DOCLIP(Bottom, -, y);
		DOCLIP(Top, +, y);
		DOCLIP(Right, -, x);
		DOCLIP(Left, +, x);

#undef DOCLIP

		VDTriBltTransformedVertex **src = vxlastheap+1;

		while(src[1]) {
			RenderTri(dst, pSources, nMipmaps, vxlastheap[0], src[0], src[1], filterMode, border);
			++src;
		}
	}

}

bool VDPixmapTriFill(VDPixmap& dst, const uint32 c, const VDTriBltVertex *pVertices, int nVertices, const int *pIndices, int nIndices, const float pTransform[16]) {
	if (dst.format != nsVDPixmap::kPixFormat_XRGB8888)
		return false;

	static const float xf_ident[16]={1.f,0.f,0.f,0.f,0.f,1.f,0.f,0.f,0.f,0.f,1.f,0.f,0.f,0.f,0.f,1.f};
	std::vector<VDTriBltTransformedVertex>	xverts(nVertices);

	if (!pTransform)
		pTransform = xf_ident;

	TransformVerts(&xverts[0], pVertices, nVertices, pTransform, dst.w, dst.h);

	const VDTriBltTransformedVertex *xsrc = &xverts[0];

	VDTriClipWorkspace clipws;

	while(nIndices >= 3) {
		const int idx0 = pIndices[0];
		const int idx1 = pIndices[1];
		const int idx2 = pIndices[2];
		const VDTriBltTransformedVertex *xv0 = &xsrc[idx0];
		const VDTriBltTransformedVertex *xv1 = &xsrc[idx1];
		const VDTriBltTransformedVertex *xv2 = &xsrc[idx2];
		const int kode0 = xv0->outcode;
		const int kode1 = xv1->outcode;
		const int kode2 = xv2->outcode;

		if (!(kode0 & kode1 & kode2)) {
			if (int orflags = kode0 | kode1 | kode2) {
				VDTriBltTransformedVertex **src = VDClipTriangle(clipws, xv0, xv1, xv2, orflags);

				if (src) {
					VDTriBltTransformedVertex *src0 = *src++;

					// fan out triangles
					while(src[1]) {
						FillTri(dst, c, src0, src[0], src[1]);
						++src;
					}
				}
			} else
				FillTri(dst, c, xv0, xv1, xv2);
		}

		pIndices += 3;
		nIndices -= 3;
	}

	return true;
}

bool VDPixmapTriBlt(VDPixmap& dst, const VDPixmap *const *pSources, int nMipmaps,
					const VDTriBltVertex *pVertices, int nVertices,
					const int *pIndices, int nIndices,
					VDTriBltFilterMode filterMode,
					bool border,
					const float pTransform[16])
{
	if (dst.format != nsVDPixmap::kPixFormat_XRGB8888)
		return false;

	static const float xf_ident[16]={1.f,0.f,0.f,0.f,0.f,1.f,0.f,0.f,0.f,0.f,1.f,0.f,0.f,0.f,0.f,1.f};
	std::vector<VDTriBltTransformedVertex>	xverts(nVertices);

	if (!pTransform)
		pTransform = xf_ident;

	TransformVerts(&xverts[0], pVertices, nVertices, pTransform, dst.w, dst.h);

	const VDTriBltTransformedVertex *xsrc = &xverts[0];

	VDTriClipWorkspace clipws;

	while(nIndices >= 3) {
		const int idx0 = pIndices[0];
		const int idx1 = pIndices[1];
		const int idx2 = pIndices[2];
		const VDTriBltTransformedVertex *xv0 = &xsrc[idx0];
		const VDTriBltTransformedVertex *xv1 = &xsrc[idx1];
		const VDTriBltTransformedVertex *xv2 = &xsrc[idx2];
		const int kode0 = xv0->outcode;
		const int kode1 = xv1->outcode;
		const int kode2 = xv2->outcode;

		if (!(kode0 & kode1 & kode2)) {
			if (int orflags = kode0 | kode1 | kode2) {
				VDTriBltTransformedVertex **src = VDClipTriangle(clipws, xv0, xv1, xv2, orflags);

				if (src) {
					VDTriBltTransformedVertex *src0 = *src++;

					// fan out triangles
					while(src[1]) {
						RenderTri(dst, pSources, nMipmaps, src0, src[0], src[1], filterMode, border);
						++src;
					}
				}
			} else
				RenderTri(dst, pSources, nMipmaps, xv0, xv1, xv2, filterMode, border);
		}

		pIndices += 3;
		nIndices -= 3;
	}

	return true;
}

///////////////////////////////////////////////////////////////////////////

void VDPixmapSetTextureBorders(VDPixmap& px, bool wrap) {
	const int w = px.w;
	const int h = px.h;

	VDPixmapBlt(px, 0,   1,   px, wrap ? w-2 : 1, 1,              1, h-2);
	VDPixmapBlt(px, w-1, 1,   px, wrap ? 1 : w-2, 1,              1, h-2);

	VDPixmapBlt(px, 0,   0,   px, 0,              wrap ? h-2 : 1, w, 1);
	VDPixmapBlt(px, 0,   h-1, px, 0,              wrap ? 1 : h-2, w, 1);
}

///////////////////////////////////////////////////////////////////////////

VDPixmapTextureMipmapChain::VDPixmapTextureMipmapChain(const VDPixmap& src, bool wrap, int maxlevels) {
	int w = src.w;
	int h = src.h;
	int mipcount = 0;

	while((w>1 || h>1) && maxlevels--) {
		++mipcount;
		w >>= 1;
		h >>= 1;
	}

	mBuffers.resize(mipcount);
	mMipMaps.resize(mipcount);

	for(int mip=0; mip<mipcount; ++mip) {
		const int mipw = ((src.w-1)>>mip)+1;
		const int miph = ((src.h-1)>>mip)+1;

		mMipMaps[mip] = &mBuffers[mip];
		mBuffers[mip].init(mipw+2, miph+2, nsVDPixmap::kPixFormat_XRGB8888);

		if (!mip) {
			VDPixmapBlt(mBuffers[0], 1, 1, src, 0, 0, src.w, src.h);
		} else {
			const VDPixmap& prevmip = mBuffers[mip-1];

			VDPixmapStretchBltBilinear(mBuffers[mip], 1<<16, 1<<16, (mipw+1)<<16, (miph+1)<<16, prevmip, 1<<16, 1<<16, (prevmip.w-1)<<16, (prevmip.h-1)<<16);
		}
		VDPixmapSetTextureBorders(mBuffers[mip], wrap);
	}
}

