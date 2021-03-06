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

#include <stdio.h>
#include <stdarg.h>
#include <crtdbg.h>
#include <windows.h>
#include <vfw.h>

#include <vd2/system/vdtypes.h>
#include <vd2/system/Error.h>
#include <vd2/system/log.h>

MyError::MyError() {
	buf = NULL;
}

MyError::MyError(const MyError& err) {
	buf = strdup(err.buf);
}

MyError::MyError(const char *f, ...) {
	va_list val;

	va_start(val, f);
	vsetf(f, val);
	va_end(val);
}

MyError::~MyError() {
	delete[] buf;
}

void MyError::assign(const MyError& e) {
	delete[] buf;
	buf = strdup(e.buf);
}

void MyError::setf(const char *f, ...) {
	va_list val;

	va_start(val, f);
	vsetf(f,val);
	va_end(val);
}

void MyError::vsetf(const char *f, va_list val) {
	buf = new char[1024];
	if (buf) {
		buf[1023] = 0;
		_vsnprintf(buf, 1023, f, val);
	}
}

void MyError::post(HWND hWndParent, const char *title) const {
	if (!buf || !*buf)
		return;

	VDDEBUG("*** %s: %s\n", title, buf);
	VDLog(kVDLogError, VDswprintf(L"Error: %hs", 1, &buf));

	MessageBox(hWndParent, buf, title, MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
}

void MyError::discard() {
	buf = NULL;
}

void MyError::TransferFrom(MyError& err) {
	if (buf)
		free(buf);

	buf = err.buf;
	err.buf = NULL;
}

/////////////////////////////////////////////////////////////////////////////

static const char *GetVCMErrorString(DWORD icErr) {
	const char *err = "(unknown)";

	// Does anyone have the *real* text strings for this?

	switch(icErr) {
	case ICERR_OK:				err = "The operation completed successfully."; break;		// sorry, couldn't resist....
	case ICERR_UNSUPPORTED:		err = "The operation is not supported."; break;
	case ICERR_BADFORMAT:		err = "The source image format is not acceptable."; break;
	case ICERR_MEMORY:			err = "Not enough memory."; break;
	case ICERR_INTERNAL:		err = "An internal error occurred."; break;
	case ICERR_BADFLAGS:		err = "An invalid flag was specified."; break;
	case ICERR_BADPARAM:		err = "An invalid parameter was specified."; break;
	case ICERR_BADSIZE:			err = "An invalid size was specified."; break;
	case ICERR_BADHANDLE:		err = "The handle is invalid."; break;
	case ICERR_CANTUPDATE:		err = "Cannot update the destination image."; break;
	case ICERR_ABORT:			err = "The operation was aborted by the user."; break;
	case ICERR_ERROR:			err = "An unknown error occurred (may be corrupt data)."; break;
	case ICERR_BADBITDEPTH:		err = "The source color depth is not acceptable."; break;
	case ICERR_BADIMAGESIZE:	err = "The source image size is not acceptable."; break;
	default:
		if (icErr <= ICERR_CUSTOM) err = "A codec-specific error occurred.";
		break;
	}

	return err;
}

MyICError::MyICError(const char *s, DWORD icErr) {
	setf("%s error: %s (error code %ld)", s, GetVCMErrorString(icErr), icErr);
}

MyICError::MyICError(DWORD icErr, const char *format, ...) throw() {
	char tmpbuf[1024];

	va_list val;
	va_start(val, format);
	tmpbuf[sizeof tmpbuf - 1] = 0;
	_vsnprintf(tmpbuf, sizeof tmpbuf, format, val);
	va_end(val);

	setf(tmpbuf, GetVCMErrorString(icErr));
}

MyMMIOError::MyMMIOError(const char *s, DWORD mmioerr) {
	const char *err = "(Unknown)";

	switch(mmioerr) {
	case MMIOERR_FILENOTFOUND:		err = "file not found"; break;
	case MMIOERR_OUTOFMEMORY:		err = "out of memory"; break;
	case MMIOERR_CANNOTOPEN:		err = "couldn't open"; break;
	case MMIOERR_CANNOTCLOSE:		err = "couldn't close"; break;
	case MMIOERR_CANNOTREAD:		err = "couldn't read"; break;
	case MMIOERR_CANNOTWRITE:		err = "couldn't write"; break;
	case MMIOERR_CANNOTSEEK:		err = "couldn't seek"; break;
	case MMIOERR_CANNOTEXPAND:		err = "couldn't expand"; break;
	case MMIOERR_CHUNKNOTFOUND:		err = "chunk not found"; break;
	case MMIOERR_UNBUFFERED:		err = "unbuffered"; break;
	case MMIOERR_PATHNOTFOUND:		err = "path not found"; break;
	case MMIOERR_ACCESSDENIED:		err = "access denied"; break;
	case MMIOERR_SHARINGVIOLATION:	err = "sharing violation"; break;
	case MMIOERR_NETWORKERROR:		err = "network error"; break;
	case MMIOERR_TOOMANYOPENFILES:	err = "too many open files"; break;
	case MMIOERR_INVALIDFILE:		err = "invalid file"; break;
	}

	setf("%s error: %s (%ld)", s, err, mmioerr);
}

MyAVIError::MyAVIError(const char *s, DWORD avierr) {
	const char *err = "(Unknown)";

	switch(avierr) {
	case AVIERR_UNSUPPORTED:		err = "unsupported"; break;
	case AVIERR_BADFORMAT:			err = "bad format"; break;
	case AVIERR_MEMORY:				err = "out of memory"; break;
	case AVIERR_INTERNAL:			err = "internal error"; break;
	case AVIERR_BADFLAGS:			err = "bad flags"; break;
	case AVIERR_BADPARAM:			err = "bad parameters"; break;
	case AVIERR_BADSIZE:			err = "bad size"; break;
	case AVIERR_BADHANDLE:			err = "bad AVIFile handle"; break;
	case AVIERR_FILEREAD:			err = "file read error"; break;
	case AVIERR_FILEWRITE:			err = "file write error"; break;
	case AVIERR_FILEOPEN:			err = "file open error"; break;
	case AVIERR_COMPRESSOR:			err = "compressor error"; break;
	case AVIERR_NOCOMPRESSOR:		err = "compressor not available"; break;
	case AVIERR_READONLY:			err = "file marked read-only"; break;
	case AVIERR_NODATA:				err = "no data (?)"; break;
	case AVIERR_BUFFERTOOSMALL:		err = "buffer too small"; break;
	case AVIERR_CANTCOMPRESS:		err = "can't compress (?)"; break;
	case AVIERR_USERABORT:			err = "aborted by user"; break;
	case AVIERR_ERROR:				err = "error (?)"; break;
	}

	setf("%s error: %s (%08lx)", s, err, avierr);
}

MyMemoryError::MyMemoryError() {
	setf("Out of memory");
}

MyWin32Error::MyWin32Error(const char *format, DWORD err, ...) {
	char szError[1024];
	char szTemp[1024];
	va_list val;

	if (!FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
			0,
			err,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			szError,
			sizeof szError,
			NULL))
	{
		szError[0] = 0;
	}

	if (szError[0]) {
		long l = strlen(szError);

		if (l>1 && szError[l-2] == '\r')
			szError[l-2] = 0;
		else if (szError[l-1] == '\n')
			szError[l-1] = 0;
	}

	va_start(val, err);
	szTemp[sizeof szTemp-1] = 0;
	_vsnprintf(szTemp, sizeof szTemp, format, val);
	va_end(val);

	setf(szTemp, szError);
}

MyCrashError::MyCrashError(const char *format, DWORD dwExceptionCode) {
	const char *s = "(Unknown Exception)";

	switch(dwExceptionCode) {
	case EXCEPTION_ACCESS_VIOLATION:
		s = "Access Violation";
		break;
	case EXCEPTION_PRIV_INSTRUCTION:
		s = "Privileged Instruction";
		break;
	case EXCEPTION_INT_DIVIDE_BY_ZERO:
		s = "Integer Divide By Zero";
		break;
	case EXCEPTION_BREAKPOINT:
		s = "User Breakpoint";
		break;
	}

	setf(format, s);
}

MyUserAbortError::MyUserAbortError() {
	buf = strdup("");
}

MyInternalError::MyInternalError(const char *format, ...) {
	char buf[1024];
	va_list val;

	va_start(val, format);
	_vsnprintf(buf, sizeof buf, format, val);
	va_end(val);

	setf("Internal error: %s", buf);
}
