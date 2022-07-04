; Disassembly of the file "C:\MAME\roms\c_5et_g.bin"
; 
; CPU Type: Z80
; 
; Created with dZ80 2.0
; 
; on Friday, 04 of May 2001 at 01:51 AM
; 
;----------------------------------
; Program entry point
0000 3E00      LD      A,00H		 ; Disable interrupts
0002 32847D    LD      (intEnable),A ; 	''
0005 C36602    JP      InitializeGame
;----------------------------------


;----------------------------------
; Return from the calling function if 
; the demo mode is active (demoMode == 1)
ReturnIfDemoMode:
0008 3A0760    LD      A,(demoMode); A = demoMode 
000b 0F        RRCA                ; Return if demoMode == 0
000c D0        RET     NC          ;    ''
000d 33        INC     SP          ; Return from the calling function
000e 33        INC     SP          ;    if demoMode == 1
000f C9        RET                 ;    ''
;----------------------------------  



;----------------------------------
; Return from the calling function if
; marioAlive is dead
ReturnIfMarioDead:
0010 3A0062    LD      A,(marioAlive); A = marioAlive
0013 0F        RRCA                 ; Return if marioAlive == 1 
0014 D8        RET     C            ;    ''
0015 33        INC     SP           ; Return from calling function
0016 33        INC     SP           ;    if marioAlive == 0
0017 C9        RET                  ;    ''
;----------------------------------



;----------------------------------
; Decrement minorTimer and return from 
; calling function if it has not
; reached 0.
ReturnIfNotMinorTimeout:
0018 210960    LD      HL,minorTimer
001b 35        DEC     (HL)
001c C8        RET     Z
001d 33        INC     SP
001e 33        INC     SP
001f C9        RET     
;----------------------------------



;----------------------------------
; Decrement majorTimer.  If it has not
; reached 0, return from the calling
; function. 
; If it has reached 0, decrement minorTimer
; and return from the calling function
; if it has not reached 0.
ContinueWhenTimerReaches0:
0020 210860    LD      HL,majorTimer
0023 35        DEC     (HL)
0024 28F2      JR      Z,ReturnIfNotMinorTimeout
0026 E1        POP     HL
0027 C9        RET     
;----------------------------------



;----------------------------------
; Look up an address in a local table 
; and jump to it.
; The table is expected to be located
; immediately after the command that 
; called this function.
; passed: A - table index
JumpToLocalTableAddress:
0028 87        ADD     A,A        ; A = table offset 
0029 E1        POP     HL         ; HL = the address this function was called from
002a 5F        LD      E,A        ; DE = table offset
002b 1600      LD      D,00H      ;    ''
002d C33200    JP      0032H      ; Skip next instruction

; (The following instruction is not part of this function)
ReturnUnlessStageOfInterest:
0030 1812      JR      ReturnUnlessStageOfInterest1 ; Continued further down

0032 19        ADD     HL,DE      ; HL = address of table entry
0033 5E        LD      E,(HL)     ; DE = entry in table
0034 23        INC     HL         ;    ''
0035 56        LD      D,(HL)     ;    ''
0036 EB        EX      DE,HL      ; HL = entry in table
0037 E9        JP      (HL)       ; Jump to the address from the table
;---------------------------------



;---------------------------------
; Adds the value in C to every 4th byte
; in a 40 byte block starting at the
; address in HL
; passed: C, HL
MoveDKSprites:
0038 110400    LD      DE,0004H   ; DE = 4
003b 060A      LD      B,0AH      ; For B = 10 to 1
003d 79        LD      A,C        ; A = C
003e 86        ADD     A,(HL)     ; A += (HL)
003f 77        LD      (HL),A     ; (HL) = A
0040 19        ADD     HL,DE      ; HL += 4
0041 10FA      DJNZ    003DH      ; Next B
0043 C9        RET     
;---------------------------------



;----------------------------------
; Return from the calling function
; unless bit N is set in A, where
; N = current stage number.
; passed: A - stage bitmask
ReturnUnlessStageOfInterest1:
0044 212762    LD      HL,currentStage ; HL = address of currentStage
0047 46        LD      B,(HL)      ; B = currentStage
0048 0F        RRCA                ; Shift A right B times
0049 10FD      DJNZ    0048H       ; Next B
004b D8        RET     C           ; Return if carry is set
004c E1        POP     HL          ; Return from calling function if...
004d C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Copy DK sprites from ROM address
; to DK sprite variables
; passed: Source address in HL
LoadDKSprites:
004e 110869    LD      DE,dkSprite1X ; Dest. address = dkSprite1X
0051 012800    LD      BC,0028H    ; 40 bytes to copy
0054 EDB0      LDIR                ; Block copy
0056 C9        RET                 ; Done
;---------------------------------- 



;----------------------------------
; Update random number
; The random number is updated by adding 
; counter1 and counter2 to the current 
; random number.
UpdateRandomNumber:
0057 3A1860    LD      A,(randNumber) ; A = randNumber
005a 211A60    LD      HL,counter1 ; Add counter1 to randNumber
005d 86        ADD     A,(HL)      ;    ''
005e 211960    LD      HL,counter2 ; Add counter2 to randNumber
0061 86        ADD     A,(HL)      ;    ''
0062 321860    LD      (randNumber),A ; Resave randNumber
0065 C9        RET                 ; Done
;----------------------------------

  

;----------------------------------
; Interrupt handler
InteruptHandler:
0066 F5        PUSH    AF          ; Push registers onto stack
0067 C5        PUSH    BC
0068 D5        PUSH    DE
0069 E5        PUSH    HL
006a DDE5      PUSH    IX
006c FDE5      PUSH    IY

006e AF        XOR     A           ; Disable interrupts
006f 32847D    LD      (intEnable),A ;	''

; Abort if the game is being tampered with?
0072 3A007D    LD      A,(IN2)    ; If Bit 0 of (IN2)
0075 E601      AND     01H        ;    is 0, abort game
0077 C20040    JP      NZ,4000H   ;    (tamper protection?)

; Configure P8257
007a 213801    LD      HL,P8257RegisterData
007d CD4101    CALL    SetP8257Registers

; Skip player stuff if in demoMode
0080 3A0760    LD      A,(demoMode) ; A = demoMode
0083 A7        AND     A          ; If demoMode == 1
0084 C2B500    JP      NZ,00B5H   ;    jump to 00B5H 

; Ignore player 2 input if this is an upright cab
0087 3A2660    LD      A,(cabType) ; If this is an upright cab
008a A7        AND     A          ;    skip ahead 
008b C29800    JP      NZ,0098H   ;    ''

; Get player 2 input
008e 3A0E60    LD      A,(player2Active) ; Check if player 2 is active
0091 A7        AND     A          ;    ''
0092 3A807C    LD      A,(IN1)    ; A = player 2 input
0095 C29B00    JP      NZ,009BH   ; Skip ahead if player 2 is active

; Get player 1 input
0098 3A007C    LD      A,(IN0)    ; A = player 1 input

; Prevent the jump button from being
; processed more than once.
009b 47        LD      B,A        ; B = player input
009c E60F      AND     0FH        ; Mask out all but direction bits in A
009e 4F        LD      C,A        ; C = direction bits
009f 3A1160    LD      A,(prevPlayerInput) ; A = previous input
00a2 2F        CPL                ; invert previous input
00a3 A0        AND     B          ; Mask out repeat input bits
00a4 E610      AND     10H        ; Mask out all but jump bit
00a6 17        RLA                ; Shift jump bit to MSB (7)
00a7 17        RLA                ;    ''
00a8 17        RLA                ;    ''
00a9 B1        OR      C          ; Restore direction bits
00aa 60        LD      H,B        ; H = original input
00ab 6F        LD      L,A        ; L = filtered input
00ac 221060    LD      (playerInput),HL ; save playerInput (L) and prevPlayerInput (H)

; Reset game if reset bit is set
00af 78        LD      A,B        ; A = player input
00b0 CB77      BIT     6,A        ; Reset if reset bit is set
00b2 C20000    JP      NZ,0000H   ;    ''

00b5 211A60    LD      HL,counter1; Decrement counter1 on every interrupt
00b8 35        DEC     (HL)       ;    ''
00b9 CD5700    CALL    UpdateRandomNumber
00bc CD7B01    CALL    CoinHandler
00bf CDE000    CALL    PlaySounds
00c2 21D200    LD      HL,00D2H   ; Push 00D2H onto the stack
00c5 E5        PUSH    HL         ;    ''
; Jump to one of the entries in the following
; table based on the current game mode
00c6 3A0560    LD      A,(gameMode) ; A = gameMode
00c9 EF        RST     JumpToLocalTableAddress ; Jump to one of the following addresses
00ca C301 ; 0 = PrepareDemoMode 
00cc 3C07 ; 1 = ActivateDemoMode
00ce B208 ; 2 = StartGame
00d0 FE06 ; 3 = DisplayCurrentGameScreen
;----------------------------------



;----------------------------------
00d2 FDE1      POP     IY         ; Pop registers from stack
00d4 DDE1      POP     IX
00d6 E1        POP     HL
00d7 D1        POP     DE
00d8 C1        POP     BC
00d9 3E01      LD      A,01H      ; Reenable interrupts
00db 32847D    LD      (intEnable),A ; ''
00de F1        POP     AF         ; Pop AF register from stack
00df C9        RET                ; Done
;---------------------------------

  

;---------------------------------
; Play sounds and music
PlaySounds:
00e0 218060    LD      HL,marioWalking ; HL = address of marioWalking
00e3 11007D    LD      DE,walkSoundTrigger ; DE = address of walkSoundTrigger
00e6 3A0760    LD      A,(demoMode) ; A = demoMode
00e9 A7        AND     A          ; Return
00ea C0        RET     NZ         ;    if in demo mode

00eb 0608      LD      B,08H      ; For B = 8 to 1
Label00ED:
00ed 7E        LD      A,(HL)     ; A = next sound effect
00ee A7        AND     A          ; If sound is done playing
00ef CAF500    JP      Z,Label00F5 ;    don't trigger it

00f2 35        DEC     (HL)       ; Decrement sound duration
00f3 3E01      LD      A,01H      ; A = 1

Label00F5:
00f5 12        LD      (DE),A     ; Turn sound on or off
00f6 1C        INC     E          ; DE = next sound trigger
00f7 2C        INC     L          ; HL = next sound effect
00f8 10F3      DJNZ    Label00ED  ; Next B

00fa 218B60    LD      HL,currentSongDuration ; HL = address of currentSongDuration
00fd 7E        LD      A,(HL)     ; A = currentSongDuration
00fe A7        AND     A          ; If the song should be playing
00ff C20801    JP      NZ,Label0108 ;    jump ahead

0102 2D        DEC     L          ; HL = address of timeRunningOut
0103 2D        DEC     L          ;    ''
0104 7E        LD      A,(HL)     ; A = (timeRunningOut)
0105 C30B01    JP      Label010B  ; Jump ahead

Label0108:
0108 35        DEC     (HL)       ; Decrement music duration
0109 2D        DEC     L          ; HL = address of currentSong
010a 7E        LD      A,(HL)     ; A = currentSong
 
Label010B:
010b 32007C    LD      (music),A  ; Trigger current song
010e 218860    LD      HL,6088H   ; HL = 6088H
0111 AF        XOR     A          ; A = 0
0112 BE        CP      (HL)       ; if (6088H) == 0
0113 CA1801    JP      Z,Label0118 ;    jump ahead
0116 35        DEC     (HL)       ; --(6088H)
0117 3C        INC     A          ; A = 1

Label0118:
0118 32807D    LD      (7D80H),A  ; (7D80H) = 1 or 0
011b C9        RET                ; Done
;----------------------------------



;----------------------------------
; Turn Off sounds and music
TurnSoundsOff:
011c 0608      LD      B,08H      ; For B = 1 to 8
011e AF        XOR     A          ; A now contains 0
011f 21007D    LD      HL,7D00H   ; Digital sound trigger (walk) address 
0122 118060    LD      DE,6080H   ; RAM address
Label0125:
0125 77        LD      (HL),A     ; Turn off sound
0126 12        LD      (DE),A     ; Write 0 to memory address
0127 2C        INC     L          ; Iterate over all 8 sound triggers
0128 1C        INC     E          ; Iterate over all 8 sound effects
0129 10FA      DJNZ    Label0125  ; Next B

012b 0604      LD      B,04H      ; For B = 1 to 4
Label012D:
012d 12        LD      (DE),A     ; Write 0 to memory address
012e 1C        INC     E          ; Iterate over all song variables
012f 10FC      DJNZ    Label012D  ; Next B

0131 32807D    LD      (7D80H),A  ; Turn off death sound
0134 32007C    LD      (music),A  ; Turn off background music
0137 C9        RET    
;---------------------------------- 



;---------------------------------- 
; P8257 control register settings
P8257RegisterData:
0138 53 ; Sent to 7808H
0139 00 ; Sent to 7800H
013a 69 ; Sent to 7800H
013b 80 ; Sent to 7801H
013c 41 ; Sent to 7801H
013d 00 ; Sent to 7802H
013e 70 ; Sent to 7802H
013f 80 ; Sent to 7803H
0140 81 ; Sent to 7803H
;---------------------------------- 



;---------------------------------
; Set P8257 control registers
; passed: HL = 0138H
SetP8257Registers:
0141 AF        XOR     A          ; A = 0
0142 32857D    LD      (toggle0_1),A ; Set 0/1 toggle to 0
0145 7E        LD      A,(HL)     ; A = 53H (0138H)
0146 320878    LD      (7808H),A  ; P8257 register = 53H
0149 23        INC     HL         ; HL = 0139H
014a 7E        LD      A,(HL)     ; A = 00H
014b 320078    LD      (7800H),A  ; P8257 register = 00H
014e 23        INC     HL         ; HL = 013AH
014f 7E        LD      A,(HL)     ; A = 69H
0150 320078    LD      (7800H),A  ; P8257 register = 69H
0153 23        INC     HL         ; HL = 013BH
0154 7E        LD      A,(HL)     ; A = 80H
0155 320178    LD      (7801H),A  ; P8257 register = 80H
0158 23        INC     HL         ; HL = 013CH
0159 7E        LD      A,(HL)     ; A = 41H
015a 320178    LD      (7801H),A  ; P8257 register = 41H
015d 23        INC     HL         ; HL = 013DH
015e 7E        LD      A,(HL)     ; A = 00H
015f 320278    LD      (7802H),A  ; P8257 register = 00H
0162 23        INC     HL         ; HL = 013EH
0163 7E        LD      A,(HL)     ; A = 70H
0164 320278    LD      (7802H),A  ; P8257 register = 70H
0167 23        INC     HL         ; HL = 013FH
0168 7E        LD      A,(HL)     ; A = 80H
0169 320378    LD      (7803H),A  ; P8257 register = 80H
016c 23        INC     HL         ; HL = 0140H
016d 7E        LD      A,(HL)     ; A = 81H
016e 320378    LD      (7803H),A  ; P8257 register = 81H
0171 3E01      LD      A,01H      ; A = 1
0173 32857D    LD      (toggle0_1),A ; 0/1 toggle = 1
0176 AF        XOR     A
0177 32857D    LD      (toggle0_1),A ; 0/1 toggle = 0
017a C9        RET                ; Done
;---------------------------------

 

;---------------------------------
; Check if a coin has been put in
CoinHandler:
017b 3A007D    LD      A,(IN2)     ; A = IN2
017e CB7F      BIT     7,A         ; Check for coin
0180 210360    LD      HL,coinValid ; HL = address of coinValid
0183 C28901    JP      NZ,0189H    ; If a coin is being entered, process it
0186 3601      LD      (HL),01H    ; If no coin, accept to next one
0188 C9        RET                 ; Done

0189 7E        LD      A,(HL)      ; If this coin has already been processed
018a A7        AND     A           ;   ''
018b C8        RET     Z           ;   then return

018c E5        PUSH    HL          ; Push coinValid on stack
018d 3A0560    LD      A,(gameMode); If (gameMode) == 3
0190 FE03      CP      03H         ;    (player is playing)
0192 CA9D01    JP      Z,019DH     ;    jump ahead

0195 CD1C01    CALL    TurnOffSounds ; Turn off sounds
0198 3E03      LD      A,03H       ; Write 3 to 6083H
019a 328360    LD      (6083H),A   ;   ''

019d E1        POP     HL          ; HL = address of coinValid
019e 3600      LD      (HL),00H    ; Prevent this coin from being reprocessed
01a0 2B        DEC     HL          ; HL = address of coinsPending
01a1 34        INC     (HL)        ; Add this coin to # of coins waiting for acceptance
01a2 112460    LD      DE,numCoinsSetting ; DE = address of numCoinsSetting
01a5 1A        LD      A,(DE)      ; A = numCoinsSetting
01a6 96        SUB     (HL)        ; Subtract # coins entered from # coins required to play
01a7 C0        RET     NZ          ; Return if not enough coins to play

01a8 77        LD      (HL),A      ; Write 0 to coinsPending
01a9 13        INC     DE          ; DE = address of numPlaysSetting
01aa 2B        DEC     HL          ; HL = address of numCredits
01ab EB        EX      DE,HL       ; HL = add of numPlaysSetting, DE = add of numCredits
01ac 1A        LD      A,(DE)      ; A = numCredits
01ad FE90      CP      90H         ; Return if 90+ credits have
01af D0        RET     NC          ;    been entered

01b0 86        ADD     A,(HL)      ; A = total number of credits entered
01b1 27        DAA                 ; Adjust A to BCD digits
01b2 12        LD      (DE),A      ; Save new credit total in numCredits
01b3 110004    LD      DE,0400H    ; Update CREDIT display
01b6 CD9F30    CALL    AddFunctionToUpdateList ;    during next update
01b9 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; The default values for player 1 score,
; player 2 score and high score.
DefaultScores:
01ba 003700 ; Player 1 score during demo (003700)
01bd AAAAAA ; Player 2 score during demo (blank)
01c0 507600 ; Default high score (007650)
;----------------------------------



;--------------------------------- 
PrepareDemoMode:
01c3 CD7408    CALL    ClearScreenAndSprites
; Initialize player scores
01c6 21BA01    LD      HL,DefaultScores ; HL = address of default scores
01c9 11B260    LD      DE,player1Score ; DE = address of player1Score
01cc 010900    LD      BC,0009H   ; Copy 9 bytes
01cf EDB0      LDIR               ; Populate scores with defaults

01d1 3E01      LD      A,01H      ; A = 1
01d3 320760    LD      (demoMode),A ; demoMode = 1
01d6 322962    LD      (levelNum),A ; levelNum = 1
01d9 322862    LD      (numLives),A ; numLives = 1

01dc CDB806    CALL    DisplayLivesAndLevel 
01df CD0702    CALL    RecordDipSwitchSettings

01e2 3E01      LD      A,01H       ; A = 1
01e4 32827D    LD      (flipScreen),A ; Orient screen right-side up
01e7 320560    LD      (gameMode),A ; gameMode = 1 (demo mode)
01ea 322762    LD      (currentStage),A ; currentStage = 1 (barrels)
01ed AF        XOR     A           ; A = 0
01ee 320A60    LD      (currentScreen),A ; currentScreen = 0

01f1 CD530A    CALL    Display1Up

01f4 110403    LD      DE,0304H    ; Display "HIGH SCORE"
01f7 CD9F30    CALL    AddFunctionToUpdateList
01fa 110202    LD      DE,0202H    ; Display high score
01fd CD9F30    CALL    AddFunctionToUpdateList
0200 110002    LD      DE,0200H    ; Display player 1 score
0203 CD9F30    CALL    AddFunctionToUpdateList
0206 C9        RET                 ; Done
;---------------------------------- 



;---------------------------------- 
; Load and record Dip Switch settings
RecordDipSwitchSettings:
0207 3A807D    LD      A,(dsw1)    ; A = dsw1 settings
020a 4F        LD      C,A         ; C = dsw1 settings
; Determine the number of lives selected
020b 212060    LD      HL,numLivesSetting ; HL = address of numLivesSetting
020e E603      AND     03H         ; A = number of lives dsw1 setting
0210 C603      ADD     A,03H       ; A = number of lives dsw1 setting
0212 77        LD      (HL),A      ; numLivesSetting = number of lives selected
; Determine the bonus life setting
0213 23        INC     HL          ; HL = address of bonusSetting
0214 79        LD      A,C         ; A = dsw1 settings
0215 0F        RRCA                ; A = bonus life score dsw1 setting
0216 0F        RRCA                ;    ''
0217 E603      AND     03H         ;    ''
0219 47        LD      B,A         ; B = bonus life score dsw1 setting
021a 3E07      LD      A,07H       ; A = 7
021c CA2602    JP      Z,0226H     ; If bits 2,3 of (7D80H) == 0, leave the score setting at 7 (7,000)
021f 3E05      LD      A,05H       ; A = 5 (5,000)
0221 C605      ADD     A,05H       ; A += 5 (5,000)
0223 27        DAA                 ; Adjust for BCD
0224 10FB      DJNZ    0221H       ; Next B 
0226 77        LD      (HL),A      ; bonusSetting = bonus lives score
; Record coins/plays setting
0227 23        INC     HL          ; HL = address of coinsPerPlay
0228 79        LD      A,C         ; A = dsw1 settings
0229 010101    LD      BC,0101H    ; BC = 0101H (1 coin/1 play)
022c 110201    LD      DE,0102H    ; DE = 0102H
022f E670      AND     70H         ; A = coins/play setting
0231 17        RLA                 ;    ''
0232 17        RLA                 ;    ''
0233 17        RLA                 ;    ''
0234 17        RLA                 ;    ''
0235 CA4702    JP      Z,0247H     ; If the switches are all 0, leave BC = 1 coin/1 play
0238 DA4102    JP      C,0241H     ; If 
023b 3C        INC     A           ; A = number of plays/coin
023c 4F        LD      C,A         ; C = number of plays/coin
023d 5A        LD      E,D         ; DE = 0101H
023e C34702    JP      0247H
0241 C602      ADD     A,02H       ; A = 2
0243 47        LD      B,A         ; B = 2
0244 57        LD      D,A         ; D = 2
0245 87        ADD     A,A         ; A = 4
0246 5F        LD      E,A         ; E = 4
0247 72        LD      (HL),D      ; numCoinsPerPlay
0248 23        INC     HL          ; HL = address of numPlaysPerCoin
0249 73        LD      (HL),E      ; numPlaysPerCoin
024a 23        INC     HL          ; 
024b 70        LD      (HL),B
024c 23        INC     HL
024d 71        LD      (HL),C
; Record cabinet type
024e 23        INC     HL          ; HL = address of cabType
024f 3A807D    LD      A,(7D80H)   ; A = dsw1 settings
0252 07        RLCA                ; Re= bit 7 of dsw1 (cabinet type)
0253 3E01      LD      A,01H       ; A = 1
0255 DA5902    JP      C,0259H     ; If upright cabinet, jump ahead
0258 3D        DEC     A           ; A = 0
0259 77        LD      (HL),A      ; Record cab type
; Load default high scores
025a 216535    LD      HL,DefaultHighScoreData
025d 110061    LD      DE,6100H 
0260 01AA00    LD      BC,00AAH    ; 170 bytes to copy
0263 EDB0      LDIR                ; Load default high scores
0265 C9        RET                 ; Done 
;-----------------------------------  



;-----------------------------------
; Initialization code
InitializeGame:
; Initialize 6000H to 6FFFH to 0 (4096 bytes)
; (Clear RAM)
0266 0610      LD      B,10H       ; For B = 1 to 16
0268 210060    LD      HL,6000H    ; First memory address = 6000H
026b AF        XOR     A           ; A = 0
026c 4F        LD      C,A         ; C = 0
026d 77        LD      (HL),A      ; Write 0 to current address
026e 23        INC     HL          ; Next address
026f 0D        DEC     C           ; Clear next 255 addresses
0270 20FB      JR      NZ,026DH    ; ''
0272 10F8      DJNZ    026CH       ; Next B

; Initialize 7000H to 73FFH to 0 (1024 bytes)
0274 0604      LD      B,04H       ; For B = 1 to 4
0276 210070    LD      HL,7000H    ; First address = 7000H
0279 4F        LD      C,A         ; C = 0
027a 77        LD      (HL),A      ; Write 0 to current address
027b 23        INC     HL          ; Next adddress
027c 0D        DEC     C           ; Clear next 255 addresses
027d 20FB      JR      NZ,027AH    ; ''
027f 10F8      DJNZ    0279H       ; Next B

; Initialize 7400H to 77FFH to ' ' (1024 bytes)
; (Clear screen)
0281 0604      LD      B,04H       ; For B = 1 to 4
0283 3E10      LD      A,10H       ; A = ' '
0285 210074    LD      HL,7400H    ; First address = 7400H
0288 0E00      LD      C,00H       ; C = 0
028A           LD      (HL),A      ; Write ' ' to current coord
028b 23        INC     HL          ; Next address
028c 0D        DEC     C           ; Clear next 255 addresses
028d 20FB      JR      NZ,028AH    ; ''
028f 10F7      DJNZ    0288H       ; Next B

; Initialize 60C0H to 60FFH to FFH (64 bytes)
0291 21C060    LD      HL,60C0H    ; First address = 60C0H
0294 0640      LD      B,40H       ; For B = 1 to 64
0296 3EFF      LD      A,0FFH      ; Value to initialize with = FFH
0298 77        LD      (HL),A      ; Write FFH to current address
0299 23        INC     HL          ; Next address
029a 10FC      DJNZ    0298H       ; Next B

029c 3EC0      LD      A,0C0H      ; Load A with C0H
029e 32B060    LD      (60B0H),A   ; Initialize buffer writePtr to point to 60C0H
02a1 32B160    LD      (60B1H),A   ; Write C0H to 60B1H 
02a4 AF        XOR     A           ; A = 0
02a5 32837D    LD      (7D83H),A   ; Write 0 to 7D83H
02a8 32867D    LD      (palette1),A   ; Write 0 to palette1
02ab 32877D    LD      (palette2),A   ; Write 0 to palette2
02ae 3C        INC     A           ; Write 1 to 7D82H
02af 32827D    LD      (7D82H),A   ;    ''
02b2 31006C    LD      SP,6C00H    ; Stack starts at 6C00H
02b5 CD1C01    CALL    TurnOffSounds
02b8 3E01      LD      A,01H       ; Enable interrupts
02ba 32847D    LD      (intEnable),A ; ''
; End of initialization

CallPendingFunction:
02bd 2660      LD      H,60H       ; Prepare for RAM address (60xxH)
02bf 3AB160    LD      A,(readPtr) ; Load A with readPtr (initially C0H)
02c2 6F        LD      L,A         ; source address (initially 60C0H)
02c3 7E        LD      A,(HL)      ; A = byte from buffer
02c4 87        ADD     A,A         ; If A = valid byte from buffer (< 80H)
02c5 301C      JR      NC,Label02E3 ;    jump ahead (don't flash 'nUP' or increment timer

02c7 CD1503    CALL    FlashNup    ; Flash current player's 'nUP' line
02ca CD5003    CALL    PreTurnUpdate ; Pre-turn stuff: Award bonus life, display lives, level number 
02cd 211960    LD      HL,counter2 ; HL = address of counter2
02d0 34        INC     (counter2)  ; Add 1 to counter2
02d1 218363    LD      HL,6383H    ; Continue checking for pending functions
02d4 3A1A60    LD      A,(counter1) ;    until (counter1) changes
02d7 BE        CP      (HL)        ;   ''
02d8 28E3      JR      Z,CallPendingFunction ;   ''

02da 77        LD      (HL),A      ; (6383H) = counter1
02db CD7F03    CALL    IncrementTime ; Increment time counter and increase difficulty
02de CDA203    CALL    AnimateOilBarrelFire
02e1 18DA      JR      CallPendingFunction ; Jump back up

Label02E3:
02e3 E61F      AND     1FH         ; Mask out all but 5 lower bits in byte from buffer
02e5 5F        LD      E,A         ; DE = byte from buffer * 2
02e6 1600      LD      D,00H       ;    ''
02e8 36FF      LD      (HL),0FFH   ; Mark the current buffer entry invalid
02ea 2C        INC     L           ; HL = next buffer location
02eb 4E        LD      C,(HL)      ; C = next byte from buffer
02ec 36FF      LD      (HL),0FFH   ; Mark the following buffer entry invalid
02ee 2C        INC     L           ; HL = next buffer location
02ef 7D        LD      A,L         ; A = buffer location
02f0 FEC0      CP      0C0H        ; If buffer ptr doesn't need to wrap
02f2 3002      JR      NC,02F6H    ;    jump ahead

02f4 3EC0      LD      A,0C0H      ; Wrap buffer ptr to 60C0H

02f6 32B160    LD      (readPtr),A ; Resave new readPtr
02f9 79        LD      A,C         ; A = second byte from buffer
02fa 21BD02    LD      HL,CallPendingFunction ; Jump back to CallPendingFunction
02fd E5        PUSH    HL          ;    when subroutine is done
02fe 210703    LD      HL,FunctionJumpTable ; HL = Address of FunctionJumpTable
0301 19        ADD     HL,DE       ; HL = Address of entry in table
0302 5E        LD      E,(HL)      ; E = first byte from table entry
0303 23        INC     HL          ; HL = address of second byte in entry
0304 56        LD      D,(HL)      ; D = second byte from table entry
0305 EB        EX      DE,HL       ; HL = address of subroutine from jump table
0306 E9        JP      (HL)        ; Jump to subroutine from table with A = argument
;----------------------------------



;----------------------------------
; Jump table for pending functions
FunctionJumpTable:
0307 1C05 ; 0 = AwardPoints
0309 9B05 ; 1 = ClearScores
030b C605 ; 2 = DisplayAllScores
030d E905 ; 3 = DisplayString
030f 1106 ; 4 = DisplayNumCredits
0311 2A06 ; 5 = DisplayTimer
0313 B806 ; 6 = DisplayLivesAndLevel
;----------------------------------



;----------------------------------
; Flash the current player's 'nUP'
; status line.  If the current 
; player's 'nUP' line is blanked, the
; 'nUP' line for the other player (if
; applicable) is displayed.
FlashNup:
0315 3A1A60    LD      A,(counter1); A = counter1
0318 47        LD      B,A         ; B = counter1
0319 E60F      AND     0FH         ; Only continue every 16 increments
031b C0        RET     NZ          ;    ''
031c CF        ReturnIfDemoMode ; Return if demoMode == 1
031d 3A0D60    LD      A,(playerUp); A = current player #
0320 CD4703    CALL    GetStatusCoord ; HL = coord for current player status
0323 11E0FF    LD      DE,0FFE0H   ; DE = -32
0326 CB60      BIT     4,B         ; If bit 4 of counter1 == 0
0328 2814      JR      Z,033EH     ;    skip to 033EH (don't blank status)

032a 3E10      LD      A,10H       ; Blank out 'nUP' status line
032c 77        LD      (HL),A      ;    ''
032d 19        ADD     HL,DE       ;    ''
032e 77        LD      (HL),A      ;    ''
032f 19        ADD     HL,DE       ;    ''
0330 77        LD      (HL),A      ;    ''
0331 3A0F60    LD      A,(twoPlayers); Return if only one player
0334 A7        AND     A           ;    ''
0335 C8        RET     Z           ;    ''

0336 3A0D60    LD      A,(playerUp) ; A = current player #
0339 EE01      XOR     01H         ; A = opposite player number
033b CD4703    CALL    GetStatusCoord ; HL = coord for other player status

033e 3C        INC     A           ; A = either current or opposite player #
033f 77        LD      (HL),A      ; Display 'nUP' for player
0340 19        ADD     HL,DE       ; ''
0341 3625      LD      (HL),25H    ; '' ('U')
0343 19        ADD     HL,DE       ; ''
0344 3620      LD      (HL),20H    ; '' ('P')
0346 C9        RET                 ; Done
;---------------------------------



;---------------------------------
; Returns the screen coordinate for the 
; current player's status display. ("nUP")
; Player 1 (A == 0) = (26, 0)
; Player 2 (A == 1) = (7, 0)
; passed: A - current player
; return: coordinate in HL
GetStatusCoord:
0347 214077    LD      HL,7740H    ; HL = (26, 0)
034a A7        AND     A           ; Return if A == 0
034b C8        RET     Z           ; ''
034c 21E074    LD      HL,74E0H    ; HL = (7, 0)
034f C9        RET                 ; Done
;---------------------------------  



;---------------------------------  
; Pre-turn calculations.
; Award bonus life if bonus has not been
; awarded yet and score is >= bonus
; setting.
; Redisplay lives and level number if bonus
; was awarded.
PreTurnUpdate:
0350 3A2D62    LD      A,bonusAwarded ; A = bonusAwarded
0353 A7        AND     A           ; Return if bonusAwarded == 1
0354 C0        RET     NZ          ; ''
0355 21B360    LD      HL,60B3H    ; HL = 60B3H
0358 3A0D60    LD      A,playerUp  ; A = playerUp
035b A7        AND     A           ; If player 2 active
035c 2803      JR      Z,0361H     ; ''
035e 21B660    LD      HL,60B6H    ; HL = 60B6H
0361 7E        LD      A,(HL)      ; A = second byte of score?
0362 E6F0      AND     0F0H        ; A = 1,000's digit of score
0364 47        LD      B,A         ; B = 1,000's digit of score
0365 23        INC     HL          ; HL = next byte of score
0366 7E        LD      A,(HL)      ; A = third byte of score
0367 E60F      AND     0FH         ; A = 10,000's digit of score
0369 B0        OR      B           ; B = 1,000's digit and 10,000's digit
036a 0F        RRCA                ; Swap upper and lower nibbles
036b 0F        RRCA                ;    to get them in the right
036c 0F        RRCA                ;    order
036d 0F        RRCA                ;    ''    
036e 212160    LD      HL,bonusSetting ; Return if score is less than
0371 BE        CP      (HL)        ;    the bonus setting
0372 D8        RET     C           ;    ''
0373 3E01      LD      A,01H       ; A = 1
0375 322D62    LD      bonusAwarded,A ; Record bonus awarded
0378 212862    LD      HL,numLives ; Load HL with address of numLives
037b 34        INC     (HL)        ; Add one life
037c C3B806    JP      06B8H       ; Redisplay lives and level number and return
;----------------------------------



;----------------------------------
; Increment the time counter (minorCounter
; and majorCounter).  The difficulty
; increases every 2048 increments.
IncrementTime:
037f 218463    LD      HL,minorCounter; HL = address of minorCounter
0382 7E        LD      A,(HL)      ; A = minorCounter
0383 34        INC     (HL)        ; Increment minorCounter
0384 A7        AND     A           ; Continue if minorCounter has rolled over
0385 C0        RET     NZ          ;    ''

0386 218163    LD      HL,majorCounter; HL = address of majorCounter
0389 7E        LD      A,(HL)      ; A = majorCounter
038a 47        LD      B,A         ; B = majorCounter
038b 34        INC     (HL)        ; increment majorCounter
038c E607      AND     07H         ; Get lower 3 bits
038e C0        RET     NZ          ; Continue if majorCounter has rolled over

038f 78        LD      A,B         ; A = majorCounter
0390 0F        RRCA    				; A = 5 MSBs of majorCounter
0391 0F        RRCA    				;    (0-248)
0392 0F        RRCA    				;    ''
0393 47        LD      B,A			; B = 5 MSBs
0394 3A2962    LD      A,(levelNum); Load the level number into A
0397 80        ADD     A,B         ; A = levelNum + top 5 bits of majorCounter
0398 FE05      CP      05H			; If A >= 5
039a 3802      JR      C,039EH	  ;    ''
039c 3E05      LD      A,05H		 ;    A = 5
039e 328063    LD      (diffLevel),A ; diffLevel = 1-5
03a1 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Animate the oil barrel fire on
; the barrels and pies stage:
AnimateOilBarrelFire:
03a2 3E03      LD      A,03H       ; Return unless barrels or pie stage
03a4 F7        RST     ReturnUnlessStageOfInterest ;    ''
03a5 D7        ReturnIfMarioDead   ; Return if mario is dead
03a6 3A5063    LD      A,(smashSequenceActive)   ; Return if smashSequenceActive
03a9 0F        RRCA                ;    == 1
03aa D8        RET     C           ;    ''

03ab 21B862    LD      HL,OilBarrelFireDelay ; Return until OilBarrelFireDelay
03ae 35        DEC     (HL)        ;    reaches 0
03af C0        RET     NZ          ;    ''

03b0 3604      LD      (HL),04H    ; Reset OilBarrelFireDelay to 4
03b2 3AB962    LD      A,(OilBarrelFireState) ; Return if oil barrel 
03b5 0F        RRCA                ;    is not on fire
03b6 D0        RET     NC          ;    ''

03b7 21296A    LD      HL,oilFireSpriteNum ; HL = address of oilFireSpriteNum
03ba 0640      LD      B,40H       ; B = 40H
03bc DD21A066  LD      IX,66A0H    ; IX = 66A0H
03c0 0F        RRCA                ; If the initial flare up
03c1 D2E403    JP      NC,03E4H    ;    is over, jump ahead
03c4 DD360902  LD      (IX+09H),02H ; (66A9H) = 2
03c8 DD360A02  LD      (IX+0AH),02H ; (66AAH) = 2
03cc 04        INC     B           ; B = 42H
03cd 04        INC     B           ;    ''
03ce CDF203    CALL    AlternateSprites ; Alternate oilFireSpriteNum between the two flare up sprites
03d1 21BA62    LD      HL,OilBarrelFireFlareduration ; Don't continue until the
03d4 35        DEC     (HL)        ;    flare up is complete
03d5 C0        RET     NZ          ;    ''

03d6 3E01      LD      A,01H       ; OilBarrelFireState = 1 (normal burn)
03d8 32B962    LD      (OilBarrelFireState),A   ;    ''
03db 32A063    LD      (63A0H),A   ; (63A0H) = 1

03de 3E10      LD      A,10H       ; OilBarrelFireFlareduration = 16
03e0 32BA62    LD      OilBarrelFireFlareduration,A ;    ''
03e3 C9        RET                 ; Done

03e4 DD360902  LD      (IX+09H),02H ; (66A9H) = 2
03e8 DD360A00  LD      (IX+0AH),00H ; (66AAH) = 0
03ec CDF203    CALL    AlternateSprites ; Alternate oilFireSpriteNum between normal flame tiles          
03ef C3DE03    JP      03DEH
;----------------------------------



;----------------------------------
; Alternates between two adjacent
; sprites.  (HL) is set to the 
; sprite number in B if counter2
; is odd, or to B + 1 if counter2
; is even.
; passed: B - base sprite number
;         HL - address of sprite
;            number variable
; return: none (the sprite number
;            is returned in the
;            sprite number variable)
AlternateSprites:
03f2 70        LD      (HL),B      ; (HL) = B
03f3 3A1960    LD      A,(counter2)   ; A = (counter2)
03f6 0F        RRCA                ; Return if (counter2) is odd
03f7 D8        RET     C           ;    ''

03f8 04        INC     B           ; B ++
03f9 70        LD      (HL),B      ; (HL) = B
03fa C9        RET                 ; Done
;--------------------------------- 



;--------------------------------- 
03fb 3A2762    LD      A,(currentStage) ; If currentStage 
03fe FE02      CP      02H         ;    != pies stage,
0400 C21304    JP      NZ,Label0413 ;    jump ahead

; Move DK along the top conveyer in the pies
; stage
0403 210869    LD      HL,dkSprite1X ; Move DK along top 
0406 3AA363    LD      A,(conveyer1Offset) ;    conveyer
0409 4F        LD      C,A         ;    ''
040a FF        RST     MoveDKSprites ;    ''
040b 3A1069    LD      A,(dkSprite3X) ; dkDistanceFromLadder = dkSprite3X - 59
040e D63B      SUB     3BH         ;    ''
0410 32B763    LD      (dkDistanceFromLadder),A ;    ''

; This code skips the main body of code below
; unless (6391H) == 1.  
Label0413:
0413 3A9163    LD      A,(6391H)   ; If (6391H) == 1
0416 A7        AND     A           ;    jump ahead
0417 C22604    JP      NZ,Label0426 ;    ''
; When counter1 reaches 0, (6391H) is set to 1
041a 3A1A60    LD      A,(counter1) ; If counter1 > 0
041d A7        AND     A           ;    jump ahead
041e C28604    JP      NZ,Label0486 ; else (counter1 == 0)
0421 3E01      LD      A,01H       ;    (6391H) = 1
0423 329163    LD      (6391H),A   ;    and execute the code below

Label0426:
0426 219063    LD      HL,6390H    ; ++(6390H)
0429 34        INC     (HL)        ;    ''
042a 7E        LD      A,(HL)      ; If (6390H) 
042b FE80      CP      80H         ;    == 128,
042d CA6404    JP      Z,Label0464 ;    jump ahead

0430 3A9363    LD      A,(6393H)   ; If (6393H) == 1,
0433 A7        AND     A           ;    jump ahead
0434 C28604    JP      NZ,Label0486 ;    ''

0437 7E        LD      A,(HL)      ; B = (6390H)
0438 47        LD      B,A         ;    ''
0439 E61F      AND     1FH         ; If it is not time to update the
043b C28604    JP      NZ,Label0486 ;   stomp animation, jump ahead

; Animate DK stomping by alternately displaying
; him with opposite leg and arm raised
043e 21CF39    LD      HL,DKSpriteDataGrinLArmRLegUp ; If bit 5 of (6390H)
0441 CB68      BIT     5,B         ;    is set, display DK with
0443 2003      JR      NZ,0448H    ;    left arm and right leg raised
0445 21F739    LD      HL,DKSpriteDataGrinRArmLLegUp ; else, display DK with
0448 CD4E00    CALL    LoadDKSprites ;    right arm and left leg raised
044b 3E03      LD      A,03H       ; Play stomp sound effect
044d 328260    LD      (soundEffect),A ;    ''

Label0450:
0450 3A2762    LD      A,(currentStage) ; If currentStage ==
0453 0F        RRCA                ;    2 (pies) or 4 (rivets),
0454 D27804    JP      NC,Label0478 ;    jump ahead
0457 0F        RRCA                ; else if currentStage == 
0458 DA8604    JP      C,Label0486 ;    3 (elevators), jump ahead
                                   ; else (currentStage == 1 (barrels))

045b 210B69    LD      HL,dkSprite1Y
045e 0EFC      LD      C,0FCH      ; Move DK up 4 pixels
0460 FF        RST     MoveDKSprites ;    ''
0461 C38604    JP      Label0486   

Label0464:
0464 AF        XOR     A           ; Reset (6390H) to 0
0465 77        LD      (HL),A      ;    ''
0466 23        INC     HL          ; Reset (6391H) to 0
0467 77        LD      (HL),A      ;    ''
0468 3A9363    LD      A,(6393H)   ; If (6393H) == 1,
046b A7        AND     A           ;    jump ahead
046c C28604    JP      NZ,Label0486 ;    ''

046f 215C38    LD      HL,DKLeftArmRaisedSpriteData ; Change DK sprites
0472 CD4E00    CALL    LoadDKSprites
0475 C35004    JP      Label0450

Label0478:
0478 210869    LD      HL,dkSprite1X ; If currentStage ==
047b 0E44      LD      C,44H       ;    2 (pies), 
047d 0F        RRCA                ;    move DK to the ladder
047e D28504    JP      NC,0485H    ; else (rivets),
0481 3AB763    LD      A,(dkDistanceFromLadder) ;    move DK left
0484 4F        LD      C,A         ;    68 pixels
0485 FF        RST     MoveDKSprites ;    ''

Label0486:
0486 3A9063    LD      A,(6390H)
0489 4F        LD      C,A
048a 112000    LD      DE,0020H
048d 3A2762    LD      A,(currentStage)
0490 FE04      CP      04H
0492 CABE04    JP      Z,AnimatePaulineInDistress
0495 79        LD      A,C
0496 A7        AND     A
0497 CAA104    JP      Z,04A1H
049a 3EEF      LD      A,0EFH
049c CB71      BIT     6,C
049e C2A304    JP      NZ,04A3H
04a1 3E10      LD      A,10H       ; A = ' '
04a3 21C475    LD      HL,75C4H    ; HL = (14,4)
04a6 CD1405    CALL    DisplayHelpTiles ; Clear "Help!" tiles to Pauline's right
04a9 3A0569    LD      A,(paulineLowerSpriteNum)
04ac 320569    LD      (paulineLowerSpriteNum),A ; Write A to paulineLowerSpriteNum
04af CB71      BIT     6,C         ; Return if bit 7 in C is 0
04b1 C8        RET     Z           ;   ''

04b2 47        LD      B,A         ; B = A
04b3 79        LD      A,C         ; A = C
04b4 E607      AND     07H         ; Return if any of bits 1-6 are set
04b6 C0        RET     NZ          ;    ''

04b7 78        LD      A,B         ; Return B to A
04b8 EE03      XOR     03H         ; Flip bits 0,1
04ba 320569    LD      (paulineLowerSpriteNum),A   ; Write A to paulineLowerSpriteNum
04bd C9        RET                 ; Done
;---------------------------------



;---------------------------------
; passed: C = If bit 6 == 0, Pauline
;            does not call for help
;         DE = -325
AnimatePaulineInDistress:
04be 3E10      LD      A,10H      ; A = 10H (' ')
04c0 212376    LD      HL,7623H   ; HL = (17,3)
04c3 CD1405    CALL    DisplayHelpTiles ; Clear "Help!" tiles to the left of Pauline
04c6 218375    LD      HL,7583H   ; HL = (12,3)
04c9 CD1405    CALL    DisplayHelpTiles ; Clear "Help!" tiles on Pauline's right
04cc CB71      BIT     6,C        ; If bit 6 of C == 0
04ce CA0905    JP      Z,0509H    ;    jump to 0509H
04d1 3A0362    LD      A,(marioX) ; A = marioX position
04d4 FE80      CP      80H        ; If mario is on the right side of the screen
04d6 D2F104    JP      NC,04F1H   ;    jump to 04F1H

04d9 3EDF      LD      A,0DFH     ; A = DFH ("Help" 1 of 3)
04db 212376    LD      HL,7623H   ; HL = (17,3)
04de CD1405    CALL    DisplayHelpTiles ; Display "Help!" on Pauline's left
04e1 3A0169    LD      A,(paulineUpperSpriteNum)  ; Flip Pauline to face left
04e4 F680      OR      80H        ;    ''
04e6 320169    LD      (paulineUpperSpriteNum),A  ;    ''
04e9 3A0569    LD      A,(paulineLowerSpriteNum)  ;    ''
04ec F680      OR      80H        ;    ''
04ee C3AC04    JP      04ACH      ; Jump above

04f1 3EEF      LD      A,0EFH     ; A = EFH (Right "Help!" 1 of 3)
04f3 218375    LD      HL,7583H   ; HL = (12,3)
04f6 CD1405    CALL    DisplayHelpTiles ; Display right "Help!"
04f9 3A0169    LD      A,(paulineUpperSpriteNum)  ; Flip Pauline to face right
04fc E67F      AND     7FH        ;    ''
04fe 320169    LD      (paulineUpperSpriteNum),A  ;    ''
0501 3A0569    LD      A,(paulineLowerSpriteNum)  ;    ''
0504 E67F      AND     7FH        ;    ''
0506 C3AC04    JP      04ACH

0509 3A0362    LD      A,(marioX)  ; A = mario's x coord
050c FE80      CP      80H         ; If mario is left of center
050e D2F904    JP      NC,04F9H    ;   Jump to 04F9H
0511 C3E104    JP      04E1H       ; Else jump to 04E1H
;------------------------------------



;------------------------------------
; Display or clear Pauline's "Help!"
; passed: A: First character to display
;         HL: Coordinate to display at
;         DE: -32
DisplayHelpTiles:
0514 0603      LD      B,03H         ; B = 1 to 3
0516 77        LD      (HL),A        ; Write A to HL
0517 19        ADD     HL,DE         ; Next column
0518 3D        DEC     A             ; A = next tile
0519 10FB      DJNZ    0516H         ; Next B
051b C9        RET     
;----------------------------------



;----------------------------------
; Award player points from the point
; table and update the score display.
; passed: A - Point table entry number
AwardPoints:
051c 4F        LD      C,A         ; C = Point table entry number
051d CF        ReturnIfDemoMode    ; Return if demoMode == 1
051e CD5F05    CALL    GetCurrentPlayerScore ; DE = address of current player's score

; Convert the table index to an offset
0521 79        LD      A,C         ; A = Point table entry number
0522 81        ADD     A,C
0523 81        ADD     A,C         ; A = Point table offset
0524 4F        LD      C,A         ; C = Point table offset
0525 212935    LD      HL,PointsTable ; HL = Address of point table
0528 0600      LD      B,00H       ; BC now = Point table offset
052a 09        ADD     HL,BC       ; HL = Address of entry in point table
052b A7        AND     A           ; Clear carry flag

; Add the points from the table to player's score
052c 0603      LD      B,03H       ; For B = 3 to 1
052e 1A        LD      A,(DE)      ; A = current score
052f 8E        ADC     A,(HL)      ; Add byte from point table to score
0530 27        DAA                 ; Correct BCD addition
0531 12        LD      (DE),A      ; Store A in score
0532 13        INC     DE          ; DE = address of next byte in score
0533 23        INC     HL          ; HL = address of next byte in point table
0534 10F8      DJNZ    052EH       ; Next B

; Update player's score display
0536 D5        PUSH    DE          ; Save address of player's score on the stack
0537 1B        DEC     DE          ; DE = address of last byte of player's score
0538 3A0D60    LD      A,playerUp  ; A = current player
053b CD6B05    CALL    DisplayPlayerScore

; Check if high score needs to be updated
053e D1        POP     DE          ; DE = address of last byte of player's score
053f 1B        DEC     DE          ;    ''
0540 21BA60    LD      HL,60BAH    ; HL = last byte of high score (most significant byte)
0543 0603      LD      B,03H       ; B = 3 to 1
0545 1A        LD      A,(DE)      ; A = last byte of score (most significant byte)
0546 BE        CP      (HL)        ; Compare MS byte of high score with MS byte of player's score
0547 D8        RET     C           ; Return if high score is greater
0548 C25005    JP      NZ,0550H    ; Break out if player's score is higher
054b 1B        DEC     DE          ; DE = prev byte of high score
054c 2B        DEC     HL          ; HL = prev byte of player's score
054d 10F6      DJNZ    0545H       ; Next B
054f C9        RET                 ; Done - no update needed

; Update high score
0550 CD5F05    CALL    055FH       ; DE = address of current player's score
0553 21B860    LD      HL,60B8H    ; HL = address of high score
0556 1A        LD      A,(DE)      ; A = current byte of player's score
0557 77        LD      (HL),A      ; Write player's score byte to high sco
0558 13        INC     DE          ; DE = address of next byte in player's score
0559 23        INC     HL          ; HL = address of next byte in high score
055a 10FA      DJNZ    0556H       ; Next B
055c C3DA05    JP      UpdateHighScoreDisplay
;---------------------------------



;---------------------------------
; Sets DE to the memory location of the 
; current player's score
; Player 1 (playerUp == 0): DE = player1Score
; Player 2 (playerUp == 1): DE = player2Score
; return: address of player's score
GetCurrentPlayerScore:
055f 11B260    LD      DE,player1Score ; DE = player1Score
0562 3A0D60    LD      A,playerUp   ; Return if player 1 is up
0565 A7        AND     A            ; ''
0566 C8        RET     Z            ; ''
0567 11B560    LD      DE,player2Score ; DE = player2Score
056a C9        RET                  ; Return
;---------------------------------



;---------------------------------
; Display a score (current player's
; score or high score)
; passed: A - current player number
;         DE = address of last byte of score
DisplayPlayerScore:
056b DD218177  LD      IX,7781H    ; IX = (28,1) (player 1 score coord)
056f A7        AND     A           ; If player 1,
0570 280A      JR      Z,DisplayScore ;    jump ahead

0572 DD212175  LD      IX,7521H    ; IX = (9,1) (player 2 score coord)
0576 1804      JR      DisplayScore ; Jump ahead

DisplayHighScore:
0578 DD214176  LD      IX,7641H    ; IX = (18,1) (high score coord)

DisplayScore:
; passed: DE - address of last byte of the 
;            score to display
;         IX - the screen coordinate to 
;            display the score at
057c EB        EX      DE,HL       ; HL = address of last byte of score
057d 11E0FF    LD      DE,0FFE0H   ; DE = -32
0580 010403    LD      BC,0304H    ; BC = 0304H

DisplayDigits:
0583 7E        LD      A,(HL)      ; A = byte from score
0584 0F        RRCA                ; Isolate upper nibble
0585 0F        RRCA                ;    ''
0586 0F        RRCA                ;    ''
0587 0F        RRCA                ;    ''
0588 CD9305    CALL    DisplayDigit
058b 7E        LD      A,(HL)      ; A = lower nibble
058c CD9305    CALL    DisplayDigit
058f 2B        DEC     HL          ; HL = next byte of score
0590 10F1      DJNZ    0583H       ; Next B
0592 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Display a single digit on screen
; passed: A - digit to display
;         IX - screen location to display to
DisplayDigit:
0593 E60F      AND     0FH         ; Mask out all but lower nibble
0595 DD7700    LD      (IX+00H),A  ; Display the digit on screen
0598 DD19      ADD     IX,DE       ; IX = next coord right
059a C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Clear and redisplay scores
; passed: A - score ID
;             (0 = player 1, 
;              1 = player 2,
;              2 = high score,
;              3 = all scores)
ClearScores:
059b FE03      CP      03H        ; Compare A with 3
059d D2BD05    JP      NC,ClearAllScores ; If A >= 3, jump ahead

; Set HL = address of player1Score, if player
; 1 is selected
05a0 F5        PUSH    AF         ; Save AF register on stack
05a1 21B260    LD      HL,player1Score ; HL = address of player 1's score
05a4 A7        AND     A          ; If player 1 (A == 0), 
05a5 CAAB05    JP      Z,05ABH    ;    jump ahead

; Set HL = address of player2Score, if player
; 2 is selected
05a8 21B560    LD      HL,player2Score ; HL = address of player 2's score
05ab FE02      CP      02H        ; If not high score (A != 2),
05ad C2B305    JP      NZ,ClearSelectedScore ;    jump ahead

; Set HL = address of high score, if high
; score is selected
05b0 21B860    LD      HL,60B8H   ; HL = address of high score

; Clear the selected score
ClearSelectedScore:
05b3 AF        XOR     A         ; A = 0
05b4 77        LD      (HL),A    ; Clear the score
05b5 23        INC     HL        ;    ''
05b6 77        LD      (HL),A    ;    ''
05b7 23        INC     HL        ;    ''
05b8 77        LD      (HL),A    ;    ''
05b9 F1        POP     AF        ; Restore AF
05ba C3C605    JP      05C6H     

ClearAllScores:
05bd 3D        DEC     A         ; A --
05be F5        PUSH    AF        ; Save AF on stack
05bf CD9B05    CALL    ClearScores ; Recall this function
05c2 F1        POP     AF        ; Restore A
05c3 C8        RET     Z         ; Return if A == 0
05c4 18F7      JR      ClearAllScores ; Process next score

DisplayAllScores:
05c6 FE03      CP      03H       ; If A == 3
05c8 CAE005    JP      Z,UpdateAllScoresDisplay ;    jump ahead

05cb 11B460    LD      DE,60B4H  ; DE = address of last byte of player1Score
05ce A7        AND     A         ; If player 1 (A == 0)
05cf CAD505    JP      Z,05D5H   ;    jump ahead

05d2 11B760    LD      DE,60B7H  ; DE = address of last byte of player2Score
05d5 FE02      CP      02H       ; If player 2 (A == 1)
05d7 C26B05    JP      NZ,DisplayPlayerScore

UpdateHighScoreDisplay:
05da 11BA60    LD      DE,60BAH   ; DE = address of last byte of high score
05dd C37805    JP      DisplayHighScore

UpdateAllScoresDisplay:
05e0 3D        DEC     A          ; A --
05e1 F5        PUSH    AF         ; Save AF on stack
05e2 CDC605    CALL    05C6H      ; Display this score
05e5 F1        POP     AF         ; Restore AF
05e6 C8        RET     Z          ; Return if done with scores
05e7 18F7      JR      05E0H      ; Process the next score
;---------------------------------



;---------------------------------
; Display a string from the string table
; passed: A - String table entry #
;             (if this is negative, the
;             string will be erased)
DisplayString:
05e9 214B36    LD      HL,StringTable ; HL = base address of string table
05ec 87        ADD     A,A        ; A = string table offset
05ed F5        PUSH    AF         ; Save AF (C flag is set if the index was negative)
05ee E67F      AND     7FH        ; Clear the MSB of A
05f0 5F        LD      E,A        ; DE = string table offset
05f1 1600      LD      D,00H      ;    ''
05f3 19        ADD     HL,DE      ; HL = address of string table entry
05f4 5E        LD      E,(HL)     ; DE = address of the string to display
05f5 23        INC     HL         ;    ''
05f6 56        LD      D,(HL)     ;    ''
05f7 EB        EX      DE,HL      ; HL = address of string to display
05f8 5E        LD      E,(HL)     ; DE = Screen coord of string
05f9 23        INC     HL         ;    ''
05fa 56        LD      D,(HL)     ;    ''
05fb 23        INC     HL         ; HL = start address of string
05fc 01E0FF    LD      BC,0FFE0H  ; BC = -32
05ff EB        EX      DE,HL      ; HL = screen coord of string

DisplayStringLoop:
0600 1A        LD      A,(DE)     ; A = character from string
0601 FE3F      CP      3FH        ; Return when 3FH character is found
0603 CA2600    JP      Z,0026H    ;    ''
0606 77        LD      (HL),A     ; Display character at screen coord
0607 F1        POP     AF         ; Restore AF
0608 3002      JR      NC,DontBlankChar ; If the original string index was negative
060a 3610      LD      (HL),10H   ; Blank the character

DontBlankChar:
060c F5        PUSH    AF         ; Resave AF
060d 13        INC     DE         ; DE = next character from string
060e 09        ADD     HL,BC      ; HL = next column to the right
060f 18EF      JR      DisplayStringLoop
;---------------------------------



;---------------------------------
; Display the number of credits entered
; passed - none
DisplayNumCredits:
0611 3A0760    LD      A,(demoMode); A = demoMode
0614 0F        RRCA               ; Return if demoMode == 0 
0615 D0        RET     NC         ;    ''
DisplayNumCredits2:
0616 3E05      LD      A,05H      ; Load A with 5
0618 CDE905    CALL    DisplayString ; Display "CREDIT"
061b 210160    LD      HL,numCredits ; HL = address of numCredits
061e 11E0FF    LD      DE,0FFE0H  ; DE = -32
0621 DD21BF74  LD      IX,74BFH   ; IX = (5,31)
0625 0601      LD      B,01H      ; Display the number of credits
0627 C38305    JP      DisplayDigits
;---------------------------------



;---------------------------------
; Display the timer box and the current
; value of the timer
; passed: A - 0 if the timer needs to be added 
;             to the player's score before 
;             displaying
DisplayTimer:
062a A7        AND     A          ; If A == 0
062b CA9106    JP      Z,Label0691 ;    jump ahead
062e 3A8C63    LD      A,(onScreenTimer) ; A = onScreenTimer
0631 A7        AND     A          ; If timer has not reached 0
0632 C2A806    JP      NZ,06A8H   ;    jump ahead
0635 3AB863    LD      A,(63B8H)  ; A = (63B8H)
0638 A7        AND     A          ; If (6358H) != 0
0639 C0        RET     NZ         ;    return

; Convert hex timer number to hex coded digits for display
063a 3AB062    LD      A,(intTimer); Load A with value from internal timer
063d 010A00    LD      BC,000AH   ; Load B with 0, load C with 0AH (10 decimal)
0640 04        INC     B          ; B counts the number of tens
0641 91        SUB     C          ; Subtract 10 decimal from A
0642 C24006    JP      NZ,0640H   ; Keep repeating until A is zero
0645 78        LD      A,B        ; Load A with the number of tens in the counter
0646 07        RLCA               ; rotate left (multiply by 2) (x2)
0647 07        RLCA               ; rotate left (multiply by 2) (x2)
0648 07        RLCA               ; rotate left (multiply by 2) (x2)
0649 07        RLCA               ; rotate left (multiply by 2) (x2)
064a 328C63    LD      (onScreenTimer),A ; Store results to the on screen timer
064d 214A38    LD      HL,TimerDisplayBoxTileData ; HL = address of timer display box characters
0650 116574    LD      DE,7465H   ; DE = (3,5)
0653 3E06      LD      A,06H      ; For A = 6 to 1
0655 DD211D00  LD      IX,001DH   ; IX = 29
0659 010300    LD      BC,0003H   ; For B = 3 to 1 (3 cols)
065c EDB0      LDIR               ; Display this column
065e DD19      ADD     IX,DE      ; Advance to next column
0660 DDE5      PUSH    IX         ; ''
0662 D1        POP     DE         ; ''
0663 3D        DEC     A          ; Next A
0664 C25506    JP      NZ,0655H   ;    ''

0667 3A8C63    LD      A,(onScreenTimer) ; A = onscreenTimer

DisplayTimer:
066a 4F        LD      C,A        ; C = onscreenTimer
066b E60F      AND     0FH        ; A = 1's digit of timer
066d 47        LD      B,A        ; B = 1's digit of timer
066e 79        LD      A,C        ; A = onscreenTimer
066f 0F        RRCA               ; A = 10's digit of timer
0670 0F        RRCA               ;    ''
0671 0F        RRCA               ;    ''
0672 0F        RRCA               ;    ''
0673 E60F      AND     0FH        ;    ''
0675 C28906    JP      NZ,0689H   ; If 10's > 0 jump ahead

0678 3E03      LD      A,03H      ; A = 3
067a 328960    LD      (timeRunningOut),A ; timeRunningOut = 3
067d 3E70      LD      A,70H      ; A = '0' (red)
067f 328674    LD      (7486H),A  ; Display '0' at (4,6) (1's place)
0682 32A674    LD      (74A6H),A  ; Display '0' at (5,6) (10's place)
0685 80        ADD     A,B        ; A = 1's digit (red)
0686 47        LD      B,A        ; B = 1's digit (red)
0687 3E10      LD      A,10H      ; A = ' '

0689 32E674    LD      (74E6H),A  ; Display A (10's digit or ' ') at (7,6) (1,000's place)
068c 78        LD      A,B        ; A = B (1's digit or ' ')
068d 32C674    LD      (74C6H),A  ; Display A (1's digit or ' ') at (6,6) (100's place)
0690 C9        RET                ; Done 

Label0691:
0691 3A8C63    LD      A,(onScreenTimer) ; A = onScreenTimer
0694 47        LD      B,A        ; B = onScreenTimer
0695 E60F      AND     0FH        ; A = 1's digit of timer
0697 C5        PUSH    BC         ; Save onScreenTimer on stack
0698 CD1C05    CALL    AwardPoints ; Add 1's digit * 100 to player's score
069b C1        POP     BC         ; B = onScreenTimer
069c 78        LD      A,B        ; A = onScreenTimer
069d 0F        RRCA               ; A = 10's digit
069e 0F        RRCA               ;    ''
069f 0F        RRCA               ;    ''
06a0 0F        RRCA               ;    ''
06a1 E60F      AND     0FH        ;    ''
06a3 C60A      ADD     A,0AH      ; Add 10's digit * 1,000 to player's score
06a5 C31C05    JP      AwardPoints ;    ''

06a8 D601      SUB     01H        ; If A == 1
06aa 2005      JR      NZ,06B1H   ;    jump ahead

06ac 21B863    LD      HL,63B8H   ; HL = 63B8H
06af 3601      LD      (HL),01H   ; (63B8) = 1

06b1 27        DAA                ; Correct BCD subtraction
06b2 328C63    LD      (onScreenTimer),A ; Store A in onScreenTimer
06b5 C36A06    JP      DisplayTimer ; Display the timer
;---------------------------------- 



;---------------------------------- 
; Display number of lives and level number.
; The current life is removed from the 
; total lives before displaying.
; The level number is capped at 99.
; passed: A - number of lives to subtract 
;            before displaying (0 or 1)
DisplayLivesAndLevel:
06b8 4F        LD      C,A         ; C = 0 or 1
06b9 CF        ReturnIfDemoMode ; Return if demoMode == 1
06ba 0606      LD      B,06H       ; B = 6
06bc 11E0FF    LD      DE,0FFE0H   ; DE = -32
06bf 218377    LD      HL,7783H    ; HL = (28, 3)
06c2 3610      LD      (HL),10H    ; Clear lives display
06c4 19        ADD     HL,DE       ;    ''
06c5 10FB      DJNZ    06C2H       ;    ''
06c7 3A2862    LD      A,(numLives); A = number of lives
06ca 91        SUB     C           ; Subtract current life
06cb CAD706    JP      Z,06D7H     ; If there are lives to display
06ce 47        LD      B,A         ; B = numLives
06cf 218377    LD      HL,7783H    ; HL = (28, 3)
06d2 36FF      LD      (HL),0FFH   ; Fill lives display
06d4 19        ADD     HL,DE       ;    ''
06d5 10FB      DJNZ    06D2H       ; ''
06d7 210375    LD      HL,7503H    ; HL = (8, 3)
06da 361C      LD      (HL),1CH    ; Write 'L'
06dc 21E374    LD      HL,74E3H    ; HL = (7, 3)
06df 3634      LD      (HL),34H    ; Write '='

; Force the level number to remain below 100
06e1 3A2962    LD      A,(levelNum); A = level number
06e4 FE64      CP      64H         ; If A >= 100
06e6 3805      JR      C,06EDH     ;    ''
06e8 3E63      LD      A,63H       ; Force level number to 99
06ea 322962    LD      (levelNum),A; save the level number
06ed 010AFF    LD      BC,0FF0AH   ; B = -1, C = 10
06f0 04        INC     B           ; B = count of 10's in level number (levelNum / 10)
06f1 91        SUB     C           ; Subtract 10 from levelNum
06f2 D2F006    JP      NC,06F0H    ; Loop until no more 10's (A < 0)
06f5 81        ADD     A,C         ; A = 1's digit
06f6 32A374    LD      (74A3H),A   ; Write 1's digit to (5,3)
06f9 78        LD      A,B         ; A = 10's digit
06fa 32C374    LD      (74C3H),A   ; Write 10's digit to (6,3)
06fd C9        RET                 ; Done
;---------------------------------- 



;----------------------------------
; Jump to one of the following table 
; entries based on the current game
; screen set (currentScreen)
; Called when gameMode == 3
; (player is playing)
DisplayCurrentGameScreen: 
06fe 3A0A60    LD      A,(currentScreen)
0701 EF        RST     JumpToLocalTableAddress
0702 8609 ; 0 = OrientScreen
0704 AB09 ; 1 = InitPlayer1
0706 D609 ; 2 = Player1Prompt
0708 FE09 ; 3 = InitPlayer2
070a 1B0A ; 4 = Player2Prompt
070c 370A ; 5 = DisplayPlayer1
070e 630A ; 6 = TriggerIntroOrIntermission
0710 760A ; 7 = ImplementIntroStage
0712 DA0B ; 8 = ImplementIntermission
0714 0000 ; 9 = reset game
0716 910C ; 10 = DisplayCurrentStage
0718 3C12 ; 11 = InitializeMarioSprite
071a 7A19 ; 12 = ImplementGame
071c 7C12 ; 13 = ImplementDeathMode
071e F212 ; 14 = EndTurnPlayer1
0720 4413 ; 15 = EndTurnPlayer2
0722 8F13 ; 16 = StartPlayer2OrEnd
0724 A113 ; 17 = StartPlayer1OrEnd
0726 AA13 ; 18 = ActivatePlayer2
0728 BB13 ; 19 = ActivatePlayer1
072a 1E14 ; 20 = CheckForHighScores
072c 8614 ; 21 = GetHighScoreInitials
072e 1516 ; 22 = ImplementEndStage1
0730 6B19 ; 23 = ActivateNextPlayer
0732 0000 ; 24 = reset game
0734 0000 ; 25 = reset game
0736 0000 ; 26 = reset game
0738 0000 ; 27 = reset game
073a 0000 ; 28 = reset game
;----------------------------------



;----------------------------------
; Called when gameMode == 1 (demo mode)
; Jump based on currentScreen, if
; there are no credits waiting.
ActivateDemoMode:
073c 210A60    LD      HL,currentScreen ; HL = address of current screen
073f 3A0160    LD      A,(numCredits) ; Load the number of credits into A
0742 A7        AND     A           ; If coins have been entered
0743 C25C07    JP      NZ,WaitForPlayerStart ;    Show the player start prompt
0746 7E        LD      A,(HL)      ; A = currentScreen
0747 EF        RST     JumpToLocalTableAddress
0748 7907 ; 0 = InsertCoinScreen
074a 6307 ; 1 = PrepareDemoMode
074c 3C12 ; 2 = InitializeMarioSprite
074e 7719 ; 3 = RunDemoMode
0750 7C12 ; 4 = ImplementDeathMode
0752 C307 ; 5 = ClearDemoScreen
0754 CB07 ; 6 = DisplayTitleScreen
0756 4B08 ; 7 = PauseOnTitleScreen
0758 0000 ; 8 = 0000H (Reset game)
075a 0000 ; 9 = 0000H (Reset game)
;----------------------------------



;----------------------------------
WaitForPlayerStart:
075c 3600      LD      (HL),00H   ; currentScreen = 0
075e 210560    LD      HL,gameMode ; gameMode = 2 (waiting for 1 or 2 player start)
0761 34        INC     (HL)       ;    ''
0762 C9        RET     
;---------------------------------



;----------------------------------
; Called when gameMode == 1 (demo
; mode) and currentScreen == 1
PrepareDemoMode:
0763 E7        RST     ContinueWhenTimerReaches0 ; Return unless (majorTimer) and (minorTimer) have decremented to 0
0764 AF        XOR     A           ; A = 0
0765 329263    LD      (6392H),A   ; (6392H) = 0
0768 32A063    LD      (63A0H),A   ; (63A0H) = 0
076b 3E01      LD      A,01H       ; A = 1
076d 322762    LD      (currentStage),A ; CurrentStage = 1 (barrels)
0770 322962    LD      (levelNum),A ; Level 1
0773 322862    LD      (numLives),A ; 1 life
0776 C3920C    JP      DisplayCurrentStage1
;----------------------------------



;----------------------------------
; Called when gameMode == 1 (demo)
; and currentScreen == 0
InsertCoinScreen:
0779 21867D    LD      HL,palette1    ; Set palette 0
077c 3600      LD      (HL),00H    ;    ''
077e 23        INC     HL          ;    ''
077f 3600      LD      (HL),00H    ;    ''
0781 111B03    LD      DE,031BH    ; Display "INSERT COIN"
0784 CD9F30    CALL    AddFunctionToUpdateList
0787 1C        INC     E           ; Display "  PLAYER    COIN"
0788 CD9F30    CALL    AddFunctionToUpdateList
078b CD6509    CALL    DisplayHighScores
078e 210960    LD      HL,minorTimer    ; (minorTimer) = 2
0791 3602      LD      (HL),02H    ;    ''
0793 23        INC     HL          ; currentScreen = 1
0794 34        INC     (HL)        ;    ''
0795 CD7408    CALL    ClearScreenAndSprites
0798 CD530A    CALL    Display1Up
079b 3A0F60    LD      A,(twoPlayers) ; If two players 
079e FE01      CP      01H         ;   display '2UP' 
07a0 CCEE09    CALL    Z,Display2Up ;    ''
07a3 ED5B2260  LD      DE,(coinsPerPlay) ; D = address of playsPerCoin, E = address of coinsPerPlay
07a7 216C75    LD      HL,756CH    ; HL = (11,12)
07aa CDAD07    CALL    07ADH       ; Run the code below twice

; The code below is executed twice.
; First, to display the number of coins 
; required for 1 player or 2 players at 
; (11,12) and (11,14), respectively.
; Second, to display '1' and '2' (for
; 1 player and 2 players) at (20,12) and
; (20,14), respectively.
; Ingenious.
; The comments below apply to the first
; execution only.
07ad 73        LD      (HL),E      ; Display number of coins for 1 player at (11,12)
07ae 23        INC     HL          ; HL = (11,14)
07af 23        INC     HL          ;    ''
07b0 72        LD      (HL),D      ; Display number of coins for 2 players at (11,14)
07b1 7A        LD      A,D         ; A = num coins for 2 players
07b2 D60A      SUB     0AH         ; A -= 10
07b4 C2BC07    JP      NZ,07BCH    ; Skip ahead if num coins for 2 players < 10

07b7 77        LD      (HL),A      ; Display '0' at (11,14)
07b8 3C        INC     A           ; A = '1'
07b9 328E75    LD      (758EH),A   ; Display '1' at (12,14)

; Display '1' and '2' during the next
; execution of this code
07bc 110102    LD      DE,0201H    ; D = '2', E = '1'
07bf 218C76    LD      HL,768CH    ; HL = (20,12)
07c2 C9        RET                 ; Done
;----------------------------------



;---------------------------------
; Called when gameMode == 1 and 
; currentScreen == 5
; Clear the demo screen
ClearDemoScreen:
07c3 CD7408    CALL    ClearScreenAndSprites
07c6 210A60    LD      HL,currentScreen ; currentScreen = 6
07c9 34        INC     (HL)       ;    ''
07ca C9        RET                ; Done
;--------------------------------- 



;--------------------------------- 
; Called when gameMode = 1 (demo mode)
; and currentScreen = 6 (flash title screen)
; Display the title screen with the
; words "DONKEY KONG"
DisplayTitleScreen:
07cb 3A8A63    LD      A,(titleScreenPaletteCycle)  ; If (titleScreenPaletteCycle) > 0
07ce FE00      CP      00H        ;    jump ahead
07d0 C22D08    JP      NZ,082DH   ;    ''

07d3 3E60      LD      A,60H      ; (titleScreenPaletteCycle) = 96 (b 1001 0110)
07d5 328A63    LD      (titleScreenPaletteCycle),A  ;    ''
07d8 0E5F      LD      C,5FH      ; 

07da FE00      CP      00H        ; If (titleScreenPaletteCycle) == 0
07dc CA3B08    JP      Z,083BH    ;    jump ahead
07df 21867D    LD      HL,palette1   ; (palette1) = 0
07e2 3600      LD      (HL),00H   ;    ''
07e4 79        LD      A,C        ; If bit 8 of (titleScreenPaletteCycle) == 0
07e5 CB07      RLC     A          ;    jump ahead
07e7 3002      JR      NC,07EBH   

07e9 3601      LD      (HL),01H   ; (palette1) = 1 ; Set palette?
07eb 23        INC     HL         ; (palette2) = 0
07ec 3600      LD      (HL),00H   ;    ''
07ee CB07      RLC     A          ; If bit 7 of (titleScreenPaletteCycle) == 0
07f0 3002      JR      NC,07F4H   ;    jump ahead

07f2 3601      LD      (HL),01H   ; (palette2) = 1 ; Set palette?

07f4 328B63    LD      (titleScreenPalette),A ; (titleScreenPalette) = A

07f7 21083D    LD      HL,DonkeyKongBigText
07fa 3EB0      LD      A,0B0H     ; A = Girder Tile
07fc 46        LD      B,(HL)     ; B = line length
07fd 23        INC     HL         ; DE = top coord of line
07fe 5E        LD      E,(HL)     ;    ''
07ff 23        INC     HL         ;    ''
0800 56        LD      D,(HL)     ;    ''

0801 12        LD      (DE),A     ; Display tile at current coord
0802 13        INC     DE         ; DE = next row down
0803 10FC      DJNZ    0801H      ; Next B

0805 23        INC     HL         ; HL = address of next data entry
0806 7E        LD      A,(HL)     ; If next line length is > 0
0807 FE00      CP      00H        ;    Draw next line
0809 C2FA07    JP      NZ,07FAH   ;    ''

080c 111E03    LD      DE,031EH   ; Display "©1981"
080f CD9F30    CALL    AddFunctionToUpdateList
0812 13        INC     DE         ; Display "NINTENDO OF AMERICA"
0813 CD9F30    CALL    AddFunctionToUpdateList
; Load and position DK
0816 21CF39    LD      HL,DKSpriteDataGrinLArmRLegUp
0819 CD4E00    CALL    LoadDKSprites
081c CD243F    CALL    DisplayTM
081f 00        NOP     
0820 210869    LD      HL,dkSprite1X
0823 0E44      LD      C,44H
0825 FF        RST     MoveDKSprites
0826 210B69    LD      HL,dkSprite1Y
0829 0E78      LD      C,78H
082b FF        RST     MoveDKSprites
082c C9        RET   

082d 3A8B63    LD      A,(titleScreenPalette)   ; C = (titleScreenPalette)
0830 4F        LD      C,A         ;    ''
0831 3A8A63    LD      A,(titleScreenPaletteCycle)   ; --(titleScreenPaletteCycle)
0834 3D        DEC     A           ;    ''
0835 328A63    LD      (titleScreenPaletteCycle),A   ;    ''
0838 C3DA07    JP      07DAH

083b 210960    LD      HL,minorTimer ; minorTimer = 2
083e 3602      LD      (HL),02H    ;    ''
0840 23        INC     HL          ; currentScreen = 7 (pause on title screen)
0841 34        INC     (HL)        ;    ''
0842 218A63    LD      HL,titleScreenPaletteCycle ; Reset palette
0845 3600      LD      (HL),00H    ;    ''
0847 23        INC     HL          ;    ''
0848 3600      LD      (HL),00H    ;    ''
084a C9        RET     
;----------------------------------



;----------------------------------
; Called when gameMode = 1 (demo mode)
; and currentScreen = 7 (pause on title screen)
PauseOnTitleScreen:
084b E7        RST     ContinueWhenTimerReaches0
084c 210A60    LD      HL,currentScreen
084f 3600      LD      (HL),00H
0851 C9        RET     
;--------------------------------



;--------------------------------
ClearRight4Cols:
; Clear the rightmost 4 columns
0852 210074    LD      HL,7400H
0855 0E04      LD      C,04H
0857 0600      LD      B,00H
0859 3E10      LD      A,10H
085b 77        LD      (HL),A
085c 23        INC     HL
085d 10FC      DJNZ    085BH
085f 0D        DEC     C
0860 C25708    JP      NZ,0857H
; Clear sprites
0863 210069    LD      HL,paulineUpperSpriteX
0866 0E02      LD      C,02H
0868 06C0      LD      B,0C0H
086a AF        XOR     A
086b 77        LD      (HL),A
086c 23        INC     HL
086d 10FC      DJNZ    086BH
086f 0D        DEC     C
0870 C26808    JP      NZ,0868H
0873 C9        RET     

;----------------------------------
; Clear the screen and all sprites
ClearScreenAndSprites:
; Clear the screen (all but first 4 rows)
0874 210474    LD      HL,7404H    ; HL = (0,4)
0877 0E20      LD      C,20H       ; For C = 32 to 1
0879 061C      LD      B,1CH       ; For B = 28 to 1
087b 3E10      LD      A,10H       ; A = ' '
087d 110400    LD      DE,0004H    ; DE = 4
0880 77        LD      (HL),A      ; Clear this screen coord
0881 23        INC     HL          ; HL = next row down
0882 10FC      DJNZ    0880H       ; Next B
0884 19        ADD     HL,DE       ; Skip the top 4 rows
0885 0D        DEC     C           ; Next C
0886 C27908    JP      NZ,0879H    ;    ''

; Clear (9,2) to (22,3)
0889 212275    LD      HL,7522H    ; HL = (9,2)
088c 112000    LD      DE,0020H    ; DE = 32
088f 0E02      LD      C,02H       ; For C = 2 to 1
0891 3E10      LD      A,10H       ; A = ' '
0893 060E      LD      B,0EH       ; For B = 14 to 1
0895 77        LD      (HL),A      ; Clear screen coord
0896 19        ADD     HL,DE       ; HL = next column left
0897 10FC      DJNZ    0895H       ; Next B
0899 212375    LD      HL,7523H    ; HL = (9,3)
089c 0D        DEC     C           ; Next C
089d C29308    JP      NZ,0893H    ;    ''

08a0 210069    LD      HL,paulineUpperSpriteX ; HL = address of paulineUpperSpriteX
08a3 0600      LD      B,00H       ; For B = 256 to 1
08a5 3E00      LD      A,00H       ; A = 0
08a7 77        LD      (HL),A      ; (HL) = 0
08a8 23        INC     HL          ; HL = next address 
08a9 10FC      DJNZ    08A7H       ; Next B

08ab 0680      LD      B,80H       ; For B = 128 to 1
08ad 77        LD      (HL),A      ; (HL) = 0
08ae 23        INC     HL          ; HL = next address
08af 10FC      DJNZ    08ADH       ; Next B

08b1 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Jump to one of the following two 
; addresses, based on currentScreen
StartGame:
08b2 3A0A60    LD      A,(currentScreen)
08b5 EF        RST     JumpToLocalTableAddress
08b6 BA08 ; 0 = DisplayPushStartPrompt
08b8 F808 ; 1 = Start1Or2Players
;----------------------------------



;----------------------------------
; Display the prompt to push 1 or 2
; player
; passed: none
; return: A containing the state of 
;         IN2, with 2 player start
;         filtered out if it is
;         invalid.
DisplayPushStartPrompt:
08ba CD7408    CALL    ClearScreenAndSprites
08bd AF        XOR     A          ; A = 0
08be 320760    LD      (demoMode),A ; demoMode = 0
08c1 110C03    LD      DE,030CH   ; Display "PUSH"
08c4 CD9F30    CALL    AddFunctionToUpdateList
08c7 210A60    LD      HL,currentScreen ; Advance to next screen
08ca 34        INC     (HL)       ;    ''
08cb CD6509    CALL    DisplayHighScores

08ce AF        XOR     A          ; A = 0
08cf 21867D    LD      HL,palette1   ; (palette1) = 0
08d2 77        LD      (HL),A     ;    ''
08d3 2C        INC     L          ; (palette2) = 0
08d4 77        LD      (HL),A     ;    ''

DisplayPush1Or2PlayerStart:
08d5 0604      LD      B,04H      ; Accept only 1 player button
08d7 1E09      LD      E,09H      ; E = 9 ("ONLY 1 PLAYER BUTTON")
08d9 3A0160    LD      A,(numCredits) ; If 1 credit is entered
08dc FE01      CP      01H        ;    jump ahead
08de CAE408    JP      Z,08E4H    ;    ''
08e1 060C      LD      B,0CH      ; Accept 1 and 2 player buttons
08e3 1C        INC     E          ; E = 10 ("1 OR 2 PLAYERS BUTTON")

08e4 3A1A60    LD      A,(counter1) ; A = counter1
08e7 E607      AND     07H        ; A = 3 LSB of counter1
08e9 C2F308    JP      NZ,08F3H   ; If 3LSB are not 0, jump ahead
08ec 7B        LD      A,E        ; A = E
08ed CDE905    CALL    DisplayString
08f0 CD1606    CALL    DisplayNumCredits2
08f3 3A007D    LD      A,(IN2)    ; A = coin/start buttons
08f6 A0        AND     B          ; Filter out invalid buttons
08f7 C9        RET                ; Done
;---------------------------------



;---------------------------------
; Starts the game in response to 
; the 1 or 2 player button being
; pressed with credits having been
; entered.
Start1Or2Players:
08f8 CDD508    CALL    DisplayPush1Or2PlayerStart
08fb FE04      CP      04H        ; If 1 player start pressed,
08fd CA0609    JP      Z,Label0906 ;    jump ahead
0900 FE08      CP      08H        ; If 2 player start pressed,
0902 CA1909    JP      Z,Label0919 ;    jump ahead
0905 C9        RET                ; Done 

Label0906:
0906 CD7709    CALL    RemoveOneCredit

; Clear player 2 variables
0909 214860    LD      HL,numLivesP2 ; HL = address of number of lives for player 2 
090c 0608      LD      B,08H      ; For B = 8 to 1
090e AF        XOR     A          ; A = 0
090f 77        LD      (HL),A     ; Current player variable = 0
0910 2C        INC     L          ; HL = address of next player variable
0911 10FC      DJNZ    090FH      ; Next B

0913 210000    LD      HL,0000H   ; HL = 0 (1 player, P2 inactive)
0916 C33809    JP      0938H      ; Jump ahead

Label0919:
0919 CD7709    CALL    RemoveOneCredit
091c CD7709    CALL    RemoveOneCredit
091f 114860    LD      DE,numLivesP2 ; DE = address of number of player 2 lives
0922 3A2060    LD      A,(numLivesSetting) ; A = number of lives setting
0925 12        LD      (DE),A     ; Initialize number of lives P2
0926 1C        INC     E          ; DE = address of P2 level number
0927 215E09    LD      HL,InitialPlayerData ; HL = 095EH
092a 010700    LD      BC,0007H   ; Load 7 bytes
092d EDB0      LDIR               ; Initialize P2 data
092f 110101    LD      DE,0101H   ; Clear P2 score
0932 CD9F30    CALL    AddFunctionToUpdateList
0935 210001    LD      HL,0100H   ; HL = 0100H (2 players, p2 inactive)

0938 220E60    LD      (player2Active),HL ; Save 2 players and P2 active variables
093b CD7408    CALL    ClearScreenAndSprites
093e 114060    LD      DE,numLivesP1 ; DE = address of num lives P1
0941 3A2060    LD      A,(numLivesSetting) ; A = num lives setting
0944 12        LD      (DE),A     ; Initiaze P1 num lives
0945 1C        INC     E          ; DE = address of P1 level num
0946 215E09    LD      HL,InitialPlayerData
0949 010700    LD      BC,0007H   ; BC = 7 bytes to copy
094c EDB0      LDIR               ; Initialize P1 data
094e 110001    LD      DE,0100H   ; Clear P1 score
0951 CD9F30    CALL    AddFunctionToUpdateList
0954 AF        XOR     A          ; currentScreen = 0
0955 320A60    LD      (currentScreen),A  ;    ''
0958 3E03      LD      A,03H      ; gameMode = 3 (playing the game)
095a 320560    LD      (gameMode),A ;    ''
095d C9        RET                ; Done
;---------------------------------



;---------------------------------
InitialPlayerData:
095e 01 ; Start on level 1
095f 653A ; Address of first entry in StageOrderTable
0961 01
0962 00 ; Bonus not awarded
0963 00
0964 00
;---------------------------------



;---------------------------------
DisplayHighScores:
0965 110004    LD      DE,0400H   ; Display the number of credits
0968 CD9F30    CALL    AddFunctionToUpdateList
; Display high scores
096b 111403    LD      DE,0314H   ; Display current high score
096e 0606      LD      B,06H      ; For B = 6 to 1
0970 CD9F30    CALL    AddFunctionToUpdateList
0973 1C        INC     E          ; Next high score
0974 10FA      DJNZ    0970H      ; Next B
0976 C9        RET                ; Done
;---------------------------------



;---------------------------------
; Remove 1 credit before starting the
; game.
RemoveOneCredit:
0977 210160    LD      HL,numCredits ; HL = address of numCredits
097a 3E99      LD      A,99H      ; A = 99H
097c 86        ADD     A,(HL)     ; Subtract 1 credit
097d 27        DAA                ;    ''
097e 77        LD      (HL),A     ;    ''
097f 110004    LD      DE,0400H   ; Display the number of credits
0982 CD9F30    CALL    AddFunctionToUpdateList
0985 C9        RET                ; Done
;---------------------------------



;---------------------------------
; Orients the screen based on
; the current player and the
; cabinet type
; Called when gameMode == 3 (playing
; the game) and currentScreen == 0
OrientScreen:
0986 CD5208    CALL    ClearRight4Cols
0989 CD1C01    CALL    TurnOffSounds
098c 11827D    LD      DE,flipScreen ; DE = address of flipScreen variable
098f 3E01      LD      A,01H      ; A = 1
0991 12        LD      (DE),A     ; Turn screen right side up
0992 210A60    LD      HL,currentScreen ; HL = address of currentScreen
0995 3A0E60    LD      A,(player2Active) ; A = player 2 active
0998 A7        AND     A          ; If player 2 active,
0999 C29F09    JP      NZ,099FH   ;    jump ahead
099c 3601      LD      (HL),01H   ; currentScreen = 1
099e C9        RET                ; Done
 
099f 3A2660    LD      A,(cabType) ; If upright cab,
09a2 3D        DEC     A          ;    jump ahead
09a3 CAA809    JP      Z,09A8H    ;    ''
09a6 AF        XOR     A          ; A = 0
09a7 12        LD      (DE),A     ; Flip screen upside down
09a8 3603      LD      (HL),03H   ; currentScreen = 3
09aa C9        RET                ; Done
;---------------------------------



;---------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 1
InitPlayer1:
09ab 214060    LD      HL,numLivesP1 ; HL = address of P1 num lives
09ae 112862    LD      DE,numLives ; DE = address of current P num lives
09b1 010800    LD      BC,0008H   ; 8 bytes to copy
09b4 EDB0      LDIR               ; Copy P1 info to current P info

09b6 2A2A62    LD      HL,(622AH) ; HL = (622AH)
09b9 7E        LD      A,(HL)     ; A = ((622AH))
09ba 322762    LD      (currentStage),A  ; (currentStage) = ((622AH))
09bd 3A0F60    LD      A,(twoPlayers) ; A = twoPlayers
09c0 A7        AND     A          ; Check if two players
09c1 210960    LD      HL,minorTimer   ; HL = minorTimer
09c4 110A60    LD      DE,currentScreen ; DE = address of currentScreen
09c7 CAD009    JP      Z,09D0H    ; If one player, jump ahead

09ca 3678      LD      (HL),78H   ; (minorTimer) = 120
09cc EB        EX      DE,HL      ; HL = address of currentScreen
09cd 3602      LD      (HL),02H   ; currentScreen = 2
09cf C9        RET                ; Done

09d0 3601      LD      (HL),01H   ; (minorTimer) = 1
09d2 EB        EX      DE,HL      ; HL = address of currentScreen
09d3 3605      LD      (HL),05H   ; currentScreen = 5
09d5 C9        RET                ; Done
;---------------------------------



;---------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 2.
; Display Player I prompt before
; showing the game intro
Player1Prompt:
09d6 AF        XOR     A          ; A = 0
09d7 32867D    LD      (palette1),A  ; Select palette?
09da 32877D    LD      (palette2),A  ;    ''
09dd 110203    LD      DE,0302H   ; Display "PLAYER (I)"
09e0 CD9F30    CALL    AddFunctionToUpdateList
09e3 110102    LD      DE,0201H   ; Display P2 score
09e6 CD9F30    CALL    AddFunctionToUpdateList
09e9 3E05      LD      A,05H      ; advance to screen mode 5
09eb 320A60    LD      (currentScreen),A ;    ''

Display2Up:
09ee 3E02      LD      A,02H      ; Display '2' at (7,0)
09f0 32E074    LD      (74E0H),A  ;    ''
09f3 3E25      LD      A,25H      ; Display 'U' at (6,0)
09f5 32C074    LD      (74C0H),A  ;    ''
09f8 3E20      LD      A,20H      ; Display 'P' at (5,0)
09fa 32A074    LD      (74A0H),A  ;    ''
09fd C9        RET                ; Done
;---------------------------------



;---------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 3.
; 
; Prepares to allow player 2 to play
InitPlayer2:
09fe 214860    LD      HL,numLivesP2 ; HL = address of num P2 lives
0a01 112862    LD      DE,numLives ; DE = address of current player num lives
0a04 010800    LD      BC,0008H   ; 8 bytes to copy
0a07 EDB0      LDIR               ; Copy P2 data to current player
0a09 2A2A62    LD      HL,(622AH) ; (currentStage) = ((622AH)
0a0c 7E        LD      A,(HL)     ;    ''
0a0d 322762    LD      (currentStage),A  ;    ''
0a10 3E78      LD      A,78H      ; (minorTimer) = 78H
0a12 320960    LD      (minorTimer),A  ;    ''
0a15 3E04      LD      A,04H      ; Advance to currentScreen 4
0a17 320A60    LD      (currentScreen),A ;    ''
0a1a C9        RET                ; Done
;---------------------------------



;---------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 4
Player2Prompt:
0a1b AF        XOR     A           ; Reset pallette
0a1c 32867D    LD      (palette1),A   ;    ''
0a1f 32877D    LD      (palette2),A   ;    ''
0a22 110303    LD      DE,0303H    ; Display "PLAYER (II)"
0a25 CD9F30    CALL    AddFunctionToUpdateList
0a28 110102    LD      DE,0201H    ; Display P2 score
0a2b CD9F30    CALL    AddFunctionToUpdateList
0a2e CDEE09    CALL    Display2Up ; 
0a31 3E05      LD      A,05H      ; Advance to currentScreen 5
0a33 320A60    LD      (currentScreen),A ;    ''
0a36 C9        RET     
;---------------------------------



;---------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 5
DisplayPlayer1:
0a37 110403    LD      DE,0304H   ; Display "HIGH SCORE"
0a3a CD9F30    CALL    AddFunctionToUpdateList
0a3d 110202    LD      DE,0202H   ; Display the high score
0a40 CD9F30    CALL    AddFunctionToUpdateList
0a43 110002    LD      DE,0200H   ; Display P1 score
0a46 CD9F30    CALL    AddFunctionToUpdateList
0a49 110006    LD      DE,0600H   ; Display lives and level num
0a4c CD9F30    CALL    AddFunctionToUpdateList
0a4f 210A60    LD      HL,currentScreen ; Advance to screen mode 6
0a52 34        INC     (HL)       ;    ''

Display1Up:
0a53 3E01      LD      A,01H       ; A = '1'
0a55 324077    LD      (7740H),A   ; (26,0) = '1'
0a58 3E25      LD      A,25H       ; A = 'U'
0a5a 322077    LD      (7720H),A   ; (25,0) = 'U'
0a5d 3E20      LD      A,20H       ; A = 'P'
0a5f 320077    LD      (7700H),A   ; (24,0) = 'P'
0a62 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 6
;
; Triggers the intro mode if the current
; player has not seen it yet, otherwise 
; trigger the intermission screen
TriggerIntroOrIntermission:
0a63 DF        RST     ReturnIfNotMinorTimeout ; Return from calling function until (minorTimer) == 0
0a64 CD7408    CALL    ClearScreenAndSprites
0a67 210960    LD      HL,minorTimer ; minorTimer = 1
0a6a 3601      LD      (HL),01H    ;    ''
0a6c 2C        INC     L           ; If the intro has not 
0a6d 34        INC     (HL)        ;    been displayed for
0a6e 112C62    LD      DE,introDisplayed ;    this player, 
0a71 1A        LD      A,(DE)      ;    currentScreen = 7
0a72 A7        AND     A           ;    else
0a73 C0        RET     NZ          ;    currentScreen = 8
0a74 34        INC     (HL)        ;    ''
0a75 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Called when gameMode == 3 (playing
; the game) and currentScreen == 7
;
; Display each part of the intro
; stage.
ImplementIntroStage:
0a76 3A8563    LD      A,(introMode)   ; A = introMode
0a79 EF        RST     JumpToLocalTableAddress
0a7a 8A0A ; 0 = DisplayIntroStage
0a7c BF0A ; 1 = PrepareIntroSprites
0a7e E80A ; 2 = AnimateIntroClimbingSequence (???)
0a80 6930 ; 3 = PauseBeforeNextMode
0a82 060B ; 4 = AnimateIntroScreen
0a84 6930 ; 5 = PauseBeforeNextMode
0a86 680B ; 6 = AnimateDKJumping
0a88 B30B ; 7 = DKGrinAndRoar
;----------------------------------



;----------------------------------
; Called when introMode == 0
DisplayIntroStage:
0a8a AF        XOR     A           ; Select pallette 01
0a8b 32867D    LD      (palette1),A   ;    ''
0a8e 3C        INC     A           ;    ''
0a8f 32877D    LD      (palette2),A   ;    ''
0a92 110D38    LD      DE,380DH    ; DE = Address of intro screen data
0a95 CDA70D    CALL    DisplayStage
0a98 3E10      LD      A,10H       ; A = ' '
0a9a 32A376    LD      (76A3H),A   ; Display ' ' at (21,3)
0a9d 326376    LD      (7663H),A   ; Display ' ' at (19,3)
0aa0 3ED4      LD      A,0D4H      ; A = girder offset y4
0aa2 32AA75    LD      (75AAH),A   ; Display girder at (13,10)
0aa5 AF        XOR     A           ; A = 0
0aa6 32AF62    LD      (climbDelay),A ; climbDelay = 0
0aa9 21B438    LD      HL,DKLadderJumpVectorData ; pNextYVector1 = address of DKLadderJumpVectorData
0aac 22C263    LD      (pNextYVector1),HL  ;    ''
0aaf 21CB38    LD      HL,DKJumpVectorData ; (pNextYVector2) = DKJumpVectorData
0ab2 22C463    LD      (pNextYVector2),HL  ;    ''
0ab5 3E40      LD      A,40H       ; A = 64
0ab7 320960    LD      (minorTimer),A ; Set minorTimer to 64
0aba 218563    LD      HL,introMode ; Increment introMode
0abd 34        INC     (HL)        ;    ''
0abe C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Called when introMode == 1
; Prepare the sprites of Donkey Kong
; climbing the ladder carrying 
; Pauline.
PrepareIntroSprites:
0abf DF        RST     ReturnIfNotMinorTimeout ; Don't continue until minor timer has run out
0ac0 218C38    LD      HL,DKSpriteDataClimbing ; Load Donkey Kong climbing
0ac3 CD4E00    CALL    LoadDKSprites ;    ladder sprire
0ac6 210869    LD      HL,dkSprite1X ; Move Donkey Kong sprite
0ac9 0E30      LD      C,30H       ;    right 48 pixels
0acb FF        RST     MoveDKSprites ;    ''
0acc 210B69    LD      HL,dkSprite1Y    ; Move Donkey Kong sprite
0acf 0E99      LD      C,99H       ;    down 153 pixels
0ad1 FF        RST     MoveDKSprites ;    ''
0ad2 3E1F      LD      A,1FH       ; ladderEraseRow = 31 
0ad4 328E63    LD      (ladderEraseRow),A ;    (bottom of ladder)
0ad7 AF        XOR     A           ; A = 0
0ad8 320C69    LD      (dkSprite2X),A   ; 
0adb 218A60    LD      HL,currentSong ; Set currentSong to 1 (intro tune)
0ade 3601      LD      (HL),01H    ;    ''
0ae0 23        INC     HL          ; Set currentSongDuration to 3
0ae1 3603      LD      (HL),03H    ;    ''
0ae3 218563    LD      HL,introMode ; Set introMode to 2
0ae6 34        INC     (HL)        ;    ''
0ae7 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Called when introMode == 2
AnimateIntroClimbingSequence:
0ae8 CD6F30    CALL    AnimateDKClimbing    
0aeb 3AAF62    LD      A,(climbDelay)
0aee E60F      AND     0FH         ; Draw up on row of the ladders
0af0 CC4A30    CALL    Z,DrawUpLadders ;    every time DK climbs 8 pixels
0af3 3A0B69    LD      A,(dkSprite1Y) ; Return if DK is lower
0af6 FE5D      CP      5DH         ;    than 5DH (???)
0af8 D0        RET     NC          ;    ''

0af9 3E20      LD      A,20H       ; Set minorTimer to 32
0afb 320960    LD      (minorTimer),A ;    ''
0afe 218563    LD      HL,introMode ; Set pCurrentMode to introMode
0b01 34        INC     (HL)        ;    ''
0b02 22C063    LD      (pCurrentMode),HL ;    ''
0b05 C9        RET                 ; Done
;----------------------------------  



;----------------------------------
; Called when introMode == 4
; Animates the introduction screen -
; DK climbing the ladders, raising
; the ladders, and jumping to the 
; top platform
AnimateIntroScreen:
0b06 3A1A60    LD      A,(counter1) ; Return if counter1 is odd?
0b09 0F        RRCA                ;    ''
0b0a D8        RET     C           ;    ''

0b0b 2AC263    LD      HL,(pNextYVector1)  ; Jump ahead if 
0b0e 7E        LD      A,(HL)      ;    DK has finished jumping 
0b0f FE7F      CP      7FH         ;    onto the top 
0b11 CA1E0B    JP      Z,0B1EH     ;    platform
0b14 23        INC     HL          ; ++(pNextYVector1)
0b15 22C263    LD      (pNextYVector1),HL  ;    ''
0b18 4F        LD      C,A         ; C = (pNextYVector1)
0b19 210B69    LD      HL,dkSprite1Y ; Move dk up by amount in (pNextYVector1)
0b1c FF        RST     MoveDKSprites
0b1d C9        RET                 ; Done

0b1e 215C38    LD      HL,DKLeftArmRaisedSpriteData
0b21 CD4E00    CALL    LoadDKSprites 
0b24 110069    LD      DE,paulineUpperSpriteX ; Copy left, right arms sprite data
0b27 010800    LD      BC,0008H    ;    to paulineUpperSpriteX - paulineLowerSpriteY
0b2a EDB0      LDIR                ;    ''
0b2c 210869    LD      HL,dkSprite1X ; Move DK 80 pixels right
0b2f 0E50      LD      C,50H       ;    ''
0b31 FF        RST     MoveDKSprites ;    ''
0b32 210B69    LD      HL,dkSprite1Y ; Move DK up 3 pixels
0b35 0EFC      LD      C,0FCH      ;    ''
0b37 FF        RST     MoveDKSprites ;    ''
0b38 CD4A30    CALL    DrawUpLadders
0b3b 3A8E63    LD      A,(ladderEraseRow) ; If the ladder has not been
0b3e FE0A      CP      0AH         ;    completely pulled up,
0b40 C2380B    JP      NZ,0B38H    ;    keep pulling it up
 
0b43 3E03      LD      A,03H       ; (soundEffect) = 3 (stomp)
0b45 328260    LD      (soundEffect),A   ;    ''
0b48 112C39    LD      DE,IntroScreenSloped6thPlatformTileData
0b4b CDA70D    CALL    DisplayStage
0b4e 3E10      LD      A,10H       ; Clear the final tiles from 
0b50 32AA74    LD      (74AAH),A   ;    the straight platform
0b53 328A74    LD      (748AH),A   ;    ''
0b56 3E05      LD      A,05H       ; (numJumps) = 5
0b58 328D63    LD      (numJumps),A
0b5b 3E20      LD      A,20H       ; Set minorTimer to 32
0b5d 320960    LD      (minorTimer),A ;    ''
0b60 218563    LD      HL,introMode ; introMode = 5
0b63 34        INC     (HL)        ;    ''
0b64 22C063    LD      (pCurrentMode),HL ; pCurrentMode = address of introMode
0b67 C9        RET     
;----------------------------------



;----------------------------------
; Animate DK jumping across the top
; platform.
; Called when introMode == 6
AnimateDKJumping:
0b68 3A1A60    LD      A,(counter1) ; Only continue
0b6b 0F        RRCA                ;    when counter1 is even?
0b6c D8        RET     C           ;    ''

0b6d 2AC463    LD      HL,(pNextYVector2)  ; Jump ahead if done
0b70 7E        LD      A,(HL)      ;    with this jump
0b71 FE7F      CP      7FH         ;    ''
0b73 CA860B    JP      Z,0B86H     ;    ''

0b76 23        INC     HL          ; Increment (pNextYVector2)
0b77 22C463    LD      (pNextYVector2),HL  ;    ''
0b7a 210B69    LD      HL,dkSprite1Y ; HL = DK sprite position
0b7d 4F        LD      C,A         ; Move DK up (pNextYVector2) pixels
0b7e FF        RST     MoveDKSprites ;    ''
0b7f 210869    LD      HL,dkSprite1X ; Move DK left 1 pixel
0b82 0EFF      LD      C,0FFH      ;    ''
0b84 FF        RST     MoveDKSprites ;    ''
0b85 C9        RET                 ; Done

0b86 21CB38    LD      HL,DKJumpVectorData ; pNextYVector2 = DKJumpVectorData
0b89 22C463    LD      (pNextYVector2),HL ;    ''
0b8c 3E03      LD      A,03H       ; (soundEffect) = 3 (stomp)
0b8e 328260    LD      (soundEffect),A ;    ''
0b91 21DC38    LD      HL,38DCH    ; HL = 38DCH
0b94 3A8D63    LD      A,(numJumps) A = numJumps - 1
0b97 3D        DEC     A
0b98 07        RLCA                ; A *= 16
0b99 07        RLCA    
0b9a 07        RLCA    
0b9b 07        RLCA    
0b9c 5F        LD      E,A         ; DE = (numJumps - 1) * 16
0b9d 1600      LD      D,00H
0b9f 19        ADD     HL,DE       ; DE = 38DCH + DE
0ba0 EB        EX      DE,HL       
0ba1 CDA70D    CALL    DisplayStage ; Display next sloped platform
0ba4 218D63    LD      HL,numJumps ; Decrement numJumps
0ba7 35        DEC     (HL)
0ba8 C0        RET     NZ          ; Return if more jumps to go

0ba9 3EB0      LD      A,0B0H      ; minorTimer = 176
0bab 320960    LD      (minorTimer),A
0bae 218563    LD      HL,introMode ; introMode = 7
0bb1 34        INC     (HL)
0bb2 C9        RET   
;----------------------------------  



;----------------------------------
; Display DKs grin at the end
; of the intro screen
; Called when introMode == 7
DKGrinAndRoar:
0bb3 218A60    LD      HL,currentSong ; HL = address of currentSong
0bb6 3A0960    LD      A,(minorTimer) ; A = minorTimer
0bb9 FE90      CP      90H         ; Jump ahead if minorTimer != 90H
0bbb 200B      JR      NZ,0BC8H    ;    ''
0bbd 360F      LD      (HL),0FH    ; currentSong = 15 (Gorilla roar)
0bbf 23        INC     HL          ; currentSongDuration = 3
0bc0 3603      LD      (HL),03H    ;    ''
0bc2 211969    LD      HL,dkHeadSprite ; HL = dkHeadSprite
0bc5 34        INC     (HL)        ; Change to grinning head sprite
0bc6 1809      JR      0BD1H       ; Jump ahead

0bc8 FE18      CP      18H         ; Jump ahead if minorTimer != 18H
0bca 2005      JR      NZ,0BD1H    ;    ''
0bcc 211969    LD      HL,dkHeadSprite    ; Change to frowning head sprite
0bcf 35        DEC     (HL)        ;    ''
0bd0 00        NOP     

0bd1 DF        RST     ReturnIfNotMinorTimeout         ; Don't continue until minorTimer has run out
0bd2 AF        XOR     A           ; introMode = 0
0bd3 328563    LD      (introMode),A ;    ''
0bd6 34        INC     (HL)        ; minorTimer = 1
0bd7 23        INC     HL          ; currentScreen = 8
0bd8 34        INC     (HL)        ;    ''
0bd9 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Display Intermission scene with
; the funky gorilla and height display
; Called when currentScreen == 8
ImplementIntermission:
0bda CD1C01    CALL    TurnOffSounds
0bdd DF        RST     ReturnIfNotMinorTimeout
0bde CD7408    CALL    ClearScreenAndSprites
0be1 1606      LD      D,06H       ; Redisplay lives and level
0be3 3A0062    LD      A,(marioAlive) ;    Subtract 1 life if Mario
0be6 5F        LD      E,A         ;    is alive?
0be7 CD9F30    CALL    AddFunctionToUpdateList
0bea 21867D    LD      HL,palette1    ; (palette1) = 1
0bed 3601      LD      (HL),01H
0bef 23        INC     HL
0bf0 3600      LD      (HL),00H    ; (palette2) = 0
0bf2 218A60    LD      HL,currentSong ; Play intermission song
0bf5 3602      LD      (HL),02H    ;    ''
0bf7 23        INC     HL          ; currentSongDuration = 3?
0bf8 3603      LD      (HL),03H    ;    ''
0bfa 21A763    LD      HL,currentHeightIndex    ; (currentHeightIndex) = 0
0bfd 3600      LD      (HL),00H    ;    ''
0bff 21DC76    LD      HL,76DCH    ; heightDisplayCoord = (22,28)
0c02 22A863    LD      (heightDisplayCoord),HL ;    ''

0c05 3A2E62    LD      A,(levelHeightIndex) ; Force levelHeightIndex to be
0c08 FE06      CP      06H         ;    5 or less
0c0a 3805      JR      C,0C11H     ;    ''
0c0c 3E05      LD      A,05H       ;    ''
0c0e 322E62    LD      (levelHeightIndex),A ;    ''

0c11 3A2F62    LD      A,(622FH)   ; If (622FH) == (622AH) 
0c14 47        LD      B,A         ;    jump ahead
0c15 3A2A62    LD      A,(622AH)   ;    ''
0c18 B8        CP      B           ;    ''
0c19 2804      JR      Z,0C1FH     ;    ''
0c1b 212E62    LD      HL,levelHeightIndex ; ++ (levelHeightIndex)
0c1e 34        INC     (HL)        ;    ''

0c1f 322F62    LD      (622FH),A   ; (622FH) = (622AH)
0c22 3A2E62    LD      A,(levelHeightIndex)   ; B = levelHeightIndex
0c25 47        LD      B,A         ;    ''

; Display intermission gorilla
0c26 21BC75    LD      HL,75BCH    ; (13,28) 
DisplayHeightAndGorilla:
0c29 0E50      LD      C,50H       ; C = first char in gorilla
DisplayColumnOfGorilla:
0c2b 71        LD      (HL),C      ; Display one column of gorilla graphic
0c2c 0C        INC     C           ;    ''
0c2d 2B        DEC     HL          ;    ''
0c2e 71        LD      (HL),C      ;    ''
0c2f 0C        INC     C           ;    ''
0c30 2B        DEC     HL          ;    ''
0c31 71        LD      (HL),C      ;    ''
0c32 0C        INC     C           ;    ''
0c33 2B        DEC     HL          ;    ''
0c34 71        LD      (HL),C      ;    ''

0c35 79        LD      A,C         ; Stop displaying
0c36 FE67      CP      67H         ;    when the last 
0c38 CA430C    JP      Z,0C43H     ;    char has been displayed

0c3b 0C        INC     C           ; C = next char in gorilla graphic
0c3c 112300    LD      DE,0023H    ; Advance HL to next column left
0c3f 19        ADD     HL,DE       ;    ''
0c40 C32B0C    JP      DisplayColumnOfGorilla ; Display next column of gorilla graphic

0c43 3AA763    LD      A,(currentHeightIndex) ; ++(currentHeightIndex)
0c46 3C        INC     A           ;    ''
0c47 32A763    LD      (currentHeightIndex),A   ;    ''
0c4a 3D        DEC     A           ; A = original currentHeightIndex
0c4b CB27      SLA     A           ; A = offset of height text
0c4d CB27      SLA     A           ;    (currentHeightIndex * 4)
0c4f E5        PUSH    HL          ; Save HL
0c50 21F03C    LD      HL,HeightTextTable ; HL = address of HeightTextTable
0c53 C5        PUSH    BC          ; Save HL
0c54 DD2AA863  LD      IX,(heightDisplayCoord)
0c58 4F        LD      C,A         ; BC = height text offset
0c59 0600      LD      B,00H       ;    ''
0c5b 09        ADD     HL,BC       ; HL = HeightTextTable + text offset
0c5c 7E        LD      A,(HL)      ; A = first char in height
0c5d DD7760    LD      (IX+60H),A  ; Display char 3 columns left of heightDisplayCoord 
0c60 23        INC     HL          ; A = second char in height
0c61 7E        LD      A,(HL)      ;    ''
0c62 DD7740    LD      (IX+40H),A  ; Display char 2 columns left of heightDisplayCoord
0c65 23        INC     HL          ; A = third char in height
0c66 7E        LD      A,(HL)      ;    ''
0c67 DD7720    LD      (IX+20H),A  ; Display char 1 column left of heightDisplayCoord
0c6a DD36E08B  LD      (IX-20H),8BH ; Display 'm' 1 column right of heightDisplayCoord
0c6e C1        POP     BC          ; B = levelHeightIndex, C = next char in gorilla
0c6f DDE5      PUSH    IX          ; Save IX
0c71 E1        POP     HL          ; HL = heightDisplayCoord
0c72 11FCFF    LD      DE,0FFFCH   ; HL = coord of next height display
0c75 19        ADD     HL,DE       ;    ''
0c76 22A863    LD      (heightDisplayCoord),HL  ; heightDisplayCoord = HL
0c79 E1        POP     HL          ; HL = coord for next char in gorilla
0c7a 115FFF    LD      DE,0FF5FH   ; DE = -161
0c7d 19        ADD     HL,DE       ; HL = 5 columns right
0c7e 05        DEC     B           ; --levelHeightIndex
0c7f C2290C    JP      NZ,DisplayHeightAndGorilla

0c82 110703    LD      DE,0307H    ; Display "HOW HIGH CAN YOU GET?"
0c85 CD9F30    CALL    AddFunctionToUpdateList
0c88 210960    LD      HL,minorTimer ; Set minorTimer to 160
0c8b 36A0      LD      (HL),0A0H   ;    ''
0c8d 23        INC     HL          ; currentScreen += 2
0c8e 34        INC     (HL)        ;    ''
0c8f 34        INC     (HL)        ;    ''
0c90 C9        RET     
;----------------------------------



;----------------------------------
DisplayCurrentStage:
0c91 DF        RST     ReturnIfNotMinorTimeout

DisplayCurrentStage1:
0c92 CD7408    CALL    ClearScreenAndSprites
0c95 AF        XOR     A           ; A = 0
0c96 328C63    LD      (onScreenTimer),A ; 0 timer
0c99 110105    LD      DE,0501H    ; Display timer
0c9c CD9F30    CALL    AddFunctionToUpdateList
0c9f 21867D    LD      HL,palette1    ; Select palette 1
0ca2 3600      LD      (HL),00H    ;    ''
0ca4 23        INC     HL          ;    ''
0ca5 3601      LD      (HL),01H    ;    ''
0ca7 3A2762    LD      A,(currentStage)   ; A = (currentStage)
0caa 3D        DEC     A           ; If (currentStage) == 1 
0cab CAD40C    JP      Z,DisplayBarrelsStage
0cae 3D        DEC     A           ; If (currentStage) == 2
0caf CADF0C    JP      Z,DisplayPiesStage
0cb2 3D        DEC     A           ; If (currentStage) == 3
0cb3 CAF20C    JP      Z,DisplayElevatorStage

; Display code for rivets stage (stage 4)
DisplayRivetsStage:
0cb6 CD430D    CALL    DisplayRivetsPlatform
0cb9 21867D    LD      HL,palette1    ; Select pallette (???)
0cbc 3601      LD      (HL),01H    ;    ''
0cbe 3E0B      LD      A,0BH       ; (6089H) = 11
0cc0 328960    LD      (6089H),A   ;    ''
0cc3 118B3C    LD      DE,RivetsStageData ; DE = Start of rivets stage data

DisplaySelectedStage:
0cc6 CDA70D    CALL    DisplayStage
0cc9 3A2762    LD      A,(currentStage)   ; If (currentStage) == 4
0ccc FE04      CP      04H         ;    display rivets 
0cce CC000D    CALL    Z,DisplayRivets
0cd1 C3A03F    JP      Label3FA0

; Display code for barrels stage (stage 1)
DisplayBarrelsStage:
0cd4 11E43A    LD      DE,BarrelsStageData ; DE = 3AE$H
0cd7 3E08      LD      A,08H       ; (6089h) = 8
0cd9 328960    LD      (6089H),A   ;    ''
0cdc C3C60C    JP      DisplaySelectedStage

; Display code for pies stage (stage 2)
DisplayPiesStage:
0cdf 115D3B    LD      DE,PiesStageData
0ce2 21867D    LD      HL,palette1
0ce5 3601      LD      (HL),01H
0ce7 23        INC     HL
0ce8 3600      LD      (HL),00H
0cea 3E09      LD      A,09H
0cec 328960    LD      (6089H),A
0cef C3C60C    JP      DisplaySelectedStage

; Display code for elevators stage (stage 3)
DisplayElevatorStage:
0cf2 CD270D    CALL    DisplayElevatorBars
0cf5 3E0A      LD      A,0AH
0cf7 328960    LD      (6089H),A
0cfa 11E53B    LD      DE,ElevatorsStageData
0cfd C3C60C    JP      DisplaySelectedStage
;----------------------------------



;----------------------------------
; Display rivets on rivet level
DisplayRivets:
0d00 0608      LD      B,08H       ; For B = 8 to 1
0d02 21170D    LD      HL,0D17H    ; HL = 0D17H
0d05 3EB8      LD      A,0B8H      ; A = B8H
0d07 0E02      LD      C,02H       ; For C = 2 to 1
0d09 5E        LD      E,(HL)      ; DE = address from table
0d0a 23        INC     HL          ;    ''
0d0b 56        LD      D,(HL)      ;    ''
0d0c 23        INC     HL          ; HL = next table entry

0d0d 12        LD      (DE),A      ; Display A at DE coord
0d0e 3D        DEC     A           ; A --
0d0f 13        INC     DE          ; DE = next row down
0d10 0D        DEC     C           ; Next C

0d11 C20D0D    JP      NZ,0D0DH    ;    ''
0d14 10EF      DJNZ    0D05H       ; Next B
0d16 C9        RET     
;----------------------------------

; Coordinates of rivets
0d17 CA76 ; (22,10)
0d19 CF76 ; (22,15)
0d1b D476 ; (22,20)
0d1d D976 ; (22,25)
0d1f 2A75 ; (9,10)
0d11 2F75 ; (9,15)
0d23 3475 ; (9,20)
0d25 3975 ; (9,25)



;----------------------------------
; Display elevator bars on springs
; level
DisplayElevatorBars:
0d27 210D77    LD      HL,770DH    ; HL = (24,13)
0d2a CD300D    CALL    Label0D30   ; Draw bars from (24/25,13)-(24/25-29)
0d2d 210D76    LD      HL,760DH    ; HL = (16,13)

Label0D30:
0d30 0611      LD      B,11H       ; For B = 17 to 1
0d32 36FD      LD      (HL),0FDH   ; Display vertical bar 2 of 2
0d34 23        INC     HL          ; HL = next row down
0d35 10FB      DJNZ    0D32H       ; Next B

0d37 110F00    LD      DE,000FH    ; HL = next column left
0d3a 19        ADD     HL,DE       ;    ''

0d3b 0611      LD      B,11H       ; For B = 17 to 1
0d3d 36FC      LD      (HL),0FCH   ; Display vertical bar 1 of 2
0d3f 23        INC     HL          ; HL = next row down
0d40 10FB      DJNZ    0D3DH       ; Next B
0d42 C9        RET     
;----------------------------------



;----------------------------------
; Display the platform supports
; on the rivets level
DisplayRivetsPlatform:
0d43 218776    LD      HL,7687H    ; HL = (20,7)
0d46 CD4C0D    CALL    0D4CH
0d49 214775    LD      HL,7547H    ; HL = (10,7)

; The following code is executed twice.
; First, with HL = (20,7) - (20,11).
; Second, with HL = (10,7) - (10,11).
0d4c 0604      LD      B,04H       ; For B = 4 to 1
0d4e 36FD      LD      (HL),0FDH   ; Display vertical bar 1
0d50 23        INC     HL          ; HL = next row down
0d51 10FB      DJNZ    0D4EH       ; Next B

0d53 111C00    LD      DE,001CH    ; DE = 28
0d56 19        ADD     HL,DE       ; HL = next column left

0d57 0604      LD      B,04H       ; For B = 4 to 1
0d59 36FC      LD      (HL),0FCH   ; Display vertical bar 2
0d5b 23        INC     HL          ; HL = next row down
0d5c 10FB      DJNZ    0D59H       ; Next B

0d5e C9        RET     
;----------------------------------



;----------------------------------
Label0D5F:
0d5f CD560F    CALL    PrepareStage
0d62 CD4124    CALL    2441H
0d65 210960    LD      HL,minorTimer ; Set minorTimer to 64
0d68 3640      LD      (HL),40H
0d6a 23        INC     HL          ; currentScreen == 11
0d6b 34        INC     (HL)
0d6c 215C38    LD      HL,DKLeftArmRaisedSpriteData
0d6f CD4E00    CALL    LoadDKSprites
0d72 110069    LD      DE,paulineUpperSpriteX
0d75 010800    LD      BC,0008H
0d78 EDB0      LDIR    
0d7a 3A2762    LD      A,(currentStage)
0d7d FE04      CP      04H
0d7f 280A      JR      Z,0D8BH
0d81 0F        RRCA    
0d82 0F        RRCA    
0d83 D8        RET     C

0d84 210B69    LD      HL,dkSprite1Y
0d87 0EFC      LD      C,0FCH
0d89 FF        RST     MoveDKSprites
0d8a C9        RET     
;----------------------------------



0d8b 210869    LD      HL,dkSprite1X
0d8e 0E44      LD      C,44H
0d90 FF        RST     MoveDKSprites
0d91 110400    LD      DE,0004H
0d94 011002    LD      BC,0210H
0d97 210069    LD      HL,paulineUpperSpriteX
0d9a CD3D00    CALL    003DH
0d9d 01F802    LD      BC,02F8H
0da0 210369    LD      HL,paulineUpperSpriteY
0da3 CD3D00    CALL    003DH
0da6 C9        RET     



;----------------------------------
; Display the game field for a stage
;
; The stage data is read in starting
; at the memory location in DE and 
; ending when AAh is read in.
; 
; The stage data consists of 5 byte 
; entries.  Each entry causes a line
; of tiles to be drawn on the screen
; between two coordinates.
;    Byte 1 = Tile to display
;       00 = ladder
;       01 = broken ladder
;       02 = Girders in barrels stage
;       03 =
;       04 =
;       05 =
;       06 =
;       AA = Marks the end of stage data
;    Byte 2 = X1 coord
;       5 MSBs = The screen column
;          number (inverted)
;       3 LSBs = The tile offset (0-7)
;          within the column 
;    Byte 3 = Y1 coord
;       5 MSBs = The screen row
;          number (NOT inverted)
;       3 LSBs = The tile offset (0-7)
;          within the row 
;    Bytes 4,5 = X2, Y2 coord formatted
;       same as X1 and Y1 above
; 
; passed: ROM address in DE
DisplayStage:
0da7 1A        LD      A,(DE)      ; A = (DE)
0da8 32B363    LD      (63B3H),A   ; (63B3H) = (DE)
0dab FEAA      CP      0AAH        ; Return if (DE) == AAH
0dad C8        RET     Z           ;    ''

0dae 13        INC     DE          ; ++DE
0daf 1A        LD      A,(DE)      ; A = (DE)
0db0 67        LD      H,A         ; H = (DE)
0db1 44        LD      B,H         ; B = (DE)
0db2 13        INC     DE          ; ++DE
0db3 1A        LD      A,(DE)      ; A = (DE)
0db4 6F        LD      L,A         ; L = (DE)
0db5 4D        LD      C,L         ; C = (DE)
0db6 D5        PUSH    DE          ; Save DE
0db7 CDF02F    CALL    2FF0H       ; ???
0dba D1        POP     DE
0dbb 22AB63    LD      (63ABH),HL
0dbe 78        LD      A,B
0dbf E607      AND     07H
0dc1 32B463    LD      (63B4H),A
0dc4 79        LD      A,C
0dc5 E607      AND     07H
0dc7 32AF63    LD      (63AFH),A
0dca 13        INC     DE
0dcb 1A        LD      A,(DE)
0dcc 67        LD      H,A
0dcd 90        SUB     B
0dce D2D30D    JP      NC,0DD3H
0dd1 ED44      NEG     
0dd3 32B163    LD      (63B1H),A
0dd6 13        INC     DE
0dd7 1A        LD      A,(DE)
0dd8 6F        LD      L,A
0dd9 91        SUB     C
0dda 32B263    LD      (63B2H),A
0ddd 1A        LD      A,(DE)
0dde E607      AND     07H
0de0 32B063    LD      (63B0H),A
0de3 D5        PUSH    DE
0de4 CDF02F    CALL    2FF0H
0de7 D1        POP     DE
0de8 22AD63    LD      (63ADH),HL
0deb 3AB363    LD      A,(63B3H)
0dee FE02      CP      02H
0df0 F24F0E    JP      P,0E4FH
0df3 3AB263    LD      A,(63B2H)
0df6 D610      SUB     10H
0df8 47        LD      B,A
0df9 3AAF63    LD      A,(63AFH)
0dfc 80        ADD     A,B
0dfd 32B263    LD      (63B2H),A
0e00 3AAF63    LD      A,(63AFH)
0e03 C6F0      ADD     A,0F0H
0e05 2AAB63    LD      HL,(63ABH)
0e08 77        LD      (HL),A
0e09 2C        INC     L
0e0a D630      SUB     30H
0e0c 77        LD      (HL),A
0e0d 3AB363    LD      A,(63B3H)
0e10 FE01      CP      01H
0e12 C2190E    JP      NZ,0E19H
0e15 AF        XOR     A
0e16 32B263    LD      (63B2H),A
0e19 3AB263    LD      A,(63B2H)
0e1c D608      SUB     08H
0e1e 32B263    LD      (63B2H),A
0e21 DA2A0E    JP      C,0E2AH
0e24 2C        INC     L
0e25 36C0      LD      (HL),0C0H
0e27 C3190E    JP      0E19H
0e2a 3AB063    LD      A,(63B0H)
0e2d C6D0      ADD     A,0D0H
0e2f 2AAD63    LD      HL,(63ADH)
0e32 77        LD      (HL),A
0e33 3AB363    LD      A,(63B3H)
0e36 FE01      CP      01H
0e38 C23F0E    JP      NZ,0E3FH
0e3b 2D        DEC     L
0e3c 36C0      LD      (HL),0C0H
0e3e 2C        INC     L
0e3f 3AB063    LD      A,(63B0H)
0e42 FE00      CP      00H
0e44 CA4B0E    JP      Z,0E4BH
0e47 C6E0      ADD     A,0E0H
0e49 2C        INC     L
0e4a 77        LD      (HL),A
0e4b 13        INC     DE
0e4c C3A70D    JP      DisplayStage
0e4f 3AB363    LD      A,(63B3H)
0e52 FE02      CP      02H
0e54 C2E80E    JP      NZ,0EE8H
0e57 3AAF63    LD      A,(63AFH)
0e5a C6F0      ADD     A,0F0H
0e5c 32B563    LD      (63B5H),A
0e5f 2AAB63    LD      HL,(63ABH)
0e62 3AB563    LD      A,(63B5H)
0e65 77        LD      (HL),A
0e66 23        INC     HL
0e67 7D        LD      A,L
0e68 E61F      AND     1FH
0e6a CA780E    JP      Z,0E78H
0e6d 3AB563    LD      A,(63B5H)
0e70 FEF0      CP      0F0H
0e72 CA780E    JP      Z,0E78H
0e75 D610      SUB     10H
0e77 77        LD      (HL),A
0e78 011F00    LD      BC,001FH
0e7b 09        ADD     HL,BC
0e7c 3AB163    LD      A,(63B1H)
0e7f D608      SUB     08H
0e81 DACF0E    JP      C,0ECFH
0e84 32B163    LD      (63B1H),A
0e87 3AB263    LD      A,(63B2H)
0e8a FE00      CP      00H
0e8c CA620E    JP      Z,0E62H
0e8f 3AB563    LD      A,(63B5H)
0e92 77        LD      (HL),A
0e93 23        INC     HL
0e94 7D        LD      A,L
0e95 E61F      AND     1FH
0e97 CAA00E    JP      Z,0EA0H
0e9a 3AB563    LD      A,(63B5H)
0e9d D610      SUB     10H
0e9f 77        LD      (HL),A
0ea0 011F00    LD      BC,001FH
0ea3 09        ADD     HL,BC
0ea4 3AB163    LD      A,(63B1H)
0ea7 D608      SUB     08H
0ea9 DACF0E    JP      C,0ECFH
0eac 32B163    LD      (63B1H),A
0eaf 3AB263    LD      A,(63B2H)
0eb2 CB7F      BIT     7,A
0eb4 C2D30E    JP      NZ,0ED3H
0eb7 3AB563    LD      A,(63B5H)
0eba 3C        INC     A
0ebb 32B563    LD      (63B5H),A
0ebe FEF8      CP      0F8H
0ec0 C2C90E    JP      NZ,0EC9H
0ec3 23        INC     HL
0ec4 3EF0      LD      A,0F0H
0ec6 32B563    LD      (63B5H),A
0ec9 7D        LD      A,L
0eca E61F      AND     1FH
0ecc C2620E    JP      NZ,0E62H
0ecf 13        INC     DE
0ed0 C3A70D    JP      DisplayStage
0ed3 3AB563    LD      A,(63B5H)
0ed6 3D        DEC     A
0ed7 32B563    LD      (63B5H),A
0eda FEF0      CP      0F0H
0edc F2E50E    JP      P,0EE5H
0edf 2B        DEC     HL
0ee0 3EF7      LD      A,0F7H
0ee2 32B563    LD      (63B5H),A
0ee5 C3620E    JP      0E62H
0ee8 3AB363    LD      A,(63B3H)
0eeb FE03      CP      03H
0eed C21B0F    JP      NZ,0F1BH
0ef0 2AAB63    LD      HL,(63ABH)
0ef3 3EB3      LD      A,0B3H
0ef5 77        LD      (HL),A
0ef6 012000    LD      BC,0020H
0ef9 09        ADD     HL,BC
0efa 3AB163    LD      A,(63B1H)
0efd D610      SUB     10H
0eff DA140F    JP      C,0F14H
0f02 32B163    LD      (63B1H),A
0f05 3EB1      LD      A,0B1H
0f07 77        LD      (HL),A
0f08 012000    LD      BC,0020H
0f0b 09        ADD     HL,BC
0f0c 3AB163    LD      A,(63B1H)
0f0f D608      SUB     08H
0f11 C3FF0E    JP      0EFFH
0f14 3EB2      LD      A,0B2H
0f16 77        LD      (HL),A
0f17 13        INC     DE
0f18 C3A70D    JP      DisplayStage
0f1b 3AB363    LD      A,(63B3H)
0f1e FE07      CP      07H
0f20 F2CF0E    JP      P,0ECFH
0f23 FE04      CP      04H
0f25 CA4C0F    JP      Z,0F4CH
0f28 FE05      CP      05H
0f2a CA510F    JP      Z,0F51H
0f2d 3EFE      LD      A,0FEH
0f2f 32B563    LD      (63B5H),A
0f32 2AAB63    LD      HL,(63ABH)
0f35 3AB563    LD      A,(63B5H)
0f38 77        LD      (HL),A
0f39 012000    LD      BC,0020H
0f3c 09        ADD     HL,BC
0f3d 3AB163    LD      A,(63B1H)
0f40 D608      SUB     08H
0f42 32B163    LD      (63B1H),A
0f45 D2350F    JP      NC,0F35H
0f48 13        INC     DE
0f49 C3A70D    JP      DisplayStage
0f4c 3EE0      LD      A,0E0H
0f4e C32F0F    JP      0F2FH
0f51 3EB0      LD      A,0B0H
0f53 C32F0F    JP      0F2FH



;----------------------------------
; Reset all game variables before
; starting the next stage

; Clear 6200H to 6226H (game flags)
; (marioAlive, marioX, marioY, marioClimbing,
; etc...)
PrepareStage:
0f56 0627      LD      B,27H       ; For B = 39 to 1
0f58 210062    LD      HL,marioAlive ; HL = address of marioAlive
0f5b AF        XOR     A           ; Set variable to 0
0f5c 77        LD      (HL),A      ;    ''
0f5d 2C        INC     L           ; ++HL
0f5e 10FC      DJNZ    0F5CH       ; Next B

; Clear 6280H to 6AFFH (Game flags and sprites?)
0f60 0E11      LD      C,11H       ; For C = 17 to 1
0f62 1680      LD      D,80H       ; D = 128
0f64 218062    LD      HL,lLadderState    ; HL = lLadderState
0f67 42        LD      B,D         ; For B = 128 to 1
0f68 77        LD      (HL),A      ; Set variable to 0
0f69 23        INC     HL          ; ++HL
0f6a 10FC      DJNZ    0F68H       ; Next B
0f6c 0D        DEC     C           ; Next C
0f6d 20F8      JR      NZ,0F67H    ;    ''

0f6f 219C3D    LD      HL,DefaultVariableValues ; Load 3D9CH - 3DDBH
0f72 118062    LD      DE,lLadderState ;    into 6280H - 62C0H
0f75 014000    LD      BC,0040H    ;    ''
0f78 EDB0      LDIR                ;    ''

; Calculate the initial timer value
; (timer = level number * 10 + 40)
; (timer is capped at 80)
0f7a 3A2962    LD      A,(levelNum) ; A = level number
0f7d 47        LD      B,A         ; B = level number
0f7e A7        AND     A           ; Clear carry flag
0f7f 17        RLA     			; A *= 2
0f80 A7        AND     A		   ; Clear carry flag
0f81 17        RLA     		    ; A *= 2
0f82 A7        AND     A		   ; Clear carry flag
0f83 17        RLA     		    ; A *= 2
0f84 80        ADD     A,B		 ; A = level number * 9
0f85 80        ADD     A,B		 ; A = level number * 10
0f86 C628      ADD     A,28H	   ; A = A + 40
0f88 FE51      CP      51H		 ; Is A >= 81?
0f8a 3802      JR      C,0F8EH	 ; No, then skip ahead to 0F8E
0f8c 3E50      LD      A,50H	   ; Yes, then A = 80
0f8e 21B062    LD      HL,intTimer ; HL = address of internal timer
0f91 0603      LD      B,03H	   ; For B = 1 to 3
0f93 77        LD      (HL),A	  ; Store the timer number in intTimer, 62B1H, and 62B2H
0f94 2C        INC     L		   ; Advance to next memory address
0f95 10FC      DJNZ    0F93H	   ; Next B

0f97 87        ADD     A,A         ; B = internal timer * 2
0f98 47        LD      B,A         ;    ''
0f99 3EDC      LD      A,0DCH      ; A = 220
0f9b 90        SUB     B           ; If 220 - internal timer * 2
0f9c FE28      CP      28H         ;    < 40
0f9e 3002      JR      NC,0FA2H    ;    then
0fa0 3E28      LD      A,28H       ;    A = 40
0fa2 77        LD      (HL),A      ; 62B3H = 10
0fa3 2C        INC     L           ; 62B4H = 10
0fa4 77        LD      (HL),A      ;    ''
0fa5 210962    LD      HL,6209H    ; 6209H = 4
0fa8 3604      LD      (HL),04H    ;    ''
0faa 2C        INC     L           ; 620AH = 8
0fab 3608      LD      (HL),08H    ;    ''
0fad 3A2762    LD      A,(currentStage) ; A = currentStage
0fb0 4F        LD      C,A         ; C = currentStage
0fb1 CB57      BIT     2,A         ; If currentStage == rivets stage
0fb3 2016      JR      NZ,Label0FCB ;    jump ahead

0fb5 21006A    LD      HL,6A00H    ; HL = 6A00H
0fb8 3E4F      LD      A,4FH       ; A = 4FH
0fba 0603      LD      B,03H       ; For B = 3 to 1
0fbc 77        LD      (HL),A      ; (6A00H, 6A04H, 6A08H) = A (79, 95, 111)
0fbd 2C        INC     L           ; (6A01H, 6A05H, 6A06H) = 3AH (58)
0fbe 363A      LD      (HL),3AH    ;    ''
0fc0 2C        INC     L           ; (6A02H, 6A06H, 6A07H) = 0FH (15)
0fc1 360F      LD      (HL),0FH    ;    ''
0fc3 2C        INC     L           ; (6A03H, 6A07H, 6A08H) = 18H (24)
0fc4 3618      LD      (HL),18H    ;    ''
0fc6 2C        INC     L           ; 
0fc7 C610      ADD     A,10H       ; A += 16
0fc9 10F1      DJNZ    0FBCH       ; Next B

Label0FCB:
0fcb 79        LD      A,C         ; A = currentStage
0fcc EF        RST     JumpToLocalTableAddress
0fcd 0000 ; 0 = restart game
0fcf D70F ; 1 = SetupBarrelStageSprites
0fd1 1F10 ; 2 = SetupPiesStageSprites
0fd3 8710 ; 3 = SetupElevatorStageSprites
0fd5 3111 ; 4 = SetupRivetsStageSprites
;----------------------------------



;----------------------------------
SetupBarrelStageSprites:
0fd7 21DC3D    LD      HL,UprightBarrelSprites ; Load upright barrel sprites
0fda 11A869    LD      DE,69A8H    ;    ''
0fdd 011000    LD      BC,0010H    ;    ''
0fe0 EDB0      LDIR                ;    ''
0fe2 21EC3D    LD      HL,3DECH    ; Copy 5 4-byte blocks
0fe5 110764    LD      DE,6407H    ;    from 3DECH to 6407H
0fe8 0E1C      LD      C,1CH       ;    (each 4-byte block is
0fea 0605      LD      B,05H       ;    stored 28 bytes apart)
0fec CD2A12    CALL    Copy4ByteBlocks
0fef 21F43D    LD      HL,3DF4H
0ff2 CDFA11    CALL    11FAH
0ff5 21003E    LD      HL,BarrelStageOilCanSprite ; Load oil can sprite
0ff8 11FC69    LD      DE,69FCH    ;    ''
0ffb 010400    LD      BC,0004H    ;    ''
0ffe EDB0      LDIR                ;    ''
1000 210C3E    LD      HL,3E0CH
1003 CDA611    CALL    11A6H
1006 211B10    LD      HL,101BH
1009 110767    LD      DE,6707H
100c 011C08    LD      BC,081CH
100f CD2A12    CALL    Copy4ByteBlocks
1012 110768    LD      DE,6807H
1015 0602      LD      B,02H
1017 CD2A12    CALL    Copy4ByteBlocks
101a C9        RET     
;----------------------------------



;----------------------------------
101b 00
101c 00
101d 02
101e 02
;----------------------------------



;----------------------------------
SetupPiesStageSprites:
101f 21EC3D    LD      HL,3DECH    ; Copy 5 4-byte blocks
1022 110764    LD      DE,6407H    ;    from 3DECH to 6407H
1025 011C05    LD      BC,051CH    ;    (each block is stored
1028 CD2A12    CALL    Copy4ByteBlocks ;    28 bytes apart)
102b CD8611    CALL    1186H
102e 21183E    LD      HL,3E18H    ; Copy 6 4-byte blocks
1031 11A765    LD      DE,65A7H    ;    from 3E18H to 65A7H
1034 010C06    LD      BC,060CH    ;    (each block is stored
1037 CD2A12    CALL    Copy4ByteBlocks ;     12 bytes apart)
103a DD21A065  LD      IX,65A0H
103e 21B869    LD      HL,69B8H
1041 111000    LD      DE,0010H
1044 0606      LD      B,06H
1046 CDD311    CALL    11D3H
1049 21FA3D    LD      HL,3DFAH
104c CDFA11    CALL    11FAH
104f 21043E    LD      HL,PiesStageOilCanSprite ; Load oil can sprite
1052 11FC69    LD      DE,69FCH    ;    ''
1055 010400    LD      BC,0004H    ;    ''
1058 EDB0      LDIR                ;    ''
105a 211C3E    LD      HL,PiesStageLadderSprites ; Load retracting
105d 114469    LD      DE,6944H    ;    ladder sprites
1060 010800    LD      BC,0008H    ;    ''
1063 EDB0      LDIR                ;    ''
1065 21243E    LD      HL,PiesStagePulleySprites ; Load pulley sprites
1068 11E469    LD      DE,69E4H    ;    ''
106b 011800    LD      BC,0018H    ;    ''
106e EDB0      LDIR                ;    ''
1070 21103E    LD      HL,3E10H
1073 CDA611    CALL    11A6H
1076 213C3E    LD      HL,PiesStagePrizeSprites ; Load prize sprites
1079 110C6A    LD      DE,prizeSprite1X    ;    ''
107c 010C00    LD      BC,000CH    ;    ''
107f EDB0      LDIR                ;    ''
1081 3E01      LD      A,01H       ; (OilBarrelFireState) = 1
1083 32B962    LD      (OilBarrelFireState),A   ;    ''
1086 C9        RET                 ; Done
;----------------------------------



;----------------------------------
SetupElevatorStageSprites:
1087 21EC3D    LD      HL,3DECH
108a 110764    LD      DE,6407H
108d 011C05    LD      BC,051CH
1090 CD2A12    CALL    Copy4ByteBlocks
1093 CD8611    CALL    1186H
1096 210066    LD      HL,6600H
1099 111000    LD      DE,0010H
109c 3E01      LD      A,01H
109e 0606      LD      B,06H
10a0 77        LD      (HL),A
10a1 19        ADD     HL,DE
10a2 10FC      DJNZ    10A0H
10a4 0E02      LD      C,02H
10a6 3E08      LD      A,08H
10a8 0603      LD      B,03H
10aa 210D66    LD      HL,660DH
10ad 77        LD      (HL),A
10ae 19        ADD     HL,DE
10af 10FC      DJNZ    10ADH
10b1 3E08      LD      A,08H
10b3 0D        DEC     C
10b4 C2A810    JP      NZ,10A8H
10b7 21643E    LD      HL,3E64H
10ba 110366    LD      DE,6603H
10bd 010E06    LD      BC,060EH
10c0 CDEC11    CALL    11ECH
10c3 21603E    LD      HL,3E60H
10c6 110766    LD      DE,6607H
10c9 010C06    LD      BC,060CH
10cc CD2A12    CALL    Copy4ByteBlocks
10cf DD210066  LD      IX,6600H
10d3 215869    LD      HL,6958H
10d6 0606      LD      B,06H
10d8 111000    LD      DE,0010H
10db CDD311    CALL    11D3H
10de 21483E    LD      HL,ElevatorStagePrizeSprites ; Load prize sprites
10e1 110C6A    LD      DE,prizeSprite1X    ;    ''
10e4 010C00    LD      BC,000CH    ;    ''
10e7 EDB0      LDIR                ;    ''
10e9 DD210064  LD      IX,6400H
10ed DD360001  LD      (IX+00H),01H
10f1 DD360358  LD      (IX+03H),58H
10f5 DD360E58  LD      (IX+0EH),58H
10f9 DD360580  LD      (IX+05H),80H
10fd DD360F80  LD      (IX+0FH),80H
1101 DD362001  LD      (IX+20H),01H
1105 DD3623EB  LD      (IX+23H),EBH
1109 DD362EEB  LD      (IX+2EH),EBH
110d DD362560  LD      (IX+25H),60H
1111 DD362F60  LD      (IX+2FH),60H
1115 117069    LD      DE,6970H    ; Load motor sprites
1118 212111    LD      HL,ElevatorStageMotorSprites ;    ''
111b 011000    LD      BC,0010H    ;    ''
111e EDB0      LDIR                ;    ''
1120 C9        RET     
;----------------------------------



;----------------------------------
ElevatorStageMotorSprites:
1121 37 45 0F 60 ; Elevator motor
1125 37 45 8F F7 ; Elevator motor
1129 77 45 0F 60 ; Elevator motor
112d 77 45 8F F7 ; Elevator motor
;----------------------------------



;----------------------------------
SetupRivetsStageSprites:
1131 21F03D    LD      HL,3DF0H
1134 110764    LD      DE,6407H
1137 011C05    LD      BC,051CH
113a CD2A12    CALL    Copy4ByteBlocks
113d 21143E    LD      HL,3E14H
1140 CDA611    CALL    11A6H
1143 21543E    LD      HL,RivetsStagePrizeSprites ; Load prize sprites
1146 110C6A    LD      DE,prizeSprite1X    ;    ''
1149 010C00    LD      BC,000CH    ;    ''
114c EDB0      LDIR                ;    ''
114e 218211    LD      HL,1182H
1151 11A364    LD      DE,64A3H
1154 011E02    LD      BC,021EH
1157 CDEC11    CALL    11ECH
115a 217E11    LD      HL,117EH
115d 11A764    LD      DE,64A7H
1160 011C02    LD      BC,021CH
1163 CD2A12    CALL    Copy4ByteBlocks
1166 DD21A064  LD      IX,64A0H
116a DD360001  LD      (IX+00H),01H
116e DD362001  LD      (IX+20H),01H
1172 215069    LD      HL,6950H
1175 0602      LD      B,02H
1177 112000    LD      DE,0020H
117a CDD311    CALL    11D3H
117d C9        RET     
;----------------------------------



117e 3F        CCF     
117f 0C        INC     C
1180 08        EX      AF,AF'
1181 08        EX      AF,AF'
1182 73        LD      (HL),E
1183 50        LD      D,B
1184 8D        ADC     A,L
1185 50        LD      D,B

1186 21A211    LD      HL,11A2H
1189 110765    LD      DE,6507H
118c 010C0A    LD      BC,0A0CH
118f CD2A12    CALL    Copy4ByteBlocks
1192 DD210065  LD      IX,6500H
1196 218069    LD      HL,6980H
1199 060A      LD      B,0AH
119b 111000    LD      DE,0010H
119e CDD311    CALL    11D3H
11a1 C9        RET     

11a2 3B        DEC     SP
11a3 00        NOP     
11a4 02        LD      (BC),A
11a5 02        LD      (BC),A

11a6 118366    LD      DE,6683H
11a9 010E02    LD      BC,020EH
11ac CDEC11    CALL    11ECH
11af 21083E    LD      HL,3E08H
11b2 118766    LD      DE,6687H
11b5 010C02    LD      BC,020CH
11b8 CD2A12    CALL    Copy4ByteBlocks
11bb DD218066  LD      IX,6680H
11bf DD360001  LD      (IX+00H),01H
11c3 DD361001  LD      (IX+10H),01H
11c7 21186A    LD      HL,6A18H
11ca 0602      LD      B,02H
11cc 111000    LD      DE,0010H
11cf CDD311    CALL    11D3H
11d2 C9        RET     

11d3 DD7E03    LD      A,(IX+03H)
11d6 77        LD      (HL),A
11d7 2C        INC     L
11d8 DD7E07    LD      A,(IX+07H)
11db 77        LD      (HL),A
11dc 2C        INC     L
11dd DD7E08    LD      A,(IX+08H)
11e0 77        LD      (HL),A
11e1 2C        INC     L
11e2 DD7E05    LD      A,(IX+05H)
11e5 77        LD      (HL),A
11e6 2C        INC     L
11e7 DD19      ADD     IX,DE
11e9 10E8      DJNZ    11D3H
11eb C9        RET     

11ec 7E        LD      A,(HL)
11ed 12        LD      (DE),A
11ee 23        INC     HL
11ef 1C        INC     E
11f0 1C        INC     E
11f1 7E        LD      A,(HL)
11f2 12        LD      (DE),A
11f3 23        INC     HL
11f4 7B        LD      A,E
11f5 81        ADD     A,C
11f6 5F        LD      E,A
11f7 10F3      DJNZ    11ECH
11f9 C9        RET     



;----------------------------------
; passed: HL - source address
11fa DD21A066  LD      IX,66A0H    ; IX = 66A0H
11fe 11286A    LD      DE,oilFireSpriteX ; DE = address of oilFireSpriteX
1201 DD360001  LD      (IX+00H),01H ; (66A0H) = 1
1205 7E        LD      A,(HL)      ; (66A3H) = (HL)
1206 DD7703    LD      (IX+03H),A  ;    ''
1209 12        LD      (DE),A      ; oilFireSpriteX = (HL)
120a 1C        INC     E           ; DE = address of oilFireSpriteNum
120b 23        INC     HL          ; ++HL
120c 7E        LD      A,(HL)      ; (66A7H) = (HL)
120d DD7707    LD      (IX+07H),A  ;    ''
1210 12        LD      (DE),A      ; oilFireSpriteNum = (HL)
1211 1C        INC     E           ; DE = address of oilFireSpritePalette
1212 23        INC     HL          ; ++HL
1213 7E        LD      A,(HL)      ; (66A8H) = (HL)
1214 DD7708    LD      (IX+08H),A  ;    ''
1217 12        LD      (DE),A      ; oilFireSpritePalette = (HL)
1218 1C        INC     E           ; DE = address of oilFireSpriteY
1219 23        INC     HL          ; ++HL
121a 7E        LD      A,(HL)      ; (66A5H) = (HL)
121b DD7705    LD      (IX+05H),A  ;    ''
121e 12        LD      (DE),A      ; oilFireSpriteY = (HL)
121f 23        INC     HL          ; ++HL
1220 7E        LD      A,(HL)      ; (66A9H) = (HL)
1221 DD7709    LD      (IX+09H),A  ;    ''
1224 23        INC     HL          ; ++HL
1225 7E        LD      A,(HL)      ; (66AAH) = (HL)
1226 DD770A    LD      (IX+0AH),A  ;    ''
1229 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; passed: HL - starting source address
;         DE - starting dest. address
;         B - the number of 4-byte blocks
;            to copy
;         C - bytes between each 4-byte 
;            destination address
CopyNSprites:
122a E5        PUSH    HL         ; Save HL
122b C5        PUSH    BC         ; Save BC
122c 0604      LD      B,04H      ; For B = 4 to 1
122e 7E        LD      A,(HL)     ; Copy value at address in HL 
122f 12        LD      (DE),A     ;    to address in DE
1230 23        INC     HL         ; ++HL
1231 1C        INC     E          ; ++DE
1232 10FA      DJNZ    122EH      ; Next B
1234 C1        POP     BC         ; Restore BC
1235 E1        POP     HL         ; Restore HL
1236 7B        LD      A,E        ; DE += C
1237 81        ADD     A,C        ;    ''
1238 5F        LD      E,A        ;    ''
1239 10EF      DJNZ    Copy4ByteBlocks
123b C9        RET     
;----------------------------------



;----------------------------------
; Places the Mario sprite at the
; starting location for this stage.
; Called when gameMode == 3 and 
; currentScreen == 11
InitializeMarioSprite:
123c DF        RST     ReturnIfNotMinorTimeout ; Return unless minorTimer has reached 0
123d 3A2762    LD      A,(currentStage)   ; A = currentStage
1240 FE03      CP      03H         ; If currentStage == 3 (elevators)
1242 0116E0    LD      BC,E016H    ;    B = 224, C = 22
1245 CA4B12    JP      Z,124BH     ;    else
1248 013FF0    LD      BC,F03FH    ;    B = 240, C = 63
124b DD210062  LD      IX,marioAlive ; IX = address of marioAlive
124f 214C69    LD      HL,marioSpriteX ; HL = address of marioSpriteX
1252 DD360001  LD      (IX+00H),01H ; marioAlive = 1
1256 DD7103    LD      (IX+03H),C  ; marioX = C (22 or 63)
1259 71        LD      (HL),C      ; (marioSpriteX) = C
125a 2C        INC     L           ; HL = marioSpriteNum
125b DD360780  LD      (IX+07H),80H ; (marioSpriteNum1) = 00H flipped horiz (Mario)
125f 3680      LD      (HL),80H    ; (marioSpriteNum) = 00H flipped horiz (Mario)
1261 2C        INC     L           ; HL = marioSpritePalette
1262 DD360802  LD      (IX+08H),02H ; (marioSpritePalette1) = 2
1266 3602      LD      (HL),02H    ; (marioSpritePalette) = 2
1268 2C        INC     L           ; HL = marioSpriteY
1269 DD7005    LD      (IX+05H),B  ; (marioY) = B
126c 70        LD      (HL),B      ; marioSpriteY = B
126d DD360F01  LD      (IX+0FH),01H ; (620FH) = 1
1271 210A60    LD      HL,currentScreen ; currentScreen = 5
1274 34        INC     (HL)        ;    ''
1275 110106    LD      DE,0601H    ; Display lives and level (subtract 1 life first)
1278 CD9F30    CALL    AddFunctionToUpdateList
127b C9        RET     
;----------------------------------



;----------------------------------
; Called when gameMode == 1 (demo
; mode) and currentScreen == 5
ImplementDeathMode:
127c CDBD1D    CALL    ImplementPointAwards
127f 3A9D63    LD      A,(deathMode)
1282 EF        RST     JumpToLocalTableAddress
1283 8B12 ; 0 = StartDeathSequence
1285 AC12 ; 1 = AdvanceDeathSequence
1287 DE12 ; 2 = CompleteDeathMode
1289 0000 ; 3 = reset game
;----------------------------------



;----------------------------------
; Called when gameMode == 1 (demo 
; mode) and deathMode == 0
StartDeathSequence:
128b DF        RST     ReturnIfNotMinorTimeout
128c 214D69    LD      HL,marioSpriteNum
128f 3EF0      LD      A,F0H       ; Set Mario sprite
1291 CB16      RL      (HL)        ;    to mario dieing
1293 1F        RRA                 ;    flipped horizontally
1294 77        LD      (HL),A      ;    if needed
1295 219D63    LD      HL,deathMode ; deathMode = 1
1298 34        INC     (HL)        ;    ''
1299 3E0D      LD      A,0DH       ; DeathSequenceCycles = 13
129b 329E63    LD      (DeathSequenceCycles),A   ;    ''
129e 3E08      LD      A,08H       ; minorTimer = 8
12a0 320960    LD      (minorTimer),A ;    ''
12a3 CDBD30    CALL    ClearSelectedSprites
12a6 3E03      LD      A,03H       ; (6088H) = 3
12a8 328860    LD      (6088H),A   ;    ''
12ab C9        RET     
;----------------------------------



;----------------------------------
; Changes the Mario sprite to the
; next sprite in the cycle and
; flips it correctly to make it
; appear to spin
AdvanceDeathSequence:
12ac DF        RST     ReturnIfNotMinorTimeout
12ad 3E08      LD      A,08H       ; minorTimer = 8
12af 320960    LD      (minorTimer),A ;    ''
12b2 219E63    LD      HL,DeathSequenceCycles ; --DeathSequenceCycles
12b5 35        DEC     (HL)        ;    ''
12b6 CACB12    JP      Z,FinishDeathSequence ; If DeathSequenceCycles == 0, finish sequence

12b9 214D69    LD      HL,marioSpriteNum ; Calculate next
12bc 7E        LD      A,(HL)      ;    sprite in
12bd 1F        RRA                 ;    death sequence
12be 3E02      LD      A,02H       ;    ''
12c0 1F        RRA                 ;    ''
12c1 47        LD      B,A         ;    ''
12c2 AE        XOR     (HL)        ;    ''
12c3 77        LD      (HL),A      ;    ''
12c4 2C        INC     L           ; Calculate vertical
12c5 78        LD      A,B         ;    flipping for
12c6 E680      AND     80H         ;    the sprite
12c8 AE        XOR     (HL)        ;    ''
12c9 77        LD      (HL),A      ;    ''
12ca C9        RET     

FinishDeathSequence:
12cb 214D69    LD      HL,marioSpriteNum ; marioSpriteNum =
12ce 3EF4      LD      A,F4H       ;    Mario dead sprite
12d0 CB16      RL      (HL)        ;    flipped horizontally
12d2 1F        RRA                 ;    if neccessary
12d3 77        LD      (HL),A      ;    ''
12d4 219D63    LD      HL,deathMode ; deathMode = 2
12d7 34        INC     (HL)        ;    ''
12d8 3E80      LD      A,80H       ; minorTimer = 128
12da 320960    LD      (minorTimer),A ;    ''
12dd C9        RET   
;----------------------------------



;----------------------------------
; Finish death sequence by clearing
; out Mario (and 6 other) sprites
CompleteDeathMode:
12de DF        RST     ReturnIfNotMinorTimeout
12df CDDB30    CALL    ClearMarioAndOtherSprites
12e2 210A60    LD      HL,currentScreen ; HL = address of currentScreen
12e5 3A0E60    LD      A,(player2Active) ; If player 2 playing
12e8 A7        AND     A           ;    currentScreen += 2
12e9 CAED12    JP      Z,12EDH     ;    else currentScreen += 1
12ec 34        INC     (HL)        ;    ''
12ed 34        INC     (HL)        ;    ''
12ee 2B        DEC     HL          ; minorTimer = 1
12ef 3601      LD      (HL),01H    ;    ''
12f1 C9        RET     
;----------------------------------



;----------------------------------
; End player 1's turn.  Subtract a
; life.  If the player has no more
; lives left, the function handles
; end of game processing.
EndTurnPlayer1:
12f2 CD1C01    CALL    TurnOffSounds
12f5 AF        XOR     A           ; Clear the introDisplayed flag
12f6 322C62    LD      (introDisplayed),A ;    ''
12f9 212862    LD      HL,numLives ; Subtract a life
12fc 35        DEC     (HL)        ;    ''
12fd 7E        LD      A,(HL)      ; A = number of lives
12fe 114060    LD      DE,numLivesP1 ; Copy current player
1301 010800    LD      BC,0008H    ;    data to player 1
1304 EDB0      LDIR                ;    variables
1306 A7        AND     A           ; If player 1 has lives
1307 C23413    JP      NZ,Label1334 ;    left, jump ahead

130a 3E01      LD      A,01H       ; Player ID for player 1 
130c 21B260    LD      HL,player1Score ; Address of player 1 score
130f CDCA13    CALL    AddScoreToHighScoreTable
1312 21D476    LD      HL,76D4H    ; HL = (22, 20)
1315 3A0F60    LD      A,(twoPlayers) ; If only one player
1318 A7        AND     A          ;    is playing,
1319 2807      JR      Z,Label1322 ;    jump ahead

131b 110203    LD      DE,0302H   ; Display "PLAYER (I)"
131e CD9F30    CALL    AddFunctionToUpdateList ;    ''
1321 2B        DEC     HL         ; HL = (22, 19)

Label1322:
1322 CD2618    CALL    Clear14x5BlockOfScreen ; Clear 14x5 block at HL
1325 110003    LD      DE,0300H   ; Display "GAME OVER"
1328 CD9F30    CALL    AddFunctionToUpdateList ;    ''
132b 210960    LD      HL,minorTimer ; minorTimer = 192
132e 36C0      LD      (HL),C0H   ;    ''
1330 23        INC     HL         ; currentScreen = 16
1331 3610      LD      (HL),10H   ;    ''
1333 C9        RET     

Label1334:
1334 0E08      LD      C,08H      ; If one player, C = 8
1336 3A0F60    LD      A,(twoPlayers) ; If only one player,
1339 A7        AND     A          ;    jump ahead
133a CA3F13    JP      Z,Label133F ;    ''

133d 0E17      LD      C,17H      ; If two players, C = 23

Label133F:
133f 79        LD      A,C        ; currentScreen = 8 or 23
1340 320A60    LD      (currentScreen),A ;    ''
1343 C9        RET     
;---------------------------------



;---------------------------------
; End player 1's turn.  Subtract a
; life.  If the player has no more
; lives left, the function handles
; end of game processing.
EndTurnPlayer2:
1344 CD1C01    CALL    TurnOffSounds
1347 AF        XOR     A          ; Clear introDisplayed flag
1348 322C62    LD      (introDisplayed),A ;    ''
134b 212862    LD      HL,numLives ; Remove 1 life 
134e 35        DEC     (HL)       ;    ''
134f 7E        LD      A,(HL)     ;    ''
1350 114860    LD      DE,numLivesP2 ; Copy current player
1353 010800    LD      BC,0008H   ;    data to player 2 
1356 EDB0      LDIR               ;    variables
1358 A7        AND     A          ; If player 2 has lives left,
1359 C27F13    JP      NZ,137FH   ;    jump ahead
135c 3E03      LD      A,03H      ; Player ID for player 2
135e 21B560    LD      HL,player2Score ; Address of Player 2 score
1361 CDCA13    CALL    AddScoreToHighScoreTable
1364 110303    LD      DE,0303H   ; Display "PLAYER (II)"
1367 CD9F30    CALL    AddFunctionToUpdateList
136a 110003    LD      DE,0300H   ; Display "GAME OVER"
136d CD9F30    CALL    AddFunctionToUpdateList
1370 21D376    LD      HL,76D3H   ; HL = (22, 20)
1373 CD2618    CALL    Clear14x5BlockOfScreen ; Clear 14x5 block at HL
1376 210960    LD      HL,minorTimer ; Set minorTimet
1379 36C0      LD      (HL),C0H   ;    to 192
137b 23        INC     HL         ; currentScreen = 17
137c 3611      LD      (HL),11H   ;    ''
137e C9        RET     

137f 0E17      LD      C,17H      ; If player 1 has lives 
1381 3A4060    LD      A,(numLivesP1) ;    left, currentScreen 
1384 A7        AND     A          ;    = 23,
1385 C28A13    JP      NZ,Label138A ; else
1388 0E08      LD      C,08H      ;    currentScreen = 8
Label138A:
138a 79        LD      A,C        ;    ''
138b 320A60    LD      (currentScreen),A ;    ''
138e C9        RET     
;---------------------------------



;---------------------------------
; If player 2 has lives left, 
; begin next turn.  Otherwise, 
; trigger end game processing.
StartPlayer2OrEnd:
138f DF        RST     ReturnIfNotMinorTimeout
1390 0E17      LD      C,17H       
1392 3A4860    LD      A,(numLivesP2) 
Label1395:
1395 34        INC     (HL)       ; minorTimer = 1
1396 A7        AND     A          
1397 C29C13    JP      NZ,Label139C 
139a 0E14      LD      C,14H      
Label139C:
139c 79        LD      A,C        
139d 320A60    LD      (currentScreen),A 
13a0 C9        RET     
;---------------------------------



;---------------------------------
; If player 1 has lives left, 
; begin next turn.  Otherwise, 
; trigger end game processing.
StartPlayer1OrEnd:
13a1 DF        RST     ReturnIfNotMinorTimeout
13a2 0E17      LD      C,17H
13a4 3A4060    LD      A,(numLivesP1)
13a7 C39513    JP      Label1395
;---------------------------------



;---------------------------------
; Prepare to start player 2's turn
ActivatePlayer2:
13aa 3A2660    LD      A,(cabType) ; Orient the screen based on cab type
13ad 32827D    LD      (flipScreen),A ;    ''
13b0 AF        XOR     A           ; currentScreen = 0 (orient the screen)
13b1 320A60    LD      (currentScreen),A ;    ''
13b4 210101    LD      HL,0101H    ; Set player 2 active
13b7 220D60    LD      (playerUp),HL ;    (playerUp = player 2, player2Active = true)
13ba C9        RET     
;---------------------------------



;---------------------------------
; Prepare to start player 1's turn
ActivatePlayer1:
13bb AF        XOR     A           ; A = 0
13bc 320D60    LD      (playerUp),A ; playerUp = 0 (player 1)
13bf 320E60    LD      (player2Active),A ; player2Active = 0
13c2 320A60    LD      (currentScreen),A ; currentScreen = 0
13c5 3C        INC     A           ; A = 1
13c6 32827D    LD      (flipScreen),A ; Orient display right-side up
13c9 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Checks if the current player's
; score needs to be added to the
; high score table.
; Inserts scores into the table 
; and readjusts the table.
; Passed: HL - address of current 
;            player's score
;         A - player ID 
;           (1 for player 1, 
;            3 for player 2)
AddScoreToHighScoreTable:
13ca 11C661    LD      DE,tempScorePlayerId ; tempScorePlayerId = A
13cd 12        LD      (DE),A      ;    ''
13ce CF        ReturnIfDemoMode    ; Return if demoMode == 1
13cf 13        INC     DE          ; Copy the current player
13d0 010300    LD      BC,0003H    ;    score to temporary
13d3 EDB0      LDIR                ;    score
; Create the tempScoreString from tempScore
13d5 0603      LD      B,03H       
13d7 21B161    LD      HL,tempScoreString 
Label13DA:
13da 1B        DEC     DE          
13db 1A        LD      A,(DE)      
13dc 0F        RRCA                
13dd 0F        RRCA                
13de 0F        RRCA                
13df 0F        RRCA                
13e0 E60F      AND     0FH         
13e2 77        LD      (HL),A      
13e3 23        INC     HL          
13e4 1A        LD      A,(DE)      
13e5 E60F      AND     0FH         
13e7 77        LD      (HL),A      
13e8 23        INC     HL          
13e9 10EF      DJNZ    Label13DA       
13eb 060E      LD      B,0EH  
Label13ED:     
13ed 3610      LD      (HL),10H    
13ef 23        INC     HL          
13f0 10FB      DJNZ    Label13ED       
13f2 363F      LD      (HL),3FH    ; Terminate the string

; Return if this score does not need to be 
; placed on the high score list
; Otherwise, HL points to the end of the
; high score to replace (highScoreX + 2) and
; DE points to the end of the current 
; score
13f4 0605      LD      B,05H
13f6 21A561    LD      HL,highScore5
13f9 11C761    LD      DE,tempScore
Label13FC:
13fc 1A        LD      A,(DE)
13fd 96        SUB     (HL)
13fe 23        INC     HL
13ff 13        INC     DE
1400 1A        LD      A,(DE)
1401 9E        SBC     A,(HL)
1402 23        INC     HL
1403 13        INC     DE
1404 1A        LD      A,(DE)
1405 9E        SBC     A,(HL)
1406 D8        RET     C

; Insert the current score into the high 
; score table by swapping the current score
; and the existing high score, including
; the score strings and player markers
1407 C5        PUSH    BC
1408 0619      LD      B,19H
Label140A:
140a 4E        LD      C,(HL)
140b 1A        LD      A,(DE)
140c 77        LD      (HL),A
140d 79        LD      A,C
140e 12        LD      (DE),A
140f 2B        DEC     HL
1410 1B        DEC     DE
1411 10F7      DJNZ    Label140A

; Continue shifting the rest of the table
; down, allowing the last high score to
; drop off the table
1413 01F5FF    LD      BC,FFF5H    ; BC = -11
1416 09        ADD     HL,BC
1417 EB        EX      DE,HL
1418 09        ADD     HL,BC
1419 EB        EX      DE,HL
141a C1        POP     BC
141b 10DF      DJNZ    Label13FC
141d C9        RET     
;----------------------------------



;----------------------------------
; Run post game processing.
; Check if either player has a high
; score and display the high score
; entry screen
CheckForHighScores:
141e CD1606    CALL    DisplayNumCredits2
1421 DF        RST     ReturnIfNotMinorTimeout
1422 CD7408    CALL    ClearScreenAndSprites
1425 3E00      LD      A,00H       ; Mark player 2 inactive
1427 320E60    LD      (player2Active),A ;    ''
142a 320D60    LD      (playerUp),A ; Player 1 is playing
142d 211C61    LD      HL,highScore1PlayerId ; HL = address of highScore1PlayerId
1430 112200    LD      DE,0022H    ; DE = 34
1433 0605      LD      B,05H       ; For B = 5 to 1
1435 3E01      LD      A,01H       ; A = 1

; If player 1 has a high score, jump ahead
1437 BE        CP      (HL)        ; If (HL) == 1,
1438 CA5914    JP      Z,HighScorePlayer1 ;    jump ahead
143b 19        ADD     HL,DE       ; HL += 34
143c 10F9      DJNZ    1437H       ; Next B

143e 211C61    LD      HL,highScore1PlayerId ; HL = address of highScore1PlayerId
1441 0605      LD      B,05H       ; For B = 5 to 1
1443 3E03      LD      A,03H       ; A = 3

; If player 2 has a high score, jump ahead
1445 BE        CP      (HL)        ; If (HL) == 3,
1446 CA4F14    JP      Z,HighScorePlayer2 ;    jump ahead
1449 19        ADD     HL,DE       ; HL += 34
144a 10F9      DJNZ    1445H       ; Next B

144c C37514    JP      ResetDemoMode ; Start the demo mode

HighScorePlayer1:
144f 3E01      LD      A,01H       ; A = 1
1451 320E60    LD      (player2Active),A ; Set player 2 active
1454 320D60    LD      (playerUp),A
1457 3E00      LD      A,00H       ; A = 0 (player 2 selected)

HighScorePlayer1:
1459 212660    LD      HL,cabType  ; Orient screen for
145c B6        OR      (HL)        ;    selected player
145d 32827D    LD      (flipScreen),A ;    ''
1460 3E00      LD      A,00H       ; Reset minor timer
1462 320960    LD      (minorTimer),A ;   ''
1465 210A60    LD      HL,currentScreen ; currentScreen = 21
1468 34        INC     (HL)        ;    ''

; Display high score entry screen
1469 110D03    LD      DE,030DH
146c 060C      LD      B,0CH       
146e CD9F30    CALL    AddFunctionToUpdateList
1471 13        INC     DE
1472 10FA      DJNZ    146EH
1474 C9        RET     
;----------------------------------



;----------------------------------
; Resets the mode to the start of
; the demo mode
ResetDemoMode:
1475 3E01      LD      A,01H      ; A = 1
1477 32827D    LD      (flipScreen),A ; Orient screen right-side up
147a 320560    LD      (gameMode),A  ; gameMode = 1
147d 320760    LD      (demoMode),A  ; demoMode = 1
1480 3E00      LD      A,00H      ; A = 0
1482 320A60    LD      (currentScreen),A ; currentScreen = 0
1485 C9        RET                ; Done
;----------------------------------



;----------------------------------
; Allow the player to input his
; initials for earning one of the
; top 5 high scores
GetHighScoreInitials:
1486 CD1606    CALL    DisplayNumCredits2
1489 210960    LD      HL,minorTimer ; If minor timer > 0,
148c 7E        LD      A,(HL)      ;    jump ahead
148d A7        AND     A           ;    ''
148e C2DC14    JP      NZ,ID14DC ;    ''

1491 32867D    LD      (palette1),A ; Select palette 00
1494 32877D    LD      (palette2),A ;    ''
1497 3601      LD      (HL),01H    ; minorTimer = 1
1499 213060    LD      HL,6030H    ; (6030H) = 10
149c 360A      LD      (HL),0AH    ;    ''
149e 23        INC     HL          ; scoreBlinkCycleState = 0
149f 3600      LD      (HL),00H    ;    ''
14a1 23        INC     HL          ; scoreBlinkCycleTimer = 16
14a2 3610      LD      (HL),10H    ;    ''
14a4 23        INC     HL          ; regiTimer = 31
14a5 361E      LD      (HL),1EH    ;    ''
14a7 23        INC     HL          ; regiTimerDelay = 62
14a8 363E      LD      (HL),3EH    ;    ''
14aa 23        INC     HL          ; selectedLetter = 'A'
14ab 3600      LD      (HL),00H    ;    ''
14ad 21E875    LD      HL,75E8H    ; nextInitialCoord = (15, 8)
14b0 223660    LD      (nextInitialCoord),HL   ;    ''

; Set HL = to the address of the player ID
; for the current player's high score
; (highScore1PlayerId, highScore2PlayerId,
; highScore3PlayerId, highScore4PlayerId,
; or highScore5PlayerId)
14b3 211C61    LD      HL,highScore1PlayerId    
14b6 3A0E60    LD      A,(player2Active) ; C = 1 if player 1 active
14b9 07        RLCA                 ;    or 3 if player 2 active
14ba 3C        INC     A            ;    ''
14bb 4F        LD      C,A          ;    ''
14bc 112200    LD      DE,0022H     ; DE = 34
14bf 0604      LD      B,04H        ; For B = 4 to 1
14c1 7E        LD      A,(HL)       ; If the player ID matches 
14c2 B9        CP      C            ;    the current player,
14c3 CAC914    JP      Z,ID14C9     ;    exit the loop
14c6 19        ADD     HL,DE        ; HL = address of next player ID
14c7 10F8      DJNZ    14C1H        ; Next B

ID14C9:
14c9 223860    LD      (pHighScorePlayerId),HL ; pHighScorePlayerId = address of the correct player ID
14cc 11F3FF    LD      DE,FFF3H     ; pHighScoreInitialsPosition = address of the 
14cf 19        ADD     HL,DE        ;    position in the high score
14d0 223A60    LD      (pHighScoreInitialsPosition),HL ;    string for the player's initials
14d3 0600      LD      B,00H        ; BC = selectedLetter
14d5 3A3560    LD      A,(selectedLetter) ;    ''
14d8 4F        LD      C,A          ;    ''
14d9 CDFA15    CALL    DisplayLetterSelectBox

ID14DC:
14dc 213460    LD      HL,regiTimerDelay ; If --regiTimerDelay > 0
14df 35        DEC     (HL)        ;    jump ahead
14e0 C2FC14    JP      NZ,ProcessInitialInput ;    ''

14e3 363E      LD      (HL),3EH    ; Reset regiTimerDelay to 62
14e5 2B        DEC     HL          ; If regiTimer has reached 0,
14e6 35        DEC     (HL)        ;    complete the high score initial
14e7 CAC615    JP      Z,CompleteInitialEntry ;    entry

14ea 7E        LD      A,(HL)      ; A = regiTimer
14eb 06FF      LD      B,FFH       ; Prepare to count 10's (counting will start at 0)
ID14ED:
14ed 04        INC     B           ; Add 1 to count of 10's
14ee D60A      SUB     0AH         ; Subtract 10 from regi time  
14f0 D2ED14    JP      NC,ID14ED   ; If regi time >= 0, repeat

14f3 C60A      ADD     A,0AH       ; Add 10 back to regi time 
14f5 325275    LD      (7552H),A   ; Display 1's digit at (10, 18)
14f8 78        LD      A,B         ; Display 10's digit at (11, 18)
14f9 327275    LD      (7572H),A   ;    ''

ProcessInitialInput:
14fc 213060    LD      HL,6030H    ; B = (6030H)
14ff 46        LD      B,(HL)      ;    ''
1500 360A      LD      (HL),0AH    ; (6030H) = b1010

1502 3A1060    LD      A,(playerInput) ; A = player input
1505 CB7F      BIT     7,A         ; If jump was pressed,
1507 C24615    JP      NZ,LetterChosen ;    jump ahead
150a E603      AND     03H         ; If left or right was pressed,
150c C21415    JP      NZ,ChangeSelectedLetter ;    jump ahead
150f 3C        INC     A           ; (6030H) = input + 1
1510 77        LD      (HL),A      ;    ''
1511 C38A15    JP      BlinkScore ; jump ahead

ChangeSelectedLetter:
1514 05        DEC     B           ; If B == 1,
1515 CA1D15    JP      Z,ProcessLeft ;    jump ahead

1518 78        LD      A,B         ; (6030H) = B
1519 77        LD      (HL),A      ;    ''
151a C38A15    JP      BlinkScore

ProcessLeft:
151d CB4F      BIT     1,A         ; If left was pressed,
151f C23915    JP      NZ,MoveSelectionLeft ;    jump ahead

1522 3A3560    LD      A,(selectedLetter) ; A = next letter to the right
1525 3C        INC     A           ;    ''
1526 FE1E      CP      1EH         ; If A does not need to be wrapped,
1528 C22D15    JP      NZ,SelectLetter ;    jump ahead

152b 3E00      LD      A,00H       ; Wrap selected letter back to 'A'

SelectLetter:
152d 323560    LD      (selectedLetter),A ; save selectedLetter
1530 4F        LD      C,A         ; BC = selected letter
1531 0600      LD      B,00H       ;    ''
1533 CDFA15    CALL    DisplayLetterSelectBox
1536 C38A15    JP      BlinkScore

MoveSelectionLeft:
1539 3A3560    LD      A,(selectedLetter) ; A = next letter to the left
153c D601      SUB     01H         ;    ''
153e F22D15    JP      P,SelectLetter     ; If A does not need to be wrapped, select the letter

1541 3E1D      LD      A,1DH       ; Wrap selected letter to 'END'
1543 C32D15    JP      SelectLetter ; Select the letter

; Choose the selected letter and add it to
; the initials
LetterChosen:
1546 3A3560    LD      A,(selectedLetter) ; If 'RUB' was selected,
1549 FE1C      CP      1CH         ;    jump ahead
154b CA6D15    JP      Z,EraseInitialLetter ;    ''
154e FE1D      CP      1DH         ; If 'END' was selected,
1550 CAC615    JP      Z,CompleteInitialEntry ;    jump ahead
1553 2A3660    LD      HL,(nextInitialCoord) ; If no more initials 
1556 018875    LD      BC,7588H    ;    can be entered
1559 A7        AND     A           ;    jump ahead
155a ED42      SBC     HL,BC       ;    ''
155c CA8A15    JP      Z,BlinkScore ;    ''

155f 09        ADD     HL,BC       ; Restore the coord in HL
1560 C611      ADD     A,11H       ; Display the selected 
1562 77        LD      (HL),A      ;    initial letter
1563 01E0FF    LD      BC,FFE0H    ; Advance to the next initial
1566 09        ADD     HL,BC       ;    letter coordinate
ID1567:
1567 223660    LD      (nextInitialCoord),HL ;    ''
156a C38A15    JP      BlinkScore

EraseInitialLetter:
156d 2A3660    LD      HL,(nextInitialCoord) ; Move to the previous
1570 012000    LD      BC,0020H    ;    initial letter
1573 09        ADD     HL,BC       ;    coordinate
1574 A7        AND     A           ; If the coordinate
1575 010876    LD      BC,7608H    ;    is valid,
1578 ED42      SBC     HL,BC       ;    jump ahead
157a C28615    JP      NZ,EraseInitialLetter2 ;    ''

157d 21E875    LD      HL,75E8H    ; Reset the initial letter coord to (15, 8)

EraseInitialLetter:
1580 3E10      LD      A,10H       ; Blank the initial 
1582 77        LD      (HL),A      ;    letter
1583 C36715    JP      ID1567

EraseInitialLetter2:
1586 09        ADD     HL,BC       ; Restore the initial letter coord
1587 C38015    JP      EraseInitialLetter

BlinkScore:
158a 213260    LD      HL,scoreBlinkCycleTimer ; if blink cycle timer
158d 35        DEC     (HL)        ;    has not reached 0,
158e C2F915    JP      NZ,ID15F9   ;    return

1591 3A3160    LD      A,(scoreBlinkCycleState) ; If the score should be displayed,
1594 A7        AND     A           ;    jump ahead
1595 C2B815    JP      NZ,BlinkCycleOn ;    ''
1598 3E01      LD      A,01H       ; else
159a 323160    LD      (scoreBlinkCycleState),A ;    toggle blink cycle state
159d 11BF01    LD      DE,01BFH    ; DE = address of blank score

DisplayOrBlankTheScore:
15a0 FD2A3860  LD      IY,(pHighScorePlayerId) ; IX = address of variable
15a4 FD6E04    LD      L,(IY+04H)  ;    containing the coord 
15a7 FD6605    LD      H,(IY+05H)  ;    to display the score at
15aa E5        PUSH    HL          ;    ''
15ab DDE1      POP     IX          ;    ''
15ad CD7C05    CALL    DisplayScore ; Display or blank the score
15b0 3E10      LD      A,10H       ; Reset the blink cycle timer
15b2 323260    LD      (scoreBlinkCycleTimer),A ;    to 16
15b5 C3F915    JP      ID15F9      ; Return

BlinkCycleOn:
15b8 AF        XOR     A           ; Toggle scoreBlinkCycleState
15b9 323160    LD      (scoreBlinkCycleState),A ;    ''
15bc ED5B3860  LD      DE,(pHighScorePlayerId) ; DE = address of last
15c0 13        INC     DE          ;    byte of player's
15c1 13        INC     DE          ;    score
15c2 13        INC     DE          ;    ''
15c3 C3A015    JP      DisplayOrBlankTheScore

CompleteInitialEntry:
15c6 ED5B3860  LD      DE,(pHighScorePlayerId) ; Clear the high score
15ca AF        XOR     A           ;    player ID for this
15cb 12        LD      (DE),A      ;    score
15cc 210960    LD      HL,minorTimer ; minorTimer = 128
15cf 3680      LD      (HL),80H    ;    ''
15d1 23        INC     HL          ; currentScreen = 20
15d2 35        DEC     (HL)        ;    ''

; Copy the player's initials (plus nine blank
; spaces) from the screen to the high score
; string.
15d3 060C      LD      B,0CH       ; For B = 12 to 1
15d5 21E875    LD      HL,75E8H    ; HL = (15, 8)
15d8 FD2A3A60  LD      IY,(pHighScoreInitialsPosition) ; 
15dc 11E0FF    LD      DE,FFE0H    ; DE = -32
ID15DF:
15df 7E        LD      A,(HL)      ; Write character
15e0 FD7700    LD      (IY+00H),A  ;    to high score string
15e3 FD23      INC     IY          ;    ''
15e5 19        ADD     HL,DE       ; HL = next screen column
15e6 10F7      DJNZ    ID15DF      ; Next B

; Display top 5 high scores
15e8 0605      LD      B,05H       ; For B = 5 to 1
15ea 111403    LD      DE,0314H    ; Display High Score N
ID15ED:
15ed CD9F30    CALL    AddFunctionToUpdateList ;    ''
15f0 13        INC     DE          ; Next high score
15f1 10FA      DJNZ    ID15ED      ; Next B
15f3 111A03    LD      DE,031AH    ; Display "YOUR NAME WAS REGISTERED."
15f6 CD9F30    CALL    AddFunctionToUpdateList
ID15F9:
15f9 C9        RET   
;----------------------------------  



;----------------------------------  
; Display the selection box around
; the selected letter in the high
; score initial entry screen.
; passed: BC - selected letter num
;            (0 ('A') - 29 ('END')
DisplayLetterSelectBox:
15fa D5        PUSH    DE          ; Save DE and HL
15fb E5        PUSH    HL          ;    ''

15fc CB21      SLA     C           ; BC = offset of XY table entry for the selected letter
15fe 210F36    LD      HL,HighScoreLetterXYTable ; DE = Address of X coord for the selected letter
1601 09        ADD     HL,BC       ;    ''
1602 EB        EX      DE,HL       ;    ''
1603 217469    LD      HL,letterSelectBoxSpriteX ; HL = letterSelectBoxSpriteX
1606 1A        LD      A,(DE)      ; A = selection box X coord
1607 13        INC     DE          ; DE = address of Y coord for the selected letter
1608 77        LD      (HL),A      ; letterSelectBoxSpriteX = X coord from table
1609 23        INC     HL          ; letterSelectBoxSpriteNum = selection box sprite (72H) 
160a 3672      LD      (HL),72H    ;    ''
160c 23        INC     HL          ; letterSelectBoxSpritePalette = 12
160d 360C      LD      (HL),0CH    ;    ''
160f 23        INC     HL          ; letterSelectBoxSpriteY = Y coord from table
1610 1A        LD      A,(DE)      ;    ''
1611 77        LD      (HL),A      ;    ''
1612 E1        POP     HL          ; Restore HL and DE
1613 D1        POP     DE          ;    ''
1614 C9        RET     
;----------------------------------



;----------------------------------
; Display the end stage animation
; depending on the stage.
ImplementEndStage1:
1615 CDBD30    CALL    ClearSelectedSprites
1618 3A2762    LD      A,(currentStage) ; jump ahead unless stage == 
161b 0F        RRCA                ;    1 (barrels stage) or 
161c D22F16    JP      NC,ImplementEndStage2 ;    3 (elevators stage)
; The following code implements the end stage
; animation for the barrels stage and elevators
; stage (DK carries Pauline up the ladders)
161f 3A8863    LD      A,(EndStageAnimationPhase)
1622 EF        RST     JumpToLocalTableAddress
1623 5416 ; 0 = BeginDKClimbingAnimation0
1625 7016 ; 1 = BeginDKClimbingAnimation1
1627 8A16 ; 2 = BeginDKClimbingAnimation2
1629 3217 ; 3 = BeginDKClimbingAnimation3 ; DK climbs up and grabs Pauline
162b 5717 ; 4 = BeginDKClimbingAnimation4
162d 8E17 ; 5 = 178EH 

ImplementEndStage2:
162f 0F        RRCA                ; Jump ahead unless stage ==
1630 D24116    JP      NC,ImplementEndStage3 ;    2 (pies stage)
; The following code implements the end stage
; animation for the pies stage (DK travels
; along the conveyer belt before carrying
; Pauline up the ladders)
1633 3A8863    LD      A,(EndStageAnimationPhase)
1636 EF        RST     JumpToLocalTableAddress
1637 A316 ; 0 = 16A3H
1639 BB16 ; 1 = 16BBH
163B 3217 ; 2 = 1732H
163d 5717 ; 3 = 1757H
163f 8E17 ; 4 = 178EH

ImplementEndStage3:
1641 CDBD1D    CALL    ImplementPointAwards
1644 3A8863    LD      A,(EndStageAnimationPhase)
1647 EF        RST     JumpToLocalTableAddress
1648 B617 ; 0 = 17B6H
164a 6930 ; 1 = 3069H
164c 3918 ; 2 = 1839H 
164e 6F18 ; 3 = 186FH
1650 8018 ; 4 = 1880H
1652 C618 ; 5 = 18C6H
;----------------------------------



;----------------------------------
; EndStageAnimationPhase = 0
; Show DK with left arm raised and start
; a 32 tick counter.  DK is moved
4 pixels right on the barrels stage
BeginDKClimbingAnimation0:
1654 CD0817    CALL    BeginStandardEndStageAnimation
1657 215C38    LD      HL,DKLeftArmRaisedSpriteData
165a CD4E00    CALL    LoadDKSprites
165d 3E20      LD      A,20H       ; minorTimer = 32
165f 320960    LD      (minorTimer),A ;    ''
Label1662:
1662 218863    LD      HL,EndStageAnimationPhase ; ++EndStageAnimationPhase
1665 34        INC     (HL)        ;    ''
1666 3E01      LD      A,01H       ; Return unless barrels stage
1668 F7        RST     ReturnUnlessStageOfInterest
1669 210B69    LD      HL,dkSprite1Y ; Move DK 4 pixels up
166c 0EFC      LD      C,FCH       ;    ''
166e FF        RST     MoveDKSprites ;    ''
166f C9        RET     
;----------------------------------



;----------------------------------
; Show DK facing right and set a 32 tick
; timer.  On the rivets level, DK is
; moved 4 pixels left
; EndStageAnimationPhase = 1
BeginDKClimbingAnimation1:
1670 DF        RST     ReturnIfNotMinorTimeout
1671 213239    LD      HL,DKSpriteFacingRight1
1674 CD4E00    CALL    LoadDKSprites
1677 3E20      LD      A,20H		 ; minorTimer = 32
1679 320960    LD      (minorTimer),A
167c 218863    LD      HL,EndStageAnimationPhase
167f 34        INC     (HL)		  ; EndStageAnimationPhase = 2
1680 3E04      LD      A,04H		 ; Continue if rivets stage
1682 F7        RST     ReturnUnlessStageOfInterest
1683 210B69    LD      HL,dkSprite1Y ; Move DK 4 pixels left
1686 0E04      LD      C,04H
1688 FF        RST     MoveDKSprites
1689 C9        RET     
;----------------------------------



;----------------------------------
; Show DK climbing
; EndStageAnimationPhase = 2
BeginDKClimbingAnimation2:
168a DF        RST     ReturnIfNotMinorTimeout
168b 218C38    LD      HL,DKSpriteDataClimbing
168e CD4E00    CALL    LoadDKSprites
1691 3E66      LD      A,66H
1693 320C69    LD      (dkSprite2X),A ; Set dkSprite2X to 102
1696 AF        XOR     A
1697 322469    LD      (6924H),A  ; Set (6924H) to 0
169a 322C69    LD      (692CH),A  ; Set (692CH) to 0
169d 32AF62    LD      (62AFH),A  ; Set (62AFH) to 0
16a0 C36216    JP      1662H      ; Move DK up the ladder and advance EndStageAnimationPhase
;----------------------------------



;----------------------------------
16a3 CD0817    CALL    BeginStandardEndStageAnimation
16a6 3A1069    LD      A,(dkSprite3X)
16a9 D63B      SUB     3BH
16ab 215C38    LD      HL,DKLeftArmRaisedSpriteData
16ae CD4E00    CALL    LoadDKSprites
16b1 210869    LD      HL,dkSprite1X
16b4 4F        LD      C,A
16b5 FF        RST     MoveDKSprites
16b6 218863    LD      HL,EndStageAnimationPhase
16b9 34        INC     (HL)
16ba C9        RET     
;----------------------------------



;----------------------------------
16bb AF        XOR     A
16bc 32A062    LD      (62A0H),A
16bf 3AA363    LD      A,(conveyer1Offset)
16c2 4F        LD      C,A
16c3 3A1069    LD      A,(dkSprite3X)
16c6 FE5A      CP      5AH
16c8 D2E116    JP      NC,16E1H
16cb CB79      BIT     7,C
16cd CAD516    JP      Z,16D5H
16d0 3E01      LD      A,01H
16d2 32A062    LD      (62A0H),A
16d5 CD0226    CALL    2602H
16d8 3AA363    LD      A,(conveyer1Offset)
16db 4F        LD      C,A
16dc 210869    LD      HL,dkSprite1X
16df FF        RST     MoveDKSprites
16e0 C9        RET     

16e1 FE5D      CP      5DH
16e3 DAEE16    JP      C,16EEH
16e6 CB79      BIT     7,C
16e8 CAD016    JP      Z,16D0H
16eb C3D516    JP      16D5H
16ee 218C38    LD      HL,DKSpriteDataClimbing
16f1 CD4E00    CALL    LoadDKSprites
16f4 3E66      LD      A,66H
16f6 320C69    LD      (dkSprite2X),A
16f9 AF        XOR     A
16fa 322469    LD      (6924H),A
16fd 322C69    LD      (692CH),A
1700 32AF62    LD      (62AFH),A
1703 218863    LD      HL,EndStageAnimationPhase
1706 34        INC     (HL)
1707 C9        RET     
;----------------------------------


;----------------------------------
; Begin the standard level win 
; animation.
BeginStandardEndStageAnimation:
1708 CD1C01    CALL    TurnOffSounds
170b 21206A    LD      HL,heartSpriteX ; heart sprite X coord = 128
170e 3680      LD      (HL),80H    ;    ''
1710 23        INC     HL          ; set heart sprite sprite number
1711 3676      LD      (HL),76H    ;    ''
1713 23        INC     HL          ; set heart sprite palette
1714 3609      LD      (HL),09H    ;    ''
1716 23        INC     HL          ; heart sprite Y coord = 32
1717 3620      LD      (HL),20H    ;    ''
1719 210569    LD      HL,paulineLowerSpriteNum ; Set Pauline's lower half
171c 3613      LD      (HL),13H    ;    to standing sprite (facing left)
171e 21C475    LD      HL,75C4H    ; Blank (14, 4) to (16, 4)
1721 112000    LD      DE,0020H    ;    ''
1724 3E10      LD      A,10H       ;    ''
1726 CD1405    CALL    DisplayHelpTiles ;    ''
1729 218A60    LD      HL,currentSong ; Play standard level end song
172c 3607      LD      (HL),07H    ;    ''
172e 23        INC     HL          ;    ''
172f 3603      LD      (HL),03H    ;    ''
1731 C9        RET     
;----------------------------------



;----------------------------------
; Animate DK climbing up and grabbing
; Pauline
BeginDKClimbingAnimation3:
1732 CD6F30    CALL    AnimateDKClimbing ; Animate DK climbing
1735 3A1369    LD      A,(dkSprite3Y)
1738 FE2C      CP      2CH
173a D0        RET     NC         ; Return until DK reaches Pauline

173b AF        XOR     A          ; Erase Pauline
173c 320069    LD      (paulineUpperSpriteX),A
173f 320469    LD      (paulineLowerSpriteX),A
1742 320C69    LD      (dkSprite2X),A
1745 3E6B      LD      A,6BH
1747 322469    LD      (6924H),A
174a 3D        DEC     A
174b 322C69    LD      (692CH),A
174e 21216A    LD      HL,6A21H
1751 34        INC     (HL)
1752 218863    LD      HL,EndStageAnimationPhase ; ++EndStageAnimationPhase
1755 34        INC     (HL)
1756 C9        RET     
;----------------------------------



;----------------------------------
BeginDKClimbingAnimation4:
1757 CD6F30    CALL    AnimateDKClimbing
175a CD6C17    CALL    176CH
175d 23        INC     HL
175e 13        INC     DE
175f CD8317    CALL    1783H
1762 3E40      LD      A,40H
1764 320960    LD      (minorTimer),A
1767 218863    LD      HL,EndStageAnimationPhase
176a 34        INC     (HL)
176b C9        RET     
;----------------------------------



;----------------------------------
176c 110300    LD      DE,0003H
176f 212F69    LD      HL,692FH    ; Some sprite Y value?
1772 060A      LD      B,0AH       ; For B = 10 to 1
1774 A7        AND     A           ; Clear flags
1775 7E        LD      A,(HL)      ; A = (sprite Y value)
1776 ED52      SBC     HL,DE       ; HL -= 3
1778 FE19      CP      19H         ; If sprite Y > 25?
177a D27F17    JP      NC,177FH    ;    jump ahead
177d 3600      LD      (HL),00H    ; Else clear the sprite? (set sprite x to 0)
177f 2B        DEC     HL          ; HL = previous sprite y value
1780 10F2      DJNZ    1774H       ; Next B
1782 C9        RET     
;----------------------------------

1783 060A      LD      B,0AH
1785 7E        LD      A,(HL)
1786 A7        AND     A
1787 C22600    JP      NZ,0026H
178a 19        ADD     HL,DE
178b 10F8      DJNZ    1785H
178d C9        RET     

178e DF        RST     ReturnIfNotMinorTimeout
178f 2A2A62    LD      HL,(622AH)
1792 23        INC     HL
1793 7E        LD      A,(HL)
1794 FE7F      CP      7FH
1796 C29D17    JP      NZ,179DH
1799 21733A    LD      HL,3A73H
179c 7E        LD      A,(HL)
179d 222A62    LD      (622AH),HL
17a0 322762    LD      (currentStage),A
17a3 110005    LD      DE,0500H
17a6 CD9F30    CALL    AddFunctionToUpdateList
17a9 AF        XOR     A
17aa 328863    LD      (EndStageAnimationPhase),A
17ad 210960    LD      HL,minorTimer
17b0 3630      LD      (HL),30H
17b2 23        INC     HL
17b3 3608      LD      (HL),08H
17b5 C9        RET     

17b6 00        NOP     
17b7 CD1C01    CALL    TurnOffSounds
17ba 218A60    LD      HL,currentSong  ; Play love song (rivets stage complete)
17bd 360E      LD      (HL),0EH
17bf 23        INC     HL
17c0 3603      LD      (HL),03H
17c2 3E10      LD      A,10H           ; Clear "HELP!" tiles around Pauline
17c4 112000    LD      DE,0020H
17c7 212376    LD      HL,7623H        ; HL = (17, 3)
17ca CD1405    CALL    DisplayHelpTiles
17cd 218375    LD      HL,7583H        ; HL = (12, 3)
17d0 CD1405    CALL    DisplayHelpTiles
17d3 21DA76    LD      HL,76DAH        ; HL = (22, 26)
17d6 CD2618    CALL    Clear14x5BlockOfScreen ; Clear 1st unattached platform
17d9 11473A    LD      DE,3A47H        ; Draw stage data starting at 3A47H
17dc CDA70D    CALL    DisplayStage
17df 21D576    LD      HL,76D5H
17e2 CD2618    CALL    Clear14x5BlockOfScreen
17e5 114D3A    LD      DE,3A4DH
17e8 CDA70D    CALL    DisplayStage
17eb 21D076    LD      HL,76D0H
17ee CD2618    CALL    Clear14x5BlockOfScreen
17f1 11533A    LD      DE,3A53H
17f4 CDA70D    CALL    DisplayStage
17f7 21CB76    LD      HL,76CBH
17fa CD2618    CALL    Clear14x5BlockOfScreen
17fd 11593A    LD      DE,3A59H
1800 CDA70D    CALL    DisplayStage
1803 215C38    LD      HL,DKLeftArmRaisedSpriteData
1806 CD4E00    CALL    LoadDKSprites
1809 210869    LD      HL,dkSprite1X
180c 0E44      LD      C,44H
180e FF        RST     MoveDKSprites
180f 210569    LD      HL,paulineLowerSpriteNum
1812 3613      LD      (HL),13H
1814 3E20      LD      A,20H
1816 320960    LD      (minorTimer),A
1819 3E80      LD      A,80H
181b 329063    LD      (6390H),A
181e 218863    LD      HL,EndStageAnimationPhase
1821 34        INC     (HL)
1822 22C063    LD      (pCurrentMode),HL
1825 C9        RET     



;----------------------------------
; Clear a 14x5 screen area, with 
; upper left corner at the screen
; coordinate given in HL
; passed: Screen coord in HL
Clear14x5BlockOfScreen
1826 11DBFF    LD      DE,FFDBH    ; DE = (-37)
1829 0E0E      LD      C,0EH       ; For C = 1 to 14
182b 3E10      LD      A,10H       ; A = ' '
182d 0605      LD      B,05H       ; For B = 1 to 5
182f 77        LD      (HL),A      ; Write ' ' to screen coord
1830 23        INC     HL          ; Advance 1 row down
1831 10FC      DJNZ    182FH       ; Next B
1833 19        ADD     HL,DE       ; Advance 1 column right
1834 0D        DEC     C           ; Next C
1835 C22D18    JP      NZ,182DH    ;    ''
1838 C9        RET                 ; Done
;----------------------------------




;----------------------------------
1839 219063    LD      HL,6390H
183c 34        INC     (HL)
183d CA5918    JP      Z,1859H
1840 7E        LD      A,(HL)
1841 E607      AND     07H
1843 C0        RET     NZ

1844 11CF39    LD      DE,DKSpriteDataGrinLArmRLegUp
1847 CB5E      BIT     3,(HL)
1849 2003      JR      NZ,184EH
184b 11F739    LD      DE,DKSpriteDataGrinRArmLLegUp
184e EB        EX      DE,HL
184f CD4E00    CALL    LoadDKSprites
1852 210869    LD      HL,dkSprite1X
1855 0E44      LD      C,44H
1857 FF        RST     MoveDKSprites
1858 C9        RET     

1859 215C38    LD      HL,DKLeftArmRaisedSpriteData
185c CD4E00    CALL    LoadDKSprites
185f 210869    LD      HL,dkSprite1X
1862 0E44      LD      C,44H
1864 FF        RST     MoveDKSprites
1865 3E20      LD      A,20H
1867 320960    LD      (minorTimer),A
186a 218863    LD      HL,EndStageAnimationPhase
186d 34        INC     (HL)
186e C9        RET     

186f DF        RST     ReturnIfNotMinorTimeout
1870 211F3A    LD      HL,DKSpriteDataGrinUpsideDown
1873 CD4E00    CALL    LoadDKSprites
1876 3E03      LD      A,03H
1878 328460    LD      (6084H),A
187b 218863    LD      HL,EndStageAnimationPhase
187e 34        INC     (HL)
187f C9        RET     

1880 210B69    LD      HL,dkSprite1Y
1883 0E01      LD      C,01H
1885 FF        RST     MoveDKSprites
1886 3A1B69    LD      A,(691BH)
1889 FED0      CP      D0H
188b C0        RET     NZ

188c 3E20      LD      A,20H
188e 321969    LD      (dkHeadSprite),A
1891 21246A    LD      HL,6A24H
1894 367F      LD      (HL),7FH
1896 2C        INC     L
1897 3639      LD      (HL),39H
1899 2C        INC     L
189a 3601      LD      (HL),01H
189c 2C        INC     L
189d 36D8      LD      (HL),D8H
189f 21C676    LD      HL,76C6H
18a2 CD2618    CALL    Clear14x5BlockOfScreen
18a5 115F3A    LD      DE,3A5FH
18a8 CDA70D    CALL    DisplayStage
18ab 110400    LD      DE,0004H
18ae 012802    LD      BC,0228H
18b1 210369    LD      HL,paulineUpperSpriteY
18b4 CD3D00    CALL    003DH
18b7 3E00      LD      A,00H
18b9 32AF62    LD      (62AFH),A
18bc 3E03      LD      A,03H
18be 328260    LD      (soundEffect),A
18c1 218863    LD      HL,EndStageAnimationPhase
18c4 34        INC     (HL)
18c5 C9        RET     

18c6 21AF62    LD      HL,62AFH
18c9 35        DEC     (HL)
18ca CA3D19    JP      Z,193DH
18cd 7E        LD      A,(HL)
18ce E607      AND     07H
18d0 C0        RET     NZ

18d1 21256A    LD      HL,6A25H
18d4 7E        LD      A,(HL)
18d5 EE80      XOR     80H
18d7 77        LD      (HL),A
18d8 211969    LD      HL,dkHeadSprite
18db 46        LD      B,(HL)
18dc CBA8      RES     5,B
18de AF        XOR     A
18df CD0930    CALL    3009H
18e2 F620      OR      ContinueWhenTimerReaches0
18e4 77        LD      (HL),A
18e5 21AF62    LD      HL,62AFH
18e8 7E        LD      A,(HL)
18e9 FEE0      CP      E0H
18eb C21019    JP      NZ,1910H
18ee 3E50      LD      A,50H
18f0 324F69    LD      (marioSpriteY),A
18f3 3E00      LD      A,00H
18f5 324D69    LD      (marioSpriteNum),A
18f8 3E9F      LD      A,9FH
18fa 324C69    LD      (marioSpriteX),A
18fd 3A0362    LD      A,(marioX)
1900 FE80      CP      80H
1902 D20F19    JP      NC,190FH
1905 3E80      LD      A,80H
1907 324D69    LD      (marioSpriteNum),A
190a 3E5F      LD      A,5FH
190c 324C69    LD      (marioSpriteX),A
190f 7E        LD      A,(HL)
1910 FEC0      CP      C0H
1912 C0        RET     NZ

1913 218A60    LD      HL,currentSong
1916 360C      LD      (HL),0CH
1918 3A2962    LD      A,(levelNum)
191b 0F        RRCA    
191c 3802      JR      C,1920H
191e 3605      LD      (HL),05H
1920 23        INC     HL
1921 3603      LD      (HL),03H
1923 21236A    LD      HL,6A23H
1926 3640      LD      (HL),40H
1928 2B        DEC     HL
1929 3609      LD      (HL),09H
192b 2B        DEC     HL
192c 3676      LD      (HL),76H
192e 2B        DEC     HL
192f 368F      LD      (HL),8FH
1931 3A0362    LD      A,(marioX)
1934 FE80      CP      80H
1936 D0        RET     NC

1937 3E6F      LD      A,6FH
1939 32206A    LD      (heartSpriteX),A
193c C9        RET     

193d 2A2A62    LD      HL,(622AH)
1940 23        INC     HL
1941 7E        LD      A,(HL)
1942 FE7F      CP      7FH
1944 C24B19    JP      NZ,194BH
1947 21733A    LD      HL,3A73H
194a 7E        LD      A,(HL)
194b 222A62    LD      (622AH),HL
194e 322762    LD      (currentStage),A
1951 212962    LD      HL,levelNum
1954 34        INC     (HL)
1955 110005    LD      DE,0500H
1958 CD9F30    CALL    AddFunctionToUpdateList
195b AF        XOR     A
195c 322E62    LD      (levelHeightIndex),A
195f 328863    LD      (EndStageAnimationPhase),A
1962 210960    LD      HL,minorTimer
1965 36E0      LD      (HL),E0H
1967 23        INC     HL
1968 3608      LD      (HL),08H
196a C9        RET     
;----------------------------------



;----------------------------------
; Prepare for the next player's turn
ActivateNextPlayer:
196b CD5208    CALL    ClearRight4Cols ; Clear the screen
196e 3A0E60    LD      A,(player2Active) ; If player 1's turn,
1971 C612      ADD     A,12H        ;    currentScreen = 18
1973 320A60    LD      (currentScreen),A ; else
1976 C9        RET                 ;    currentScreen = 19
;----------------------------------



;----------------------------------
; Demonstrate the game by having 
; the computer run mario through
; the first stage.
RunDemoMode:
1977 CDEE21    CALL    SimulateDemoInput

ImplementGame:
197a CDBD1D    CALL    ImplementPointAwards
197d CD8C1E    CALL    ImplementSmashSequence ; If a smash sequence is active, then game processing stops here
1980 CDC31A    CALL    1AC3H
1983 CD721F    CALL    1F72H
1986 CD8F2C    CALL    2C8FH
1989 CD032C    CALL    2C03H
198c CDED30    CALL    30EDH
198f CD042E    CALL    2E04H
1992 CDEA24    CALL    24EAH
1995 CDDB2D    CALL    2DDBH
1998 CDD42E    CALL    2ED4H
199b CD0722    CALL    2207H
199e CD331A    CALL    1A33H
19a1 CD852A    CALL    2A85H
19a4 CD461F    CALL    1F46H
19a7 CDFA26    CALL    26FAH
19aa CDF225    CALL    25F2H
19ad CDDA19    CALL    PickupBonusPrizes
19b0 CDFB03    CALL    03FBH
19b3 CD0828    CALL    2808H
19b6 CD1D28    CALL    281DH
19b9 CD571E    CALL    CheckForWin
19bc CD071A    CALL    1A07H
19bf CDCB2F    CALL    2FCBH
19c2 00        NOP     
19c3 00        NOP     
19c4 00        NOP     
19c5 3A0062    LD      A,(marioAlive) ; Return if mario is still alive
19c8 A7        AND     A           ;    ''
19c9 C0        RET     NZ          ;    ''

19ca CD1C01    CALL    TurnOffSounds
19cd 218260    LD      HL,soundEffect ; Trigger DK stomp sound?
19d0 3603      LD      (HL),03H    ;    ''
19d2 210A60    LD      HL,currentScreen ; currentScreen = 4 (death sequence)
19d5 34        INC     (HL)        ;    ''
19d6 2B        DEC     HL          ; minorTimer = 64
19d7 3640      LD      (HL),40H    ;    ''
19d9 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Checks if Mario can pick up one
; of the bonus prizes (Pauline's
; hat, purse, or umbrella) and awards
; points as appropriate.
PickupBonusPrizes:
19da 3A0362    LD      A,(marioX)  ; A = marioX
19dd 0603      LD      B,03H       ; For B = 3 to 1
19df 210C6A    LD      HL,prizeSprite1X ; HL = prizeSprite1X
19e2 BE        CP      (HL)        ; If sprite X coord == marioX
19e3 CAED19    JP      Z,19EDH     ;    jump ahead
19e6 2C        INC     L           ; HL = next sprite X coord
19e7 2C        INC     L           ;    ''
19e8 2C        INC     L           ;    ''
19e9 2C        INC     L           ;    ''
19ea 10F6      DJNZ    19E2H       ; Next B
19ec C9        RET                 ; Done

19ed 3A0562    LD      A,(marioY)  ; A = marioY
19f0 2C        INC     L           ; HL = address of sprite Y coord
19f1 2C        INC     L           ;    ''
19f2 2C        INC     L           ;    ''
19f3 BE        CP      (HL)        ; If sprite Y coord != marioY
19f4 C0        RET     NZ          ;    return

19f5 2D        DEC     L           ; HL = address of sprite number
19f6 2D        DEC     L           ;    ''
19f7 CB5E      BIT     3,(HL)      ; If spriteNumber < (?)8
19f9 C0        RET     NZ          ;    return

19fa 2D        DEC     L           ; HL = address of sprite X coord
19fb 224363    LD      (pPointSpriteX),HL ; Replace this sprite with point sprite
19fe AF        XOR     A           ; Award points based on level number
19ff 324263    LD      (pointAwardType),A   ;    ''
1a02 3C        INC     A           ; Points are waiting to be awarded
1a03 324063    LD      (pointDisplayMode),A ;    ''
1a06 C9        RET     
;----------------------------------



;----------------------------------
; Jump based on (6386H)
1a07 3A8663    LD      A,(6386H)
1a0a EF        RST     JumpToLocalTableAddress
1a0b 1E1A ; 0 = 1A1EH
1a0d 151A ; 1 = 1A15H
1a0f 1F1A ; 2 = 1A1FH
1a11 2A1A ; 3 = 1A2AH
1a13 0000 ; 4 = reset game
;----------------------------------




;----------------------------------
1a15 AF        XOR     A
1a16 328763    LD      (6387H),A
1a19 3E02      LD      A,02H
1a1b 328663    LD      (6386H),A
1a1e C9        RET     

1a1f 218763    LD      HL,6387H
1a22 35        DEC     (HL)
1a23 C0        RET     NZ

1a24 3E03      LD      A,03H
1a26 328663    LD      (6386H),A
1a29 C9        RET     

1a2a 3A1662    LD      A,(6216H)
1a2d A7        AND     A
1a2e C0        RET     NZ

1a2f E1        POP     HL
1a30 C3D219    JP      19D2H
1a33 3E08      LD      A,08H
1a35 F7        RST     ReturnUnlessStageOfInterest
1a36 3A0362    LD      A,(marioX)
1a39 FE4B      CP      4BH
1a3b CA4B1A    JP      Z,1A4BH
1a3e FEB3      CP      B3H
1a40 CA4B1A    JP      Z,1A4BH
1a43 3A9162    LD      A,(6291H)
1a46 3D        DEC     A
1a47 CA511A    JP      Z,1A51H
1a4a C9        RET     

1a4b 3E01      LD      A,01H
1a4d 329162    LD      (6291H),A
1a50 C9        RET     

1a51 329162    LD      (6291H),A
1a54 47        LD      B,A
1a55 3A0562    LD      A,(marioY)
1a58 3D        DEC     A
1a59 FED0      CP      D0H
1a5b D0        RET     NC

1a5c 07        RLCA    
1a5d D2621A    JP      NC,1A62H
1a60 CBD0      SET     2,B
1a62 07        RLCA    
1a63 07        RLCA    
1a64 D2691A    JP      NC,1A69H
1a67 CBC8      SET     1,B
1a69 E607      AND     07H
1a6b FE06      CP      06H
1a6d C2721A    JP      NZ,1A72H
1a70 CBC8      SET     1,B
1a72 3A0362    LD      A,(marioX)
1a75 07        RLCA    
1a76 D27B1A    JP      NC,1A7BH
1a79 CBC0      SET     0,B
1a7b 219262    LD      HL,6292H
1a7e 78        LD      A,B
1a7f 85        ADD     A,L
1a80 6F        LD      L,A
1a81 7E        LD      A,(HL)
1a82 A7        AND     A
1a83 C8        RET     Z

1a84 3600      LD      (HL),00H
1a86 219062    LD      HL,rivetsRemaining
1a89 35        DEC     (HL)
1a8a 78        LD      A,B
1a8b 010500    LD      BC,0005H
1a8e 1F        RRA     
1a8f DABD1A    JP      C,1ABDH
1a92 21CB02    LD      HL,02CBH
1a95 A7        AND     A
1a96 CA9E1A    JP      Z,1A9EH
1a99 09        ADD     HL,BC
1a9a 3D        DEC     A
1a9b C2991A    JP      NZ,1A99H
1a9e 010074    LD      BC,7400H
1aa1 09        ADD     HL,BC
1aa2 3E10      LD      A,10H
1aa4 77        LD      (HL),A
1aa5 2D        DEC     L
1aa6 77        LD      (HL),A
1aa7 2C        INC     L
1aa8 2C        INC     L
1aa9 77        LD      (HL),A
1aaa 3E01      LD      A,01H       ; Points waiting to be awarded
1aac 324063    LD      (pointDisplayMode),A ;    ''
1aaf 324263    LD      (pointAwardType),A   ; Award 100 points
1ab2 322562    LD      (6225H),A   ; (6225H) = 1
1ab5 3A1662    LD      A,(6216H)
1ab8 A7        AND     A
1ab9 CC951D    CALL    Z,1D95H
1abc C9        RET     
;----------------------------------



;----------------------------------
1abd 212B01    LD      HL,012BH
1ac0 C3951A    JP      1A95H
;----------------------------------



;----------------------------------
1ac3 3A1662    LD      A,(6216H)   ; If (6216H) == 1
1ac6 3D        DEC     A           ;    jump ahead
1ac7 CAB21B    JP      Z,1BB2H     ;    ''
1aca 3A1E62    LD      A,(621EH)   ; Else if (621EH) == 1
1acd A7        AND     A           ;    jump ahead
1ace C2551B    JP      NZ,1B55H    ;    ''
1ad1 3A1762    LD      A,(6217H)   ; Else if (6217H) == 1
1ad4 3D        DEC     A           ;    jump ahead
1ad5 CAE61A    JP      Z,1AE6H     ;    ''
1ad8 3A1562    LD      A,(climbing); Else if mario is climbing
1adb 3D        DEC     A           ;    jump ahead
1adc CA381B    JP      Z,1B38H     ;    ''

1adf 3A1060    LD      A,(playerInput) ; If player is pushing JUMP
1ae2 17        RLA                 ;    jump ahead
1ae3 DA6E1B    JP      C,1B6EH     ;    ''

1ae6 CD1F24    CALL    CheckForBarriers ; D = blocked left, E = blocked right
1ae9 3A1060    LD      A,(playerInput)  ; A = playerInput
1aec 1D        DEC     E                ; If can't move right
1aed CAF51A    JP      Z,CheckForLeftInput ;    skip checking for RIGHT input

1af0 CB47      BIT     0,A              ; If RIGHT input
1af2 C28F1C    JP      NZ,1C8FH         ;    handle it

CheckForLeftInput:
1af5 15        DEC     D                ; If can't move left
1af6 CAFE1A    JP      Z,1AFEH          ;    skip checking for LEFT input

1af9 CB4F      BIT     1,A              ; If LEFT input
1afb C2AB1C    JP      NZ,1CABH         ;    handle it

1afe 3A1762    LD      A,(6217H)
1b01 3D        DEC     A
1b02 C8        RET     Z

1b03 3A0562    LD      A,(marioY)
1b06 C608      ADD     A,08H
1b08 57        LD      D,A
1b09 3A0362    LD      A,(marioX)
1b0c F603      OR      03H
1b0e CB97      RES     2,A
1b10 011500    LD      BC,0015H
1b13 CD6E23    CALL    236EH
1b16 F5        PUSH    AF
1b17 210762    LD      HL,marioSpriteNum1
1b1a 7E        LD      A,(HL)
1b1b E680      AND     80H
1b1d F606      OR      06H
1b1f 77        LD      (HL),A
1b20 211A62    LD      HL,621AH
1b23 3E04      LD      A,04H
1b25 B9        CP      C
1b26 3601      LD      (HL),01H
1b28 D22C1B    JP      NC,1B2CH
1b2b 35        DEC     (HL)
1b2c F1        POP     AF
1b2d A7        AND     A
1b2e CA4E1B    JP      Z,1B4EH
1b31 7E        LD      A,(HL)
1b32 A7        AND     A
1b33 C0        RET     NZ

1b34 2C        INC     L
1b35 72        LD      (HL),D
1b36 2C        INC     L
1b37 70        LD      (HL),B
1b38 3A1060    LD      A,(playerInput)
1b3b CB5F      BIT     3,A        ; Down 
1b3d C2F21C    JP      NZ,1CF2H
1b40 3A1562    LD      A,(climbing)
1b43 A7        AND     A
1b44 C8        RET     Z

1b45 3A1060    LD      A,(playerInput)
1b48 CB57      BIT     2,A        ; Up
1b4a C2031D    JP      NZ,1D03H
1b4d C9        RET     

1b4e 2C        INC     L
1b4f 70        LD      (HL),B
1b50 2C        INC     L
1b51 72        LD      (HL),D
1b52 C3451B    JP      1B45H
1b55 211E62    LD      HL,621EH
1b58 35        DEC     (HL)
1b59 C0        RET     NZ

1b5a 3A1862    LD      A,(6218H)
1b5d 321762    LD      (6217H),A
1b60 210762    LD      HL,marioSpriteNum1
1b63 7E        LD      A,(HL)
1b64 E680      AND     80H
1b66 77        LD      (HL),A
1b67 AF        XOR     A
1b68 320262    LD      (6202H),A
1b6b C3A61D    JP      1DA6H
1b6e 3E01      LD      A,01H
1b70 321662    LD      (6216H),A
1b73 211062    LD      HL,6210H
1b76 3A1060    LD      A,(playerInput)
1b79 018000    LD      BC,0080H
1b7c 1F        RRA     
1b7d DA8A1B    JP      C,1B8AH
1b80 0180FF    LD      BC,FF80H
1b83 1F        RRA     
1b84 DA8A1B    JP      C,1B8AH
1b87 010000    LD      BC,0000H
1b8a AF        XOR     A
1b8b 70        LD      (HL),B
1b8c 2C        INC     L
1b8d 71        LD      (HL),C
1b8e 2C        INC     L
1b8f 3601      LD      (HL),01H
1b91 2C        INC     L
1b92 3648      LD      (HL),48H
1b94 2C        INC     L
1b95 77        LD      (HL),A
1b96 320462    LD      (6204H),A
1b99 320662    LD      (6206H),A
1b9c 3A0762    LD      A,(marioSpriteNum1)
1b9f E680      AND     80H
1ba1 F60E      OR      0EH
1ba3 320762    LD      (marioSpriteNum1),A
1ba6 3A0562    LD      A,(marioY)
1ba9 320E62    LD      (620EH),A
1bac 218160    LD      HL,6081H
1baf 3603      LD      (HL),03H
1bb1 C9        RET     

1bb2 DD210062  LD      IX,marioAlive
1bb6 3A0362    LD      A,(marioX)
1bb9 DD770B    LD      (IX+0BH),A
1bbc 3A0562    LD      A,(marioY)
1bbf DD770C    LD      (IX+0CH),A
1bc2 CD9C23    CALL    239CH
1bc5 CD1F24    CALL    CheckForBarriers
1bc8 15        DEC     D
1bc9 C2F21B    JP      NZ,1BF2H
1bcc DD361000  LD      (IX+10H),00H
1bd0 DD361180  LD      (IX+11H),80H
1bd4 DDCB07FE  SET     7,(IX+07H)
1bd8 3A2062    LD      A,(6220H)
1bdb 3D        DEC     A
1bdc CAEC1B    JP      Z,1BECH
1bdf CD0724    CALL    2407H
1be2 DD7412    LD      (IX+12H),H
1be5 DD7513    LD      (IX+13H),L
1be8 DD361400  LD      (IX+14H),00H
1bec CD9C23    CALL    239CH
1bef C3051C    JP      1C05H
1bf2 1D        DEC     E
1bf3 C2051C    JP      NZ,1C05H
1bf6 DD3610FF  LD      (IX+10H),FFH
1bfa DD361180  LD      (IX+11H),80H
1bfe DDCB07BE  RES     7,(IX+07H)
1c02 C3D81B    JP      1BD8H
1c05 CD1C2B    CALL    2B1CH
1c08 3D        DEC     A
1c09 CA3A1C    JP      Z,1C3AH
1c0c 3A1F62    LD      A,(621FH)
1c0f 3D        DEC     A
1c10 CA761C    JP      Z,1C76H
1c13 3A1462    LD      A,(6214H)
1c16 D614      SUB     14H
1c18 C2331C    JP      NZ,1C33H
1c1b 3E01      LD      A,01H
1c1d 321F62    LD      (621FH),A
1c20 CD5328    CALL    2853H
1c23 A7        AND     A
1c24 CAA61D    JP      Z,1DA6H
1c27 324263    LD      (pointAwardType),A
1c2a 3E01      LD      A,01H       ; Points waiting to be awarded
1c2c 324063    LD      (pointDisplayMode),A ;   ''
1c2f 322562    LD      (6225H),A   ; (6225H) = 1
1c32 00        NOP     
1c33 3C        INC     A
1c34 CC5429    CALL    Z,2954H
1c37 C3A61D    JP      1DA6H
1c3a 05        DEC     B
1c3b CA4F1C    JP      Z,1C4FH
1c3e 3C        INC     A
1c3f 321F62    LD      (621FH),A
1c42 AF        XOR     A
1c43 211062    LD      HL,6210H
1c46 0605      LD      B,05H
1c48 77        LD      (HL),A
1c49 2C        INC     L
1c4a 10FC      DJNZ    1C48H
1c4c C3A61D    JP      1DA6H
1c4f 321662    LD      (6216H),A
1c52 3A2062    LD      A,(6220H)
1c55 EE01      XOR     01H
1c57 320062    LD      (marioAlive),A
1c5a 210762    LD      HL,marioSpriteNum1
1c5d 7E        LD      A,(HL)
1c5e E680      AND     80H
1c60 F60F      OR      0FH
1c62 77        LD      (HL),A
1c63 3E04      LD      A,04H
1c65 321E62    LD      (621EH),A
1c68 AF        XOR     A
1c69 321F62    LD      (621FH),A
1c6c 3A2562    LD      A,(6225H)
1c6f 3D        DEC     A
1c70 CC951D    CALL    Z,1D95H
1c73 C3A61D    JP      1DA6H
1c76 3A0562    LD      A,(marioY)
1c79 210E62    LD      HL,620EH
1c7c D60F      SUB     0FH
1c7e BE        CP      (HL)
1c7f DAA61D    JP      C,1DA6H
1c82 3E01      LD      A,01H
1c84 322062    LD      (6220H),A
1c87 218460    LD      HL,6084H
1c8a 3603      LD      (HL),03H
1c8c C3A61D    JP      1DA6H


;----------------------------------
; Called to handle right input
1c8f 0601      LD      B,01H       ; B = 1
1c91 3A0F62    LD      A,(620FH)   ; If (620FH) == 1
1c94 A7        AND     A           ;    jump ahead
1c95 C2D21C    JP      NZ,1CD2H    ;    ''

1c98 3A0262    LD      A,(6202H)   ; B = (6202H)
1c9b 47        LD      B,A         ;    ''
1c9c 3E05      LD      A,05H       ; A = 5
1c9e CD0930    CALL    3009H
1ca1 320262    LD      (6202H),A
1ca4 E603      AND     03H
1ca6 F680      OR      80H
1ca8 C3C21C    JP      1CC2H
1cab 06FF      LD      B,FFH
1cad 3A0F62    LD      A,(620FH)
1cb0 A7        AND     A
1cb1 C2D21C    JP      NZ,1CD2H
1cb4 3A0262    LD      A,(6202H)
1cb7 47        LD      B,A
1cb8 3E01      LD      A,01H
1cba CD0930    CALL    3009H
1cbd 320262    LD      (6202H),A
1cc0 E603      AND     03H
1cc2 210762    LD      HL,marioSpriteNum1
1cc5 77        LD      (HL),A
1cc6 1F        RRA     
1cc7 DC8F1D    CALL    C,1D8FH
1cca 3E02      LD      A,02H
1ccc 320F62    LD      (620FH),A
1ccf C3A61D    JP      1DA6H
1cd2 210362    LD      HL,marioX
1cd5 7E        LD      A,(HL)
1cd6 80        ADD     A,B
1cd7 77        LD      (HL),A
1cd8 3A2762    LD      A,(currentStage)
1cdb 3D        DEC     A
1cdc C2EB1C    JP      NZ,1CEBH
1cdf 66        LD      H,(HL)
1ce0 3A0562    LD      A,(marioY)
1ce3 6F        LD      L,A
1ce4 CD3323    CALL    2333H
1ce7 7D        LD      A,L
1ce8 320562    LD      (marioY),A
1ceb 210F62    LD      HL,620FH
1cee 35        DEC     (HL)
1cef C3A61D    JP      1DA6H
1cf2 3A0F62    LD      A,(620FH)
1cf5 A7        AND     A
1cf6 C28A1D    JP      NZ,1D8AH
1cf9 3E03      LD      A,03H
1cfb 320F62    LD      (620FH),A
1cfe 3E02      LD      A,02H
1d00 C3111D    JP      1D11H
1d03 3A0F62    LD      A,(620FH)
1d06 A7        AND     A
1d07 C2761D    JP      NZ,1D76H
1d0a 3E04      LD      A,04H
1d0c 320F62    LD      (620FH),A
1d0f 3EFE      LD      A,FEH
1d11 210562    LD      HL,marioY
1d14 86        ADD     A,(HL)
1d15 77        LD      (HL),A
1d16 47        LD      B,A
1d17 3A2262    LD      A,(6222H)
1d1a EE01      XOR     01H
1d1c 322262    LD      (6222H),A
1d1f C2511D    JP      NZ,1D51H
1d22 78        LD      A,B
1d23 C608      ADD     A,08H
1d25 211C62    LD      HL,621CH
1d28 BE        CP      (HL)
1d29 CA671D    JP      Z,1D67H
1d2c 2D        DEC     L
1d2d 96        SUB     (HL)
1d2e CA671D    JP      Z,1D67H
1d31 0605      LD      B,05H
1d33 D608      SUB     08H
1d35 CA3F1D    JP      Z,1D3FH
1d38 05        DEC     B
1d39 D604      SUB     04H
1d3b CA3F1D    JP      Z,1D3FH
1d3e 05        DEC     B
1d3f 3E80      LD      A,80H
1d41 210762    LD      HL,marioSpriteNum1
1d44 A6        AND     (HL)
1d45 EE80      XOR     80H
1d47 B0        OR      B
1d48 77        LD      (HL),A
1d49 3E01      LD      A,01H
1d4b 321562    LD      (climbing),A
1d4e C3A61D    JP      1DA6H
1d51 2D        DEC     L
1d52 2D        DEC     L
1d53 7E        LD      A,(HL)
1d54 F603      OR      03H
1d56 CB97      RES     2,A
1d58 77        LD      (HL),A
1d59 3A2462    LD      A,(6224H)
1d5c EE01      XOR     01H
1d5e 322462    LD      (6224H),A
1d61 CC8F1D    CALL    Z,1D8FH
1d64 C3491D    JP      1D49H
1d67 3E06      LD      A,06H
1d69 320762    LD      (marioSpriteNum1),A
1d6c AF        XOR     A
1d6d 321962    LD      (6219H),A
1d70 321562    LD      (climbing),A
1d73 C3A61D    JP      1DA6H
1d76 3A1A62    LD      A,(621AH)
1d79 A7        AND     A
1d7a CA8A1D    JP      Z,1D8AH
1d7d 321962    LD      (6219H),A
1d80 3A1C62    LD      A,(621CH)
1d83 D613      SUB     13H
1d85 210562    LD      HL,marioY
1d88 BE        CP      (HL)
1d89 D0        RET     NC

1d8a 210F62    LD      HL,620FH
1d8d 35        DEC     (HL)
1d8e C9        RET     

1d8f 3E03      LD      A,03H
1d91 328060    LD      (6080H),A
1d94 C9        RET     

1d95 322562    LD      (6225H),A
1d98 3A2762    LD      A,(currentStage)
1d9b 3D        DEC     A
1d9c C8        RET     Z

1d9d 218A60    LD      HL,currentSong
1da0 360D      LD      (HL),0DH
1da2 2C        INC     L
1da3 3603      LD      (HL),03H
1da5 C9        RET     

1da6 214C69    LD      HL,marioSpriteX
1da9 3A0362    LD      A,(marioX)
1dac 77        LD      (HL),A
1dad 3A0762    LD      A,(marioSpriteNum1)
1db0 2C        INC     L
1db1 77        LD      (HL),A
1db2 3A0862    LD      A,(marioSpritePalette1)
1db5 2C        INC     L
1db6 77        LD      (HL),A
1db7 3A0562    LD      A,(marioY)
1dba 2C        INC     L
1dbb 77        LD      (HL),A
1dbc C9        RET     
;---------------------------------



;---------------------------------
; Implements point awarding and
; display
ImplementPointAwards:
1dbd 3A4063    LD      A,(pointDisplayMode)  ; A = (pointDisplayMode)
1dc0 EF        RST     JumpToLocalTableAddress
1dc1 491E ; 0 = NoPointsToAward
1de3 C91D ; 1 = AwardPoints
1dc5 4A1E ; 2 = DisplayPointsUntilTimeout
1de7 0000 ; 3 = Reset game
;---------------------------------



;---------------------------------
; Award and display point bonuses
AwardPoints:
1dc9 3E40      LD      A,40H      ; pointSpriteTimeout = 64
1dcb 324163    LD      (pointSpriteTimeout),A  ;    ''
1dce 3E02      LD      A,02H      ; (pointDisplayMode) = 2
1dd0 324063    LD      (pointDisplayMode),A  ;    ''
1dd3 3A4263    LD      A,(pointAwardType)  ; switch pointAwardType
1dd6 1F        RRA                ;    case 1, 3, or 5
1dd7 DA703E    JP      C,AwardSelectedPoints ;       award 100, 300, or 500 points
1dda 1F        RRA                ;    case 2 
1ddb DA001E    JP      C,Award300Points ;       award 300 points
1dde 1F        RRA                ;    case 4
1ddf DAF51D    JP      C,1DF5H    ;       award random points (300, 500, or 800)
                                  ;    case 0
                                  ;       award points based 
                                  ;       on the level number
1de2 218560    LD      HL,6085H   ; (6085H) = 3
1de5 3603      LD      (HL),03H   ;    ''
1de7 3A2962    LD      A,(levelNum)  ; Switch (levelNum)
1dea 3D        DEC     A          ;    case level 1
1deb CA001E    JP      Z,Award300Points ;       award 300 points
1dee 3D        DEC     A          ;    case level 2
1def CA081E    JP      Z,Award500Points ;       award 500 points
                                  ;    case level 3+
1df2 C3101E    JP      Award800Points ;       award 800 points

AwardRandomPoints:
1df5 3A1860    LD      A,(randNum) ; Randomly award
1df8 1F        RRA                ;    500 points
1df9 DA081E    JP      C,Award500Points ;    800 points
1dfc 1F        RRA                ;    or 300 points
1dfd DA101E    JP      C,Award800Points ;    ''

Award300Points:
1e00 067D      LD      B,7DH      ; B = 300 point sprite   
1e02 110300    LD      DE,0003H   ; Add 300 points to score
1e05 C3151E    JP      DisplaySpriteAtAbsoluteCoord      ;    ''

Award500Points:
1e08 067E      LD      B,7EH      ; B = 500 point sprite
1e0a 110500    LD      DE,0005H   ; Add 500 points to score
1e0d C3151E    JP      DisplaySpriteAtAbsoluteCoord      ;    ''

Award800Points:
1e10 067F      LD      B,7FH      ; B = 800 point sprite
1e12 110800    LD      DE,0008H   ; Add 800 points to score

DisplaySpriteAtAbsoluteCoord:
1e15 CD9F30    CALL    AddFunctionToUpdateList
1e18 2A4363    LD      HL,(pPointSpriteX) ; A = temp point sprite X coord
1e1b 7E        LD      A,(HL)     ;    ''
1e1c 3600      LD      (HL),00H   ; Clear temp point sprite X coord
1e1e 2C        INC     L          ; C = temp point sprite Y position 
1e1f 2C        INC     L          ;
1e20 2C        INC     L          ;
1e21 4E        LD      C,(HL)     ; C = (HL)
1e22 C3361E    JP      DisplayPointsSprite

1e25 110100    LD      DE,0001H   ; Add 100 points to score

DisplaySpriteRelativeCoord:
1e28 CD9F30    CALL    AddFunctionToUpdateList
1e2b 3A0562    LD      A,(marioY) ; C = marioY + 20
1e2e C614      ADD     A,14H      ;    ''
1e30 4F        LD      C,A        ;    ''
1e31 3A0362    LD      A,(marioX) ; A = marioX
1e34 00        NOP     
1e35 00        NOP     

DisplayPointsSprite:
1e36 21306A    LD      HL,pointsSpriteX ; Point sprite X coord = A
1e39 77        LD      (HL),A     ;    ''
1e3a 2C        INC     L          ; Point sprite number = B
1e3b 70        LD      (HL),B     ;    ''
1e3c 2C        INC     L          ; Point sprite palette = 7
1e3d 3607      LD      (HL),07H   ;    ''
1e3f 2C        INC     L          ; Point sprite Y coord = C
1e40 71        LD      (HL),C     ;    ''
1e41 3E05      LD      A,05H      ; Return unless stage == 1 (barrels) or 4 (rivets)
1e43 F7        RST     ReturnUnlessStageOfInterest
1e44 218560    LD      HL,6085H   ; (6085H) = 3
1e47 3603      LD      (HL),03H   ;    ''

NoPointsToAward:
1e49 C9        RET                
;----------------------------------



;----------------------------------
; Keeps the point award sprite 
; displayed until the timeout
; reaches 0
DisplayPointsUntilTimeout:
1e4a 214163    LD      HL,pointSpriteTimeout ; Don't continue until
1e4d 35        DEC     (HL)        ;    pointSpriteTimeout
1e4e C0        RET     NZ          ;    reaches 0

1e4f AF        XOR     A           ; Stop showing the points sprite
1e50 32306A    LD      (pointsSpriteX),A ;    ''
1e53 324063    LD      (pointDisplayMode),A   ; (pointDisplayMode) = 0
1e56 C9        RET                 ;    Done
;----------------------------------



;----------------------------------
; Check for a win condition on the
; current stage
CheckForWin:
1e57 3A2762    LD      A,(currentStage) ; If currentStage 
1e5a CB57      BIT     2,A         ;    == rivets stage
1e5c C2801E    JP      NZ,CheckForWinOnRivetsStage ;    jump ahead

1e5f 1F        RRA                 ; If currentStage
1e60 3A0562    LD      A,(marioY)  ;    == barrels or elevators
1e63 DA7A1E    JP      C,CheckForWinOnBarrelsOrElevatorsStage ;    jump ahead

; currentStage == pies stage
1e66 FE51      CP      51H         ; If mario is below the 
1e68 D0        RET     NC          ;    top platform, return

1e69 3A0362    LD      A,(marioX)  ; If mario is on the
1e6c 17        RLA                 ;    right side of the
FaceMarioForWin:
1e6d 3E00      LD      A,00H       ;    screen, face mario
1e6f DA741E    JP      C,FaceMarioForWin1 ;    left, otherwise
1e72 3E80      LD      A,80H       ;    face right
FaceMarioForWin1:
1e74 324D69    LD      (marioSpriteNum),A ;    ''
1e77 C3851E    JP      EndStageWithAWin

; currentStage == barrels or elevators stage
CheckForWinOnBarrelsOrElevatorsStage:
1e7a FE31      CP      31H         ; If mario is below Pauline's
1e7c D0        RET     NC          ;    platform, return
1e7d C36D1E    JP      FaceMarioForWin

CheckForWinOnRivetsStage:
1e80 3A9062    LD      A,(rivetsRemaining) ; If there are rivets left
1e83 A7        AND     A           ;    return
1e84 C0        RET     NZ          ;    ''

EndStageWithAWin:
1e85 3E16      LD      A,16H       ; currentScreen = 22
1e87 320A60    LD      (currentScreen),A ;    ''
1e8a E1        POP     HL          ; Abort game sequence
1e8b C9        RET    
;---------------------------------- 



;----------------------------------
; Checks if a smash sequence is being
; animated.  If so, all other action
; in the game is stopped until the
; sequence has finished
ImplementSmashSequence:
1e8c 3A5063    LD      A,(smashSequenceActive) ; If (smashSequenceActive) 
1e8f A7        AND     A           ;    == 0
1e90 C8        RET     Z           ;    return

1e91 CD961E    CALL    1E96H       ; Else, call 1E96H
1e94 E1        POP     HL          ;    and return
1e95 C9        RET                 ;    from calling function
;----------------------------------



;----------------------------------
; Implement the smash sequence animation
ImplementSmashSequence1:
; Jump to address based on (smashSequenceMode)
1e96 3A4563    LD      A,(smashSequenceMode)
1e99 EF        RST     JumpToLocalTableAddress
1e9a A01E ; 0 = SmashSequence0
1e9c 091F ; 1 = SmashSequence1
1e9e 231F ; 2 = 1F23H
;----------------------------------



;----------------------------------
SmashSequence0:
1ea0 3A5263    LD      A,(6352H)   ; If 6352H
1ea3 FE65      CP      65H         ;    == 101
1ea5 21B869    LD      HL,69B8H    ;    HL = 69B8H
1ea8 CAB41E    JP      Z,1EB4H     ;    ''
1eab 21D069    LD      HL,69D0H    ; Else if 6352H < 101
1eae DAB41E    JP      C,1EB4H     ;    HL = 69D0H
1eb1 218069    LD      HL,6980H    ; Else (6352H > 101), HL = 6980H

1eb4 DD2A5163  LD      IX,(6351H) 
1eb8 1600      LD      D,00H
1eba 3A5363    LD      A,(6353H)
1ebd 5F        LD      E,A
1ebe 010400    LD      BC,0004H
1ec1 3A5463    LD      A,(indexOfSmashedSprite) ; A = the index of the smashed sprite
1ec4 A7        AND     A           ; If the index is 0,
1ec5 CACF1E    JP      Z,Label1ECF ;    jump ahead
Label1EC8:
1ec8 09        ADD     HL,BC       ; HL = address of next sprite
1ec9 DD19      ADD     IX,DE
1ecb 3D        DEC     A           ; Loop until HL = the address
1ecc C2C81E    JP      NZ,Label1EC8 ;    of the smashed sprite
Label1ECF:
1ecf DD360000  LD      (IX+00H),00H
1ed3 DD7E15    LD      A,(IX+15H)
1ed6 A7        AND     A
1ed7 3E02      LD      A,02H        ; Award 300 points
1ed9 CADE1E    JP      Z,Label1EDE ;    ''
1edc 3E04      LD      A,04H        ; Award random points
Label1EDE:
1ede 324263    LD      (pointAwardType),A ;    ''
1ee1 012C6A    LD      BC,smashSpriteX ; BC = address of smash sprite X coord
1ee4 7E        LD      A,(HL)       ; A = X coord of smashed sprite
1ee5 3600      LD      (HL),00H     ; Remove smashed sprite
1ee7 02        LD      (BC),A       ; Set X coord of smash sprite
1ee8 0C        INC     C            ; BC = address of smash sprite sprite number
1ee9 2C        INC     L            ; HL = address of smashed sprite sprite number 
1eea 3E60      LD      A,60H        ; Smash sprite number = 60H
1eec 02        LD      (BC),A       ;    ''
1eed 0C        INC     C            ; BC = address of smash sprite palette
1eee 2C        INC     L            ; BC = address of smashed sprite palette
1eef 3E0C      LD      A,0CH        ; Set smash sprite palette
1ef1 02        LD      (BC),A       ;    ''
1ef2 0C        INC     C            ; BC = address of smash sprite Y coord
1ef3 2C        INC     L            ; BC = address of smashed sprite Y coord
1ef4 7E        LD      A,(HL)       ; Set Y coord of smash sprite
1ef5 02        LD      (BC),A       ;    ''
1ef6 214563    LD      HL,smashSequenceMode ; smashSequenceMode = 1
1ef9 34        INC     (HL)         ;    ''
1efa 2C        INC     L            ; smashSequenceDelay = 6
1efb 3606      LD      (HL),06H     ;    ''
1efd 2C        INC     L            ; smashSequenceFrames = 5
1efe 3605      LD      (HL),05H
1f00 218A60    LD      HL,currentSong ; Trigger the hammer hit song
1f03 3606      LD      (HL),06H     ;    ''
1f05 2C        INC     L            ; currentSongDuration = 3
1f06 3603      LD      (HL),03H     ;    ''
1f08 C9        RET     
;----------------------------------



;----------------------------------
; Part 1 of the smash animation.
; The smash sprite oscillates briefly
; between a large and medium sized
; circle.
SmashSequencePart1:
1f09 214663    LD      HL,smashSequenceDelay ; Return until
1f0c 35        DEC     (HL)        ;    smashSequenceDelay reaches
1f0d C0        RET     NZ          ;    0

1f0e 3606      LD      (HL),06H    ; Reset smashSequenceDelay to 6
1f10 2C        INC     L           ; Decrement smashSequenceFrames
1f11 35        DEC     (HL)        ;    ''
1f12 CA1D1F    JP      Z,1F1DH     ; Jump ahead if the smash cycle is done

1f15 212D6A    LD      HL,smashSpriteNum ; Oscillate sprite
1f18 7E        LD      A,(HL)      ;    between 60H and 61H
1f19 EE01      XOR     01H         ;    ''
1f1b 77        LD      (HL),A      ;    ''
1f1c C9        RET     

1f1d 3604      LD      (HL),04H    ; smashSequenceFrames = 4
1f1f 2D        DEC     L           ; smashSequenceMode = 2
1f20 2D        DEC     L           ;    ''
1f21 34        INC     (HL)        ;    ''
1f22 C9        RET     
;----------------------------------



;----------------------------------
; Part 2 of the smash animation.
; The smash sprite grows smaller
; until it disappears
SmashSequencePart2:
1f23 214663    LD      HL,smashSequenceDelay ; Return until 
1f26 35        DEC     (HL)        ;    delay reaches 0
1f27 C0        RET     NZ          ;    ''

1f28 360C      LD      (HL),0CH    ; Reset delay to 12
1f2a 2C        INC     L           ; Decrement smashSequenceFrames
1f2b 35        DEC     (HL)        ;    ''
1f2c CA341F    JP      Z,1F34H     ; Jump ahead if it reaches 0
1f2f 212D6A    LD      HL,smashSpriteNum ; Set sprite number
1f32 34        INC     (HL)        ;    to the next sprite in
1f33 C9        RET                 ;    the sequence

1f34 2D        DEC     L           ; smashSequenceMode = 0
1f35 2D        DEC     L           ;    ''
1f36 AF        XOR     A           ;    ''
1f37 77        LD      (HL),A      ;    ''
1f38 325063    LD      (smashSequenceActive),A   ; smashSequenceActive = 0
1f3b 3C        INC     A           ; Trigger point display
1f3c 324063    LD      (pointDisplayMode),A ;    ''
1f3f 212C6A    LD      HL,smashSpriteX ; pPointSpriteX = (smashSpriteX)
1f42 224363    LD      (pPointSpriteX),HL ;    ''
1f45 C9        RET     
;----------------------------------



;----------------------------------
1f46 3A2162    LD      A,(6221H)
1f49 A7        AND     A
1f4a C8        RET     Z           ; Return if (6221h) == 0

1f4b AF        XOR     A    
1f4c 320462    LD      (6204H),A   ; (6204h) = 0
1f4f 320662    LD      (6206H),A   ; (6206h) = 0
1f52 322162    LD      (6221H),A   ; (6221h) = 0
1f55 321062    LD      (6210H),A   ; (6210h) = 0
1f58 321162    LD      (6211H),A   ; (6211h) = 0
1f5b 321262    LD      (6212H),A   ; (6212h) = 0
1f5e 321362    LD      (6213H),A   ; (6213h) = 0
1f61 321462    LD      (6214H),A   ; (6214h) = 0
1f64 3C        INC     A
1f65 321662    LD      (6216H),A   ; (6216h) = 1
1f68 321F62    LD      (621FH),A   ; (621fh) = 1
1f6b 3A0562    LD      A,(marioY)
1f6e 320E62    LD      (620EH),A   ; (620eh) = (marioY)
1f71 C9        RET     
;----------------------------------



;----------------------------------
1f72 3A2762    LD      A,(currentStage)
1f75 3D        DEC     A
1f76 C0        RET     NZ          ; Return if (currentStage != barrels

1f77 DD210067  LD      IX,6700H    ; IX = 6700h
1f7b 218069    LD      HL,6980H    
1f7e 112000    LD      DE,0020H
1f81 060A      LD      B,0AH       ; For B = 10 to 1
1f83 DD7E00    LD      A,(IX+00H)
1f86 3D        DEC     A
1f87 CA931F    JP      Z,1F93H     ; Jump ahead if (IX) == 1
1f8a 2C        INC     L           ; HL += 4
1f8b 2C        INC     L
1f8c 2C        INC     L
1f8d 2C        INC     L
1f8e DD19      ADD     IX,DE       ; IX += 32
1f90 10F1      DJNZ    1F83H       ; Next B
1f92 C9        RET     

1f93 DD7E01    LD      A,(IX+01H)
1f96 3D        DEC     A
1f97 CAEC20    JP      Z,20ECH
1f9a DD7E02    LD      A,(IX+02H)
1f9d 1F        RRA     
1f9e DAAC1F    JP      C,1FACH
1fa1 1F        RRA     
1fa2 DAE51F    JP      C,1FE5H
1fa5 1F        RRA     
1fa6 DAEF1F    JP      C,1FEFH
1fa9 C35320    JP      2053H
1fac D9        EXX     
1fad DD3405    INC     (IX+05H)
1fb0 DD7E17    LD      A,(IX+17H)
1fb3 DDBE05    CP      (IX+05H)
1fb6 C2CE1F    JP      NZ,1FCEH
1fb9 DD7E15    LD      A,(IX+15H)
1fbc 07        RLCA    
1fbd 07        RLCA    
1fbe C615      ADD     A,15H
1fc0 DD7707    LD      (IX+07H),A
1fc3 DD7E02    LD      A,(IX+02H)
1fc6 EE07      XOR     07H
1fc8 DD7702    LD      (IX+02H),A
1fcb C3BA21    JP      21BAH
1fce DD7E0F    LD      A,(IX+0FH)
1fd1 3D        DEC     A
1fd2 C2DF1F    JP      NZ,1FDFH
1fd5 DD7E07    LD      A,(IX+07H)
1fd8 EE01      XOR     01H
1fda DD7707    LD      (IX+07H),A
1fdd 3E04      LD      A,04H
1fdf DD770F    LD      (IX+0FH),A
1fe2 C3BA21    JP      21BAH
1fe5 D9        EXX     
1fe6 010001    LD      BC,0100H
1fe9 DD3403    INC     (IX+03H)
1fec C3F61F    JP      1FF6H
1fef D9        EXX     
1ff0 0104FF    LD      BC,FF04H
1ff3 DD3503    DEC     (IX+03H)
1ff6 DD6603    LD      H,(IX+03H)
1ff9 DD6E05    LD      L,(IX+05H)
1ffc 7C        LD      A,H
1ffd E607      AND     07H
1fff FE03      CP      03H
2001 CA5F21    JP      Z,215FH
2004 2D        DEC     L
2005 2D        DEC     L
2006 2D        DEC     L
2007 CD3323    CALL    2333H
200a 2C        INC     L
200b 2C        INC     L
200c 2C        INC     L
200d 7D        LD      A,L
200e DD7705    LD      (IX+05H),A
2011 CDDE23    CALL    23DEH
2014 CDB424    CALL    24B4H
2017 DD7E03    LD      A,(IX+03H)
201a FE1C      CP      1CH
201c DA2F20    JP      C,202FH
201f FEE4      CP      E4H
2021 DABA21    JP      C,21BAH
2024 AF        XOR     A
2025 DD7710    LD      (IX+10H),A
2028 DD361160  LD      (IX+11H),60H
202c C33820    JP      2038H
202f AF        XOR     A
2030 DD3610FF  LD      (IX+10H),FFH
2034 DD3611A0  LD      (IX+11H),A0H
2038 DD3612FF  LD      (IX+12H),FFH
203c DD3613F0  LD      (IX+13H),F0H
2040 DD7714    LD      (IX+14H),A
2043 DD770E    LD      (IX+0EH),A
2046 DD7704    LD      (IX+04H),A
2049 DD7706    LD      (IX+06H),A
204c DD360208  LD      (IX+02H),08H
2050 C3BA21    JP      21BAH
2053 D9        EXX     
2054 CD9C23    CALL    239CH
2057 CD2F2A    CALL    2A2FH
205a A7        AND     A
205b C28320    JP      NZ,2083H
205e DD7E03    LD      A,(IX+03H)
2061 C608      ADD     A,08H
2063 FE10      CP      10H
2065 DA7920    JP      C,2079H
2068 CDB424    CALL    24B4H
206b DD7E10    LD      A,(IX+10H)
206e E601      AND     01H
2070 07        RLCA    
2071 07        RLCA    
2072 4F        LD      C,A
2073 CDDE23    CALL    23DEH
2076 C3BA21    JP      21BAH
2079 AF        XOR     A
207a DD7700    LD      (IX+00H),A
207d DD7703    LD      (IX+03H),A
2080 C3BA21    JP      21BAH
2083 DD340E    INC     (IX+0EH)
2086 DD7E0E    LD      A,(IX+0EH)
2089 3D        DEC     A
208a CAA220    JP      Z,20A2H
208d 3D        DEC     A
208e CAC320    JP      Z,20C3H
2091 DD7E10    LD      A,(IX+10H)
2094 3D        DEC     A
2095 3E04      LD      A,04H
2097 C29C20    JP      NZ,209CH
209a 3E02      LD      A,02H
209c DD7702    LD      (IX+02H),A
209f C3BA21    JP      21BAH
20a2 DD7E15    LD      A,(IX+15H)
20a5 A7        AND     A
20a6 C2B520    JP      NZ,20B5H
20a9 210562    LD      HL,marioY
20ac DD7E05    LD      A,(IX+05H)
20af D616      SUB     16H
20b1 BE        CP      (HL)
20b2 D2C320    JP      NC,20C3H
20b5 DD7E10    LD      A,(IX+10H)
20b8 A7        AND     A
20b9 C2E120    JP      NZ,20E1H
20bc DD7711    LD      (IX+11H),A
20bf DD3610FF  LD      (IX+10H),FFH
20c3 CD0724    CALL    2407H
20c6 CB3C      SRL     H
20c8 CB1D      RR      L
20ca CB3C      SRL     H
20cc CB1D      RR      L
20ce DD7412    LD      (IX+12H),H
20d1 DD7513    LD      (IX+13H),L
20d4 AF        XOR     A
20d5 DD7714    LD      (IX+14H),A
20d8 DD7704    LD      (IX+04H),A
20db DD7706    LD      (IX+06H),A
20de C3BA21    JP      21BAH
20e1 DD361001  LD      (IX+10H),01H
20e5 DD361100  LD      (IX+11H),00H
20e9 C3C320    JP      20C3H
20ec D9        EXX     
20ed CD9C23    CALL    239CH
20f0 7C        LD      A,H
20f1 D61A      SUB     1AH
20f3 DD4619    LD      B,(IX+19H)
20f6 B8        CP      B
20f7 DA0421    JP      C,2104H
20fa CD2F2A    CALL    2A2FH
20fd A7        AND     A
20fe C21821    JP      NZ,2118H
2101 CDB424    CALL    24B4H
2104 DD7E03    LD      A,(IX+03H)
2107 C608      ADD     A,08H
2109 FE10      CP      10H
210b D2CE1F    JP      NC,1FCEH
210e AF        XOR     A
210f DD7700    LD      (IX+00H),A
2112 DD7703    LD      (IX+03H),A
2115 C3BA21    JP      21BAH
2118 DD7E05    LD      A,(IX+05H)
211b FEE0      CP      E0H
211d DA4621    JP      C,2146H
2120 DD7E07    LD      A,(IX+07H)
2123 E6FC      AND     FCH
2125 F601      OR      01H
2127 DD7707    LD      (IX+07H),A
212a AF        XOR     A
212b DD7701    LD      (IX+01H),A
212e DD7702    LD      (IX+02H),A
2131 DD3610FF  LD      (IX+10H),FFH
2135 DD7711    LD      (IX+11H),A
2138 DD7712    LD      (IX+12H),A
213b DD3613B0  LD      (IX+13H),B0H
213f DD360E01  LD      (IX+0EH),01H
2143 C35321    JP      2153H
2146 CD0724    CALL    2407H
2149 CDCB22    CALL    22CBH
214c DD7E05    LD      A,(IX+05H)
214f DD7719    LD      (IX+19H),A
2152 AF        XOR     A
2153 DD7714    LD      (IX+14H),A
2156 DD7704    LD      (IX+04H),A
2159 DD7706    LD      (IX+06H),A
215c C3BA21    JP      21BAH
215f 7D        LD      A,L
2160 C605      ADD     A,05H
2162 57        LD      D,A
2163 7C        LD      A,H
2164 011500    LD      BC,0015H
2167 CD6D21    CALL    216DH
216a C3BA21    JP      21BAH
216d CD6E23    CALL    236EH
2170 3D        DEC     A
2171 C0        RET     NZ

2172 78        LD      A,B
2173 D605      SUB     05H
2175 DD7717    LD      (IX+17H),A
2178 3A4863    LD      A,(oilBarrellOnFire)
217b A7        AND     A
217c CAB221    JP      Z,21B2H
217f 3A0562    LD      A,(marioY)
2182 D604      SUB     04H
2184 BA        CP      D
2185 D8        RET     C

2186 3A8063    LD      A,(6380H)
2189 1F        RRA     
218a 3C        INC     A
218b 47        LD      B,A
218c 3A1860    LD      A,(randNum)
218f 4F        LD      C,A
2190 E603      AND     03H
2192 B8        CP      B
2193 D0        RET     NC

2194 211060    LD      HL,playerInput
2197 3A0362    LD      A,(marioX)
219a BB        CP      E
219b CAB221    JP      Z,21B2H
219e D2A921    JP      NC,21A9H
21a1 CB46      BIT     0,(HL)
21a3 CAAE21    JP      Z,21AEH
21a6 C3B221    JP      21B2H
21a9 CB4E      BIT     1,(HL)
21ab C2B221    JP      NZ,21B2H
21ae 79        LD      A,C
21af E618      AND     18H
21b1 C0        RET     NZ

21b2 DD3407    INC     (IX+07H)
21b5 DDCB02C6  SET     0,(IX+02H)
21b9 C9        RET     

21ba D9        EXX     
21bb DD7E03    LD      A,(IX+03H)
21be 77        LD      (HL),A
21bf 2C        INC     L
21c0 DD7E07    LD      A,(IX+07H)
21c3 77        LD      (HL),A
21c4 2C        INC     L
21c5 DD7E08    LD      A,(IX+08H)
21c8 77        LD      (HL),A
21c9 2C        INC     L
21ca DD7E05    LD      A,(IX+05H)
21cd 77        LD      (HL),A
21ce C38D1F    JP      1F8DH


;----------------------------------
; Input data for the demo mode
; The first byte below is the first demo
; mode input value.  The first repeat value 
; is preset to ???.
; The two byte pairs of values that follow
; are:
; Byte 1 = repeat count
; Byte 2 = input data
; The expectation seems to be that Mario 
; will be dead before the input runs out.
; Interesting things happen if he doesn't,
; and the rest of the code that follows is
; treated as input data...
DemoModeInputData:
21d1    80 ; Jump
21d2 FE 01 ; Right x 
21d4 C0 04 ; Up x
21d6 50 02 ; Left x 
21d8 10 82 ; Jump, Left x 
21da 60 02 ; Left x 
21dc 10 82 ; Jump, Left x 
21de CA 01 ; Right x 
21e0 10 81 ; Jump, Right x 
21e2 FF 02 ; Left x 
21e4 38 01 ; Right x 
21e6 80 02 ; Left x 
21e8 FF 04 ; Up x 
21ea 80 04 ; Up x
21ec 60 80 ; Jump


;----------------------------------
; Simulate input during the demo mode
; The simulated input is read from
; DemoModeInputData above.
SimulateDemoInput:
21ee 11D121    LD      DE,DemoModeInputData ; DE = address of DemoModeInputData
21f1 21CC63    LD      HL,demoInputIndex ; A = (demoInputIndex)
21f4 7E        LD      A,(HL)      ;    ''
21f5 07        RLCA                ; Convert the index to an offset
21f6 83        ADD     A,E         ; DE += input offset
21f7 5F        LD      E,A         ;    (DE points to the byte of the simulated imput that should be used
21f8 1A        LD      A,(DE)      ; playerInput = (DE)
21f9 321060    LD      (playerInput),A ;    ''
21fc 2C        INC     L           ; HL = address of demoInputRepeat
21fd 7E        LD      A,(HL)      ; A = (demoInputRepeat)
21fe 35        DEC     (HL)        ; --demoInputRepeat
21ff A7        AND     A           ; Return until demoInputRepeat
2200 C0        RET     NZ          ;    == 0

2201 1C        INC     E           ; (demoInputRepeat) = next repeat value
2202 1A        LD      A,(DE)      ;    ''
2203 77        LD      (HL),A      ;    ''
2204 2D        DEC     L           ; ++(demoInputIndex)
2205 34        INC     (HL)        ;    ''
2206 C9        RET     
;----------------------------------



;----------------------------------
; Update the position of the retractable 
; ladders on the pies level
2207 3E02      LD      A,02H       ; Return if not the pies level
2209 F7        RST     ReturnUnlessStageOfInterest
220a 3A1A60    LD      A,(counter1)
220d 1F        RRA     
220e 218062    LD      HL,lLadderState ; A = (lLadderState)
2211 7E        LD      A,(HL)      ;    on odd counter1
2212 DA1922    JP      C,2219H     ;    cycles and 
2215 218862    LD      HL,rLadderState ;    (rLadderState) on even
2218 7E        LD      A,(HL)      ;    counter1 cycles
2219 E5        PUSH    HL          ; 
221a EF        RST     JumpToLocalTableAddress

221b 2722 ; 0 = 2227H Ladder up
221d 5922 ; 1 = 2259H Ladder moving down
221f 9922 ; 2 = 2299H Ladder down for random time
2221 A222 ; 3 = 22A2H
2223 0000 
2225 0000 
;----------------------------------



;----------------------------------
; Controls the retractable ladders
; on the pies level when they are
; in the up position, waiting to descend.
; 
; passed: HL - lLadderState or rLadderState
LadderState0:
2227 E1        POP     HL
2228 2C        INC     L
2229 35        DEC     (HL)        ; --nLadderDelay
222a C23A22    JP      NZ,Label223A ; If it's time to descend
222d 2D        DEC     L           ;    advance to the next ladder state
222e 34        INC     (HL)        ;    ''
222f 2C        INC     L
2230 2C        INC     L           ; HL = nLadderX
2231 CD4322    CALL    Label2243   ; If Mario is on this ladder
2234 3E01      LD      A,01H       ;    (621AH) = 1
2236 321A62    LD      (621AH),A   ;
2239 C9        RET     

Label223A:
223a 2C        INC     L           ; If the ladder is still up
223b CD4322    CALL    Label2243   ; If Mario is on this ladder
223e AF        XOR     A           ;    (621AH) = 0
223f 321A62    LD      (621AH),A
2242 C9        RET     
;----------------------------------



;----------------------------------
; Abort the calling function if:
;    Mario's Y coord is > 122 or
;    (6216H) != 0 or
;    Mario's X coord != current ladder's X coord
;
; passed: HL - the current retractable
;              ladder's X coordinate address
Label2243:
2243 3A0562    LD      A,(marioY)  
2246 FE7A      CP      7AH        
2248 D25722    JP      NC,Label2257
224b 3A1662    LD      A,(6216H)  
224e A7        AND     A          
224f C25722    JP      NZ,Label2257 
2252 3A0362    LD      A,(marioX) 
2255 BE        CP      (HL)      
2256 C8        RET     Z
Label2257:
2257 E1        POP     HL
2258 C9        RET     
;----------------------------------



;----------------------------------
; Move the ladder down one pixel every
; 4 calls.  Also force Mario down with it.
;
; If Mario is above the top of the stationary
; part of the ladder, he is moved down at
; the same speed as the retractable ladder.
; Otherwise, he is moved down at half the 
; speed.
;
; passed: HL - lLadderState or rLadderState
LadderState1:
2259 E1        POP     HL
225a 2C        INC     L
225b 2C        INC     L
225c 2C        INC     L
225d 2C        INC     L
225e 35        DEC     (HL)        ; --(nLadderMoveDelay)
225f C0        RET     NZ          ; If counter has reached 0

2260 3E04      LD      A,04H       ; reset nLadderMoveDelay to 4
2262 77        LD      (HL),A
2263 2D        DEC     L           
2264 34        INC     (HL)        ; Move ladder down 1 pixel
2265 CDBD22    CALL    22BDH       ; Update the ladder sprite Y coord
2268 3E78      LD      A,78H       ; If the ladder has reached its
226a BE        CP      (HL)        ;   lowest point
226b C27522    JP      NZ,2275H
226e 2D        DEC     L           ; Advance to the next ladder state
226f 2D        DEC     L
2270 2D        DEC     L
2271 34        INC     (HL)
2272 2C        INC     L
2273 2C        INC     L
2274 2C        INC     L
2275 2D        DEC     L           ; HL = nLadderX
2276 CD4322    CALL    Label2243   ; If Mario is on the ladder
2279 3A0562    LD      A,(marioY)
227c FE68      CP      68H
227e D28A22    JP      NC,228AH    ; If Mario is higher than the top of
2281 210562    LD      HL,marioY   ;    the stationary ladder
2284 34        INC     (HL)        ;    move him down 1 pixel
2285 CDC03F    CALL    3FC0H       ; Mario's sprite is now climbing, HL = marioSpriteY
2288 34        INC     (HL)        ; Move Mario's sprite down 1 pixel
2289 C9        RET     
;----------------------------------



;----------------------------------
; If (marioY) is odd, return to the 
; code above and move Mario down 1 pixel.
; If (marioY) is a multiple of 4,
; set (6222H) to 1 and return without
; moving Mario down.
; If (marioY) is a multiple of 2,
; set (6222H) to 0 and return without
; moving Mario down.
;
; passed: (marioY) in A
228a 1F        RRA                 ; If (marioY) is odd
228b DA8122    JP      C,2281H     ;    jump back up
228e 1F        RRA                 ; If (marioY) is a multiple of 4
228f 3E01      LD      A,01H       ;    (6222H) = 1
2291 DA9522    JP      C,2295H     ;    otherwise
2294 AF        XOR     A           ;    (6222H) = 0
2295 322262    LD      (6222H),A
2298 C9        RET     
;----------------------------------



;----------------------------------
; Leave the ladder down until a
; random roll of..., then advance
; to the next state.
;
; passed: HL - lLadderState or rLadderState
LadderState2:
2299 E1        POP     HL
229a 3A1860    LD      A,(randNum)
229d E63C      AND     3CH
229f C0        RET     NZ

22a0 34        INC     (HL)
22a1 C9        RET     
;----------------------------------



;----------------------------------
; Raise the ladder back up
;
; passed: HL - lLadderState or rLadderState
22a2 E1        POP     HL
22a3 2C        INC     L
22a4 2C        INC     L
22a5 2C        INC     L
22a6 2C        INC     L   
22a7 35        DEC     (HL)        ; --(nLadderMoveDelay)
22a8 C0        RET     NZ          ; Return if counter has not reached 0

22a9 3602      LD      (HL),02H    ; Reset nLadderMoveDelay to 2
22ab 2D        DEC     L
22ac 35        DEC     (HL)        ; Move ladder up 1 pixel
22ad CDBD22    CALL    22BDH       ; Update the ladder sprite Y coord
22b0 3E68      LD      A,68H
22b2 BE        CP      (HL)
22b3 C0        RET     NZ          ; Return if ladder is not all the way up

22b4 AF        XOR     A
22b5 0680      LD      B,80H
22b7 2D        DEC     L
22b8 2D        DEC     L
22b9 70        LD      (HL),B      ; nLadderDelay = 80H
22ba 2D        DEC     L
22bb 77        LD      (HL),A      ; nLadderState = 0
22bc C9        RET     
;----------------------------------



;----------------------------------
; Set either lLadderSpriteY or
; rLadderSpriteY to the current
; ladder's Y coord (in nLadderY)
; Depending on which ladder is being
; processed
;
; passed: nLadderY in HL
22bd 7E        LD      A,(HL)     ; A = ladder Y coord
22be CB5D      BIT     3,L        
22c0 114B69    LD      DE,694BH   
22c3 C2C922    JP      NZ,22C9H
22c6 114769    LD      DE,6947H
22c9 12        LD      (DE),A
22ca C9        RET     
;----------------------------------



;----------------------------------
22cb 3A4863    LD      A,(oilBarrelOnFire)
22ce A7        AND     A
22cf CAE122    JP      Z,22E1H     ; If oil barrel is not on fire jump ahead
22d2 3A8063    LD      A,(6380H)
22d5 3D        DEC     A           ; A = (6380H) - 1
22d6 EF        RST     JumpToLocalTableAddress
22d7 F622 ; 22F6H
22d9 F622 ; 22F6H
22db 0323 ; 2303H
22dd 0323 ; 2303H
22df 1A23 ; 231AH
;----------------------------------



;----------------------------------
22e1 3A2962    LD      A,(levelNum)
22e4 47        LD      B,A
22e5 05        DEC     B
22e6 3E01      LD      A,01H
22e8 CAF922    JP      Z,22F9H    ; If this is level 1, jump ahead with A = 1
22eb 05        DEC     B
22ec 3EB1      LD      A,B1H
22ee CAF922    JP      Z,22F9H    ; If this is level 2, jump ahead with A = B1h
22f1 3EE9      LD      A,E9H
22f3 C3F922    JP      22F9H      ; Level 3+ jump ahead with A = E9h
;----------------------------------



;----------------------------------
; passed: IX
22f6 3A1860    LD      A,(randNum)
22f9 DD7711    LD      (IX+11H),A
22fc E601      AND     01H
22fe 3D        DEC     A           ; A = random 1 or -1
22ff DD7710    LD      (IX+10H),A
2302 C9        RET   
;----------------------------------  



;----------------------------------  
; Set ???'s X direction? to head
; toward Mario
; passed: IX
2303 3A1860    LD      A,(randNum)
2306 DD7711    LD      (IX+11H),A
2309 3A0362    LD      A,(marioX)
230c DDBE03    CP      (IX+03H)
230f 3E01      LD      A,01H
2311 D21623    JP      NC,2316H
2314 3D        DEC     A
2315 3D        DEC     A
2316 DD7710    LD      (IX+10H),A
2319 C9        RET     
;----------------------------------  



;----------------------------------  
; passed: IX
231a 3A0362    LD      A,(marioX)
231d DD9603    SUB     (IX+03H)
2320 0EFF      LD      C,FFH
2322 DA2623    JP      C,2326H
2325 0C        INC     C
2326 07        RLCA    
2327 CB11      RL      C
2329 07        RLCA    
232a CB11      RL      C
232c DD7110    LD      (IX+10H),C
232f DD7711    LD      (IX+11H),A
2332 C9        RET     
;----------------------------------  




;----------------------------------  
2333 3E0F      LD      A,0FH
2335 A4        AND     H
2336 05        DEC     B
2337 CA4223    JP      Z,2342H
233a FE0F      CP      0FH
233c D8        RET     C

233d 06FF      LD      B,FFH
233f C34723    JP      2347H

2342 FE01      CP      01H
2344 D0        RET     NC

2345 0601      LD      B,01H
2347 3EF0      LD      A,F0H
2349 BD        CP      L
234a CA6023    JP      Z,2360H
234d 3E4C      LD      A,4CH
234f BD        CP      L
2350 CA6623    JP      Z,2366H
2353 7D        LD      A,L
2354 CB6F      BIT     5,A
2356 CA5C23    JP      Z,235CH
2359 90        SUB     B
235a 6F        LD      L,A
235b C9        RET     

235c 80        ADD     A,B
235d C35A23    JP      235AH
2360 CB7C      BIT     7,H
2362 C25923    JP      NZ,2359H
2365 C9        RET     

2366 7C        LD      A,H
2367 FE98      CP      98H
2369 D8        RET     C

236a 7D        LD      A,L
236b C35C23    JP      235CH
236e 210063    LD      HL,6300H
2371 EDB1      CPIR    
2373 C29A23    JP      NZ,239AH
2376 E5        PUSH    HL
2377 C5        PUSH    BC
2378 011400    LD      BC,0014H
237b 09        ADD     HL,BC
237c 0C        INC     C
237d 5F        LD      E,A
237e 7A        LD      A,D
237f BE        CP      (HL)
2380 CA8F23    JP      Z,238FH
2383 09        ADD     HL,BC
2384 BE        CP      (HL)
2385 CA9523    JP      Z,2395H
2388 57        LD      D,A
2389 7B        LD      A,E
238a C1        POP     BC
238b E1        POP     HL
238c C37123    JP      2371H
238f 09        ADD     HL,BC
2390 3E01      LD      A,01H
2392 C39823    JP      2398H
2395 AF        XOR     A
2396 ED42      SBC     HL,BC
2398 C1        POP     BC
2399 46        LD      B,(HL)
239a E1        POP     HL
239b C9        RET     
;----------------------------------  

239c DD7E04    LD      A,(IX+04H)
239f DD8611    ADD     A,(IX+11H)
23a2 DD7704    LD      (IX+04H),A
23a5 DD7E03    LD      A,(IX+03H)
23a8 DD8E10    ADC     A,(IX+10H)
23ab DD7703    LD      (IX+03H),A
23ae DD7E06    LD      A,(IX+06H)
23b1 DD9613    SUB     (IX+13H)
23b4 6F        LD      L,A
23b5 DD7E05    LD      A,(IX+05H)
23b8 DD9E12    SBC     A,(IX+12H)
23bb 67        LD      H,A
23bc DD7E14    LD      A,(IX+14H)
23bf A7        AND     A
23c0 17        RLA     
23c1 3C        INC     A
23c2 0600      LD      B,00H
23c4 CB10      RL      B
23c6 CB27      SLA     A
23c8 CB10      RL      B
23ca CB27      SLA     A
23cc CB10      RL      B
23ce CB27      SLA     A
23d0 CB10      RL      B
23d2 4F        LD      C,A
23d3 09        ADD     HL,BC
23d4 DD7405    LD      (IX+05H),H
23d7 DD7506    LD      (IX+06H),L
23da DD3414    INC     (IX+14H)
23dd C9        RET     

23de DD7E0F    LD      A,(IX+0FH)
23e1 3D        DEC     A
23e2 C20324    JP      NZ,2403H
23e5 AF        XOR     A
23e6 DDCB0726  SLA     (IX+07H)
23ea 17        RLA     
23eb DDCB0826  SLA     (IX+08H)
23ef 17        RLA     
23f0 47        LD      B,A
23f1 3E03      LD      A,03H
23f3 B1        OR      C
23f4 CD0930    CALL    3009H
23f7 1F        RRA     
23f8 DDCB081E  RR      (IX+08H)
23fc 1F        RRA     
23fd DDCB071E  RR      (IX+07H)
2401 3E04      LD      A,04H
2403 DD770F    LD      (IX+0FH),A
2406 C9        RET     

2407 DD7E14    LD      A,(IX+14H)
240a 07        RLCA    
240b 07        RLCA    
240c 07        RLCA    
240d 07        RLCA    
240e 4F        LD      C,A
240f E60F      AND     0FH
2411 67        LD      H,A
2412 79        LD      A,C
2413 E6F0      AND     F0H
2415 6F        LD      L,A
2416 DD4E13    LD      C,(IX+13H)
2419 DD4612    LD      B,(IX+12H)
241c ED42      SBC     HL,BC
241e C9        RET     


;----------------------------------
; Implements the barriers that stop
; mario from moving past the edges
; of the screeen or past the
; invisible barriers surrounding
; DK on the barrels and elevators
; stages.
; Passed: none
; Return: D = 1 if mario can't move left
;         E = 1 if mario can't move right
CheckForBarriers:
241f 110001    LD      DE,0100H    ; DE = 0100H
2422 3A0362    LD      A,(marioX)  ; If marioX < 22
2425 FE16      CP      16H         ;    (at extreme left edge)
2427 D8        RET     C           ;    return DE = 0100H

2428 15        DEC     D           ; DE = 0001H
2429 1C        INC     E           ;    ''
242a FEEA      CP      EAH         ; If marioX > 234 (extreme rightt edge)
242c D0        RET     NC          ;    return DE = 0001H

242d 1D        DEC     E           ; DE = 0000H
242e 3A2762    LD      A,(currentStage) ;if currentStage != 
2431 0F        RRCA                ;    1 (barrels) or 3 (elevators)
2432 D0        RET     NC          ;    return DE = 0000H

2433 3A0562    LD      A,(marioY) ; If marioY > 88 
2436 FE58      CP      58H         ;    (lower than top platform)
2438 D0        RET     NC          ;    return DE = 0000H

2439 3A0362    LD      A,(marioX)  ; If marioX > 108
243c FE6C      CP      6CH         ;    (invisible barrier on top platform)
243e D0        RET     NC          ;    return DE = 0000H

243f 14        INC     D           ; Return DE = 0100H
2440 C9        RET                 ;    ''
;----------------------------------



;----------------------------------

; 3F0CH to 3F11H
; If 3F0CH through 3F11H contain the
; text "INTEND", IY = 6310H, otherwise
; IY = 6311H
2441 210C3F    LD      HL,3F0CH    ; HL = 3F0CH
2444 3E5E      LD      A,5EH       ; A = 94
2446 0606      LD      B,06H       ; For B = 6 to 1
Label2448:
2448 86        ADD     A,(HL)      ; A += (HL)
2449 23        INC     HL          ; ++HL
244a 10FC      DJNZ    Label2448   ; Next B
244c FD211063  LD      IY,6310H    ; If the sum == 100H,
2450 A7        AND     A           ;    IY = 6310H
2451 CA5624    JP      Z,2456H     ; else
2454 FD23      INC     IY          ;    IY = 6311H

2456 3A2762    LD      A,(currentStage) ; If currentStage == 1
2459 3D        DEC     A                ;    (barrels stage),
245a 21E43A    LD      HL,BarrelsStageData ;    HL = address of barrels
245d CA7124    JP      Z,Label2471      ;    stage data
2460 3D        DEC     A                ; else if currentStage == 2
2461 215D3B    LD      HL,PiesStageData ;    (pies stage),
2464 CA7124    JP      Z,Label2471      ;    HL = address of pies stage data
2467 3D        DEC     A                ; else if currentStage == 3
2468 21E53B    LD      HL,ElevatorsStageData ;    (elevators stage),
246b CA7124    JP      Z,Label2471      ;    HL = address of elevators stage data
246e 218B3C    LD      HL,RivetsStageData ; else (rivets stage) HL = address of rivets stage data
Label2471:
2471 DD210063  LD      IX,6300H         ; IX = 6300H
2475 110500    LD      DE,0005H         ; DE = 5
Label2478:
2478 7E        LD      A,(HL)           ; A = byte of stage data
2479 A7        AND     A                ; If byte == 0 (ladder),
247a CA8824    JP      Z,2488H          ;    jump ahead
247d 3D        DEC     A                ; else if byte == 1 (broken ladder),
247e CA9E24    JP      Z,249EH          ;    jump ahead
2481 FEA9      CP      A9H              ; else if byte == AAH (end of stage data),
2483 C8        RET     Z                ;    return
                                        ; else (byte == 2 or 3 - girders)
2484 19        ADD     HL,DE            ; HL += 5
2485 C37824    JP      Label2478        

; Handle ladder data
2488 23        INC     HL               ; IX + 0 = X coord of ladder
2489 7E        LD      A,(HL)           ;    ''
248a DD7700    LD      (IX+00H),A       ;    ''
248d 23        INC     HL               ; IX + 21 = X offset of ladder?
248e 7E        LD      A,(HL)           ;    ''
248f DD7715    LD      (IX+15H),A       ;    ''
2492 23        INC     HL               ; IX + 42 = Y offset of ladder
2493 23        INC     HL               ;    ''
2494 7E        LD      A,(HL)           ;    ''
2495 DD772A    LD      (IX+2AH),A       ;    ''
2498 DD23      INC     IX
249a 23        INC     HL
249b C37824    JP      2478H

249e 23        INC     HL
249f 7E        LD      A,(HL)
24a0 FD7700    LD      (IY+00H),A
24a3 23        INC     HL
24a4 7E        LD      A,(HL)
24a5 FD7715    LD      (IY+15H),A
24a8 23        INC     HL
24a9 23        INC     HL
24aa 7E        LD      A,(HL)
24ab FD772A    LD      (IY+2AH),A
24ae FD23      INC     IY
24b0 23        INC     HL
24b1 C37824    JP      2478H

24b4 DD7E05    LD      A,(IX+05H)
24b7 FEE8      CP      E8H
24b9 D8        RET     C

24ba DD7E03    LD      A,(IX+03H)
24bd FE2A      CP      2AH
24bf D0        RET     NC

24c0 FE20      CP      20H
24c2 D8        RET     C

24c3 DD7E15    LD      A,(IX+15H)
24c6 A7        AND     A
24c7 CAD024    JP      Z,24D0H
24ca 3E03      LD      A,03H
24cc 32B962    LD      (OilBarrelFireState),A
24cf AF        XOR     A
24d0 DD7700    LD      (IX+00H),A
24d3 DD7703    LD      (IX+03H),A
24d6 218260    LD      HL,soundEffect ; Trigger DK stomp sound
24d9 3603      LD      (HL),03H    ;    ''
24db E1        POP     HL
24dc 3A4863    LD      A,(oilBarrellOnFire)
24df A7        AND     A
24e0 C2BA21    JP      NZ,21BAH
24e3 3C        INC     A
24e4 324863    LD      (oilBarrellOnFire),A
24e7 C3BA21    JP      21BAH
24ea 3E02      LD      A,02H
24ec F7        RST     ReturnUnlessStageOfInterest
24ed CD2325    CALL    2523H
24f0 CD9125    CALL    2591H
24f3 DD21A065  LD      IX,65A0H
24f7 0606      LD      B,06H
24f9 21B869    LD      HL,69B8H
24fc DD7E00    LD      A,(IX+00H)
24ff A7        AND     A
2500 CA1C25    JP      Z,251CH
2503 DD7E03    LD      A,(IX+03H)
2506 77        LD      (HL),A
2507 2C        INC     L
2508 DD7E07    LD      A,(IX+07H)
250b 77        LD      (HL),A
250c 2C        INC     L
250d DD7E08    LD      A,(IX+08H)
2510 77        LD      (HL),A
2511 2C        INC     L
2512 DD7E05    LD      A,(IX+05H)
2515 77        LD      (HL),A
2516 2C        INC     L
2517 DD19      ADD     IX,DE
2519 10E1      DJNZ    24FCH
251b C9        RET     

251c 7D        LD      A,L
251d C604      ADD     A,04H
251f 6F        LD      L,A
2520 C31725    JP      2517H
2523 219B63    LD      HL,639BH
2526 7E        LD      A,(HL)
2527 A7        AND     A
2528 C28F25    JP      NZ,258FH
252b 3A9A63    LD      A,(639AH)
252e A7        AND     A
252f C8        RET     Z

2530 0606      LD      B,06H
2532 111000    LD      DE,0010H
2535 DD21A065  LD      IX,65A0H
2539 DDCB0046  BIT     0,(IX+00H)
253d CA4525    JP      Z,2545H
2540 DD19      ADD     IX,DE
2542 10F5      DJNZ    2539H
2544 C9        RET     

2545 CD5700    CALL    UpdateRandomNumber      ; Update the game's random number
2548 FE60      CP      60H
254a DD36057C  LD      (IX+05H),7CH
254e DA5825    JP      C,2558H
2551 3AA362    LD      A,(conveyer2Dir)
2554 3D        DEC     A
2555 C26E25    JP      NZ,256EH
2558 DD3605CC  LD      (IX+05H),CCH
255c 3AA662    LD      A,(conveyer3Dir)
255f 07        RLCA    
2560 DD360307  LD      (IX+03H),07H
2564 D27625    JP      NC,2576H
2567 DD3603F8  LD      (IX+03H),F8H
256b C37625    JP      2576H
256e CD5700    CALL    UpdateRandomNumber      ; Update the game's random number
2571 FE68      CP      68H
2573 C36025    JP      2560H
2576 DD360001  LD      (IX+00H),01H
257a DD36074B  LD      (IX+07H),4BH
257e DD360908  LD      (IX+09H),08H
2582 DD360A03  LD      (IX+0AH),03H
2586 3E7C      LD      A,7CH
2588 329B63    LD      (639BH),A
258b AF        XOR     A
258c 329A63    LD      (639AH),A
258f 35        DEC     (HL)
2590 C9        RET     

2591 DD21A065  LD      IX,65A0H
2595 111000    LD      DE,0010H
2598 0606      LD      B,06H
259a DDCB0046  BIT     0,(IX+00H)
259e CABB25    JP      Z,25BBH
25a1 DD7E03    LD      A,(IX+03H)
25a4 67        LD      H,A
25a5 C607      ADD     A,07H
25a7 FE0E      CP      0EH
25a9 DAD625    JP      C,25D6H
25ac DD7E05    LD      A,(IX+05H)
25af FE7C      CP      7CH
25b1 CAC025    JP      Z,25C0H
25b4 3AA663    LD      A,(conveyer3Offset)
25b7 84        ADD     A,H
25b8 DD7703    LD      (IX+03H),A
25bb DD19      ADD     IX,DE
25bd 10DB      DJNZ    259AH
25bf C9        RET     

25c0 7C        LD      A,H
25c1 FE80      CP      80H
25c3 CAD625    JP      Z,25D6H
25c6 3AA563    LD      A,(conveyer2LOffset)
25c9 D2CF25    JP      NC,25CFH
25cc 3AA463    LD      A,(conveyer2ROffset)
25cf 84        ADD     A,H
25d0 DD7703    LD      (IX+03H),A
25d3 C3BB25    JP      25BBH
25d6 21B869    LD      HL,69B8H
25d9 3E06      LD      A,06H
25db 90        SUB     B
25dc CAE725    JP      Z,25E7H
25df 2C        INC     L
25e0 2C        INC     L
25e1 2C        INC     L
25e2 2C        INC     L
25e3 3D        DEC     A
25e4 C3DC25    JP      25DCH
25e7 AF        XOR     A
25e8 DD7700    LD      (IX+00H),A
25eb DD7703    LD      (IX+03H),A
25ee 77        LD      (HL),A
25ef C3BB25    JP      25BBH
25f2 3E02      LD      A,02H       ; Abort if not pies stage
25f4 F7        RST     ReturnUnlessStageOfInterest
25f5 CD0226    CALL    2602H
25f8 CD2F26    CALL    262FH
25fb CD7926    CALL    2679H
25fe CDD32A    CALL    ConveyMario
2601 C9        RET     
;----------------------------------



;----------------------------------
2602 3A1A60    LD      A,(counter1) ; If odd counter cycle
2605 0F        RRCA                ;    jump ahead
2606 DA1626    JP      C,2616H     ;    ''

2609 21A062    LD      HL,62A0H    ; --(62A0H)
260c 35        DEC     (HL)        ;    ''
260d C21626    JP      NZ,2616H    ; If (62A0H) > 0 jump ahead

2610 3680      LD      (HL),80H    ;    else (62A0H) = 128
2612 2C        INC     L           ; HL = address of conveyer1Dir
2613 CDDE26    CALL    26DEH       ; Double the conveyer speed?

2616 21A162    LD      HL,conveyer1Dir ; HL = conveyer1Dir
2619 CDE926    CALL    GetConveyerOffset ; A = offset
261c 32A363    LD      (conveyer1Offset),A ; (conveyer1Offset) = offset
261f 3A1A60    LD      A,(counter1) ; Continue once
2622 E61F      AND     1FH         ;    every 32 counter
2624 FE01      CP      01H         ;    cycles
2626 C0        RET     NZ          ;    ''

2627 11E469    LD      DE,69E4H    ; HL = 69E4H
262a EB        EX      DE,HL       ; DE = address of conveyer1Dir
262b CDA626    CALL    ConveySprite
262e C9        RET     
;----------------------------------



262f 21A362    LD      HL,conveyer2Dir
2632 3A0562    LD      A,(marioY)
2635 FEC0      CP      C0H
2637 DA6F26    JP      C,266FH
263a 3A1A60    LD      A,(counter1)
263d 0F        RRCA    
263e DA4C26    JP      C,264CH
2641 2D        DEC     L
2642 35        DEC     (HL)
2643 C24C26    JP      NZ,264CH
2646 36C0      LD      (HL),C0H
2648 2C        INC     L
2649 CDDE26    CALL    26DEH
264c 21A362    LD      HL,conveyer2Dir
264f CDE926    CALL    GetConveyerOffset ; A = offset
2652 32A563    LD      (conveyer2LOffset),A ; (conveyer2LOffset) = offset
2655 ED44      NEG     
2657 32A463    LD      (conveyer2ROffset),A   ; (conveyer2ROffset) = opposite of offset
265a 3A1A60    LD      A,(counter1)
265d E61F      AND     1FH
265f C0        RET     NZ

2660 2D        DEC     L
2661 11EC69    LD      DE,69ECH
2664 EB        EX      DE,HL
2665 CDA626    CALL    ConveySprite
2668 E67F      AND     7FH
266a 21ED69    LD      HL,69EDH
266d 77        LD      (HL),A
266e C9        RET     

266f CB7E      BIT     7,(HL)
2671 C24C26    JP      NZ,264CH
2674 36FF      LD      (HL),FFH
2676 C34C26    JP      264CH
2679 3A1A60    LD      A,(counter1)
267c 0F        RRCA    
267d DA8D26    JP      C,268DH
2680 21A562    LD      HL,62A5H
2683 35        DEC     (HL)
2684 C28D26    JP      NZ,268DH
2687 36FF      LD      (HL),FFH
2689 2C        INC     L
268a CDDE26    CALL    26DEH
268d 21A662    LD      HL,conveyer3Dir
2690 CDE926    CALL    GetConveyerOffset ; A = offset
2693 32A663    LD      (conveyer3Offset),A ; (conveyer3Offset) = offset
2696 3A1A60    LD      A,(counter1) ; A = counter1
2699 E61F      AND     1FH         ; A %= 31
269b FE02      CP      02H
269d C0        RET     NZ

269e 11F469    LD      DE,69F4H
26a1 EB        EX      DE,HL
26a2 CDA626    CALL    ConveySprite
26a5 C9        RET     



;----------------------------------
; passed: HL - address of sprite?
;         DE - address of conveyer dir
;              variable
ConveySprite:
26a6 2C        INC     L           ; HL = sprite X coord
26a7 1A        LD      A,(DE)      ; A = conveyer dir
26a8 17        RLA                 ; If conveyer is moving left
26a9 DAC526    JP      C,ConveySpriteLeft ;    jump ahead

26ac 7E        LD      A,(HL)      ; ++ X coord
26ad 3C        INC     A           ;    ''
26ae FE53      CP      53H         ; If X coord == 83
26b0 C2B526    JP      NZ,26B5H    ;    X coord = 80
26b3 3E50      LD      A,50H       ;    ''
26b5 77        LD      (HL),A      ;    ''
26b6 7D        LD      A,L         ; HL += 4
26b7 C604      ADD     A,04H       ;    ''
26b9 6F        LD      L,A         ;    ''
26ba 7E        LD      A,(HL)      ; --(HL)
26bb 3D        DEC     A           ;    ''
26bc FECF      CP      CFH         ; If (HL) == 207
26be C2C326    JP      NZ,26C3H    ;    (HL) = 210
26c1 3ED2      LD      A,D2H       ;    ''
26c3 77        LD      (HL),A      ;    ''
26c4 C9        RET     

ConveySpriteLeft:
26c5 7E        LD      A,(HL)      ; -- X coord
26c6 3D        DEC     A           ;    ''
26c7 FE4F      CP      4FH         ; If X coord == 79
26c9 C2CE26    JP      NZ,26CEH    ;    X coord = 82
26cc 3E52      LD      A,52H       ;    ''
26ce 77        LD      (HL),A      ;    ''
26cf 7D        LD      A,L         ; HL += 4
26d0 C604      ADD     A,04H       ;    ''
26d2 6F        LD      L,A         ;    ''
26d3 7E        LD      A,(HL)      ; ++(HL)
26d4 3C        INC     A           ;    ''
26d5 FED3      CP      D3H         ; If (HL) == 211
26d7 C2DC26    JP      NZ,26DCH    ;    (HL) = 208
26da 3ED0      LD      A,D0H       ;    ''
26dc 77        LD      (HL),A      ;    ''
26dd C9        RET     
;----------------------------------



;----------------------------------
26de CB7E      BIT     7,(HL)      ; If (HL) < 0
26e0 CAE626    JP      Z,26E6H     ;    (HL) = -2
26e3 3602      LD      (HL),02H    ;    else (HL) = 2
26e5 C9        RET                 ;    ''
26e6 36FE      LD      (HL),FEH    ;    ''
26e8 C9        RET                 ;    ''
;----------------------------------



;----------------------------------
; Determines if, and in what direction
; an object on a conveyer belt should
; be moved.
; Conveyers only move on even counter
; cycles.
; passed: HL - address of conveyer 
;            direction variable
; Return: offset (in pixels)
GetConveyerOffset:
26e9 3A1A60    LD      A,(counter1) ; If counter1 
26ec E601      AND     01H         ;    is even
26ee C8        RET     Z           ;    return A = 0

26ef CB7E      BIT     7,(HL)      ; If conveyer dir is negative
26f1 3EFF      LD      A,FFH       ;    A = -1
26f3 C2F826    JP      NZ,26F8H    ;    else
26f6 3E01      LD      A,01H       ;    A = 1
26f8 77        LD      (HL),A      ; conveyer dir = A
26f9 C9        RET                 ; Return A = -1 or 1
;----------------------------------



26fa 3E04      LD      A,04H
26fc F7        RST     ReturnUnlessStageOfInterest
26fd 3A0562    LD      A,(marioY)
2700 FEF0      CP      F0H
2702 D27F27    JP      NC,277FH
2705 3A2962    LD      A,(levelNum)
2708 3D        DEC     A
2709 3A1A60    LD      A,(counter1)
270c C21A27    JP      NZ,271AH
270f E603      AND     03H
2711 FE01      CP      01H
2713 CA1E27    JP      Z,271EH
2716 DA2227    JP      C,2722H
2719 C9        RET     

271a 0F        RRCA    
271b DA2227    JP      C,2722H
271e CD4527    CALL    2745H
2721 C9        RET     

2722 CD9727    CALL    2797H
2725 CDDA27    CALL    27DAH
2728 0606      LD      B,06H
272a 111000    LD      DE,0010H
272d 215869    LD      HL,6958H
2730 DD210066  LD      IX,6600H
2734 DD7E03    LD      A,(IX+03H)
2737 77        LD      (HL),A
2738 2C        INC     L
2739 2C        INC     L
273a 2C        INC     L
273b DD7E05    LD      A,(IX+05H)
273e 77        LD      (HL),A
273f 2C        INC     L
2740 DD19      ADD     IX,DE
2742 10F0      DJNZ    2734H
2744 C9        RET     

2745 3A9863    LD      A,(6398H)
2748 A7        AND     A
2749 C8        RET     Z

274a 3A1662    LD      A,(6216H)
274d A7        AND     A
274e C0        RET     NZ

274f 3A0362    LD      A,(marioX)
2752 FE2C      CP      2CH
2754 DA6627    JP      C,2766H
2757 FE43      CP      43H
2759 DA6F27    JP      C,276FH
275c FE6C      CP      6CH
275e DA6627    JP      C,2766H
2761 FE83      CP      83H
2763 DA8727    JP      C,2787H
2766 AF        XOR     A
2767 329863    LD      (6398H),A
276a 3C        INC     A
276b 322162    LD      (6221H),A
276e C9        RET     

276f 3A0562    LD      A,(marioY)
2772 FE71      CP      71H
2774 DA7F27    JP      C,277FH
2777 3D        DEC     A
2778 320562    LD      (marioY),A
277b 324F69    LD      (marioSpriteY),A
277e C9        RET     

277f AF        XOR     A
2780 320062    LD      (marioAlive),A
2783 329863    LD      (6398H),A
2786 C9        RET     

2787 3A0562    LD      A,(marioY)
278a FEE8      CP      E8H
278c D27F27    JP      NC,277FH
278f 3C        INC     A
2790 320562    LD      (marioY),A
2793 324F69    LD      (marioSpriteY),A
2796 C9        RET     

2797 0606      LD      B,06H
2799 111000    LD      DE,0010H
279c DD210066  LD      IX,6600H
27a0 DDCB0046  BIT     0,(IX+00H)
27a4 CAC227    JP      Z,27C2H
27a7 DDCB0D5E  BIT     3,(IX+0DH)
27ab CAC727    JP      Z,27C7H
27ae DD7E05    LD      A,(IX+05H)
27b1 3D        DEC     A
27b2 DD7705    LD      (IX+05H),A
27b5 FE60      CP      60H
27b7 C2C227    JP      NZ,27C2H
27ba DD360377  LD      (IX+03H),77H
27be DD360D04  LD      (IX+0DH),04H
27c2 DD19      ADD     IX,DE
27c4 10DA      DJNZ    27A0H
27c6 C9        RET     

27c7 DD7E05    LD      A,(IX+05H)
27ca 3C        INC     A
27cb DD7705    LD      (IX+05H),A
27ce FEF8      CP      F8H
27d0 C2C227    JP      NZ,27C2H
27d3 DD360000  LD      (IX+00H),00H
27d7 C3C227    JP      27C2H
27da 21A762    LD      HL,62A7H
27dd 7E        LD      A,(HL)
27de A7        AND     A
27df C20628    JP      NZ,2806H
27e2 0606      LD      B,06H
27e4 DD210066  LD      IX,6600H
27e8 DDCB0046  BIT     0,(IX+00H)
27ec CAF427    JP      Z,27F4H
27ef DD19      ADD     IX,DE
27f1 10F5      DJNZ    27E8H
27f3 C9        RET     

27f4 DD360001  LD      (IX+00H),01H
27f8 DD360337  LD      (IX+03H),37H
27fc DD3605F8  LD      (IX+05H),F8H
2800 DD360D08  LD      (IX+0DH),08H
2804 3634      LD      (HL),34H
2806 35        DEC     (HL)
2807 C9        RET     

2808 FD210062  LD      IY,marioAlive
280c 3A0562    LD      A,(marioY)
280f 4F        LD      C,A
2810 210704    LD      HL,0407H
2813 CD6F28    CALL    286FH
2816 A7        AND     A
2817 C8        RET     Z

2818 3D        DEC     A
2819 320062    LD      (marioAlive),A
281c C9        RET     

281d 0602      LD      B,02H
281f 111000    LD      DE,0010H
2822 FD218066  LD      IY,6680H
2826 FDCB0146  BIT     0,(IY+01H)
282a C23228    JP      NZ,2832H
282d FD19      ADD     IY,DE
282f 10F5      DJNZ    2826H
2831 C9        RET     

2832 FD4E05    LD      C,(IY+05H)
2835 FD6609    LD      H,(IY+09H)
2838 FD6E0A    LD      L,(IY+0AH)
283b CD6F28    CALL    286FH
283e A7        AND     A
283f C8        RET     Z

2840 325063    LD      (smashSequenceActive),A
2843 3AB963    LD      A,(63B9H)
2846 90        SUB     B
2847 325463    LD      (indexOfSmashedSprite),A
284a 7B        LD      A,E
284b 325363    LD      (6353H),A
284e DD225163  LD      (6351H),IX
2852 C9        RET     

2853 FD210062  LD      IY,marioAlive
2857 3A0562    LD      A,(marioY)
285a C60C      ADD     A,0CH
285c 4F        LD      C,A
285d 3A1060    LD      A,(playerInput)
2860 E603      AND     03H
2862 210805    LD      HL,0508H
2865 CA6B28    JP      Z,286BH
2868 210813    LD      HL,1308H
286b CD883E    CALL    3E88H
286e C9        RET     
;----------------------------------



;----------------------------------
; Jump based on currentStage
; passed: HL
286f 3A2762    LD      A,(currentStage)
2872 E5        PUSH    HL          ; Save Hl on the stack
2873 EF        RST     JumpToLocalTableAddress
2874 0000 ; 0 = reset game
2876 8028 ; 1 (barrels) = 2880H
2878 B028 ; 2 (pies) = 28B0H
287a E028 ; 3 (elevators) = 28E0H
287c 0129 ; 4 (rivets) = 2801H
287e 0000 ; 5 = reset game
;----------------------------------



;----------------------------------
2880 E1        POP     HL          ; Restore HL
2881 060A      LD      B,0AH       ; B = 10
2883 78        LD      A,B         ; 63B9H = 10
2884 32B963    LD      (63B9H),A   ;    ''
2887 112000    LD      DE,0020H    ; DE = 32
288a DD210067  LD      IX,6700H    ; IX = 6700H
288e CD1329    CALL    2913H
2891 0605      LD      B,05H
2893 78        LD      A,B
2894 32B963    LD      (63B9H),A
2897 1E20      LD      E,20H
2899 DD210064  LD      IX,6400H
289d CD1329    CALL    2913H
28a0 0601      LD      B,01H
28a2 78        LD      A,B
28a3 32B963    LD      (63B9H),A
28a6 1E00      LD      E,00H
28a8 DD21A066  LD      IX,66A0H
28ac CD1329    CALL    2913H
28af C9        RET     

28b0 E1        POP     HL
28b1 0605      LD      B,05H
28b3 78        LD      A,B
28b4 32B963    LD      (63B9H),A
28b7 112000    LD      DE,0020H
28ba DD210064  LD      IX,6400H
28be CD1329    CALL    2913H
28c1 0606      LD      B,06H
28c3 78        LD      A,B
28c4 32B963    LD      (63B9H),A
28c7 1E10      LD      E,10H
28c9 DD21A065  LD      IX,65A0H
28cd CD1329    CALL    2913H
28d0 0601      LD      B,01H
28d2 78        LD      A,B
28d3 32B963    LD      (63B9H),A
28d6 1E00      LD      E,00H
28d8 DD21A066  LD      IX,66A0H
28dc CD1329    CALL    2913H
28df C9        RET     

28e0 E1        POP     HL
28e1 0605      LD      B,05H
28e3 78        LD      A,B
28e4 32B963    LD      (63B9H),A
28e7 112000    LD      DE,0020H
28ea DD210064  LD      IX,6400H
28ee CD1329    CALL    2913H
28f1 060A      LD      B,0AH
28f3 78        LD      A,B
28f4 32B963    LD      (63B9H),A
28f7 1E10      LD      E,10H
28f9 DD210065  LD      IX,6500H
28fd CD1329    CALL    2913H
2900 C9        RET     

2901 E1        POP     HL
2902 0607      LD      B,07H
2904 78        LD      A,B
2905 32B963    LD      (63B9H),A
2908 112000    LD      DE,0020H
290b DD210064  LD      IX,6400H
290f CD1329    CALL    2913H
2912 C9        RET     


;----------------------------------
; passed: IX, C, HL
2913 DDE5      PUSH    IX
2915 DDCB0046  BIT     0,(IX+00H)
2919 CA4C29    JP      Z,294CH

291c 79        LD      A,C
291d DD9605    SUB     (IX+05H)
2920 D22529    JP      NC,2925H
2923 ED44      NEG     
2925 3C        INC     A
2926 95        SUB     L
2927 DA3029    JP      C,2930H
292a DD960A    SUB     (IX+0AH)
292d D24C29    JP      NC,294CH
2930 FD7E03    LD      A,(IY+03H)
2933 DD9603    SUB     (IX+03H)
2936 D23B29    JP      NC,293BH
2939 ED44      NEG     
293b 94        SUB     H
293c DA4529    JP      C,2945H
293f DD9609    SUB     (IX+09H)
2942 D24C29    JP      NC,294CH
2945 3E01      LD      A,01H
2947 DDE1      POP     IX
2949 33        INC     SP
294a 33        INC     SP
294b C9        RET     

294c DD19      ADD     IX,DE
294e 10C5      DJNZ    2915H
2950 AF        XOR     A
2951 DDE1      POP     IX
2953 C9        RET     

2954 3E0B      LD      A,0BH
2956 F7        RST     ReturnUnlessStageOfInterest
2957 CD7429    CALL    2974H
295a 321862    LD      (6218H),A
295d 0F        RRCA    
295e 0F        RRCA    
295f 328560    LD      (6085H),A
2962 78        LD      A,B
2963 A7        AND     A
2964 C8        RET     Z

2965 FE01      CP      01H
2967 CA6F29    JP      Z,296FH
296a DD360101  LD      (IX+01H),01H
296e C9        RET     

296f DD361101  LD      (IX+11H),01H
2973 C9        RET     

2974 FD210062  LD      IY,marioAlive
2978 3A0562    LD      A,(marioY)
297b 4F        LD      C,A
297c 210804    LD      HL,0408H
297f 0602      LD      B,02H
2981 111000    LD      DE,0010H
2984 DD218066  LD      IX,6680H
2988 CD1329    CALL    2913H
298b C9        RET     

298c 2AC863    LD      HL,(63C8H)
298f 7D        LD      A,L
2990 C60E      ADD     A,0EH
2992 6F        LD      L,A
2993 56        LD      D,(HL)
2994 2C        INC     L
2995 7E        LD      A,(HL)
2996 C60C      ADD     A,0CH
2998 5F        LD      E,A
2999 EB        EX      DE,HL
299a CDF02F    CALL    2FF0H
299d 7E        LD      A,(HL)
299e FEB0      CP      B0H
29a0 DAAC29    JP      C,29ACH
29a3 E60F      AND     0FH
29a5 FE08      CP      08H
29a7 D2AC29    JP      NC,29ACH
29aa AF        XOR     A
29ab C9        RET     

29ac 3E01      LD      A,01H
29ae C9        RET     

29af 3E04      LD      A,04H
29b1 F7        RST     ReturnUnlessStageOfInterest
29b2 FD210062  LD      IY,marioAlive
29b6 3A0562    LD      A,(marioY)
29b9 4F        LD      C,A
29ba 210804    LD      HL,0408H
29bd CD222A    CALL    2A22H
29c0 A7        AND     A
29c1 CA202A    JP      Z,2A20H
29c4 3E06      LD      A,06H
29c6 90        SUB     B
29c7 CAD029    JP      Z,29D0H
29ca DD19      ADD     IX,DE
29cc 3D        DEC     A
29cd C3C729    JP      29C7H
29d0 DD7E05    LD      A,(IX+05H)
29d3 D604      SUB     04H
29d5 57        LD      D,A
29d6 3A0C62    LD      A,(620CH)
29d9 C605      ADD     A,05H
29db BA        CP      D
29dc D2EE29    JP      NC,29EEH
29df 7A        LD      A,D
29e0 D608      SUB     08H
29e2 320562    LD      (marioY),A
29e5 3E01      LD      A,01H
29e7 47        LD      B,A
29e8 329863    LD      (6398H),A
29eb 33        INC     SP
29ec 33        INC     SP
29ed C9        RET     

29ee 3A0C62    LD      A,(620CH)
29f1 D60E      SUB     0EH
29f3 BA        CP      D
29f4 D21B2A    JP      NC,2A1BH
29f7 3A1062    LD      A,(6210H)
29fa A7        AND     A
29fb 3A0362    LD      A,(marioX)
29fe CA082A    JP      Z,2A08H
2a01 F607      OR      07H
2a03 D604      SUB     04H
2a05 C30E2A    JP      2A0EH
2a08 D608      SUB     08H
2a0a F607      OR      07H
2a0c C604      ADD     A,04H
2a0e 320362    LD      (marioX),A
2a11 324C69    LD      (marioSpriteX),A
2a14 3E01      LD      A,01H
2a16 0600      LD      B,00H
2a18 33        INC     SP
2a19 33        INC     SP
2a1a C9        RET     

2a1b AF        XOR     A
2a1c 320062    LD      (marioAlive),A
2a1f C9        RET     

2a20 47        LD      B,A
2a21 C9        RET     

2a22 0606      LD      B,06H
2a24 111000    LD      DE,0010H
2a27 DD210066  LD      IX,6600H
2a2b CD1329    CALL    2913H
2a2e C9        RET     

2a2f DD7E03    LD      A,(IX+03H)
2a32 67        LD      H,A
2a33 DD7E05    LD      A,(IX+05H)
2a36 C604      ADD     A,04H
2a38 6F        LD      L,A
2a39 E5        PUSH    HL
2a3a CDF02F    CALL    2FF0H
2a3d D1        POP     DE
2a3e 7E        LD      A,(HL)
2a3f FEB0      CP      B0H
2a41 DA7B2A    JP      C,2A7BH
2a44 E60F      AND     0FH
2a46 FE08      CP      08H
2a48 D27B2A    JP      NC,2A7BH
2a4b 7E        LD      A,(HL)
2a4c FEC0      CP      C0H
2a4e CA7B2A    JP      Z,2A7BH
2a51 DA692A    JP      C,2A69H
2a54 FED0      CP      D0H
2a56 DA6E2A    JP      C,2A6EH
2a59 FEE0      CP      E0H
2a5b DA632A    JP      C,2A63H
2a5e FEF0      CP      F0H
2a60 DA6E2A    JP      C,2A6EH
2a63 E60F      AND     0FH
2a65 3D        DEC     A
2a66 C3722A    JP      2A72H
2a69 3EFF      LD      A,FFH
2a6b C3722A    JP      2A72H
2a6e E60F      AND     0FH
2a70 D609      SUB     09H
2a72 4F        LD      C,A
2a73 7B        LD      A,E
2a74 E6F8      AND     F8H
2a76 81        ADD     A,C
2a77 BB        CP      E
2a78 DA7D2A    JP      C,2A7DH
2a7b AF        XOR     A
2a7c C9        RET     

2a7d D604      SUB     04H
2a7f DD7705    LD      (IX+05H),A
2a82 3E01      LD      A,01H
2a84 C9        RET     

2a85 3A1562    LD      A,(climbing)
2a88 A7        AND     A
2a89 C0        RET     NZ

2a8a 3A1662    LD      A,(6216H)
2a8d A7        AND     A
2a8e C0        RET     NZ

2a8f 3A9863    LD      A,(6398H)
2a92 FE01      CP      01H
2a94 C8        RET     Z

2a95 3A0362    LD      A,(marioX)
2a98 D603      SUB     03H
2a9a 67        LD      H,A
2a9b 3A0562    LD      A,(marioY)
2a9e C60C      ADD     A,0CH
2aa0 6F        LD      L,A
2aa1 E5        PUSH    HL
2aa2 CDF02F    CALL    2FF0H
2aa5 D1        POP     DE
2aa6 7E        LD      A,(HL)
2aa7 FEB0      CP      B0H
2aa9 DAB42A    JP      C,2AB4H
2aac E60F      AND     0FH
2aae FE08      CP      08H
2ab0 D2B42A    JP      NC,2AB4H
2ab3 C9        RET     

2ab4 7A        LD      A,D
2ab5 E607      AND     07H
2ab7 CACD2A    JP      Z,2ACDH
2aba 012000    LD      BC,0020H
2abd ED42      SBC     HL,BC
2abf 7E        LD      A,(HL)
2ac0 FEB0      CP      B0H
2ac2 DACD2A    JP      C,2ACDH
2ac5 E60F      AND     0FH
2ac7 FE08      CP      08H
2ac9 D2CD2A    JP      NC,2ACDH
2acc C9        RET     

2acd 3E01      LD      A,01H
2acf 322162    LD      (6221H),A
2ad2 C9        RET     
;----------------------------------



;----------------------------------
ConveyMario:
2ad3 3A0362    LD      A,(marioX)  ; B = mario's X coord
2ad6 47        LD      B,A         ;    ''
2ad7 3A0562    LD      A,(marioY) ; If (marioY) == 80 (top conveyer belt level)
2ada FE50      CP      50H         ;    load conveyer 1's offset
2adc CAEA2A    JP      Z,LoadConveyer1Offset: ;    ''

2adf FE78      CP      78H         ; If (marioY) == 120 (middle conveyer belts level)
2ae1 CAF62A    JP      Z,LoadConveyer2Offset ;    load conveyer 2's offset

2ae4 FEC8      CP      C8H         ; If (marioY) == 200 (bottom conveyer belt level)
2ae6 CAF02A    JP      Z,LoadConveyer3Offset ;    load conveyer 3's offset

2ae9 C9        RET                 ; Return if Mario is not on a conveyer

LoadConveyer1Offset:
2aea 3AA363    LD      A,(conveyer1Offset) ; A = conveyer1Offset
2aed C3022B    JP      MoveMarioAlongConveyer

LoadConveyer3Offset:
2af0 3AA663    LD      A,(conveyer3Offset)
2af3 C3022B    JP      MoveMarioAlongConveyer

LoadConveyer2Offset:
2af6 78        LD      A,B         ; A = marioX
2af7 FE80      CP      80H         ; If mario is on the left conveyer
2af9 3AA563    LD      A,(conveyer2LOffset) ;   load left conveyer offset
2afc D2022B    JP      NC,MoveMarioAlongConveyer ;    ''
2aff 3AA463    LD      A,(conveyer2ROffset) ;    else load right conveyer offset

MoveMarioAlongConveyer:
2b02 80        ADD     A,B         ; marioX += offset
2b03 320362    LD      (marioX),A  ;    ''
2b06 324C69    LD      (marioSpriteX),A   ; (marioSpriteX) = new marioX
2b09 CD1F24    CALL    CheckForBarriers
2b0c 210362    LD      HL,marioX   ; HL = address of marioX
2b0f 1D        DEC     E           ; If Mario can't move right
2b10 CA182B    JP      Z,MoveMarioBackLeft ;    jump ahead
2b13 15        DEC     D           ; If Mario can't move left
2b14 CA1A2B    JP      Z,MoveMarioBackRight ;    jump ahead
2b17 C9        RET     

MoveMarioBackLeft:
2b18 35        DEC     (HL)        ; Move Mario back 1 pixel left
2b19 C9        RET                 

MoveMarioBackRight:
2b1a 34        INC     (HL)        ; Move Mario back 1 pixel right     
2b1b C9        RET     
;----------------------------------



;----------------------------------
2b1c DD210062  LD      IX,marioAlive
2b20 CD292B    CALL    2B29H
2b23 CDAF29    CALL    29AFH
2b26 AF        XOR     A
2b27 47        LD      B,A
2b28 C9        RET     

2b29 3A2762    LD      A,(currentStage)
2b2c 3D        DEC     A
2b2d C2532B    JP      NZ,2B53H
2b30 3A0362    LD      A,(marioX)
2b33 67        LD      H,A
2b34 3A0562    LD      A,(marioY)
2b37 C607      ADD     A,07H
2b39 6F        LD      L,A
2b3a CD9B2B    CALL    2B9BH
2b3d A7        AND     A
2b3e CA512B    JP      Z,2B51H
2b41 7B        LD      A,E
2b42 91        SUB     C
2b43 FE04      CP      04H
2b45 D2742B    JP      NC,2B74H
2b48 79        LD      A,C
2b49 D607      SUB     07H
2b4b 320562    LD      (marioY),A
2b4e 3E01      LD      A,01H
2b50 47        LD      B,A
2b51 E1        POP     HL
2b52 C9        RET     

2b53 3A0362    LD      A,(marioX)
2b56 D603      SUB     03H
2b58 67        LD      H,A
2b59 3A0562    LD      A,(marioY)
2b5c C607      ADD     A,07H
2b5e 6F        LD      L,A
2b5f CD9B2B    CALL    2B9BH
2b62 FE02      CP      02H
2b64 CA7A2B    JP      Z,2B7AH
2b67 7A        LD      A,D
2b68 C607      ADD     A,07H
2b6a 67        LD      H,A
2b6b 6B        LD      L,E
2b6c CD9B2B    CALL    2B9BH
2b6f A7        AND     A
2b70 C8        RET     Z

2b71 C37A2B    JP      2B7AH
2b74 3E00      LD      A,00H
2b76 0600      LD      B,00H
2b78 E1        POP     HL
2b79 C9        RET     

2b7a 3A1062    LD      A,(6210H)
2b7d A7        AND     A
2b7e 3A0362    LD      A,(marioX)
2b81 CA8B2B    JP      Z,2B8BH
2b84 F607      OR      07H
2b86 D604      SUB     04H
2b88 C3912B    JP      2B91H
2b8b D608      SUB     08H
2b8d F607      OR      07H
2b8f C604      ADD     A,04H
2b91 320362    LD      (marioX),A
2b94 324C69    LD      (marioSpriteX),A
2b97 3E01      LD      A,01H
2b99 E1        POP     HL
2b9a C9        RET     

2b9b E5        PUSH    HL
2b9c CDF02F    CALL    2FF0H
2b9f D1        POP     DE
2ba0 7E        LD      A,(HL)
2ba1 FEB0      CP      B0H
2ba3 DAD92B    JP      C,2BD9H
2ba6 E60F      AND     0FH
2ba8 FE08      CP      08H
2baa D2D92B    JP      NC,2BD9H
2bad 7E        LD      A,(HL)
2bae FEC0      CP      C0H
2bb0 CAD92B    JP      Z,2BD9H
2bb3 DADC2B    JP      C,2BDCH
2bb6 FED0      CP      D0H
2bb8 DACB2B    JP      C,2BCBH
2bbb FEE0      CP      E0H
2bbd DAC52B    JP      C,2BC5H
2bc0 FEF0      CP      F0H
2bc2 DACB2B    JP      C,2BCBH
2bc5 E60F      AND     0FH
2bc7 3D        DEC     A
2bc8 C3CF2B    JP      2BCFH
2bcb E60F      AND     0FH
2bcd D609      SUB     09H
2bcf 4F        LD      C,A
2bd0 7B        LD      A,E
2bd1 E6F8      AND     F8H
2bd3 81        ADD     A,C
2bd4 4F        LD      C,A
2bd5 BB        CP      E
2bd6 DAE12B    JP      C,2BE1H
2bd9 AF        XOR     A
2bda 47        LD      B,A
2bdb C9        RET     

2bdc 7B        LD      A,E
2bdd E6F8      AND     F8H
2bdf 3D        DEC     A
2be0 4F        LD      C,A
2be1 3A0C62    LD      A,(620CH)
2be4 DD9605    SUB     (IX+05H)
2be7 83        ADD     A,E
2be8 B9        CP      C
2be9 CAEF2B    JP      Z,2BEFH
2bec D2F82B    JP      NC,2BF8H
2bef 79        LD      A,C
2bf0 D607      SUB     07H
2bf2 320562    LD      (marioY),A
2bf5 C3FD2B    JP      2BFDH
2bf8 3E02      LD      A,02H
2bfa 0600      LD      B,00H
2bfc C9        RET     

2bfd 3E01      LD      A,01H
2bff 47        LD      B,A
2c00 E1        POP     HL
2c01 E1        POP     HL
2c02 C9        RET     

2c03 3E01      LD      A,01H
2c05 F7        RST     ReturnUnlessStageOfInterest
2c06 D7        ReturnIfMarioDead
2c07 3A9363    LD      A,(6393H)
2c0a 0F        RRCA    
2c0b D8        RET     C

2c0c 3AB162    LD      A,(62B1H)
2c0f A7        AND     A
2c10 C8        RET     Z

2c11 4F        LD      C,A
2c12 3AB062    LD      A,(62B0H)
2c15 D602      SUB     02H
2c17 B9        CP      C
2c18 DA7B2C    JP      C,2C7BH
2c1b 3A8263    LD      A,(6382H)
2c1e CB4F      BIT     1,A
2c20 C2862C    JP      NZ,2C86H
2c23 3A8063    LD      A,(6380H)
2c26 47        LD      B,A
2c27 3A1A60    LD      A,(counter1)
2c2a E61F      AND     1FH
2c2c B8        CP      B
2c2d CA332C    JP      Z,2C33H
2c30 10FA      DJNZ    2C2CH
2c32 C9        RET     

2c33 3AB062    LD      A,(62B0H)
2c36 CB3F      SRL     A
2c38 B9        CP      C
2c39 DA412C    JP      C,2C41H
2c3c 3A1960    LD      A,(6019H)
2c3f 0F        RRCA    
2c40 D0        RET     NC

2c41 CD5700    CALL    UpdateRandomNumber      ; Update the game's random number
2c44 E60F      AND     0FH
2c46 C2862C    JP      NZ,2C86H
2c49 3E01      LD      A,01H
2c4b 328263    LD      (6382H),A
2c4e 3C        INC     A
2c4f 328F63    LD      (638FH),A
2c52 3E01      LD      A,01H
2c54 329263    LD      (6392H),A
2c57 3AB262    LD      A,(62B2H)
2c5a B9        CP      C
2c5b C0        RET     NZ

2c5c D608      SUB     08H
2c5e 32B262    LD      (62B2H),A
2c61 112000    LD      DE,0020H
2c64 210064    LD      HL,6400H
2c67 0605      LD      B,05H
2c69 7E        LD      A,(HL)
2c6a A7        AND     A
2c6b CA722C    JP      Z,2C72H
2c6e 19        ADD     HL,DE
2c6f 10F8      DJNZ    2C69H
2c71 C9        RET     

2c72 3A8263    LD      A,(6382H)
2c75 F680      OR      80H
2c77 328263    LD      (6382H),A
2c7a C9        RET     

2c7b C602      ADD     A,02H
2c7d B9        CP      C
2c7e CA492C    JP      Z,2C49H
2c81 3E02      LD      A,02H
2c83 C34B2C    JP      2C4BH
2c86 AF        XOR     A
2c87 328263    LD      (6382H),A
2c8a 3E03      LD      A,03H
2c8c C34F2C    JP      2C4FH
2c8f 3E01      LD      A,01H
2c91 F7        RST     ReturnUnlessStageOfInterest
2c92 D7        ReturnIfMarioDead
2c93 3A9363    LD      A,(6393H)
2c96 0F        RRCA    
2c97 DA152D    JP      C,2D15H
2c9a 3A9263    LD      A,(6392H)
2c9d 0F        RRCA    
2c9e D0        RET     NC

2c9f DD210067  LD      IX,6700H
2ca3 112000    LD      DE,0020H
2ca6 060A      LD      B,0AH
2ca8 DD7E00    LD      A,(IX+00H)
2cab 0F        RRCA    
2cac DAB32C    JP      C,2CB3H
2caf 0F        RRCA    
2cb0 D2B82C    JP      NC,2CB8H
2cb3 DD19      ADD     IX,DE
2cb5 10F1      DJNZ    2CA8H
2cb7 C9        RET     

2cb8 DD22AA62  LD      (62AAH),IX
2cbc DD360002  LD      (IX+00H),02H
2cc0 1600      LD      D,00H
2cc2 3E0A      LD      A,0AH
2cc4 90        SUB     B
2cc5 87        ADD     A,A
2cc6 87        ADD     A,A
2cc7 5F        LD      E,A
2cc8 218069    LD      HL,6980H
2ccb 19        ADD     HL,DE
2ccc 22AC62    LD      (62ACH),HL
2ccf 3E01      LD      A,01H
2cd1 329363    LD      (6393H),A
2cd4 110105    LD      DE,0501H
2cd7 CD9F30    CALL    AddFunctionToUpdateList
2cda 21B162    LD      HL,62B1H
2cdd 35        DEC     (HL)
2cde C2E62C    JP      NZ,2CE6H
2ce1 3E01      LD      A,01H
2ce3 328663    LD      (6386H),A
2ce6 7E        LD      A,(HL)
2ce7 FE04      CP      04H
2ce9 D2F62C    JP      NC,2CF6H
2cec 21A869    LD      HL,69A8H
2cef 87        ADD     A,A
2cf0 87        ADD     A,A
2cf1 5F        LD      E,A
2cf2 1600      LD      D,00H
2cf4 19        ADD     HL,DE
2cf5 72        LD      (HL),D
2cf6 DD360715  LD      (IX+07H),15H
2cfa DD36080B  LD      (IX+08H),0BH
2cfe DD361500  LD      (IX+15H),00H
2d02 3A8263    LD      A,(6382H)
2d05 07        RLCA    
2d06 D2152D    JP      NC,2D15H
2d09 DD360719  LD      (IX+07H),19H
2d0d DD36080C  LD      (IX+08H),0CH
2d11 DD361501  LD      (IX+15H),01H
2d15 21AF62    LD      HL,62AFH
2d18 35        DEC     (HL)
2d19 C0        RET     NZ

2d1a 3618      LD      (HL),18H
2d1c 3A8F63    LD      A,(638FH)
2d1f A7        AND     A
2d20 CA512D    JP      Z,2D51H
2d23 4F        LD      C,A
2d24 213239    LD      HL,3932H
2d27 3A8263    LD      A,(6382H)
2d2a 0F        RRCA    
2d2b DA2F2D    JP      C,2D2FH
2d2e 0D        DEC     C
2d2f 79        LD      A,C
2d30 87        ADD     A,A
2d31 87        ADD     A,A
2d32 87        ADD     A,A
2d33 4F        LD      C,A
2d34 87        ADD     A,A
2d35 87        ADD     A,A
2d36 81        ADD     A,C
2d37 5F        LD      E,A
2d38 1600      LD      D,00H
2d3a 19        ADD     HL,DE
2d3b CD4E00    CALL    LoadDKSprites
2d3e 218F63    LD      HL,638FH
2d41 35        DEC     (HL)
2d42 C2512D    JP      NZ,2D51H
2d45 3E01      LD      A,01H
2d47 32AF62    LD      (62AFH),A
2d4a 3A8263    LD      A,(6382H)
2d4d 0F        RRCA    
2d4e DA832D    JP      C,2D83H
2d51 2AA862    LD      HL,(62A8H)
2d54 7E        LD      A,(HL)
2d55 DD2AAA62  LD      IX,(62AAH)
2d59 ED5BAC62  LD      DE,(62ACH)
2d5d FE7F      CP      7FH
2d5f CA8C2D    JP      Z,2D8CH
2d62 4F        LD      C,A
2d63 E67F      AND     7FH
2d65 12        LD      (DE),A
2d66 DD7E07    LD      A,(IX+07H)
2d69 CB79      BIT     7,C
2d6b CA702D    JP      Z,2D70H
2d6e EE03      XOR     03H
2d70 13        INC     DE
2d71 12        LD      (DE),A
2d72 DD7707    LD      (IX+07H),A
2d75 DD7E08    LD      A,(IX+08H)
2d78 13        INC     DE
2d79 12        LD      (DE),A
2d7a 23        INC     HL
2d7b 7E        LD      A,(HL)
2d7c 13        INC     DE
2d7d 12        LD      (DE),A
2d7e 23        INC     HL
2d7f 22A862    LD      (62A8H),HL
2d82 C9        RET     

2d83 21CC39    LD      HL,39CCH
2d86 22A862    LD      (62A8H),HL
2d89 C3542D    JP      2D54H
2d8c 21C339    LD      HL,39C3H
2d8f 22A862    LD      (62A8H),HL
2d92 DD360101  LD      (IX+01H),01H
2d96 3A8263    LD      A,(6382H)
2d99 0F        RRCA    
2d9a DAA52D    JP      C,2DA5H
2d9d DD360100  LD      (IX+01H),00H
2da1 DD360202  LD      (IX+02H),02H
2da5 DD360001  LD      (IX+00H),01H
2da9 DD360F01  LD      (IX+0FH),01H
2dad AF        XOR     A
2dae DD7710    LD      (IX+10H),A
2db1 DD7711    LD      (IX+11H),A
2db4 DD7712    LD      (IX+12H),A
2db7 DD7713    LD      (IX+13H),A
2dba DD7714    LD      (IX+14H),A
2dbd 329363    LD      (6393H),A
2dc0 329263    LD      (6392H),A
2dc3 1A        LD      A,(DE)
2dc4 DD7703    LD      (IX+03H),A
2dc7 13        INC     DE
2dc8 13        INC     DE
2dc9 13        INC     DE
2dca 1A        LD      A,(DE)
2dcb DD7705    LD      (IX+05H),A
2dce 215C38    LD      HL,DKLeftArmRaisedSpriteData
2dd1 CD4E00    CALL    LoadDKSprites
2dd4 210B69    LD      HL,dkSprite1Y
2dd7 0EFC      LD      C,FCH
2dd9 FF        RST     MoveDKSprites
2dda C9        RET     

2ddb 3E0A      LD      A,0AH
2ddd F7        RST     ReturnUnlessStageOfInterest
2dde D7        ReturnIfMarioDead
2ddf 3A8063    LD      A,(6380H)
2de2 3C        INC     A
2de3 A7        AND     A
2de4 1F        RRA     
2de5 47        LD      B,A
2de6 3A2762    LD      A,(currentStage)
2de9 FE02      CP      02H
2deb 2001      JR      NZ,2DEEH
2ded 04        INC     B
2dee 3EFE      LD      A,FEH
2df0 37        SCF     
2df1 1F        RRA     
2df2 A7        AND     A
2df3 10FC      DJNZ    2DF1H
2df5 47        LD      B,A
2df6 3A1A60    LD      A,(counter1)
2df9 A0        AND     B
2dfa C0        RET     NZ

2dfb 3E01      LD      A,01H
2dfd 32A063    LD      (63A0H),A
2e00 329A63    LD      (639AH),A
2e03 C9        RET     

2e04 3E04      LD      A,04H
2e06 F7        RST     ReturnUnlessStageOfInterest
2e07 D7        ReturnIfMarioDead
2e08 DD210065  LD      IX,6500H
2e0c FD218069  LD      IY,6980H
2e10 060A      LD      B,0AH
2e12 DD7E00    LD      A,(IX+00H)
2e15 0F        RRCA    
2e16 D2A72E    JP      NC,2EA7H
2e19 3A1A60    LD      A,(counter1)
2e1c E60F      AND     0FH
2e1e C2292E    JP      NZ,2E29H
2e21 FD7E01    LD      A,(IY+01H)
2e24 EE07      XOR     07H
2e26 FD7701    LD      (IY+01H),A
2e29 DD7E0D    LD      A,(IX+0DH)
2e2c FE04      CP      04H
2e2e CA842E    JP      Z,2E84H
2e31 DD3403    INC     (IX+03H)
2e34 DD3403    INC     (IX+03H)
2e37 DD6E0E    LD      L,(IX+0EH)
2e3a DD660F    LD      H,(IX+0FH)
2e3d 7E        LD      A,(HL)
2e3e 4F        LD      C,A
2e3f FE7F      CP      7FH
2e41 CA9C2E    JP      Z,2E9CH
2e44 23        INC     HL
2e45 DD8605    ADD     A,(IX+05H)
2e48 DD7705    LD      (IX+05H),A
2e4b DD750E    LD      (IX+0EH),L
2e4e DD740F    LD      (IX+0FH),H
2e51 DD7E03    LD      A,(IX+03H)
2e54 FEB7      CP      B7H
2e56 DA6C2E    JP      C,2E6CH
2e59 79        LD      A,C
2e5a FE7F      CP      7FH
2e5c C26C2E    JP      NZ,2E6CH
2e5f DD360D04  LD      (IX+0DH),04H
2e63 AF        XOR     A
2e64 328360    LD      (6083H),A
2e67 3E03      LD      A,03H
2e69 328460    LD      (6084H),A
2e6c DD7E03    LD      A,(IX+03H)
2e6f FD7700    LD      (IY+00H),A
2e72 DD7E05    LD      A,(IX+05H)
2e75 FD7703    LD      (IY+03H),A
2e78 111000    LD      DE,0010H
2e7b DD19      ADD     IX,DE
2e7d 1E04      LD      E,04H
2e7f FD19      ADD     IY,DE
2e81 108F      DJNZ    2E12H
2e83 C9        RET     

2e84 3E03      LD      A,03H
2e86 DD8605    ADD     A,(IX+05H)
2e89 DD7705    LD      (IX+05H),A
2e8c FEF8      CP      F8H
2e8e DA6C2E    JP      C,2E6CH
2e91 DD360300  LD      (IX+03H),00H
2e95 DD360000  LD      (IX+00H),00H
2e99 C36C2E    JP      2E6CH
2e9c 21AA39    LD      HL,39AAH
2e9f 3E03      LD      A,03H
2ea1 328360    LD      (6083H),A
2ea4 C34B2E    JP      2E4BH
2ea7 3A9663    LD      A,(6396H)
2eaa 0F        RRCA    
2eab D2782E    JP      NC,2E78H
2eae AF        XOR     A
2eaf 329663    LD      (6396H),A
2eb2 DD360550  LD      (IX+05H),50H
2eb6 DD360D01  LD      (IX+0DH),01H
2eba CD5700    CALL    UpdateRandomNumber      ; Update the game's random number
2ebd E60F      AND     0FH
2ebf C6F8      ADD     A,F8H
2ec1 DD7703    LD      (IX+03H),A
2ec4 DD360001  LD      (IX+00H),01H
2ec8 21AA39    LD      HL,39AAH
2ecb DD750E    LD      (IX+0EH),L
2ece DD740F    LD      (IX+0FH),H
2ed1 C3782E    JP      2E78H
2ed4 3E0B      LD      A,0BH
2ed6 F7        RST     ReturnUnlessStageOfInterest
2ed7 D7        ReturnIfMarioDead
2ed8 11186A    LD      DE,6A18H
2edb DD218066  LD      IX,6680H
2edf DD7E01    LD      A,(IX+01H)
2ee2 0F        RRCA    
2ee3 DAED2E    JP      C,2EEDH
2ee6 111C6A    LD      DE,6A1CH
2ee9 DD219066  LD      IX,6690H
2eed DD360E00  LD      (IX+0EH),00H
2ef1 DD360FF0  LD      (IX+0FH),F0H
2ef5 3A1762    LD      A,(6217H)
2ef8 0F        RRCA    
2ef9 D2972F    JP      NC,2F97H
2efc AF        XOR     A
2efd 321862    LD      (6218H),A
2f00 218960    LD      HL,6089H
2f03 3604      LD      (HL),04H
2f05 DD360906  LD      (IX+09H),06H
2f09 DD360A03  LD      (IX+0AH),03H
2f0d 061E      LD      B,1EH
2f0f 3A0762    LD      A,(marioSpriteNum1)
2f12 CB27      SLA     A
2f14 D21B2F    JP      NC,2F1BH
2f17 F680      OR      80H
2f19 CBF8      SET     7,B
2f1b F608      OR      08H
2f1d 4F        LD      C,A
2f1e 3A9463    LD      A,(6394H)
2f21 CB5F      BIT     3,A
2f23 CA432F    JP      Z,2F43H
2f26 CBC0      SET     0,B
2f28 CBC1      SET     0,C
2f2a DD360905  LD      (IX+09H),05H
2f2e DD360A06  LD      (IX+0AH),06H
2f32 DD360F00  LD      (IX+0FH),00H
2f36 DD360EF0  LD      (IX+0EH),F0H
2f3a CB79      BIT     7,C
2f3c CA432F    JP      Z,2F43H
2f3f DD360E10  LD      (IX+0EH),10H
2f43 79        LD      A,C
2f44 324D69    LD      (marioSpriteNum),A
2f47 0E07      LD      C,07H
2f49 219463    LD      HL,6394H
2f4c 34        INC     (HL)
2f4d C2B72F    JP      NZ,2FB7H
2f50 219563    LD      HL,6395H
2f53 34        INC     (HL)
2f54 7E        LD      A,(HL)
2f55 FE02      CP      02H
2f57 C2BE2F    JP      NZ,2FBEH
2f5a AF        XOR     A
2f5b 329563    LD      (6395H),A
2f5e 321762    LD      (6217H),A
2f61 DD7701    LD      (IX+01H),A
2f64 3A0362    LD      A,(marioX)
2f67 ED44      NEG     
2f69 DD770E    LD      (IX+0EH),A
2f6c 3A0762    LD      A,(marioSpriteNum1)
2f6f 324D69    LD      (marioSpriteNum),A
2f72 DD360000  LD      (IX+00H),00H
2f76 3A8963    LD      A,(6389H)
2f79 328960    LD      (6089H),A
2f7c EB        EX      DE,HL
2f7d 3A0362    LD      A,(marioX)
2f80 DD860E    ADD     A,(IX+0EH)
2f83 77        LD      (HL),A
2f84 DD7703    LD      (IX+03H),A
2f87 23        INC     HL
2f88 70        LD      (HL),B
2f89 23        INC     HL
2f8a 71        LD      (HL),C
2f8b 23        INC     HL
2f8c 3A0562    LD      A,(marioY)
2f8f DD860F    ADD     A,(IX+0FH)
2f92 77        LD      (HL),A
2f93 DD7705    LD      (IX+05H),A
2f96 C9        RET     

2f97 3A1862    LD      A,(6218H)
2f9a 0F        RRCA    
2f9b D0        RET     NC

2f9c DD360906  LD      (IX+09H),06H
2fa0 DD360A03  LD      (IX+0AH),03H
2fa4 3A0762    LD      A,(marioSpriteNum1)
2fa7 07        RLCA    
2fa8 3E3C      LD      A,3CH
2faa 1F        RRA     
2fab 47        LD      B,A
2fac 0E07      LD      C,07H
2fae 3A8960    LD      A,(6089H)
2fb1 328963    LD      (6389H),A
2fb4 C37C2F    JP      2F7CH
2fb7 3A9563    LD      A,(6395H)
2fba A7        AND     A
2fbb CA7C2F    JP      Z,2F7CH
2fbe 3A1A60    LD      A,(counter1)
2fc1 CB5F      BIT     3,A
2fc3 CA7C2F    JP      Z,2F7CH
2fc6 0E01      LD      C,01H
2fc8 C37C2F    JP      2F7CH
2fcb 3E0E      LD      A,0EH
2fcd F7        RST     ReturnUnlessStageOfInterest
2fce 21B462    LD      HL,62B4H
2fd1 35        DEC     (HL)
2fd2 C0        RET     NZ

2fd3 3E03      LD      A,03H
2fd5 32B962    LD      (OilBarrelFireState),A
2fd8 329663    LD      (6396H),A
2fdb 110105    LD      DE,0501H
2fde CD9F30    CALL    AddFunctionToUpdateList
2fe1 3AB362    LD      A,(62B3H)
2fe4 77        LD      (HL),A
2fe5 21B162    LD      HL,62B1H
2fe8 35        DEC     (HL)
2fe9 C0        RET     NZ

2fea 3E01      LD      A,01H
2fec 328663    LD      (6386H),A
2fef C9        RET     



;----------------------------------
; passed: HL
; 9738
2ff0 7D        LD      A,L         ; A = L (38H)
2ff1 0F        RRCA                ; Discard 3 LSBs
2ff2 0F        RRCA                ;    ''
2ff3 0F        RRCA                ;    ''
2ff4 E61F      AND     1FH         ;    ''
2ff6 6F        LD      L,A         ; L = A (7H)
2ff7 7C        LD      A,H         ; A = !H (97H)
2ff8 2F        CPL                 ;    ''  (68H)
2ff9 E6F8      AND     F8H         ; Discard 3 LSBs (68H)
2ffb 5F        LD      E,A         ; E = !H (68H)
2ffc AF        XOR     A           ; A = 0
2ffd 67        LD      H,A         ; H = 0
2ffe CB13      RL      E
3000 17        RLA     
3001 CB13      RL      E
3003 17        RLA     
3004 C674      ADD     A,74H
3006 57        LD      D,A
3007 19        ADD     HL,DE
3008 C9        RET     
;----------------------------------



;----------------------------------
; passed: A
3009 57        LD      D,A         ; D = A
300a 0F        RRCA                ; If bit 0 of A == 1
300b DA2230    JP      C,3022H     ;    jump ahead

300e 0E93      LD      C,93H       ; C = 147
3010 0F        RRCA                ; If bit 2 of A == 1
3011 0F        RRCA                ;    jump ahead
3012 D21730    JP      NC,3017H
3015 0E6C      LD      C,6CH
3017 07        RLCA    
3018 DA3130    JP      C,3031H
301b 79        LD      A,C
301c E6F0      AND     F0H
301e 4F        LD      C,A
301f C33130    JP      3031H
3022 0EB4      LD      C,B4H
3024 0F        RRCA    
3025 0F        RRCA    
3026 D22B30    JP      NC,302BH
3029 0E1E      LD      C,1EH
302b CB50      BIT     2,B
302d CA3130    JP      Z,3031H
3030 05        DEC     B
3031 79        LD      A,C
3032 0F        RRCA    
3033 0F        RRCA    
3034 4F        LD      C,A
3035 E603      AND     03H
3037 B8        CP      B
3038 C23130    JP      NZ,3031H
303b 79        LD      A,C
303c 0F        RRCA    
303d 0F        RRCA    
303e E603      AND     03H
3040 FE03      CP      03H
3042 C0        RET     NZ

3043 CB92      RES     2,D
3045 15        DEC     D
3046 C0        RET     NZ

3047 3E04      LD      A,04H
3049 C9        RET     



;----------------------------------
; Animates drawing the ladders up
; after DK
DrawUpLadders:
304a 11E0FF    LD      DE,FFE0H    ; DE = -32
304d 3A8E63    LD      A,(ladderEraseRow) ; A = ladderEraseRow
3050 4F        LD      C,A         ; BC = ladderEraseRow (31)
3051 0600      LD      B,00H       ;    ''
3053 210076    LD      HL,7600H    ; HL = (16,0) (1 col left of the left ladder)
3056 CD6430    CALL    EraseLadderTile
3059 21C075    LD      HL,75C0H    ; HL = (14,0) (1 col left of the right ladder)
305c CD6430    CALL    EraseLadderTile
305f 218E63    LD      HL,ladderEraseRow ; --ladderEraseRow
3062 35        DEC     (HL)        ;    (prepare to erase the net row up)
3063 C9        RET                 ; Done
;----------------------------------

 

;----------------------------------
; Erase a ladder tile by overwriting
; it with the tile to its left
; passed: column coord in HL
;         row offset in BC
;         -32 in DE
EraseLadderTile:
3064 09        ADD     HL,BC       ; HL (7600) += ladderEraseRow
3065 7E        LD      A,(HL)      ; A = char at coord in (HL)
3066 19        ADD     HL,DE       ; HL = 1 row to the right
3067 77        LD      (HL),A      ; Copy char to (HL)
3068 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Increments the current mode when
; minorTimer reaches 0
PauseBeforeNextMode:
3069 DF        RST     ReturnIfNotMinorTimeout         ; Return if minorTimer has not run out
306a 2AC063    LD      HL,(pCurrentMode) ; HL = address of current mode
306d 34        INC     (HL)        ; Increment current mode
306e C9        RET                 ; Done
;----------------------------------



;----------------------------------
; Animate Donkey Kong climbing up 
; ladders
AnimateDKClimbing:
306f 21AF62    LD      HL,climbDelay ; HL = address of climbDelay
3072 34        INC     (HL)        ; climbDelay++
3073 7E        LD      A,(HL)      ; A = climbDelay
3074 E607      AND     07H         ; Isolate 3 LSBs
3076 C0        RET     NZ          ; Continue once every 8 calls

3077 210B69    LD      HL,dkSprite1Y ; HL = address of dkSprite1Y
307a 0EFC      LD      C,FCH       ; C = FCH
307c FF        RST     MoveDKSprites ; Move DK up 4 pixels
307d 0E81      LD      C,81H       ; C = 81H
307f 210969    LD      HL,dkSprite1Num ; HL = address of the first sprite in DK
3082 CD9630    CALL    AlternateSprites ; Switch sprites for left/right arms
3085 211D69    LD      HL,dkSprite6Num ; HL = address of the sixth sprite in DK
3088 CD9630    CALL    AlternateSprites ; Switch leg sprites
308b CD5700    CALL    UpdateRandomNumber ; A = random number
308e E680      AND     80H         ; A = 00H or 80H
3090 212D69    LD      HL,692DH    ; (692DH) = 00H or 80H
3093 AE        XOR     (HL)        ; Randomly flip Pauline's legs sprite
3094 77        LD      (HL),A      ;    ''
3095 C9        RET                 ; Done
;----------------------------------



;----------------------------------
; XORs the variable pointed to in 
; HL and HL + DE with the value in 
; C
;
; passed: C
;         address in HL
;         DE = 4
; return: HL + 2*DE
AlternateSprites:
3096 0602      LD      B,02H      ; B = 2 to 1
3098 79        LD      A,C        ; A = C
3099 AE        XOR     (HL)       ; A = A XOR C
309a 77        LD      (HL),A     ; (HL) = A XOR C
309b 19        ADD     HL,DE      ; HL = next address
309c 10FA      DJNZ    3098H      ; Next B
309e C9        RET                ; Done
;----------------------------------



;---------------------------------
; Prepares the selected function from the
; jump table to be called during the next
; update cycle.
; passed: D - the function entry number in
;             the jump table
;         E - the argument to pass to the
;             function (in A)
AddFunctionToUpdateList:
309f E5        PUSH    HL         ; Save HL
30a0 21C060    LD      HL,60C0H   ; HL = 60C0H
30a3 3AB060    LD      A,(writePtr1) ; Get location of write pointer (starting at 60C0H)
30a6 6F        LD      L,A        ; Address = writePtr1
30a7 CB7E      BIT     7,(HL)     ; Check bit 7 of 60Hxx
30a9 CABB30    JP      Z,30BBH    ; If bit 7 == 1
30ac 72        LD      (HL),D     ; Write D to 60Hxx
30ad 2C        INC     L          ; HL += 1
30ae 73        LD      (HL),E     ; Write E to 60Hxx + 1
30af 2C        INC     L          ; HL += 1
30b0 7D        LD      A,L        ; A = lower byte of HL
30b1 FEC0      CP      C0H        ; If A < C0H
30b3 D2B830    JP      NC,30B8H   ;    ''
30b6 3EC0      LD      A,C0H      ; A = C0H
30b8 32B060    LD      (writePtr1),A ; Record new write pointer
30bb E1        POP     HL         ; Restore HL
30bc C9        RET                ; Done
;---------------------------------



;----------------------------------
; Clear selected sprites
ClearSelectedSprites:
30bd 215069    LD      HL,6950H    ; Clear sprites at 6950H and 6954H
30c0 0602      LD      B,02H       ;    ''
30c2 CDE430    CALL    ClearNSprites ;    ''
30c5 2E80      LD      L,80H       ; Clear sprites from 6980H to 699FH
30c7 060A      LD      B,0AH       ;    ''
30c9 CDE430    CALL    ClearNSprites ;    ''
30cc 2EB8      LD      L,B8H       ; Clear sprites from 69B8H to 69E0H
30ce 060B      LD      B,0BH       ;    ''
30d0 CDE430    CALL    ClearNSprites ;    ''
30d3 210C6A    LD      HL,prizeSprite1X ; Clear prize sprites and
30d6 0605      LD      B,05H       ;    6A08H to 6A0CH
30d8 C3E430    JP      ClearNSprites ;    then return
;----------------------------------



;----------------------------------
; Clear Mario and other sprites
ClearMarioAndOtherSprites:
30db 214C69    LD      HL,marioSpriteX ; Clear Mario sprite
30de 3600      LD      (HL),00H    ;    ''
30e0 2E58      LD      L,58H       ; Clear 6958H to 696CH (6 sprites)
30e2 0606      LD      B,06H       ;    and then return
;----------------------------------



;----------------------------------
; Clear the specified number of
; sprites by setting their X coord
; to 0
; passed: HL = first sprite address
;         B = number of sprites to clear
ClearNSprites:
30e4 7D        LD      A,L         ; A = L
30e5 3600      LD      (HL),00H    ; Clear sprite's X coord
30e7 C604      ADD     A,04H       ; HL = address of next sprite
30e9 6F        LD      L,A         ;    ''
30ea 10F9      DJNZ    30E5H       ; Next B
30ec C9        RET     
;----------------------------------



;----------------------------------
30ed CDFA30    CALL    30FAH
30f0 CD3C31    CALL    313CH
30f3 CDB131    CALL    31B1H
30f6 CDF334    CALL    34F3H
30f9 C9        RET     

30fa 3A8063    LD      A,(6380H)
30fd FE06      CP      06H
30ff 3802      JR      C,3103H
3101 3E05      LD      A,05H
3103 EF        RST     JumpToLocalTableAddress
3104 1031 ; 3110h
3106 1031 ; 3110h
3108 1B31 ; 311bh
310a 2631 ; 3126h
310c 2631 ; 3126h
310e 3131 ; 3131h

3110 3A1A60    LD      A,(counter1)
3113 E601      AND     01H
3115 FE01      CP      01H
3117 C8        RET     Z

3118 33        INC     SP
3119 33        INC     SP
311a C9        RET     

311b 3A1A60    LD      A,(counter1)
311e E607      AND     07H
3120 FE05      CP      05H
3122 F8        RET     M

3123 33        INC     SP
3124 33        INC     SP
3125 C9        RET     

3126 3A1A60    LD      A,(counter1)
3129 E603      AND     03H
312b FE03      CP      03H
312d F8        RET     M

312e 33        INC     SP
312f 33        INC     SP
3130 C9        RET     

3131 3A1A60    LD      A,(counter1)
3134 E607      AND     07H
3136 FE07      CP      07H
3138 F8        RET     M

3139 33        INC     SP
313a 33        INC     SP
313b C9        RET     

313c DD210064  LD      IX,6400H
3140 AF        XOR     A
3141 32A163    LD      (63A1H),A
3144 0605      LD      B,05H
3146 112000    LD      DE,0020H
3149 DD7E00    LD      A,(IX+00H)
314c FE00      CP      00H
314e CA7C31    JP      Z,317CH
3151 3AA163    LD      A,(63A1H)
3154 3C        INC     A
3155 32A163    LD      (63A1H),A
3158 3E01      LD      A,01H
315a DD7708    LD      (IX+08H),A
315d 3A1762    LD      A,(6217H)
3160 FE01      CP      01H
3162 C26A31    JP      NZ,316AH
3165 3E00      LD      A,00H
3167 DD7708    LD      (IX+08H),A
316a DD19      ADD     IX,DE
316c 10DB      DJNZ    3149H
316e 21A063    LD      HL,63A0H
3171 3600      LD      (HL),00H
3173 3AA163    LD      A,(63A1H)
3176 FE00      CP      00H
3178 C0        RET     NZ

3179 33        INC     SP
317a 33        INC     SP
317b C9        RET     

317c 3AA163    LD      A,(63A1H)
317f FE05      CP      05H
3181 CA6A31    JP      Z,316AH
3184 3A2762    LD      A,(currentStage)
3187 FE02      CP      02H
3189 C29531    JP      NZ,3195H
318c 3AA163    LD      A,(63A1H)
318f 4F        LD      C,A
3190 3A8063    LD      A,(6380H)
3193 B9        CP      C
3194 C8        RET     Z

3195 3AA063    LD      A,(63A0H)
3198 FE01      CP      01H
319a C26A31    JP      NZ,316AH
319d DD7700    LD      (IX+00H),A
31a0 DD7718    LD      (IX+18H),A
31a3 AF        XOR     A
31a4 32A063    LD      (63A0H),A
31a7 3AA163    LD      A,(63A1H)
31aa 3C        INC     A
31ab 32A163    LD      (63A1H),A
31ae C36A31    JP      316AH
31b1 CDDD31    CALL    31DDH
31b4 AF        XOR     A
31b5 32A263    LD      (63A2H),A
31b8 21E063    LD      HL,63E0H
31bb 22C863    LD      (63C8H),HL
31be 2AC863    LD      HL,(63C8H)
31c1 012000    LD      BC,0020H
31c4 09        ADD     HL,BC
31c5 22C863    LD      (63C8H),HL
31c8 7E        LD      A,(HL)
31c9 A7        AND     A
31ca CAD031    JP      Z,31D0H
31cd CD0232    CALL    3202H
31d0 3AA263    LD      A,(63A2H)
31d3 3C        INC     A
31d4 32A263    LD      (63A2H),A
31d7 FE05      CP      05H
31d9 C2BE31    JP      NZ,31BEH
31dc C9        RET     

31dd 3A8063    LD      A,(6380H)
31e0 FE03      CP      03H
31e2 F8        RET     M

31e3 CDF631    CALL    31F6H
31e6 FE01      CP      01H
31e8 C0        RET     NZ

31e9 213964    LD      HL,6439H
31ec 3E02      LD      A,02H
31ee 77        LD      (HL),A
31ef 217964    LD      HL,6479H
31f2 3E02      LD      A,02H
31f4 77        LD      (HL),A
31f5 C9        RET     

31f6 3A1860    LD      A,(randNum)
31f9 E603      AND     03H
31fb FE01      CP      01H
31fd C0        RET     NZ

31fe 3A1A60    LD      A,(counter1)
3201 C9        RET     

3202 DD2AC863  LD      IX,(63C8H)
3206 DD7E18    LD      A,(IX+18H)
3209 FE01      CP      01H
320b CA7A32    JP      Z,327AH
320e DD7E0D    LD      A,(IX+0DH)
3211 FE04      CP      04H
3213 F23032    JP      P,3230H
3216 DD7E19    LD      A,(IX+19H)
3219 FE02      CP      02H
321b CA7E32    JP      Z,327EH
321e CD0F33    CALL    330FH
3221 3A1860    LD      A,(randNum)
3224 E603      AND     03H
3226 C23332    JP      NZ,3233H
3229 DD7E0D    LD      A,(IX+0DH)
322c A7        AND     A
322d CA5732    JP      Z,3257H
3230 CD3D33    CALL    333DH
3233 DD7E0D    LD      A,(IX+0DH)
3236 FE04      CP      04H
3238 F29132    JP      P,3291H
323b CDAD33    CALL    33ADH
323e CD8C29    CALL    298CH
3241 FE01      CP      01H
3243 CA9732    JP      Z,3297H
3246 DD2AC863  LD      IX,(63C8H)
324a DD7E0E    LD      A,(IX+0EH)
324d FE10      CP      10H
324f DA8C32    JP      C,328CH
3252 FEF0      CP      F0H
3254 D28432    JP      NC,3284H
3257 DD7E13    LD      A,(IX+13H)
325a FE00      CP      00H
325c C2B932    JP      NZ,32B9H
325f 3E11      LD      A,11H
3261 DD7713    LD      (IX+13H),A
3264 1600      LD      D,00H
3266 5F        LD      E,A
3267 217A3A    LD      HL,3A7AH
326a 19        ADD     HL,DE
326b 7E        LD      A,(HL)
326c DD460E    LD      B,(IX+0EH)
326f DD7003    LD      (IX+03H),B
3272 DD4E0F    LD      C,(IX+0FH)
3275 81        ADD     A,C
3276 DD7705    LD      (IX+05H),A
3279 C9        RET     

327a CDBD32    CALL    32BDH
327d C9        RET     

327e CDD632    CALL    32D6H
3281 C32932    JP      3229H
3284 3E02      LD      A,02H
3286 DD770D    LD      (IX+0DH),A
3289 C35732    JP      3257H
328c 3E01      LD      A,01H
328e C38632    JP      3286H
3291 CDE733    CALL    33E7H
3294 C35732    JP      3257H
3297 DD2AC863  LD      IX,(63C8H)
329b DD7E0D    LD      A,(IX+0DH)
329e FE01      CP      01H
32a0 C2B132    JP      NZ,32B1H
32a3 3E02      LD      A,02H
32a5 DD350E    DEC     (IX+0EH)
32a8 DD770D    LD      (IX+0DH),A
32ab CDC333    CALL    33C3H
32ae C35732    JP      3257H
32b1 3E01      LD      A,01H
32b3 DD340E    INC     (IX+0EH)
32b6 C3A832    JP      32A8H
32b9 3D        DEC     A
32ba C36132    JP      3261H
32bd 3A2762    LD      A,(currentStage)
32c0 FE01      CP      01H
32c2 CACE32    JP      Z,32CEH
32c5 FE02      CP      02H
32c7 CAD232    JP      Z,32D2H
32ca CDB934    CALL    34B9H
32cd C9        RET     

32ce CD2C34    CALL    342CH
32d1 C9        RET     

32d2 CD7834    CALL    3478H
32d5 C9        RET     

32d6 DD7E1C    LD      A,(IX+1CH)
32d9 FE00      CP      00H
32db C2FD32    JP      NZ,32FDH
32de DD7E1D    LD      A,(IX+1DH)
32e1 FE01      CP      01H
32e3 C20B33    JP      NZ,330BH
32e6 DD361D00  LD      (IX+1DH),00H
32ea 3A0562    LD      A,(marioY)
32ed DD460F    LD      B,(IX+0FH)
32f0 90        SUB     B
32f1 DA0333    JP      C,3303H
32f4 DD361CFF  LD      (IX+1CH),FFH
32f8 DD360D00  LD      (IX+0DH),00H
32fc C9        RET     

32fd DD351C    DEC     (IX+1CH)
3300 C2F832    JP      NZ,32F8H
3303 DD361900  LD      (IX+19H),00H
3307 DD361C00  LD      (IX+1CH),00H
330b CD0F33    CALL    330FH
330e C9        RET     

330f DD7E16    LD      A,(IX+16H)
3312 FE00      CP      00H
3314 C23233    JP      NZ,3332H
3317 DD36162B  LD      (IX+16H),2BH
331b DD360D00  LD      (IX+0DH),00H
331f 3A1860    LD      A,(randNum)
3322 0F        RRCA    
3323 D23233    JP      NC,3332H
3326 DD7E0D    LD      A,(IX+0DH)
3329 FE01      CP      01H
332b CA3633    JP      Z,3336H
332e DD360D01  LD      (IX+0DH),01H
3332 DD3516    DEC     (IX+16H)
3335 C9        RET     

3336 DD360D02  LD      (IX+0DH),02H
333a C33233    JP      3332H
333d DD7E0D    LD      A,(IX+0DH)
3340 FE08      CP      08H
3342 CA7133    JP      Z,3371H
3345 FE04      CP      04H
3347 CA8A33    JP      Z,338AH
334a CDA133    CALL    33A1H
334d DD7E0F    LD      A,(IX+0FH)
3350 C608      ADD     A,08H
3352 57        LD      D,A
3353 DD7E0E    LD      A,(IX+0EH)
3356 011500    LD      BC,0015H
3359 CD6E23    CALL    236EH
335c A7        AND     A
335d CA9933    JP      Z,3399H
3360 DD701F    LD      (IX+1FH),B
3363 3A0562    LD      A,(marioY)
3366 47        LD      B,A
3367 DD7E0F    LD      A,(IX+0FH)
336a 90        SUB     B
336b D0        RET     NC

336c DD360D04  LD      (IX+0DH),04H
3370 C9        RET     

3371 DD7E0F    LD      A,(IX+0FH)
3374 C608      ADD     A,08H
3376 DD461F    LD      B,(IX+1FH)
3379 B8        CP      B
337a C0        RET     NZ

337b DD360D00  LD      (IX+0DH),00H
337f DD7E19    LD      A,(IX+19H)
3382 FE02      CP      02H
3384 C0        RET     NZ

3385 DD361D01  LD      (IX+1DH),01H
3389 C9        RET     

338a DD7E0F    LD      A,(IX+0FH)
338d C608      ADD     A,08H
338f DD461F    LD      B,(IX+1FH)
3392 B8        CP      B
3393 C0        RET     NZ

3394 DD360D00  LD      (IX+0DH),00H
3398 C9        RET     

3399 DD701F    LD      (IX+1FH),B
339c DD360D08  LD      (IX+0DH),08H
33a0 C9        RET     

33a1 3E07      LD      A,07H
33a3 F7        RST     ReturnUnlessStageOfInterest
33a4 DD7E0F    LD      A,(IX+0FH)
33a7 FE59      CP      59H
33a9 D0        RET     NC

33aa 33        INC     SP
33ab 33        INC     SP
33ac C9        RET     

33ad DD7E0D    LD      A,(IX+0DH)
33b0 FE01      CP      01H
33b2 CAD933    JP      Z,33D9H
33b5 DD7E07    LD      A,(IX+07H)
33b8 E67F      AND     7FH
33ba DD7707    LD      (IX+07H),A
33bd DD350E    DEC     (IX+0EH)
33c0 CD0934    CALL    3409H
33c3 3A2762    LD      A,(currentStage)
33c6 FE01      CP      01H
33c8 C0        RET     NZ

33c9 DD660E    LD      H,(IX+0EH)
33cc DD6E0F    LD      L,(IX+0FH)
33cf DD460D    LD      B,(IX+0DH)
33d2 CD3323    CALL    2333H
33d5 DD750F    LD      (IX+0FH),L
33d8 C9        RET     

33d9 DD7E07    LD      A,(IX+07H)
33dc F680      OR      80H
33de DD7707    LD      (IX+07H),A
33e1 DD340E    INC     (IX+0EH)
33e4 C3C033    JP      33C0H
33e7 CD0934    CALL    3409H
33ea DD7E0D    LD      A,(IX+0DH)
33ed FE08      CP      08H
33ef C20534    JP      NZ,3405H
33f2 DD7E14    LD      A,(IX+14H)
33f5 A7        AND     A
33f6 C20134    JP      NZ,3401H
33f9 DD361402  LD      (IX+14H),02H
33fd DD350F    DEC     (IX+0FH)
3400 C9        RET     

3401 DD3514    DEC     (IX+14H)
3404 C9        RET     

3405 DD340F    INC     (IX+0FH)
3408 C9        RET     

3409 DD7E15    LD      A,(IX+15H)
340c A7        AND     A
340d C22834    JP      NZ,3428H
3410 DD361502  LD      (IX+15H),02H
3414 DD3407    INC     (IX+07H)
3417 DD7E07    LD      A,(IX+07H)
341a E60F      AND     0FH
341c FE0F      CP      0FH
341e C0        RET     NZ

341f DD7E07    LD      A,(IX+07H)
3422 EE02      XOR     02H
3424 DD7707    LD      (IX+07H),A
3427 C9        RET     

3428 DD3515    DEC     (IX+15H)
342b C9        RET     

342c DD6E1A    LD      L,(IX+1AH)
342f DD661B    LD      H,(IX+1BH)
3432 AF        XOR     A
3433 010000    LD      BC,0000H
3436 ED4A      ADC     HL,BC
3438 C24234    JP      NZ,3442H
343b 218C3A    LD      HL,3A8CH
343e DD360326  LD      (IX+03H),26H
3442 DD3403    INC     (IX+03H)
3445 7E        LD      A,(HL)
3446 FEAA      CP      AAH
3448 CA5634    JP      Z,3456H
344b DD7705    LD      (IX+05H),A
344e 23        INC     HL
344f DD751A    LD      (IX+1AH),L
3452 DD741B    LD      (IX+1BH),H
3455 C9        RET     

3456 AF        XOR     A
3457 DD7713    LD      (IX+13H),A
345a DD7718    LD      (IX+18H),A
345d DD770D    LD      (IX+0DH),A
3460 DD771C    LD      (IX+1CH),A
3463 DD7E03    LD      A,(IX+03H)
3466 DD770E    LD      (IX+0EH),A
3469 DD7E05    LD      A,(IX+05H)
346c DD770F    LD      (IX+0FH),A
346f DD361A00  LD      (IX+1AH),00H
3473 DD361B00  LD      (IX+1BH),00H
3477 C9        RET     

3478 DD6E1A    LD      L,(IX+1AH)
347b DD661B    LD      H,(IX+1BH)
347e AF        XOR     A
347f 010000    LD      BC,0000H
3482 ED4A      ADC     HL,BC
3484 C29A34    JP      NZ,349AH
3487 21AC3A    LD      HL,3AACH
348a 3A0362    LD      A,(marioX)
348d CB7F      BIT     7,A
348f CAA834    JP      Z,34A8H
3492 DD360D01  LD      (IX+0DH),01H
3496 DD36037E  LD      (IX+03H),7EH
349a DD7E0D    LD      A,(IX+0DH)
349d FE01      CP      01H
349f C2B334    JP      NZ,34B3H
34a2 DD3403    INC     (IX+03H)
34a5 C34534    JP      3445H
34a8 DD360D02  LD      (IX+0DH),02H
34ac DD360380  LD      (IX+03H),80H
34b0 C39A34    JP      349AH
34b3 DD3503    DEC     (IX+03H)
34b6 C34534    JP      3445H
34b9 3A2762    LD      A,(currentStage)
34bc FE03      CP      03H
34be C8        RET     Z

34bf 3A0362    LD      A,(marioX)
34c2 CB7F      BIT     7,A
34c4 C2ED34    JP      NZ,34EDH
34c7 21C43A    LD      HL,3AC4H
34ca 0600      LD      B,00H
34cc 3A1960    LD      A,(6019H)
34cf E606      AND     06H
34d1 4F        LD      C,A
34d2 09        ADD     HL,BC
34d3 7E        LD      A,(HL)
34d4 DD7703    LD      (IX+03H),A
34d7 DD770E    LD      (IX+0EH),A
34da 23        INC     HL
34db 7E        LD      A,(HL)
34dc DD7705    LD      (IX+05H),A
34df DD770F    LD      (IX+0FH),A
34e2 AF        XOR     A
34e3 DD770D    LD      (IX+0DH),A
34e6 DD7718    LD      (IX+18H),A
34e9 DD771C    LD      (IX+1CH),A
34ec C9        RET     

34ed 21D43A    LD      HL,3AD4H
34f0 C3CA34    JP      34CAH
34f3 210064    LD      HL,6400H
34f6 11D069    LD      DE,69D0H
34f9 0605      LD      B,05H
34fb 7E        LD      A,(HL)
34fc A7        AND     A
34fd CA1E35    JP      Z,351EH
3500 2C        INC     L
3501 2C        INC     L
3502 2C        INC     L
3503 7E        LD      A,(HL)
3504 12        LD      (DE),A
3505 3E04      LD      A,04H
3507 85        ADD     A,L
3508 6F        LD      L,A
3509 1C        INC     E
350a 7E        LD      A,(HL)
350b 12        LD      (DE),A
350c 2C        INC     L
350d 1C        INC     E
350e 7E        LD      A,(HL)
350f 12        LD      (DE),A
3510 2D        DEC     L
3511 2D        DEC     L
3512 2D        DEC     L
3513 1C        INC     E
3514 7E        LD      A,(HL)
3515 12        LD      (DE),A
3516 13        INC     DE
3517 3E1B      LD      A,1BH
3519 85        ADD     A,L
351a 6F        LD      L,A
351b 10DE      DJNZ    34FBH
351d C9        RET     

351e 3E05      LD      A,05H
3520 85        ADD     A,L
3521 6F        LD      L,A
3522 3E04      LD      A,04H
3524 83        ADD     A,E
3525 5F        LD      E,A
3526 C31735    JP      3517H


;--------------------------------
; Points table
; Lists possible points values to 
; award to the player.
PointsTable:
3529 00 00 00 ; Entry 0 (000000)
352c 00 01 00 ; Entry 1 (000100)
452f 00 02 00 ; Entry 2 (000200)
3532 00 03 00 ; Entry 3 (000300)
3535 00 04 00 ; Entry 4 (000400)
3538 00 05 00 ; Entry 5 (000500)
353b 00 06 00 ; Entry 6 (000600)
353e 00 07 00 ; Entry 7 (000700)
3541 00 08 00 ; Entry 8 (000800)
3544 00 09 00 ; Entry 9 (000900)
3547 00 00 00 ; Entry 10 (000000)
354a 00 10 00 ; Entry 11 (001000)
354d 00 20 00 ; Entry 12 (002000)
3550 00 30 00 ; Entry 13 (003000)
3553 00 40 00 ; Entry 14 (004000)
3556 00 50 00 ; Entry 15 (005000)
3559 00 60 00 ; Entry 16 (006000)
355c 00 70 00 ; Entry 17 (007000)
355f 00 80 00 ; Entry 18 (008000)
3562 00 90 00 ; Entry 19 (009000)
;--------------------------------



;----------------------------------
; Default high score data
DefaultHighScoreData:
; "1ST  007650              "
3565 9477   ; highScore1StringCoord (28, 20)
3567 012324101000000706050010101010101010101010101010103F ; highScore1String
3581 00     ; highScore1PlayerId (not earned by current players)
3582 507600 ; highScore1 (007650)
3585 F476   ; highScore1Coord (23, 20)

; 2ND  006100              "
3587 9677   ; highScore2StringCoord (28,22)
3589 021E14101000000601000010101010101010101010101010103F ; highScore2String
35a3 00     ; highScore2PlayerId
35a4 006100 ; highScore2 (006100)
35a7 F676   ; highScore2Coord (23,22)

; "3RD  005950              "
35a9 9877 ; (28,24)
35ab 032214101000000509050010101010101010101010101010103F
35c5 00
35c6 505900 ; 005950
35c9 F876 ; (23,24)

; "4TH  005050              "
35cb 9A77 ; (28,26)
35cd 042418101000000500050010101010101010101010101010103F
35e7 00
35e8 505000 ; 005050
35eb FA76 ; (23,26)

; "5TH  004300              "
35ed 9C77 ; (28, 28)
35ef 052418101000000403000010101010101010101010101010103F
3609 00
360a 004300 ; 004300
360d FC76 ; (23, 28)
;----------------------------------



;----------------------------------
; The following table lists the X 
; and Y coordinates required to
; display the letter selection box
; around each letter on the high
; score initial screen
; Row 1
HighScoreLetterXYTable:
360f 3B 5C ; 'A'
3611 4B 5C ; 'B'
3613 5B 5C ; 'C'
3615 6B 5C ; 'D'
3617 7B 5C ; 'E'
3619 8B 5C ; 'F'
361b 9B 5C ; 'G'
361d AB 5C ; 'H'
361f BB 5C ; 'I'
3621 CB 5C ; 'J'

; Row 2
3623 3B 6C ; 'K'
3625 4B 6C ; 'L'
3627 5B 6C ; 'M'
3629 6B 6C ; 'N'
362b 7B 6C ; 'O'
362d 8B 6C ; 'P'
362f 9B 6C ; 'Q'
3631 AB 6C ; 'R'
3633 BB 6C ; 'S'
3635 CB 6C ; 'T'

; Row 3
3637 3B 7C ; 'U'
3639 4B 7C ; 'V'
363b 5B 7C ; 'W'
363d 6B 7C ; 'X'
363f 7B 7C ; 'Y'
3641 8B 7C ; 'Z'
3643 9B 7C ; '.'
3645 AB 7C ; '-'
3647 BB 7C ; 'RUB'
3649 CB 7C ; 'END'
;---------------------------------



;---------------------------------
; String table
StringTable:
364b 8B36 ; 0 = "GAME OVER"
364d 0100 ; 1 = ???
364f 9836 ; 2 = "PLAYER (I)"
3651 A536 ; 3 = "PLAYER (II)"
3653 B236 ; 4 = "HIGH SCORE"
3655 BF36 ; 5 = "CREDIT    "
3657 0600 ; 6 = ???
3659 CC36 ; 7 = "HOW HIGH CAN YOU GET ? "
365b 0800 ; 8 = ???
365d E636 ; 9 = "ONLY 1 PlAYER BUTTON"
365f FD36 ; A = "1 OR 2 PLAYERS BUTTON"
3661 0B00 ; B = ???
3663 1537 ; C = "PUSH"
3665 1C37 ; D = "NAME REGISTRATION"
3667 3037 ; E = "NAME:"
3669 3837 ; F = "---         "
366b 4737 ; 10 = "A B C D E F G H I J"
366d 5D37 ; 11 = "K L M N O P Q R S T"
366f 7337 ; 12 = "U V W X Y Z . -RUBEND "
3671 8B37 ; 13 = "REGI TIME  (30) "
3673 0061 ; 14 = ??? (6100H)
3675 2261 ; 15 = ??? (6122H)
3677 4461 ; 16 = ??? (6144H)
3679 6661 ; 17 = ??? (6166H)
367b 8861 ; 18 = ??? (6188H)
367d 9E37 ; 19 = "RANK  SCORE  NAME    "
367f B637 ; 1A = "YOUR NAME WAS REGISTERED."
3681 D237 ; 1B = "INSERT COIN "
3683 E137 ; 1C = "  PLAYER    COIN"
3685 1D00 ; 1D = ??? (001DH)
3687 003F ; 1E = ??? (3F00H)
3689 093F ; 1F = ??? (3F09H)
;--------------------------------

    

;--------------------------------
; Strings
; "GAME  OVER" 
368b 9676 ; (20, 22) 
368d 17111D1510101F2615223F
; "PLAYER (I)" 
3698 9476 ; (20, 20)
369a 201C11291522103032313F
; "PLAYER (II)"
36a5 9476 ; (20, 20)
36a7 201C11291522103033313F
; "HIGH SCORE" 
36b2 8076 ; (20, 0)  
36b4 181917181023131F22153F
; "CREDIT    "
36bf 9F75 ; (12, 31)
36c1 132215141924101010103F
; "HOW HIGH CAN YOU GET ? "
36cc 5E77 ; (25, 31)
36ce 181F2710181917181013111E10291F251017152410FB103F
; "ONLY 1 PlAYER BUTTON"
36e6 2977 ; (25, 9)
36e8 1F1E1C29100110201C1129152210122524241F1E3F
; "1 OR 2 PLAYERS BUTTON"
36fd 2977 ; (25, 9)
36ff 01101F22100210201C112915222310122524241F1E3F
; "PUSH"
3715 2776 ; (17, 7)
3717 202523183F 
; "NAME REGISTRATION"
371c 0677 ; (24, 6)
371e 1E111D1510221517192324221124191F1E3F 
; "NAME:"
3730 8876 ; (20, 8)
3732 1E111D152E3F
; "---         " ('-''s are underlines)
3738 E975 ; (15, 9)
373a 2D2D2D1010101010101010103F
; "A B C D E F G H I J"
3747 0B77 ; (24, 11)
3749 1110121013101410151016101710181019101A3F  
; "K L M N O P Q R S T"
375d 0D77 ; (24, 13)
375f 1B101C101D101E101F102010211022102310243F
; "U V W X Y Z . -RUBEND "
3773 0F77 ; (24, 15)
3775 251026102710281029102A102B102C4445464748103F
; "REGI TIME  (30) "
378b F276 ; (23, 18)
378c 221517191024191D15101030030031103F
; "RANK  SCORE  NAME    "
379e 9277 ; (28, 18)
37a0 22111E1B101023131F221510101E111D15101010103F 
; "YOUR NAME WAS REGISTERED."
37b6 7277 ; (27, 18)
37b8 291F2522101E111D15102711231022151719232415221514423F  
; "INSERT COIN "
37d2 A776 ; (21, 7)
37d4 191E2315222410131F191E103F
; "  PLAYER    COIN"
37e1 0A77 ; (24, 10)
37e3 1010201C1129152210101010131F191E3F
; "© NINTENDO    "
37f4 FC76 ; (23, 28)
37f6 494A101E191E24151E141F101010103F
; "1981"
3806 7C75 ; (11, 28)
3808 010908013F
;--------------------------------



;--------------------------------
; Intro screen
; (Barrels level before DK stomps 
; and warps it)
380d 02 9738 6838 ; (13+0,7+0)-(18+7,7+0) (Pauline's platform)
3812 02 DF54 1054 ; (4+0,10+4)-(29+7,10+4) (5th platform)
3817 02 EF6D 206D ; (2+0,13+5)-(27+7,13+5) (4th platform
381c 02 DF8E 108E
3821 02 EFAF 20AF
3826 02 DFD0 10D0
382b 02 EFF1 10F1
3830 00 5318 5354
3835 00 6318 6354
383a 00 9338 9354
383f 00 8354 83F1
3844 00 9354 93F1
3849 AA
;---------------------------------



;---------------------------------
; Characters that make up the timer
; display    
;           |BONUS|
;           |0000 |
;            -----
TimerDisplayBoxTileData:
384a 8D ; upper-right corner
384b 7D ; right edge
384c 8C ; lower-right corner
384d 6F ; top edge
384e 00 ; '0'
384f 7C ; bottom edge
3850 6E ; top edge
3851 00 ; '0'
3852 7C ; bottom edge
3853 6D ; top edge
3854 00 ; '0'
3855 7C ; bottom edge
3856 6C ; top edge
3857 00 ; '0'
3858 7C ; bottom edge
3859 8F ; upper-left corner
385a 7F ; left edge
385b 8E ; lower-left corner
;---------------------------------



;---------------------------------
DKLeftArmRaisedSpriteData:
385c 47 27 08 50 ; DK front right leg
3860 2F A7 08 50 ; DK front left leg (flipped h.)
3864 3B 25 08 50 ; DK front chest
3868 00 70 08 48 ; ???
386c 3B 23 07 40 ; DK front head
3870 46 A9 08 44 ; DK front left arm (flipped h.)
3874 00 70 08 48 ; ???
3878 30 29 08 44 ; DK front right arm
387c 00 70 08 48 ; ???
3880 00 70 0A 48 ; ???
;---------------------------------



;----------------------------------
PaulineFacingRightSpriteData:
3884 6F 10 09 23 ; 10H (Pauline's head facing right)
3888 6F 11 0A 33 ; 11H (Pauline's body facing right)
;----------------------------------



;----------------------------------
; Sprite data for DK climbing
DKSpriteDataClimbing:
388c 50 34 08 3C ; DK Rear Left Arm
3890 00 35 08 3C ; DK Rear Right Arm
3894 53 32 08 40 ; DK Rear Left Head
3898 63 33 08 40 ; DK Rear Right Head
389c 00 70 08 48 ; 
38a0 53 36 08 50 ; DK Rear Left Leg
38a4 63 37 08 50 ; DK Rear Right Leg
38a8 6B 31 08 41 ; DK Right Arm?
38ac 00 70 08 48 ; 
38b0 6A 14 0A 48 ; Pauline being carried
;----------------------------------



;----------------------------------
; Data describing DK's jump from the
; ladders onto the platform in the
; intro screen
DKLadderJumpVectorData:
38b4 FD FD FD FD FD FD FD ; -3 x 7
38bb FE FE FE FE FE FE ; -2 x 6
38c1 FF FF FF FF ; -1 x 4
38c5 00 00 ; 0 x 2
38c7 01 01 01 ; 1 x 3
38ca 7F ; End of vector data
;----------------------------------



;----------------------------------
; Data describing DK's jumps across
; the top platform in the intro
; screen
DKJumpVectorData:
38cb FF FF FF FF FF ; -1 x 5
38d0 00 ; 0 x 1
38d1 FF ; -1 x 1
38d2 00 00 ; 0 x 2
38d4 01 ; 1 x 1
38d5 00 ; 0 x 1
38d6 01 01 01 01 01 ; 1 x 5
38db 7F ; End of vector data
;----------------------------------



;----------------------------------
38dc 047F

38de F0        RET     P
38df 10F0      DJNZ    38D1H
38e1 02        LD      (BC),A
38e2 DF        RST     ReturnIfNotMinorTimeout
38e3 F270F8    JP      P,F870H
38e6 02        LD      (BC),A
38e7 6F        LD      L,A
38e8 F8        RET     M

38e9 10F8      DJNZ    38E3H
38eb AA        XOR     D
38ec 04        INC     B
38ed DF        RST     ReturnIfNotMinorTimeout
38ee D0        RET     NC

38ef 90        SUB     B
38f0 D0        RET     NC

38f1 02        LD      (BC),A
38f2 DF        RST     ReturnIfNotMinorTimeout
38f3 DC20D1    CALL    C,D120H
38f6 AA        XOR     D
38f7 FF        RST     MoveDKSprites
38f8 FF        RST     MoveDKSprites
38f9 FF        RST     MoveDKSprites
38fa FF        RST     MoveDKSprites
38fb FF        RST     MoveDKSprites
38fc 04        INC     B
38fd DF        RST     ReturnIfNotMinorTimeout
38fe A8        XOR     B
38ff 20A8      JR      NZ,38A9H
3901 04        INC     B
3902 5F        LD      E,A
3903 B0        OR      B
3904 20B0      JR      NZ,38B6H
3906 02        LD      (BC),A
3907 DF        RST     ReturnIfNotMinorTimeout
3908 B0        OR      B
3909 20BB      JR      NZ,38C6H
390b AA        XOR     D
390c 04        INC     B
390d DF        RST     ReturnIfNotMinorTimeout
390e 88        ADC     A,B
390f 3088      JR      NC,3899H
3911 04        INC     B
3912 DF        RST     ReturnIfNotMinorTimeout
3913 90        SUB     B
3914 B0        OR      B
3915 90        SUB     B
3916 02        LD      (BC),A
3917 DF        RST     ReturnIfNotMinorTimeout
3918 9A        SBC     A,D
3919 208F      JR      NZ,38AAH
391b AA        XOR     D
391c 04        INC     B
391d BF        CP      A
391e 68        LD      L,B
391f 2068      JR      NZ,3989H
3921 04        INC     B
3922 3F        CCF     
3923 70        LD      (HL),B
3924 2070      JR      NZ,3996H
3926 02        LD      (BC),A
3927 DF        RST     ReturnIfNotMinorTimeout
3928 6E        LD      L,(HL)
3929 2079      JR      NZ,39A4H
392b AA        XOR     D



;----------------------------------
IntroScreenSloped6thPlatformTileData:
392c 02 DF58 A055 ; (4+0,11+0)-(11+7,10+5) 6th platform sloped portion
3931 AA 
;----------------------------------



;----------------------------------
; Data for DK sprites
; DK facing right, left arm reaching out
DKSpriteFacingRight1:
;    X  #  P  Y
3932 00 70 08 44 
3936 2B AC 08 4C ; 2CH h (left leg back)
393a 3B AE 08 4C ; 2EH h (body sideways)
393e 3B AF 08 3C ; 2FH h (back sideways)
3942 4B B0 07 3C ; 30H h (head sideways)
3946 4B AD 08 4C ; 2DH h (left arm reaching forward)
394a 00 70 08 44 
394e 00 70 08 44 
3952 00 70 08 44 
3956 00 70 0A 44 

395a 47 27 08 4C ; 27H (left leg)
395e 2F A7 08 4C ; 27H (right leg)
3962 3B        DEC     SP
3963 25        DEC     H
3964 08        EX      AF,AF'
3965 4C        LD      C,H
3966 00        NOP     
3967 70        LD      (HL),B
3968 08        EX      AF,AF'
3969 44        LD      B,H
396a 3B        DEC     SP
396b 23        INC     HL
396c 07        RLCA    
396d 3C        INC     A
396e 4B        LD      C,E
396f 2A083C    LD      HL,(3C08H)
3972 4B        LD      C,E
3973 2B        DEC     HL
3974 08        EX      AF,AF'
3975 4C        LD      C,H
3976 2B        DEC     HL
3977 AA        XOR     D
3978 08        EX      AF,AF'
3979 3C        INC     A
397a 2B        DEC     HL
397b AB        XOR     E
397c 08        EX      AF,AF'
397d 4C        LD      C,H
397e 00        NOP     
397f 70        LD      (HL),B
3980 0A        LD      A,(BC)
3981 44        LD      B,H
3982 00        NOP     
3983 70        LD      (HL),B
3984 08        EX      AF,AF'
3985 44        LD      B,H
3986 4B        LD      C,E
3987 2C        INC     L
3988 08        EX      AF,AF'
3989 4C        LD      C,H
398a 3B        DEC     SP
398b 2E08      LD      L,08H
398d 4C        LD      C,H
398e 3B        DEC     SP
398f 2F        CPL     
3990 08        EX      AF,AF'
3991 3C        INC     A
3992 2B        DEC     HL
3993 3007      JR      NC,399CH
3995 3C        INC     A
3996 2B        DEC     HL
3997 2D        DEC     L
3998 08        EX      AF,AF'
3999 4C        LD      C,H
399a 00        NOP     
399b 70        LD      (HL),B
399c 08        EX      AF,AF'
399d 44        LD      B,H
399e 00        NOP     
399f 70        LD      (HL),B
39a0 08        EX      AF,AF'
39a1 44        LD      B,H
39a2 00        NOP     
39a3 70        LD      (HL),B
39a4 08        EX      AF,AF'
39a5 44        LD      B,H
39a6 00        NOP     
39a7 70        LD      (HL),B
39a8 0A        LD      A,(BC)
39a9 44        LD      B,H

39aa FDFDFD    DB      FDH, FDH, FDH    ; Unknown opcode
39ad FEFE      CP      FEH
39af FEFE      CP      FEH
39b1 FF        RST     MoveDKSprites
39b2 FF        RST     MoveDKSprites
39b3 00        NOP     
39b4 FF        RST     MoveDKSprites
39b5 00        NOP     
39b6 00        NOP     
39b7 010001    LD      BC,0100H
39ba 010202    LD      BC,0202H
39bd 02        LD      (BC),A
39be 02        LD      (BC),A
39bf 03        INC     BC
39c0 03        INC     BC
39c1 03        INC     BC
39c2 7F        LD      A,A
39c3 1E4E      LD      E,4EH
39c5 BB        CP      E
39c6 4C        LD      C,H
39c7 D8        RET     C

39c8 4E        LD      C,(HL)
39c9 59        LD      E,C
39ca 4E        LD      C,(HL)
39cb 7F        LD      A,A
39cc BB        CP      E
39cd 4D        LD      C,L
39ce 7F        LD      A,A

;----------------------------------
; Data for DK sprites
; DK grinning, left arm raised, 
; right leg raised
DKSpriteDataGrinLArmRLegUp:
;    X  #  P  Y
39cf 47 27 08 50 ; 27H (left leg)
39d3 2D 26 08 50 ; 26H (right leg raised)
39d7 3B 25 08 50 ; 25H (torso)
39db 00 70 08 48
39df 3B 24 07 40 ; 24H (grin)
39e3 4B 28 08 40 ; 28H (left arm raised)
39e7 00 70 08 48
39eb 30 29 08 44 ; 29H (right arm)
39ef 00 70 08 48
39f3 00 70 0A 48
;----------------------------------



;----------------------------------
; Data for DK sprites
; DK grinning, right arm raised, 
; left leg raised
;    X  #  P  Y
DKSpriteDataGrinRArmLLegUp:
39f7 49 A6 08 50 ; 26H h (left leg raised)
39fb 2F A7 08 50 ; 27H h (right leg)
39ff 3B 25 08 50 ; 25H (torso)
3a03 00 70 08 48 
3a07 3B 24 07 40 ; 24H (grin)
3a0b 46 A9 08 44 ; 29H h (left arm)
3a0f 00 70 08 48
3a13 2B A8 08 40 ; 28H h (right arm raised)
3a17 00 70 08 48
3a1b 00 70 0A 48
;----------------------------------



;----------------------------------
; Data for DK sprites
; DK grinning upside down
;    X  #  P  Y
DKSpriteDataGrinUpsideDown:
3a1f 73 A7 88 60 ; 27H h,v (left leg)
3a23 8B 27 88 60 ; 27H v (right leg)
3a27 7F 25 88 60 ; 25H v (torso)
3a2b 00 70 88 68 
3a2f 7F 24 87 70 ; 24H v (grin)
3a33 74 29 88 6C ; 29H v (right arm)
3a37 00 70 88 68 
3a3b 8A A9 88 6C ; 29H h,v (left arm)
3a3f 00 70 88 68 
3a43 00 70 8A 68 
;----------------------------------



;----------------------------------
3a47 05 AF F0 50 F0 AA
;----------------------------------

3a4d 05        DEC     B
3a4e AF        XOR     A
3a4f E8        RET     PE

3a50 50        LD      D,B
3a51 E8        RET     PE

3a52 AA        XOR     D
3a53 05        DEC     B
3a54 AF        XOR     A
3a55 E0        RET     PO

3a56 50        LD      D,B
3a57 E0        RET     PO

3a58 AA        XOR     D
3a59 05        DEC     B
3a5a AF        XOR     A
3a5b D8        RET     C

3a5c 50        LD      D,B
3a5d D8        RET     C

3a5e AA        XOR     D
3a5f 05        DEC     B
3a60 B7        OR      A
3a61 58        LD      E,B
3a62 48        LD      C,B
3a63 58        LD      E,B
3a64 AA        XOR     D


;----------------------------------
; Table defining the order of the
; stages for each level
StageOrderTable:
3a65 01 04             ; Level 1
3a67 01 03 04          ; Level 2
3a6a 01 02 03 04       ; Level 3
3a6e 01 02 01 03 04    ; Level 4
3a73 01 02 01 03 01 04 ; Level 5+
3a79 7F 
;----------------------------------

3a7a FF        RST     MoveDKSprites
3a7b 00        NOP     
3a7c FF        RST     MoveDKSprites
3a7d FF        RST     MoveDKSprites
3a7e FEFE      CP      FEH
3a80 FEFE      CP      FEH
3a82 FEFE      CP      FEH
3a84 FEFE      CP      FEH
3a86 FEFE      CP      FEH
3a88 FEFF      CP      FFH
3a8a FF        RST     MoveDKSprites
3a8b 00        NOP     
3a8c E8        RET     PE

3a8d E5        PUSH    HL
3a8e E3        EX      (SP),HL
3a8f E2E1E0    JP      PO,E0E1H
3a92 DF        RST     ReturnIfNotMinorTimeout
3a93 DEDD      SBC     A,DDH
3a95 DDDCDCDC  CALL    C,DCDCH
3a99 DCDCDC    CALL    C,DCDCH
3a9c DDDDDEDF  SBC     A,DFH
3aa0 E0        RET     PO

3aa1 E1        POP     HL
3aa2 E2E3E4    JP      PO,E4E3H
3aa5 E5        PUSH    HL
3aa6 E7        RST     ContinueWhenTimerReaches0
3aa7 E9        JP      (HL)
3aa8 EB        EX      DE,HL
3aa9 EDF0      DB      EDH, F0H         ; Undocumented 8 T-State NOP
3aab AA        XOR     D
3aac 80        ADD     A,B
3aad 7B        LD      A,E
3aae 78        LD      A,B
3aaf 76        HALT    
3ab0 74        LD      (HL),H
3ab1 73        LD      (HL),E
3ab2 72        LD      (HL),D
3ab3 71        LD      (HL),C
3ab4 70        LD      (HL),B
3ab5 70        LD      (HL),B
3ab6 6F        LD      L,A
3ab7 6F        LD      L,A
3ab8 6F        LD      L,A
3ab9 70        LD      (HL),B
3aba 70        LD      (HL),B
3abb 71        LD      (HL),C
3abc 72        LD      (HL),D
3abd 73        LD      (HL),E
3abe 74        LD      (HL),H
3abf 75        LD      (HL),L
3ac0 76        HALT    
3ac1 77        LD      (HL),A
3ac2 78        LD      A,B
3ac3 AA        XOR     D
3ac4 EEF0      XOR     F0H
3ac6 DBA0      IN      A,(A0H)
3ac8 E6C8      AND     C8H
3aca D678      SUB     78H
3acc EB        EX      DE,HL
3acd F0        RET     P

3ace DBA0      IN      A,(A0H)
3ad0 E6C8      AND     C8H
3ad2 E6C8      AND     C8H
3ad4 1B        DEC     DE
3ad5 C8        RET     Z

3ad6 23        INC     HL
3ad7 A0        AND     B
3ad8 2B        DEC     HL
3ad9 78        LD      A,B
3ada 12        LD      (DE),A
3adb F0        RET     P

3adc 1B        DEC     DE
3add C8        RET     Z

3ade 23        INC     HL
3adf A0        AND     B
3ae0 12        LD      (DE),A
3ae1 F0        RET     P

3ae2 1B        DEC     DE
3ae3 C8        RET     Z


BarrelsStageData:
3ae4 02 9738 6838 (13,7)-(18,7) (Pauline's platform)
3ae9 02 9F54 1054 (12,10)-(29,10) (Straight portion of 6th platform)
3aee 02 DF58 A055 (4,11)-(11,10) (Sloped portion of 6th platform)
3af3 02 EF6D 2079 (2,13)-(27,15) (5th platform)
3af8 02 DF9A 108E (4,19)-(29,17) (4th platform)
3afd 02 EFAF 20BB (2,21)-(27,23) (3rd platform)
3b02 02 DFDC 10D0 (4,27)-(29,26) (2nd platform)
3b07 02 FFF0 80F7 (0,30)-(15,30) (1st platform - slope)
3b0c 02 7FF8 00F8 (16,31)-(31,31) (1st platform - straight)
3b11 00 CB57 CB6F (6,10)-(6,13) (0,7) (5-6 ladder - right)
3b16 00 CB99 CBB1 (6,19)-(6,22) (0,1) (3-4 ladder - right)
3b1b 00 CBDB CBF3 (6+4,27+3)-(6+4,30+3) (1-2 ladder - right)
3b20 00 6318 6354 (19+4,3+4)-(19+4,10+4) (exit ladder - right)
3b25 01 63D5 63F8 (19+4,26+5)-(19+4,31+0) (1-2 broken ladder - left)
3b2a 00 3378 3390 (25+4,15+0)-(25+4,18+0) (4-5 ladder - left)
3b2f 00 33BA 33D2
3b34 00 5318 5354
3b39 01 5392 53B8
3b3e 00 5B76 5B92
3b43 00 73B6 73D6
3b4a 00 8395 83B5
3b4d 00 9338 9354
3b52 01 BB70 BB98
3b57 01 6B54 6B75
3b5c AA



PiesStageData:
3b5d 06 8F90 7090 (14+0,18+0)-(17+7,18+0) 
3b62 06 8F98 7098 (14+0,19+0)-(17+7,19+0)
3b67 06 8FA0 70A0 (14+0,20+0)-(17+7,20+0)
3b6c 00 6318 6358
3b71 00 6380 63A8
3b76 00 63D0 63F8
3b7b 00 5318 5358
3b80 00 53A8 53D0
3b85 00 9B80 9BA8
3b8a 00 9BD0 9BF8
3b8f 01 2358 2380
3b94 01 DB58 DB80
3b99 00 2B80 2BA8
3b9e 00 D380 D3A8
3ba3 00 A3A8 A3D0
3ba8 00 2BD0 2BF8
3bad 00 D3D0 D3F8
3bb2 00 9338 9358
3bb7 02 9738 6838
3bbc 03 EF58 1058
3bc1 03 F780 8880
3bc6 03 7780 0880
3bcb 02 A7A8 50A8
3bd0 02 E7A8 B8A8
3bd5 02 3FA8 18A8
3bda 03 EFD0 10D0
3bdf 02 EFF8 10F8
3be4 AA



ElevatorsStageData:
3be5 00 6318 6358 (19+4,3+0)-(19+4,11+0)
3bea 00 6388 63D0 (19+4,17+0)-(19+4,26+0)
3bef 00 5318 5358
3bf4 00 5388 53D0
3bf9 00 E368 E390 
3bfe 00 E3B8 E3D0 
3c03 00 CB90 CBB0
3c08 00 B358 B378
3c0d 00 9B80 9BA0 
3c12 00 9338 9358 
3c17 00 2388 23C0
3c1c 00 1BC0 1BE8 
3c21 02 9738 6838
3c28 02 B758 1058
3c2b 02 EF68 E068
3c30 02 D770 C870 
3c35 02 BF78 B078
3c3a 02 A780 9080 
3c3f 02 6788 4888
3c44 02 2788 1088
3c49 02 EF90 C890
3c4e 02 A7A0 98A0
3c53 02 BFA8 B0A8
3c58 02 D7B0 C8B0
3c5d 02 EFB8 E0B8
3c62 02 27C0 10C0
3c67 02 EFD0 D8D0
3c6c 02 67D0 50D0
3c71 02 CFD8 C0D8
3c76 02 B7E0 A8E0
3c7b 02 9FE8 88E8 
3c80 02 27E8 10E8
3c85 02 EFF8 10F8
3c8a AA



RivetsStageData:
3c8b 00 7B80 7BA8 (16+4,16+0)-(16+4,21+0)
3c90 00 7BD0 7BF8 (16+4,26+0)-(16+4,31+0)
3c95 00 3358 3380
3c9a 00 5358 5380
3c9f 00 AB58 AB80
3ca4 00 CB58 CB80
3ca9 00 2B80 2BA8
3cae 00 D380 D3A8
3cb3 00 23A8 23D0
3cb8 00 5BA8 5BD0
3cbd 00 A3A8 A3D0
3cc2 00 DBA8 DBD0
3cc7 00 1BD0 1BF8
3ccc 00 E3D0 E3F8
3cd1 05 B730 4830
3cd6 05 CF58 3058
3cdb 05 D780 2880
3ce0 05 DFA8 20A8
3ce5 05 E7D0 18D0
3cea 05 EFF8 10F8
3cef AA



HeightTextTable:
3cf0 10 82 85 8B ; " 25m"
3cf4 10 85 80 8B ; " 50m"
3cf8 10 87 85 8B ; " 75m"
3cfc 81 80 80 8B ; "100m"
3d00 81 82 85 8B ; "125m"
3d04 81 85 80 8B ; "150m"
;--------------------------------- 



;--------------------------------- 
; Data describing how to draw the
; "DONKEY KONG" words on the title 
; screen.
;
; Each entry consists of a one-byte
; number of tiles to draw and a two-
; byte screen coordinate.  The tiles
; are drawn starting at the coordinate
; and moving down.
; 
; 'D'
DonkeyKongBigText:
3d08 05 8877 ; (28, 8)
3d0b 01 6877 ; (27, 8)
3d0e 01 6C77 ; (27, 12)
3d11 03 4977 ; (26, 9)
; 'O'
3d14 05 0877 
3d17 01 E876 
3d1a 01 EC76 
3d1d 05 C876 
; 'N'
3d20 05 8876 
3d23 02 6976 
3d26 02 4A76 
3d29 05 2876 
; 'K'
3d2c 05 E875 
3d2f 01 CA75 
3d32 03 A975 
3d35 01 8875 
3d38 01 8C75 
; 'E'
3d3b 05 4875 
3d3e 01 2875
3d41 01 2A75
3d44 01 2C75
3d47 01 0875
3d4a 01 0A75
3d4d 01 0C75
; 'Y'
3d50 03 C874
3d53 03 AA74
3d56 03 8874
; 'K'
3d59 05 2F77
3d5c 05 0F77
3d5f 02 F076
3d62 02 CF76
3d65 02 D276
; 'O'
3668 05 8F76
3d6b 05 6F76
3d6e 01 4F76
3d71 01 5376
3d74 05 2F76
; 'N'  
3d77 05 EF75
3d7a 02 D075
3d7d 02 B175
3d80 05 8F75
; 'G'
3d83 03 5075
3d86 05 2F75
3d89 01 0F75
3d8c 01 1375
3d8f 01 EF74
3d92 01 F174
3d95 01 F374
3d98 02 D174
3d9b 00      ; End of data
;----------------------------------
 


;----------------------------------
; The following data items are the
; default values for various game
; variables - reset before every
; stage
DefaultVariableValues:
3d9c 00 ; lLadderState = up
3d9d 00 ; lLadderDelay = 0 (maximum)
3d9e 23 ; lLadderX = 35
3d9f 68 ; lLadderY = (all the way up)
3da0 01 ; 6284H
3da1 11 ; 6285H
3da2 00 ; 6286H
3da3 00 ; 6287H
3da4 00 ; rLadderState = up
3da5 10 ; rLadderDelay = 16
3da6 DB ; rLadderX = 
3da7 68 ; rLadderY = (all the way up)
3da8 01 ; 628CH
3da9 40 ; 628DH
3daa 00 ; 628EH
3dab 00 ; 628FH
3dac 08 ; rivetsRemaining = 8
3dad 01 ; 6291H
3dae 01 ; 6292H
3daf 01 ; 6293H
3db0 01 ; 6294H
3db1 01 ; 6295H
3db2 01 ; 6296H
3db3 01 ; 6297H
3db4 01 ; 6298H
3db5 01 ; 6299H
3db6 00 ; 629AH
3db7 00 ; 629BH
3db8 00 ; 629CH
3db9 00 ; 629DH
3dba 00 ; 629EH
3dbb 00 ; 629FH
3dbc 80 ; 62A0H
3dbd 01 ; 62A1H (conveyer1Dir = 1)
3dbc C0 ; 62A2H
3dbd FF ; 62A3H (conveyer2Dir = -1)
3dc0 01 ; 62A4H
3dc1 FF ; 62A5H
3dc2 FF ; 62A6H (conveyer3Dir = -1)
3dc3 34 ; 62A7H
3dc4 C3 ; 62A8H
3dc5 39 ; 62A9H
3dc6 00 ; 62AAH
3dc7 67 ; 62ABH
3dc8 80 ; 62ACH
3dc9 69 ; 62ADH
3dca 1A ; 62AEH
3dcb 01 ; 62AFH
3dcc 00 ; 62B0H
3dcd 00 ; 62B1H
3dce 00 ; 62B2H
3dcf 00 ; 62B3H
3dd0 00 ; 62B4H
3dd1 00 ; 62B5H
3dd2 00 ; 62B6H
3dd3 00 ; 62B7H
3dd4 04 ; OilBarrelFireDelay
3dd5 00 ; OilBarrelFireState
3dd6 10 ; OilBarrelFireFlareduration
3dd7 00 ; 62BBH
3dd8 00 ; 62BCH
3dd9 00 ; 62BDH
3dda 00 ; 62BEH
3ddb 00 ; 62BFH
;----------------------------------
 


;----------------------------------
; Sprite data for the four upright
; barrels standing to DK's left in
; the barrel's stage
UprightBarrelSprites:
3ddc 1E 18 0B 4B ; Upright barrel
3de0 14 18 0B 4B ; Upright barrel
3de4 1E 18 0B 3B ; Upright barrel
3de8 14 18 0B 3B ; Upright barrel
;----------------------------------



;----------------------------------
3dec 3D 01 03 02

3df0 4D 01 04 01

3df4 277001E0
3df8 00007F40
3dfc 01780200
;----------------------------------



;----------------------------------
BarrelStageOilCanSprite:
3e00 27 49 0C F0 ; Oil can
;----------------------------------



;----------------------------------
PiesStageOilCanSprite:
3e04 7F 49 0C 88 ; Oil can
;----------------------------------



3e08 1E07      LD      E,07H
3e0a 03        INC     BC
3e0b 09        ADD     HL,BC
3e0c 24        INC     H
3e0d 64        LD      H,H
3e0e BB        CP      E
3e0f C0        RET     NZ

3e10 23        INC     HL
3e11 8D        ADC     A,L
3e12 7B        LD      A,E
3e13 B4        OR      H
3e14 1B        DEC     DE
3e15 8C        ADC     A,H
3e16 7C        LD      A,H
3e17 64        LD      H,H

3e18 4B0E0402        LD      (BC),A


;----------------------------------
PiesStageLadderSprites:
3e1c 23 46 03 68 ; Ladder sprite
3e20 DB 46 03 68 ; Ladder sprite
;----------------------------------



;----------------------------------
PiesStagePulleySprites:
3e24 17 50 00 5C ; Left conveyer pulley
3e28 E7 D0 00 5C ; Right conveyer pulley
3e2c 8C 50 00 84 ; Left conveyer pulley
3e30 73 D0 00 84 ; Right conveyer pulley
3e34 17 50 00 D4 ; Left conveyer pulley
3e38 E7 D0 00 D4 ; Right conveyer pulley
;----------------------------------



;----------------------------------
PiesStagePrizeSprites:
3e3c 53 73 0A A0 ; Pauline's hat
3e40 8B 74 0A F0 ; Pauline's purse
3e44 DB 75 0A A0 ; Pauline's umbrella
;----------------------------------



;----------------------------------
ElevatorStagePrizeSprites:
3e48 5B 73 0A C8 ; Hat
3e4c E3 74 0A 60 ; Purse
3e50 1B 75 0A 80 ; Umbrella
;----------------------------------



;----------------------------------
RivetsStagePrizeSprites:
3e54 DB 73 0A C8 ; Hat
3e58 93 74 0A F0 ; Purse
3e5c 33 75 0A 50 ; Umbrella
;----------------------------------



3e60 44        LD      B,H
3e61 03        INC     BC
3e62 08        EX      AF,AF'
3e63 04        INC     B
3e64 37        SCF     
3e65 F437C0    CALL    P,C037H
3e68 37        SCF     
3e69 8C        ADC     A,H
3e6a 77        LD      (HL),A
3e6b 70        LD      (HL),B
3e6c 77        LD      (HL),A
3e6d A4        AND     H
3e6e 77        LD      (HL),A
3e6f D8        RET     C



;----------------------------------
; passed: A = (pointAwardType) rotated right
;            1 bit
; return: DE - function call to pass
;            to the AddFunctionToUpdateList
;            function
;            (0001H = award 100 points
;             0003H = award 300 points
;             0005H = award 500 points)
;         B - the point sprite to display
AwardSelectedPoints:
3e70 110100    LD      DE,0001H    ; If (pointAwardType) == 1 
3e73 067B      LD      B,7BH       ;    award 100 points
3e75 1F        RRA                 ;    ''
3e76 D2281E    JP      NC,DisplaySpriteRelativeCoord 

3e79 1E03      LD      E,03H       ; If (pointAwardType) == 3
3e7b 067D      LD      B,7DH       ;    award 300 points
3e7d 1F        RRA                 ;    ''
3e7e D2281E    JP      NC,DisplaySpriteRelativeCoord

; NOTE: There appears to be a bug here
;       500 points are awarded, but the
;       800 point sprite is displayed
;       (E is set to 5 = 500 points,
;       B is set to 7FH = 800 point sprite)
3e81 1E05      LD      E,05H       ; If (pointAwardType) == 5
3e83 067F      LD      B,7FH       ;    award 500 points
3e85 C3281E    JP      DisplaySpriteRelativeCoord
;----------------------------------



;----------------------------------
3e88 3A2762    LD      A,(currentStage)
3e8b E5        PUSH    HL
3e8c EF        RST     JumpToLocalTableAddress
3e8d 0000 ; 0000h
3e8f 993E ; 3e99h
3e91 B028 ; 28b0h
3e93 E028 ; 28e0h
3e95 0129 ; 2901h
3e97 0000 ; 0000h
;----------------------------------



;----------------------------------   
3e99 E1        POP     HL
3e9a AF        XOR     A
3e9b 326060    LD      (6060H),A
3e9e 060A      LD      B,0AH
3ea0 112000    LD      DE,0020H
3ea3 DD210067  LD      IX,6700H
3ea7 CDC33E    CALL    3EC3H
3eaa 0605      LD      B,05H
3eac DD210064  LD      IX,6400H
3eb0 CDC33E    CALL    3EC3H
3eb3 3A6060    LD      A,(6060H)
3eb6 A7        AND     A
3eb7 C8        RET     Z

3eb8 FE01      CP      01H
3eba C8        RET     Z

3ebb FE03      CP      03H
3ebd 3E03      LD      A,03H
3ebf D8        RET     C

3ec0 3E07      LD      A,07H
3ec2 C9        RET     

3ec3 DDCB0046  BIT     0,(IX+00H)
3ec7 CAFA3E    JP      Z,3EFAH
3eca 79        LD      A,C
3ecb DD9605    SUB     (IX+05H)
3ece D2D33E    JP      NC,3ED3H
3ed1 ED44      NEG     
3ed3 3C        INC     A
3ed4 95        SUB     L
3ed5 DADE3E    JP      C,3EDEH
3ed8 DD960A    SUB     (IX+0AH)
3edb D2FA3E    JP      NC,3EFAH
3ede FD7E03    LD      A,(IY+03H)
3ee1 DD9603    SUB     (IX+03H)
3ee4 D2E93E    JP      NC,3EE9H
3ee7 ED44      NEG     
3ee9 94        SUB     H
3eea DAF33E    JP      C,3EF3H
3eed DD9609    SUB     (IX+09H)
3ef0 D2FA3E    JP      NC,3EFAH
3ef3 3A6060    LD      A,(6060H)
3ef6 3C        INC     A
3ef7 326060    LD      (6060H),A
3efa DD19      ADD     IX,DE
3efc 10C5      DJNZ    3EC3H
3efe C9        RET     

3eff 00        NOP   


;----------------------------------
; "©1981"
3f00 5C76 ; (18, 28)
3f02 494A010908013F

; "NINTENDO OF AMERICA"
3f09 7D77 ; (27, 29)
3f0b 1E
Label3F0C:
3f0c 191E24151E141F101F161111D152219131110191E132B3F
;----------------------------------



;----------------------------------
; Display (TM)
DisplayTM:
3f24 21AF74    LD      HL,74AFH    ; HL = (5, 15)
3f27 11E0FF    LD      DE,FFE0H    ; DE = -32
3f2a 369F      LD      (HL),9FH    ; Display '(T'
3f2c 19        ADD     HL,DE       ; HL = (4, 15)
3f2d 369E      LD      (HL),9EH    ; Display 'M)'
3f2f C9        RET     
;----------------------------------



;----------------------------------
3f30 50        LD      D,B
3f31 52        LD      D,D
3f32 4F        LD      C,A
3f33 47        LD      B,A
3f34 52        LD      D,D
3f35 41        LD      B,C
3f36 4D        LD      C,L
3f37 2C        INC     L
3f38 57        LD      D,A
3f39 45        LD      B,L
3f3a 2057      JR      NZ,3F93H
3f3c 4F        LD      C,A
3f3d 55        LD      D,L
3f3e 4C        LD      C,H
3f3f 44        LD      B,H
3f40 2054      JR      NZ,3F96H
3f42 45        LD      B,L
3f43 41        LD      B,C
3f44 43        LD      B,E
3f45 48        LD      C,B
3f46 2059      JR      NZ,3FA1H
3f48 4F        LD      C,A
3f49 55        LD      D,L
3f4a 2E2A      LD      L,2AH
3f4c 2A2A2A    LD      HL,(2A2AH)
3f4f 2A5445    LD      HL,(4554H)
3f52 4C        LD      C,H
3f53 2E54      LD      L,54H
3f55 4F        LD      C,A
3f56 4B        LD      C,E
3f57 59        LD      E,C
3f58 4F        LD      C,A
3f59 2D        DEC     L
3f5a 4A        LD      C,D
3f5b 41        LD      B,C
3f5c 50        LD      D,B
3f5d 41        LD      B,C
3f5e 4E        LD      C,(HL)
3f5f 2030      JR      NZ,3F91H
3f61 34        INC     (HL)
3f62 34        INC     (HL)
3f63 2832      JR      Z,3F97H
3f65 34        INC     (HL)
3f66 34        INC     (HL)
3f67 29        ADD     HL,HL
3f68 323135    LD      (3531H),A
3f6b 312020    LD      SP,2020H
3f6e 2020      JR      NZ,3F90H
3f70 45        LD      B,L
3f71 58        LD      E,B
3f72 54        LD      D,H
3f73 45        LD      B,L
3f74 4E        LD      C,(HL)
3f75 54        LD      D,H
3f76 49        LD      C,C
3f77 4F        LD      C,A
3f78 4E        LD      C,(HL)
3f79 2033      JR      NZ,3FAEH
3f7b 3034      JR      NC,3FB1H
3f7d 2020      JR      NZ,3F9FH
3f7f 2053      JR      NZ,3FD4H
3f81 59        LD      E,C
3f82 53        LD      D,E
3f83 54        LD      D,H
3f84 45        LD      B,L
3f85 4D        LD      C,L
3f86 2044      JR      NZ,3FCCH
3f88 45        LD      B,L
3f89 53        LD      D,E
3f8a 49        LD      C,C
3f8b 47        LD      B,A
3f8c 4E        LD      C,(HL)
3f8d 2020      JR      NZ,3FAFH
3f8f 2049      JR      NZ,3FDAH
3f91 4B        LD      C,E
3f92 45        LD      B,L
3f93 47        LD      B,A
3f94 41        LD      B,C
3f95 4D        LD      C,L
3f96 49        LD      C,C
3f97 2043      JR      NZ,3FDCH
3f99 4F        LD      C,A
3f9a 2E20      LD      L,20H
3f9c 4C        LD      C,H
3f9d 49        LD      C,C
3f9e 4D        LD      C,L
3f9f 2E


;----------------------------------
Label3FA0:
3fa0 CDA63F    CALL    DisplayPiesLadders
3fa3 C35F0D    JP      Label0D5F
;----------------------------------



;----------------------------------
; If the currentStage is the pies
; level (2), draw the ladders for
; that level, otherwise return
; immediately.
DisplayPiesLadders:
3fa6 3E02      LD      A,02H       ; Abort unless currentStage == 2 (pies)
3fa8 F7        RST     ReturnUnlessStageOfInterest
3fa9 0602      LD      B,02H       ; For B = 2 to 1
3fab 216C77    LD      HL,776CH    ; HL = (27,12)
3fae 3610      LD      (HL),10H    ; Display ' ' at HL
3fb0 23        INC     HL          ; HL += 2 rows
3fb1 23        INC     HL          ;    ''
3fb2 36C0      LD      (HL),C0H    ; Display ladder at HL
3fb4 218C74    LD      HL,748CH    ; HL = (4,12)
3fb7 10F5      DJNZ    3FAEH       ; Next B
3fb9 C9        RET     
;----------------------------------

3fba 00        NOP     
3fbb 00        NOP     
3fbc 00        NOP     
3fbd 00        NOP     
3fbe 00        NOP     
3fbf 00        NOP     


;----------------------------------
; Called when Mario starts climbing
; a ladder
; Set Mario's sprite to the climbing
; sprite and returns the address of 
; marioSpriteY
;
; passed: none
; return:  marioSpriteY in HL
3fc0 214D69    LD      HL,marioSpriteNum
3fc3 3603      LD      (HL),03H
3fc5 2C        INC     L
3fc6 2C        INC     L
3fc7 C9        RET   
;----------------------------------

  

;----------------------------------
3fc8 00        NOP     
3fc9 00        NOP     
3fca 41        LD      B,C
3fcb 7F        LD      A,A
3fcc 7F        LD      A,A
3fcd 41        LD      B,C
3fce 00        NOP     
3fcf 00        NOP     
3fd0 00        NOP     
3fd1 7F        LD      A,A
3fd2 7F        LD      A,A
3fd3 183C      JR      4011H
3fd5 76        HALT    
3fd6 63        LD      H,E
3fd7 41        LD      B,C
3fd8 00        NOP     
3fd9 00        NOP     
3fda 7F        LD      A,A
3fdb 7F        LD      A,A
3fdc 49        LD      C,C
3fdd 49        LD      C,C
3fde 49        LD      C,C
3fdf 41        LD      B,C
3fe0 00        NOP     
3fe1 1C        INC     E
3fe2 3E63      LD      A,63H
3fe4 41        LD      B,C
3fe5 49        LD      C,C
3fe6 79        LD      A,C
3fe7 79        LD      A,C
3fe8 00        NOP     
3fe9 7C        LD      A,H
3fea 7E        LD      A,(HL)
3feb 13        INC     DE
3fec 11137E    LD      DE,7E13H
3fef 7C        LD      A,H
3ff0 00        NOP     
3ff1 7F        LD      A,A
3ff2 7F        LD      A,A
3ff3 0E1C      LD      C,1CH
3ff5 0E7F      LD      C,7FH
3ff7 7F        LD      A,A
3ff8 00        NOP     
3ff9 00        NOP     
3ffa 41        LD      B,C
3ffb 7F        LD      A,A
3ffc 7F        LD      A,A
3ffd 41        LD      B,C
3ffe 00        NOP     
3fff 00        NOP     
