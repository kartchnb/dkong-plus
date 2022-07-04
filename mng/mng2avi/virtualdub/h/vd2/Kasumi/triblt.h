#ifndef f_VD2_KASUMI_TRIBLT_H
#define f_VD2_KASUMI_TRIBLT_H

#include <vector>
#include <vd2/Kasumi/pixmaputils.h>

struct VDTriBltVertex {
	float x, y, z, u, v;
};

enum VDTriBltFilterMode {
	kTriBltFilterPoint,
	kTriBltFilterBilinear,
	kTriBltFilterTrilinear,
	kTriBltFilterCount
};

bool VDPixmapTriFill(VDPixmap& dst, uint32 c,
					const VDTriBltVertex *pVertices, int nVertices,
					const int *pIndices, const int nIndices,
					const float pTransform[16] = NULL);

bool VDPixmapTriBlt(VDPixmap& dst, const VDPixmap *const *pSources, int nMipmaps,
					const VDTriBltVertex *pVertices, int nVertices,
					const int *pIndices, const int nIndices,
					VDTriBltFilterMode filterMode,
					bool border = false,
					const float pTransform[16] = NULL);

class VDPixmapTextureMipmapChain {
public:
	VDPixmapTextureMipmapChain(const VDPixmap& src, bool wrap=false, int maxlevels = 16);

	const VDPixmap *const *Mips() const { return &mMipMaps[0]; }
	int Levels() const { return mMipMaps.size(); }

protected:
	std::vector<VDPixmapBuffer>		mBuffers;
	std::vector<const VDPixmap *>	mMipMaps;
};

#endif
