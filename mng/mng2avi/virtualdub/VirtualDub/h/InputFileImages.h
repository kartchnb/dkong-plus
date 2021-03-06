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

#ifndef f_INPUTFILEIMAGES_H
#define f_INPUTFILEIMAGES_H

#include "InputFile.h"

class InputFileImages : public InputFile {
public:
	InputFileImages();
	~InputFileImages();

	void Init(const wchar_t *szFile);

	void setOptions(InputFileOptions *_ifo);
	InputFileOptions *createOptions(const char *buf);
	InputFileOptions *promptForOptions(HWND hwnd);

	void setAutomated(bool fAuto);

	void InfoDialog(HWND hwndParent);
};

#endif
