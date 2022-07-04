@virtualdub\vdub /s"%1" /x
@if exist %2 del /q %2
@ren output.avi %2
:end
