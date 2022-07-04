@if not exist pngs mkdir pngs
@if "%1"=="" goto badparm
@if "%2"=="" goto badparm
@if "%3"=="" goto nosound
@goto goodparms
:badparm
@echo This batch file requires 2 parameters, with a third optional parameter
@echo 1) input mng name
@echo 2) output avi name
@echo 3) input wav name (optional)
@goto end
:nosound
@rem delete old pngs
@del /Q pngs\png*.png
@mng2avi %1
@virtualdub\vdub /s"output.vdb" /x
@ren output.avi %2
@goto end
:goodparms
@if not exist pngs mkdir pngs
@if not exist %3 goto nosound
@rem delete old pngs
@del /Q pngs\png*.png    
@rem @mng2avi -log %1 -wav_name %3 -movieaudio 1
@mng2avi %1 -wav_name %3 -movieaudio 1 -moviesyncframes -20
@virtualdub\vdub /s"output.vdb" /x
@if exist %2 del /q %2
@ren output.avi %2
@del /Q output.vdb
:end
