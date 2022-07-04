#ifndef f_VIDEODISPLAY_H
#define f_VIDEODISPLAY_H

#include <windows.h>
#include <vd2/system/vectors.h>
#include <vd2/Kasumi/pixmap.h>

#define VIDEODISPLAYCONTROLCLASS (g_szVideoDisplayControlName)
extern const char g_szVideoDisplayControlName[];

class IVDVideoDisplay;

class VDINTERFACE IVDVideoDisplayCallback {
public:
	virtual void DisplayRequestUpdate(IVDVideoDisplay *pDisp) = 0;
};

class VDINTERFACE IVDVideoDisplay {
public:
	enum {
		kFormatPal8			= nsVDPixmap::kPixFormat_Pal8,
		kFormatRGB1555		= nsVDPixmap::kPixFormat_XRGB1555,
		kFormatRGB565		= nsVDPixmap::kPixFormat_RGB565,
		kFormatRGB888		= nsVDPixmap::kPixFormat_RGB888,
		kFormatRGB8888		= nsVDPixmap::kPixFormat_XRGB8888,
		kFormatYUV422_YUYV	= nsVDPixmap::kPixFormat_YUV422_YUYV,
		kFormatYUV422_UYVY	= nsVDPixmap::kPixFormat_YUV422_UYVY
	};

	enum FieldMode {
		kAllFields,
		kEvenFieldOnly,
		kOddFieldOnly,

		kVisibleOnly		= 16,

		kFieldModeMax		= 255
	};

	enum FilterMode {
		kFilterAnySuitable,
		kFilterPoint,
		kFilterBilinear,
		kFilterBicubic
	};

	virtual void Reset() = 0;
	virtual bool SetSource(bool bAutoUpdate, const VDPixmap& src, void *pSharedObject = 0, ptrdiff_t sharedOffset = 0, bool bAllowConversion = true, bool bInterlaced = false) = 0;
	virtual bool SetSourcePersistent(bool bAutoUpdate, const VDPixmap& src, bool bAllowConversion = true, bool bInterlaced = false) = 0;
	virtual void SetSourceSubrect(const vdrect32 *r) = 0;
	virtual void Update(int mode = kAllFields) = 0;
	virtual void PostUpdate(int mode = kAllFields) = 0;
	virtual void Cache() = 0;
	virtual void SetCallback(IVDVideoDisplayCallback *p) = 0;
	virtual void LockAcceleration(bool) = 0;
	virtual FilterMode GetFilterMode() = 0;
	virtual void SetFilterMode(FilterMode) = 0;
};

IVDVideoDisplay *VDGetIVideoDisplay(HWND hwnd);
bool VDRegisterVideoDisplayControl();

#endif
