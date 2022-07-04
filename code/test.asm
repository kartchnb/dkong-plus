; Disassembly of the file "dkong.bin"
; 
; CPU Type: Z80
; 
; Created with dZ80 2.0
; 
; on Saturday, 12 of February 2011 at 07:37 AM
; 

#include "vars.h"

;------------------------------------------------------------------------------
; Program entry point
l0000:  ld      a,00h                       ; Disable interrupts
        ld      (INTERRUPT_ENABLE),a        ; ''
;------------------------------------------------------------------------------

l0001:
        ld      HL,7740h                    ; HL = (26, 0)
        ld      (HL),11h                    ; 'A'
        inc     HL
        ld      (HL),12h                    ; 'B'
        inc     HL
        ld      (HL),13h                    ; 'C'
        jr      l0001
        .word   l0001
        .block  4096
        .end
