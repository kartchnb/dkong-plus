set SOURCE=dkong+.asm

set TASMTABS=..\tasm
..\tasm\tasm -c -b -fFF -g3 -t80 -l %SOURCE% bin\dkong.bin

..\tools\bin2hex bin\dkong.bin bin\temp /l4096 /i0
..\tools\hex2bin bin\temp bin\c_5et_g.bin
..\tools\bin2hex bin\dkong.bin bin\temp /l4096 /i4096
..\tools\hex2bin bin\temp bin\c_5ct_g.bin
..\tools\bin2hex bin\dkong.bin bin\temp /l4096 /i8192
..\tools\hex2bin bin\temp bin\c_5bt_g.bin
..\tools\bin2hex bin\dkong.bin bin\temp /l4096 /i12288
..\tools\hex2bin bin\temp bin\c_5at_g.bin
rm bin/temp

del mame\roms\dkong\c_5*.bin
copy bin\c_5*.bin ..\mame\roms\dkong

cd ..\mame
mamed dkong
cd ..\code