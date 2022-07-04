@echo off
goto 00_Start
###############################################################################

DEMO.BAT - demonstrate CMP software with the supplied sample files

To execute this demo, the sample files must be in the current directory.
Usage:
        DEMO
or:
        DEMO filename
If a filename is specified, the demo will run non-interactively and output will
be written to the named file. This is part of the actual regression tests.

2001-02-26  author: Stan Brown, Oak Road Systems
2001-02-27  Check free environment space and display a useful message.
            Offer the option to rerun each part of the demo.
2001-03-01  Allow an optional first parameter for redirecting all output.
2001-04-08  Add a demo of debugging output.
2001-12-16  Pause between command and output in demo #2.
2005-11-06  Add demos for the /J option and the - file.
            Ask users to choose 16-bit or 32-bit version.
            Replace CHOICE with TOURKEY for XP.
            Offer the option to quit when soliciting user input.
2005-11-08  If not interactive, assume cmp32 and don't ask.

              Copyright 2001-2006  Stan Brown, Oak Road Systems
                           http://oakroadsystems.com
###############################################################################
:00_Start
set G=0123456789012345678901234567890123456789
set X=0123456789012345678901234567890123456789
set G=
if "%X%" == "0123456789012345678901234567890123456789" goto 01_EnvOK
set X=
echo.
echo This demo needs about 80 bytes of free environment space, but
echo less than that is available. Try running it in a secondary shell
echo and specifying environment space, like this:
echo           %%comspec%% /e:8192 /c %0
echo The figure of 8192 is just an example. Use a large enough number,
echo which depends on how much environment space you are already using.
echo If you have a SHELL statement in C:\CONFIG.SYS use that number
echo plus 50 or so; otherwise try /e:1024.
echo.
goto 99_Exit
:01_EnvOK
set G=
if "%2" == "" goto 02_ParamsOK
echo.
echo You invoked this batch file with two or more parameters. In normal
echo use it takes no parameters; the only optional parameter is a file
echo name for output.
echo.
goto 99_Exit
:02_ParamsOK
if "%1" == "" cls
echo Welcome to this demo of the CMP program from Oak Road Systems.
set G=cmp32
if not "%1" == "" goto 03_CheckDir
echo.
echo You need about 100 KB (kilobytes, not megabytes) free space on
echo your disk. Also, the DOS program MORE.COM needs to be somewhere
echo in your PATH. If you have a normal DOS or WINDOWS installation,
echo the MORE program is already present in the right place.
echo.
echo Most users can use 32-bit CMP, which is recommended because it
echo copes with long filenames and because it can use all of Windows
echo memory. But if you're running in plain DOS, or in a DOS window
echo under Windows 3.x, you need the 16-bit version. (Both are in
echo Z file you downloaded.) 
echo.
tourkey /c:13q /n "Do you use the 16-bit or 32-bit program? [1/3/Quit] "
if errorlevel 3 go 90_Cleanup
if not errorlevel 2 set G=cmp16
:03_CheckDir
if not exist ALICE1 goto 09_WrongDir
if not exist ALICE2 goto 09_WrongDir
if not exist ALICE3 goto 09_WrongDir
if exist %G%.exe goto 10_CorrectDir
if exist ..\%G%.exe copy ..\%G%.exe >nul
if exist %G%.exe goto 10_CorrectDir
echo Can't find %G%.exe. Please make sure you are running from the
echo right directory (the one that contains the demo files). If you
echo have moved files after unpacking the zip file, please copy
echo %G%.exe to the current directory and run this demo again.
echo.
goto 99_Exit
:09_WrongDir
echo Before running this demo, you must first issue a 'CD' command to
echo get to the directory that contains the supplied demo files.
echo.
goto 99_Exit
:10_CorrectDir
if not exist CMPTEMP\* goto 15_MakeDir
echo The subdirectory CMPTEMP exists, probably left over from a
echo previous demo that was stopped in the middle.
tourkey /c:ny /n "Is it okay to delete it? "
if not errorlevel 2 goto 99_Exit
echo y|del CMPTEMP >nul
goto 16_CopyFiles
:15_MakeDir
md CMPTEMP
:16_CopyFiles
copy ALICE1 CMPTEMP\ALICE2 >nul
copy ALICE2 CMPTEMP\ALICE1 >nul
if "%1" == "" goto 20_BeginDemo
echo Output of "%0 %1" >%1
echo ====================================================================== >>%1
echo.>>%1
echo. | date >>%1
echo.>>%1
%G% -d- >>%1
echo.>>%1
echo.>>%1
:20_BeginDemo

if not "%1" == "" goto Demo1
echo.
echo.
echo NOTE: Every CMP command in this demo uses the /z option. That's
echo always a good idea in a batch file, so that any setting of the
echo environment variable is disregarded and the options in effect are
echo only those on the command line.
echo.
echo CMP options are marked with a leading / or - character, and can be
echo specified in capitals or lower case.
echo.
echo.
echo.
echo There are 8 parts to this demo; the last two parts cover new features
tourkey /c:nyq /n "in CMP 5.2.  Do you want to see ONLY new features? [Y/N/Quit] " 
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto End6
echo.
echo.
echo.
echo DEMO #1 (of 8 parts): A few differences in traditional and UNIX formats.
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End1
:Demo1
set X=%G% -z alice1 alice2
if "%1" == "" goto Mid1A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto :Mid1B
:Mid1A
echo %X%
pause
%X%|more
echo.
echo The above was traditional format, with line numbers on each line
echo reported. Now for UNIX format, which shows groups of lines as
echo added, changed, or deleted.
echo.
:Mid1B
set X=%X% -u
if "%1" == "" goto Mid1C
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo2
:Mid1C
echo %X%
pause
%X%|more
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo1
:End1

echo.
echo DEMO #2 (of 8 parts): multiple file compare
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End2
:Demo2
set X=%G% -z alice* CMPTEMP /a2f3
if "%1" == "" goto Mid2A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo3
:Mid2A
echo.
echo The /a2 option is used to limit reports to the first two differences.
echo The /f3 option displays line numbers right justified in 4 columns, so
echo that the reported lines all line up vertically.
echo.
echo %X%
echo.
pause
echo.
%X%|more
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo2
:End2

echo.
echo DEMO #3 (of 8 parts): binary file compare /R with formatting options
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End3
:Demo3
set X=%G% -z alice1 alice3 /rw40 /if4 /2
if "%1" == "" goto Mid3A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo4
:Mid3A
echo.
echo The /r option specifies comparing in binary mode. (It so happens that
echo the sample files are text, so the /R option disregards line boundaries.)
echo The /w40 option specifies blocks of 40 characters.
echo The /i opton suppresses differences between capitals and lower case.
echo The /f4 option displays line numbers right justified in 4 columns, so
echo that the reported lines all line up vertically.
echo The /2 option says to make the older file file 1 and the newer one file 2.
echo.
echo Non-printing characters will be shown as hex values in angle brackets.
echo.
echo %X%
pause
%X%|more
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo3
:End3

echo.
echo DEMO #4 (of 8 parts): resync /L,__
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End4
:Demo4
set X=%G% -z alice1 alice2 -u
if "%1" == "" goto Mid4A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Mid4B
:Mid4A
echo.
echo The resync value (second parameter on the /L option) can have a great
echo impact on the quality of the difference reports. Here is an illustration
echo of how the same compare can look different with different resync values.
echo (The user guide goes into a lot of detail about how you can set the resync
echo threshold to make more meaningful comparisons.)
echo.
echo First let's look at a compare with the default resync of 2. This value
echo is used by CMP unless you specify otherwise, and it's usually a
echo reasonable choice.
echo.
echo %X%
pause
%X%|more
echo.
echo Notice that the differences were reported in 9 difference blocks.
echo.
echo Now let's try that again with a resync of 1 (/L,1 option). (This is
echo how CMP behaved up through release 4.3.) Note that you will get a lot of
echo smaller difference blocks, 18 of them in fact.
echo.
:Mid4B
set X=%X% /L,1
if "%1" == "" goto Mid4C
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo5
:Mid4C
echo %X%
pause
%X%|more
echo.
echo For these particular files, the default resync of 2 was a better choice.
echo For other files, a different resync may be better. See the user guide
echo section "Difference Blocks and Look-Ahead" for more discussion of this
echo point.
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo4
:End4

echo.
echo DEMO #5 (of 8 parts): comparison options /B, /E, /I
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End5
:Demo5
set X=%G% -z alice1 alice2 -u
if "%1" == "" goto Mid5A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Mid5B
:Mid5A
echo.
echo Ordinarily, CMP compares files for exact equality. But you can tell it
echo to disregard added or deleted blank lines (/e option), differences of
echo capitals and lower case (/i option), and different runs of blanks or
echo tabs within a line (/b option). Depending on the file contents, this
echo will often cause CMP to report fewer differences.
echo.
echo First look at an exact comparison.
echo.
echo %X%
pause
%X%|more
echo.
echo You see there were 9 difference blocks, and the report was four screens
echo long (assuming a 25-line screen).
echo.
echo Now let's try that again with the /b, /e, and /i options.
:Mid5B
set X=%X% /bei
if "%1" == "" goto Mid5C
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Mid5D
:Mid5C
echo %X%
pause
%X%|more
echo.
echo This time you see that there were only 7 difference blocks, and
echo the report was about 25%% shorter. If it's appropriate for your
echo application, these options (or any of them) will suppress
echo nonessential differences.
echo.
echo.
echo When files compare identical and you've used an option to suppress
echo some kinds of differences, you get a different summary message. To
echo illustrate this, let's compare a file to itself, first without /E and
echo then with that option. Look at the different equality messages:
echo.
pause
:Mid5D
set X=%G% -z alice1 alice1
if "%1" == "" goto Mid5E
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Mid5F
:Mid5E
echo %X%
%X%
echo.
echo.
:Mid5F
set X=%X% /E
if "%1" == "" goto Mid5G
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo6
:Mid5G
echo %X%
%X%
echo.
echo As you can see, when you have an option to suppress some
echo differences CMP says that the files are "effectively identical"
echo rather than "identical".
echo.
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo5
:End5

echo.
echo DEMO #6 (of 8 parts): debugging output (long)
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End6
:Demo6
set X=%G% -z alice1 alice2 /ib /d-
if "%1" == "" goto Mid6A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo7
:Mid6A
echo.
echo The /d option turns on debugging output, to display the values of all
echo options, the files found (or expected but not found), and the internals
echo of the comparison process. To reduce the number of differences found
echo we'll use the /I option (ignore case) and the /B option (all runs of
echo blanks and tabs are equal).
echo.
echo Look for the messages "resync aborted". That is where, after a difference
echo between the two files, CMP finds two lines that match, but then another
echo difference within the resync threshold. (The user guide goes into a lot
echo of detail about how you can set the resync threshold to make more
echo meaningful comparisons, and there were more examples in Demo #4.)
echo.
echo %X%
pause
%X%|more
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo6
:End6

echo.
echo DEMO #7 (of 8 parts): /j option, new in CMP 5.2
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End7
:Demo7
set X=%G% -z alice1 alice3 /j2
if "%1" == "" goto Mid7A
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo7B
:Mid7A
echo.
echo The /j2 option tells CMP to display the lines that exist in file 2 and
echo aren't found in file 1. This can be handy when you have two versions of
echo a file, and you want to pass the added lines from the new version to
echo some other program. (You could use /j1 to find the lines that were
echo removed from file 1 to make file 2.)
echo.
echo %X%
pause
%X%
:Demo7B
set X=%X%*
if "%1" == "" goto Mid7B
echo ====================================================================== >>%1
echo %X% >>%1
echo ====================================================================== >>%1
%X% >>%1
echo. >>%1
echo. >>%1
goto Demo8
:Mid7B
echo.
echo As you see, the lines are shown with line numbers by default. Also, the
echo "comparing" header and summary footer are displayed as usual. If you're
echo passing file lines to another program, you probably don't want these.
echo.
echo To suppress line numbers, add an asterisk (*) to the /j option, as shown
echo below. This doesn't suppress the "comparing" header and the summary
echo footer, but they're written to stderr instead of stdout so that they
echo won't participate in redirection or piping.
echo.
echo Registered users can suppress the header and footer entirely by specifying 
echo the /q2 option or higher.
echo.
echo %X%
pause
%X%
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo7
:End7

echo.
echo DEMO #8 (of 8 parts): Comparison to standard input (stdin), new in CMP 5.2
tourkey /c:nyq /n "Do you want to see this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if not errorlevel 2 goto End8
:Demo8
set X=%G% -z alice1 - /1
if "%1" == "" goto Mid8A
echo ====================================================================== >>%1
echo type alice1 ! %X%   (using ! to symbolize vertical bar) >>%1
echo ====================================================================== >>%1
type alice1 | %X% >>%1
echo. >>%1
echo. >>%1
goto Demo9
:Mid8A
echo.
echo CMP lets you compare the output of a program to a reference file. To do
echo this, type the program command and on the same line type a vertical bar 
echo and your CMP command. In the CMP command, use a hyphen (-) to take input
echo piped from the earlier command on the line. 
echo.
echo This is handy when you have a benchmark for a known good version of the
echo program and you want to test that the new version of the program produces
echo the same output.
echo.
echo Here's a toy example, using the "type alice1" command and comparing its
echo output to reference file alice1; obviously they'll be identical. In real
echo life you'd have some more interesting command before the vertical bar.
echo.
pause
echo type alice1 ! %X%       (using ! to symbolize vertical bar)
type alice1 | %X%
echo.
echo Since the /1 option was specified, CMP returns 0 in ERRORLEVEL if the files
echo are identical and 1 if they're different. This can be tested in a batch
echo file with the IF ERRORLEVEL command (not shown here).
echo.
tourkey /c:nyq /n "Do you want to repeat this part of the demo? [Y/N/Quit] "
if errorlevel 3 goto 90_Cleanup
if errorlevel 2 goto Demo8
:End8

:Demo9

if not "%1" == "" goto 90_Cleanup
cls
echo.
echo.
echo This concludes the demo of CMP. Thanks for viewing!
echo.
echo The user guide should answer most of your questions, but if you can't
echo find your answers there please feel free to write to
echo                    support@oakroadsystems.com
echo Everyone's questions will be answered, but registered users receive
echo priority in support.
echo.

:90_Cleanup
if "%G%" == "" goto 91_Cleanup
if exist ..\%G%.exe del %G%.exe >nul
:91_Cleanup
if not exist CMPTEMP\* goto 99_Exit
echo y | del CMPTEMP >nul
rd CMPTEMP
set X=
set G=
:99_Exit
rem :: vim: ic tw=0 comments=n\:\:\:,n\:echo,n\:rem
