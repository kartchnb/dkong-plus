This file provides information about three separate but closely-related 
computer software products:

MNGPLG - An ActiveX control for displaying MNG animations in Internet 
         Explorer.
MNG4IE - A Netscape-style browser plug-in for viewing MNG animations.
MNGSV  - A simple standalone Windows application for viewing MNG 
         animations.

By Jason Summers  <jason1@pobox.com>
Version 1.0.8  Dec 2005
Web site: <http://entropymine.com/jason/mngctrl/>

The package in which you received this README file may not contain all of 
the software listed. All the software, along with source code, should be 
available at the above web site.


COPYRIGHT NOTICE

Copyright (c) 2000-2005 by Jason Summers

THIS SOFTWARE IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT 
ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR 
FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND 
PERFORMANCE OF THE SOFTWARE IS WITH YOU.  SHOULD THE SOFTWARE PROVE DEFECTIVE, 
YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL 
ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE 
THIS SOFTWARE AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING 
ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE 
USE OR INABILITY TO USE THIS SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF 
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD 
PARTIES OR A FAILURE OF THIS SOFTWARE TO OPERATE WITH ANY OTHER PROGRAMS), 
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF 
SUCH DAMAGES.

Permission is granted to anyone to use this software for any purpose, 
including commercial applications, and to alter it and redistribute it 
freely, subject to the following restrictions:

 1. The origin of this source code must not be misrepresented;
    you must not claim that you wrote the original software.

 2. Altered source or binary versions must be plainly marked as such, and 
    must not be misrepresented as being the original.

 3. This Copyright notice may not be removed or altered from any source
    or altered source distribution, although you may add a Copyright
    notice for yourself for any code that you have written.


This software uses several third-party libraries (listed below), some of which 
are optional. If you redistribute binary versions of MNG4IE, MNGPLG, or MNGSV, 
it is your responsibility to comply with the licenses of any libraries used.

---------

Based on libmng.
   Copyright (c) 2000-2005 Gerard Juyn (gerard@libmng.com)
   <http://www.libmng.com/>

Uses the zlib compression library.
   (C) 1995-2005 Jean-loup Gailly and Mark Adler

This software is based in part on the work of the Independent JPEG Group.
   Copyright (C) 1991-1998, Thomas G. Lane

Uses the Little cms color management library by Marti Maria.
   Copyright (C) 1998-2005 Marti Maria


---------

A NOTE ABOUT SECURITY

Although I've tried to write it carefully, this software has not had any sort of 
serious security audit. Due to the nature of plug-ins and ActiveX controls when 
used in web browsers, it is possible for certain types of bugs to exist which 
may allow remote web sites to take control of your computer or do harm to it by 
sending a carefully constructed malicious data file to the software. If you are 
paranoid about security, you may not wish to leave this software installed for 
an extended period of time.

---------

REQUIREMENTS

All programs require a 32-bit Windows operating system (Windows 95 or 
higher).

MNG4IE requires Internet Explorer 4.0 or higher. It requires that your IE 
security settings be set low enough to run ActiveX controls (the default 
settings are sufficiently low).

MNGPLG requires a 32-bit web browser that supports Netscape-style 
plug-ins, such as Netscape, Mozilla, Firefox, or Opera.


------------
INSTRUCTIONS
------------
Skip to the section about the application you're using.


----------
  MNG4IE
----------

INTRODUCTION

MNG4IE is a free ActiveX control which displays the MNG image/animation 
format. It is specifically designed for use in Microsoft's Internet 
Explorer web browser. It configures itself to handle the following MIME 
types:

 video/x-mng
 video/mng
 image/x-jng
 image/jng

For best results, documents to be viewed should have the file extension 
".mng" or ".jng".

It can also display PNG image files, but it would cause too many problems 
for it to try to take over the PNG data type.

If you are configuring a web server to support MNG and JNG, the correct
MIME types to use are "video/x-mng" and "image/x-jng", since the MIME types
have not, as of this writing, been officially registered.


INSTALLATION

MNG4IE is distributed in a ZIP file. It can be installed by extracting the 
mng4ie.dll file to some permanent location on your hard disk, and running 
the "regsvr32.exe" utility on it. For example, create a new folder at 
"C:\Program Files\MNG4IE", unzip the "mng4ie.dll", "reg.bat", and 
"unreg.bat" into that folder, then run reg.bat.


UNINSTALLATION - If you installed manually from the ZIP file

Run "regsvr32.exe /u mng4ie.dll", or run the unreg.bat file. Then, if you 
wish, delete the files you unzipped.


UNINSTALLATION - If you auto-installed via the web

Some earlier versions of MNG4IE were distributed in a CAB file which 
allowed for auto-installation. This is no longer offered, because new 
versions of Internet Explorer are becoming less willing to allow this 
(unless the CAB file is signed with a code-signing certificate, but I 
don't have one of those).

If you installed MNG4IE in this way, from IE's menu select "Tools" -> 
"Internet Options" -> "Temporary Internet Files : Settings" -> "View 
Objects", right click on the "MNG4IE" item, and select "Remove" from the 
menu.


HOW TO USE (FOR END USERS)

Right-click on an MNG image as it is being displayed to get a menu with 
some of the usual features.

Right-click and choose "Properties" to display some internal information
about the image. Some images have embedded text information that will be
shown in the "Image comments" area. For technical reasons, some or all of
the comments may not be available until the animation completes a full loop.


HOW TO USE (FOR WEB DEVELOPERS)

First, if at all possible, configure your web server (not browser) to 
assign the MIME type "video/x-mng" to files that end in ".mng", and
assign type "image/x-jng" to files that end in ".jng".

One way to embed MNG files in a web is to use the nonstandard <embed> tag. 
For example:

  <embed src="foo.mng" width="100" height="100" type="video/x-mng">

Or instead, you can instead use IE's nonstandard version of the <object> 
tag. This example enforces the use of MNG4IE (rather than some other MNG 
viewer).

  <object width=100 height=100
    classid="CLSID:99715EC0-AAFD-11D6-A49D-4D4E47344945">
   <param name="src" value="foo.mng">
  </object>


True transparency is not supported, although the background color of the
web page will be used when possible. If you want to use a different
background color in the transparent areas, you can you can supply a
specify a color by using the BGCOLOR attribute in the EMBED tag, i.e.:
  <embed src="foo.mng" bgcolor="#ff0000"  ...>

or in a PARAM tag:
  ... <param name="bgcolor" value="#ff0000"> ...

You cannot use color names like "red"; you must use the hexadecimal format 
as in the example.

An image can be made into a "hotlink" by including an HREF parameter and 
optionally a TARGET attribute. For example:

  <embed src="foo.mng" href="http://www.libpng.org/pub/mng/"
   target="_blank" ...>

[The "target" attribute doesn't seem to work quite right, however.]


MNG4IE also has (very limited) scripting capability. Currently it offers 
just one property and one method:

 * property "Version" (read-only), which returns an integer
     representing the version number
 * method "Animate()": call Animate(0) to freeze the animation,
     and Animate(1) to resume the animation.


HISTORY

v1.0.6+
* See HISTORY (1.0.6+) section below.

v1.0.5
* Updated binary to libmng 1.0.5 and lcms 1.10.
* Source code merged with MNGPLG and MNGSV.
* Unicode support is probably badly broken.

v1.0.4
* Updated binary to libmng 1.0.5rc3.
* More-aggressively registers itself with Windows.

v1.0.3
* Updated binary to libmng 1.0.5b3.

v1.0.2
* Fixed some timer-related bugs that may have been causing crashes.
* Updated binary to libmng 1.0.5b2.

v1.0.1:
* Updated binary to libmng 1.0.5b1 and lcms 1.09b.
* Added support for the experimental (nonstandard) "Dynamic MNG" feature
  available in the new version of libmng.
* Partial transparency support. Supports solid background colors, but not
  background images.
* Rearranged the "About"/"Image Comments" dialog boxes.
* Source code is mostly Unicode-compatible.

v1.0.0:
* Initial release.


------------
   MNGPLG
------------

INTRODUCTION

NOTE: Some versions of Mozilla-based web browsers (e.g. Netscape 6+) have 
native MNG support. At the time of this writing, it is not clear whether 
future versions of Mozilla-based browsers will have native MNG support or 
not. It may not be possible to use MNGPLG in browsers that have native MNG 
support.

MNGPLG is a Netscape-style browser plug-in which displays the MNG 
image/animation format. It is configured to claim the following MIME types:

 video/x-mng
 video/mng
 image/x-jng
 image/jng

It claims the file extensions ".mng" and ".jng", but file extensions should 
only apply when no MIME type is available (e.g. on an FTP site, or on your 
local hard disk).

It can also display PNG image files, but it would cause too many problems 
for it to try to claim the PNG data type.

If you are configuring a web server to support MNG and JNG, the correct
MIME types to use are "video/x-mng" and "image/x-jng", since the MIME types
have not, as of this writing, been officially registered.


INSTALLATION

There's no install program. To install it, copy the included "npmngplg.dll" 
file to your browser's "Plugins" folder, then restart your browser.

For Netscape 4.x, the Plugins folder is typically located somewhere like:
C:\Program Files\Netscape\Communicator\Program\Plugins

Note: Windows Explorer, by default, is configured to hide files that end in 
".dll". You should probably change that setting. I'd tell you how, but it's 
different in almost every version of Windows.

In Netscape 4.x, you can verify that the plug-in is installed by choosing 
Help|About Plug-ins from the main menu (with JavaScript enabled).

To uninstall, delete the npmngplg.dll file. It does not create any other 
files. It currently does not write anything to the Windows registry.


HOW TO USE (FOR END USERS)

Right-click on an MNG image as it is being displayed to get a menu with some 
of the usual features.

Right-click and choose "Properties" to display some internal information
about the image. Some images have embedded text information that will be
shown in the "Image comments" area. For technical reasons, some or all of
the comments may not be available until the animation completes a full loop.


HOW TO USE (FOR WEB DEVELOPERS)

First, if at all possible, configure your web server (not browser) to 
assign the MIME type "video/x-mng" to files that end in ".mng", and
assign type "image/x-jng" to files that end in ".jng".

The most reliable way to embed MNG files in a web page is (unfortunately)
to use the  nonstandard <embed> tag. For example:

<embed src="foo.mng" width="100" height="100" type="video/x-mng">

The src, width, and height attributes are required. Width and height should 
match the actual width and height of the image.

Standards-compliant browsers also support the <object> tag:

<object data="foo.mng" width="100" height="100" type="video/x-mng">
</object>

Transparency is not supported, and may never be. However, you can supply a 
background color to use in transparent areas by using the BGCOLOR 
attribute in the EMBED tag, i.e.:

<embed src="foo.mng" bgcolor="#ff0000"  ...>

You cannot use color names like "red"; you must use the hexadecimal format 
as in the example.

An image can be made into a "hotlink" by including an HREF and optionally a 
TARGET attribute in the EMBED tag. For example:

<embed src="foo.mng" href="http://www.libpng.org/pub/mng/" target="_blank" 
...>


HISTORY

v1.0.6+
* See HISTORY (1.0.6+) section below.

v1.0.5
* Updated binary to libmng 1.0.5 and lcms 1.10.
* Source code merged with MNG4IE and MNGSV.

v1.0.4
* Updated binary to libmng 1.0.5rc3.

v1.0.3
* Updated binary to libmng 1.0.5b3.

v1.0.2
* Fixed a timer-related bug

v1.0.1
* Updated to use libmng 1.0.5b1.
* Added support for libmng's new "Dynamic MNG" feature. 

v1.0.0
* Updated to use libmng 1.0.4. 
* Fixed a bug introduced in v0.9.4(?) that might cause a crash in rare
  circumstances in some versions of Windows. 
* Set default background color to be white. 
* Some other minor changes. 

v0.9.4
* Updated binary to use libmng 1.0.3 and lcms 1.08a and zlib 1.1.4. 
* Use mng_set_outputsrgb() instead of more-complicated color profile
  code. 
* Removed dependency on Netscape plug-in SDK. 
* Some source code cleanup. 

v0.9.3
* The included binary has been updated to use libmng 1.0.0. 

v0.9.2
* The included binary has been updated to use libmng 0.9.3. 
* New feature to display text comments in MNG files. 

v0.9.1
* This is a very minor revision. The only change worth mentioning
  is a fix for an incompatibility with recent versions of Opera.

v0.9.0
* I've bumped up the version number to 0.9 because it now has
  essentially all the features that I consider necessary for v1.0,
  but it's really not that much different from v0.4.x.
* Ability to freeze/unfreeze the animation. 
* Scroll bars when in full-page mode. 
* Errors in the MNG file no longer pop up dialog boxes. 

v0.4.1
* There are no feature changes. It has been updated to use the very
  latest developer version of libmng, which corrects a few problems with
  viewing some MNG images. 

v0.4.0
* Allows you to make MNG images into links by putting "HREF=..." in the
  EMBED tag. 
* A Stop Animation function on the right-click menu. 
* Some other little things I've forgotten about.... 

v0.3.0
* Progressive display. Starts to display images before the entire file
  is downloaded. 
* Supports printing when embedded in a web page (provided your browser
  supports this). 
* Better color correction (sRGB) 
* The BGCOLOR attribute works now. 
* More error checking. Perhaps too much. It may pop up dialog boxes when
  it finds a problem with an image, which is probably a bad thing to do,
  but it should help in testing. 


-------------
MNGSV
-------------

INSTALLATION

There's no install program. To install it, put mngsv.exe somewhere on your 
hard disk. You may wish to associate '.mng' and '.jng' files with it.

HOW TO USE

Hopefully it's self-explanatory. This is a minimal MNG viewer, without a 
lot of features.

HISTORY

v1.0.6+
* See HISTORY (1.0.6+) section below.

v1.0.5
* Initial release.


-------------

HISTORY (1.0.6+, all applications)

v1.0.8 (Dec. 2005)
* Updated binary to zlib 1.2.3 and lcms 1.15.
* MNG4IE didn't work in some cases where the document was uncacheable
  and served via SSL. This has hopefully been fixed.

v1.0.7 (Nov. 2004)
* Updated binary to libmng 1.0.8 and lcms 1.13.

v1.0.6
* Updated binary to libmng 1.0.8alpha.


-------------

SOURCE CODE

The C/C++ source code is included.

MNG4IE is an ATL ActiveX control, and requires ATL 3.0 (or higher?). I think 
that means it pretty much requires Microsoft Visual C++ 6.0 or higher. For 
example, it will not compile with ATL 2.x, which is what is included with 
MSVC++ 5. It's possible that it could be compiled by other C++ compilers, 
but I expect that will be difficult.

MNGPLG and MNGSV require no special toolkits, beyond the standard Windows SDK.

To compile the software, you'll also need:

- libmng MNG library <http://www.libmng.com/>. I've mostly tested it with 
version 1.0.5-1.0.8, but it should also be compatible with other versions, maybe 
with minor changes.

libmng in turn uses some other libraries:

    - zlib compression library

    - [optional] IJG JPEG library

    - [optional] lcms "Little Color Management System" library. 

If you include lcms, turn on the MNG_FULL_CMS option in libmng_conf.h (or 
define MNG_FULL_CMS in your project settings) before compiling.

If you don't include lcms, comment out the "#define MNGCTRL_CMS" line in 
mngctrl.h.

I also recommend turning on the MNG_ERROR_TELLTALE and 
MNG_SUPPORT_DYNAMICMNG options in libmng_conf.h or your libmng project 
settings.

