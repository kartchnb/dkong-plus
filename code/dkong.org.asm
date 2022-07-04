; Disassembly of the file "dkong.bin"
; 
; CPU Type: Z80
; 
; Created with dZ80 2.0
; 
; on Saturday, 12 of February 2011 at 07:37 AM
; 

#include "vars.h"

		.org	$00
		
;------------------------------------------------------------------------------
; Program entry point
L_ORG:  ld      a,0                       ; Disable interrupts
        ld      (INTERRUPT_ENABLE),a        ; ''
        jp      L_INIT_GAME                       ; Initialize the game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check if demo mode is active (no coins have been inserted).  
; If it is, abort the calling function        
; Note: This code MUST start at address 0008h.
		.org	$08
l0008:  ld      a,(NO_COINS_INSERTED)
        rrca    
        ret     nc							; Return if NO_COINS_INSERTED == 0
        inc     sp		
        inc     sp							; Return from calling function otherwise
        ret     						
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Check if Mario is dead.  If he is, abort the calling function
; NOTE: This code MUST start at address 0010h.
		.org	$10
l0010:  ld      a,(MARIO_ALIVE)
        rrca    							; Return if MARIO_ALIVE == 1
        ret     c
        inc     sp
        inc     sp							; Return from calling function otherwise
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Decrement the minor timer.  If it has not reached 0, abort the calling function
		.org $18
l0018:  ld      hl,MINOR_TIMER				; -- MINOR_TIMER
        dec     (hl)
        ret     z							; Return if MINOR_TIMER has reached 0
        inc     sp
        inc     sp							; Return from the calling function otherwise
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Decrement the major timer.  If it has not reached 0, abort the calling function
; If it has reached 0, decrement MINOR_TIMER and return from the calling function 
; if it has not reached 0.
; NOTE: This function MUST start at address $0020
		.org	$20
        ld      hl,MAJOR_TIMER
        dec     (hl)						; --MAJOR_TIMER
        jr      z,l0018
l0026:  pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Retrieve an address in a jump table immediately following the instruction
; that called this function and jump to the address.
; NOTE: This function MUST start at address 0028h.
;
; passed: a - the table index to jump to 
        .org    $28
        add     a,a							; A *= 2
        pop     hl							; HL = the address of the instruction that called this function
        ld      e,a							
        ld      d,$00						; DE = table index offset
        jp      l0032						; Skip the next instruction
		
; The following instruction is not part of the previous function
; NOTE: This instruction MUST be at address $0030		
		.org	$30
        jr      l0044
		
l0032:  add     hl,de						; HL = address of table entry
        ld      e,(hl)						
        inc     hl
        ld      d,(hl)
        ex      de,hl						; HL = entry in table
        jp      (hl)						; Jump to the address
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Move the 10 sprites that make up Donkey Kong either horizontally or
; vertically by adding the amount in c to every 4th byte starting at the
; address in hl.
;
; NOTE: This function MUST start at address 0038h.
;
; passed: 	hl - the address of the first sprites x or y coord
;			c - the amount to move the sprite 
		.org $38
l0038:  ld      de,4
        ld      b,10
L_MOVE_N_SPRITES:  
		ld      a,c
        add     a,(hl)
        ld      (hl),a
        add     hl,de
        djnz    L_MOVE_N_SPRITES
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Return from the calling function unless the stage is one of the stages of 
; interest.
; Checks if the bit in a corresponding to the current stage is set.  This
; allows multiple stages to be checked for.
; passed:	a - the stage bit mask
l0044:  ld      hl,CURRENT_STAGE
        ld      b,(hl)
l0048:  rrca    
        djnz    l0048
        ret     c
        pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Copy Donkey Kong sprites from a ROM address into the Donkey Kong sprite 
; memory
; passed:  hl - source address
L_LOAD_DK_SPRITES:  
		ld      de,DK_SPRITE_1_X
        ld      bc,40   
        ldir    
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Update the random number by adding the values of the two counters to the 
; current random number
; 
; passed:	none
; return:	a - random number
;			hl - COUNTER_1 
L_UPDATE_RAND_NUM:  ld      a,(RANDOM_NUMBER)
        ld      hl,COUNTER_2
        add     a,(hl)
        ld      hl,COUNTER_1
        add     a,(hl)
        ld      (RANDOM_NUMBER),a
        ret 
;------------------------------------------------------------------------------
    
		

;------------------------------------------------------------------------------
; Interrupt handler
; Called periodically to update the game state		
		.org	$66
L_INTERRUPT_HANDLER:  
		; Push the registers onto the stack
		push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy
		
        xor     a
        ld      (INTERRUPT_ENABLE),a		; Disable interrupts
		
        ld      a,(MISC_INPUT)					; If bit 0 of INPUT2 is 0, abort the game 
        and     1
        jp      nz,l4000
		
; Configure the P8257		
        ld      hl,L_P8257_REGISTER_DATA
        call    L_CONFIG_P8257
		
		; Skip player handling if no coin has been inserted (attract mode is active)
        ld      a,(NO_COINS_INSERTED)
        and     a
        jp      nz,l00b5
		
		; Ignore player 2 input if this is an upright cabinet
        ld      a,(CABINET_TYPE)
        and     a
        jp      nz,l0098
		
		; If player 2 is active, get player 2 input
        ld      a,(SECOND_PLAYER)
        and     a
        ld      a,(P2_INPUT)
        jp      nz,l009b
		
		; Get player 1 input
l0098:  ld      a,(P1_INPUT)

		; Read the input and save the old input in PLAYER_INPUT_LAG
l009b:  ld      b,a
        and     $0f
        ld      c,a
        ld      a,(PLAYER_INPUT_LAG)
        cpl     
        and     b
        and     $10
        rla     
        rla     
        rla     
        or      c
        ld      h,b
        ld      l,a
        ld      (PLAYER_INPUT),hl		; Save player input and player input lag
		
		; Reset the game if the reset input bit is set
        ld      a,b
        bit     6,a
        jp      nz,L_ORG
		
		; Decrement COUNTER_2 on every interrupt
l00b5:  ld      hl,COUNTER_2
        dec     (hl)
		
        call    L_UPDATE_RAND_NUM		; Update the random number
        call    L_CHECK_FOR_COIN		; Check for coins
        call    L_PLAY_SOUNDS			; Play sounds
        
		; Make sure registers are popped from the stack after the next function
		ld      hl,L_POP_REGISTERS_FROM_STACK				
        push    hl
		
		; Jump to a function based on the current game state
        ld      a,(GAME_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_INIT_ATTRACT_MODE ; 0 = Prepare attract mode
		.word	L_IMPLEMENT_ATTRACT_MODE ; 1 = Implement attract mode
		.word	L_WAITING_FOR_START_MODE	; 2 = Start game
		.word	L_IMPLEMENT_GAME_PLAY	; 3 = Display current game screen
;------------------------------------------------------------------------------


        
;------------------------------------------------------------------------------
; Pop the registers from the stack
L_POP_REGISTERS_FROM_STACK:  
		pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        ld      a,$01
        ld      (INTERRUPT_ENABLE),a
        pop     af
        ret 
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Play sounds if not in attract mode
L_PLAY_SOUNDS:  
		ld      hl,WALK_SOUND_TRIGGER
        ld      de,WALK_SOUND_OUTPUT
		
		; Don't play sounds if attract mode is active
        ld      a,(NO_COINS_INSERTED)
        and     a
        ret     nz

		; Pass each sound trigger to the sound chip
        ld      b,8				; For b = 8 to 1
l00ed:  ld      a,(hl)			; a > 0 if the current sound should be played
        and     a
		
		; If this sound has not been triggered, jump ahead
        jp      z,l00f5		
		
        dec     (hl)			; Decrement the sound trigger value
        ld      a,1
l00f5:  ld      (de),a			; Turn the sound on or off
        inc     e				; Advance to the next sound and trigger
        inc     l
        djnz    l00ed			; Next b
		
		; If the current song needs to be triggered, jump ahead
        ld      hl,PENDING_SONG_TRIGGER_REPEAT
        ld      a,(hl)
        and     a
        jp      nz,l0108
		
		; Set or clear the SONG_TRIGGER
        dec     l
        dec     l
        ld      a,(hl)
        jp      l010b
		
		; Turn on the song trigger
l0108:  dec     (hl)
        dec     l
        ld      a,(hl)
		
		; Turn on or off the song
l010b:  ld      (SONG_OUTPUT),a
        
		; If the death sound is not playing, jump ahead
		ld      hl,DEATH_SOUND_TRIGGER
        xor     a				; a = 0
        cp      (hl)
        jp      z,l0118
		
		; Decrement the death sound counter to not trigger the sound
        dec     (hl)
        inc     a				; a = 1
		
		; Trigger or turn off the death sound
l0118:  ld      (DEATH_SOUND_OUTPUT),a
        ret   
;------------------------------------------------------------------------------
  


;------------------------------------------------------------------------------
; Turn off all sounds 
L_SOUNDS_OFF:  
		; All sound triggers and sound outputs
		ld      b,8		; For b = 8 to 1
        xor     a			; a = 0
        ld      hl,WALK_SOUND_OUTPUT
        ld      de,WALK_SOUND_TRIGGER
l0125:  ld      (hl),a
        ld      (de),a
        inc     l
        inc     e
        djnz    l0125		; Next b

		; Clear ($7d08-$7d0c)
        ld      b,4		; For b = 4 to 1
l012d:  ld      (de),a
        inc     e
        djnz    l012d		; Next b

		; Clear song outputs
        ld      (DEATH_SOUND_OUTPUT),a
        ld      (SONG_OUTPUT),a
        ret     
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; P8257 control register settings
L_P8257_REGISTER_DATA:
		.byte	$53		; Sent to $7808
		.byte	$00		; Sent to $7800
		.byte	$69		; Sent to $7800
		.byte	$80		; Sent to $7801
		.byte	$41		; Sent to $7801
		.byte	$00		; Sent to $7802
		.byte	$70		; Sent to $7802
		.byte	$80		; Sent to $7803
		.byte	$81		; Send to $7803
;------------------------------------------------------------------------------

		

;------------------------------------------------------------------------------
; Set P8257 control registers
; passed:	hl - set to point to L_P8257_REGISTER_DATA
L_CONFIG_P8257:  xor     a
        ld      ($7d85),a
        ld      a,(hl)
        ld      ($7808),a
        inc     hl
        ld      a,(hl)
        ld      ($7800),a
        inc     hl
        ld      a,(hl)
        ld      ($7800),a
        inc     hl
        ld      a,(hl)
        ld      ($7801),a
        inc     hl
        ld      a,(hl)
        ld      ($7801),a
        inc     hl
        ld      a,(hl)
        ld      ($7802),a
        inc     hl
        ld      a,(hl)
        ld      ($7802),a
        inc     hl
        ld      a,(hl)
        ld      ($7803),a
        inc     hl
        ld      a,(hl)
        ld      ($7803),a
        ld      a,$01
        ld      ($7d85),a
        xor     a
        ld      ($7d85),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for and handle coin insertion
L_CHECK_FOR_COIN:  
		ld      a,(MISC_INPUT)
        bit     MISC_INPUT_COIN_BIT,a
        ld      hl,COIN_VALID
		; Jump ahead if a coin is being insered
        jp      nz,l0189
		
		; Mark the next coin insertion as valid
        ld      (hl),1
        ret     

		; Return if this coin has already been registered
l0189:  ld      a,(hl)
        and     a
        ret     z
		
        push    hl					; Save COIN_VALID address to the stack
		
		; If the player is playing skip sound stuff
        ld      a,(GAME_STATE)
        cp      GAME_STATE_PLAY
        jp      z,l019d
		
        call    L_SOUNDS_OFF		; Turn off all sounds
		
		; Trigger coin insertion sound
        ld      a,3
        ld      (SPRING_SOUND_TRIGGER),a
		
		; Mark this coin insertion as invalid so that it is not reprocessed
l019d:  pop     hl					; Restore COIN_VALID address from the stack
        ld      (hl),$00

		; Add this coin to the coins waiting to be processed
		dec     hl					; hl = NUM_COINS_PENDING
        inc     (hl)
		
		; Return if there are not enough coins for one credit
        ld      de,DIP_COINS_PER_CREDIT
        ld      a,(de)
        sub     (hl)
        ret     nz
		
		; Convert coins to credits
        ld      (hl),a				; Spend all the pending coins
        inc     de					; de = DIP_PLAYS_PER_CREDIT
        dec     hl					; hl = NUM_PLAYS
        ex      de,hl				
        ld      a,(de)
		
		; Return if 90 credits have been paid for (the max that can be handled)
        cp      $90
        ret     nc
		
		; Add the number of plays that have been earned for the credits that have been paid for
        add     a,(hl)
        daa     					; Adjust a to BCD digits
        ld      (de),a				; Save the number of plays
		
		; Update the number of plays that are displayed
        ld      de,$0400
        call    L_ADD_EVENT
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The default initial score values
L_INITIAL_SCORE_DATA:
		.byte	$00, $37, $00	; Player 1 score = 003700
		.byte	$aa, $aa, 		; Player 2 score = blank
L_BLANK_SCORE_DATA:	; The $aa bytes display a blank score
			.byte $aa
		.byte	$50, $76, $00	; High score = 007650
;------------------------------------------------------------------------------
		


;------------------------------------------------------------------------------
; Initialize the attract mode
L_INIT_ATTRACT_MODE:  
		call    L_CLEAR_STAGE_SCREEN

		; Load the initially displayed scores from ROM
        ld      hl,L_INITIAL_SCORE_DATA
        ld      de,PREV_P1_SCORE
        ld      bc,9
        ldir    
		
		; Initialize the attract mode
        ld      a,1
        ld      (NO_COINS_INSERTED),a					; In attract mode, waiting for coins
        ld      (CP_LEVEL_NUMBER),a						; Level 1
        ld      (CP_NUMBER_LIVES),a						; 1 life
		
        call    L_DISPLAY_LIVES_AND_LEVEL									; Display lives and level
        call    L_LOAD_DIP_SETTINGS

        ld      a,1
        ld      (SCREEN_ORIENTATION),a					; Orient the screen normally
        ld      (GAME_STATE),a							; In attract mode
        ld      (CURRENT_STAGE),a								; Starting on the barrels stage

        xor     a
        ld      (GAME_SUBSTATE),a						; Displaying the coin entry screen
        call    L_DISPLAY_1UP
        ld      de,$0304
        call    L_ADD_EVENT							; Display "HIGH SCORE"
        ld      de,$0202
        call    L_ADD_EVENT							; Display the high score
        ld      de,$0200
        call    L_ADD_EVENT							; Display player 1's score
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Load DIP settings and default high score table
L_LOAD_DIP_SETTINGS:  
		; Read the number of lives setting
		ld      a,(DIP_INPUT)
        ld      c,a
        ld      hl,DIP_NUM_LIVES
        and     %00000011
        add     a,3
        ld      (hl),a

		; Read the bonus life setting
        inc     hl
        ld      a,c
        rrca    
        rrca    
        and     %00000011
        ld      b,a
        ld      a,7
        jp      z,l0226
        ld      a,5
l0221:  add     a,5
        daa     
        djnz    l0221
l0226:  ld      (hl),a

		; 
        inc     hl
        ld      a,c
        ld      bc,$0101
        ld      de,$0102
        and     %01110000
        rla     
        rla     
        rla     
        rla     
        jp      z,l0247
        jp      c,l0241
        inc     a
        ld      c,a
        ld      e,d
        jp      l0247
l0241:  add     a,2
        ld      b,a
        ld      d,a
        add     a,a
        ld      e,a
l0247:  ld      (hl),d

        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),b
        inc     hl
        ld      (hl),c
        inc     hl

		; Read the cabinet type
        ld      a,(DIP_INPUT)
        rlca    
        ld      a,1
        jp      c,l0259
        dec     a
l0259:  ld      (hl),a

		; Load the default high score table
        ld      hl,L_DEFAULT_HIGH_SCORE_DATA
        ld      de,HIGH_SCORE_TABLE
        ld      bc,170
        ldir    
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialization code
L_INIT_GAME:  
		; Clear 4096 bytes of RAM ($6000 to $6FFF) to $00        
		ld      b,16			
        ld      hl,$6000
        xor     a
l026c:  ld      c,a
l026d:  ld      (hl),a
        inc     hl
        dec     c
        jr      nz,l026d
        djnz    l026c
        
		; Clear 1024 bytes of RAM ($7000 to $73ff) to $00        
        ld      b,4
        ld      hl,$7000
l0279:  ld      c,a
l027a:  ld      (hl),a
        inc     hl
        dec     c
        jr      nz,l027a
        djnz    l0279
        
		; Clear 1024 bytes of tile RAM ($7400 to $77ff) to $10 (blank space character)
        ld      b,4
        ld      a,$10
        ld      hl,TILE_COORD(0,0)
l0288:  ld      c,0
l028a:  ld      (hl),a
        inc     hl
        dec     c
        jr      nz,l028a
        djnz    l0288
        
		; Clear 64 byte circular event buffer ($60c0 to $60ff) to $ff (invalid value)    
		; Can hold 32 events with their parameters
        ld      hl,$60c0
        ld      b,64
        ld      a,$ff
l0298:  ld      (hl),a
        inc     hl
        djnz    l0298
        
		; Initialize the circular event buffer write pointer to $c0 ($60c0)
        ld      a,$c0
        ld      (ACTION_BUFFER_WRITE_POS),a
        ld      (ACTION_BUFFER_READ_POS),a
        
		; Initialize the display palette to 00
        xor     a
        ld      ($7d83),a   ; ($7d83) = 0
        ld      (PALETTE_1_OUTPUT),a 
        ld      (PALETTE_2_OUTPUT),a

		; Initialize the screen orientation
        inc     a
        ld      (SCREEN_ORIENTATION),a   ; (SCREEN_ORIENTATION) = 1

		; Initialize the stack
        ld      sp,$6c00    ; Stack starts at $6c00

		; Turn off sounds
        call    L_SOUNDS_OFF       ; Turn off sounds and music

		; Reenable interrupts
        ld      a,1       
        ld      (INTERRUPT_ENABLE),a    ; Reenable interrupts
; End of initialization
;------------------------------------------------------------------------------
        


;------------------------------------------------------------------------------
; Main program loop
; Checks if there are events waiting in the event buffer and processes them
; until the buffer is empty.
L_MAIN_LOOP:  
		; Check for actions in the action buffer
		ld      h,$60
        ld      a,(ACTION_BUFFER_READ_POS)   ; A = (readPtr)
        ld      l,a
        ld      a,(hl)
		
		; Double a to turn it into a 2-byte offset
        add     a,a
        jr      nc,L_PROCESS_ACTION_BUFFER    ; If A is a valid buffer byte, jump ahead (skipping 'nUp' display and timer incrementing)
        
		call    L_DISPLAY_NUP ; Flash the current player's 'nUp' line
        call    L_AWARD_BONUS_LIFE ; Pre-turn stuff: Award bonus life, display lives and level number
        ld      hl,COUNTER_1
        inc     (hl)        ; ++counter2
        ld      hl,$6383
        ld      a,(COUNTER_2)
        cp      (hl)
        jr      z,L_MAIN_LOOP
        ld      (hl),a
        call    L_INCREASE_DIFFICULTY
        call    L_IMPLEMENT_BARREL_FIRE
        jr      L_MAIN_LOOP
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Process actions from the action buffer
;
; passed:	a - the offset of the action function to jump to in 
;				the table below
;			hl - pointer to the location of the action buffer read
;				position
L_PROCESS_ACTION_BUFFER:  
		; Parse the action jump table index
		and     %00011111
        ld      e,a
        ld      d,$00
        ld      (hl),$ff					; Clear this action

		; Read the action parameter
        inc     l
        ld      c,(hl)
        ld      (hl),$ff					; Clear this parameter

		; Advance the action buffer read pointer (wrapping around if needed)
        inc     l
        ld      a,l
        cp      $c0
        jr      nc,l02f6
        ld      a,$c0
l02f6:  ld      (ACTION_BUFFER_READ_POS),a

        ld      a,c							; a = action parameter

		; Make sure execution returns to the main loop after the action is processed
        ld      hl,L_MAIN_LOOP
        push    hl

		; Jump to the correct offset in the jump table below
        ld      hl,l0307
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        jp      (hl)

        ; Jump table
l0307   .word   L_AWARD_POINTS ; 0 = Award points
        .word   L_ZERO_SCORES ; 1 = Clear scores
        .word   L_DISPLAY_SCORES ; 2 = Display all scores
        .word   L_DISPLAY_STRING ; 3 = Display string
        .word   L_DISPLAY_CREDITS ; 4 = Display the number of credits
        .word   L_PROCESS_TIMER ; 5 = Display timer
        .word   L_DISPLAY_LIVES_AND_LEVEL ; 6 = Display lives and level
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display "1UP" and "2UP" (if two players are playing)
; The string for the current player is flashed
L_DISPLAY_NUP:  
		; Only proceed once every 16 counter cycles
		ld      a,(COUNTER_2)
        ld      b,a
        and     $0f
        ret     nz

		; Abort if in attract mode
        rst     $08

		; Get the coordinate for this player's "nUP" string
        ld      a,(CURRENT_PLAYER)
        call    L_RETURN_NUP_COORD

		; Display the "nUP" line every other time
		; (on for 16 cycles, off for 16 cycles)
        ld      de,-32
        bit     4,b
        jr      z,l033e					; Display "1UP" or "2UP"

		; Clear the "nUP" string
        ld      a,$10
        ld      (hl),a
        add     hl,de
        ld      (hl),a
        add     hl,de
        ld      (hl),a

		; If two players, display the other "nUP" line without blinking
        ld      a,(TWO_PLAYERS)
        and     a
        ret     z
        ld      a,(CURRENT_PLAYER)
        xor     $01							; a = inactive player
        call    L_RETURN_NUP_COORD			; Get coordinate of inactive player's "nUP" line

		; Display "1UP" or "2UP'
l033e:  inc     a							; Convert player ID (0 or 1) to player number (1 or 2)
        ld      (hl),a
        add     hl,de						; Move 1 column right
        ld      (hl),$25					; 'U'
        add     hl,de						; Move 1 column right
        ld      (hl),$20					;'P'
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Return the coordinate of either "1UP" (a = 0) or "2UP" (a = 1)
;
; passed:	a - 0 (player 1) or 1 (player 2)
L_RETURN_NUP_COORD:  
		ld      hl,TILE_COORD(26,0)
        and     a
        ret     z
        ld      hl,TILE_COORD(7,0)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Handle awarding bonus life
L_AWARD_BONUS_LIFE:  
		; Return if the player has already received a bonus life
		ld      a,(CP_BONUS_LIFE_AWARDED)
        and     a
        ret     nz

		; Get the 2nd and 3rd digits of the player's score
        ld      hl,PREV_P1_SCORE+1
        ld      a,(CURRENT_PLAYER)
        and     a
        jr      z,l0361
        ld      hl,PREV_P2_SCORE+1
l0361:  ld      a,(hl)
        and     $f0
        ld      b,a							; b = 3rd digit of current player's score
        inc     hl
        ld      a,(hl)
        and     $0f							; a = 2nd digit of current player's score
        or      b
        rrca    
        rrca    
        rrca    
        rrca    							; a = 2nd and 3rd digits of current player's score

		; Return if the player has not earned an extra life
        ld      hl,DIP_BONUS_LIFE
        cp      (hl)
        ret     c

		; Award a bonus life
        ld      a,$01
        ld      (CP_BONUS_LIFE_AWARDED),a
        ld      hl,CP_NUMBER_LIVES
        inc     (hl)
        jp      L_DISPLAY_LIVES_AND_LEVEL
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Increment the minor and major counters
; The difficulty starts out equal to the level number and increases by 1 every 2048 
; counter cycles to a maximum of 5.
L_INCREASE_DIFFICULTY:  
		; Increment the minor counter
		ld      hl,MINOR_COUNTER
        ld      a,(hl)
        inc     (hl)

		; Return if the minor counter has not rolled over
        and     a
        ret     nz

		; Increment the major counter
        ld      hl,MAJOR_COUNTER
        ld      a,(hl)
        ld      b,a
        inc     (hl)

		; Return if the 3 LSBs have not rolled over
        and     %00000111
        ret     nz

		; Isolate the 5 MSBs
        ld      a,b
        rrca    
        rrca    
        rrca    
        ld      b,a

		; Increase the difficulty level to a maximum or 5
        ld      a,(CP_LEVEL_NUMBER)
        add     a,b
        cp      5
        jr      c,l039e
        ld      a,5
l039e:  ld      (CP_DIFFICULTY),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Handle the barrel fire animation on the barrels and mixer levels.  This 
; includes displaying the initial flare up when an oil barrel is thrown and
; the normal burning afterwards.
L_IMPLEMENT_BARREL_FIRE:  
		ld      a,%0011
        rst     $30							; Return unless this is the barrels stage or mixer stage
        ; Return if Mario is dead
        rst     $10

		; Return if the smash animation is playing
        ld      a,(SMASH_ANIMATION_ACTIVE)
        rrca    
        ret     c

		; Return if it is not time to update the barrel fire
        ld      hl,BARREL_FIRE_FREEZE
        dec     (hl)
        ret     nz

		; Reset the barrel fire delay to 4
        ld      (hl),4

		; Return if the oil barrel is not burning
        ld      a,(BARREL_FIRE_STATE)
        rrca    
        ret     nc

		; Prepare the sprite
        ld      hl,BARREL_FIRE_SPRITE_NUM
        ld      b,$40						; Basic fire sprite
        ld      ix,BARREL_FIRE_STRUCT
		
		; If the barrel fire is not in its initial flare up, jump ahead
        rrca    
        jp      nc,l03e4
		
		; Display the flared up barrel fire sprite
        ld      (ix+9),2
        ld      (ix+10),2
        inc     b
        inc     b							; b = $42, the first flared up sprite
        call    L_TOGGLE_FIRE_SPRITES
		
		; Return if the flare up time has not run out
        ld      hl,BARREL_FIRE_FLARE_UP_TIME
        dec     (hl)
        ret     nz

		; The barrel fire is now burning normally
        ld      a,1
        ld      (BARREL_FIRE_STATE),a
        ld      (RELEASE_A_FIREBALL),a
l03de:  ld      a,16
        ld      (BARREL_FIRE_FLARE_UP_TIME),a
        ret     

		; Display the normal barrel fire sprite
l03e4:  ld      (ix+9),2
        ld      (ix+10),0
        call    L_TOGGLE_FIRE_SPRITES
        jp      l03de
;------------------------------------------------------------------------------
		

		
;------------------------------------------------------------------------------
; Alternate between the sprite number in b and the next sprite up
; passed:	b - the first sprite number 
;			hl - the sprite number memory address
; return:	(hl) - the resulting sprite number
L_TOGGLE_FIRE_SPRITES:  
		ld      (hl),b
        ld      a,(COUNTER_1)
        rrca    
        ret     c
        inc     b
        ld      (hl),b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate Donkey Kong (stomping, grabbing barrels, etc) and Pauline (yelling 
; HELP! and being frantic)
L_ANIMATE_DK_AND_PAULINE:  
		; If this is not the mixer stage, skip ahead
		ld      a,(CURRENT_STAGE)
        cp      2
        jp      nz,l0413

		; Move Donkey Kong along the top conveyer
        ld      hl,DK_SPRITE_1_X
        ld      a,(TOP_CONVEYER_DIR)
        ld      c,a
        rst     $38						; Move Donkey Kong horizontally

		; Calculate and save Donkey Kong's distance from the ladder
        ld      a,(DK_SPRITE_3_X)
        sub     59
        ld      (DK_DISTANCE_TO_LADDER),a

		; If Donkey Kong is in an action, jump ahead to perform it
l0413:  ld      a,(TIME_FOR_DK_ACTION)
        and     a
        jp      nz,l0426

		; If counter 2 has not yet run down, then jump ahead to skip Donkey Kong
		; animation and animate Pauline
        ld      a,(COUNTER_2)
        and     a
        jp      nz,l0486

		; If counter 2 has run down, it is time for Donkey Kong to act 
        ld      a,1
        ld      (TIME_FOR_DK_ACTION),a

		; If ++ANIMATION_TIMER == 128, jump ahead
l0426:  ld      hl,ANIMATION_TIMER
        inc     (hl)
        ld      a,(hl)
        cp      128
        jp      z,l0464

		; If Donkey Kong is not stomping, then jump ahead to animate Pauline
        ld      a,(DK_STOMPING)
        and     a
        jp      nz,l0486

		; If it is not time to update Donkey Kong's stomp animation,
		; skip ahead to animate Pauline
        ld      a,(hl)
        ld      b,a
        and     %00011111
        jp      nz,l0486

		; Toggle between Donkey Kong stomping sprites
        ld      hl,L_DK_SPRITES_GRIN_L_STOMP
        bit     5,b
        jr      nz,l0448
        ld      hl,L_DK_SPRITES_GRIN_R_STOMP
l0448:  call    L_LOAD_DK_SPRITES

		; Trigger stomp sound
        ld      a,3
        ld      (STOMP_SOUND_TRIGGER),a

		; Jump ahead if the current stage is mixer or rivets
l0450:  ld      a,(CURRENT_STAGE)
        rrca    
        jp      nc,l0478

		; Jump ahead if this is the elevators stage
        rrca    
        jp      c,l0486

		; If this is the barrels stage, move Donkey Kong 4 pixels left
        ld      hl,DK_SPRITE_1_Y
        ld      c,-4
        rst     $38
        jp      l0486

		; Set ANIMATION_TIMER and TIME_FOR_DK_ACTION to 0
l0464:  xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a

		; If Donkey Kong is not stomping, then skip ahead to animate Pauline
        ld      a,(DK_STOMPING)
        and     a
        jp      nz,l0486

        ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        jp      l0450

		; Move Donkey Kong to the ladder?
l0478:  ld      hl,DK_SPRITE_1_X
        ld      c,68

		; If the current stage is mixer, jump ahead
        rrca    
        jp      nc,l0485

        ld      a,(DK_DISTANCE_TO_LADDER)
        ld      c,a
l0485:  rst     $38

; Animate Pauline on the barrels, mixer, and elevators level
; The HELP! tiles are periodically displayed and erased
; and Pauline is animated as frantic
l0486:  ld      a,(ANIMATION_TIMER)
        ld      c,a
        ld      de,32						; Used to move tile address one column left

		; If the current stage is rivets
        ld      a,(CURRENT_STAGE)
        cp      4
        jp      z,l04be

		; If ANIMATION_TIMER is zero, then clear the HElP! tiles next to Pauline
        ld      a,c
        and     a
        jp      z,l04a1

		; If bit 6 of ANIMATION_TIMER is set, display the HELP! tiles
        ld      a,$ef
        bit     6,c
        jp      nz,l04a3

l04a1:  ld      a,$10						; Blank tile
		; Display or clear the HElP! tiles next to Pauline
l04a3:  ld      hl,TILE_COORD(14,4)
        call    L_DISPLAY_OR_CLEAR_HELP						; Display or clear HELP!

        ld      a,(PAULINE_LOWER_SPRITE_NUM)
		; Record Paulines lower sprite number
l04ac:  ld      (PAULINE_LOWER_SPRITE_NUM),a
		; All done if bit 6 of ANIMATION_TIMER is not set
        bit     6,c
        ret     z

		; Return if lower three bits of ANIMATION_TIMER are not 0
        ld      b,a						; b = pauline lower sprite number
        ld      a,c						; a = ANIMATION_TIMER
        and     %00000111
        ret     nz

		; Animate Pauline frantic by swapping her lower sprite number 
		; between $11 and $12
        ld      a,b
        xor     %00000011
        ld      (PAULINE_LOWER_SPRITE_NUM),a
        ret     

; Animate Pauline on the rivets stage
		; Clear the HELP! tiles from both sides of Pauline
l04be:  ld      a,$10
        ld      hl,TILE_COORD(17,3)
        call    L_DISPLAY_OR_CLEAR_HELP						; Display or clear HELP!
        ld      hl,TILE_COORD(12,3)
        call    L_DISPLAY_OR_CLEAR_HELP						; Display or clear HELP!

		; If bit 6 of ANIMATION_TIMER is 0, jump ahead
        bit     6,c
        jp      z,l0509

		; If Mario is right of center, jump ahead
        ld      a,(MARIO_X)
        cp      128
        jp      nc,l04f1

		; Mario is left of center, so face Pauline left and display the HELP! tiles to Pauline's left
        ld      a,$df						; Last of the three HELP! tiles
        ld      hl,TILE_COORD(17,3)
        call    L_DISPLAY_OR_CLEAR_HELP						; Display HELP!
l04e1:  ld      a,(PAULINE_UPPER_SPRITE_NUM)	; Face pauline left
        or      %10000000
        ld      (PAULINE_UPPER_SPRITE_NUM),a
        ld      a,(PAULINE_LOWER_SPRITE_NUM)
        or      %10000000
        jp      l04ac						; Animate Pauline

		; Mario is right of center, so face Pauline right and display the HELP! tiles to Pauline's right
l04f1:  ld      a,$ef						; Last of the three HELP! tiles
        ld      hl,TILE_COORD(12,3)
        call    L_DISPLAY_OR_CLEAR_HELP						; Display HELP!
l04f9:  ld      a,(PAULINE_UPPER_SPRITE_NUM)
        and     %01111111
        ld      (PAULINE_UPPER_SPRITE_NUM),a
        ld      a,(PAULINE_LOWER_SPRITE_NUM)
        and     %01111111
        jp      l04ac						; Animate Pauline

		; If Mario is right of center, face Pauline right
l0509:  ld      a,(MARIO_X)
        cp      128
        jp      nc,l04f9

		; If Mario is left of center, face Pauline left
        jp      l04e1
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display or clear the HELP! tiles to Pauline's left or right
; passed:	a - the last tile of a 3 tile set 
;				($10 to clear the tiles, or $df or $ef to display HELP!)
;			hl - the right-most screen coordinate for the set of 3 tiles
;			de - 32 to move left 1 column before displaying the next tile
L_DISPLAY_OR_CLEAR_HELP:  
		ld      b,3							; b = 3 to 1
l0516:  ld      (hl),a						; Display the current tile
        add     hl,de						; Move left one column
        dec     a							; Decrement the tile
        djnz    l0516						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Award points to the player
; passed:  a - the points award table entry number of the points to award
L_AWARD_POINTS:  
		ld      c,a
        rst     $08							; Return if in attract mode

		; Get pointer to the current playe's score in de
        call    L_GET_PLAYER_SCORE

		; Convert the point table entry number to a table offset
        ld      a,c
        add     a,c
        add     a,c
        ld      c,a

		; Get pointer to the table entry
        ld      hl,L_POINT_AWARD_TABLE
        ld      b,$00
        add     hl,bc

		; Add the points to the player's score
        and     a
        ld      b,3							; For b = 3 to 1
l052e:  ld      a,(de)
        adc     a,(hl)
        daa     
        ld      (de),a
        inc     de
        inc     hl
        djnz    l052e						; Next b

		; Display the current player's score
        push    de
        dec     de
        ld      a,(CURRENT_PLAYER)
        call    L_DISPLAY_PLAYER_SCORE

		; Check if the player's score is higher than the high score
        pop     de
        dec     de
        ld      hl,PREV_HIGH_SCORE+2
        ld      b,3							; For b = 3 to 1
l0545:  ld      a,(de)
        cp      (hl)
        ret     c
		; If the score is higher, jump ahead
        jp      nz,l0550
        dec     de
        dec     hl
        djnz    l0545						; Next b
        ret

		; Replace the high score with player's score
l0550:  call    L_GET_PLAYER_SCORE
        ld      hl,PREV_HIGH_SCORE
l0556:  ld      a,(de)
        ld      (hl),a
        inc     de
        inc     hl
        djnz    l0556						; Next b
        jp      l05da						; Display the high score
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Return the current player's stored score
; Return:  de - PREV_P1_SCORE or PREV_P2_SCORE
;          a - CURRENT_PLAYER
L_GET_PLAYER_SCORE:  
		ld      de,PREV_P1_SCORE
        ld      a,(CURRENT_PLAYER)
        and     a
        ret     z
        ld      de,PREV_P2_SCORE
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the player's score (0 for player 1, or 1 for player 2)
; pssed:  a - the player number (0 = player 1, 1 = player 2)
;         de - pointer to player's score:  
L_DISPLAY_PLAYER_SCORE:
		; Determine the screen coordinate to display the score at
		ld      ix,TILE_COORD(28,1)
        and     a
        jr      z,L_DISPLAY_HIGH_SCORE_2
        ld      ix,TILE_COORD(9,1)
        jr      L_DISPLAY_HIGH_SCORE_2

		; Get the screen coordinate to display the high score at
L_DISPLAY_HIGH_SCORE:  
		ld      ix,TILE_COORD(18,1)

L_DISPLAY_HIGH_SCORE_2:  ex      de,hl
        ld      de,-32
        ld      bc,$0304					; For b = 3 to 1

		; Display each digit of the score
l0583:  ld      a,(hl)
        rrca    
        rrca    
        rrca    
        rrca    
        call    L_DISPLAY_SCORE_DIGIT
        ld      a,(hl)
        call    L_DISPLAY_SCORE_DIGIT
        dec     hl
        djnz    l0583					; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display one digit of the score and move 1 column to the right
; passed:  a - digit to display in BCD.  Only the least-significant nibble is looked at.
;          de - -32
;          ix - the screen coordinate to display at
L_DISPLAY_SCORE_DIGIT:  
		and     %00001111
        ld      (ix+0),a
        add     ix,de
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Zero-out scores
; passed: A - score ID
;             (0 = player 1, 
;              1 = player 2,
;              2 = high score,
;              3 = all scores)
L_ZERO_SCORES:
		; If a is 3, jump ahead to zero all scores
		cp      3
		jp      nc,l05bd

		; Get the address of the requested score
		push    af
		ld      hl,PREV_P1_SCORE
		and     a
		jp      z,l05ab
		ld      hl,PREV_P2_SCORE
l05ab:  cp      2
		jp      nz,l05b3
		ld      hl,PREV_HIGH_SCORE

		; Zero the selected score
l05b3:  xor     a
		ld      (hl),a
		inc     hl
		ld      (hl),a
		inc     hl
		ld      (hl),a
		pop     af
		jp      L_DISPLAY_SCORES

		; Zero each score in turn
		; (High score, player 2, player 1)
l05bd:  dec	 a
		push    af
		call    L_ZERO_SCORES
		pop     af
		ret     z
		jr      l05bd
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display scores
; passed: A - score ID
;             (0 = player 1, 
;              1 = player 2,
;              2 = high score,
;              3 = all scores)
L_DISPLAY_SCORES:  		
		; If a is 3, jump ahead to display all scores
		cp	  3
		jp      z,l05e0
l05cb:  ld      de,PREV_P1_SCORE+2
        and     a
        jp      z,l05d5
        ld      de,PREV_P2_SCORE+2
l05d5:  cp      2
        jp      nz,L_DISPLAY_PLAYER_SCORE
l05da:  ld      de,PREV_HIGH_SCORE+2

		; Display the score
        jp      L_DISPLAY_HIGH_SCORE

		; Display each score in turn
		; (High score, player 2, player 1)
l05e0:  dec     a
        push    af
        call    L_DISPLAY_SCORES
        pop     af
        ret     z
        jr      l05e0
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display a string from the string table
; passed: a - string table entry number
;			if the entry number is negative, the string is erased
L_DISPLAY_STRING:  
		; Look up the string address in the string table
		ld      hl,L_STRING_TABLE
        add     a,a
        push    af
        and     %01111111
        ld      e,a
        ld      d,$00
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl

		; Get the screen coordinate of the string
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl

		; Display each character in the string 
		; (string ends when $3f is found)
        ld      bc,-32
        ex      de,hl
l0600:  ld      a,(de)
        cp      $3f
        jp      z,l0026
        ld      (hl),a
        pop     af
		
		; If the string is to be erased, display a space instead
        jr      nc,l060c
        ld      (hl),$10

		; Move to the next character
l060c:  push    af
        inc     de
        add     hl,bc
        jr      l0600
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the number of plays that have been paid for
L_DISPLAY_CREDITS:  
		; Return if no coins have been inserted
		ld      a,(NO_COINS_INSERTED)
        rrca    
        ret     nc
		
		; Display the number of credits paid for
L_DISPLAY_CREDITS_2:  
		ld      a,5
        call    L_DISPLAY_STRING
        ld      hl,NUM_PLAYS
        ld      de,-32
        ld      ix,TILE_COORD(5, 31)
        ld      b,1
		; Use the score display code to display the number of credits
        jp      l0583
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Process the timer either initializing it, displaying it, or adding it to
; the player's score.
; passed:	a - 0: Add the timer to the player's score without displaying it
;				1: Simply display the timer
L_PROCESS_TIMER:  
		; If a = 0, jump ahead to add the timer to the player's score
		and     a
        jp      z,l0691
		
		; If ONSCREEN_TIMER is not reached 0, jump ahead
        ld      a,(ONSCREEN_TIMER)
        and     a
        jp      nz,l06a8
		
		; Return unless the timer is 0 because it hasn't been initialized yet
        ld      a,(TIMER_HAS_RUN_DOWN)
        and     a
        ret     nz
		
		; Convert the hex timer number to hex BCD for display
        ld      a,(INTERNAL_TIMER)
        ld      bc,$000a
		
		; Determine the number of 10's in the timer
		; (Because the displayed timer counts down by 100's, this will be
		; displayed as the 1,000's digit)
l0640:  inc     b
        sub     c
        jp      nz,l0640
        ld      a,b
		
		; Shift the digit to the most-significant nibble in store in the onscreen timer
        rlca    
        rlca    
        rlca    
        rlca    
        ld      (ONSCREEN_TIMER),a
		
		; Display the timer box
        ld      hl,L_TIMER_BOX_TILE_DATA
        ld      de,TILE_COORD(3, 5)
        ld      a,6							; For a = 6 to 1
l0655:  ld      ix,29
        ld      bc,3						; 3 bytes of data to display
        ldir    
        add     ix,de						; Advance to the next column
        push    ix
        pop     de							; Load ix into de
        dec     a							
        jp      nz,l0655					; Next a
		
		; Determine the number of 1's in the timer
		; (Because the displayed timer counts down by 100's, this will be
		; displayed as the 100's digit)
        ld      a,(ONSCREEN_TIMER)
l066a:  ld      c,a
        and     %00001111
        ld      b,a
		
		; If the timer is greater than or equal to 1,000, then jump ahead to
		; skip the time running out warning
        ld      a,c
        rrca    
        rrca    
        rrca    
        rrca    
        and     %00001111
        jp      nz,l0689
		
		; Trigger the time running out warning sound
        ld      a,SONG_TRIGGER_OUT_OF_TIME
        ld      (SONG_TRIGGER),a
		
		; Display the last two '0's of the timer in red
        ld      a,$70						; Red '0'
        ld      (TILE_COORD(4,6)),a			; 1's digit of displayed score
        ld      (TILE_COORD(5,6)),a			; 10's digit of displayed score

		; Clear the 1,000's digit and display the 100's digit in red
        add     a,b
        ld      b,a
        ld      a,$10						; ' '
		
		; Display the 1,000's digit			
l0689:  ld      (TILE_COORD(7,6)),a			; 1,000's digit of displayed score

		; Display the 100's digit
        ld      a,b
        ld      (TILE_COORD(6,6)),a			; 100's digit of displayed score
        ret     

		; Award the 100's points to the player
l0691:  ld      a,(ONSCREEN_TIMER)
        ld      b,a
        and     %00001111
        push    bc
        call    L_AWARD_POINTS
        pop     bc
		
		; Award the 1000's points to the player
        ld      a,b
        rrca    
        rrca    
        rrca    
        rrca    
        and     %00001111
        add     a,10
        jp      L_AWARD_POINTS
		
		; Decrement the timer
l06a8:  sub     1

		; If the timer has not reached 0, then skip ahead
        jr      nz,l06b1
		
		; Indicate that the timer is 0 because it has run down, not that it
		; needs to be initialized
        ld      hl,TIMER_HAS_RUN_DOWN
        ld      (hl),1
		
		; Resave the onscreen timer and jump back up to display it
l06b1:  daa     
        ld      (ONSCREEN_TIMER),a
        jp      l066a
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the number of lives and the current level number
; passed:	a - The number of lives to subtract before the lives are displayed
L_DISPLAY_LIVES_AND_LEVEL:  
		ld      c,a
        rst     $08							; Return if attract mode is not active

		; Blank (28,3)-(22,3)
        ld      b,6							; For b = 6 to 1
        ld      de,-32						
        ld      hl,TILE_COORD(28,3)
l06c2:  ld      (hl),$10					; Display ' '
        add     hl,de						; Move 1 column right
        djnz    l06c2						; Next b

		; Subtract a life if a = 1
        ld      a,(CP_NUMBER_LIVES)
        sub     c

        jp      z,l06d7						; If there are no lives left, jump ahead

		; Display the number of lives
        ld      b,a							; For b = number of lives to 1
        ld      hl,TILE_COORD(28,3)
l06d2:  ld      (hl),$ff					; Display the life icon
        add     hl,de						; Move 1 column right
        djnz    l06d2						; Next b

		; Display "L="
l06d7:  ld      hl,TILE_COORD(8,3)
        ld      (hl),$1c					; Display 'L'
        ld      hl,TILE_COORD(7,3)
        ld      (hl),$34					; Display '='
        ld      a,(CP_LEVEL_NUMBER)
        
		; Limit level number to 99
		cp      100
        jr      c,l06ed
        ld      a,99
        ld      (CP_LEVEL_NUMBER),a

		; Convert the level number to 10's digit (in b) and 1's digit (in a)
l06ed:  ld      bc,$ff0a
l06f0:  inc     b
        sub     c
        jp      nc,l06f0
        add     a,c
        ld      (TILE_COORD(5,3)),a			; Display 1's digit
        ld      a,b
        ld      (TILE_COORD(6,3)),a			; Display 10's digit
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Called when the GAME_STATE == 3 (player is playing)
; Jump to one of the following table entries based on the current game screen
L_IMPLEMENT_GAME_PLAY:  
		ld      a,(GAME_SUBSTATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_ORIENT_SCREEN	; 0 = orient the screen
		.word	L_INIT_P1	; 1 = initialize player 1
		.word	L_P1_PROMPT_SCREEN	; 2 = display player 1 prompt
		.word	L_INIT_P2	; 3 = intialize player 2
		.word	L_P2_PROMPT_SCREEN	; 4 = display player 2 prompt
		.word	L_DISPLAY_TURN_DATA	; 5 = display data for this turn
		.word	L_PREPARE_SCREEN_FOR_TURN	; 6 = trigger introduction or intermission
		.word	L_IMPLEMENT_INTRO_STAGE	; 7 = show introduction stage
		.word	L_DISPLAY_INTERMISSION	; 8 = show intermission
		.word	L_ORG	; 9 = reset game
		.word	L_DISPLAY_CURRENT_STAGE	; 10 = display current stage
		.word	L_INIT_MARIO	; 11 = initialize Mario sprite
		.word	L_RUN_GAME	; 12 = run game
		.word	L_IMPLEMENT_DEATH_ANIM	; 13 = display Mario death animation
		.word	L_POST_DEATH_PROCESSING_P1	; 14 = end turn player 1
		.word	L_POST_DEATH_PROCESSING_P2	; 15 = end turn player 2
		.word	L_ADV_FROM_P1_GAME_OVER	; 16 = start player 2 or end the game
		.word	L_ADV_FROM_P2_GAME_OVER	; 17 = start player 1 or end the game
		.word	L_PREPARE_FOR_P2_TURN	; 18 = activate player 2
		.word	L_PREPARE_FOR_P1_TURN	; 19 = activate player 1
		.word	L_CHECK_FOR_HS_INITIALS	; 20 = check for high scores
		.word	L_IMPLEMENT_HS_INITIAL_ENTRY	; 21 = get initials for high scores
		.word	L_IMPLEMENT_STAGE_WIN_ANIM	; 22 = show win animation for barrels, mixer, and elevator stages
		.word	L_PREP_FOR_NEXT_PLAYER	; 23 = activate next player
		.word	L_ORG	; 24 = reset game
		.word	L_ORG	; 25 = reset game
		.word	L_ORG	; 26 = reset game
		.word	L_ORG	; 27 = reset game
		.word	L_ORG	; 28 = reset game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Called when GAME_STATE == 1 (attract mode)
; If credits have been paid for, just wait for the player to push start, otherwise
; run through the attract sequence.
L_IMPLEMENT_ATTRACT_MODE: 	
		ld      hl,GAME_SUBSTATE
		ld      a,(NUM_PLAYS)
        and     a
		jp		nz,L_PROMPT_FOR_START					; If coins have been entered, just show the start prompt
		ld		a,(hl)
		rst		$28
		; Jump table
		.word	L_INSERT_COINS_SCREEN ; 0 = display insert coin screen
		.word	L_PREPARE_DEMO_MODE ; 1 = prepare for attract mode
		.word	L_INIT_MARIO ; 2 = initialize Mario sprite
		.word	L_RUN_GAME_DEMO ; 3 = run demo
		.word	L_IMPLEMENT_DEATH_ANIM ; 4 = display Mario death animation
		.word	L_CLEAN_UP_DEMO_MODE ; 5 = clear the screen
		.word	L_FLASH_DK_TITLE_SCREEN ; 6 = display the title screen with "DONKEY KONG" letters and cycle the palette
		.word	L_FREEZE_DK_TITLE_SCREEN ; 7 = display the title screen until it times out
		.word	L_ORG ; 8 = reset game
		.word	L_ORG ; 9 = reset game
;------------------------------------------------------------------------------

		
		
;------------------------------------------------------------------------------
; Prompt the player to push start
; passed - hl - GAME_SUBSTATE
L_PROMPT_FOR_START:  
		ld      (hl),$00					; Set GAME_SUBSTATE to 0
        ld      hl,GAME_STATE
        inc     (hl)						; GAME_STATE = 2 (waiting for player to push start)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Prepare for the demonstration mode by setting the stage, level and number of
; lives, and displaying the stage.
L_PREPARE_DEMO_MODE:  
		; Return until the timers decrement to 0
		rst     $20						
        
		; Clear $6392 and the fireball release trigger
		xor     a
        ld      ($6392),a
        ld      (RELEASE_A_FIREBALL),a

		; Demo occurs on barrels stage, level 1 with 1 life
        ld      a,1
        ld      (CURRENT_STAGE),a
        ld      (CP_LEVEL_NUMBER),a
        ld      (CP_NUMBER_LIVES),a

		; Display and initialize the current stage
        jp      L_DISPLAY_CURRENT_STAGE_2
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the initial screen in attract mode.  The string "INSERT COIN" is shown
; and the number of coins required for 1 and 2 players is also displayed.  The
; previous game's score(s) is shown as well.
L_INSERT_COINS_SCREEN:  
		; Initialize pallette to 00
		ld      hl,PALETTE_1_OUTPUT						
        ld      (hl),$00
        inc     hl
        ld      (hl),$00
		
		ld      de,$031b
        call    L_ADD_EVENT				; Display "INSERT COIN"
        inc     e
        call    L_ADD_EVENT				; Display "  PLAYER    COIN"
        call    L_DISPLAY_HIGH_SCORES

		; Set MINOR_TIMER to 2
        ld      hl,MINOR_TIMER
        ld      (hl),2
		
		; Set GAME_SUBSTATE to 1 (initializing the attract mode)
        inc     hl
        inc     (hl)
		
		; Clear the game section of the screen and display "1UP"
        call    L_CLEAR_STAGE_SCREEN
        call    L_DISPLAY_1UP
		
		; If the last game had two players, then display "2UP" as well
        ld      a,(TWO_PLAYERS)
        cp      1
        call    z,L_DISPLAY_2UP		
		
		; Display the number of coins required for 1 player to play
        ld      de,(NUM_COINS_FOR_1P)
        ld      hl,TILE_COORD(11,12)
        call    l07ad
		
		; Display e at the tile address in hl and d in the next row down
l07ad:  ld      (hl),e
        inc     hl
        inc     hl
        ld      (hl),d
        ld      a,d
		; If the coins required for two players >= 10, then display both digits
        sub     10
        jp      nz,l07bc
        ld      (hl),a
        inc     a
        ld      (TILE_COORD(12,14)),a
		
		; Display '1' and '2' for 1 and 2 players
l07bc:  ld      de,$0201
        ld      hl,TILE_COORD(20,12)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clean up the demonstration mode by clearing the stage tiles and advancing to 
; the next substate
L_CLEAN_UP_DEMO_MODE:  
		call    L_CLEAR_STAGE_SCREEN
		
		; Attract mode substate = 6
        ld      hl,GAME_SUBSTATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the DONKEY KONG title screen
; The palette is cycled to make the screen flash excitingly
L_FLASH_DK_TITLE_SCREEN:  
		; If the palette cycle counter has already been initialized, jump ahead
		ld      a,(TITLE_PALETTE_CYCLE_COUNTER)
        cp      0
        jp      nz,l082d
		
		; Initialize the palette cycle counter to 96 
        ld      a,96
        ld      (TITLE_PALETTE_CYCLE_COUNTER),a

		; Set the palette cycle pattern
        ld      c,%01011111

		; If the palette cycle counter has reached zero, then advance to the next
		; submode
l07da:  cp      0
        jp      z,l083b
		
		; Rotate the palette and set PALETTE_1_OUTPUT to the previous value of bit 7
        ld      hl,PALETTE_1_OUTPUT
        ld      (hl),0
		ld      a,c
        rlc     a
        jr      nc,l07eb
        ld      (hl),1
		
		; Rotate the palette and set PALETTE_2_OUTPUT to the previous value of bit 7
l07eb:  inc     hl
        ld      (hl),0
        rlc     a
        jr      nc,l07f4
        ld      (hl),1
		
		; Draw the large "DONKEY KONG" letters
l07f4:  ld      (TITLE_PALETTE_PATTERN),a
        ld      hl,L_LARGE_DK_LETTER_DATA
		
		; Draw one line of tiles
l07fa:  ld      a,$b0						; Girder tile with large round hole
		ld      b,(hl)						; for b = the number of tiles to draw to 1
        inc     hl
        ld      e,(hl)						; de = the first tile screen coordinate
        inc     hl
        ld      d,(hl)
l0801:  ld      (de),a						; Display the rivet tile at the current coordinate
        inc     de							; Move down one row
        djnz    l0801						; Next b
		
		; If this is not the end of the letter data, then repeat
        inc     hl
        ld      a,(hl)
        cp      $00
        jp      nz,l07fa
		
		; Display "©1981" and "NINTENDO OF AMERICA"
        ld      de,$031e
        call    L_ADD_EVENT
        inc     de
        call    L_ADD_EVENT
		
		; Load Donkey Kong sprites
        ld      hl,L_DK_SPRITES_GRIN_L_STOMP
        call    L_LOAD_DK_SPRITES
		
		; Display "(TM)"
        call    L_DISPLAY_TM
		
		; NOTE: Is there a need for this NOP?
        nop     
		
		; Position and display Donkey Kong 
        ld      hl,DK_SPRITE_1_X
        ld      c,68
        rst     $38
        ld      hl,DK_SPRITE_1_Y
        ld      c,120
        rst     $38
        ret     

		; Load the previous palette pattern
l082d:  ld      a,(TITLE_PALETTE_PATTERN)
        ld      c,a
		
		; Decrement the cycle counter
        ld      a,(TITLE_PALETTE_CYCLE_COUNTER)
        dec     a
        ld      (TITLE_PALETTE_CYCLE_COUNTER),a

		; Implement the palette cycling
        jp      l07da
		
		; Clean up and move to the next substate
l083b:  ld      hl,MINOR_TIMER
        ld      (hl),2					; Set MINOR_TIMER to 2
        inc     hl
        inc     (hl)						; Advance the substate
        ld      hl,TITLE_PALETTE_CYCLE_COUNTER
        ld      (hl),0						; Set TITLE_PALETTE_CYCLE_COUNTER to 0
        inc     hl
        ld      (hl),0						; Set TITLE_PALETTE_PATTERN to 0
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Pause on the DONKEY KONG title screen and then restart the attract mode
L_FREEZE_DK_TITLE_SCREEN:  
		; Return until the timers run down
		rst     $20

		; Reset the attract mode substate to 0
        ld      hl,GAME_SUBSTATE
        ld      (hl),0
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clear the entire screen and all the sprite
L_CLEAR_SCREEN_AND_SPRITES:  
		; Clear the entire screen
		ld      hl,TILE_COORD(0,0)
        ld      c,4						; For c = 4 to 1
l0857:  ld      b,0						; For b = 256 to 1
        ld      a,$10					; ' '
l085b:  ld      (hl),a
        inc     hl
        djnz    l085b					; Next b
        dec     c		
        jp      nz,l0857				; Next c
        
        ; Clear all 96 sprites
        ld      hl,SPRITE_STRUCTS
        ld      c,2						; For c = 2 to 1
l0868:  ld      b,192					; For b = 192 to 1
        xor     a
l086b:  ld      (hl),a					; 0 this sprite byte
        inc     hl
        djnz    l086b					; Next b
        dec     c
        jp      nz,l0868				; Next c
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clear the screen tiles (all but the top 4 rows)
L_CLEAR_STAGE_SCREEN:  
		ld      hl,TILE_COORD(0,4)
        ld      c,32					; For c = 32 to 1 (32 columns)
l0879:  ld      b,28					; For b = 28 to 1 (the lower 28 rows)
        ld      a,$10					; ' '
        ld      de,4
l0880:  ld      (hl),a					; Clear this screen coord
        inc     hl						; Advance 1 row down
        djnz    l0880					; Next b
        add     hl,de					; Skip the top 4 rows
        dec     c						
        jp      nz,l0879				; Next c
		
		; Clear (9,2) to (22,3)
        ld      hl,TILE_COORD(9,2)
        ld      de,32			
        ld      c,2						; For c = 2 to 1 (2 rows)
        ld      a,$10				
l0893:  ld      b,14					; For b = 14 to 1
l0895:  ld      (hl),a					; Clear this screen coord
        add     hl,de					; Advance 1 column left
        djnz    l0895					; Next b
        ld      hl,TILE_COORD(9,3)
        dec     c						
        jp      nz,l0893				; Next c
		
		; Clear sprites
        ld      hl,SPRITE_STRUCTS
        ld      b,0
        ld      a,0
l08a7:  ld      (hl),a
        inc     hl
        djnz    l08a7
        ld      b,128
l08ad:  ld      (hl),a
        inc     hl
        djnz    l08ad
		
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Game processing once a coin has been entered.  The attract mode no longer runs, 
; and the screen prompts the player to just push start already...
L_WAITING_FOR_START_MODE:  ld      a,(GAME_SUBSTATE)
        rst     $28							; Jump to local table address
        .word	L_DISPLAY_PUSH_START_SCREEN	; 0 = display start prompt
		.word	L_HANDLE_START_BUTTONS	; 1 = start 1 or 2 players
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Display the "push 1 player" or "push 1 or 2 player" screen
; 
; passed:	none
; return:	the state of misc input in a
L_DISPLAY_PUSH_START_SCREEN:  
		call    L_CLEAR_STAGE_SCREEN
		
		; Coins have been inserted
        xor     a
        ld      (NO_COINS_INSERTED),a
        
        ; Display "PUSH"
        ld      de,$030c
        call    L_ADD_EVENT
        
        ; Advance to the next substate
        ld      hl,GAME_SUBSTATE
        inc     (hl)
        
        call    L_DISPLAY_HIGH_SCORES
        
        ; Initialize the palette to 00
        xor     a
        ld      hl,PALETTE_1_OUTPUT
        ld      (hl),a
        inc     l
        ld      (hl),a
               
        ; If only 1 play has been paid for, jump ahead to only offer 1 player option
l08d5:  ld      b,%00000100					; Filter out every input but 1 player start
        ld      e,$09						; = "ONLY 1 PlAYER BUTTON"
        ld      a,(NUM_PLAYS)
        cp      1
        jp      z,l08e4
        
        ; If more than 1 play has been paid for, offer 1 or 2 player
        ld      b,%00001100					; Filter out every input but 1 and 2 player start
        inc     e							; "1 OR 2 PLAYERS BUTTON"
        
        ; Only display 1, or 1 or 2 player prompt when the 3 LSBs of COUNTER_2 are zero?
l08e4:  ld      a,(COUNTER_2)
        and     %00000111
        jp      nz,l08f3
        
        ld      a,e
        call    L_DISPLAY_STRING
        call    L_DISPLAY_CREDITS_2
        
        ; Filter MISC_INPUT
l08f3:  ld      a,(MISC_INPUT)
        and     b
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Wait for the player to press either 1 player start or 2 player start and
; start the game when one of them is pressed.
;
; passed:	none
; return:	none
L_HANDLE_START_BUTTONS:  
		; Display "ONLY 1 PLAYER BUTTON" or "1 or 2 PLAYERS BUTTON" and filter
		; player input accordingly
		call    l08d5						; a = misc input

		; If the 1 PLAYER START has been pressed, jump ahead to start 1 player
        cp      $04
        jp      z,l0906
		
		; If the 2 PLAYER START has been pressed, jump ahead to start 2 players
        cp      $08	
        jp      z,l0919
        ret     
		
		; Subtract one play from the number of plays that have been paid for
l0906:  call    L_SUBTRACT_ONE_PLAY

		; Clear player 2 data
        ld      hl,P2_DATA
        ld      b,$08
        xor     a
l090f:  ld      (hl),a
        inc     l
        djnz    l090f
		
		; Jump ahead to set SECOND_PLAYER to 0 (indicating that the current player is player 1)
		; and set TWO_PLAYERS to 0 (indicating that one player is playing)
        ld      hl,$0000
        jp      l0938
		
		; Subtract two plays from the number of plays that have been paid for
l0919:  call    L_SUBTRACT_ONE_PLAY
        call    L_SUBTRACT_ONE_PLAY
		
		; Initialize player 2's number of lives to the initial number of lives
		; (from the DIP settings)
        ld      de,P2_NUMBER_LIVES
        ld      a,(DIP_NUM_LIVES)
        ld      (de),a
		
		; Fill player 2's data with the initial data values
        inc     e							; de = P2_LEVEL_NUMBER
        ld      hl,L_INITIAL_PLAYER_DATA_TABLE
        ld      bc,7						; 7 bytes of data to copy
        ldir    
		
		; Zero player 2's score
        ld      de,$0101
        call    L_ADD_EVENT
		
		; Set SECOND_PLAYER to 0 (indicating that the current player is player 1)
		; and set TWO_PLAYERS to 1 (indicating that two players are playing)
        ld      hl,$0100
		
		; Set the values of SECOND_PLAYER (to the value of l) 
		; and TWO_PLAYERS (to the value of h)
l0938:  ld      (SECOND_PLAYER),hl

		; Clear the entire stage portion of the screen
        call    L_CLEAR_STAGE_SCREEN
		
		; Initialize player 1's number of lives to the initial number of lives
		; (from the DIP settings)
        ld      de,P1_NUMBER_LIVES
        ld      a,(DIP_NUM_LIVES)
        ld      (de),a
		
		; Fill player 1's data with the initial data values
        inc     e							; de = P1_LEVEL_NUMBER
        ld      hl,L_INITIAL_PLAYER_DATA_TABLE
        ld      bc,7						; 7 bytes of data to copy
        ldir    
		
		; Zero player 1's score
        ld      de,$0100
        call    L_ADD_EVENT
		
		; Set the game state to playing and game substate to orienting the screen
        xor     a
        ld      (GAME_SUBSTATE),a
        ld      a,3
        ld      (GAME_STATE),a
        ret 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following table contains the initial values for player data when the game
; is first beginning
L_INITIAL_PLAYER_DATA_TABLE:  
		.byte	1		; LEVEL_NUMBER - Start on level one
		.word	L_STAGE_ORDER_TABLE	; STAGE_ORDER_POINTER - Address of the stage order for level 1
		.byte	1		; INTRO_NOT_DISPLAYED - The introduction stage has not been displayed
		.byte	0		; BONUS_AWARDED - The bonus life has not been awarded
		.byte	0		; HEIGHT_INDEX - Still working on 25 meters
		.byte	0		; STAGE_ORDER_POINTER_LAG - Not initialized
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the high score table
L_DISPLAY_HIGH_SCORES:  
		; Display the number of plays that have been paid for
		ld      de,$0400
        call    L_ADD_EVENT	

		; Display the high score table			
        ld      de,$0314
        ld      b,$06
l0970:  call    L_ADD_EVENT
        inc     e
        djnz    l0970
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Subtract one play from the number of plays that have been paid for.
; 
; passed:	none
; return: 	none
L_SUBTRACT_ONE_PLAY:  
		; Interesting way to subtract one play...
		ld      hl,NUM_PLAYS
        ld      a,$99
        add     a,(hl)
        daa     
        ld      (hl),a
		
		; Redisplay the number of credits paid for
        ld      de,$0400
        call    L_ADD_EVENT
		
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Orient the screen for the next player.
; This really only applies to cocktail cabinets, where the screen is flipped
; when it is the second player's turn.
L_ORIENT_SCREEN:  
		call    L_CLEAR_SCREEN_AND_SPRITES
        call    L_SOUNDS_OFF
        
        ; Orient the screen right side up
        ld      de,SCREEN_ORIENTATION
        ld      a,1
        ld      (de),a
        
        ; If the second player is active, jump ahead to invert the screen, if needed
        ld      hl,GAME_SUBSTATE
        ld      a,(SECOND_PLAYER)
        and     a
        jp      nz,l099f
        
        ; If this is the first player, set substate to 1
        ld      (hl),1
        ret     
        
        ; If this is an upright cabinet, don't flip the screen 
        ; for the second player
l099f:  ld      a,(CABINET_TYPE)
        dec     a
        jp      z,l09a8
        
        ; If this is a cocktail cabinet, flip the screen for 
        ; the second player
        xor     a
        ld      (de),a
        
        ; This is the second player, so set the substate to 3
l09a8:  ld      (hl),3
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize player 1 and cause the player 1 prompt to be shown if there are 
; two players in the game
L_INIT_P1:  
		; Copy player 1 data to the current player data
		ld      hl,P1_DATA
        ld      de,CP_DATA
        ld      bc,8
        ldir    
        
        ; Record the current stage
        ld      hl,(CP_STAGE_ORDER_POINTER)
        ld      a,(hl)
        ld      (CURRENT_STAGE),a
        
        ; If this is a two player game,
        ; set the minor timer to 120 and substate to 2 
        ; to display the 1 player prompt
        ld      a,(TWO_PLAYERS)
        and     a
        ld      hl,MINOR_TIMER
        ld      de,GAME_SUBSTATE
        jp      z,l09d0
        ld      (hl),120
        ex      de,hl
        ld      (hl),2
        ret     
         
        ; If this is a one player game,
        ; set the minor timer to 1 and substate to 5
        ; to skip the 1 player prompt
l09d0:  ld      (hl),1
        ex      de,hl
        ld      (hl),5
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the player 1 prompt.
; This is only done in two player games.
L_P1_PROMPT_SCREEN:  
		; Set the palette to 00
		xor     a
        ld      (PALETTE_1_OUTPUT),a
        ld      (PALETTE_2_OUTPUT),a
        
        ; Display "PLAYER (I)"
        ld      de,$0302
        call    L_ADD_EVENT
        
        ; Display player 2's score?
        ld      de,$0201
        call    L_ADD_EVENT
        
        ; Advance to substate 5
        ld      a,5
        ld      (GAME_SUBSTATE),a
		
L_DISPLAY_2UP:  
		; Display "2UP"
		ld      a,$02						; '2'
        ld      (TILE_COORD(7,0)),a
        ld      a,$25						; 'U'
        ld      (TILE_COORD(6,0)),a
        ld      a,$20						; 'P'
        ld      (TILE_COORD(5,0)),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize player 2 and cause the player 2 prompt to be shown 
L_INIT_P2:  
		; Copy player 2 data to the current player data
		ld      hl,P2_NUMBER_LIVES
        ld      de,CP_NUMBER_LIVES
        ld      bc,8
        ldir    
       
        ; Record the current stage		
        ld      hl,(CP_STAGE_ORDER_POINTER)
        ld      a,(hl)
        ld      (CURRENT_STAGE),a
        
        ; Set the minor timer to 120 and substate to 4 to display the player 2 prompt
        ld      a,120
        ld      (MINOR_TIMER),a
        ld      a,GAME_SUBSTATE_PLAY_START_P2
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the player 2 prompt.
L_P2_PROMPT_SCREEN:  
		; Set palette 00
		xor     a
        ld      (PALETTE_1_OUTPUT),a
        ld      (PALETTE_2_OUTPUT),a
        
        ; Display "PLAYER (II)"
        ld      de,$0303
        call    L_ADD_EVENT
        
        ; Display player 2 score
        ld      de,$0201
        call    L_ADD_EVENT
        call    L_DISPLAY_2UP
        
        ; Set substate to 5
        ld      a,5
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the high score, player 1 score and lives and level
L_DISPLAY_TURN_DATA:  
		; Display "HIGH SCORE"
		ld      de,$0304
        call    L_ADD_EVENT
        
        ; Display the high score
        ld      de,$0202
        call    L_ADD_EVENT
        
        ; Display player 1 score
        ld      de,$0200
        call    L_ADD_EVENT
        
        ; Display lives and level (w/o subtracting a life)
        ld      de,$0600
        call    L_ADD_EVENT
        
        ; Advance the substate (to 6)
        ld      hl,GAME_SUBSTATE
        inc     (hl)
		
L_DISPLAY_1UP:  
		; Display "1UP"
		ld      a,$01						; '1'
        ld      (TILE_COORD(26,0)),a
        ld      a,$25						; 'U'
        ld      (TILE_COORD(25,0)),a
        ld      a,$20						; 'P'
        ld      (TILE_COORD(24,0)),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Prepare for the next turn by clearing the screen and triggering the stage display
; or the intro, if needed.
L_PREPARE_SCREEN_FOR_TURN:  
		rst     $18						; Return until the minor timer runs down
        
        call    L_CLEAR_STAGE_SCREEN
        
        ; Set the minor timer to 1
        ld      hl,MINOR_TIMER
        ld      (hl),1
        
        ; Advance the substate
        inc     l
        inc     (hl)
        
        ; If the intro has already been displayed, return
        ld      de,CP_INTRO_NOT_DISPLAYED
        ld      a,(de)
        and     a
        ret     nz
        
        ; Intro needs to be displayed, so advance the substate again
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Called when GAME_STATE == 3 (player is playing) and GAME_SUBSTATE == 7
;
; Display each part of the introduction animation
L_IMPLEMENT_INTRO_STAGE:  
		ld      a,(INTRODUCTION_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_DISPLAY_INTRODUCTION_STAGE	; 0 = display introduction screen
		.word	L_DISPLAY_DK_CLIMBING	; 1 = prepare sprites
		.word	L_IMPLEMENT_DK_CLIMB_ANIM	; 2 = animate climbing sequence
		.word	L_PAUSE_CURRENT_STATE	; 3 = pause
		.word	L_ANIMATE_DK_JUMP_FROM_LAD	; 4 = animate introduction screen
		.word	L_PAUSE_CURRENT_STATE	; 5 = pause
		.word	L_ANIMATE_DK_PLAT_JUMPS	; 6 = animate Donkey Kong jumping
		.word	L_ANIMATE_DK_GRIN_TAUNT	; 7 = Donkey Kong grins and laughs
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the introduction stage (with straight girders before they are warped
; by Donkey Kong) and prepare for Donkey Kong's jumps.
L_DISPLAY_INTRODUCTION_STAGE:  
		; Set palette 01
		xor     a
        ld      (PALETTE_1_OUTPUT),a
        inc     a
        ld      (PALETTE_2_OUTPUT),a
        
        ; Display the introduction stage (girder straight before they are warped 
		; by Donkey Kong)
        ld      de,L_INTRO_STAGE_DATA
        call    L_DISPLAY_STAGE
		
		; Blank the tiles at the top of Donkey Kong's escape ladders
		; Otherwise, girders are drawn at the top of each one
        ld      a,$10						; Blank tile
        ld      (TILE_COORD(21,3)),a
        ld      (TILE_COORD(19,3)),a
		
		; Draw a girder at the bottom of the ladder to Pauline's platform
		; Otherwise, it is just another ladder
        ld      a,$d4
        ld      (TILE_COORD(13,10)),a
		
		; Clear the climbing counter to 0
        xor     a
        ld      (DK_CLIMBING_COUNTER),a
		
		; Initialize Donkey Kong's ladder jump vector pointer to the beginning of the 
		; vector data
        ld      hl,L_DK_JUMP_FROM_LADDER_DATA
        ld      (LADDER_JUMP_VECTOR_POINTER),hl
		
		; Initialize Donkey Kong's platform jump vector pointer to the beginning of the
		; vector data
        ld      hl,L_DK_JUMP_ACROSS_PLAT_DATA
        ld      (PLATFORM_JUMP_VECTOR_POINTER),hl
		
		; Set the minor timer to 64
        ld      a,64
        ld      (MINOR_TIMER),a
		
		; Advance to the next state in the introduction display
        ld      hl,INTRODUCTION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Load and position Donkey Kong's climbing sprites, and begin playing the 
; introduction song.
L_DISPLAY_DK_CLIMBING:  
		rst     $18							; Return if the minor timer has not reached 0

		; Load the Donkey Kong climbing sprites and move them into position
        ld      hl,L_DK_SPRITES_CLIMBING
        call    L_LOAD_DK_SPRITES
        ld      hl,DK_SPRITE_1_X
        ld      c,48
        rst     $38
        ld      hl,DK_SPRITE_1_Y
        ld      c,-103
        rst     $38
		
        ld      a,31
        ld      (LADDER_ROW_TO_ERASE),a
		
        xor     a
        ld      (DK_SPRITE_2_X),a
		
		; Trigger the introduction song to play (once)
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_INTRODUCTION
        inc     hl							; PENDING_SONG_TRIGGER_REPEAT
        ld      (hl),3
		
		; Advance to the next introduction state
        ld      hl,INTRODUCTION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate Donkey Kong climbing the ladders on the introduction stage, including 
; pulling the ladders up behind him
L_IMPLEMENT_DK_CLIMB_ANIM:  
		; Display the next part of the climbing animation
		call    L_ANIMATE_CLIMBING_LADDERS
		
		; If Donkey Kong has climbed 8 pixels (up an entire tile of the ladder)
		; then animate the ladder being pulled up behind him
        ld      a,(DK_CLIMBING_COUNTER)
        and     %1111
        call    z,L_ANIMATE_LADDER_PULL_UP
        
        ; If Donkey Kong has not reached the top of the ladders, then return
        ld      a,(DK_SPRITE_1_Y)
        cp      93
        ret     nc
        
        ; Set the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a
        
        ; Advance to the next introduction state
        ld      hl,INTRODUCTION_STATE
        inc     (hl)
        
        ; Save INTRODUCTION_STATE as the current state variable
        ld      (CURRENT_STATE_VAR_POINTER),hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate Donkey Kong's jump from the ladder onto the top platform on the 
; introduction stage
L_ANIMATE_DK_JUMP_FROM_LAD:  
		; Return until counter 2 reaches 0
		ld      a,(COUNTER_2)
        rrca    
        ret     c
        
        ; Get the next jump vector
        ld      hl,(LADDER_JUMP_VECTOR_POINTER)
        ld      a,(hl)
        
        ; If the end of the vector data has been reached, jump ahead
        ; to complete the jump
        cp      $7f
        jp      z,l0b1e
         
        ; Advance the vector pointer
        inc     hl
        ld      (LADDER_JUMP_VECTOR_POINTER),hl
        
        ; Move Donkey Kong's sprites up by the vector amount
        ld      c,a
        ld      hl,DK_SPRITE_1_Y
        rst     $38
        ret     
        
        ; Complete the jump
        ; Load Donkey Kong sprites
l0b1e:  ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        
        ; Load Pauline's sprites
        ld      de,PAULINE_SPRITES
        ld      bc,8
        ldir    
        
        ; Position Donkey Kong
        ld      hl,DK_SPRITE_1_X
        ld      c,80
        rst     $38
        ld      hl,DK_SPRITE_1_Y
        ld      c,-4
        rst     $38
        
        ; Pull up the rest of the ladder
l0b38:  call    L_ANIMATE_LADDER_PULL_UP
        ld      a,(LADDER_ROW_TO_ERASE)
        cp      10
        jp      nz,l0b38
        
        ; Trigger the stomp sound
        ld      a,3
        ld      (STOMP_SOUND_TRIGGER),a
        
        ; Deform the 6th platform
        ld      de,L_INTRO_DATA_SLOPE6
        call    L_DISPLAY_STAGE
        ld      a,$10						; Blank tile
		ld      (TILE_COORD(5,10)),a
		ld      (TILE_COORD(4,10)),a
		
		; Mark platform 5 as the next to deform when Donkey Kong jumps again
        ld      a,5
        ld      (STAGE_DEFORM_INDEX),a
        
        ; Set the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a
        
        ; Advance the current state
        ld      hl,INTRODUCTION_STATE
        inc     (hl)
        ld      (CURRENT_STATE_VAR_POINTER),hl
        ret     
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Animate Donkey Kong's jumps across the top platform and the deformations that
; result
L_ANIMATE_DK_PLAT_JUMPS:  
		; Return until counter 2 reaches 0
		ld      a,(COUNTER_2)
        rrca    
        ret     c
        
        ; If the end of the vector data has been reached,
        ; then advance to the next state 
        ld      hl,(PLATFORM_JUMP_VECTOR_POINTER)
        ld      a,(hl)
        cp      $7f
        jp      z,l0b86
        
        ; Advance the vector data pointer
        inc     hl
        ld      (PLATFORM_JUMP_VECTOR_POINTER),hl
        
        ; Make Donkey Kong jump
        ld      hl,DK_SPRITE_1_Y
        ld      c,a
        rst     $38						; Move Donkey Kong up or down
        ld      hl,DK_SPRITE_1_X
        ld      c,-1
        rst     $38						; Move Donkey Kong left
        ret     
        
l0b86:  
		; Reset the vector data pointer to the start of the vector data
		ld      hl,L_DK_JUMP_ACROSS_PLAT_DATA
        ld      (PLATFORM_JUMP_VECTOR_POINTER),hl
        
        ; Trigger the stomp sound
        ld      a,3
        ld      (STOMP_SOUND_TRIGGER),a
        
        ; Convert the stage deform index to an offset
        ld      hl,l38dc
        ld      a,(STAGE_DEFORM_INDEX)
        dec     a
        rlca    
        rlca    
        rlca    
        rlca    
        ld      e,a
        ld      d,$00
        add     hl,de
        ex      de,hl
        
        ; Display the deformed platform
        call    L_DISPLAY_STAGE
        
        ; Decrement the deform index to the next lower platform
        ld      hl,STAGE_DEFORM_INDEX
        dec     (hl)
        
        ; Return if the next platform is valid
        ret     nz
        
        ; Set the timer
        ld      a,176
        ld      (MINOR_TIMER),a
        
        ; Advance to the next (and last) introduction state
        ld      hl,INTRODUCTION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate Donkey Kong's grin and laugh taunt at the end of the introduction stage
L_ANIMATE_DK_GRIN_TAUNT:  
		; If the minor timer has not run down to 144, jump ahead
		ld      hl,PENDING_SONG_TRIGGER
        ld      a,(MINOR_TIMER)
        cp      144
        jr      nz,l0bc8
        
        ; Trigger the roaring "song"
        ld      (hl),SONG_TRIGGER_ROAR
        inc     hl
        ld      (hl),3
        
        ; Show Donkey Kong grinning
        ld      hl,DK_SPRITE_5_NUM
        inc     (hl)
        jr      l0bd1
        
        ; If the minor timer has not decremented to 24, skip ahead
l0bc8:  cp      24
        jr      nz,l0bd1
        
        ; Show Donkey Kong not grinning
        ld      hl,DK_SPRITE_5_NUM
        dec     (hl)
        nop     
        
        ; Return until the minor timer reaches 0
l0bd1:  rst     $18

		; Reset the introduction state
        xor     a
        ld      (INTRODUCTION_STATE),a
        
        ; Show Donkey Kong grinning
        inc     (hl)
        
        ; Raise Donkey Kong's right arm (to match his left)
        inc     hl
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the intermission screen showing the height that the player has reached
L_DISPLAY_INTERMISSION:  
		; Turn off sounds and return until the minor timer reaches 0
		call    L_SOUNDS_OFF
        rst     $18
        
        ; Display Mario's lives
        call    L_CLEAR_STAGE_SCREEN
        ld      d,$06
        ld      a,(MARIO_ALIVE)
        ld      e,a
        call    L_ADD_EVENT
        
        ; Palette 10
        ld      hl,PALETTE_1_OUTPUT
        ld      (hl),$01
        inc     hl
        ld      (hl),$00
        
        ; Trigger the intermission song
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_INTERMISSION
        inc     hl
        ld      (hl),3
        
        ; Initialize the height string index to the first entry in the table
        ld      hl,INTERM_HEIGHT_STRING_INDEX
        ld      (hl),0
        
        ; Initialize the height string coord to the bottom of the "stack"
        ld      hl,TILE_COORD(22,28)
        ld      (INTERM_HEIGHT_STRING_COORD),hl
        
        ; Limit the height index to 5
        ld      a,(CP_HEIGHT_INDEX)
        cp      6
        jr      c,l0c11
        ld      a,5
        ld      (CP_HEIGHT_INDEX),a
        
        ; If the player has not advanced in height 
        ; (completed a stage), then jump ahead
l0c11:  ld      a,(CP_STAGE_ORDER_POINTER_LAG)
        ld      b,a
        ld      a,(CP_STAGE_ORDER_POINTER)
        cp      b
        jr      z,l0c1f
        
        ; Increase the players height by 1 (25 m)
        ld      hl,CP_HEIGHT_INDEX
        inc     (hl)
        
        ; Update the stage order pointer lag
l0c1f:  ld      (CP_STAGE_ORDER_POINTER_LAG),a

		; Get the current player's height
        ld      a,(CP_HEIGHT_INDEX)
        ld      b,a
        
        ; Start drawing the intermission gorilla at
        ld      hl,TILE_COORD(13,28)
l0c29:  ld      c,$50

		; NOTE: this may be a good place to save some space
		; Draw one column of the gorilla
l0c2b:  ld      (hl),c
        inc     c
        dec     hl
        ld      (hl),c
        inc     c
        dec     hl
        ld      (hl),c
        inc     c
        dec     hl
        ld      (hl),c
        
        ; If this is the last of the gorilla tiles, jump ahead
        ld      a,c
        cp      $67
        jp      z,l0c43
        
        ; Advance to the bottom of the next column and continue drawing tiles
        inc     c
        ld      de,35
        add     hl,de
        jp      l0c2b
        
        ; Convert the currently displayed height index to an offset in the height string table
l0c43:  ld      a,(INTERM_HEIGHT_STRING_INDEX)
        inc     a
        ld      (INTERM_HEIGHT_STRING_INDEX),a
        dec     a
        sla     a
        sla     a
        push    hl
        ld      hl,L_HEIGHT_STRING_TABLE
        
        push    bc
        ld      ix,(INTERM_HEIGHT_STRING_COORD)
        
        ; Convert the height string offset into a table address
        ld      c,a
        ld      b,0
        add     hl,bc
        
        ; Display the height string
        ld      a,(hl)
        ld      (ix+96),a
        inc     hl
        ld      a,(hl)
        ld      (ix+64),a
        inc     hl
        ld      a,(hl)
        ld      (ix+32),a
        ld      (ix-32),$8b					; 'm'
        
        ; Advance to the coord of the next height string to be displayed
        pop     bc
        push    ix
        pop     hl
        ld      de,-4
        add     hl,de
        ld      (INTERM_HEIGHT_STRING_COORD),hl
        
        ; Advance to the coordinate to draw the next gorilla up
        pop     hl
        ld      de,-161
        add     hl,de
        
        ; If there are more heights to be displayed, jump back up to display them
        dec     b
        jp      nz,l0c29
        
        ; Display "HOW HIGH CAN YOU GET ? "
        ld      de,$0307
        call    L_ADD_EVENT
        
        ; Set the minor timer to 160
        ld      hl,MINOR_TIMER
        ld      (hl),160
        
        ; Advance the game substate by two
        inc     hl
        inc     (hl)
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the current stage
L_DISPLAY_CURRENT_STAGE:  
		; Return until the minor timer has reached 0
		rst     $18
L_DISPLAY_CURRENT_STAGE_2:  
		call    L_CLEAR_STAGE_SCREEN

		; Display the onscreen timer (forces it to drawn on screen)
        xor     a
        ld      (ONSCREEN_TIMER),a
        ld      de,$0501
        call    L_ADD_EVENT

		; Select palette 01
        ld      hl,PALETTE_1_OUTPUT
        ld      (hl),0
        inc     hl
        ld      (hl),1

		; If on the barrels stage, jump ahead to display it
        ld      a,(CURRENT_STAGE)
        dec     a
        jp      z,l0cd4

		; If on the mixer stage, jump ahead to display it
        dec     a
        jp      z,l0cdf

		; If on the elevators stage, jump ahead to display it
        dec     a
        jp      z,l0cf2

		; Display the rivets stage
        call    L_DRAW_PAULINE_PLAT_POSTS

		; Palette 11
		ld      hl,PALETTE_1_OUTPUT
        ld      (hl),1

        ld      a,SONG_TRIGGER_BG_RIVETS
        ld      (SONG_TRIGGER),a
        
        ; Display the rivets stage
        ld      de,L_RIVETS_STAGE_DATA
        
l0cc6:  call    L_DISPLAY_STAGE
		
		; If the current stage is the rivets stage
        ld      a,(CURRENT_STAGE)
        cp      4
        call    z,L_DISPLAY_RIVETS
        
        ; Jump ahead to fully initialize the stage
        jp      L_WIERD_DISPLAY_STAGE_FN
        
        ; Display the barrels stage 
l0cd4:  ld      de,L_BARRELS_STAGE_DATA
        ld      a,SONG_TRIGGER_BG_BARRELS
        ld      (SONG_TRIGGER),a
        jp      l0cc6
        
        ; Display the mixer stage
l0cdf:  ld      de,L_MIXER_STAGE_DATA
        ld      hl,PALETTE_1_OUTPUT
        ld      (hl),1
        inc     hl
        ld      (hl),0
        ld      a,SONG_TRIGGER_BG_MIXER
        ld      (SONG_TRIGGER),a
        jp      l0cc6
        
        ; Display the elevators stage
l0cf2:  call    L_DRAW_ELEVATOR_SUPPORTS
        ld      a,SONG_TRIGGER_BG_ELEVATORS
        ld      (SONG_TRIGGER),a
        ld      de,L_ELEVATORS_STAGE_DATA
        jp      l0cc6
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the rivets on the rivets level
L_DISPLAY_RIVETS:  
		ld      b,8							; For b = 8 to 1
        ld      hl,L_RIVET_COORD_DATA					; hl = address of rivet coordinates
l0d05:  ld      a,$b8						; a = rivet tile
        ld      c,$02						; For c = 2 to 1
        ld      e,(hl)						; de = coordinate from table
        inc     hl
        ld      d,(hl)
        inc     hl							; hl = next table entry
l0d0d:  ld      (de),a						; display the rivet tile at the coordinate in de
        dec     a							; --a
        inc     de							; de = next row down
        dec     c							
        jp      nz,l0d0d					; Next c
        djnz    l0d05						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Coordinates of rivets
L_RIVET_COORD_DATA:	
		.word	TILE_COORD(22,10)
		.word	TILE_COORD(22,15)
		.word	TILE_COORD(22,20)
		.word	TILE_COORD(22,25)
		.word	TILE_COORD(9,10)
		.word	TILE_COORD(9,15)
		.word	TILE_COORD(9,20)
		.word	TILE_COORD(9,25)
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Draw the elevator supports on the elevators stage
L_DRAW_ELEVATOR_SUPPORTS:  
		ld      hl,TILE_COORD(24,13)
        call    l0d30
		
		; Draw the right side of the elevator support
        ld      hl,TILE_COORD(16,13)
l0d30:  ld      b,17						; For b = 17 to 1 (17 tiles high)
l0d32:  ld      (hl),$fd					
        inc     hl
        djnz    l0d32						; Next b
		
		; Draw the left side of the elevator support
        ld      de,15						; Enough to move back to the top of the left side
        add     hl,de
        ld      b,17						; For b = 17 to 1 (17 tiles high)
l0d3d:  ld      (hl),$fc
        inc     hl
        djnz    l0d3d						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Draw the posts that support Pauline's platform on the rivets stage
L_DRAW_PAULINE_PLAT_POSTS:  
		; Draw the post at (20,7)-(21,10)
		ld      hl,TILE_COORD(20,7)
        call    l0d4c

		; Draw the post at (10,7)-(11,10)
        ld      hl,TILE_COORD(10,7)

		; Draw the right half of the post supporting Pauline's platform on the rivets stage
l0d4c:  ld      b,4						; For b = 4 to 1
l0d4e:  ld      (hl),$fd
        inc     hl
        djnz    l0d4e						; Next b

		; Draw the left half of the post
        ld      de,28						; Move 1 column left
        add     hl,de
        ld      b,4						; For b = 4 to 1
l0d59:  ld      (hl),$fc
        inc     hl
        djnz    l0d59						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Complete the initialization of the current stage
; Initializes the ladder data and positions Donkey Kong and Pauline for the stage
L_COMPLETE_STAGE_INIT:  
		
		call    L_INIT_CURRENT_STAGE
        call    L_PARSE_STAGE_LADDER_DATA
        
        ; Initialize the minor timer to 64
        ld      hl,MINOR_TIMER
        ld      (hl),64
        
        ; Advance the submode
        inc     hl
        inc     (hl)
        
        ; Load the Donkey Kong and Pauline sprites
        ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        ld      de,PAULINE_UPPER_SPRITE_X
        ld      bc,8
        ldir    
        
        ; If the current stage is the rivets stage, jump ahead
        ld      a,(CURRENT_STAGE)
        cp      4
        jr      z,l0d8b
        
        ; Return if the stage is the mixer or elevators
        rrca    
        rrca    
        ret     c
        
        ; Move Donkey Kong in place for the barrels stage
        ld      hl,DK_SPRITE_1_Y
        ld      c,-4
        rst     $38
        ret     
        
        ; Move Donkey Kong into position for the rivets stage
l0d8b:  ld      hl,DK_SPRITE_1_X
        ld      c,68
        rst     $38
        
        ; Move Pauline into place for the rivets stage
        ld      de,4						; 4 bytes per sprite structure
        ld      bc,TWO_BYTES(2,16)		; 2 sprites to copy, move by 16 pixels
        ld      hl,PAULINE_UPPER_SPRITE_X
        call    L_MOVE_N_SPRITES
        ld      bc,TWO_BYTES(2,$f8)		; 2 sprites to copy, move -8 pixels 
        ld      hl,PAULINE_UPPER_SPRITE_Y
        call    L_MOVE_N_SPRITES
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display the game screen for the current stage
;
; The screen data is read in starting at the memory location in de and ending when
; $aa is read in.
;
; The stage data consists of 5 byte entries.  Each entry causes a line of tiles 
; to be drawn on the screen between two coordinates.
;
;	byte 0 = Identifies the type of line to display
;		0 = ladder (vertical)
;		1 = broken ladder (vertical)
;		2 = girders in the barrel's stage
;        3 = Girders with square holes
;        4 = Blank tiles
;        5 = Girders with circular holes
;        6 = X's (tile number $FE)
;		$aa = marks the end of the screen data
;
;	byte 1 = x1 coord
;		5 msbs = the tile x coord
;		3 lsbs = unknown
;		(with the 3 lsbs masked out, this is actually the pixel x coord of the upper left corner of the tile)
;
;	byte 2 = y1 coord
;		5 msbs = the tile y coord
;		3 lsbs = the tile offset (0-7) of the first tile (barrel girders and ladders only)
;		(with the 3 lsbs masked out, this is actually the pixel y coord of the upper left corner of the tile)

;	byte 3 = x2 coord
;		5 msbs = the tile x coord
;		3 lsbs = unknown
;		(with the 3 lsbs masked out, this is actually the pixel x coord of the upper left corner of the tile)
;
;	byte 4 = y2 coord
;		5 msbs = the tile y coord
;		3 lsbs = the tile offset (0-7) of the last tile (barrel girders and ladders only)
;		(with the 3 lsbs masked out, this is actually the pixel y coord of the upper left corner of the tile)
;
; passed:	de - starting ROM address for screen data
L_DISPLAY_STAGE:  
		; Read in the next tile ID
		ld      a,(de)
        ld      (STAGE_DATA_TILE_ID),a

		; Return if an $aa was found
        cp      $aa
        ret     z

		; Read in the first stage location
        inc     de
        ld      a,(de)
        ld      h,a
        ld      b,h						; b = x coord
        inc     de
        ld      a,(de)
        ld      l,a
        ld      c,l						; c = y coord

		; Convert the location data in hl to a tile memory address
        push    de
        call    L_STAGE_LOC_TO_ADDRESS
        pop     de
        ld      (STAGE_DATA_START_ADDRESS),hl

		; Isolate and save ??? (no idea what this is used for)
        ld      a,b
        and     %00000111
        ld      (STAGE_DATA_UNKNOWN),a

		; Isolate and save the y offset of the first tile
        ld      a,c
        and     %00000111
        ld      (STAGE_DATA_FIRST_Y_OFFSET),a

		; Read in the ending x location
        inc     de
        ld      a,(de)
        ld      h,a
        
        ; Calculate the x difference between the start and end x coordinates
        sub     b
        jp      nc,l0dd3
        neg    
l0dd3:  ld      (STAGE_DATA_X_DIFF),a

		; Read the ending y location
        inc     de
        ld      a,(de)
        ld      l,a
        
        ; Calculate the y difference
        sub     c
        ld      (STAGE_DATA_Y_DIFF),a
        
        ; Determine the bottom y offset?
        ld      a,(de)
        and     %00000111
        ld      (STAGE_DATA_LAST_Y_OFFSET),a
        
        ; Convert the ending location to a tile memory address
        push    de
        call    L_STAGE_LOC_TO_ADDRESS
        pop     de
        ld      (STAGE_DATA_END_ADDRESS),hl

		; If ladders are not being drawn, jump ahead
        ld      a,(STAGE_DATA_TILE_ID)
        cp      2
        jp      p,l0e4f

		; Subtract the two tiles that are being drawn
		; (the girder and the ladder below it)
        ld      a,(STAGE_DATA_Y_DIFF)
        sub     16						; = 2 tiles
        ld      b,a
        ld      a,(STAGE_DATA_FIRST_Y_OFFSET)
        add     a,b
        ld      (STAGE_DATA_Y_DIFF),a
        
        ; Display the correctly offset girder tile at this location
        ld      a,(STAGE_DATA_FIRST_Y_OFFSET)
        add     a,-16
        ld      hl,(STAGE_DATA_START_ADDRESS)
        ld      (hl),a
        
        ; Display the correctly offset top of ladder tile on the next row down
        inc     l							; ++y
        sub     48
        ld      (hl),a
        
        ; If this is not a broken ladder, skip ahead
        ld      a,(STAGE_DATA_TILE_ID)
        cp      1
        jp      nz,l0e19
        
        ; If this is a broken ladder, then force the rest of the ladder to be skipped
        xor     a
        ld      (STAGE_DATA_Y_DIFF),a
        
        ; Subtract the next tile that is being drawn
l0e19:  ld      a,(STAGE_DATA_Y_DIFF)
        sub     8							; = 1 tile
        ld      (STAGE_DATA_Y_DIFF),a
        
        ; If this is the bottom of the ladder, jump ahead to draw the bottom of the ladder
        jp      c,l0e2a
        
        ; Draw a ladder tile on the next row
        inc     l
        ld      (hl),$c0
        
        ; Continue drawing the ladder
        jp      l0e19
        
        ; Determine the correct bottom ladder tile 
l0e2a:  ld      a,(STAGE_DATA_LAST_Y_OFFSET)
        add     a,$d0
        
        ; Draw the bottom tile at the ending screen memory address
        ld      hl,(STAGE_DATA_END_ADDRESS)
        ld      (hl),a
        
        ; If not drawing a broken ladder, jump ahead
        ld      a,(STAGE_DATA_TILE_ID)
        cp      1
        jp      nz,l0e3f
        
        ; If drawing a broken ladder, draw one extra ladder tile
        ; just above the bottom
        dec     l							; --y
        ld      (hl),$c0
        inc     l							; ++y
        
        ; If the bottom tile is not offset, jump ahead
l0e3f:  ld      a,(STAGE_DATA_LAST_Y_OFFSET)
        cp      $00
        jp      z,l0e4b
        
        ; Draw the rest of the lower girder on the next row
        add     a,$e0
        inc     l
        ld      (hl),a
        
        ; Move on to the next group of stage data
l0e4b:  inc     de
        jp      L_DISPLAY_STAGE
        
        ; If barrel stage girders are not being drawn, jump ahead 
l0e4f:  ld      a,(STAGE_DATA_TILE_ID)
        cp      2
        jp      nz,l0ee8
        
        ; Determine the first tile to draw based on the tile offset
        ld      a,(STAGE_DATA_FIRST_Y_OFFSET)
        add     a,$f0
        ld      (STAGE_DATA_CURRENT_TILE),a
        
        ; Get the first screen memory location to draw the tile to
        ld      hl,(STAGE_DATA_START_ADDRESS)
        
        ; Draw the tile at the current screen address
l0e62:  ld      a,(STAGE_DATA_CURRENT_TILE)
        ld      (hl),a
        
        ; If this is the bottom of the screen, jump ahead
        inc     hl
        ld      a,l
        and     %00011111
        jp      z,l0e78
        
        ; If the the girder tile was not offset, jump ahead
        ld      a,(STAGE_DATA_CURRENT_TILE)
        cp      $f0
        jp      z,l0e78
        
        ; Draw the tile to complete the girder
        sub     $10
        ld      (hl),a
        
        ; Advance to the next column
l0e78:  ld      bc,31
        add     hl,bc
        
        ; If the end of the line has been reached, jump ahead to operate on the next stage data group
        ld      a,(STAGE_DATA_X_DIFF)
        sub     8							; = 1 tile
        jp      c,l0ecf
        
        ; If the line is horizontal, jump back up to continue drawing tiles
        ld      (STAGE_DATA_X_DIFF),a
        ld      a,(STAGE_DATA_Y_DIFF)
        cp      0
        jp      z,l0e62
        
        ; Display the tile at the current screen address
        ld      a,(STAGE_DATA_CURRENT_TILE)
        ld      (hl),a
        
        ; If this is the bottom of the screen, jump ahead
        inc     hl
        ld      a,l
        and     %00011111
        jp      z,l0ea0
        
        ; Draw the tile to complete the girder
        ld      a,(STAGE_DATA_CURRENT_TILE)
        sub     16
        ld      (hl),a
        
        ; Advance to the next column right
l0ea0:  ld      bc,$001f
        add     hl,bc
        
        ; If the end of the line has been reached, jump ahead to operate on the next stage data group
        ld      a,(STAGE_DATA_X_DIFF)
        sub     8							; = 1 tile
        jp      c,l0ecf
        
        ; If the line is sloping up, jump ahead
        ld      (STAGE_DATA_X_DIFF),a
        ld      a,(STAGE_DATA_Y_DIFF)
        bit     7,a
        jp      nz,l0ed3
        
        ; Handle lines sloping down
        
        ; Change the tile to the next offset down
        ld      a,(STAGE_DATA_CURRENT_TILE)
        inc     a
        ld      (STAGE_DATA_CURRENT_TILE),a
        
        ; If it's not time to advance to the next row down, jump ahead
        cp      $f8
        jp      nz,l0ec9
        
        ; Advance to the next row down and reset the tile to the first full girder
        inc     hl
        ld      a,$f0
        ld      (STAGE_DATA_CURRENT_TILE),a
        
        ; If this is not the bottom of the screen, jump back to continue drawing the line
l0ec9:  ld      a,l
        and     %00011111
        jp      nz,l0e62
        
        ; Move on to the next group of stage data
l0ecf:  inc     de
        jp      L_DISPLAY_STAGE
        
		; Handle lines sloping up
		
		; Change the tile to the next offset up
l0ed3:  ld      a,(STAGE_DATA_CURRENT_TILE)
        dec     a
        ld      (STAGE_DATA_CURRENT_TILE),a
        
        ; If it's not time to advance to the next row up, jump ahead
        cp      $f0
        jp      p,l0ee5
        
        ; Advance to the next row up and reset the tile to the first full girder
        dec     hl
        ld      a,$f7
        ld      (STAGE_DATA_CURRENT_TILE),a
        
        ; Jump back up to continue drawing the line
l0ee5:  jp      l0e62

		; If not drawing ???, jump ahead
l0ee8:  ld      a,(STAGE_DATA_TILE_ID)
        cp      3
        jp      nz,l0f1b
        
        ; Draw a blank tile at this screen address
        ld      hl,(STAGE_DATA_START_ADDRESS)
        ld      a,$b3					; blank tile
        ld      (hl),a
        
        ; Advance to the next column right
        ld      bc,32
        add     hl,bc
        
        ; If this is the end of the line, jump ahead
        ld      a,(STAGE_DATA_X_DIFF)
        sub     16						; = 2 tiles
l0eff:  jp      c,l0f14
        ld      (STAGE_DATA_X_DIFF),a
        
        ; Draw a square-hole girder at this screen address
        ld      a,$b1
        ld      (hl),a
        
        ; Advance to the next column right
        ld      bc,32
        add     hl,bc
        
        ; If this is the end of the line, jump ahead
        ld      a,(STAGE_DATA_X_DIFF)
        sub     8							; = 1 tile
        
        ; Jump back up to continue drawing the line
        jp      l0eff
        
        ; Draw a blank tile at the current screen address
l0f14:  ld      a,$b2
        ld      (hl),a
        
        ; Jump back to process the next stage data group
        inc     de
        jp      L_DISPLAY_STAGE
        
        ; If tile is ???, then jump back to handle the next group of stage data
l0f1b:  ld      a,(STAGE_DATA_TILE_ID)
        cp      7
        jp      p,l0ecf	
        
        ; If drawing blank tiles, jump ahead
        cp      4
        jp      z,l0f4c
        
        ; If drawing circular-hole girders, jump ahead
        cp      5
        jp      z,l0f51
        
        ; Draw X's, 
        
        ; Select the 'X' tile
        ld      a,$fe
l0f2f:  ld      (STAGE_DATA_CURRENT_TILE),a

		; Draw the til to the current screen address
        ld      hl,(STAGE_DATA_START_ADDRESS)
l0f35:  ld      a,(STAGE_DATA_CURRENT_TILE)
        ld      (hl),a
        
        ; Advance to the next column right
        ld      bc,32
        add     hl,bc
        
        ; Subtract one tile from the line
        ld      a,(STAGE_DATA_X_DIFF)
        sub     8						; = 1 tile
        ld      (STAGE_DATA_X_DIFF),a
        
        ; If this is not the end of the line, jump up to continue processing it
        jp      nc,l0f35
        
        ; Jump up to process the next group of stage data
        inc     de
        jp      L_DISPLAY_STAGE
        
        ; Draw blank tiles?
l0f4c:  ld      a,$e0
        jp      l0f2f
        
        ; Draw girders with circular holes
l0f51:  ld      a,$b0
        jp      l0f2f
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize the current stage
L_INIT_CURRENT_STAGE:  
		; Zero all of Mario's data
		ld      b,39						; For b = 39 to 1
        ld      hl,MARIO_DATA_STRUCT
l0f5b:  xor     a						; a = 0
l0f5c:  ld      (hl),a					; Zero the current address
        inc     l
        djnz    l0f5c					; Next b
        
        ; Zero $6280 to $6aff
        ; (includes all stage data and sprite data structures)
        ld      c,17						; For c = 17 to 1
        ld      d,128
        ld      hl,STAGE_DATA_BLOCK
l0f67:  ld      b,d						; For b = 128 to 1
l0f68:  ld      (hl),a					; Zero the current address
        inc     hl
        djnz    l0f68					; next b
        dec     c
        jr      nz,l0f67					; Next c
       
		; Load the stage variables with their initial values
        ld      hl,L_INITIAL_STAGE_DATA_TABLE
        ld      de,STAGE_DATA_BLOCK
        ld      bc,64					; 64 bytes of data
        ldir    
        
        ; Initialize the timer to the (current level number x 10) + 40
        ld      a,(CP_LEVEL_NUMBER)
        ld      b,a
        and     a
        rla     
        and     a
        rla     
        and     a
        rla     
        add     a,b
        add     a,b						; a = level number x 10
        add     a,40
        
        ; Cap the timer at 80
        cp      81
        jr      c,l0f8e
        ld      a,80
        
l0f8e:  ld      hl,INTERNAL_TIMER
        
        ; Save the timer value to the internal timer, $62b1, and $62b2
        ld      b,3						; for b = 3 to 1
l0f93:  ld      (hl),a
        inc     l
        djnz    l0f93					; Next b
        
        ; Initialize $62b3
        add     a,a
        ld      b,a
        ld      a,220
        sub     b
        
        ; Cap $62b3 at 40
        cp      40
        jr      nc,l0fa2
        ld      a,40
l0fa2:  ld      (hl),a

		; Initialize $62b4
        inc     l
        ld      (hl),a
        
        ld      hl,$6209
        ld      (hl),4
        
        inc     l						; $620a
        ld      (hl),8
        
        ; If current stage is not rivets, jump ahead
        ld      a,(CURRENT_STAGE)
        ld      c,a
        bit     2,a
        jr      nz,l0fcb
        
        ; Initialize 3 sprites
        ld      hl,$6a00
        ld      a,79
        ld      b,3						; For b = 3 to 1
l0fbc:  ld      (hl),a					; Sprite x 
        inc     l
        ld      (hl),$3a					; Sprite number = solid block?
        inc     l
        ld      (hl),$0f					; Sprite palette
        inc     l
        ld      (hl),24					; Sprite y				
        inc     l
        add     a,16						; Move the next sprite right 16 pixels
        djnz    l0fbc						; Next b
        
        ; Jump to a function in the table based on the current stage 
        ; to setup the current stage
l0fcb:  ld      a,c
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_ORG	; 0 = reset game
		.word	L_INIT_BARRELS_STAGE_SPRITES	; 1 = setup barrels stage sprites
		.word	L_INIT_MIXER_STAGE_SPRITES	; 2 = setup mixer stage sprites
		.word	L_INIT_ELEVATOR_STAGE_SPRITES	; 3 = setup elevators stage sprites
		.word	L_INIT_RIVETS_STAGE_SPRITES	; 4 = setup rivets stage sprites
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize the sprites for the barrels stage
L_INIT_BARRELS_STAGE_SPRITES:	
		; Load the sprite data for the four standing barrels next to Donkey Kong
		ld      hl,L_STANDING_BARRELS_SPRITE_DATA
        ld      de,STANDING_BARREL_SPRITE_DATA
        ld      bc,16
        ldir    
        
        ; Initialize the fire ball data structures
        ld      hl,L_FIREBALL_SPRITE_DATA
        ld      de,FIREBALL_STRUCTS+7	; Sprite number entry
        ld      c,28					; Destination blocks are spaces 32 bytes apart
        ld      b,5					; Copy 5 blocks of 4 byte data
        call    L_LD_SPRITE_DATA_TO_STRUCT

		; Load the initial data for the oil barrel fire
		; (fire not lit)
        ld      hl,L_BARRELS_FIRE_SPRITE_DATA
        call    L_LOAD_BARREL_FIRE_DATA
        
        ; Load the oil barrel sprite
        ld      hl,L_OIL_BARREL_SPRITE_DATA_1
        ld      de,OIL_BARREL_SPRITE
        ld      bc,4						; 4 bytes of data
        ldir    
        
        ; Initialize the hammers
        ld      hl,L_BARRELS_HAMMER_COORDS
        call    L_INIT_HAMMER_SPRITES
        
        ; Initialize 10 barrel sprites?
        ; Note: It looks like this code may be consolidated
        ;	   Instead of initializing 8 barrels and then 2 more,
        ;       I should be able to initialize all 10 at once
        ld      hl,L_INITIAL_BARREL_DATA
        ld      de,BARREL_STRUCTS+7				; Sprite number entry
        ld      bc,TWO_BYTES(8,28)		; 8 blocks, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        ld      de,BARREL_STRUCTS+(8*32)+7	; Sprite number entry
        ld      b,2						; 2 blocks, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The initial barrel data for barrels on the barrels stage
; The barrels are initially inactive
L_INITIAL_BARREL_DATA:  .byte	0						; Sprite number					; Sprite number
		.byte	0						; Palette
		.byte	2						
		.byte	2
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize the sprites for the mixer stage
L_INIT_MIXER_STAGE_SPRITES:  
        ; Initialize the fire ball data structures
		ld      hl,L_FIREBALL_SPRITE_DATA
        ld      de,FIREBALL_STRUCTS+7			; Sprite number entry
        ld      bc,TWO_BYTES(5,28)				; 5 bytes, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; NOTE: why are the springs being initialized on the mixer level?
        ; Do I have something wrong here?
        call    L_INIT_SPRING_DATA
        
        ; Initialize pie sprites
        ld      hl,L_PIE_SPRITE_DATA
        ld      de,PIE_STRUCTS+7				; Sprite number entry
        ld      bc,TWO_BYTES(6,12)		; 6 blocks, 16 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        ld      ix,PIE_STRUCTS
        ld      hl,PIE_SPRITES
        ld      de,16					; 16 byte data structures
        ld      b,6						; 6 sprites
        call    L_COPY_STRUCT_TO_SPRITE
        
        ; Load the initial data for the oil barrel fire
        ; (Initially lit)
		ld      hl,L_MIXER_FIRE_SPRITE_DATA
        call    L_LOAD_BARREL_FIRE_DATA
                
        ; Load the oil barrel sprite
        ld      hl,L_OIL_BARREL_SPRITE_DATA_2
        ld      de,OIL_BARREL_SPRITE
        ld      bc,4
        ldir    
        
        ; Initialize the retractable ladder sprites
        ld      hl,L_RETRACT_LADDER_SPRITE_DATA
        ld      de,RETRACTABLE_LADDER_SPRITES
        ld      bc,8						; 2 sprites
        ldir    
        
        ; Initialize the conveyer belt motor sprites
        ld      hl,L_MIXER_MOTOR_SPRITE_DATA
        ld      de,CONVEYER_MOTOR_SPRITES
        ld      bc,24					; 6 sprites
        ldir    
        
        ; Initialize the hammers
        ld      hl,L_MIXER_HAMMER_COORDS
        call    L_INIT_HAMMER_SPRITES
        
        ; Initialize the prize sprites
        ld      hl,L_MIXER_PRIZE_SPRITE_DATA
        ld      de,PRIZE_SPRITES
        ld      bc,12				; 3 sprites
        ldir    
        
        ; Mark the oil barrel fire as burning
        ld      a,1
        ld      (BARREL_FIRE_STATE),a
        ret     
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Initialize the sprites for the elevators stage
L_INIT_ELEVATOR_STAGE_SPRITES:  
		; Initialize the fire ball data structures
		ld      hl,L_FIREBALL_SPRITE_DATA
        ld      de,FIREBALL_STRUCTS+7			; Sprite number entry
        ld      bc,TWO_BYTES(5,28)				; 5 bytes, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; Initialize the springs
        call    L_INIT_SPRING_DATA
        
        ; Mark the elevator platforms as active
        ld      hl,ELEVATOR_STRUCTS
        ld      de,16					; 16 byte data structures
        ld      a,1
        ld      b,6						; For b = 6 to 1
l10a0:  ld      (hl),a
        add     hl,de
        djnz    l10a0						; Next b
        
        ; NOTE: The c loop seems redundant
        ld      c,2						; For c = 2 to 1
        ld      a,8
l10a8:  ld      b,3						; For b = 3 to 1
        ld      hl,ELEVATOR_STRUCTS+13
l10ad:  ld      (hl),a
        add     hl,de
        djnz    l10ad					; Next b
        
        ; NOTE: I don't think this is necessary - a should already be 8
        ld      a,8
        dec     c						
        jp      nz,l10a8					; Next c
        
        ; Initialize the coordinates of the elevator platforms
        ld      hl,L_ELEVATOR_COORDS
        ld      de,ELEVATOR_STRUCTS+3		; X coordinate entry
        ld      bc,TWO_BYTES(6,14)			; 6 sprites, 16 byte data structures
        call    L_COPY_COORDS_TO_STRUCTS
        
l10c3:  ld      hl,L_ELEVATOR_SPRITE_DATA
        ld      de,ELEVATOR_STRUCTS+7					; Sprite number entry
        ld      bc,TWO_BYTES(6,12)			; 6 sprites, 16 byte data structs
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; Copy elevator data to the sprites
        ld      ix,ELEVATOR_STRUCTS
        ld      hl,ELEVATOR_PLATFORM_SPRITES
        ld      b,6
        ld      de,16
        call    L_COPY_STRUCT_TO_SPRITE
        
        ; Load the prize sprites for the elevator stage
        ld      hl,L_ELEV_PRIZE_SPRITE_DATA
        ld      de,PRIZE_SPRITES
        ld      bc,12						; 3 sprites
        ldir    
        
        ld      ix,FIREBALL_STRUCTS
        ld      (ix+0),1				; Fireball active
        ld      (ix+3),88				; Fireball x coordinate
        ld      (ix+14),88
        ld      (ix+5),128			; Fireball y coordinate
        ld      (ix+15),128
        
        ld      (ix+32),1				; Fireball active
        ld      (ix+35),235				; Fireball x coordinate
        ld      (ix+46),235
        ld      (ix+37),96				; Fireball y coordinate
        ld      (ix+47),96
        
        ; Load the elevator motor sprites
        ld      de,ELEVATOR_MOTOR_SPRITE_DATA
        ld      hl,L_ELEV_MOTOR_SPRITE_DATA
        ld      bc,16					; 4 sprites
        ldir    
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for each of the elevator motors on the elevator level
L_ELEV_MOTOR_SPRITE_DATA:	
		.byte	55	; X coordinate
		.byte	$45	; Sprite number
		.byte	$0f	; Palette
		.byte	96	; Y coordinate
		
		.byte	55	; X coordinate
		.byte	$45	; Sprite number
		.byte	$8f	; Palette (Flipped vertically)
		.byte	247	; Y coordinate
		
		.byte	119	; X coordinate
		.byte	$45	; Sprite number
		.byte	$0f	; Palette
		.byte	96	; Y coordinate
		
		.byte	119	; X coordinate
		.byte	$45	; Sprite number
		.byte	$8f	; Palette (Flipped vertically)
		.byte	247	; Y coordinate
; ------------------------------------------------------------------------------

 
 
;------------------------------------------------------------------------------
; Initialize the sprites for the rivets stage
L_INIT_RIVETS_STAGE_SPRITES:  
		; Initialize the firefox sprites
		ld      hl,L_FIREFOX_SPRITE_DATA
        ld      de,FIREBALL_STRUCTS+7	; Sprite num entry
        ld      bc,TWO_BYTES(5,28)		; 5 sprites, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; Initialize the hammers
        ld      hl,L_RIVETS_HAMMER_COORDS
        call    L_INIT_HAMMER_SPRITES
        
        ; Initialize the prize sprites
        ld      hl,L_RIVETS_PRIZE_SPRITE_DATA
        ld      de,PRIZE_SPRITES
        ld      bc,12					; 3 sprites
        ldir    
        
        ; Initialize the two (invisible) collision detection sprites on either 
        ; side of Donkey Kong
        ld      hl,L_DK_COL_SPRITE_COORD_DATA
        ld      de,COLLISION_AREA_STRUCT+3	; X coordinate entry
        ld      bc,TWO_BYTES(2,30)		; 2 sprites, 32 byte data structures
        call    L_COPY_COORDS_TO_STRUCTS 
        ld      hl,L_DK_COL_SPRITE_DATA
        ld      de,COLLISION_AREA_STRUCT+7	; Sprite number entry
        ld      bc,TWO_BYTES(2,28)		; 2 sprites, 32 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; Misc data
        ld      ix,COLLISION_AREA_STRUCT
        ld      (ix+0),1					; Sprite active
        ld      (ix+32),1
        
        ; Copy the collision sprite data to the sprite data structures
        ld      hl,COLLISION_AREA_SPRITES
        ld      b,2						; 2 sprites
        ld      de,32						; 32 byte data structures
        call    L_COPY_STRUCT_TO_SPRITE
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; The following data is for the collision detection sprites on either side of
; Donkey Kong on the rivets stage
L_DK_COL_SPRITE_DATA:	
		.byte	$3f	; Blank sprite
		.byte	$0c	; Palette
		.byte	8
		.byte	8
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following coordinates define the position of the collision detection 
; sprites on either side of Donkey Kong on the rivets stage 
L_DK_COL_SPRITE_COORD_DATA:	
		.byte	115	; X coordinate
		.byte	80	; Y coordinate
		
		.byte	141	; X coordinate
		.byte	80	; Y coordinate
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize the spring data for the springs on the elevators stage
L_INIT_SPRING_DATA:  
		; Initialize the spring structure data
		ld      hl,L_INITIAL_SPRING_DATA
        ld      de,SPRING_STRUCTS+7				; Sprite number entry
        ld      bc,TWO_BYTES(10,12)				; 10 blocks, 16 byte data structures
        call    L_LD_SPRITE_DATA_TO_STRUCT
        
        ; Initialize the spring sprites from the spring data structures
        ld      ix,SPRING_STRUCTS
        ld      hl,SPRING_SPRITES
        ld      b,10
        ld      de,16
        call    L_COPY_STRUCT_TO_SPRITE
        ret     
;---------------------------------------------- 


;------------------------------------------------------
; Initial values for some of the spring structure data such as the initial 
; spring sprite number...
L_INITIAL_SPRING_DATA:	
		.byte	$3b	; Normal spring sprite
		.byte	$00	; The sprite palette
		.byte	2
		.byte	2
;------------------------------------------------------------------------------



;-------------------------------------------------------------------
; Initialize the hammer sprites for the current stage
;
; passed:	hl - the ROM address of the two hammer's coordinates
L_INIT_HAMMER_SPRITES:  
		; Initialize the hammer data structures
		ld      de,HAMMER_STRUCTS+3					; First x coord position
        ld      bc,TWO_BYTES(2,14)			; 2 blocks, 14
        call    L_COPY_COORDS_TO_STRUCTS
        ld      hl,L_HAMMER_SPRITE_DATA
        ld      de,HAMMER_STRUCTS+7			; Sprite number entry
        ld      bc,TWO_BYTES(2,12)	; 2 blocks, 16 bytes apart
        call    L_LD_SPRITE_DATA_TO_STRUCT
        ld      ix,HAMMER_STRUCTS
        
        ; Mark both hammers as active
        ld      (ix+0),1
        ld      (ix+16),1
        
        ; Copy hammer sprite data from the data structures to the sprite structures
        ld      hl,HAMMER_SPRITES
        ld      b,2						; 2 sprites
        ld      de,16					; Source data structure are 16 bytes long
        call    L_COPY_STRUCT_TO_SPRITE
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Copy sprite information from a data structure (ie the spring data structures)
; to a sprite data structure.
; For example, this function copies the x and y coordinates, and the sprite 
; number and palette from the spring data structures to the spring sprites.
;
; passed:	hl - address of the sprite to copy to
;			ix - address of the data structure to copy from
;			b - the number of data structures to copy
;			de - the distance between source data structures
L_COPY_STRUCT_TO_SPRITE:  
		; Copy the x coordinate
		ld      a,(ix+3)
        ld      (hl),a
        
        ; Copy the sprite number
        inc     l
        ld      a,(ix+7)
        ld      (hl),a
        
        ; Copy the sprite palette
        inc     l
        ld      a,(ix+8)
        ld      (hl),a
        
        ; Copy the y coordinate
        inc     l
        ld      a,(ix+5)
        ld      (hl),a
        
        ; Process the next structure
        inc     l
        add     ix,de
        djnz    L_COPY_STRUCT_TO_SPRITE
        
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Load x and y coordinates into one or more data structures
; The x and y coordinates are spaced two bytes apart
; passed:	hl - source address
;			de - destination address
;			b - the number of 2 byte blocks to copy
;			c - the distance between the destination blocks (- 2 bytes)
L_COPY_COORDS_TO_STRUCTS:  
		; Copy the x coordinate to the destination structure
		ld      a,(hl)
        ld      (de),a
        inc     hl
        
		; Copy the y coordinate to the destination structure
        inc     e
        inc     e
        ld      a,(hl)
        ld      (de),a
        
        ; Advance to the next data structure
        inc     hl
        ld      a,e
        add     a,c
        ld      e,a
        
        djnz    L_COPY_COORDS_TO_STRUCTS						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Load oil fire data into the oil fire sprite and data structure
; passed:	hl - source address
L_LOAD_BARREL_FIRE_DATA:  
		ld      ix,BARREL_FIRE_STRUCT
        ld      de,BARREL_FIRE_SPRITE
        
        ; Set the barrel fire structure active
        ld      (ix+0),1
        
        ; Load the fire x coordinate
        ld      a,(hl)
        ld      (ix+3),a
        ld      (de),a
        
        ; Load the fire tile number
        inc     e
        inc     hl
        ld      a,(hl)
        ld      (ix+7),a
        ld      (de),a
        
        ; Load the fire palette
        inc     e
        inc     hl
        ld      a,(hl)
        ld      (ix+8),a
        ld      (de),a
        
        ; Load the fire y coordinate
        inc     e
        inc     hl
        ld      a,(hl)
        ld      (ix+5),a
        ld      (de),a
        
        ; Load ???
        inc     hl
        ld      a,(hl)
        ld      (ix+9),a
        
        ; Load ???
        inc     hl
        ld      a,(hl)
        ld      (ix+10),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Load 4 bytes of basic sprite data (sprite number, palette, etc) from a ROM 
; address into sequential data structure.
; The same 4 byte block is copied to each destination
; passed:	hl - starting source address
;			de - starting destination address
;			b - the number of blocks to load
;			c - the size of the data structure (- 4 bytes)
L_LD_SPRITE_DATA_TO_STRUCT:  
		push    hl
        push    bc
        
        ; Copy 4 bytes from the the source to the destination
        ld      b,4						; For b = 4 to 1
l122e:  ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     e
        djnz    l122e					; Next b
        
        ; Restore the original source address and 
        pop     bc
        pop     hl
        
        ; Advance to the next destination address and continue
        ld      a,e
        add     a,c
        ld      e,a
        djnz    L_LD_SPRITE_DATA_TO_STRUCT
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize Mario (position and sprite number).  The number of lives are also 
; displayed (after the current life is deducted)
L_INIT_MARIO:  
		; Return until the minor timer has run down
		rst     $18
		
		; If current stage is elevators, set Mario's coordinate to (22,224)
        ld      a,(CURRENT_STAGE)
        cp      3
        ld      bc,TWO_BYTES(224,22)
        jp      z,l124b
        
        ; If current stage is not elevators, set Mario's coordinate to (63,240)
        ld      bc,TWO_BYTES(240,63)
        
        ; ix = first byte of Mario structure
l124b:  ld      ix,MARIO_DATA_STRUCT
        ld      hl,MARIO_SPRITE
        ld      (ix+0),1					; Mario is alive
        
        ; Set Mario's x coordinate
        ld      (ix+3),c					; X coordinate
        ld      (hl),c
        
        ; Set Mario's sprite to $00, facing right 
        inc     l
        ld      (ix+7),$80				; Sprite number
        ld      (hl),$80
        
        ; Set Mario's palette to $02
        inc     l
        ld      (ix+8),$02				; Sprite palette
        ld      (hl),$02
        
        ; Set Mario's y coordinate
        inc     l
        ld      (ix+5),b					; Y coordinate
        ld      (hl),b
        
        ; 
        ld      (ix+15),1
        
        ; Advance to the next substate
        ld      hl,GAME_SUBSTATE
        inc     (hl)
        
        ; Decrement and display the number of lives
        ld      de,$0601
        call    L_ADD_EVENT
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Implement Mario's death animation
L_IMPLEMENT_DEATH_ANIM:  
		; Award any pending pointdfs 
		call    L_IMPLEMENT_POINT_AWARD
		
		; Jump based on the current animation state
        ld      a,(DEATH_ANIMATION_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_PREPARE_DEATH_ANIMATION	; 0 = start death sequence animation
		.word	L_ROTATE_MARIO_DEAD_SPRITE	; 1 = advance death sequence
		.word	L_CLEAN_UP_DEATH_ANIMATION	; 2 = complete death sequence
		.word	L_ORG	; 3 = reset game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Prepare the death animation
L_PREPARE_DEATH_ANIMATION:  
		rst     $18						; Return until minor timer times out
		
		; Determine if the Mario sprite needs to be flipped horizontally
        ld      hl,MARIO_SPRITE_NUM
        ld      a,$f0
        rl      (hl)
        rra     
        ld      (hl),a
        
        ; Advance to the next animation state
        ld      hl,DEATH_ANIMATION_STATE
        inc     (hl)
        
        ; Set the death animation counter to 13
        ld      a,13
        ld      (DEATH_ANIMATION_COUNTER),a
        
        ; Set the minor timer to 8
        ld      a,8
        ld      (MINOR_TIMER),a
        
        call    L_CLEAR_SPRITES_WHEN_DEAD
        
        ; Trigger the death song
        ld      a,3
        ld      (DEATH_SOUND_TRIGGER),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Rotate Mario's death sprite to animate him spinning
L_ROTATE_MARIO_DEAD_SPRITE:  
		rst     $18						; Return until minor timer runs out
		
		; Set the minor timer to 8
        ld      a,8
        ld      (MINOR_TIMER),a
        
        
        ld      hl,DEATH_ANIMATION_COUNTER
        dec     (hl)
        jp      z,l12cb
        
        ld      hl,MARIO_SPRITE_NUM
        ld      a,(hl)
        rra     
        ld      a,$02
        rra     
        ld      b,a
        xor     (hl)
        ld      (hl),a
        
        inc     l
        ld      a,b
        and     %10000000
        xor     (hl)
        ld      (hl),a
        ret    
		
		; Set Mario's sprite to lying flat on his back,
		; vertically flipped as appropriate 
l12cb:  ld      hl,MARIO_SPRITE_NUM
        ld      a,$f4
        rl      (hl)
        rra     
        ld      (hl),a
        
        ; Advance the death animation state
        ld      hl,DEATH_ANIMATION_STATE
        inc     (hl)
        
        ; Initialize the minor timer to 128
        ld      a,128
        ld      (MINOR_TIMER),a
        
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clean up the death animation and advance to the next state
L_CLEAN_UP_DEATH_ANIMATION:	
		rst     $18						; Return until minor timer runs out
		
		; Clear out Mario's sprite
        call    L_CLEAR_MARIO_SPRITE
        
        ; If this is a one player game, advance the substate by one
        ld      hl,GAME_SUBSTATE
        ld      a,(SECOND_PLAYER)
        and     a
        jp      z,l12ed
        
        ; If this is a two player game, advance the substate by two
        inc     (hl)
        
        ; Advance the substate
l12ed:  inc     (hl)

		; Set the minor timer to 1
        dec     hl
        ld      (hl),1
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; After death processing for player 1.  Remove a life, and end the player's 
; game if there are no more lives left.
L_POST_DEATH_PROCESSING_P1:  
		call    L_SOUNDS_OFF
        
        ; Set the intro as having been displayed for the current player
        xor     a
        ld      (CP_INTRO_NOT_DISPLAYED),a
        
        ; Subtract a life
        ld      hl,CP_NUMBER_LIVES
        dec     (hl)
        ld      a,(hl)
        
        ; Save the current player data to the first player data
        ld      de,P1_DATA
        ld      bc,8
        ldir    
        
        ; If player 1 has more lives, jump ahead
        and     a
        jp      nz,l1334
        
        ; Check if player 1's score qualifies for the high score list
        ld      a,1						; Player 1 ID
        ld      hl,PREV_P1_SCORE
        call    L_ADD_SCORE_TO_HS_TABLE
        
        ; If there is only 1 player, jump ahead to skip displaying the player I prompt
        ld      hl,TILE_COORD(22,20)
        ld      a,(TWO_PLAYERS)
        and     a
        jr      z,l1322
        
        ; Display the player I string
        ld      de,$0302
        call    L_ADD_EVENT
        dec     hl
l1322:  call    L_CLEAR_AROUND_GAME_OVER

		; Display "GAME OVER"
        ld      de,$0300
        call    L_ADD_EVENT
        
        ; Set the minor timer to 192
        ld      hl,MINOR_TIMER
        ld      (hl),192
        
        ; Set game substate to 16 and return
        inc     hl
        ld      (hl),16
        ret     
        
        ; If there is only 1 player, jump ahead to advance to substate 8
l1334:  ld      c,8
        ld      a,(TWO_PLAYERS)
        and     a
        jp      z,l133f
        
        ; If there are 2 players, advance the substate to 23
        ld      c,23
        
l133f:  ld      a,c
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; After death processing for player 1.  Remove a life, and end the player's 
; game if there are no more lives left.  
L_POST_DEATH_PROCESSING_P2:  
		call    L_SOUNDS_OFF
        
        ; Set the intro as having been displayed for the current player
        xor     a
        ld      (CP_INTRO_NOT_DISPLAYED),a
        
        ; Subtract a life
        ld      hl,CP_NUMBER_LIVES
        dec     (hl)
        ld      a,(hl)
        
        ; Save the current player data to the first player data
        ld      de,P2_NUMBER_LIVES
        ld      bc,8
        ldir    
        
        ; If player 1 has more lives, jump ahead
        and     a
        jp      nz,l137f
        
        ; Check if player 1's score qualifies for the high score list
        ld      a,3						; Player 2 ID
        ld      hl,PREV_P2_SCORE
        call    L_ADD_SCORE_TO_HS_TABLE
        
        ; Display the player II string
        ld      de,$0303
        call    L_ADD_EVENT
        
        ; Display "GAME OVER"
        ld      de,$0300
        call    L_ADD_EVENT
        ld      hl,TILE_COORD(22,19)
        call    L_CLEAR_AROUND_GAME_OVER
        
        ; Set the minor timer to 192
        ld      hl,MINOR_TIMER
        ld      (hl),192
        
        ; Set game substate to 17 and return
        inc     hl
        ld      (hl),$11
        ret     
        
        ; If player 1 has lives left, jump ahead to advance to game substate 23
l137f:  ld      c,$17
        ld      a,(P1_NUMBER_LIVES)
        and     a
        jp      nz,l138a
        
        ; If player 1 has no more lives, advance to substate 8
        ld      c,8
l138a:  ld      a,c
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function is called when Player 1's game is over.
; It checks if Player 2 has lives left and advances to the appropriate substate
L_ADV_FROM_P1_GAME_OVER:  
		; Return until the minor timer runs down
		rst     $18
		
		; If player 2 has more lives, jump ahead to advance to substate 23
		; (move on to the next player)
        ld      c,23
        ld      a,(P2_NUMBER_LIVES)
l1395:  inc     (hl)						; MINOR_TIMER = 1
        and     a
        jp      nz,l139c
        
        ; If player 2 has no more lives, advance to substate 20
        ; (Check if high scores need to be entered)
        ld      c,20
l139c:  ld      a,c
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function is called when Player 2's game is over.
; It checks if Player 1 has lives left and advances to the appropriate substate
L_ADV_FROM_P2_GAME_OVER:  
		; Return until the minor timer runs down
		rst     $18
		
        ; If player 1 has more lives, jump ahead to advance to substate 23
		; (move on to the next player)
		; If player 1 has no more lives left, advance to substate 20 
		; (Check if high scores need to be entered)
		ld      c,23
        ld      a,(P1_NUMBER_LIVES)
        jp      l1395
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Prepare for player 2's turn.  
; Orient the screen and activate player 2. 
L_PREPARE_FOR_P2_TURN:  
		; Orient the screen for player 2
		; (Flipped vertically for cocktail cabinets) 
		ld      a,(CABINET_TYPE)
        ld      (SCREEN_ORIENTATION),a
        
        ; Set substate to 0
        xor     a
        ld      (GAME_SUBSTATE),a
        
        ; Activate player 2
        ; Set CURRENT_PLAYER to 1 (player 2)
        ; and SECOND_PLAYER to 1
        ld      hl,TWO_BYTES(1,1)
        ld      (CURRENT_PLAYER),hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Prepare for player 2's turn.  
; Orient the screen and activate player 2. 
L_PREPARE_FOR_P1_TURN:  
		; Activate player 1
		xor     a
        ld      (CURRENT_PLAYER),a
        ld      (SECOND_PLAYER),a
        
        ; Set substate to 0
        ld      (GAME_SUBSTATE),a
        
        ; Orient the screen upright
		inc     a
        ld      (SCREEN_ORIENTATION),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check if the player's score needs to be added to the high score table and
; insert it.
; I won't pretend that I've actually analyzed this code enough to really 
; understand what it's doing...
; passed:	a - the number of the player whose score is being checked
;				(1 for player 1, 3 for player 2)
;			hl - the address of the player's score
L_ADD_SCORE_TO_HS_TABLE:  
		
		ld      de,$61c6
        ld      (de),a
        
        ; Return if the demo mode is active
        rst     $08
        
        ; Copy the current player's score to $61c7
        inc     de
        ld      bc,3						; 3 bytes to copy
        ldir    
        
        ; Separate and store each digit in the score
        ld      b,3						; For b = 3 to 1
        ld      hl,CURRENT_SCORE_STRING
        
        ; Isolate the MS nibble of the previos byte of the score
l13da:  dec     de
        ld      a,(de)
        rrca    
        rrca    
        rrca    
        rrca    
        and     %00001111
        
        ; Save this digit 
        ld      (hl),a
        inc     hl
        
        ; Isolate the LS nibble
        ld      a,(de)
        and     %00001111
        
        ; Save the digit
        ld      (hl),a
        inc     hl
        
        djnz    l13da						; Next b
        
        ; Clear the next 14 bytes of the score string
        ld      b,14
l13ed:  ld      (hl),$10					; Space
        inc     hl
        djnz    l13ed
        
        ; Mark the end of the high score string
        ld      (hl),$3F
        
        ld      b,5
        
        ; Subtract the current high score entry from the current player's score
        ; Return if the high score is higher than the player's score
        ld      hl,$61a5
        ld      de,$61c7
l13fc:  ld      a,(de)
        sub     (hl)
        inc     hl
        inc     de
        ld      a,(de)
        sbc     a,(hl)
        inc     hl
        inc     de
        ld      a,(de)
        sbc     a,(hl)
        ret     c
        
        ; Add the player's score to the high score table
        push    bc
        ld      b,25
l140a:  ld      c,(hl)
        ld      a,(de)
        ld      (hl),a
        ld      a,c
        ld      (de),a
        dec     hl
        dec     de
        djnz    l140a
        
        ld      bc,-11
        add     hl,bc
        ex      de,hl
        add     hl,bc
        ex      de,hl
        pop     bc
        djnz    l13fc
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Determines if either player needs to enter high score initials
L_CHECK_FOR_HS_INITIALS:  
		call    L_DISPLAY_CREDITS_2
        
        ; Return until the minor timer runs down
		rst     $18
        
        call    L_CLEAR_STAGE_SCREEN
        
        ; Activate player 1
        ld      a,0
        ld      (SECOND_PLAYER),a
        ld      (CURRENT_PLAYER),a
        
        ld      hl,HIGH_SCORE_TABLE_ENTRY_1+28	; Player ID
        ld      de,34					; 34 byte data structure
        ld      b,5						; For b = 5 to 1 (5 high score entries)
        
        ; If this score was earned by player 1, jump ahead
        ld      a,1						; Player 1 ID
l1437:  cp      (hl)
        jp      z,l1459
        
        ; Check the next high score entry
        add     hl,de
        djnz    l1437						; Next b
        
        ld      hl,HIGH_SCORE_TABLE_ENTRY_1+28	; Player ID
        ld      b,5						; For b = 5 to 1 (5 high score entries)
        
        ; If this score was earned by player 2, jump ahead
        ld      a,3						; Player 2 ID   
l1445:  cp      (hl)
        jp      z,l144f
        
        ; Check the next high score entry
        add     hl,de
        djnz    l1445						; Next b
        
        ; If neither player earned a high score, start the game
        jp      L_RESTART_GAME
        
        ; Activate player 2
l144f:  ld      a,1
        ld      (SECOND_PLAYER),a
        ld      (CURRENT_PLAYER),a
        
        ; Orient the screen for the player with the high score
        ld      a,0
l1459:  ld      hl,CABINET_TYPE
        or      (hl)
        ld      (SCREEN_ORIENTATION),a
        
        ; Advance to the next substate
        ld      a,0
        ld      (MINOR_TIMER),a
        ld      hl,GAME_SUBSTATE
        inc     (hl)
        
        ; Display 
        ; "NAME REGISTRATION"
        ; "NAME:"
		; "---         "
		; "A B C D E F G H I J"
		; "K L M N O P Q R S T"
		; "U V W X Y Z . -RUBEND "
		; "REGI TIME  (30) "
		; and the 5 high scores
		ld      de,$030d
        ld      b,12						; For b = 12 to 1 (12 strings to display)
l146e:  call    L_ADD_EVENT
        inc     de						; Next string
        djnz    l146e					; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Restart the game to waiting for a coin
L_RESTART_GAME:  
		ld      a,1
        ld      (SCREEN_ORIENTATION),a
        ld      (GAME_STATE),a
        ld      (NO_COINS_INSERTED),a
        ld      a,0
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function implements the high score initial entry screen
; The user is allowed to navigate through the initial letters and enter their 
; initials.
;
; Note: it appears that it would not be difficult to alter this code to allow
;	   names of up to 12 characters to be entered
L_IMPLEMENT_HS_INITIAL_ENTRY:  
		call    L_DISPLAY_CREDITS_2

		; Jump ahead if the minor timer has not run out
        ld      hl,MINOR_TIMER
        ld      a,(hl)
        and     a
        jp      nz,l14dc
        
        ; Palette 00
        ld      (PALETTE_1_OUTPUT),a
        ld      (PALETTE_2_OUTPUT),a
        
        ; Set minor timer to 1
        ld      (hl),1
        
        ; Initialize JOYSTICK_INPUT_DELAY to 10
        ld      hl,JOYSTICK_INPUT_DELAY
        ld      (hl),10
        
        ; Set 
        inc     hl
        ld      (hl),0					; BLANK_CP_HIGH_SCORE
        
        inc     hl
        ld      (hl),16					; BLINK_SCORE_TIMER
        
        inc     hl
        ld      (hl),30					; INITIALS_TIMER_VALUE
        
        inc     hl
        ld      (hl),62					; INITIALS_TIMER_DELAY				
        
        inc     hl
        ld      (hl),0					; SELECTED_LETTER
        
        ld      hl,TILE_COORD(15,8)
        ld      (INITIALS_COORD),hl
        
        ; Determine this player's ID (1 = player 1, 3 = player 2)
        ld      hl,HIGH_SCORE_TABLE_ENTRY_1+28 ; Player ID
        ld      a,(SECOND_PLAYER)
        rlca    
        inc     a
        ld      c,a
        
        ; Check each high score entry to find the one for this player
        ld      de,34						; 34 byte high score data structure
        ld      b,4						; For b = 4 to 1
l14c1:  ld      a,(hl)
        cp      c
        jp      z,l14c9
        add     hl,de						; Next high score entry
        djnz    l14c1						; Next b
        
        ; Save the address of the high score entry player ID
l14c9:  ld      (PLAYER_ID_ADDRESS),hl

		; Save the position in the string to write the player's initials to
        ld      de,-13
        add     hl,de
        ld      (INITIALS_ADDRESS),hl
		
		; Display the letter selection box over the currently selected letter 
		; (initially 'A')
        ld      b,0
        ld      a,(SELECTED_LETTER)
        ld      c,a
        call    L_UPDATE_LETTER_SEL_BOX
		
		; If the initials timer delay has not run down, jump ahead to skip
		; decrementing and displaying the initials timer value
l14dc:  ld      hl,INITIALS_TIMER_DELAY
        dec     (hl)
        jp      nz,l14fc
		
		; Reset the initials timer delay
        ld      (hl),62
		
		; Decrement the initials countdown timer and jump ahead, if it has reached zero
        dec     hl
        dec     (hl)
        jp      z,l15c6
        
		; Determine the 10's (a) and 1's (b) digit of the initials timer value
		ld      a,(hl)
        ld      b,255
l14ed:  inc     b
        sub     10
        jp      nc,l14ed
        add     a,10
		
		; Display the 10's digit
        ld      (TILE_COORD(10,18)),a
		
		; Display the 1's digit
        ld      a,b
        ld      (TILE_COORD(11,18)),a
		
		; Initialize the joystick input delay to 10
l14fc:  ld      hl,JOYSTICK_INPUT_DELAY
        ld      b,(hl)
        ld      (hl),10
		
		; If the player has pushed the JUMP button (to select the current letter),
		; jump ahead to process it
        ld      a,(PLAYER_INPUT)
        bit     7,a
        jp      nz,l1546
		
		; If the player has pushed the joystick either LEFT or RIGHT (to change the
		; current letter), jump ahead to process it
        and     %00000011
        jp      nz,l1514
		
		; The joystick is not currently being pressed in any direction
		; so set the joystick input delay to 1 so the next time the joystick
		; is used, it will be processed immediately 
        inc     a							; a = 1
        ld      (hl),a
		
		; Jump ahead to blink the current player's high score
        jp      l158a
		
		; Decrement the joystick input delay
		; Jump ahead to handle the input only if the delay has reached 0
		; (Otherwise the input is ignored)
l1514:  dec     b
        jp      z,l151d
        ld      a,b
        ld      (hl),a
		
		; Jump ahead to blink the current player's high score
        jp      l158a
		
		; If the player pushed the joystick LEFT, jump ahead to process it
l151d:  bit     1,a
        jp      nz,l1539
		
		; The player pushed the joystick RIGHT
		; Select the next letter to the right
        ld      a,(SELECTED_LETTER)
        inc     a
        
        ; If the letter selection does not need to wrap, jump ahead 
        cp      30
        jp      nz,l152d
        
        ; Wrap the letter selection back to the first letter
        ld      a,0
        
        ; Move the letter selection sprite to the newly selected letter
l152d:  ld      (SELECTED_LETTER),a
        ld      c,a
        ld      b,0
        call    L_UPDATE_LETTER_SEL_BOX
        
        ; Jump ahead to blink the current player's high score
        jp      l158a
        
        ; The player pushed thw joystick LEFT
        ; Select the next letter to the left
l1539:  ld      a,(SELECTED_LETTER)
        sub     1
        
        ; If the letter selection does not need to be wrapped around, 
        ; jump back up to update the letter selection box sprite
        jp      p,l152d
        
        ; Wrap the letter selection box around to the last letter
        ld      a,29
        
        ; Jump back up to update the letter selection box sprite
        jp      l152d
        
        ; The player pushed the JUMP button
        ; If "RUB" was selected, jump ahead to process it
l1546:  ld      a,(SELECTED_LETTER)
        cp      28
        jp      z,l156d
        
        ; If "END" was selected, jump ahead to process it
        cp      29
        jp      z,l15c6
        
        ; If the last initial entry position has been reached, 
        ; jump ahead to skip the letter selection and blink the current player's score
        ld      hl,(INITIALS_COORD)
        ld      bc,TILE_COORD(12,8)
        and     a						; Clear the carry flag
        sbc     hl,bc
        jp      z,l158a
        
        ; Convert the selected letter index to the actual letter
        add     hl,bc
        add     a,17
        
        ; Display the selected letter
        ld      (hl),a
        
        ; Advance to the next initial letter entry coordinate
        ld      bc,-32
        add     hl,bc
l1567:  ld      (INITIALS_COORD),hl

		; Jump ahead to blink the current player's high score
        jp      l158a
        
        ; "RUB" was selected
        ; Move left one initial letter entry coordinate
l156d:  ld      hl,(INITIALS_COORD)
        ld      bc,32
        add     hl,bc
        
        ; If the first initial entry coordinate has not been reached,
        ; jump ahead  
        and     a						; Clear the carry flag
        ld      bc,TILE_COORD(16,8)
        sbc     hl,bc
        jp      nz,l1586
        
        ; Keep the initial letter entry from going past the first entry coordinate
        ld      hl,TILE_COORD(15,8)
        
        ; Erase the initial letter
l1580:  ld      a,$10
        ld      (hl),a
        jp      l1567
        
        ; Erase the initial letter to the left
l1586:  add     hl,bc
        jp      l1580
				
		; If the blink timer has not run down, jump ahead
l158a:  ld      hl,BLINK_SCORE_TIMER
        dec     (hl)
        jp      nz,l15f9
		
		; If the blank score toggle is currently off, jump ahead to turn it on
		; and display the current player's high score
        ld      a,(BLANK_CP_HIGH_SCORE)
        and     a
        jp      nz,l15b8
		
		; Turn the blank score toggle on to cause the score to be blinked off
        ld      a,1
        ld      (BLANK_CP_HIGH_SCORE),a
		
		; Load the address of blank score data
        ld      de,L_BLANK_SCORE_DATA
		
		; Load the screen coordinate to display the current player's high score
l15a0:  ld      iy,(PLAYER_ID_ADDRESS)
        ld      l,(iy+4)
        ld      h,(iy+5)
		
		; Display the high score (or the blank score data)
        push    hl
        pop     ix							; The screen coordinate
        call    L_DISPLAY_HIGH_SCORE_2
		
		; Reset the blink score timer to 16
        ld      a,16
        ld      (BLINK_SCORE_TIMER),a
		
        jp      l15f9
		
		; Toggle display of the score off
l15b8:  xor     a
        ld      (BLANK_CP_HIGH_SCORE),a
		
		; Set DE to the last byte of the high score BCD entry
        ld      de,(PLAYER_ID_ADDRESS)
        inc     de
        inc     de
        inc     de
		
		; Jump back up to blank the score
        jp      l15a0
		
		; Clear the player ID, for this high score entry as it is no longer needed
l15c6:  ld      de,(PLAYER_ID_ADDRESS)
        xor     a
        ld      (de),a
		
		; Reset the minor timer to 128
        ld      hl,MINOR_TIMER
        ld      (hl),128
		
		; Decrement the game substate
l15d1:  inc     hl
        dec     (hl)
		
		; Copy the initials the player entered to the high score entry
		; NOTE: Although only 3 initials are accepted, 12 characters are copied
		;		Is it possible, the programmers originally intended to use all 12
		;		characters for the player's name?
        ld      b,12						; For b = 12 to 1 (12 characters to copy)
        ld      hl,TILE_COORD(15,8)
        ld      iy,(INITIALS_ADDRESS)
        ld      de,-32
l15df:  ld      a,(hl)
        ld      (iy+0),a
        inc     iy
        add     hl,de
        djnz    l15df						; Next b
		
		; Redisplay the high score table
        ld      b,5							; For b = 5 to 1 (5 high scores to redisplay)
        ld      de,$0314
l15ed:  call    L_ADD_EVENT
        inc     de
        djnz    l15ed						; Next b
		
		; Display "YOUR NAME WAS REGISTERED"
        ld      de,$031a					
        call    L_ADD_EVENT
		
l15f9:  ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Update the letter selection sprite on the High Score entry screen over the
; currently selected letter
;
; passed:	bc - the index number of the currently selected letter in the 
;				high score letter coordinate table
L_UPDATE_LETTER_SEL_BOX:  
		push    de
        push    hl
		
		; Multiply the letter index by two to convert it to a table offset
        sla     c
		
		; Look up the letter coordinates in the table
        ld      hl,L_HS_LETTER_COORD_TABLE
        add     hl,bc
        ex      de,hl
		
		; Position the letter selection box sprite over the selected letter
        ld      hl,ELEVATOR_MOTOR_SPRITE_2_X	; Used in this case for the letter selection box sprite
        ld      a,(de)
        inc     de
        ld      (hl),a						; X coordinate
        inc     hl
        ld      (hl),$72					; Letter selection box sprite
        inc     hl
        ld      (hl),$0c					; Palette
        inc     hl
        ld      a,(de)						; Y coordinate
        ld      (hl),a
		
        pop     hl
        pop     de
        
		ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display each stage of the standard stage win animation
; The win animations for the mixer and rivets stages are handled elsewhere
L_IMPLEMENT_STAGE_WIN_ANIM:  
		call    L_CLEAR_SPRITES_WHEN_DEAD
		
		; If the current stage is mixer or rivets, jump ahead for 
		; their win animations
        ld      a,(CURRENT_STAGE)
        rrca    
        jp      nc,L_IMPLEMENT_MIXER_WIN_ANIM
        
        ; Jump based on the state of the win animation
        ld      a,(WIN_ANIMATION_STATE)
l1622:  rst     $28							; Jump to local table address
		; Jump table
        .word	L_WIN_STAGE_ANIM_0	; 0 = Donkey Kong climbing animation 0
		.word	L_WIN_STAGE_ANIM_1	; 1 = Donkey Kong climbing animation 1
		.word	L_WIN_STAGE_ANIM_2	; 2 = Donkey Kong climbing animation 2
		.word	L_WIN_STAGE_ANIM_3	; 3 = Donkey Kong climbing animation 3 (Donkey Kong grabs Pauline)
		.word	L_WIN_STAGE_ANIM_4	; 4 = Donkey Kong climbing animation 4
		.word	L_ADVANCE_TO_NEXT_STAGE	; 5 = Donkey Kong climbing animation 5
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display each stage of the mixer stage win animation
; The win animations for the rivets stage is handled elsewhere
L_IMPLEMENT_MIXER_WIN_ANIM:  
		; If this is the rivets stage, jump ahead to implement that win animation
		rrca    
        jp 		nc,L_IMPLEMENT_RIVETS_WIN_ANIM
        
        ld      a,(WIN_ANIMATION_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_MIXER_WIN_STAGE_ANIM_0	; 0 = 
		.word	L_WAIT_FOR_DK_TO_REACH_LADDERS	; 1 = 
		.word	L_WIN_STAGE_ANIM_3	; 2 = 
		.word	L_WIN_STAGE_ANIM_4	; 3 = 
		.word	L_ADVANCE_TO_NEXT_STAGE	; 4 = 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_IMPLEMENT_RIVETS_WIN_ANIM:  
		
		call    L_IMPLEMENT_POINT_AWARD
        ld      a,(WIN_ANIMATION_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_RIVETS_WIN_STAGE_ANIM_0	; 0 = 
		.word	L_PAUSE_CURRENT_STATE		; 1 = 
		.word	L_RIVETS_WIN_STAGE_ANIM_1	; 2 = 
		.word	L_RIVETS_WIN_STAGE_ANIM_2	; 3 = 
		.word	L_RIVETS_WIN_STAGE_ANIM_3	; 4 = 
		.word	L_RIVETS_WIN_STAGE_ANIM_4	; 5 = 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_WIN_STAGE_ANIM_0:	
		; Display Pauline standing with a heart next to her
		; Also start playing the standard win stage tune
		call L_WIN_ANIM_DISPLAY_PAULINE
		
		; Display Donkey Kong with his left arm raised
        ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        
        ; Initialize the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a

		; Advance to the next stage of the animation
l1662:  ld      hl,WIN_ANIMATION_STATE
        inc     (hl)

		; Return unless this is the barrels stage
        ld      a,$01
        rst     $30							; Return unless this is the barrels stage
        
        ; Move Donkey Kong up 4 pixels
        ld      hl,DK_SPRITE_1_Y
        ld      c,$fc
        rst     $38
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_WIN_STAGE_ANIM_1:	
		; Return until the minor timer has reached 0
		rst     $18
        
        ; Change Donkey Kong's sprites
        ld      hl,L_DK_SPRITES_THROW_BARREL
        call    L_LOAD_DK_SPRITES
        
        ; Reset the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a
        
        ; Advance to the next animation stage
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        
        ; Return unless this is the elevators stage
        ld      a,4
        rst     $30
        
        ; Move Donkey Kong up 4 pixels
        ld      hl,DK_SPRITE_1_Y
l1686:  ld      c,4
        rst     $38
        
        ret     
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
L_WIN_STAGE_ANIM_2:  
		; Return until the minor timer has reached 0
		rst     $18
        
        ; Change the Donkey Kong sprites
        ld      hl,L_DK_SPRITES_CLIMBING
        call    L_LOAD_DK_SPRITES
        
        ; Show Donkey Kong's right arm climbing the ladder
        ld      a,102
        ld      (DK_SPRITE_2_X),a
        
        ; Hide the sprites showing Donkey Kong carrying Pauline
        xor     a						; a = 0
        ld      (DK_SPRITE_8_X),a
        ld      (DK_SPRITE_10_X),a
        ld      (DK_CLIMBING_COUNTER),a
        
        ; Jump back to advance the animation state and
        ; move Donkey Kong into position
        jp      l1662
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_MIXER_WIN_STAGE_ANIM_0:  
		; Display Pauline standing with a heart next to her
		call    L_WIN_ANIM_DISPLAY_PAULINE
		
		; Determine where the conveyer has moved Donkey Kong
        ld      a,(DK_SPRITE_3_X)
        sub     59
        
        ; Load new Donkey Kong sprites
        ld      hl,L_DK_SPRITES_L_ARM_RAISED
		call    L_LOAD_DK_SPRITES
		
		; Move Donkey Kong back to where the conveyer has moved him
        ld      hl,DK_SPRITE_1_X
        ld      c,a
        rst     $38
        
        ; Advance to the next animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Wait for the conveyer belt to move Donkey Kong to the escape ladders
L_WAIT_FOR_DK_TO_REACH_LADDERS:  
		; Set the conveyer reverse timer to 256 (maximum)
		xor     a
        ld      (TOP_MASTER_REVERSE_TIMER),a
        
        ; Save the top conveyer's direction
        ld      a,(TOP_CONVEYER_DIR)
        ld      c,a
        
        ; If Donkey Kong is to the right of x coordinate 90,
        ; jump ahead
        ld      a,(DK_SPRITE_3_X)
        cp      90
        jp      nc,l16e1
        
        ; If Donkey Kong is to the left of x coordinate 90 and
		; the conveyer is moving right, jump ahead
        bit     7,c
        jp      z,l16d5
        
        ; Set the conveyer reverse timer to 1 so that it will reverse
		; immediately
l16d0:  ld      a,1
        ld      (TOP_MASTER_REVERSE_TIMER),a
		
l16d5:  call    L_IMPLEMENT_TOP_CONVEYER
	
		; Move Donkey Kong along the conveyer belt
        ld      a,(TOP_CONVEYER_DIR)
        ld      c,a
        ld      hl,DK_SPRITE_1_X
        rst     $38
        ret     
		
		; If Donkey Kong is to the left of x coordinate 93,
		; jump ahead because he's in the sweet spot
l16e1:  cp      93
        jp      c,l16ee
        
        ; If Donkey Kong is to the right of x coordinate 93 and
		; the conveyer is moving right, jump ahead
        bit     7,c
        jp      z,l16d0
        
		; Jump back up to reverse the conveyer belt
        jp      l16d5
        
		; Change Donkey Kong's sprites to climbing
l16ee:  ld      hl,L_DK_SPRITES_CLIMBING
        call    L_LOAD_DK_SPRITES
		
		; Display Donkey Kong's right climbing arm
        ld      a,102
        ld      (DK_SPRITE_2_X),a
		
		; Hide Donkey Kong's right carrying arm and Pauline being carried
        xor     a
        ld      (DK_SPRITE_8_X),a
        ld      (DK_SPRITE_10_X),a
		
		; Zero the climbing counter
        ld      (DK_CLIMBING_COUNTER),a
		
		; Advance the win animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Update Pauline for the stage win animation
; Pauline is displayed with a heart next to her
L_WIN_ANIM_DISPLAY_PAULINE:  
		call    L_SOUNDS_OFF

		; Initialize the heart sprite that appears next to Pauline during the
		; win stage animation
        ld      hl,HEART_SPRITE_X
        ld      (hl),128
        inc     hl
        ld      (hl),$76					; HEART_SPRITE_NUM
        inc     hl
        ld      (hl),$09					; HEART_SPRITE_PAL
        inc     hl
        ld      (hl),32					; HEART_SPRITE_Y
        
        ; Display Pauline standing calmly
        ld      hl,PAULINE_LOWER_SPRITE_NUM
        ld      (hl),$13
        
        ; Clear the "HELP!" tiles to Pauline's right
        ld      hl,TILE_COORD(14,4)
        ld      de,32
        ld      a,$10						; Blank tile
        call    L_DISPLAY_OR_CLEAR_HELP						; Clear HELP!
        
        ; Play the standard win stage song (triggered three times)
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_STAGE_END
        inc     hl
        ld      (hl),3
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_WIN_STAGE_ANIM_3:  
		; Animate Donkey Kong climbing up the exit ladders
		call    L_ANIMATE_CLIMBING_LADDERS
        
        ; Return if Donkey Kong hasn't yet reached Pauline's platform
        ld      a,(DK_SPRITE_3_Y)
        cp      44
        ret     nc
        
        ; Hide Pauline's sprites
        xor     a
        ld      (PAULINE_UPPER_SPRITE_X),a
        ld      (PAULINE_LOWER_SPRITE_X),a
        
        ; Hide Donkey Kong's climbing right arm sprite
        ld      (DK_SPRITE_2_X),a
        
        ; Display Donkey Kong's right arm carrying sprite
        ld      a,107
        ld      (DK_SPRITE_8_X),a
        
        ; Display Pauline being carrying sprite
        dec     a
        ld      (DK_SPRITE_10_X),a
        
        ; Replace the heart sprite with the broken heart sprite
        ld      hl,HEART_SPRITE_NUM
        inc     (hl)
        
        ; Advance to the next win animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_WIN_STAGE_ANIM_4:  
		; Animate Donkey Kong climbing off the stage
		call    L_ANIMATE_CLIMBING_LADDERS
        call    L_HIDE_OFFSCREEN_DK_SPRITES
        
        ; Return until all of Donkey Kong's sprites are hidden 
        ; (Donkey Kong has climbed completely offscreen)
        inc     hl						; hl = x coordinate of first Donkey Kong sprite
        inc     de						; de = 4
        call    L_CHECK_IF_DK_SPRITES_HIDDEN
        
        ; Set minor timer to 64
        ld      a,64
        ld      (MINOR_TIMER),a
        
        ; Advance to the next animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function hidesach sprite in Donkey Kong as it goes off screen
L_HIDE_OFFSCREEN_DK_SPRITES:  
		; Check each sprite in Donkey Kong
		ld      de,3
        ld      hl,DK_SPRITE_10_Y
        ld      b,10						; For b = 10 to 1 (10 sprites in Donkey Kong)

		; If this Donkey Kong sprite has not gone off the screen yet,
		; jump ahead to process the next sprite
l1774:  and     a							; Clear carry flag
        ld      a,(hl)						; a = sprite y coordinate
        sbc     hl,de						; hl = sprite x coordinate
        cp      25
        jp      nc,l177f
        
        ; Hide this sprite
        ld      (hl),0
        
        ; Move on to the next sprite
l177f:  dec     hl
        djnz    l1774						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function checks each sprite in Donkey Kong to see if they've been hidden
; If all the sprites have been hidden, the function simply returns
; If there are still unhidden sprites, the calling function is aborted
L_CHECK_IF_DK_SPRITES_HIDDEN:  
		; Check each Donkey Kong sprite
		ld      b,10						; For b = 10 to 1 (10 sprites in Donkey Kong)

		; If this sprite has not been hidden, return from the calling function
l1785:  ld      a,(hl)
        and     a
        jp      nz,l0026
        
        ; Next sprite
        add     hl,de
        djnz    l1785						; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_ADVANCE_TO_NEXT_STAGE:  
		; Return until the minor timer expires
		rst     $18
		
		; Advance to the next stage
        ld      hl,(CP_STAGE_ORDER_POINTER)
        inc     hl
        
        ; If the end the stage data has not been reached, jump ahead
        ld      a,(hl)
        cp      $7f
        jp      nz,l179d
        
        ; Repeat level 5's stage order indefinately
        ld      hl,L_STAGE_ORDER_TABLE_LAST
        ld      a,(hl)
        
        ; Update the current stage
l179d:  ld      (CP_STAGE_ORDER_POINTER),hl
        ld      (CURRENT_STAGE),a
        
        ; Display the timer and add it to the player's score
        ld      de,$0500
        call    L_ADD_EVENT
        
        ; Reset the win animation state
        xor     a
        ld      (WIN_ANIMATION_STATE),a
        
        ; Set the minor timer to 48
        ld      hl,MINOR_TIMER
        ld      (hl),48
        
        ; Set the game substate to 8
        ; (Intermission)
        inc     hl
        ld      (hl),8
        ret     
;------------------------------------------------------------------------------

	

;------------------------------------------------------------------------------
L_RIVETS_WIN_STAGE_ANIM_0:  
		; Note: the following 'nop' should be discardable
		nop     							; I have no idea why this is here...
		
		; Trigger the rivet stageg end song
		call    L_SOUNDS_OFF
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_RIVET_END
        inc     hl
        ld      (hl),3
        
        ; Clear all "HELP!" tiles around Pauline
        ld      a,$10						; Blank tile
        ld      de,32
        ld      hl,TILE_COORD(17,3)
        call    L_DISPLAY_OR_CLEAR_HELP		; Clear HELP!
        ld      hl,TILE_COORD(12,3)
        call    L_DISPLAY_OR_CLEAR_HELP		; Clear HELP!
        
        ; Clear each detached platform and redisplay it as fallen
        ld      hl,TILE_COORD(22,26)
        call    L_CLEAR_AROUND_GAME_OVER
        ld      de,L_RIVETS_DATA_FALL1
        call    L_DISPLAY_STAGE
        ld      hl,TILE_COORD(22,21)
        call    L_CLEAR_AROUND_GAME_OVER
        ld      de,L_RIVETS_DATA_FALL2
        call    L_DISPLAY_STAGE
        ld      hl,TILE_COORD(22,16)
        call    L_CLEAR_AROUND_GAME_OVER
        ld      de,L_RIVETS_DATA_FALL3
        call    L_DISPLAY_STAGE
        ld      hl,TILE_COORD(22,11)
        call    L_CLEAR_AROUND_GAME_OVER
        ld      de,L_RIVETS_DATA_FALL4
        call    L_DISPLAY_STAGE
        
        ; Change Donkey Kong's sprites
        ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        ld      hl,DK_SPRITE_1_X
        ld      c,68
        rst     $38
        
        ; Update Pauline
        ld      hl,PAULINE_LOWER_SPRITE_NUM
        ld      (hl),$13
        
        ; Set the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a
        
        ; Set the animation timer to 128 to control Donkey Kong and Pauline's animation
        ld      a,128
        ld      (ANIMATION_TIMER),a
        
        ; Increment the animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ld      (CURRENT_STATE_VAR_POINTER),hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clear the section of the screen around the game over message
; passed:	hl - the starting tile coordinate
L_CLEAR_AROUND_GAME_OVER:  
		ld      de,-37
        ld      c,14						; For c = 14 to 1 
        ld      a,$10					; Space
l182d:  ld      b,5						; For b = 5 to 1
l182f:  ld      (hl),a
        inc     hl
        djnz    l182f
        add     hl,de					; 
        dec     c
        jp      nz,l182d					; Next c
        
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
L_RIVETS_WIN_STAGE_ANIM_1:  
		; If the animation timer has rolled over, jump ahead
		ld      hl,ANIMATION_TIMER
        inc     (hl)
        jp      z,l1859
        
        ; Return if the lowest 3 bits are not 0s
        ld      a,(hl)
        and     %0000111
        ret     nz
        
        ; If bit 3 of the animation timer is 1,
        ; jump ahead to make Donkey Kong stomp on his left foot
        ld      de,L_DK_SPRITES_GRIN_L_STOMP
        bit     3,(hl)
        jr      nz,l184e
        
        ; Bit 3 of theganimation timer is 0,
        ; make Donkey Kongfstomp on his right foot 
        ld      de,L_DK_SPRITES_GRIN_R_STOMP
        
        ; Change Donkey Kong's sprites
l184e:  ex      de,hl
        call    L_LOAD_DK_SPRITES
        ld      hl,DK_SPRITE_1_X
        ld      c,68
        rst     $38
        ret     
        
        ; Change Donkey Kong's sprites
l1859:  ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        ld      hl,DK_SPRITE_1_X
        ld      c,68
        rst     $38
        
        ; Set the minor timer to 32
        ld      a,32
        ld      (MINOR_TIMER),a
        
        ; Advance to the next animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret 
;------------------------------------------------------------------------------

            

;------------------------------------------------------------------------------
L_RIVETS_WIN_STAGE_ANIM_2:  
		; Return until the minor timer times out
		rst     $18
		
        ; Change Donkey Kong's sprites
        ld      hl,L_DK_SPRITES_GRIN_UD
        call    L_LOAD_DK_SPRITES
        
        ; Trigger the falling sound
        ld      a,3
        ld      (FALL_SOUND_TRIGGER),a
        
        ; Advance to the next animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret  
;------------------------------------------------------------------------------

           

;------------------------------------------------------------------------------
L_RIVETS_WIN_STAGE_ANIM_3:  
		; Move Donkey Kong down 1 pixel
		ld      hl,DK_SPRITE_1_Y
        ld      c,1
        rst     $38
        
        ; Return if Donkey Kong has not reached the fallen platforms
        ld      a,(DK_SPRITE_5_Y)
        cp      208
        ret     nz
        
        ; Change Donkey Kong's head sprite
        ld      a,$20
        ld      (DK_SPRITE_5_NUM),a
        
        ; Create the stars sprite just below Donkey Kong's head
        ld      hl,DK_STARS_SPRITE_X
        ld      (hl),127					; X coordinate
        inc     l
        ld      (hl),$39					; Sprite numbet
        inc     l
        ld      (hl),$01					; Palette
        inc     l
        ld      (hl),216					; Y coordinate
        
        ; Clear Pauline's platform and redraw it lower down
        ld      hl,TILE_COORD(22,6)
        call    L_CLEAR_AROUND_GAME_OVER
        ld      de,L_RIVETS_DATA_FALL_TOP
        call    L_DISPLAY_STAGE
        
        ; Reposition Pauline
        ld      de,4						; 4 byte sprite struct
        ld      bc,TWO_BYTES(2,40)			; 2 sprites, 40 pixels
        ld      hl,PAULINE_UPPER_SPRITE_Y
        call    L_MOVE_N_SPRITES
        
        ; Set the climbing counter to 256 (0) 
        ; (used in the animation)
        ld      a,0
        ld      (DK_CLIMBING_COUNTER),a
        
        ; Trigger the stomp sound
        ld      a,3
        ld      (STOMP_SOUND_TRIGGER),a
        
        ; Advance to the next animation state
        ld      hl,WIN_ANIMATION_STATE
        inc     (hl)
        ret     
;------------------------------------------------------------------------------

        

;------------------------------------------------------------------------------
L_RIVETS_WIN_STAGE_ANIM_4:  
		; If the climbing counter has reached 0, jump ahead
		ld      hl,DK_CLIMBING_COUNTER
        dec     (hl)
        jp      z,l193d
        
        ; Return if the 3 lowest bits are not 0
        ld      a,(hl)
        and     %00000111
        ret     nz
        
        ; Flip the star sprite horizontally
        ld      hl,DK_STARS_SPRITE_NUM
        ld      a,(hl)
        xor     %10000000
        ld      (hl),a
        
        ; Convert Donkey Kong's head sprite into the number 0 - 2
		ld      hl,DK_SPRITE_5_NUM
        ld      b,(hl)
        res     5,b
        
		; The following function essentially advances a from 0 to 1, 1 to 2, and 2 to 0
		; in an extraordinarily complicated way 
		xor     a							; a = 0
        call    l3009
		
		; Convert a (0-2) to Donkey Kong's stunned head sprite ($20-$22)
        or      %00100000
        ld      (hl),a
		
		; If the animation counter has not reached 224
		; jump ahead to trigger the level end song
        ld      hl,DK_CLIMBING_COUNTER
        ld      a,(hl)
        cp      224
        jp      nz,l1910
		
		; If Mario was on the right side of the screen,
		; then display Mario to Pauline's right
        ld      a,80
        ld      (MARIO_SPRITE_Y),a
        ld      a,0
        ld      (MARIO_SPRITE_NUM),a
        ld      a,159
        ld      (MARIO_SPRITE_X),a
        ld      a,(MARIO_X)
        cp      128
        jp      nc,l190f
		
		; Mario was on the left side of the screen,
		; display Mario to Pauline's left
        ld      a,$80
        ld      (MARIO_SPRITE_NUM),a
        ld      a,$5f
        ld      (MARIO_SPRITE_X),a
		
		; Return if the animation counter has not reached 192
l190f:  ld      a,(hl)
l1910:  cp      192
        ret     nz
		
		; If the current level is odd, trigger the first level end tune
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_LEVEL_END_1
        ld      a,(CP_LEVEL_NUMBER)
        rrca    
        jr      c,l1920
		
		; The current level is even, trigger the second level end tune
        ld      (hl),SONG_TRIGGER_LEVEL_END_2
		
l1920:  inc     hl
        ld      (hl),3
		
		; If Mario was on the Pauline's right, 
		; then display the heart sprite to Pauline's right
        ld      hl,HEART_SPRITE_Y
        ld      (hl),64
        dec     hl
        ld      (hl),9						; Palette
        dec     hl
        ld      (hl),$76					; Sprite number
        dec     hl
        ld      (hl),143					; Y coordinate
        ld      a,(MARIO_X)
        cp      128
        ret     nc

		; Else if Mario was on Pauline's left,
		; then display the heart sprite to Pauline's left
        ld      a,111
        ld      (HEART_SPRITE_X),a
        ret     
		
		; Advance to the start of the next level's stage order list
l193d:  ld      hl,(CP_STAGE_ORDER_POINTER)
        inc     hl
		
		; If the stage order pointer does not need to be wrapped,
		; jump ahead
        ld      a,(hl)
        cp      $7f
        jp      nz,l194b
		
		; Point the stage order pointer to the level 5 stage order
        ld      hl,L_STAGE_ORDER_TABLE_LAST
        ld      a,(hl)
l194b:  ld      (CP_STAGE_ORDER_POINTER),hl

		; Set the current stage to the first stage in the new level
        ld      (CURRENT_STAGE),a
		
		; Advance the level number
        ld      hl,CP_LEVEL_NUMBER
        inc     (hl)
		
		; Display the timer and add the value to the player's score
        ld      de,$0500
        call    L_ADD_EVENT
		
		; Reset the height index
        xor     a							; a = 0
        ld      (CP_HEIGHT_INDEX),a
		
		; Reset the animation state
        ld      (WIN_ANIMATION_STATE),a
		
		; Set the minor timer to 
        ld      hl,MINOR_TIMER
        ld      (hl),224
		
		; Set the game substate to 8
        inc     hl
        ld      (hl),8
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clear the screen (everything) and move on to the next player
L_PREP_FOR_NEXT_PLAYER:  
		call    L_CLEAR_SCREEN_AND_SPRITES
        ld      a,(SECOND_PLAYER)
        add     a,18
        ld      (GAME_SUBSTATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function runs the game, optionally simulating the player's input
L_RUN_GAME_DEMO:  
		call    L_SIMULATE_DEMO_INPUT

L_RUN_GAME:  
		call    L_IMPLEMENT_POINT_AWARD
        call    L_CHECK_FOR_SMASH_ANIM
        call    l1ac3
        call    l1f72
        call    l2c8f
        call    l2c03
        call    L_IMPLEMENT_FIREBALLS
        call    L_IMPLEMENT_SPRINGS
        call    l24ea
        call    L_RANDOMLY_RELEASE_FIREBALL
        call    L_ANIMATE_HAMMER_CYCLE
        call    L_IMPLEMENT_RET_LADDERS
        call    l1a33
        call    l2a85
        call    l1f46
        call    L_IMPLEMENT_ELEVATORS
        call    L_IMPLEMENT_CONVEYERS
        call    L_CHECK_IF_PRIZE_REACHED
        call    L_ANIMATE_DK_AND_PAULINE
        call    L_CHECK_FOR_ENEMY_COLLISION
        call    L_CHECK_FOR_HAMMER_KILL
        call    L_CHECK_FOR_WIN_CONDITIONS
        call    l1a07
        call    l2fcb
        
        ; NOTE: these NOPs can, apparently, be removed without problems
        nop     
        nop     
        nop     
        
        ; Return if Mario is still alive
        ld      a,(MARIO_ALIVE)
        and     a
        ret     nz
		
		; Play the stomping sound
        call    L_SOUNDS_OFF
        ld      hl,STOMP_SOUND_TRIGGER
        ld      (hl),3
		
		; Advance to the next game substate
l19d2:  ld      hl,GAME_SUBSTATE
        inc     (hl)
		
		; Set the minor timer to 64
        dec     hl							; MINOR_TIMER
        ld      (hl),64	
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function checks if Mario is on top of a prize sprite
; If so, it triggers the point award system
L_CHECK_IF_PRIZE_REACHED:  
		; Check each prize sprite to see if Mario has reached it
		ld      a,(MARIO_X)
        ld      b,3							; For b = 3 to 1 (3 prize sprites)

		; If Mario's x coordinate matches this prize sprite's x coordinate
		; jump ahead
        ld      hl,PRIZE_SPRITES
l19e2:  cp      (hl)
        jp      z,l19ed
		
		; Examine the next prize sprite
        inc     l
        inc     l
        inc     l
        inc     l
        djnz    l19e2
		
		; Return if there are no more prize sprites
        ret     

		; Return if Mario's y coordinate does not match the prize sprite's
		; y coordinate
l19ed:  ld      a,(MARIO_Y)
        inc     l
        inc     l
        inc     l							; x coordinate
        cp      (hl)
        ret     nz

		; Return if this prize sprite has already been awarded
		; (The sprite number is one of the point award sprites)
        dec     l
        dec     l							; sprite number
        bit     3,(hl)
        ret     nz
		
		; Record this sprite address as the point award sprite address
        dec     l							; start of the sprite data
        ld      (SMASHED_SPRITE_POINTER),hl
		
        xor     a							; 0
        ld      (POINT_AWARD_TYPE),a
		
        inc     a							; 1
        ld      (POINT_AWARD_STATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l1a07:  
		ld      a,($6386)
        rst     $28							; Jump to local table address
		; Jump table
		.word 	l1a1e	; 0 = 
		.word	l1a15	; 1 = 
		.word	l1a1f	; 2 = 
		.word	l1a2a	; 3 = 
		.word	L_ORG	; 4 = reset game
;------------------------------------------------------------------------------


        
;------------------------------------------------------------------------------
l1a15:	
		xor     a
        ld      ($6387),a
        ld      a,$02
        ld      ($6386),a
l1a1e:  ret     
;------------------------------------------------------------------------------
        


;------------------------------------------------------------------------------
l1a1f:	
		ld      hl,$6387
        dec     (hl)
        ret     nz
        
		ld      a,$03
        ld      ($6386),a
        ret     
;------------------------------------------------------------------------------
        


;------------------------------------------------------------------------------
l1a2a:	
		ld      a,(MARIO_IS_JUMPING)
        and     a
        ret     nz
		
        pop     hl
        jp      l19d2
l1a33:  ld      a,$08
        rst     $30							; Return unless this is the rivets stage
        ld      a,(MARIO_X)
        cp      $4b
        jp      z,l1a4b
        cp      $b3
        jp      z,l1a4b
        ld      a,($6291)
        dec     a
        jp      z,l1a51
        ret     

l1a4b:  ld      a,$01
        ld      ($6291),a
        ret     

l1a51:  ld      ($6291),a
        ld      b,a
        ld      a,(MARIO_Y)
        dec     a
        cp      $d0
        ret     nc
		
        rlca    
        jp      nc,l1a62
        set     2,b
l1a62:  rlca    
        rlca    
        jp      nc,l1a69
        set     1,b
l1a69:  and     $07
        cp      $06
        jp      nz,l1a72
        set     1,b
l1a72:  ld      a,(MARIO_X)
        rlca    
        jp      nc,l1a7b
        set     0,b
l1a7b:  ld      hl,$6292
        ld      a,b
        add     a,l
        ld      l,a
        ld      a,(hl)
        and     a
        ret     z
        ld      (hl),$00
        ld      hl,REMAINING_RIVETS
        dec     (hl)
        ld      a,b
        ld      bc,$0005
        rra     
        jp      c,l1abd
        ld      hl,$02cb
l1a95:  and     a
        jp      z,l1a9e
l1a99:  add     hl,bc
        dec     a
        jp      nz,l1a99
l1a9e:  ld      bc,TILE_COORD(0,0)
        add     hl,bc
        ld      a,$10
        ld      (hl),a
        dec     l
        ld      (hl),a
        inc     l
        inc     l
        ld      (hl),a
        ld      a,1
        ld      (POINT_AWARD_STATE),a
        ld      (POINT_AWARD_TYPE),a
        ld      ($6225),a
        ld      a,(MARIO_IS_JUMPING)
        and     a
        call    z,l1d95
        ret     
		
l1abd:  ld      hl,$012b
        jp      l1a95
;------------------------------------------------------------------------------

		

;------------------------------------------------------------------------------
l1ac3:  
		; If Mario is still in a jump, 
		; jump ahead
		ld      a,(MARIO_IS_JUMPING)
        dec     a
        jp      z,l1bb2
        
        ; If the hammer cycle delay is active, jump ahead to handle it
        ld      a,(MARIO_HAMMER_CYCLE_DELAY)
        and     a
        jp      nz,l1b55
        
        ; If the hammer cycle is active, jump ahead
        ld      a,(HAMMER_CYCLE_ACTIVE)
        dec     a
        jp      z,l1ae6
        
        ; If Mario is climbing, jump ahead
        ld      a,(MARIO_IS_CLIMBING)
        dec     a
        jp      z,l1b38
        
        ; If the jump button is pressed, jump ahead
        ld      a,(PLAYER_INPUT)
        rla     
        jp      c,l1b6e
        
        ; d will be 1 if Mario can't move left
        ; e will be 1 if Mario can't move right
l1ae6:  call    L_IMPLEMENT_BARRIERS
        
        ; If Mario is blocked to the right, 
        ; jump ahead to ignore the joystick right input  
        ld      a,(PLAYER_INPUT)
        dec     e
        jp      z,l1af5
        
        ; If the joystick is pressed to the right, jump ahead to process it
        bit     0,a						; right input
        jp      nz,l1c8f
        
        ; If Mario is blocked to the left, 
        ; jump ahead to ignore the joystick left input  
l1af5:  dec     d
        jp      z,l1afe
        
        ; If the joystick is pressed to the left, jump ahead to process it
        bit     1,a
        jp      nz,l1cab
        
        ; If the hammer cycle is active (can't climb ladders), 
		; then return
l1afe:  ld      a,(HAMMER_CYCLE_ACTIVE)
        dec     a
		ret     z
		
		; Add 8 pixels to Mario's y coordinate to where his feet are
        ld      a,(MARIO_Y)
        add     a,8
        ld      d,a
        
        ; Fudge Mario's x coordinate a bit to make it easier to get 
		; on a ladder
        ld      a,(MARIO_X)
        or      %00000011
        res     2,a
        
        ; Check if Mario is on a ladder
        ; a will be 0 if at the bottom, 1 if at the top
        ; This function will be aborted if no ladder
        ld      bc,21
        call    L_CHECK_IF_ON_LADDER
        
        ; Set Mario's sprite to $06, flipped horizontally 
        ; to match the current sprite number
        push    af
        ld      hl,MARIO_DATA_SPRITE_NUM
        ld      a,(hl)
        and     %10000000
        or      %00000110
        ld      (hl),a
        
        ; If Mario is standing over a normal ladder,
        ; set $621a to 1
        ld      hl,$621a
        ld      a,4
        cp      c
        ld      (hl),1
        jp      nc,l1b2c
        
        ; If Mario is standing over a broken ladder,
        ; set $621a to 0
        dec     (hl)
        
        ; If Mario is at the bottom of a ladder,
        ; jump ahead
l1b2c:  pop     af
        and     a
        jp      z,l1b4e
        
        ; Mario is at the top of a ladder
        ; If this is a normal ladder, return
        ld      a,(hl)
        and     a
        ret     nz
        
        ; Save the coordinate of the top of the ladder
        inc     l						; TOP_OF_CURRENT_LADDER
        ld      (hl),d
        
        ; Save the coordinate of the bottom of the ladder
        inc     l						; BOT_OF_CURRENT_LADDER
        ld      (hl),b
        
        ; If the joystick is being pressed down, jump ahead
l1b38:  ld      a,(PLAYER_INPUT)
        bit     3,a
        jp      nz,l1cf2
        
        ; Return if Mario is not climbing a ladder
        ld      a,(MARIO_IS_CLIMBING)
        and     a
        ret     z
		
		; If the joystick is being pressed up, jump ahead
l1b45:  ld      a,(PLAYER_INPUT)
        bit     2,a
        jp      nz,l1d03
        ret     
		
		; Mario is at the bottom of a ladder
l1b4e:  inc     l							; TOP_OF_CURRENT_LADDER
        ld      (hl),b
        inc     l							; BOT_OF_CURRENT_LADDER
        ld      (hl),d
        jp      l1b45
        
		; Decrement the hammer cycle delay and return if it hasn't
		; reached 0
l1b55:  ld      hl,MARIO_HAMMER_CYCLE_DELAY
        dec     (hl)
        ret     nz
		
		; Activate the hammer cycle
        ld      a,(HAMMER_GRABBED)
        ld      (HAMMER_CYCLE_ACTIVE),a
		
		; Face Mario's sprite in the correct direction
        ld      hl,MARIO_DATA_SPRITE_NUM
        ld      a,(hl)
        and     $80
        ld      (hl),a
        xor     a
        ld      ($6202),a
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
        ; Jump button is pressed
		
		; Flag Mario as jumping
l1b6e:  ld      a,1
        ld      (MARIO_IS_JUMPING),a
		
		; If the joystick is pressed right, 
		; set MARIO_JUMPING_LEFT to $00 
		; and MARIO_JUMPING_RIGHT to $80
        ld      hl,MARIO_JUMPING_LEFT
        ld      a,(PLAYER_INPUT)
        ld      bc,$0080
        rra     
        jp      c,l1b8a
		; If the joystick is pressed left
		; set MARIO_JUMPING_LEFT to $ff 
		; and MARIO_JUMPING_RIGHT to $80
        ld      bc,$ff80
        rra     
        jp      c,l1b8a
		; If the joystick is centered
		; set MARIO_JUMPING_LEFT to $00 
		; and MARIO_JUMPING_RIGHT to $00
        ld      bc,$0000
l1b8a:  xor     a
        ld      (hl),b
        inc     l							; MARIO_JUMPING_RIGHT
        ld      (hl),c
		
        inc     l							; $6212
        ld      (hl),$01
        inc     l							; $6213
        ld      (hl),$48
        inc     l							; $6214
        ld      (hl),a
        ld      ($6204),a
        ld      ($6206),a
        
		; Change Mario's sprite to him jumping, flipped to the correct direction
		ld      a,(MARIO_DATA_SPRITE_NUM)
        and     %10000000
        or      $0e							; Jumping sprite
        ld      (MARIO_DATA_SPRITE_NUM),a
		
		; Save the y coordinate of the start of the jump
        ld      a,(MARIO_Y)
        ld      (MARIO_JUMP_Y_COORD),a
		
		; Trigger the jumping sound
        ld      hl,JUMP_SOUND_TRIGGER
        ld      (hl),3
        ret    
		
		; Mario is jumping
		
l1bb2:  ld      ix,MARIO_DATA_STRUCT
        ld      a,(MARIO_X)
        ld      (ix+11),a
        ld      a,(MARIO_Y)
        ld      (ix+12),a
        
        call    l239c
        
		; Check for barriers
        call    L_IMPLEMENT_BARRIERS
        
        ; If Mario can move left, jump ahead
        dec     d
        jp      nz,l1bf2
        
		; Mario is blocked to the left
		; Force Mario to bounce to the right
        ld      (ix+16),0					; MARIO_JUMPING_LEFT
        ld      (ix+17),$80					; MARIO_JUMPING_RIGHT
        set     7,(ix+7)					; Sprite number
        
l1bd8:  ld      a,($6220)
        dec     a
        jp      z,l1bec
        
        call    l2407
        
        ld      (ix+18),h
        ld      (ix+19),l
        ld      (ix+20),0
        
l1bec:  call    l239c
        jp      l1c05
        
        ; If Mario can move right, jump ahead
l1bf2:  dec     e
        jp      nz,l1c05
        
		; Mario is blocked to the right
		; Force Mario to bounce to the left
        ld      (ix+16),$FF					; MARIO_JUMPING_LEFT
        ld      (ix+17),$80					; MARIO_JUMPING_RIGHT
        res     7,(ix+7)					; Mario's sprite number
        jp      l1bd8
        
        
l1c05:  call    l2b1c
        dec     a
        jp      z,l1c3a
        ld      a,($621f)
        dec     a
        jp      z,l1c76
        ld      a,($6214)
        sub     $14
        jp      nz,l1c33
        ld      a,$01
        ld      ($621f),a
        call    L_CHECK_FOR_ENEMY_JUMP
        and     a
        
        ; If an enemy has not been jumped,
		; jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      z,l1da6
        
		; Initiate a point reward for jumping an enemy
        ld      (POINT_AWARD_TYPE),a
        ld      a,1
        ld      (POINT_AWARD_STATE),a
        ld      ($6225),a
		
		; NOTE: The following nop can be removed
        nop     
		
l1c33:  inc     a
        call    z,L_IMPLEMENT_HAMMER_GRAB
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1c3a:  dec     b
        jp      z,l1c4f
        inc     a
        ld      ($621f),a
        xor     a
        ld      hl,MARIO_JUMPING_LEFT
        ld      b,$05
l1c48:  ld      (hl),a
        inc     l
        djnz    l1c48
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1c4f:  ld      (MARIO_IS_JUMPING),a
        ld      a,($6220)
        xor     1
        ld      (MARIO_ALIVE),a
        ld      hl,MARIO_DATA_SPRITE_NUM
        ld      a,(hl)
        and     $80
        or      $0f
        ld      (hl),a
        ld      a,$04
        ld      (MARIO_HAMMER_CYCLE_DELAY),a
        xor     a
        ld      ($621f),a
        ld      a,($6225)
        dec     a
        call    z,l1d95
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1c76:  ld      a,(MARIO_Y)
        ld      hl,MARIO_JUMP_Y_COORD
        sub     $0f
        cp      (hl)
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      c,l1da6
        
        ld      a,$01
        ld      ($6220),a
        ld      hl,FALL_SOUND_TRIGGER
        ld      (hl),$03
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1c8f:  ld      b,1
        ld      a,($620f)
        and     a
        jp      nz,l1cd2
        ld      a,($6202)
        ld      b,a
        ld      a,5
        call    l3009
        ld      ($6202),a
        and     $03
        or      $80
        jp      l1cc2
l1cab:  ld      b,$ff
        ld      a,($620f)
        and     a
        jp      nz,l1cd2
        ld      a,($6202)
        ld      b,a
        ld      a,1
        call    l3009
        ld      ($6202),a
        and     $03
l1cc2:  ld      hl,MARIO_DATA_SPRITE_NUM
        ld      (hl),a
        rra     
        call    c,l1d8f
        ld      a,$02
        ld      ($620f),a
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1cd2:  ld      hl,MARIO_X
        ld      a,(hl)
        add     a,b
        ld      (hl),a
        ld      a,(CURRENT_STAGE)
        dec     a
        jp      nz,l1ceb
        ld      h,(hl)
        ld      a,(MARIO_Y)
        ld      l,a
        call    L_MOVE_SPRITE_ALONG_PLAT
        ld      a,l
        ld      (MARIO_Y),a
l1ceb:  ld      hl,$620f
        dec     (hl)
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
        ; If $620f is not 0, jump ahead
l1cf2:  ld      a,($620f)
        and     a
        jp      nz,l1d8a
        
        ; Reset $620f to 3
        ld      a,3
        ld      ($620f),a
        
        ; Jump ahead to move Mario Mario down 2 pixels
        ld      a,2
        jp      l1d11
        
l1d03:  ld      a,($620f)
        and     a
        jp      nz,l1d76
        ld      a,$04
        ld      ($620f),a
        ld      a,-2
        
        ; Move Mario up or down the ladder
l1d11:  ld      hl,MARIO_Y
        add     a,(hl)
        ld      (hl),a
        
        ld      b,a
        ld      a,($6222)
        xor     %00000001
        ld      ($6222),a
        
        jp      nz,l1d51
        
        ; If Mario (Mario's y coordinate + 8) has reached the bottom of the ladder,
        ; jump ahead
        ld      a,b
        add     a,8
        ld      hl,BOT_OF_CURRENT_LADDER
        cp      (hl)
        jp      z,l1d67
        
        ; If Mario (Mario's y coordinate + 8) has reached the top of the ladder,
        ; jump ahead
        dec     l						; TOP_OF_CURRENT_LADDER
        sub     (hl)
        jp      z,l1d67
        
        ; Determine what Mario sprite to use
        ; If Mario is still near the top of the ladder, 
        ; one of the "just starting to climb down the ladder"
        ; sprites is used; otherwise the "climbing the ladder"
        ; sprite is used
        ld      b,$05
        sub     8
        jp      z,l1d3f
        dec     b	; $04
        sub     4
        jp      z,l1d3f
        dec     b	; $03
        
        ; Set Mario's sprite number flipped horizontally to match the 
        ; current sprite's orientation
l1d3f:  ld      a,%10000000
        ld      hl,MARIO_DATA_SPRITE_NUM
        and     (hl)
        xor     $80
        or      b
        ld      (hl),a
        
        ; Flag Mario as climbing a ladder
l1d49:  ld      a,1
        ld      (MARIO_IS_CLIMBING),a
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1d51:  dec     l
        dec     l
        ld      a,(hl)
        or      $03
        res     2,a
        ld      (hl),a
        ld      a,($6224)
        xor     $01
        ld      ($6224),a
        call    z,l1d8f
        jp      l1d49
l1d67:  ld      a,$06
        ld      (MARIO_DATA_SPRITE_NUM),a
        xor     a
        ld      ($6219),a
        ld      (MARIO_IS_CLIMBING),a
        
        ; Jump ahead to update Mario's coordinate and sprite data
        ; and return
        jp      l1da6
        
l1d76:  ld      a,($621a)
        and     a
        jp      z,l1d8a
        ld      ($6219),a
        ld      a,(BOT_OF_CURRENT_LADDER)
        sub     $13
        ld      hl,MARIO_Y
        cp      (hl)
        ret     nc
		
l1d8a:  ld      hl,$620f
        dec     (hl)
        ret     
		
l1d8f:  ld      a,$03
        ld      (WALK_SOUND_TRIGGER),a
        ret     

l1d95:  ld      ($6225),a
        ld      a,(CURRENT_STAGE)
        dec     a
        ret     z
		
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_RIVET_REMOVED
        inc     l
        ld      (hl),3
        ret     
		
		; Update Mario's x coordinate
l1da6:  ld      hl,MARIO_SPRITE_X
        ld      a,(MARIO_X)
        ld      (hl),a
        
        ; Update Mario's sprite number
        ld      a,(MARIO_DATA_SPRITE_NUM)
        inc     l						; MARIO_SPRITE_NUM
        ld      (hl),a
        
        ; Update Mario's palette
        ld      a,(MARIO_DATA_PALETTE)
        inc     l						; MARIO_SPRITE_PAL
        ld      (hl),a
        
        ; Update Mario's y coordinate
        ld      a,(MARIO_Y)
        inc     l						; MARIO_SPRITE_Y
        ld      (hl),a
        ret   
;------------------------------------------------------------------------------


	
;------------------------------------------------------------------------------
; Implement the awarding of points to the player.
L_IMPLEMENT_POINT_AWARD:  
		ld      a,(POINT_AWARD_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_NO_POINTS_TO_DISPLAY	; 0 = no points to award
		.word	L_GIVE_POINT_AWARD	; 1 = award points
		.word	L_DISPLAY_POINT_AWARD_SPRITE	; 2 = display points until timeout
		.word	L_ORG	; 3 = reset game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Determine how many points should be awarded to the player and
; award them and display the award sprite
L_GIVE_POINT_AWARD:  
		; Initialize the point award display timer
		ld      a,64
        ld      (POINT_AWARD_DISPLAY_TIMER),a
		
		; Advance the point award state (display points)
        ld      a,2
        ld      (POINT_AWARD_STATE),a
		
		; If the point award type is 1, 
		; jump ahead
        ld      a,(POINT_AWARD_TYPE)
        rra    
        jp      c,DETERMINE_POINT_AWARD_AMT
		
		; If the point award type is 2, 
		; jump ahead to award 300 points
        rra     
        jp      c,l1e00
		
		; If the point award type is 4, 
		; jump ahead to award random points
        rra     
        jp      c,l1df5
		
		
		; The point award type is 0
		
		; Trigger the award sound
        ld      hl,AWARD_SOUND_TRIGGER
        ld      (hl),3
		
		; If the level number is 1, 
		; award 300 points
        ld      a,(CP_LEVEL_NUMBER)
        dec     a
        jp      z,l1e00
		
		; If the level number is 2,
		; Award 500 points
        dec     a
        jp      z,l1e08
		
		; Jump ahead to award 800 points
        jp      l1e10
		
		
		
		; Randomly award 300, 500, or 800 points
l1df5:  ld      a,(RANDOM_NUMBER)
        rra     
        jp      c,l1e08						; Award 500 points
        rra     
        jp      c,l1e10						; Award 800 points
		
		
		
		; Award 300 points
l1e00:  ld      b,$7d
        ld      de,$0003					; Award 300 points
        jp      l1e15
		
		
		
		; Award 500 points
l1e08:  ld      b,$7e
        ld      de,$0005					; Award 500 points
        jp      l1e15
		
		
		
		; Award 800 points
l1e10:  ld      b,$7f
        ld      de,$0008					; Award 800 points
		
		
		
		; Award the points
l1e15:  call    L_ADD_EVENT

		; Get the x and y coordinate of the smashed sprite
        ld      hl,(SMASHED_SPRITE_POINTER)
        ld      a,(hl)						; X coordinate
        ld      (hl),0						; Hide the sprite
        inc     l
        inc     l
        inc     l
        ld      c,(hl)						; Y coordinate
		
        jp      l1e36
        
		; NOTE: I don't see how execution can reach the following line
		; 		It can probably be removed
		ld      de,$0001
		
		; Award the points
l1e28:  call    L_ADD_EVENT

		; Get Mario's x and y coordinates (+20 pixels down)
        ld      a,(MARIO_Y)
        add     a,20
        ld      c,a
        ld      a,(MARIO_X)
		
		; NOTE: The following two nops can probably be removed
        nop     
        nop     
		
		; At this point:
		; 	a = x coordinate of award sprite
		;	b = award sprite image
		;	c = y coordinate of award sprite
		
		; Initialize the award sprite
l1e36:  ld      hl,AWARD_SPRITE
        ld      (hl),a						; X coordinate
        inc     l
        ld      (hl),b						; Sprite image
        inc     l
        ld      (hl),7						; Sprite palette
        inc     l
        ld      (hl),c						; Y coordinate
		
        ; Return unless this is the barrels stage or elevator stage
		ld      a,%00000101
        rst     $30							
		
		; Trigger the award sound
        ld      hl,AWARD_SOUND_TRIGGER
        ld      (hl),3
		
		; Return
L_NO_POINTS_TO_DISPLAY:  
		ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; This function continues to display the point award sprite until
; the display timer runs down
L_DISPLAY_POINT_AWARD_SPRITE:  
		; If the point display timer has not reached 0,
		; return
		ld      hl,POINT_AWARD_DISPLAY_TIMER
        dec     (hl)
        ret     nz
		
		; Remove the sprite
        xor     a
        ld      (AWARD_SPRITE_X),a
		
		; Reset the point award state
        ld      (POINT_AWARD_STATE),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check if the current stage win conditions have been met
L_CHECK_FOR_WIN_CONDITIONS:
		ld      a,(CURRENT_STAGE)
        bit     2,a
        jp      nz,l1e80					; Jump ahead if this is the rivets stage
        rra     
        ld      a,(MARIO_Y)
        jp      c,l1e7a						; Jump ahead if this is the barrels stage or elevators stage
		
		; Processing for mixer stage
		; Check if Mario has reached the top conveyer
        cp      81
        ret     nc							; Return if Mario y coordinate is below the top platform
		
		; Face Mario left if he is on the right side of the screen
        ld      a,(MARIO_X)
        rla     
l1e6d:  ld      a,0	
        jp      c,l1e74						
		
		; Face Mario right if he is on the left side of the screen
        ld      a,$80
		
l1e74:  ld      (MARIO_SPRITE_NUM),a
        jp      l1e85
		
		; Processing for barrels stage and elevators stage
		; Check if Mario has reached Pauline's platform
l1e7a:  cp      49
        ret     nc
        jp      l1e6d						; Face Mario right (towards Pauline)
		
		; Processing for rivets stage
		; Check if all rivets have been removed
l1e80:  ld      a,(REMAINING_RIVETS)
        and     a
        ret     nz							; Return if there are still rivets to be removed
		
l1e85:  ld      a,22
        ld      (GAME_SUBSTATE),a
        pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check if the smash animation is running.  If it is, implement it and abort
; any other game processing.
L_CHECK_FOR_SMASH_ANIM:  
		; Return if a smash animation is not active
		ld      a,(SMASH_ANIMATION_ACTIVE)
        and     a
        ret     z
        
        ; Return 
        call    L_IMPLEMENT_SMASH_ANIM
        
        ; Return from the calling function
        pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Implement the smash animation
L_IMPLEMENT_SMASH_ANIM:  
		ld      a,(SMASH_ANIMATION_STATE)
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_INIT_SMASH_ANIM	; 0 = smash animation 0
		.word	L_SMASH_ANIM_PHASE_1	; 1 = smash animation 1
		.word	L_COMPLETE_SMASH_ANIM	; 2 = smash animation 2
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function initializes the smash animation
L_INIT_SMASH_ANIM:  
		; If the lower byte of the smash enemy class pointer
		; == $65, set hl to point to the pie sprites
		ld      a,(SMASH_ENEMY_CLASS_POINTER+1)
        cp      $65
        ld      hl,PIE_SPRITES
        jp      z,l1eb4
        
        ; If the lower byte of the smash enemy class pointer
		; == $65, set hl to point to the fireball sprites 
        ld      hl,FIREBALL_SPRITES
        jp      c,l1eb4
        
        ; If the lower byte of the smash enemy class pointer
		; == $65, set hl to point to the spring sprites
        ld      hl,SPRING_SPRITES
        
        ; Prepare to locate the smashed sprite
l1eb4:  ld      ix,(SMASH_ENEMY_CLASS_POINTER)
        ld      d,0
        ld      a,(SMASH_ENEMY_DATA_SIZE)
        ld      e,a							; de = size of the enemy data structure
        ld      bc,4						; bc = size of sprite data

		; If the enemy index is 0, nothing more needs to be done so
		; jump ahead
        ld      a,(SMASH_ANIMATION_ENEMY_INDEX)
        and     a
        jp      z,l1ecf
        
		; Advance to the sprite and data structure of the enemy
		; that was smashed
l1ec8:  add     hl,bc
        add     ix,de
        dec     a
        jp      nz,l1ec8

		; Mark the enemy data structure as inactive
l1ecf:  ld      (ix+0),0					; Inactive

		; If this is not a special sprite, 
		; award 300 points
        ld      a,(ix+21)
        and     a
        ld      a,2
        jp      z,l1ede
		
		; If this is a special sprite,
		; randomly award 300, 500, or 800 points
        ld      a,4
		
		; Record the type of award
l1ede:  ld      (POINT_AWARD_TYPE),a

		; Set the smash sprite's x coordinate to that of the
		; smashed enemy
        ld      bc,SMASH_SPRITE
        ld      a,(hl)
        ld      (hl),0						; Hide the enemy sprite
        ld      (bc),a
		
		; Set the smash sprite's image to the first image in the
		; smash sprite animation
        inc     c
        inc     l
        ld      a,$60
        ld      (bc),a
		
		; Set the smash sprite's palette to 12
        inc     c
        inc     l
        ld      a,12
        ld      (bc),a
		
		; Set the smash sprite's y coordinate to that of the
		; smashed enemy
        inc     c
        inc     l
        ld      a,(hl)
        ld      (bc),a

		; Advance the smash animation state
        ld      hl,SMASH_ANIMATION_STATE
        inc     (hl)
		
		; Set the smash animation frame delay to 6
        inc     l							; SMASH_ANIMATION_FRAME_DELAY
        ld      (hl),6

		; Set the smash animation cycle counter to 5
        inc     l							; SMASH_ANIMATION_CYCLE_COUNTER
        ld      (hl),5	
		
		; Trigger the hammet hit song
        ld      hl,PENDING_SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_HAMMER_HIT
        inc     l
        ld      (hl),3
		
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function displays the first phase of the smash animation by cycling 
; between the first two images in the animation until the cycle counter
; reaches 0
L_SMASH_ANIM_PHASE_1:  
		; If the smash animation frame delay has not reached 0, 
		; return
		ld      hl,SMASH_ANIMATION_FRAME_DELAY
        dec     (hl)
        ret     nz
		
		; Reset the smash animation frame delay to 6
        ld      (hl),6
		
		; If the smash animation cycle counter has reached 0,
		; jump ahead
        inc     l
        dec     (hl)
        jp      z,l1f1d
		
		; Cycle between the first two sprite images in the smash
		; animation
        ld      hl,SMASH_SPRITE_NUM
        ld      a,(hl)
        xor     1
        ld      (hl),a
        ret     
		
		; Reset the smash animation cycle counter
l1f1d:  ld      (hl),4

		; Advance the smash animation state
        dec     l
        dec     l
        inc     (hl)
		
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; This function completes the smash animation by advancing through the rest of 
; the images in the animation
L_COMPLETE_SMASH_ANIM:  
		; If the smah animation frame delay has not reached 0,
		; return
		ld      hl,SMASH_ANIMATION_FRAME_DELAY
        dec     (hl)
        ret     nz
		
		; Reset the frame delay to 12
        ld      (hl),12
		
		; If the smash animation cycle counter has reached 0,
		; jump ahead
        inc     l							; SMASH_ANIMATION_CYCLE_COUNTER
        dec     (hl)
        jp      z,l1f34
		
		; Advance to the next sprite in the animation 
        ld      hl,SMASH_SPRITE_NUM
        inc     (hl)
        ret     
		
		; Reset the smash animation
l1f34:  dec     l
        dec     l							; SMASH_ANIMATION_STATE
        xor     a
        ld      (hl),a
        ld      (SMASH_ANIMATION_ACTIVE),a
        inc     a
        ld      (POINT_AWARD_STATE),a
        ld      hl,SMASH_SPRITE
        ld      (SMASHED_SPRITE_POINTER),hl
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
l1f46:  
		; If Mario is not falling,
		; return
		ld      a,(MARIO_IS_FALLING)
        and     a
        ret     z
		
		; 
        xor     a
        ld      ($6204),a
        ld      ($6206),a
        ld      (MARIO_IS_FALLING),a
        ld      (MARIO_JUMPING_LEFT),a
        ld      (MARIO_JUMPING_RIGHT),a
        ld      ($6212),a
        ld      ($6213),a
        ld      ($6214),a
		
        inc     a
        ld      (MARIO_IS_JUMPING),a
        ld      ($621f),a
        ld      a,(MARIO_Y)
        ld      (MARIO_JUMP_Y_COORD),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l1f72:  
		; Return unless this is the barrels stage
		; Note: I can save 2 bytes by using rst $30
		ld      a,(CURRENT_STAGE)
        dec     a
        ret     nz
		
        ld      ix,BARREL_STRUCTS
        ld      hl,SPRING_SPRITES
        ld      de,32					; 32 byte data structure
        ld      b,10					; For b = 10 to 1 (10 barrels)

		; If the barrel is active, jump ahead
l1f83:  ld      a,(ix+0)
        dec     a
        jp      z,l1f93
        
        ; Advance to the next barrel
        ; Note: change this to add a,3
        inc     l
        inc     l
        inc     l

		; Process the next barrel
l1f8d:  inc     l
        add     ix,de
        djnz    l1f83					; Next b
        ret     

		; If ??? has reached 0, jump ahead
l1f93:  ld      a,(ix+1)
        dec     a
        jp      z,l20ec
        
        ; If bit 0 of ??? is 1, jump ahead
        ld      a,(ix+2)
        rra     
        jp      c,l1fac
        
        ; If bit 1 of ??? is 1, jump ahead
        rra     
        jp      c,l1fe5
        
        ; If bit 2 of ??? is 1, jump ahead
        rra     
        jp      c,l1fef
        
        ; Jump ahead
        jp      l2053
        
        ; Move the barrel down 1 pixel
l1fac:  exx     
        inc     (ix+5)						; Y coordinate entry
        
        ; If the barrel y coordinate has not reached ???, jump ahead
        ld      a,(ix+23)
        cp      (ix+5)						; Y coordinate
        jp      nz,l1fce
        
        ; Advance the barrel rolling animation
        ; Select either the normal barrel graphics (barrel type == 0)
		; or the oil barrel graphics (barrel type == 1)
		ld      a,(ix+21)					; Barrel type
        rlca    							
        rlca    
        add     a,$15						; The first normal barrel sprite image
        ld      (ix+7),a					; Sprite number entry
        
        ld      a,(ix+2)
        xor     %00000111
        ld      (ix+2),a
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
        
        
        ; If ??? has not reached 0, jump ahead
l1fce:  ld      a,(ix+15)
        dec     a
        jp      nz,l1fdf
        
        ; Toggle the barrel falling sprite
        ; (Between $16 and $17 or $1a and $1b)
        ld      a,(ix+7)					; Sprite number
        xor     %00000001
        ld      (ix+7),a
        
        ; Reset the ??? counter to 4
        ld      a,4
        
        ; Update the ??? counter
l1fdf:  ld      (ix+15),a
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
        
        
        
l1fe5:  exx     
        ld      bc,$0100
        
        ; Move the barrel right 1 pixel
        inc     (ix+3)						; X coordinate entry
        jp      l1ff6
        
        
l1fef:  exx     
        ld      bc,$ff04
        
        ; Move the barrel left 1 pixel
        dec     (ix+3)						; X coordinate entry
        
l1ff6:  ld      h,(ix+3)					; X coordinate entry
        ld      l,(ix+5)					; Y coordinate entry
        ld      a,h
        and     %00000111
        cp      3
        jp      z,l215f
        
        ; Make the barrel follow the countours of the platforms
        dec     l
        dec     l
        dec     l
        call    L_MOVE_SPRITE_ALONG_PLAT
        inc     l
        inc     l
        inc     l
        
        ld      a,l
        ld      (ix+5),a
        
        call    l23de
        
        call    l24b4
        
        ld      a,(ix+3)
        cp      %00011100
        jp      c,l202f
        cp      $e4
        jp      c,L_LD_SPRITE_DATA_TO_STRUCT_2
        xor     a
        ld      (ix+16),a
        ld      (ix+17),$60
        jp      l2038
        
l202f:  xor     a
        ld      (ix+16),$ff
        ld      (ix+17),$a0
l2038:  ld      (ix+18),$ff
        ld      (ix+19),$f0
        ld      (ix+20),a
        ld      (ix+14),a
        ld      (ix+4),a
        ld      (ix+6),a
        ld      (ix+2),8
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
        
l2053:  exx     
        call    l239c
        call    l2a2f
        and     a
        jp      nz,l2083
        ld      a,(ix+3)
        add     a,8
        cp      $10
        jp      c,l2079
        call    l24b4
        ld      a,(ix+16)
        and     1
        rlca    
        rlca    
        ld      c,a
        call    l23de
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l2079:  xor     a
        ld      (ix+0),a
        ld      (ix+3),a
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l2083:  inc     (ix+14)
        ld      a,(ix+14)
        dec     a
        jp      z,l20a2
        dec     a
        jp      z,l20c3
        ld      a,(ix+16)
        dec     a
        ld      a,4
        jp      nz,l209c
        ld      a,2
l209c:  ld      (ix+2),a
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l20a2:  ld      a,(ix+21)
        and     a
        jp      nz,l20b5
        ld      hl,MARIO_Y
        ld      a,(ix+5)
        sub     $16
        cp      (hl)
        jp      nc,l20c3
l20b5:  ld      a,(ix+16)
        and     a
        jp      nz,l20e1
        ld      (ix+17),a
        ld      (ix+16),$ff
l20c3:  call    l2407
        srl     h
        rr      l
        srl     h
        rr      l
        ld      (ix+18),h
        ld      (ix+19),l
        xor     a
        ld      (ix+20),a
        ld      (ix+4),a
        ld      (ix+6),a
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l20e1:  ld      (ix+16),1
        ld      (ix+17),0
        jp      l20c3
        
l20ec:  exx     
        call    l239c
        ld      a,h
        sub     $1a
        ld      b,(ix+25)
        cp      b
        jp      c,l2104
        call    l2a2f
        and     a
        jp      nz,l2118
        call    l24b4
        
        ; If the x coordinate (+8) is > 16
        ; jump back to animate the sprite
l2104:  ld      a,(ix+3)
        add     a,8
        cp      16
        jp      nc,l1fce
        
        ; The x coordinate is <= 16
        ; Deactivate the sprite
        xor     a
        ld      (ix+0),a
        ld      (ix+3),a
        
        ; Update the sprite and process the next object
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
        
l2118:  ld      a,(ix+5)
        cp      $e0
        jp      c,l2146
        ld      a,(ix+7)
        and     $fc
        or      1
        ld      (ix+7),a
        xor     a
        ld      (ix+1),a
        ld      (ix+2),a
        ld      (ix+16),$ff
        ld      (ix+17),a
        ld      (ix+18),a
        ld      (ix+19),$b0
        ld      (ix+14),1
        jp      l2153
l2146:  call    l2407
        call    l22cb
        ld      a,(ix+5)
        ld      (ix+25),a
        xor     a
l2153:  ld      (ix+20),a
        ld      (ix+4),a
        ld      (ix+6),a
l215c:  jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l215f:  ld      a,l
l2160:  add     a,5
        ld      d,a
        ld      a,h
        ld      bc,$0015
        call    l216d
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2
l216d:  call    L_CHECK_IF_ON_LADDER
        dec     a
        ret     nz
        ld      a,b
        sub     5
        ld      (ix+23),a
		
		; If the barrel fire is not lit, then jump ahead
		; (barrel will always take ladders before the barrel is lit)
        ld      a,(BARREL_FIRE_STATUS)
        and     a
        jp      z,l21b2
		
		; Return if the barrel is below or on the same level as Mario
		; (barrel will never take the ladder)
        ld      a,(MARIO_Y)
        sub     4
        cp      d
        ret     c
		
		; Convert the difficulty (1 to 5) to a modified difficulty number between 1 and 3
        ld      a,(CP_DIFFICULTY)
        rra     
        inc     a
        ld      b,a
		
		; Get a random number between 0 and 3
        ld      a,(RANDOM_NUMBER)
        ld      c,a
        and     %00000011
		
		; If random number is greater than the modified difficulty number, then return
		; (barrel will not take the ladder)
        cp      b
        ret     nc
		
		; If Mario is directly below the barrel, then go down the ladder
        ld      hl,PLAYER_INPUT
        ld      a,(MARIO_X)
        cp      e
        jp      z,l21b2
	
		; If the barrel is to the right of Mario, check if Mario is moving left
        jp      nc,l21a9
		
		; If Mario is not moving right, then skip ahead
        bit     0,(hl)
        jp      z,l21ae
		
		; If the barrel is to the left of Mario and Mario is moving right, 
		; then the barrel will go down the ladder
        jp      l21b2
		
		; If the barrel is to the right of Mario and Mario is moving left, 
		; then the barrel will go down the ladder
l21a9:  bit     1,(hl)
        jp      nz,l21b2
		
		; 25% chance of the barrel going down the ladder on its own
l21ae:  ld      a,c
        and     $18
        ret     nz
		
		; Advance the barrel animation
l21b2:  inc     (ix+7)

		; Set the barrel to take the ladder
        set     0,(ix+2)
        ret     
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Copy data from an object data structure to a sprite structure
L_LD_SPRITE_DATA_TO_STRUCT_2:  
		exx     
        ld      a,(ix+3)					; X coordinate
        ld      (hl),a
        inc     l
        ld      a,(ix+7)					; Sprite number
        ld      (hl),a
        inc     l
        ld      a,(ix+8)					; Palette
        ld      (hl),a
        inc     l
        ld      a,(ix+5)					; Y coordinate
        ld      (hl),a

        ; Jump back to process the next object
        jp      l1f8d
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Input data for the attract mode game play demonstration
;
; The first byte of data is the first demo input value, which is repeated ???
; times.
;
; The two byte pairs that follow are:
;	byte 0 = the input data
;	byte 1 = repeat count for the following input
;		bit 0 = right
;		bit 1 = left
;		bit 2 = up
;		bit 3 = down
;		bit 7 = jump
;
; The expectation seems to be that Mario will be dead before the input runs out.
; Interesting things heppen, however, if he doesn't and the rest of the code that
; follows is treated as input data...
L_DEMO_INPUT_DATA:	
		.byte	$80	         	; jump
		.word	TWO_BYTES($01, 254) ; right
		.word	TWO_BYTES($04, 192) ; up
		.word	TWO_BYTES($02, 80)  ; left
		.word	TWO_BYTES($82, 16)  ; jump left 
		.word	TWO_BYTES($02, 96)  ; left
		.word	TWO_BYTES($82, 16)  ; jump left
		.word	TWO_BYTES($01, 202) ; right
		.word	TWO_BYTES($81, 16)  ; jump right
		.word	TWO_BYTES($02, 255) ; left
		.word	TWO_BYTES($01, 56)  ; right 
		.word	TWO_BYTES($02, 128) ; left
		.word	TWO_BYTES($04, 255) ; up
		.word	TWO_BYTES($04, 128) ; up
		.word	TWO_BYTES($80, 96)  ; jump
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Simulate player input for the demo mode
L_SIMULATE_DEMO_INPUT:  
		; Convert the input index number to a memory offset in de
		ld      de,L_DEMO_INPUT_DATA
        ld      hl,DEMO_INPUT_INDEX
        ld      a,(hl)
        rlca    
        add     a,e
        ld      e,a
        
        ; Get the byte of simulated input
        ld      a,(de)
        ld      (PLAYER_INPUT),a
        
        ; Decrement the input repeat, and return if it has not reached zero
        inc     l
        ld      a,(hl)
        dec     (hl)
        and     a
        ret     nz
		
		; Read the next input repeat
        inc     e
        ld      a,(de)
        ld      (hl),a
        
        ; Increment the input index
        dec     l
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Implement the logic for the retractin ladders on the mixer stage
L_IMPLEMENT_RET_LADDERS:  ld      a,2
        rst     $30							; Return unless this is the mixer stage
        
        ; If counter 2 is odd, process the left ladder
        ld      a,(COUNTER_2)
        rra
        ld      hl,L_RETRACT_LADDER_DATA
        ld      a,(hl)
        jp      c,l2219
        
        ; Counter 2 is even; process the right ladder
        ld      hl,R_RETRACT_LADDER_STATE
        ld      a,(hl)
        
l2219:  push    hl
        rst     $28							; Jump to local table address
		; Jump table
		.word	L_LADDER_STATE_0	; 0 = ladder in up position
		.word	L_LADDER_STATE_1	; 1 = ladder moving down
		.word	L_LADDER_STATE_2	; 2 = ladder in down position
		.word	L_LADDER_STATE_3	; 3 = ladder moving up
		.word	L_ORG	; 4 = reset game
		.word	L_ORG	; 5 = reset game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function controls the retractable ladders on the mixer level
; when they are in the up position, waiting to descend
;
; passed:	hl (on the stack) - the address of the ladder data
L_LADDER_STATE_0:  
		; Decrement the ladder delay and jump ahead if it has reached
		; 0, to skip moving on to the next ladder state
		pop     hl
        inc     l							; RETRACT_LADDER_DELAY	
        dec     (hl)
        jp      nz,l223a

		; Advance to the next ladder state
        dec     l							; RETRACT_LADDER_STATE
        inc     (hl)				
		
		; If Mario is on this ladder, set $621a to 1 and return
        inc     l
        inc     l							; RETRACT_LADDER_X
        call    L_CHECK_IF_MARIO_ON_LADDER
        ld      a,1
        ld      ($621a),a
        ret   
		
		; The ladder is still waiting to descend
		; If Mario is on the ladder, set $621a to 0 and return
l223a:  inc     l
        call    L_CHECK_IF_MARIO_ON_LADDER
        xor     a
        ld      ($621a),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function checks if Mario is on the current retractable 
; ladder.
; Abort the calling function if:
; 	Mario's y coordinate is > 122 or
;	MARIO_IS_JUMPING is not 0 or
;	Mario's x coordinate does not match the ladder's x coordinate
;
; passed:	hl - the address of the current retractable ladder's
;				x coordinate
L_CHECK_IF_MARIO_ON_LADDER:  
		; If Mario's y coordinate is 122 or more,
		; jump ahead to abort the calling function
		ld      a,(MARIO_Y)
        cp      122
        jp      nc,l2257
        
        ; If Mario is jumping, 
        ; jump ahead to abort the calling function
		ld      a,(MARIO_IS_JUMPING)
        and     a
        jp      nz,l2257
        
        ; If Mari 's x coordinate is equal to (hl),
        ; return
        ld      a,(MARIO_X)
        cp      (hl)
        ret     z
        
        ; Return from the calling function
l2257:  pop     hl
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; This function moves the ladder down one pixel every 4th call.
; It also forces Mario down with it, if Mario is on the ladder
;
; If Mario is above the stationary part of the ladder, he is moved
; down at the same speed as the retractable ladder; otherwise, he
; is moved down at half speed.
;
; passed:	hl (on the stack) - the address of the ladder's state
L_LADDER_STATE_1:  
		; Decrement the ladder movement delay
		; Return if it has not reached 0
		pop     hl
        inc     l
        inc     l
        inc     l
        inc     l							; RETRACT_LADDER_MOVE_DELAY
        dec     (hl)
        ret     nz
		
		; Reset the movement delay to 4
        ld      a,4
        ld      (hl),a
		
		; Lower the ladder 1 pixel
        dec     l							; RETRACT_LADDER_Y
        inc     (hl)
		
		; Update the y coordinate of the sprite for the current ladder
        call    L_UPDATE_LADDER_SPRITE_COORD
		
		; If the ladder has not reached its lowest point, jump ahead
        ld      a,120
        cp      (hl)
        jp      nz,l2275
		
		; Advance to the next ladder state
        dec     l
        dec     l
        dec     l
        inc     (hl)
		
        inc     l
        inc     l
        inc     l

		; Return if Mario is not on this ladder
l2275:  dec     l							; RETRACT_LADDER_X
l2276:  call    L_CHECK_IF_MARIO_ON_LADDER

		; If Mario is above the stationary part of the ladder, jump ahead
        ld      a,(MARIO_Y)
        cp      104
        jp      nc,l228a
		
		; Mario is below the stationary part of the ladder;
		; Move Mario down 1 pixel
l2281:  ld      hl,MARIO_Y
        inc     (hl)
		
		; Display Mario's sprite as climbing
        call    L_SET_MARIO_SPRITE_TO_CLIMBING
		
		; Move Mario down 1 pixel
        inc     (hl)						; MARIO_SPRITE_Y
        ret     

		; If bit 0 Mario's y coordinate is a 1, jump back up to move him
		; down 1 pizel
l228a:  rra     
        jp      c,l2281
		
		; If bit 1 of Mario's y coordinate is a 1, set $6222 to 1
        rra     
        ld      a,1
        jp      c,l2295
		
		; Bit 1 of Mario's y coordinate is a 0, set $6222 to 0
        xor     a
l2295:  ld      ($6222),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function leaves the ladder in the down position for a random time
; before advancing to the next state
L_LADDER_STATE_2:  
		pop     hl
        ld      a,(RANDOM_NUMBER)
        and     %00111100
        ret     nz
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function moves the ladder back into the up position 1 pixel at a time
L_LADDER_STATE_3:  
		; Decrement the movement delay
		; Return if it has not reached 0
		pop     hl
        inc     l
        inc     l
        inc     l
        inc     l						; RETRACT_LADDER_MOVE_DELAY
        dec     (hl)
        ret     nz
		
		; Reset the movement delay to 2
        ld      (hl),2
        
        ; Move the ladder up 1 pixel
        dec     l						; RETRACT_LADDER_Y
        dec     (hl)
        
        ; Update the sprite
        call    L_UPDATE_LADDER_SPRITE_COORD
        
        ; Return if the ladder is not completely up
        ld      a,104
        cp      (hl)
        ret     nz
		
		; Reset the ladder delay (time before retracting again)
        xor     a
        ld      b,128
        dec     l
        dec     l						; RETRACT_LADDER_DELAY
        ld      (hl),b
        
        ; Reset the ladder state to 0
        dec     l						; RETRACT_LADDER_STATE
        ld      (hl),a
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Update the address of the y coordinate of the ladder sprite corresponding to 
; the currently processed ladder
;
; passed:	hl - address of the retractable ladder's y coordinate
L_UPDATE_LADDER_SPRITE_COORD:  
		; If this is the right ladder, set the y coordinate of the right ladder
		; sprite
		ld      a,(hl)
        bit     3,l
        ld      de,R_RETRACT_LADDER_SPRITE_Y
        jp      nz,l22c9
		
		; Update the coordinate of the left ladder sprite
        ld      de,L_RETRACT_LADDER_SPRITE_Y
		
l22c9:  ld      (de),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l22cb:  ld      a,(BARREL_FIRE_STATUS)
        and     a
        jp      z,l22e1
        ld      a,(CP_DIFFICULTY)
        dec     a
        rst     $28							; Jump to local table address
		; Jump table
		.word	l22f6	; 0 = 
		.word	l22f6	; 1 = 
		.word	l2303	; 2 = 
		.word	l2303	; 3 = 
		.word	l231a	; 4 = 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l22e1:  ld      a,(CP_LEVEL_NUMBER)
        ld      b,a
        dec     b
        ld      a,1
        jp      z,l22f9
        dec     b
        ld      a,$b1
        jp      z,l22f9
		
        ld      a,$e9
        jp      l22f9
l22f6:  ld      a,(RANDOM_NUMBER)
l22f9:  ld      (ix+17),a
        and     1
        dec     a
        ld      (ix+16),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2303:  ld      a,(RANDOM_NUMBER)
        ld      (ix+17),a
        ld      a,(MARIO_X)
        cp      (ix+3)
        ld      a,1
        jp      nc,l2316
        dec     a
        dec     a
l2316:  ld      (ix+16),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l231a:  ld      a,(MARIO_X)
        sub     (ix+3)
        ld      c,$ff
        jp      c,l2326
        inc     c
l2326:  rlca    
        rl      c
        rlca    
        rl      c
        ld      (ix+16),c
        ld      (ix+17),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function contains the logic the rolls the barrels along the girder
; platforms and makes the barrels follow the slope of the platforms.
; passed:	h - sprite x coordinate
;			l - sprite y coordinate
;			b - 1 if the barrel is rolling right,
;			  - -1 if the barrel is rolling left
; return:	l - the sprite's new y coordinate
L_MOVE_SPRITE_ALONG_PLAT:  
		ld      a,%00001111
        and     h
        
        ; If the barrel is rolling right, jump ahead
        dec     b
        jp      z,l2342

		; If the barrel is rolling left
		; and is not at the edge of a tile grid space, return
        cp      %00001111
        ret     c
        
        ; Mark the barrel as rolling left, and jump ahead
        ld      b,-1
        jp      l2347

        ; Return unless the barrel is at the edge of a tile grid space    
l2342:  cp      1
        ret     nc
		
		; Mark the barrel as rolling right
        ld      b,1
        
        ; Jump ahead if the barrel has reached the straight part of the bottom platform
l2347:  ld      a,240
        cp      l
        jp      z,l2360
        
        ; Jump ahead if the barrel is on the straight part of the top platform
        ld      a,76
        cp      l
        jp      z,l2366
        
        ; Jump ahead if the barrel has ???
        ld      a,l
        bit     5,a
        jp      z,l235c
        
l2359:  sub     b

		; Update the barrel's y coordinate and return
l235a:  ld      l,a
        ret     
		
		; Move the barrel down 1 pixel
l235c:  add     a,b
        jp      l235a

l2360:  bit     7,h
        jp      nz,l2359
        ret     
		
		; Return if the barrel has not reached the sloped portion
		; of the top platform
l2366:  ld      a,h
        cp      152
        ret     c
		
		; Jump back up to move the barrel down 1 pixel
        ld      a,l
        jp      l235c		
;------------------------------------------------------------------------------

         
		
;------------------------------------------------------------------------------
; This function checks if Mario is at the top or bottom of a ladder.
; If Mario is not at the top or bottom of a ladder, the calling function is 
; aborted
;
; NOTE: A few bytes may be saved by setting bc to 21 at the beginning
; of this function rather than having the calling function set it.
; That is, unless other values are used
;
; passed:	a - Mario's x coordinate
;			d - Mario's y coordinate (+8)
;			bc - set to 21 (the number of normal ladders + 1)
; return:	a - 0 if Mario is at the bottom of a ladder,
;				1 if Mario is at the top of a ladder
;			b - the y coordinate of the other end of the ladder
;				(bottom if Mario is at the top of the ladder,
;				top if Mario is at the bottom of the ladder)
L_CHECK_IF_ON_LADDER:  
		; If there is not a normal ladder under Mario,
		; jump ahead to return from the calling function
		ld      hl,NORMAL_LADDER_X_COORD_DATA
l2371:  cpir    
        jp      nz,l239a
        
        ; Save hl and bc
        push    hl
        push    bc
        
        ; Advance hl to this ladder's y1 coordinate
        ld      bc,20
        add     hl,bc
        
        inc     c
        
        ; If Mario is at the bottom of this ladder,
        ; jump ahead
        ld      e,a						; Save Mario x in e
        ld      a,d						; Load Mario y from d
        cp      (hl)
        jp      z,l238f
        
        ; Advance hl to this ladder's y2 coordinate
        add     hl,bc
        
        ; If Mario is at the top of this ladder, jump ahead
        cp      (hl)
        jp      z,l2395
        
        ; Search again for another ladder
        ld      d,a						; Save Mario y in d Note: this may not be neccessary - d already contains the y coordinate
        ld      a,e						; Load Mario x from e
        pop     bc
        pop     hl
        jp      l2371

		; Advance hl to the ladder's y2 coordinate
l238f:  add     hl,bc

		; Jump ahead to return a as 1
        ld      a,1
        jp      l2398
        
        ; Return a as 0
l2395:  xor     a						; a = 0
        
        ; Backup hl to the ladder's y1 coordinate
        sbc     hl,bc
        
        ; Store the ladder's other y coordinate in b
l2398:  pop     bc
        ld      b,(hl)
        
l239a:  pop     hl
        ret     
;------------------------------------------------------------------------------
		

		
;------------------------------------------------------------------------------
l239c:  
		ld      a,(ix+4)
        add     a,(ix+17)
        ld      (ix+4),a
        ld      a,(ix+3)					; X coordinate
        adc     a,(ix+16)
        ld      (ix+3),a
        
        ld      a,(ix+6)
        sub     (ix+19)
        ld      l,a
        ld      a,(ix+5)					; Y coordinate
        sbc     a,(ix+18)
        ld      h,a
        ld      a,(ix+20)
        and     a						; Clear the carry bit
        rla     						; Bit 7 to carry flag
        inc     a
        ld      b,0
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        ld      c,a
        add     hl,bc
        ld      (ix+5),h				; Y coordinate
        ld      (ix+6),l				
        inc     (ix+20)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; passed;	c - 
l23de:  
		; Decrement the ??? counter
		; If it has not reached 0, jump ahead to skip this function
		ld      a,(ix+15)
        dec     a
        jp      nz,l2403
        
        xor     a						; a = 0
        sla     (ix+7)
        rla     
        sla     (ix+8)
        rla     
        ld      b,a
        ld      a,3
        or      c
        call    l3009
        
        rra     
        rr      (ix+8)
        rra     
        rr      (ix+7)
        
        ; Reset the ??? to 4
        ld      a,4
l2403:  ld      (ix+15),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2407:  ld      a,(ix+20)
        rlca    
        rlca    
        rlca    
        rlca    
        ld      c,a
        and     %00001111
        ld      h,a
        ld      a,c
        and     %11110000
        ld      l,a
        ld      c,(ix+19)
        ld      b,(ix+18)
        sbc     hl,bc
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Implement the barriers that stop Mario from moving past the edges of the screen
; or past the invisible barriers surrounding Donkey Kong on the barrels and 
; elevators stages.
;
; passed:	none
; return:	d = 1 if Mario can't move left
;			e = 1 if Mario can't move right
L_IMPLEMENT_BARRIERS:  
		; Check if Mario is at the left edge of the stage
		ld      de,$0100					
        ld      a,(MARIO_X)
		cp		22
        ret     c							; Return if Mario X < 22
		
		; Check if Mario is at the right edge of the stage
        dec     d
        inc     e
        cp      234
        ret     nc							; Return if Mario X > 234

		; Return if not the barrels stage or elevators stage
        dec     e
        ld      a,(CURRENT_STAGE)
        rrca    
        ret     nc
		
		; Return if Mario is below the top platform
        ld      a,(MARIO_Y)
        cp      88
        ret     nc							; Return if Mario Y > 88
		
		; Check if Mario is approaching Donkey Kong
		; (There is an invisible barrier preventing Mario from approaching the two ladders)
        ld      a,(MARIO_X)
        cp      108
        ret     nc							; Return if Mario X > 108
        inc     d
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Parse the stage data for the current stage and use it to fill in the ladder
; data structures (type, x coordinate, and y1 - y2 coordinates)
; NOTE:	This function seems to have been written to deal with two different
;		versions of the Donkey Kong code.  One (earlier version?) allowed for
;		one more normal ladder and one less broken ladder than this one does.
;		The section of this code that checks for the older version can probably
;		be removed to save space, as it doesn't seem to be needed.
;		The value of characters 2 - 7 will always add up to 256.
L_PARSE_STAGE_LADDER_DATA:  
		; Add the values of the characters 2 - 7 in the nintendo string + $5e
		ld      hl,L_NINTENDO_STRING_DATA_1
        ld      a,$5e
        ld      b,6						; For b = 6 to 1
l2448:  add     a,(hl)
        inc     hl
        djnz    l2448					; Next b
        
        ; If the characters added up to 256 (0),
        ; (characters 2-7 = "INTEND")
        ; set iy to BROKEN_LADDER_X_COORD_DATA
        ld      iy,BROKEN_LADDER_X_COORD_DATA
        and     a
        jp      z,l2456
        
        ; If the characters did not add up to 256, 
        ; (characters 2-7 != "INTEND")
        ; set iy to $6311
        inc     iy
        
        ; If the current stage is barrels,
        ; point to the barrels stage data
l2456:  ld      a,(CURRENT_STAGE)
        dec     a
        ld      hl,L_BARRELS_STAGE_DATA
        jp      z,l2471
        
        ; If the current stage is the mixer,
        ; point to the mixer stage data
        dec     a
        ld      hl,L_MIXER_STAGE_DATA
        jp      z,l2471
        
        ; If the current stage is the elevators,
        ; point to the elevators stage data
        dec     a
        ld      hl,L_ELEVATORS_STAGE_DATA
        jp      z,l2471
        
        ; Point to the rivets stage data
        ld      hl,L_RIVETS_STAGE_DATA
        
l2471:  ld      ix,NORMAL_LADDER_X_COORD_DATA
        ld      de,5
        
        ; If the first tile type of stage data is $00,
        ; (normal ladder),
        ; then jump ahead
l2478:  ld      a,(hl)
        and     a
        jp      z,l2488
        
        ; If the first tile type of stage data is $01,
        ; (broken ladder),
        ; then jump ahead
        dec     a
        jp      z,l249e
        
        ; If the end of the data has been reached, return
        cp      $a9
        ret     z
		
		; Check out the next tile type
        add     hl,de
        jp      l2478
        
		; Record the coordinates of the normal ladder
l2488:  inc     hl						; X1 coordinate
        ld      a,(hl)
        ld      (ix+0),a
        inc     hl						; Y1 coordinate
        ld      a,(hl)
        ld      (ix+21),a
        inc     hl
        inc     hl						; Y2 coordinate
        ld      a,(hl)
        ld      (ix+42),a
        
		; Advance to the next ladder data structure 
		; and the next block of tile data
        inc     ix
        inc     hl
        
		; Process the next block of tile data
        jp      l2478
        
		; Record the coordinates of the broken ladder
l249e:  inc     hl						; X1 coordinate
        ld      a,(hl)
        ld      (iy+0),a
        inc     hl						; Y1 coordinate
        ld      a,(hl)
        ld      (iy+21),a
        inc     hl
        inc     hl						; Y2 coordinate
        ld      a,(hl)
        ld      (iy+42),a
        
		; Advance to the next ladder data structure 
		; and the next block of tile data
        inc     iy
        inc     hl
        
		; Process the next block of tile data
        jp      l2478
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
l24b4:  
		; Return if ??? is above 232
		ld      a,(ix+5)					; Y coordinate
        cp      232
        ret     c
		
        ; Returm if ??? is right of 42 or left of 32
        ld      a,(ix+3)					; X coordinate
        cp      42
        ret     nc
        cp      32
        ret     c
		
		; If this is not an oil barrel, jump ahead
		; to skip the fire flare up
        ld      a,(ix+21)				; Barrel type
        and     a
        jp      z,l24d0
        
        ; Flare up the oil fire
        ld      a,3
        ld      (BARREL_FIRE_STATE),a
        
        ; Mark the barrel as inactive
        xor     a
l24d0:  ld      (ix+0),a					; Active
        ld      (ix+3),a					; X coordinate
        
        ; Trigger Donkey Kong's stomp sound
        ld      hl,STOMP_SOUND_TRIGGER
        ld      (hl),3
        
        pop     hl
        
        ; If the barrel fire is marked as burning, jump ahead
        ld      a,(BARREL_FIRE_STATUS)
        and     a
        jp      nz,L_LD_SPRITE_DATA_TO_STRUCT_2
        
        ; Mark the fire as burning
        inc     a
        ld      (BARREL_FIRE_STATUS),a
        
        jp      L_LD_SPRITE_DATA_TO_STRUCT_2

		
		; Return unless this is the mixer stage
l24ea:  ld      a,%00000010
        rst     $30							
		
        call    l2523
        call    L_MOVE_PIES_ON_CONVEYERS
        ld      ix,PIE_STRUCTS
        ld      b,6
        ld      hl,PIE_SPRITES
l24fc:  ld      a,(ix+0)
        and     a
        jp      z,l251c
        ld      a,(ix+3)
        ld      (hl),a
        inc     l
        ld      a,(ix+7)
        ld      (hl),a
        inc     l
        ld      a,(ix+8)
        ld      (hl),a
        inc     l
        ld      a,(ix+5)
        ld      (hl),a
        inc     l
l2517:  add     ix,de
        djnz    l24fc
        ret     
		
l251c:  ld      a,l
        add     a,$04
        ld      l,a
        jp      l2517
l2523:  ld      hl,$639b
        ld      a,(hl)
        and     a
        jp      nz,l258f
        ld      a,($639a)
        and     a
        ret     z
		
        ld      b,$06
        ld      de,$0010
        ld      ix,PIE_STRUCTS
l2539:  bit     0,(ix+0)
        jp      z,l2545
        add     ix,de
        djnz    l2539
        ret     
		
l2545:  call    L_UPDATE_RAND_NUM
        cp      $60
        ld      (ix+5),$7c
        jp      c,l2558
        ld      a,(RIGHT_MASTER_CONVEYER_DIR)
        dec     a
        jp      nz,l256e
l2558:  ld      (ix+5),$cc
        ld      a,(BOT_MASTER_CONVEYER_DIR)
        rlca    
l2560:  ld      (ix+3),$07
        jp      nc,l2576
        ld      (ix+3),$f8
        jp      l2576
l256e:  call    L_UPDATE_RAND_NUM
        cp      $68
        jp      l2560
l2576:  ld      (ix+0),$01
        ld      (ix+7),$4b
        ld      (ix+9),$08
        ld      (ix+10),$03
        ld      a,$7c
        ld      ($639b),a
        xor     a
        ld      ($639a),a
l258f:  dec     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function moves the pies along the conveyers on the mixer stage
; Note: It should be possible to optomize this function to gain a few bytes
L_MOVE_PIES_ON_CONVEYERS:  
		ld      ix,PIE_STRUCTS
        ld      de,16					; 16 byte data structures
        ld      b,6						; For b = 6 to 1 (6 pies)
        
        ; If this pie is not active, jump ahead to process the next one
l259a:  bit     0,(ix+0)
        jp      z,l25bb
        
        ; If the pie is off the left edge of the scen, jump ahead
        ld      a,(ix+3)					; x coordinate
        ld      h,a
        add     a,7
        cp      14
        jp      c,l25d6
        
        ; If the pie is on the left or right conveyers
        ld      a,(ix+5)					; y coordinate
        cp      124
        jp      z,l25c0
        
        ; The pie is on the bottom conveye r
        ; Move the pie along the bottom conveyer
        ld      a,(BOT_CONVEYER_DIR)
        add     a,h
        ld      (ix+3),a					; x coordinate
        
        ; Move on to the next pie
l25bb:  add     ix,de
        djnz    l259a
        ret     
		
		; The pie is on the left or right conveyer
		; If the pie has reached the oil barrel, jump ahead
l25c0:  ld      a,h
        cp      128
        jp      z,l25d6
        
        ; If the pie is on the right conveyer belt,
        ; use the right conveyer belt direction
        ld      a,(RIGHT_CONVEYER_DIR)
        jp      nc,l25cf
        
        ; If the pie is on the left conveyer belt,
        ; use the left conveyer belt direction
        ld      a,(LEFT_CONVEYER_DIR)
        
        ; Move the pie along this conveyer belt
l25cf:  add     a,h
        ld      (ix+3),a
        
        ; Jump back to process the next pie
        jp      l25bb
        
        ; Get the address of the pie sprite that went offscreen
        ; and jump ahead to inactivate it
l25d6:  ld      hl,PIE_SPRITES
        ld      a,6
        sub     b
l25dc:  jp      z,l25e7

        ; Advance to the next pie sprite
        inc     l
        inc     l
        inc     l
        inc     l
        
        ; Jump back up to continue searching for the correct sprite
        dec     a
        jp      l25dc
        
        ; Deactivate the sprite structure
l25e7:  xor     a
        ld      (ix+0),a					; Sprite active
        ld      (ix+3),a					; X coordinate
        
        ; Hide the sprite
        ld      (hl),a
        
        ; Jump back up to process the next pie
        jp      l25bb
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function performs conveyer handling for the mixer stage
L_IMPLEMENT_CONVEYERS:  
		ld      a,2
        rst     $30							; Return unless this is the mixer stage
        call    L_IMPLEMENT_TOP_CONVEYER
        call    L_IMPLEMENT_MID_CONVEYERS
        call    L_IMPLEMENT_BOT_CONVEYERS
        call    L_MOVE_MARIO_ON_CONVEYERS
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function controls the top conveyer belt and causes it to change directions
; periodically.
;
; It also calls the animate motor function to animate the top two conveyer belt
; motor sprite to simulate them rotating.
L_IMPLEMENT_TOP_CONVEYER:  
		; If counter 2 is odd, jump ahead to skip the conveyer reverse logic
		ld      a,(COUNTER_2)
        rrca    
        jp      c,l2616
		
		; If the conveyer reverse timer has not reached zero, jump ahead to
		; skip the conveyer reverse logic
        ld      hl,TOP_MASTER_REVERSE_TIMER
        dec     (hl)
        jp      nz,l2616
		
		; Reset the conveyer reverse timer to 128
        ld      (hl),128
		
		; Reverse the conveyer belt
        inc     l							; TOP_MASTER_CONVEYER_DIR
        call    L_REVERSE_CONVEYER_DIR
		
		; Set the conveyer belt speed to 1 in the current direction
l2616:  ld      hl,TOP_MASTER_CONVEYER_DIR
        call    L_SET_CONVEYER_SPEED_TO_1
		
		; Set the top conveyer belt direction and speed to match the master
		; animation conveyer belt direction
        ld      (TOP_CONVEYER_DIR),a
		
		; If it is not time to update the motor animation, then return
        ld      a,(COUNTER_2)
        and     %00011111
        cp      1
        ret     nz
		
		; Animate the two conveyer belt motors
        ld      de,CONV_MOTOR_SPRITE_TL
        ex      de,hl
        call    L_ANIMATE_MOTOR_SPRITES
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function controls the left and right conveyer belts on the mixer stage
; These two conveyer belts are tied to the middle master conveyer belt direction
; and they always move opposite of each other.  
; Interestingly, they reverse direction periodically until Mario has climbed
; above the bottom conveyer belt.  As long as Mario is above that, they will
; always move inwards.  
;
; It also calls the animate motor function to animate the top two conveyer belt
; motor sprite to simulate them rotating.
;
; NOTE: If space is at a premium, this behavior could be changed to have the
;		left and right conveyers always move inward.  This would technically 
;		change the game, but would have no effect on game play.
L_IMPLEMENT_MID_CONVEYERS:  
		; If Mario is above the bottom conveyer platform,
		; jump ahead to force the left and right conveyer belts 
		; to move inward
		ld      hl,RIGHT_MASTER_CONVEYER_DIR
        ld      a,(MARIO_Y)
        cp      192
        jp      c,l266f

		; If counter 2 is odd, jump ahead
        ld      a,(COUNTER_2)
        rrca    
        jp      c,l264c
        
        ; Decrement MID_MASTER_REVERSE_TIMER 
        ; If it has not reached 0, jump ahead  
        dec     l							; MID_MASTER_REVERSE_TIMER
        dec     (hl)
        jp      nz,l264c
        
        ; Reset MID_MASTER_REVERSE_TIMER to 192
        ld      (hl),192
        inc     l							; RIGHT_MASTER_CONVEYER_DIR
        
        ; Reverse the middle (left and right) conveyers
        call    L_REVERSE_CONVEYER_DIR
        
l264c:  ld      hl,RIGHT_MASTER_CONVEYER_DIR
        call    L_SET_CONVEYER_SPEED_TO_1	; a = RIGHT_MASTER_CONVEYER_DIR speed and dir
        
        ; Set the right and left conveyer belt directions
        ; (opposite of each other)
        ld      (RIGHT_CONVEYER_DIR),a
        neg     
        ld      (LEFT_CONVEYER_DIR),a
        
        ; If it is not time to update the motor animation, then return
        ld      a,(COUNTER_2)
        and     %00011111
        ret     nz
		
		; Update the animation of the left and right conveyer motors
        dec     l							; MID_MASTER_REVERSE_TIMER
        ld      de,CONV_MOTOR_SPRITE_MR
        ex      de,hl
        call    L_ANIMATE_MOTOR_SPRITES
        
        ; Face the motor sprite number to the right
        ; Note: is this necessary?  The motor sprite number was already updated
        ; 	  in the call to L_ANIMATE_MOTOR_SPRITES...
        and     %01111111
        ld      hl,CONV_MOTOR_SPRITE_MR_NUM
        ld      (hl),a
        ret    

		; If the middle master conveyer is moving left, jump back up 
l266f:  bit     7,(hl)						; RIGHT_MASTER_CONVEYER_DIR
        jp      nz,l264c
		
		; If the middle master conveyer is moving right, 
		; Reverse the conveyer direction and jump back up
		; This causes the pies on the left and right conveyers 
		; to start moving inward once Mario is above the bottom 
		; conveyer
        ld      (hl),-1
        jp      l264c
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; This function controls the bottom conveyer belt and causes it to change directions
; periodically.
;
; It also calls the animate motor function to animate the bottom two conveyer belt
; motor sprite to simulate them rotating.
L_IMPLEMENT_BOT_CONVEYERS:  
		; If counter 2 is odd, jump ahead
		ld      a,(COUNTER_2)
        rrca    
        jp      c,l268d
        
        ; Decrement the conveyer reverse countdown timer
        ; If it has not reached 0, jump ahead to skip reinitializing it
        ; and reversing the conveyer
        ld      hl,BOT_MASTER_REVERSE_TIMER
        dec     (hl)
        jp      nz,l268d
        
        ; Reinitialize the timer
        ld      (hl),255
        
        ; Reverse the conveyer belt
        inc     l
        call    L_REVERSE_CONVEYER_DIR
        
        
l268d:  ld      hl,BOT_MASTER_CONVEYER_DIR
        call    L_SET_CONVEYER_SPEED_TO_1
        
        ; Set the direction and speed of the bottom conveyer
        ld      (BOT_CONVEYER_DIR),a
        
        ; If it is not time to update the conveyer motor animation
        ; return
        ld      a,(COUNTER_2)
        and     %00011111
        cp      2
        ret     nz
		
		; Animate the two bottom conveyer motors
        ld      de,CONV_MOTOR_SPRITE_BL
        ex      de,hl
        call    L_ANIMATE_MOTOR_SPRITES
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Animate a pair of conveyer belt motor sprites by advancing them in the 
; direction matching the conveyer belt's direction.
;
; passed:	hl - the address of the first of the two conveyer belt motor 
;				sprites
;			de - the address of the conveyer belt direction variable
; Return:	a - the new motor sprite number
L_ANIMATE_MOTOR_SPRITES:  
		; If the conveyer belt is moving left, jump ahead
		inc     l							; Sprite number
        ld      a,(de)
        rla     
        jp      c,l26c5
		
		; Handle the motor sprites when the conveyer belt it moving right
		
		; Advance to the next motor sprite to give the illusion that it is 
		; rotating
        ld      a,(hl)
        inc     a
		
		; If the motor sprite number does not need to be wrapped, jump ahead
		; to skip it
        cp      $53
        jp      nz,l26b5
		
		; Wrap the motor sprite number to the first motor sprite
        ld      a,$50
		
		; Save the new motor sprite number
l26b5:  ld      (hl),a

		; Advance to the opposite motor sprite sprite (it is flipped horizontally)
        ld      a,l
        add     a,4
		
		; Reverse to the previous motor sprite to give the illusion that it is
		; rotating
        ld      l,a
        ld      a,(hl)
        dec     a
		
		; If the motor sprite number does not need to be wrapped, jump ahead
		; to skip it
        cp      $cf							; $4f flipped horizontally
        jp      nz,l26c3
		
		; Wrap the motor sprite number
        ld      a,$d2						; $52 flipped horizontally
		
				
								
		; Handle the motor sprites when the conveyer belt is moving left
		
		; Save the new motor sprite
l26c3:  ld      (hl),a
        ret     
		
		; Reverse to the previous motor sprite to give the illusion that it is
		; rotating
l26c5:  ld      a,(hl)
        dec     a
		
		; If the motor sprite number does not need to be wrapped, jump ahead
		; to skip it
        cp      $4f
        jp      nz,l26ce
		
		; Wrap the motor sprite
        ld      a,$52
		
		; Save the new motor sprite
l26ce:  ld      (hl),a

		; Advance to the opposite motor sprite (it is flipped horizontally)
        ld      a,l
        add     a,4
		
		; Advance to the next motor sprite to give the illusion that it is
		; rotating
        ld      l,a
        ld      a,(hl)
        inc     a
		
		; If the motor sprite number does not need to be wrapped, jump ahead
		; to skip it
        cp      $d3							; $53 flipped horizontally
        jp      nz,l26dc
		
		; Wrap the motor sprite number
        ld      a,$d0						; $50 flipped horizontally
		
		; Save the new motor sprite
l26dc:  ld      (hl),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Reverse the direction of a conveyer belt
; passed:	hl - the address of the conveyer belt direction variable
L_REVERSE_CONVEYER_DIR:  
		; If the conveyer belt is moving right, jump ahead
		bit     7,(hl)
        jp      z,l26e6
		
		; The conveyer belt is moving left, so reverse it to move right
        ld      (hl),2
        ret  
		
		; The conveyer belt is moving right, so reverse it to move left
l26e6:  ld      (hl),-2
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Slow a conveyer belt speed to 1 pixel in the current direction
;
; passed:	hl - the address of the conveyer belt direction variable
; return:	a - the conveyer belt speed and direction
L_SET_CONVEYER_SPEED_TO_1:  
		; Return if counter 2 is even
		ld      a,(COUNTER_2)
        and     %00000001
        ret     z
		
		; If the conveyer belt is moving left, set the direction to -1
        bit     7,(hl)
        ld      a,-1
        jp      nz,l26f8
		
		; The conveyer belt is moving right, so set the direction to 1
        ld      a,1
l26f8:  ld      (hl),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Handle the elevators
; Move the elevators
; Detect when Mario is on an elevator
; Move Mario with the elevator
; Kill Mario if he reaches the bottom of the screen or is crushed at the top 
;	of the elevator
; Make Mario fall if he steps of the elevator
L_IMPLEMENT_ELEVATORS:  
		; Return unless this is the elevators stage
		ld      a,%00000100
        rst     $30		
        
        ; If Mario has reached the bottom of the screen,
        ; jump ahead to kill him				
        ld      a,(MARIO_Y)
        cp      240
        jp      nc,l277f
        
		; NOTE: The following check for the level number can be 
		; 		removed.  The way Donkey Kong is configured, 
		;		the elevator stage can't be reached on level 1
        ; If the current level is 2 or greater,
        ; jump ahead to make the conveyers move at double speed
        ld      a,(CP_LEVEL_NUMBER)
        dec     a
        ld      a,(COUNTER_2)
        jp      nz,l271a
        
        ; On the first odd cycle, 
        ; jump ahead to move Mario on the elevators
        and     %00000011
        cp      1
        jp      z,l271e
        
        ; On the first even cycle,
        ; jump ahead to move the elevators
        jp      c,l2722
        ret     
	
		; On odd cycles, 
		; jump ahead to move the elevators
l271a:  rrca    
        jp      c,l2722
        
        ; On even cycles,
        ; jump ahead to move Mario on the elevators
l271e:  call    L_MOVE_MARIO_ON_ELEVATORS
        ret    
		
		; Move the elevators
l2722:  call    L_MOVE_ELEVATORS
		; Spawn a new elevator if it is time
        call    L_SPAWN_NEW_ELEVATOR
        
        ; Update the elevator sprite coordinates to match the data structures
        ld      b,6							; 6 elevator platforms
        ld      de,16						; 16 byte data structures 
        ld      hl,ELEVATOR_PLATFORM_SPRITES
        ld      ix,ELEVATOR_STRUCTS
l2734:  ld      a,(ix+3)					; X coordinate
        ld      (hl),a						; Sprite x coordinate
        inc     l
        inc     l
        inc     l							; Sprite y coordinate
        ld      a,(ix+5)					; Y coordinate
        ld      (hl),a
        inc     l
        
        ; Advance to the next sprite
        add     ix,de
        djnz    l2734
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Move Mario up or down with the elevators
; Checks if Mario has reached the very top or bottom of the elevator shaft
;	and kills him
; Make Mario fall if he steps off the platform
L_MOVE_MARIO_ON_ELEVATORS:  
		; Return if Mario is not riding an elevator
		ld      a,(MARIO_ON_ELEVATOR)
        and     a
        ret     z
		
		; Return if Mario is jumping
        ld      a,(MARIO_IS_JUMPING)
        and     a
        ret     nz
		
		; If Mario has stepped off the left edge of the lefT elevator column,
		; jump ahead to make him fall
        ld      a,(MARIO_X)
        cp      44
        jp      c,l2766
        
        ; If Mario is still on the left elevator column,
        ; jump ahead to move him up with the elevators
        cp      67
        jp      c,l276f
        
        ; If Mario has stepped off the right edge of the left elevator column,
        ; or the left edge of the right elevator column,
        ; jump ahead to make him fall
        cp      108
        jp      c,l2766
        
        ; If Mario is still on the right elevator column,
        ; jump ahead to move him down with the elevators
        cp      131
        jp      c,l2787
        
        ; Mario has stepped off the right edge of the right elevator column
		; Mark Mario as no longer riding the elevators
l2766:  xor     a
        ld      (MARIO_ON_ELEVATOR),a
        
        ; Mark Mario as falling
        inc     a
        ld      (MARIO_IS_FALLING),a
        ret     
		
		; Mario is riding the left elevator column
		
		; If Mario has been smashed at the top of the elevator,
		; jump ahead to kill him
l276f:  ld      a,(MARIO_Y)
        cp      113
        jp      c,l277f
        dec     a
		
		; Move Mario up with the elevator
        ld      (MARIO_Y),a
        ld      (MARIO_SPRITE_Y),a
        ret   
		
		; Mark Mario as dead
l277f:  xor     a
        ld      (MARIO_ALIVE),a
		
		; Mark Mario as no longer on the elevator
        ld      (MARIO_ON_ELEVATOR),a
        ret     
		
		; Mario is riding the right elevator column
		
		; If Mario has reached the bottom of the the elevator column,
		; jump back up to kill him
l2787:  ld      a,(MARIO_Y)
        cp      232
        jp      nc,l277f
		
		; Move Mario down with the elevator
        inc     a
        ld      (MARIO_Y),a
        ld      (MARIO_SPRITE_Y),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Move the elevators
; When an elevator reaches the top of the left column it is sent to the top of
; the right column
; When an elevator reaches the bottom of the right column, it is deactivated
L_MOVE_ELEVATORS:  
		; Iterate over each elevator platform
		ld      b,6							; 6 elevator sprites
        ld      de,16						; 16 byte data structures
        ld      ix,ELEVATOR_STRUCTS
		
		; If this elevator is inactive,
		; jump ahead to process the next one
l27a0:  bit     0,(ix+0)					
        jp      z,l27c2
		
		; If the elevator is moving down,
		; jump ahead to skip the moving up logic
        bit     3,(ix+13)					; Direction
        jp      z,l27c7

		; The elevator is moving up
		
		; Move the elevator one pixel up
        ld      a,(ix+5)					; Y coordinate
        dec     a
		ld      (ix+5),a
		
		; If the elevator has not reached the top, 
		; jump ahead
        cp      96
        jp      nz,l27c2
		
		; Move the elevator to the top of the right column
        ld      (ix+3),119					; X coordinate
        ld      (ix+13),4					; Direction
		
		; Process the next elevator platform
l27c2:  add     ix,de
        djnz    l27a0
        ret  
		
		; The elevator is moving down
		
		; Move the elevator one pixel down
l27c7:  ld      a,(ix+5)
        inc     a
        ld      (ix+5),a
		
		; If the elevator has not reached the bottom,
		; jump back up to process the next elevator
        cp      248
        jp      nz,l27c2
		
		; Deactivate this elevator and process the next one
        ld      (ix+0),0					; Inactive
        jp      l27c2
;------------------------------------------------------------------------------


		
;------------------------------------------------------------------------------
; Spawns a new elevator when the elevator spawn timer reaches 0
L_SPAWN_NEW_ELEVATOR:  
		; If it is not time to spawn an elevator, 
		; jump ahead to decrement the spawn timer
		ld      hl,ELEVATOR_SPAWN_TIMER
        ld      a,(hl)
        and     a
        jp      nz,l2806
		
		; Search for the first available elevator data structure
        ld      b,6							; 6 elevator platforms
        ld      ix,ELEVATOR_STRUCTS

		; If this elevator is inactive, 
		; jump ahead to use it
l27e8:  bit     0,(ix+0)
        jp      z,l27f4
		
		; Check the next elevator
        add     ix,de
        djnz    l27e8
        ret   
		
		; Spawn the elevator at the bottom of the left column
l27f4:  ld      (ix+0),1					; Active
        ld      (ix+3),55					; X coordinate
        ld      (ix+5),248					; Y coordinate
        ld      (ix+13),8					; Moving up
        ld      (hl),52						; ELEVATOR_SPAWN_TIMER
		
		; Decrement the elevator spawn timer
l2806:  dec     (hl)						; ELEVATOR_SPAWN_TIMER
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Check if Mario has come in contact with an enemy and kill him
L_CHECK_FOR_ENEMY_COLLISION:  
		; If Mario has not contacted any enemy,
		; return
		ld      iy,MARIO_DATA_STRUCT
        ld      a,(MARIO_Y)
        ld      c,a
        ld      hl,$0407					; 8x14 collision boundary
        call    L_IMPL_ENEMY_COLL_FOR_STAGE
        and     a
        ret     z
		
		; Mario has contacted an enemy
		
		; Mark Mario as dead
        dec     a
        ld      (MARIO_ALIVE),a
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Check if Mario has struck an enemy with the hammer
L_CHECK_FOR_HAMMER_KILL:  
		; Examine each hammer
		ld      b,2							; 2 hammers
        ld      de,16						; 16 byte data structures
        ld      iy,HAMMER_STRUCTS

		; If Mario has this hammer, jump ahead to handle it
l2826:  bit     0,(iy+1)
        jp      nz,l2832
		
		; Check the next hammer
        add     iy,de
        djnz    l2826						; Next b
        ret     

		; If the hammer has not hit an enemy, 
		; return
l2832:  ld      c,(iy+5)					; Hammer y coordinate
        ld      h,(iy+9)					; Collision boundary x radius
        ld      l,(iy+10)					; Collision boundary y radius
        call    L_IMPL_ENEMY_COLL_FOR_STAGE
        and     a
        ret     z
		
		; The hammer has struck an enemy
		
		; Activate the smash animation sequence
        ld      (SMASH_ANIMATION_ACTIVE),a
		
		; Calculate the index of the enemy that was struck
        ld      a,(NUM_ENEMIES_OF_CURRENT_CLASS)
        sub     b
        ld      (SMASH_ANIMATION_ENEMY_INDEX),a
		
		; Save the structure size
        ld      a,e							; Data structure size in bytes
        ld      (SMASH_ENEMY_DATA_SIZE),a
		
		; Save a pointer to the first entry in the enemy's class data structures
        ld      (SMASH_ENEMY_CLASS_POINTER),ix
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check if Mario has jumped over an enemy
L_CHECK_FOR_ENEMY_JUMP:  
		; Setup the collision check
		ld      iy,MARIO_DATA_STRUCT
        ld      a,(MARIO_Y)
		
		; Setup the boundary 12 pixels below Mario
        add     a,12
        ld      c,a
		
		; If the player is not pressing left or right, 
		; jump ahead to use a normal sized boundary
        ld      a,(PLAYER_INPUT)
        and     %00000011
        ld      hl,TWO_BYTES(5, 8)			; 10x16 boundary
        jp      z,l286b
		
		; If the player is pressing left or right,
		; use a wider boundary
        ld      hl,TWO_BYTES(19,8)			; 28x16 boundary

		; Check if Mario has jumped over an enemy
l286b:  call    l3e88
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for collisions with enemies specific to the current stage
L_IMPL_ENEMY_COLL_FOR_STAGE:  
		ld      a,(CURRENT_STAGE)
        push    hl
        rst     $28							; Jump to local table address
        ; Jump table
		.word	L_ORG	; 0 = reset game
		.word	L_BARREL_ENEMY_COLLISION	; 1 = barrels stage
		.word	L_MIXER_ENEMY_COLLISION		; 2 = mixer stage
		.word	L_ELEVATOR_ENEMY_COLLISION	; 3 = elevators stage
		.word	L_RIVETS_ENEMY_COLLISION	; 4 = rivets stage
		.word	L_ORG	; 5 = reset game
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for collisions with enemies on the barrels stage
L_BARREL_ENEMY_COLLISION:  
		pop     hl							; Collision boundary size
		
		; Return if there has been a collision with a barrel
        ld      b,10						; 10 barrels
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      de,32						; 32 byte data size
        ld      ix,BARREL_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return if there has been a collision with a fire ball
        ld      b,5							; 5 fire balls
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      e,32						; 32 byte data size
        ld      ix,FIREBALL_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return if there has been a collision with the barrel fire
        ld      b,1							; 1 barrel fire
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
		; NOTE: The following instruction can probably be removed
        ld      e,0							; Only 1 structure - this is not needed
        ld      ix,BARREL_FIRE_STRUCT
        call    L_CHECK_FOR_COLLISION

		; Return with no collision detected
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for collisions on the mixer stage
L_MIXER_ENEMY_COLLISION:  
		pop     hl							; Collision boundary size
		
		; Return if there has been a collision with a fire ball
        ld      b,5							; 5 fire balls	
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      de,32						; 32 byte data size
        ld      ix,FIREBALL_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return if there has been a collision with a "pie"
        ld      b,6							; 6 pies
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      e,16						; 16 byte data structure
        ld      ix,PIE_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return if there has been a collision with the barrel fire
        ld      b,1							; 1 barrel fire
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
		; NOTE: The following instruction can probably be removed
        ld      e,0							; Only 1 structure - this is not needed
        ld      ix,BARREL_FIRE_STRUCT
        call    L_CHECK_FOR_COLLISION
		
		; Return with no collision detected
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for collisions on the elevators stage
L_ELEVATOR_ENEMY_COLLISION:  
		pop     hl							; Collision boundary size
		
		; Return if there has been a collision with a fire ball
        ld      b,5							; 5 fire balls
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      de,32						; 32 byte data size
        ld      ix,FIREBALL_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return if there has been a collision with a spring
        ld      b,10						; 10 springs
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      e,16						; 16 byte data size
        ld      ix,SPRING_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return with no collision detected
        ret     
;------------------------------------------------------------------------------

		
		
;------------------------------------------------------------------------------
; Check for collisions on the rivets stage
L_RIVETS_ENEMY_COLLISION:  
		pop     hl							; Collision boundary size
		
		; Return if there has been a collision with a fire ball
        ld      b,7							; 7 fire balls
        ld      a,b
        ld      (NUM_ENEMIES_OF_CURRENT_CLASS),a
        ld      de,32						; 32 byte data size
        ld      ix,FIREBALL_STRUCTS
        call    L_CHECK_FOR_COLLISION
		
		; Return with no collision detected
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for collision between 1 sprite (Mario/Hammer) and a group of sprites
; (enemies)
; passed:	b - the number of enemies to process
;			c - y coordinate
;			de - the size of the structure
;			h - the collision boundary width (radius)
;			l - the collision boundary height (radius)
;			ix - pointer to the first enemy sprite
;			iy - pointer to the start of the prime sprite data structure
; return:	a - 1 if a collision occurred,
;				0 otherwise
L_CHECK_FOR_COLLISION:  
		push    ix

		; If the current enemy sprite is inactive, jump ahead to check the next one
l2915:  bit     0,(ix+0)					; Active flag
        jp      z,l294c
		
		; Calculate the absolute difference between 
		; the primary sprite's y coordinate and
		; the enemy sprite's y coordinate
        ld      a,c
        sub     (ix+5)						; Y coordinate
        jp      nc,l2925
        neg     

		; If the primary sprite's vertical collision boundary 
		; encompasses the center of the enemy sprite,
		; jump ahead
l2925:  inc     a
        sub     l							; Boundary height
        jp      c,l2930
		
		; If the boundaries don't overlap vertically, 
		; jump ahead to process the next enemy
        sub     (ix+10)						; Enemy boundary height
        jp      nc,l294c
		
		; Calculate the absolute difference between 
		; the primary sprite's x coordinate and
		; the enemy sprite's x coordinate
l2930:  ld      a,(iy+3)					; X coordinate
        sub     (ix+3)						; X coordinate
		jp      nc,l293b
		neg     
		
		; If the primary sprite's horizontal collision boundary
		; encompasses the center of the enemy sprite
		; jump ahead
l293b:  sub     h							; Boundary width
        jp      c,l2945
		
		; If the boundaries don't ovelap horizontally,
		; jump ahead to process the next enemy
        sub     (ix+9)						; Enemy boundary width
        jp      nc,l294c
		
		; Indicate that a collision has ocurred
l2945:  ld      a,1
        pop     ix
		
		; Return from the calling function
        inc     sp
        inc     sp
        ret  
		
		; Process the next enemy sprite
l294c:  add     ix,de
        djnz    l2915
        
        ; Indicate that a collision did not occur
        xor     a
        pop     ix
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Implements the logic that checks for Mario grabbing a hammer and then 
; triggers the hammer cycle to start
L_IMPLEMENT_HAMMER_GRAB:  
		; Return unless this is the barrels stage, mixer stage, or rivets stage
		ld      a,%00001011
        rst     $30							
        
		; Check if a hammer has been grabbed
		; Return if no hammer has been grabbed
		call    L_CHECK_FOR_HAMMER_GRAB

		; Set the hammer grabbed flag to true
        ld      (HAMMER_GRABBED),a
		
		; Trigger the award sound to play
        rrca    
        rrca    							; $04
        ld      (AWARD_SOUND_TRIGGER),a
		
		; If no hammer was grabbed, return?
        ld      a,b
        and     a
        ret     z
		
		; If the second hammer was grabbed, jump ahead to mark it as taken
        cp      1
        jp      z,l296f
		
		; Mark the first hammer as grabbed
        ld      (ix+1),1					; Hammer grabbed
        ret     
		
		; Mark the second hammer as grabbed
l296f:  ld      (ix+17),1					; Hammer grabbed
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Detect when a hammer has been grabbed by checking if Mario has "collided" 
; with a hammer.
; 
; return:	a - 1 if a hammer has been grabbed
;			b - 0 if no hammer was grabbed
;				1 if the second hammer was grabbed
;				2 if the first hammer was grabbed
;			ix - pointing to the first hammer data structure
L_CHECK_FOR_HAMMER_GRAB:  
		ld      iy,MARIO_DATA_STRUCT
        ld      a,(MARIO_Y)
        ld      c,a
        ld      hl,TWO_BYTES(4,8)			; 8x16 collision area
        ld      b,2							; 2 hammers
        ld      de,16						; 16 byte data structures
        ld      ix,HAMMER_STRUCTS
        call    L_CHECK_FOR_COLLISION
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Checks if the current fireball is attempting to move off a girder into
; empty air.  
; return:	a - 0 if the tile the fireball is moving onto is a girder
;				1 if it is not
L_CHECK_IF_NOT_SUPPORTED:  
		; Get the fireball's next intended x coordinate
		ld      hl,(CURRENT_FIREBALL)
        ld      a,l
        add     a,14						; Next intended x coordinate
        ld      l,a
        ld      d,(hl)
		
		; Get the fireball's y coordinate + 12
        inc     l							; Next intended y coordinate
        ld      a,(hl)
        add     a,12
        ld      e,a
		
		; Convert the fireball coordinate to a screen memory address
        ex      de,hl
        call    L_STAGE_LOC_TO_ADDRESS
        ld      a,(hl)
		
		; If the tile is less than the girder tiles,
		; jump ahead to return a as 1
        cp      $b0
        jp      c,l29ac
		
		; If the tile is outside the block of girder tiles,
		; jump ahead to return a as 1
        and     %00001111
        cp      $08
        jp      nc,l29ac
		
		; The tile is a girder tile
		; Return a as 0
        xor     a
        ret     

		; The tile is not a girder
		; Return a as 1
l29ac:  ld      a,1
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Handle Mario's interaction with the elevators.
; Detect when Mario has landed on an elevator platform and flag him as riding it
; Detect when Mario has struck the bottom of an elevator platform with his head
;	and kill him
; Detect when Mario has hit the side of an elevator? and stop him?
; return:	a - 1 if Mario has interacted with an elevator
;			b - 1 if Mario is riding an elevator?
L_INTERACT_WITH_ELEVATORS:  
		; Return unless this is the elevators stage
		ld      a,%00000100
        rst     $30		
        
		; If Mario has not collided with an elevator platform,
		; jump ahead to return a and b as 0
        ld      iy,MARIO_DATA_STRUCT
        ld      a,(MARIO_Y)
        ld      c,a
        ld      hl,TWO_BYTES(4,8)			; 8x16 collision area
        call    L_CHECK_FOR_ELEVATOR_COLLISION
        and     a
        jp      z,l2a20
		
		; Calculate the index of the elevator Mario has collided with
        ld      a,6
		
		; If the correct index has been found, jump ahead
        sub     b
l29c7:  jp      z,l29d0

		; Advance to the next elevator index
        add     ix,de
        dec     a
        jp      l29c7

		; If Mario is not above the top of the elevator platform,
		; jump ahead
		; (This is a rough and generous collision detection, as the boundaries
		; are shifted to make it easier for Mario to get onto the platform)
l29d0:  ld      a,(ix+5)					; Y coordinate of elevator
        sub     4							; Shift the boundary up 4 pixels
        ld      d,a
        ld      a,($620c)
        add     a,5							; Allow Mario to overlap the elevator by 3 pixels
        cp      d
        jp      nc,l29ee
		
		; Move Mario to stand directly on the platform
        ld      a,d
        sub     8
        ld      (MARIO_Y),a
		
		; Indicate that Mario is now riding an elevator platform
        ld      a,1
        ld      b,a
        ld      (MARIO_ON_ELEVATOR),a
		
		; Return from the calling function
		; NOTE: These two instructions can be replaced with pop hl
        inc     sp
        inc     sp
        ret     

		; If Mario has struck the bottom of a platform with his head,
		; jump ahead to kill him
l29ee:  ld      a,($620c)
        sub     14							; Allow some overlap
        cp      d
        jp      nc,l2a1b
		
		; Detect if Mario has struck the side of an elevator platform
		
		; If Mario is jumping to the right, jump ahead to handle it
        ld      a,(MARIO_JUMPING_LEFT)
        and     a
        ld      a,(MARIO_X)
        jp      z,l2a08
		
		; Mario is jumping left
		; Adjust his x coordinate to stop at the right edge of the platform
        or      %00000111
        sub     4
		
		; Jump ahead to update Mario's x coordinate
        jp      l2a0e
		
		; Mario is jumping right
		; Adjust his x coordinate to stop at the left edge of the platform
l2a08:  sub     8
        or      %00000111
        add     a,4
		
		; Update Mario's x coordinate
l2a0e:  ld      (MARIO_X),a
        ld      (MARIO_SPRITE_X),a
        
		; Return a = 1 and b = 0
		ld      a,1
        ld      b,0
		
		; Return from the calling function
		; NOTE: These two instructions can be replaced with pop hl
        inc     sp
        inc     sp
        ret     
		
		; Mark Mario as dead and return a and b = 0
l2a1b:  xor     a
        ld      (MARIO_ALIVE),a
        ret     

		; Return a and b = 0
l2a20:  ld      b,a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Check for a collision between Mario and an elevator platform
; return: 	a - 1 if a collision has occurred
L_CHECK_FOR_ELEVATOR_COLLISION:  
		ld      b,6								; 6 elevator platforms
        ld      de,16							; 16 byte data structures
        ld      ix,ELEVATOR_STRUCTS
        call    L_CHECK_FOR_COLLISION
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2a2f:  ld      a,(ix+3)
        ld      h,a
        ld      a,(ix+5)
        add     a,$04
        ld      l,a
        push    hl
        call    L_STAGE_LOC_TO_ADDRESS
        pop     de
        ld      a,(hl)
        cp      $b0
        jp      c,l2a7b
        and     $0f
        cp      $08
        jp      nc,l2a7b
        ld      a,(hl)
        cp      $c0
        jp      z,l2a7b
        jp      c,l2a69
        cp      $d0
        jp      c,l2a6e
        cp      $e0
        jp      c,l2a63
        cp      $f0
        jp      c,l2a6e
l2a63:  and     $0f
        dec     a
        jp      l2a72
l2a69:  ld      a,$ff
        jp      l2a72
l2a6e:  and     $0f
        sub     $09
l2a72:  ld      c,a
        ld      a,e
        and     $f8
        add     a,c
        cp      e
        jp      c,l2a7d
l2a7b:  xor     a
        ret     

l2a7d:  sub     $04
        ld      (ix+5),a
        ld      a,$01
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2a85:  
		ld      a,(MARIO_IS_CLIMBING)
        and     a
        ret     nz
		
        ld      a,(MARIO_IS_JUMPING)
        and     a
        ret     nz
		
        ld      a,(MARIO_ON_ELEVATOR)
        cp      $01
        ret     z
		
        ld      a,(MARIO_X)
        sub     $03
        ld      h,a
        ld      a,(MARIO_Y)
        add     a,$0c
        ld      l,a
        push    hl
        call    L_STAGE_LOC_TO_ADDRESS
        pop     de
        ld      a,(hl)
        cp      $b0
        jp      c,l2ab4
        and     $0f
        cp      $08
        jp      nc,l2ab4
        ret    
		
l2ab4:  ld      a,d
        and     $07
        jp      z,l2acd
        ld      bc,$0020
        sbc     hl,bc
        ld      a,(hl)
        cp      $b0
        jp      c,l2acd
        and     $0f
        cp      $08
        jp      nc,l2acd
        ret     
		
l2acd:  ld      a,1
        ld      (MARIO_IS_FALLING),a
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; This function moves Mario along the conveyer belts on the mixer stage
; It's interesting to note that even the top conveyer belt is handled here,
; even though Mario can never stand on it in the game.  Perhaps the idea was
; to make Mario reach Pauline's platform to win the stage.
; NOTE: It may be possible to remove this unneeded functionality
;		and save a few bytes
;		alternatively, it may be possible to make it work as
;		originally intended
L_MOVE_MARIO_ON_CONVEYERS:  
		; If Mario is standing on the top conveyer, jump ahead
		ld      a,(MARIO_X)
        ld      b,a
        ld      a,(MARIO_Y)
        cp      80
        jp      z,l2aea
        
        ; If Mario is standing on the left or right conveyer, jump ahead
		cp      120
        jp      z,l2af6
        
        ; If Mario is standing on the bottom conveyer, jump ahead
		cp      $c8
        jp      z,l2af0
        ret     

		; Move Mario along the top conveyer
l2aea:  ld      a,(TOP_CONVEYER_DIR)
        jp      l2b02

		; Move Mario along the bottom conveyer
l2af0:  ld      a,(BOT_CONVEYER_DIR)
        jp      l2b02
        
        ; If Mario is on the right conveyer, move him along it
l2af6:  ld      a,b
        cp      128
        ld      a,(RIGHT_CONVEYER_DIR)
        jp      nc,l2b02
        
        ; If Mario is on the left conveyer, move him along it
        ld      a,(LEFT_CONVEYER_DIR)
        
        ; Move Mario
l2b02:  add     a,b
        ld      (MARIO_X),a
        ld      (MARIO_SPRITE_X),a
        
        ; Check if Mario has hit the edge of the screen
        call    L_IMPLEMENT_BARRIERS
        
        ; If Mario has hit the right edge, jump ahead to correct his position
        ld      hl,MARIO_X
        dec     e
        jp      z,l2b18
        
        ; If Mario has hit the left edge, jump ahead to correct his position
        dec     d
        jp      z,l2b1a
        
        ret     
		
		; Stop Mario from moving into the right edge of the screen
l2b18:  dec     (hl)
        ret     

		
		; Stop Mario from moving into the left edge of the screen
l2b1a:  inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2b1c:  
		ld      ix,MARIO_DATA_STRUCT
        call    l2b29
        call    L_INTERACT_WITH_ELEVATORS
        xor     a
        ld      b,a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; passed:	ix - MARIO_DATA_STRUCT
l2b29:  
		; If the current stage is not barrels, 
		; jump ahead
		ld      a,(CURRENT_STAGE)
        dec     a
        jp      nz,l2b53
        
        ; Save Mario's coordinate to hl
        ; (Y coordinate + 7)
        ld      a,(MARIO_X)
        ld      h,a
        ld      a,(MARIO_Y)
        add     a,7
        ld      l,a
        
        call    l2b9b
        
        ; If a is 0, jump ahead
        and     a
        jp      z,l2b51
        
        
        ld      a,e
        sub     c
        cp      4
        jp      nc,l2b74
        
        ld      a,c
        sub     $07
        ld      (MARIO_Y),a
        ld      a,$01
        ld      b,a
l2b51:  pop     hl
        ret     
		
l2b53:  ld      a,(MARIO_X)
        sub     $03
        ld      h,a
        ld      a,(MARIO_Y)
        add     a,$07
        ld      l,a
        call    l2b9b
        cp      2
        jp      z,l2b7a
        ld      a,d
        add     a,%00000111
        ld      h,a
        ld      l,e
        call    l2b9b
        and     a
        ret     z
		
        jp      l2b7a
l2b74:  ld      a,$00
        ld      b,$00
        pop     hl
        ret     
		
l2b7a:  ld      a,(MARIO_JUMPING_LEFT)
        and     a
        ld      a,(MARIO_X)
        jp      z,l2b8b
        or      $07
        sub     $04
        jp      l2b91
l2b8b:  sub     $08
        or      $07
        add     a,$04
l2b91:  ld      (MARIO_X),a
        ld      (MARIO_SPRITE_X),a
        ld      a,$01
        pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; passed:	hl - x,y coordinate
;			ix - 
; return:	a - 
;			b -
;			c - The y coordinate of the top of the supporting tile surface
;			de - the original x,y coordinate
l2b9b:  
		push    hl
		
		; Convert the x,y coordinate to a screen tile memory address
        call    L_STAGE_LOC_TO_ADDRESS
        
        pop     de
        
        ; Get the tile at the coordinate passed in
        ld      a,(hl)
        
        ; If the tile cannot support weight,
        ; jump ahead
        cp      $b0
        jp      c,l2bd9
        and     %00001111
        cp      8
        jp      nc,l2bd9
    
            
        ; If the tile is the ladder tile,
        ; jump ahead
        ld      a,(hl)
        cp      $c0
        jp      z,l2bd9
        
        ; If the tile is less than the ladder tile, 
        ; jump ahead
        jp      c,l2bdc
        
        ; If the tile is one of the upper porion barrel girders with ladders, 
        ; jump ahead
        cp      $d0
        jp      c,l2bcb
        
        ; If the tile is one of the barrel girders with a ladder,
        ; jump ahead
        cp      $e0
        jp      c,l2bc5
        
        ; If the tile is one of the upper porion barrel girders, 
        ; jump ahead
        cp      $f0
        jp      c,l2bcb
        
        ; The tile is one of the lower barrel girders
        
        ; Isolate the offset of the girder
l2bc5:  and     %00001111
        dec     a
        jp      l2bcf
        
        ; Isolate the offset of the girder - 9
l2bcb:  and     %00001111
        sub     9

l2bcf:  ld      c,a
        
        ; Round the y coordinate to the nearest tile boundary
        ld      a,e
        and     %11111000
        
        ; Add the tile offset
        add     a,c
        ld      c,a
        
        ; If the original y coordinate is below the top of the girder,
        ; jump ahead
        cp      e
        jp      c,l2be1
        
        ; Report that there is no supporting surface?
l2bd9:  xor     a
        ld      b,a
        ret     
		
		; Round the y coordinate to the nearest tile boundary - 1
l2bdc:  ld      a,e
        and     %11111000
        dec     a
        ld      c,a
        
l2be1:  ld      a,($620c)
        sub     (ix+5)							; Y coordinate
        add     a,e
        cp      c
        jp      z,l2bef
        jp      nc,l2bf8
l2bef:  ld      a,c
        sub     7
        ld      (MARIO_Y),a
        jp      l2bfd
        
l2bf8:  ld      a,2
        ld      b,0
        ret     
		
l2bfd:  ld      a,$01
        ld      b,a
        pop     hl
        pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l2c03:  
		; Return unless this is the barrels stage
		ld      a,%00000001
        rst     $30							
        
		; Return if Mario is dead
        rst     $10
		
		; If Donkey Kong is stomping,
		; return
        ld      a,(DK_STOMPING)
        rrca    
        ret     c
		
        ld      a,($62b1)
        and     a
        ret     z
		
        ld      c,a
        ld      a,(INTERNAL_TIMER)
        sub     2
        cp      c
        jp      c,l2c7b
        ld      a,($6382)
        bit     1,a
        jp      nz,l2c86
        ld      a,(CP_DIFFICULTY)
        ld      b,a
        ld      a,(COUNTER_2)
        and     %00011111
l2c2c:  cp      b
        jp      z,l2c33
        djnz    l2c2c
        ret     
		
l2c33:  ld      a,(INTERNAL_TIMER)
        srl     a
        cp      c
        jp      c,l2c41
        ld      a,(COUNTER_1)
        rrca    
        ret     nc
		
l2c41:  call    L_UPDATE_RAND_NUM
        and     %00001111
        jp      nz,l2c86
l2c49:  ld      a,1
l2c4b:  ld      ($6382),a
        inc     a
l2c4f:  ld      ($638f),a
        ld      a,1
        ld      ($6392),a
        ld      a,($62b2)
        cp      c
        ret     nz
		
        sub     8
        ld      ($62b2),a
        ld      de,32
        ld      hl,FIREBALL_STRUCTS
        ld      b,5
l2c69:  ld      a,(hl)
        and     a
        jp      z,l2c72
        add     hl,de
        djnz    l2c69
        ret    
		
l2c72:  ld      a,($6382)
        or      %10000000
        ld      ($6382),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; passed:	a - 
;			c - 
l2c7b:  add     a,2
        cp      c
        jp      z,l2c49
        
        ld      a,$02
        jp      l2c4b
l2c86:  xor     a
        ld      ($6382),a
        ld      a,$03
        jp      l2c4f
l2c8f:  ld      a,$01
        rst     $30							; Return unless this is the barrels stage
        ; Return if Mario is dead
        rst     $10
        ld      a,(DK_STOMPING)
        rrca    
        jp      c,l2d15
        ld      a,($6392)
        rrca    
        ret     nc
		
        ld      ix,BARREL_STRUCTS
        ld      de,32
        ld      b,10
l2ca8:  ld      a,(ix+0)
        rrca    
        jp      c,l2cb3
        rrca    
        jp      nc,l2cb8
l2cb3:  add     ix,de
        djnz    l2ca8
        ret     
		
l2cb8:  ld      ($62aa),ix
        ld      (ix+0),$02
        ld      d,$00
        ld      a,$0a
        sub     b
        add     a,a
        add     a,a
        ld      e,a
        ld      hl,SPRING_SPRITES
        add     hl,de
        ld      ($62ac),hl
        ld      a,1
        ld      (DK_STOMPING),a
        ld      de,$0501
        call    L_ADD_EVENT
        ld      hl,$62b1
        dec     (hl)
        jp      nz,l2ce6
        ld      a,$01
        ld      ($6386),a
l2ce6:  ld      a,(hl)
        cp      $04
        jp      nc,l2cf6
        ld      hl,STANDING_BARREL_SPRITE_DATA
        add     a,a
        add     a,a
        ld      e,a
        ld      d,$00
        add     hl,de
        ld      (hl),d
l2cf6:  ld      (ix+7),$15
        ld      (ix+8),$0b
        ld      (ix+21),$00
        ld      a,($6382)
        rlca    
        jp      nc,l2d15
        ld      (ix+7),$19
        ld      (ix+8),$0c
        ld      (ix+21),$01
l2d15:  ld      hl,DK_CLIMBING_COUNTER
        dec     (hl)
        ret     nz
		
        ld      (hl),$18
        ld      a,($638f)
        and     a
        jp      z,l2d51
        ld      c,a
        ld      hl,L_DK_SPRITES_THROW_BARREL
        ld      a,($6382)
        rrca    
        jp      c,l2d2f
        dec     c
l2d2f:  ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        add     a,a
        add     a,a
        add     a,c
        ld      e,a
        ld      d,$00
        add     hl,de
        call    L_LOAD_DK_SPRITES
        ld      hl,$638f
        dec     (hl)
        jp      nz,l2d51
        ld      a,1
        ld      (DK_CLIMBING_COUNTER),a
        ld      a,($6382)
        rrca    
        jp      c,l2d83
l2d51:  ld      hl,($62a8)
l2d54:  ld      a,(hl)
        ld      ix,($62aa)
        ld      de,($62ac)
        cp      $7f
        jp      z,l2d8c
        ld      c,a
        and     $7f
        ld      (de),a
        ld      a,(ix+7)
        bit     7,c
        jp      z,l2d70
        xor     $03
l2d70:  inc     de
        ld      (de),a
        ld      (ix+7),a
        ld      a,(ix+8)
        inc     de
        ld      (de),a
        inc     hl
        ld      a,(hl)
        inc     de
        ld      (de),a
        inc     hl
        ld      ($62a8),hl
        ret     
		
l2d83:  ld      hl,l39cc
        ld      ($62a8),hl
        jp      l2d54
l2d8c:  ld      hl,l39c3
        ld      ($62a8),hl
        ld      (ix+1),$01
        ld      a,($6382)
        rrca    
        jp      c,l2da5
        ld      (ix+1),$00
        ld      (ix+2),$02
l2da5:  ld      (ix+0),$01
        ld      (ix+15),$01
        xor     a
        ld      (ix+16),a
        ld      (ix+17),a
        ld      (ix+18),a
        ld      (ix+19),a
        ld      (ix+20),a
        ld      (DK_STOMPING),a
        ld      ($6392),a
        ld      a,(de)
        ld      (ix+3),a
        inc     de
        inc     de
        inc     de
        ld      a,(de)
        ld      (ix+5),a
        ld      hl,L_DK_SPRITES_L_ARM_RAISED
        call    L_LOAD_DK_SPRITES
        ld      hl,DK_SPRITE_1_Y
        ld      c,$fc
        rst     $38
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function causes a fireball or firefox to randomly be released 
; on the mixer or rivets stage
L_RANDOMLY_RELEASE_FIREBALL:  
		; Return unless this is the mixer stage or rivets stage
		ld      a,%00001010
        rst     $30		

		; Return if Mario is dead
        rst     $10
		
		; Calculate the modified difficulty 
		; by incrementing the current difficulty and multiplying by 2
        ld      a,(CP_DIFFICULTY)
        inc     a
        and     a
        rra     
        ld      b,a
		
		; Increment the modified difficulty by one 
		; if this is the mixer stage
        ld      a,(CURRENT_STAGE)
        cp      2
        jr      nz,l2dee		
        inc     b  							; ++b if this is the mixer stage

		; For b = modified difficulty to 1
		; Convert the modified difficulty into a random bit mask
		; The bit mask makes it more likely that a fireball is released
		; on higher difficulty settings
l2dee:  ld      a,254
        scf        							; Set the carry flag
		
l2df1:  rra     
        and     a							; Clear the carry flag
        djnz    l2df1						; Next b

		; Use the random bit mask to randomly release a fireball
		; Return if a fireball should not be released
        ld      b,a
        ld      a,(COUNTER_2)
        and     b
        ret     nz
		
		; Trigger a fireball to be released
        ld      a,1
        ld      (RELEASE_A_FIREBALL),a
        ld      ($639a),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Process the springs on the elevators level
; This function spawns new springs, makes them bounce, and then causes them to 
; fall when they reach the gap in the top platform
L_IMPLEMENT_SPRINGS:  
		; Return unless this is the elevators stage
		ld      a,%00000100
        rst     $30	
        						
        ; Return if Mario is dead
        rst     $10
        
        ld      ix,SPRING_STRUCTS			; ix points to the first spring data structure
        ld      iy,SPRING_SPRITES			; iy points to the first spring sprite?
        ld      b,10						; For b = 10 to 1 (10 springs)

		; If this spring is not active, jump ahead to process the next spring
l2e12:  ld      a,(ix+0)					
        rrca    
        jp      nc,l2ea7					; If the spring is inactive, don't process it

        ld      a,(COUNTER_2)
        and     %00001111
        jp      nz,l2e29

        ld      a,(iy+1)					; Swap between extended and compressed sprites every 16 counter cycles
        xor     %00000111
        ld      (iy+1),a

		; If the spring is falling, jump ahead to skip the bounce logic
l2e29:  ld      a,(ix+13)					; Spring state
        cp      4
        jp      z,l2e84						; If the spring is falling, skip bounce processing

		; Move the spring two pixels right
        inc     (ix+3)						; X coordinate
        inc     (ix+3)							

		; Get the next bounce vector
        ld      l,(ix+14)					; hl = address of next bounce vector
        ld      h,(ix+15)
        ld      a,(hl)						; a = next bounce vector
        ld      c,a							; c = next bounce vector as well
        
        ; If this is the end of the vecor data, jump ahead
        ; to process the end of the bounce
        cp      $7f
        jp      z,l2e9c						; If the end of the bounce sequence has been reached, restart the sequence
		
		; Advance to next bounce vector
        inc     hl				
        					
		; Move the spring up or down by the vector
        add     a,(ix+5)
        ld      (ix+5),a

		; Resave the address of the next bounce vector
l2e4b:  ld      (ix+14),l
        ld      (ix+15),h
		
		; If the spring has not reached the gap in the platform,
		; jump ahead to skip the falling logic
        ld      a,(ix+3)					; X coordinate
        cp      183
        jp      c,l2e6c						; If the spring has not reached the gap, simply update the sprite position

        ; If the end of the bounce has not been reached,
        ; jump ahead to skip the falling logic
        ld      a,c
        cp      $7f
        jp      nz,l2e6c	
        
        ; Trigger the spring's falling state
        ld      (ix+13),4					; Enter the falling state
		
		; Turn off spring bounce sound
        xor     a
        ld      (SPRING_SOUND_TRIGGER),a
		
		; Trigger the falling sound
        ld      a,3
        ld      (FALL_SOUND_TRIGGER),a
		
		; Move the sprite to the new coordinate
l2e6c:  ld      a,(ix+3)					; Data structure x coordinate				
        ld      (iy+0),a					; Sprite x coordinate
        ld      a,(ix+5)					; Data structure y coordinate
        ld      (iy+3),a					; Sprite y coordinate

		; Advance to the next spring structure
l2e78:  ld      de,16
        add     ix,de	
        
		; Advance to the next spring sprite							
        ld      e,4
        add     iy,de	
        
        ; Process the next spring
        djnz    l2e12						; Next b
        ret     
		
		; Move the spring 3 pixels down
l2e84:  ld      a,3
        add     a,(ix+5)					; y coordinate
        ld      (ix+5),a

		; If the spring has not reached the bottom of the screen, jump back up
		; to update the sprite position
        cp      248
        jp      c,l2e6c

		; Inactivate the spring
        ld      (ix+3),0					; x coordinate
        ld      (ix+0),0					; Sprite inactive
        
        ; Jump back up to update the sprite posituon
        jp      l2e6c
		
		; Restart the bounce sequence
l2e9c:  ld      hl,L_SPRING_VECTOR_DATA	

		; Play the spring bounce sound					
        ld      a,3
        ld      (SPRING_SOUND_TRIGGER),a
        
        ; Jump back up to continue processing the bounce logic
        jp      l2e4b						; Continue the bounce sequence processing
		
		; If it is not time to release a spring, 
		; jump back up to process the next spring
l2ea7:  ld      a,(RELEASE_SPRING)
        rrca    
        jp      nc,l2e78								

		; Release a new spring
        xor     a
        ld      (RELEASE_SPRING),a			; Reset the release spring flag
        ld      (ix+5),80					; Y coordinate
        ld      (ix+13),1					; Spring state = bouncing

		; Get a random number between -8 and 7
        call    L_UPDATE_RAND_NUM
        and     %00001111
        add     a,-8

		; Initialize spring
        ld      (ix+3),a					; Spring x coord = -8 to 7
        ld      (ix+0),1					; Activate spring
        ld      hl,L_SPRING_VECTOR_DATA		; Point to start of bounce vector data
        ld      (ix+14),l
        ld      (ix+15),h
        
        ; Jump back up to process the next spring
        jp      l2e78						; Process next spring
;------------------------------------------------------------------------------
		


;------------------------------------------------------------------------------
; This function animates the hammer cycle if it is active.
; This involves:
;	Displaying the hammer in Mario's hands when he first grabs it
; 	Animating the up/down pounding of the hammer when Mario reaches the ground
;	Playing the hammer time song
;	Alternating the hammer color when time is running out
;	Deactivating the hammer when the cycle is over
L_ANIMATE_HAMMER_CYCLE:  
		; Note: this stage check could probably be eliminated without affecting game play
		ld      a,%1011
        rst     $30							; Return unless this is the barrels stage, mixer stage, or rivets stage
        
        ; Return if Mario is dead
        rst     $10

        ; Determine which hammer is being held
        ld      de,HAMMER_SPRITE_1			
        ld      ix,HAMMER_STRUCT_1
        ld      a,(ix+1)					; Mario has hammer
        rrca    
        jp      c,l2eed
        ld      de,HAMMER_SPRITE_2
        ld      ix,HAMMER_STRUCT_2

		; Indicate that the hammer is above Mario
l2eed:  ld      (ix+14),0					; X offset
        ld      (ix+15),-16					; Y offset

		; If the hammer cycle is not active, jump ahead to skip 
		; running the cycle (raising and lowering the hammer)
        ld      a,(HAMMER_CYCLE_ACTIVE)
        rrca    
        jp      nc,l2f97

		; The hammer cycle is active
		; Clear the hammer grabbed flag as it is no longer needed
        xor     a
        ld      (HAMMER_GRABBED),a
        
		; Trigger the hammer time tune
        ld      hl,SONG_TRIGGER
        ld      (hl),SONG_TRIGGER_HAMMER
        
        ld      (ix+9),6
        ld      (ix+10),3
        
        ; Convert Mario's sprite to a version holding the hammer in the air
        ; (Current sprite * 2 with bit 3 set, properly flipped)
        ld      b,$1e						; Hammer up sprite number
        ld      a,(MARIO_DATA_SPRITE_NUM)
        sla     a
        jp      nc,l2f1b
        or      %10000000					; Flip horizontally
        set     7,b
l2f1b:  or      %00001000					; Set the sprite to one of the hammer-carrying sprites
        ld      c,a
        
        ; If it is not time to lower the hammer, jump ahead
        ld      a,(HAMMER_CYCLE_COUNTER)
        bit     3,a
        jp      z,l2f43
        
        ; Set the Mario and hammer sprites to their lowered positions
        set     0,b
        set     0,c

        ld      (ix+9),5
        ld      (ix+10),6
        
        ; Indicate the hammer is lowered to Mario's left
        ld      (ix+15),0					; Y offset
        ld      (ix+14),-16					; X offset
        
        ; If Mario is facing left, jump ahead to skip flipping the hammer 
        bit     7,c
        jp      z,l2f43

		; Indicatd the hammer is lowered to Mario's right
        ld      (ix+14),16					; X offset
        
        ; Save the sprite number
l2f43:  ld      a,c
        ld      (MARIO_SPRITE_NUM),a
        
        ; Use palette 7
        ld      c,7
        
        ; Advance the hammer cycle
        ld      hl,HAMMER_CYCLE_COUNTER
        inc     (hl)
        
        ; If the cycle has not wrapped around back to 0, jump ahead
        jp      nz,l2fb7
        
        ; Increment the hammer cycle wrap counter
        ld      hl,HAMMER_CYCLE_WRAP_COUNTER
        inc     (hl)
        ld      a,(hl)
        
        ; If the hammer cycle has not wrapped twice, jump ahead
        cp      2
        jp      nz,l2fbe
        
        ; Reset hammer cycle data
        xor     a
        ld      (HAMMER_CYCLE_WRAP_COUNTER),a
        ld      (HAMMER_CYCLE_ACTIVE),a
        ld      (ix+1),a					; Mario no longer has the hammer
        ld      a,(MARIO_X)
        neg     
        ld      (ix+14),a					; X offset = -MARIO_X (this is used lower down to set the hammer's x coordinate to 0)
        
        ; Update Mario's sprite 
        ld      a,(MARIO_DATA_SPRITE_NUM)
        ld      (MARIO_SPRITE_NUM),a
        
        ; Mark the hammer as inactive
        ld      (ix+0),0					; Sprite inactive

		; Play the previously active tune
        ld      a,(PRE_HAMMER_TUNE)
        ld      (SONG_TRIGGER),a
        
        ; Set the hammer's x coordinate based on
        ; the hammer's offset from Mario
l2f7c:  ex      de,hl
        ld      a,(MARIO_X)
        add     a,(ix+14)					; X offset					; X offset
        ld      (hl),a						; Hammer sprite x coordinate
        ld      (ix+3),a					; X coordinate
        
        ; Update the hammer sprite number and palette
        inc     hl							; Sprite number
        ld      (hl),b					
        inc     hl							; Sprite palette
        ld      (hl),c
        
        ; Set the hammer y coordinate based on the offset from Mario
        inc     hl							; Y coordinate
        ld      a,(MARIO_Y)
        add     a,(ix+15)					; Y offset
        ld      (hl),a
        ld      (ix+5),a					; Y coordinate
        ret     
        
		; If the hammer has not been grabbed, return
l2f97:  ld      a,(HAMMER_GRABBED)
        rrca    
        ret     nc
		
        ld      (ix+9),6
        ld      (ix+10),3
        
        ; Set b to the upright hammer sprite horizontally flipped to match Mario
        ld      a,(MARIO_DATA_SPRITE_NUM)
        rlca    
        ld      a,$3c						; $1e shifted left 1 bit
        rra     
        ld      b,a
        
        ; Use palette 7
        ld      c,7							; Palette 7
        
		; Save the current tune so that it can be restored after the hammer cycle is over
        ld      a,(SONG_TRIGGER)
        ld      (PRE_HAMMER_TUNE),a
        
        ; Jump back up to update the hammer sprite
        jp      l2f7c
        
		; If the hammer cycle counter has not yet wrapped once,
		; jump back up to update the hammer sprite
l2fb7:  ld      a,(HAMMER_CYCLE_WRAP_COUNTER)
        and     a
        jp      z,l2f7c
		
		; Cycle the hammer palette to provide a visual indication that
		; the hammer will disappear soon
		
		; If it is not time to change the hammer color,
		; Jump back up to update the hammer sprite
l2fbe:  ld      a,(COUNTER_2)
        bit     3,a
        jp      z,l2f7c
		
		; Set the palette to 1 and jump back up to update the hammer sprite
        ld      c,1
        jp      l2f7c
;------------------------------------------------------------------------------
		

		
;------------------------------------------------------------------------------
l2fcb:  
		; Return unless this is the mixer stage, elevators stage, or rivets stage
		ld      a,%00001110
        rst     $30			
		
        ld      hl,$62b4
        dec     (hl)
        ret     nz
		
		; Make the barrel fire flare up 
        ld      a,3
        ld      (BARREL_FIRE_STATE),a
		
		
        ld      (RELEASE_SPRING),a
		
		; Redisplay the timer
        ld      de,$0501
        call    L_ADD_EVENT

		
        ld      a,($62b3)
        ld      (hl),a
		
        ld      hl,$62b1
        dec     (hl)
        
		ret     nz

        ld      a,1
        ld      ($6386),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Convert a two byte tile location into a tile memory address
; passed:  hl - the stage location data
; return:  hl - the tile memory address
L_STAGE_LOC_TO_ADDRESS:  
		; Isolate the x coord (5 MSBs in l)
		ld      a,l
        rrca    
        rrca    
        rrca    
        and     %00011111
        ld      l,a

		; Isolate the y coord (5 MSBs in h)
        ld      a,h
        cpl     							; Invert a
        and     %11111000
        ld      e,a

		; Convert the x and y to a tile memory address
        xor     a
        ld      h,a
        rl      e						
        rla     
        rl      e
        rla     							; a = 2 MSBs in e
        add     a,$74
        ld      d,a
        add     hl,de
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; I have absolutely no idea what this function does...
; passed:	a - 
;			b - 
; return:	a
l3009:  
		; Copy a to d
		ld      d,a
		
		; If a is 1, 3, or 5, jump ahead
        rrca    
        jp      c,l3022

		; If a is 0 or 2, set c to $93
        ld      c,$93
        rrca    
        rrca    
        jp      nc,l3017
		
		; If a is 4, set c to $6c
        ld      c,$6c
		
		; If a is 2, jump ahead
l3017:  rlca    
        jp      c,l3031
		
		; Isolate the 4 MSBs of c
        ld      a,c
        and     %11110000
        ld      c,a
		
        jp      l3031
		
		; If a is 1 or 3, set c to $b4
l3022:  ld      c,$b4
        rrca    
        rrca    
        jp      nc,l302b
		
		; If a is 5, set c to $1e
        ld      c,$1e
		
		; If b is >= 4, jump ahead to skip decrementing b
l302b:  bit     2,b
        jp      z,l3031
		
        dec     b
		
		; Rotate c two bits right
l3031:  ld      a,c
        rrca    
        rrca    
        ld      c,a
		
		; If the 2 LSBs of c are not equal to b, 
		; jump back up to rotate it again
        and     %00000011
        cp      b		
        jp      nz,l3031
		
		; Rotate c two bits right
        ld      a,c
        rrca    
        rrca    
		
		; If the 2 LSBs of c are not both 1's, retrun
        and     %00000011
        cp      3
        ret     nz		
		
        res     2,d
        dec     d
        ret     nz
        
		ld      a,4
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Animate the ladder being pulled up on the introduction stage by erasing each 
; row of the ladder one by one
L_ANIMATE_LADDER_PULL_UP:  
		ld      de,-32
		
		; Get the current ladder row to erase
        ld      a,(LADDER_ROW_TO_ERASE)
        ld      c,a
        ld      b,0						; bc = row
        
        ; Erase each ladder tile at the current row
        ld      hl,TILE_COORD(16,0)
        call    L_ERASE_INTRO_LADDER_TILE
        ld      hl,TILE_COORD(14,0)
        call    L_ERASE_INTRO_LADDER_TILE
        
        ; Advance to the next row
        ld      hl,LADDER_ROW_TO_ERASE
        dec     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate the ladders on the introduction stage being pulled up by overwriting 
; a ladder tile with the tile to the left of it
; passed:  hl - screen memory address of the tile just to the left of the one to
;				overwrite
;			bc - the row to act on
;			de - -32
L_ERASE_INTRO_LADDER_TILE:  
		; Overwrite the ladder tile with the tile to the left
		add     hl,bc
        ld      a,(hl)
        add     hl,de
        ld      (hl),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Advances the current game state variable once the minor timer runs down
L_PAUSE_CURRENT_STATE:  
		rst     $18						; Return until the minor timer has run down
		
		; Advance the current state variable
        ld      hl,(CURRENT_STATE_VAR_POINTER)
        inc     (hl)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Animate Donkey Kong carrying Pauline up the ladders on the introduction stage
L_ANIMATE_CLIMBING_LADDERS:  
		; Return until 8 increments of counter have occured
		ld      hl,DK_CLIMBING_COUNTER
        inc     (hl)
        ld      a,(hl)
        and     %0111
        ret     nz
        
        ; Move Donkey Kong up 4 pixels
        ld      hl,DK_SPRITE_1_Y
        ld      c,-4
        rst     $38
        
        ; Alternate between Donkey Kong's climbing arm sprites
        ld      c,%10000001
        ld      hl,DK_SPRITE_1_NUM
        call    L_ALT_DK_ARMS_AND_LEGS
 
        ; Alternate between Donkey Kong's climbing leg sprites
        ld      hl,DK_SPRITE_6_NUM
        call    L_ALT_DK_ARMS_AND_LEGS
        
        ; Randomly flip Pauline's struggling legs
        call    L_UPDATE_RAND_NUM
        and     %10000000
        ld      hl,DK_SPRITE_10_NUM
        xor     (hl)
        ld      (hl),a
        
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Alternate Donkey Kong's arm or leg sprites to animate Donkey Kong's climb up
; the ladders 
; passed:  a - $81
;			hl - address of a Donkey Kong sprite y coord
;			de - 4
L_ALT_DK_ARMS_AND_LEGS:  
		; Alternate Donkey Kong's arms between sprites $34 and $35
		; to animate Donkey Kong climbing the ladders
		ld      b,2						; For b = 2 to 1
l3098:  ld      a,c						; %1001
        xor     (hl)
        ld      (hl),a
        add     hl,de					; Next arm sprite y coord
        djnz    l3098					; Next b
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Add function to circular event buffer to be processed and called during the
; next interrupt
; Event numbers:
;	0 = Award points
;		0 = 0 points
;		1 = 100 points
;		2 = 200 points
;		...
;		9 = 900 points
;		10 = 0 points
;		11 = 1000 points
;		12 = 2000 points
;		...
;		19 = 9000 points
;
;	1 = Clear scores
;
;	2 = Display scores
;		0 = Display player 1 score
;		1 = Display player 2 score
;		2 = Display high score
;		3 = Display all scored
;
;	3 = Display a string from the string table
;		
;	4 = Display the number of plays earned
;
;	5 = Display the timer
;		0 = Add the timer to the player's score
;		1 = Don't add the timer to the player's score
;
;	6 = Display current lives and level number
;		0 = Don't subtract a life first
;		1 = Do subtract a life first
;
; passed:	d - the event number
;			e - the argument to pass to the function
L_ADD_EVENT:  
		push    hl
        ld      hl,$60c0
        ld      a,(ACTION_BUFFER_WRITE_POS)
        ld      l,a
        bit     7,(hl)
        jp      z,l30bb
        ld      (hl),d
        inc     l
        ld      (hl),e
        inc     l
        ld      a,l
        cp      $c0
        jp      nc,l30b8
        ld      a,$c0
l30b8:  ld      (ACTION_BUFFER_WRITE_POS),a
l30bb:  pop     hl
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Clear sprites before running the death animation
L_CLEAR_SPRITES_WHEN_DEAD:  
		; Clear the collision detection sprites
		ld      hl,COLLISION_AREA_SPRITES
        ld      b,2						; For b = 2 to 1
        call    l30e4
        
        ; Clear $6980 through $69a4
        ld      l,$80					; hl = $6980
        ld      b,10						; For b = 10 to 1
        call    l30e4
        
        ; Clear the pie and conveyer motor sprites
        ld      l,$b8					; hl = PIE_SPRITES
        ld      b,11						; For b = 11 to 1
        call    l30e4
        
        ; Clear the prize and hammer sprites
        ld      hl,PRIZE_SPRITES
        ld      b,5						; For b = 5 to 1
        jp      l30e4
        
        
L_CLEAR_MARIO_SPRITE:  
		; Clear the Mario sprite
		ld      hl,MARIO_SPRITE_X
        ld      (hl),0
        
        ; Clear the elevator platform sprites
        ld      l,$58					; hl = ELEVATOR_PLATFORM_SPRITES
        ld      b,6
        
l30e4:  ld      a,l

		; Set the current sprite's x coordinate to 0
l30e5:  ld      (hl),0

		; Advance to the next sprite
        add     a,4
        ld      l,a
        djnz    l30e5					; Next b
        
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
L_IMPLEMENT_FIREBALLS:  
		; Return if it is not time to update the fireballs
		; (Fireballs are updated faster on higher difficulty levels)
		call    L_CONTROL_FIREBALL_SPEED

		; Spawn new fireballs if it is time
		; Return from this function if there are no active fireballs
        call    L_SPAWN_FIREBALLS
		
		; Make the fireballs move
        call    L_PROCESS_EACH_FIREBALL
		
		; Update the fireball sprites to match the fireball data structures
        call    L_UPDATE_FIREBALL_SPRITES
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function controls how often the fireballs are updated
; based on the current difficulty level (up to a maximum of 5).
; The fireballs are updated slower (and, thus, move slower) on
; slower difficulty levels.  As the difficulty level increases,
; so does the fireball speed.
L_CONTROL_FIREBALL_SPEED:  
		; Jump to one of the following functions based on the
		; difficulty level (up to a maximum of 5)
		ld      a,(CP_DIFFICULTY)
        cp      6
        jr      c,l3103
        ld      a,5
l3103:  rst     $28							; Jump to local table address
		; Jump table
		.word	L_CONTROL_FIREBALL_SPEED_0_1	; 0 = 
		.word	L_CONTROL_FIREBALL_SPEED_0_1	; 1 = 
		.word	L_CONTROL_FIREBALL_SPEED_2	; 2 = 
		.word	L_CONTROL_FIREBALL_SPEED_3_4	; 3 = 
		.word	L_CONTROL_FIREBALL_SPEED_3_4	; 4 = 
		.word	L_CONTROL_FIREBALL_SPEED_5 	; 5 = 
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Difficulty levels 0 and 1
; Fireballs are processed one out of two calls
L_CONTROL_FIREBALL_SPEED_0_1:  
		; Return if counter 2 is odd
		ld      a,(COUNTER_2)
        and     %00000001
        cp      1
        ret     z
		
		; Return from the calling function if counter 2 is even
        inc     sp
        inc     sp
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Difficulty level 2
; Fireballs are processed 5 out of 8 times
L_CONTROL_FIREBALL_SPEED_2: 	
		; Return if the 3 LSBs of counter 2 are less than 5
		ld      a,(COUNTER_2)
        and     %00000111
        cp      5
        ret     m
		
		; Return from the calling function 
		; if the 3 LSBs of counter 2 are greater than or equal to 5
        inc     sp
        inc     sp
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Difficulty levels 3 and 4
; Fireballs are processed 3 out of 4 times?
L_CONTROL_FIREBALL_SPEED_3_4:  
		; Return if the 2 LSBs of counter 2 are not equal to 3
		ld      a,(COUNTER_2)
        and     %00000011
        cp      3
        ret     m
		
		; Return from the calling function 
		; if the 2 LSBs of counter 2 are 3
        inc     sp
        inc     sp
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Difficulty level 5
; Fireballs are processed 7 out of 8 times
L_CONTROL_FIREBALL_SPEED_5:	
		; Return if the 3 LSBs of counter 2 are not equal to 7
		ld      a,(COUNTER_2)
        and     %00000111
        cp      7
        ret     m

		; Return from the calling function
		; if the 3 LSBs of counter 2 are 7
		inc     sp
        inc     sp
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function counts the number of active fireballs,
; Spawns new ones when it is time to and there are open fireball
; data structures,
; Returns from the calling function if there are no active 
; fireballs
;
; NOTE: Apparently, the number of active fireballs on the mixer
;		stage is limited by the current difficulty level.  
;		I did not know that...
L_SPAWN_FIREBALLS:  
		ld      ix,FIREBALL_STRUCTS
		
		; Set the active fireball count to 0
        xor     a
        ld      (ACTIVE_FIREBALL_COUNT),a
		
		; Examine each fireball data structure
        ld      b,5							; 5 fireballs
        ld      de,32						; 32 byte data structures

		; If this fireball is not active, jump ahead
l3149:  ld      a,(ix+0)
        cp      0
        jp      z,l317c
		
		; Increment the fireball index
        ld      a,(ACTIVE_FIREBALL_COUNT)
        inc     a
        ld      (ACTIVE_FIREBALL_COUNT),a
		
		; If the hammer cycle is not active,
		; set the fireball sprite palette to 1
		; (normal fireball colors)
        ld      a,1
        ld      (ix+8),a
        ld      a,(HAMMER_CYCLE_ACTIVE)
        cp      1
        jp      nz,l316a
		
		; If the hammer cycle is active,
		; set the fireball sprite palette to 0
		; (inverted fireball colors)
        ld      a,0
        ld      (ix+8),a
		
		; Process the next fireball
l316a:  add     ix,de
        djnz    l3149						; Next b

		; Set the fireball release trigger to 0
        ld      hl,RELEASE_A_FIREBALL
        ld      (hl),0
		
		; If there are active fireballs, return
        ld      a,(ACTIVE_FIREBALL_COUNT)
        cp      0
        ret     nz
		
		; If there are no active fireballs, 
		; return from the calling function
        inc     sp
        inc     sp
        ret     
		
		
		; The current fireball data structure (in ix)
		; is not being used
		
		; If there are already 5 active fireballs, 
		; jump back up to process the next data structure
		; NOTE: I don't see that this check is necessary - 
		;		it can probably be removed
l317c:  ld      a,(ACTIVE_FIREBALL_COUNT)
        cp      5
        jp      z,l316a
		
		; If this is not the mixer stage, jump ahead
        ld      a,(CURRENT_STAGE)
        cp      2
        jp      nz,l3195
		
		; If the number of active fireballs 
		; already matches the difficulty level, return
        ld      a,(ACTIVE_FIREBALL_COUNT)
        ld      c,a
        ld      a,(CP_DIFFICULTY)
        cp      c
        ret     z
		
		; If it is not time to release a fireball,
		; jump back up to process the next fireball
		; data structure
l3195:  ld      a,(RELEASE_A_FIREBALL)
        cp      1
        jp      nz,l316a
		
		; Set this fireball active
        ld      (ix+0),a					; Active
		
		; Mark that this fireball needs to be initialized
        ld      (ix+24),a					; Not initialized
		
		; Turn off the fireball release flag
        xor     a
        ld      (RELEASE_A_FIREBALL),a
		
		; Increment the number of active fireballs
        ld      a,(ACTIVE_FIREBALL_COUNT)
        inc     a
        ld      (ACTIVE_FIREBALL_COUNT),a
		
		; Jump back up to process the next fireball
        jp      l316a
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Update each fireball in turn
L_PROCESS_EACH_FIREBALL:  
		; Make fireballs 2 and 4 move left roughly 25% of the time
		call    L_FIREBALLS_ABRUPT_LEFT
		
		; Initialize the count of updated fireballs
        xor     a
        ld      (UPDATED_FIREBALL_COUNT),a
		
		; Process each fireball
        ld      hl,FIREBALL_STRUCTS - 32	; 32 bytes before the first fireball data structure
        ld      (CURRENT_FIREBALL),hl
l31be:  ld      hl,(CURRENT_FIREBALL)
        ld      bc,32
        add     hl,bc
        ld      (CURRENT_FIREBALL),hl
		
		; If this fireball is not active, 
		; jump ahead to skip processing it
        ld      a,(hl)
        and     a
        jp      z,l31d0
		
		; Update this fireball
		; Make it move, climb ladders, etc
        call    L_UPDATE_CURRENT_FIREBALL

		; Increment the number of fireballs that have been processed
l31d0:  ld      a,(UPDATED_FIREBALL_COUNT)
        inc     a
        ld      (UPDATED_FIREBALL_COUNT),a
		
		; If there are still more fireballs to process,
		; jump back up to process the next one
        cp      5
        jp      nz,l31be
		
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function makes the 2nd and 4th fireballs turn left roughly 25% of the 
; time on difficulty level 3 or higher
; I have no idea why
L_FIREBALLS_ABRUPT_LEFT:  
		; Return if the difficulty level is less than 3
		ld      a,(CP_DIFFICULTY)
        cp      3
        ret     m
		
		; Roughly a 25% chance of continuing 
        call    L_ROUGH_25_P_CHANCE
        cp      1
        ret     nz
		
		; Make fireballs 2 and 4 move left
        ld      hl,FIREBALL_STRUCT_2+25		; Direction
        ld      a,2
        ld      (hl),a
        ld      hl,FIREBALL_STRUCT_4+25		; Direction
        ld      a,2
        ld      (hl),a
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function returns a 1 roughly 25% of the time
L_ROUGH_25_P_CHANCE:  
		; 25% chance of returning a 1
		ld      a,(RANDOM_NUMBER)
        and     %00000011
        cp      1
        ret     nz
		
		; Return the value of counter 2
        ld      a,(COUNTER_2)
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function updates the current fireball's state and position
L_UPDATE_CURRENT_FIREBALL:  
		; Work with the currently active fireball
		ld      ix,(CURRENT_FIREBALL)

		; If the fireball has not been initialized yet
        ld      a,(ix+24)					; Not initialized
        cp      1
        jp      z,l327a
		
		; If the fireball is moving up or down,
		; jump ahead to skip handling horizontal movement
        ld      a,(ix+13)					; Fireball direction
        cp      4
        jp      p,l3230
		
		; If the fireball needs to pause, 
		; jump ahead to handle it
        ld      a,(ix+25)
        cp      2
        jp      z,l327e
        
		; Make the fireball change direction periodically
		call    L_CHANGE_FIREBALL_DIR
        
		ld      a,(RANDOM_NUMBER)
        and     %00000011
        jp      nz,l3233
		
		; If the fireball is standing still, 
		; jump ahead to make the fireball bob without moving
l3229:  ld      a,(ix+13)					; Fireball direction
        and     a
        jp      z,l3257
		
		; Handle the fireball climbing up and down ladders
		; If the fireball can climb a ladder, this function decides
		; if it should
l3230:  call    L_HANDLE_FIREBALLS_AND_LADDERS

		; If the fireball is moving up or down,
		; jump (way) ahead 
l3233:  ld      a,(ix+13)					; Fireball direction
        cp      4
        jp      p,l3291
		
		; Update the fireball's position while its walking
        call    L_UPDATE_FIREBALL_WALK
		
		; If the fireball is attempting to move off a girder,
		; jump ahead to reverse its direction
        call    L_CHECK_IF_NOT_SUPPORTED
        cp      1
        jp      z,l3297
		
		; Work with the current fireball
        ld      ix,(CURRENT_FIREBALL)
		
		; If the fireball is attempting to move off the left side
		; of the screen, 
		; jump ahead to make it reverse its direction
		; NOTE: Some code could be saved by jumping to the same
		;		address used when the fireball attempts to move
		;		off the girder (just above here)
		;		It would slightly change the game mechanics, 
		;		but shouldn't be noticeable
        ld      a,(ix+14)					; Next intended x coordinate
        cp      16
        jp      c,l328c
		
		; If the fireball is attempting to move off the right side
		; of the screen,
		; jump ahead to reverse its direction
		; NOTE: Some code could be saved the same as above
        cp		240
        jp      nc,l3284
		
		; If the bob table index has not reached the start of the table,
		; jump ahead to decrement the index
l3257:  ld      a,(ix+19)					; Bob table index
        cp      0
        jp      nz,l32b9
		
		; Reset the fireball bob table index to the end of the table
        ld      a,FIREBALL_BOB_TABLE_LENGTH-1
		
		; Save the new fireball bob table index
l3261:  ld      (ix+19),a					; Bob table index

		; Load the fireball bob y offset
        ld      d,0
        ld      e,a
        ld      hl,L_FIREBALL_BOB_TABLE
        add     hl,de
        ld      a,(hl)
		
		; Move the fireball to its next intended x coordinate
        ld      b,(ix+14)					; Next intended x coordinate
        ld      (ix+3),b					; X coordinate
		
		; Move the fireball to its next y coordinate plus the
		; bob offset
        ld      c,(ix+15)					; Next intended y coordinate
        add     a,c
        ld      (ix+5),a					; Y coordinate
        ret     
		
		
		; The current fireball has not been initialized yet
l327a:  call    L_INIT_FIREBALL_FOR_STAGE
        ret     
		
		
		; Handle the fireball while it is paused
l327e:  call    L_HANDLE_FIREBALL_PAUSED

		; Jump back up to continue processing the fireball movement
        jp      l3229
		
		; Make the fireball move left next
l3284:  ld      a,2

		; Update the fireball direction
l3286:  ld      (ix+13),a					; Fireball direction

		; Jump up to move the fireball to its next intended coordinate
        jp      l3257
		
		; Make the fireball move right next
l328c:  ld      a,1

		; Jump up to update the fireball direction and
		; move the fireball
        jp      l3286
		
		; Update the fireball climbing up or down the current ladder
l3291:  call    L_UPDATE_FIREBALL_CLIMB

		; Jump up to move the fireball to its next intended coordinate
        jp      l3257
		
		; Work with the currently active fireball
l3297:  ld      ix,(CURRENT_FIREBALL)

		; If the fireball is moving left, 
		; jump ahead to reverse its direction
        ld      a,(ix+13)					; Fireball direction
        cp      1
        jp      nz,l32b1
		
		; The fireball is moving right
		; Make the fireball move left immediately
        ld      a,2
        dec     (ix+14)						; Next intended x coordinate

		; Update the fireball direction
l32a8:  ld      (ix+13),a					; Fireball direction

		; If the current stage is barrels, 
		; make the fireball follow the contours of the platforms
        call    L_HANDLE_BARREL_PLATS

		; Jump up to move the fireball to its next intended coordinate
        jp      l3257
		
		; Make the fireball move right immediately
l32b1:  ld      a,1
        inc     (ix+14)						; Next intended x coordinate
		
		; Jump back up to update the fireball direction
		; and to move the fireball
        jp      l32a8
		
		; Decrement the bob table index and jump back up
		; to make the fireball bob as it moves
l32b9:  dec     a
        jp      l3261
;------------------------------------------------------------------------------


        
;------------------------------------------------------------------------------
; This function calls the correct function to initialize the fireball depending
; on the current stage
; passed:	ix - the address of the current fireball
L_INIT_FIREBALL_FOR_STAGE:  
        ; If the current stage is the barrels stage, 
		; jump ahead
		ld      a,(CURRENT_STAGE)
        cp      1
        jp      z,l32ce
		
		; If the current stage is the mixer stage
		; jump ahead
        cp      2
        jp      z,l32d2
		
		; If the current stage is the elevators or rivets stage,
		; initialize the fireball for the rivets stage
		; NOTE: If the current stage is elevators, this function
		;		returns immediately
        call    L_INIT_FIREBALL_RIVETS
        ret     
		
		; The current stage is barrels
		; Initialize the fireball for the barrels stage
l32ce:  call    L_INIT_FIREBALL_BARRELS
        ret   
		
		; The current stage is the mixer
		; Initialize the fireball for the mixer stage
l32d2:  call    L_INIT_FIREBALL_MIXER
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function controls fireballs while they are paused.
L_HANDLE_FIREBALL_PAUSED:  
		; If the pause timer is not 0, jump ahead to decrement it
		ld      a,(ix+28)					; Pause timer
        cp      0
        jp      nz,l32fd

		; If the fireball is not paused,
		; jump ahead to change direction
        ld      a,(ix+29)
        cp      1
        jp      nz,l330b
		
		; NOTE: Is this needed?  If the comparison to 1 fails above,
		; does that mean ix+29 is 0?
        ld      (ix+29),0
        
		; If the fireball is lower than Mario,
		; jump ahead to unpause it
		ld      a,(MARIO_Y)
        ld      b,(ix+15)
        sub     b
        jp      c,l3303
		
		; Reset the pause timer
        ld      (ix+28),255					; Pause timer
		
		; Make the fireball stand still
l32f8:  ld      (ix+13),0
        ret     

		; Decrement the timer
l32fd:  dec     (ix+28)						; Pause timer

		; If the timer has not reached 0, 
		; jump up to keep the fireball standing still
        jp      nz,l32f8
		
		; Mark the fireball as no longer paused
l3303:  ld      (ix+25),0

		; Reset the pause timer to 0
        ld      (ix+28),0					; Pause timer
		
		; Periodically change the fireball's direction
l330b:  call    L_CHANGE_FIREBALL_DIR
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function makes the fireball change direction periodically.
; The fireball continues moving in the current direction (left or right) for a 
; set period of time and then has a chance of changing direction.
L_CHANGE_FIREBALL_DIR:  
		; If the direction counter has not reached 0, 
		; jump ahead to decrement it and return
		ld      a,(ix+22)
        cp      0
        jp      nz,l3332
        
		; Reset the direction counter to 43
        ld      (ix+22),43
        
        ; Make the fireball stand still
        ld      (ix+13),0
        
        ; 50% chance of jumping ahead and keep moving in the
		; same direction until the direction counter reaches
		; 0 again
        ld      a,(RANDOM_NUMBER)
        rrca    
        jp      nc,l3332
        
        ; If the fireball is moving right,
        ; jump ahead
		; NOTE: Because the fireball was made to stand still up
		; above, this compare will always be non-zero, so the 
		; fireball will always end up moving right at this point.
		; This appears to be a bug, but some code could be shaved 
		; off here by just making the fireball move right without
		; affecting the game play
        ld      a,(ix+13)
        cp      1
        jp      z,l3336
        
		; Make the fireball move right
        ld      (ix+13),1
		
		; Decrement the direction counter
l3332:  dec     (ix+22)
        ret     
		
		; Make the fireball move left
		; NOTE: Execution will never reach here
l3336:  ld      (ix+13),2

		; Jump back up to decrement the direction counter and return
        jp      l3332
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This functions checks if the fireball is standing on the top or bottom of a
; ladder.  If so and the fireball can get closer to Mario by climbing the
; ladder, then it will take it; otherwise, the ladder will be ignored.
;
; This function also makes the fireball continue climbing a ladder if one is 
; currently being climbed.
L_HANDLE_FIREBALLS_AND_LADDERS:  
		; If the fireball is moving up, jump ahead
		ld      a,(ix+13)					; Fireball direction
        cp      8
        jp      z,l3371
		
		; If the fireball is moving down, jump ahead
        cp      4
        jp      z,l338a
		
		; Return if the fireball is attempting to move above
		; the top platform
		; This prevents the fireball from 
		; climbing the escape ladders, I believe
        call    L_ABORT_IF_FIREBALL_TOO_HIGH
		
        ; Check if the fireball is on a ladder
        ; a will be 0 if at the bottom, 1 if at the top
        ; This function will be aborted if no ladder
        ld      a,(ix+15)					; Next intended y coordinate
        add     a,8
        ld      d,a
        ld      a,(ix+14)					; Next intended x coordinate
        ld      bc,21
        call    L_CHECK_IF_ON_LADDER
		
		; If the fireball is at the bottom of a ladder,
		; jump ahead
        and     a
        jp      z,l3399
		
		; The fireball is at the top of a ladder
		; Save the coordinate of the bottom of the ladder
        ld      (ix+31),b
		
		; Return (don't climb down) if the fireball is below Mario
        ld      a,(MARIO_Y)
        ld      b,a
        ld      a,(ix+15)					; The next intended y coordinate
        sub     b
        ret     nc
		
		; Mark the fireball as moving down
        ld      (ix+13),4					; Direction
        ret     

		
		
		; The fireball is moving up
		; If the fireball has not reached the top of the ladder 
		; being climbed, return
l3371:  ld      a,(ix+15)					; Next intended y coordinate
        add     a,8
        ld      b,(ix+31)
        cp      b
        ret     nz
		
		; Mark the fireball as standing still
        ld      (ix+13),0					; Direction
		
		; Return if the fireball is not paused (standing without moving)
        ld      a,(ix+25)
        cp      2
        ret     nz
		
		; Mark the fireball as paused
        ld      (ix+29),1
        ret     
		
		
		
		; The fireball is moving down
		; If the fireball has not reached the bottom of the ladder
		; being climbed, return
l338a:  ld      a,(ix+15)
        add     a,8
        ld      b,(ix+31)
        cp      b
        ret     nz
		
		; Mark the fireball as standing still
        ld      (ix+13),0
        ret     
		
		
		
		; The fireball is at the bottom of a ladder
		; Record the y coordinate of the top of the ladder
l3399:  ld      (ix+31),b

		; Mark the fireball as moving up
        ld      (ix+13),8
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function checks if the current fireball is attempting to move too high
; on the barrels, mixer, or elevators stages.  If the fireball attempts to move
; onto the top platform, 
; passed:	ix - pointer to the fireball structure to process
; return:	none
L_ABORT_IF_FIREBALL_TOO_HIGH:  
		; Return unless this is the barrels stage, mixer stage, or elevators stage
		ld      a,%00000111
        rst     $30			
		
		; Return if the fireball is not trying to move onto the top
		; platform on the stage
        ld      a,(ix+15)
        cp      89
        ret     nc
		
		; If the fireball is trying to move onto the top platform on the stage,
		; return from the calling function
        inc     sp
        inc     sp
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function updates the fireball's position while it is walking
; The fireball is forced to follow the contours of the platforms on the barrels
; stage
L_UPDATE_FIREBALL_WALK:  
		; If the fireball is moving right, jump ahead
		ld      a,(ix+13)					; Direction
        cp      1
        jp      z,l33d9
		
		; The fireball is moving left
		; Face the fireball to the left
        ld      a,(ix+7)					; Sprite image
        and     %01111111					; Clear the flipped bit
        ld      (ix+7),a					; Sprite image
		
		; Move the fireball 1 pixel to the left
        dec     (ix+14)						; Next intended x coordinate
		
		; Update the sprite image
l33c0:  call    L_UPDATE_FIREBALL_SPRITE

		; If the current stage is not the barrels,
		; return
L_HANDLE_BARREL_PLATS:  
		ld      a,(CURRENT_STAGE)
        cp      STAGE_BARRELS
        ret     nz
		
		; Make the fireball move along the platforms
        ld      h,(ix+14)					; Next intended x coordinate
        ld      l,(ix+15)					; Next intended y coordinate
        ld      b,(ix+13)					; Direction
        call    L_MOVE_SPRITE_ALONG_PLAT
        ld      (ix+15),l					; Next intended y corodinate
        ret     
		
		; The fireball is moving right
		; Face the fireball to the right
l33d9:  ld      a,(ix+7)					; Sprite image
        or      %10000000					; Set the flipped bit
        ld      (ix+7),a					; Sprite image
		
		; Move the fireball 1 pixel to the right
        inc     (ix+14)						; Next intended x coordinate
		
		; Jump back up to continue updating the fireball's position
        jp      l33c0
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function moves the fireball up or down the current ladder
; (depending, of course, on which direction the fireball is climbing)
; It does not check if the fireball has reached the top or bottom of the
; ladder - this is handled elsewhere
; passed:	ix - pointer to the current fireball
L_UPDATE_FIREBALL_CLIMB:  
		; Update the fireball's sprite image
		call    L_UPDATE_FIREBALL_SPRITE
		
		; If the fireball is moving down
        ld      a,(ix+13)					; Direction
        cp      8
        jp      nz,l3405
		
		; If the ladder climb counter has not reached 0,
		; jump ahead to decrement it and return
        ld      a,(ix+20)					; Climb update counter
        and     a
        jp      nz,l3401
		
		; Reset the sprite update counter to 2
        ld      (ix+20),2					; Climb update counter
		
		; Move the fireball up 1 pixel
        dec     (ix+15)						; Y coordinate
        ret     
		
		; Decrement the ladder climb counter
l3401:  dec     (ix+20)						; Climb update counter
        ret    
		
		; Move the fireball down 1 pixel
l3405:  inc     (ix+15)						; Y coordinate
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function updates the fireball sprite image, cycling it periodically 
; between the two sprite images for the fireball (either $3d and $3e, or $4d 
; and $4e)
; passed:	ix - pointer to the fireball to process
L_UPDATE_FIREBALL_SPRITE:  
		; If the sprite update counter has not reached 0,
		; jump ahead to decrement it and return
		ld      a,(ix+21)					; The sprite update counter
        and     a
        jp      nz,l3428
        
		; Reset the sprite update counter to 2
		ld      (ix+21),2					; The sprite update counter
        
		; Advance the sprite number
		inc     (ix+7)						; The sprite number
		
		; If the sprite does not need to be wrapped,
		; return
        ld      a,(ix+7)					; The sprite number
        and     %00001111
        cp      $0f
        ret     nz
		
		; Wrap the fireball sprite to the first of the two sprite
		; images (either $3d or $4d)
        ld      a,(ix+7)					; The sprite number
        xor     %00000010
        ld      (ix+7),a					; The sprite number
        ret     

		; Decrement the sprite update counter
l3428:  dec     (ix+21)						; The sprite update counter
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function initializes the current fireball for the barrels stage
; passed:	ix - pointer to the fireball structure to process
L_INIT_FIREBALL_BARRELS:  
		; If the oil barrel jump pointer has not been set,
		; jump ahead to initialize it
		ld      l,(ix+26)					; Oil barrel jump pointer
        ld      h,(ix+27)					; Oil barrel jump pointer
        xor     a							; Clear the carry flag
        ld      bc,0
        adc     hl,bc
        jp      nz,l3442
		
		; Set the oil barrel jump pointer to the beginning of the table
        ld      hl,L_OIL_BARREL_JUMP_TABLE_BARRELS
		
		; Initialize the fireball's x coordinate to 38
        ld      (ix+3),38

		; Move the fireball right 1 pixel
l3442:  inc     (ix+3)
		
		; If the end of the oil barrel jump table has been reached,
		; jump ahead to finish initializing the fireball
l3445:  ld      a,(hl)
        cp      $aa							; End of data
        jp      z,l3456
		
		; Update the fireball's y coordinate
        ld      (ix+5),a
		
		; Advance to the next entry in the oil barrel jump table
        inc     hl
        ld      (ix+26),l
        ld      (ix+27),h
        ret     
		
		; The end of the oil barrel jump table has been reached
		; Initialize the fireball's data
l3456:  xor     a
        ld      (ix+19),a					; Bob table index
        ld      (ix+24),a					; The fireball has now been initialized
        ld      (ix+13),a					; The fireball is standing still
        ld      (ix+28),a					; The fireball is not paused

		; Next intended x and y coordinates equal the current 
		; x and y coordinates
        ld      a,(ix+3)					
        ld      (ix+14),a
        ld      a,(ix+5)
        ld      (ix+15),a
		
		; Clear the oil barrel jump table pointer
        ld      (ix+26),0
        ld      (ix+27),0
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; This function initializes the current fireball for the mixer stage
; passed:	ix - pointer to the fireball structure to process
L_INIT_FIREBALL_MIXER:  
		; If the oil barrel jump pointer has already been initialized,
		; jump ahead to skip initializing it
		ld      l,(ix+26)					; Oil barrel jump index
        ld      h,(ix+27)					; Oil barrel jump index
        xor     a
        ld      bc,0
        adc     hl,bc
        jp      nz,l349a
		
		; Initialize the oil barrel jump pointer to the start of the table
        ld      hl,L_OIL_BARREL_JUMP_TABLE_MIXER
		
		; If Mario is on the left side of the screen, 
		; jump ahead
        ld      a,(MARIO_X)
        bit     7,a
        jp      z,l34a8
		
		; Mario is on the right side of the screen
		; Mark the fireball as moving right
        ld      (ix+13),1
		
		; Fireball x coordinate starts at 126
        ld      (ix+3),126
		
		; If the fireball is moving left,
		; jump ahead
l349a:  ld      a,(ix+13)
        cp      1
        jp      nz,l34b3
		
		; Move the fireball 1 pixel right
        inc     (ix+3)
		
		; Jump up to the barrels stage initialization function
		; to continue the oil barrel jump processing
        jp      l3445
		
		; Mark the fireball as moving left
l34a8:  ld      (ix+13),2

		; Fireball x coordinate starts at 128
        ld      (ix+3),128
		
		; Jump back up to continue the oil barrel jump processing
        jp      l349a
		
		; Move the fireball 1 pixel left
l34b3:  dec     (ix+3)

		; Jump up to the barrels stage initialization function
		; to continue the oil barrel jump processing
        jp      l3445
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initialize the fireball on the rivets stage
; Place it in its initial position
; passed:	ix - the address of the current fireball
L_INIT_FIREBALL_RIVETS:  
		; If the current stage is the elevators stage,
		; return
		; NOTE: This function is only called when the current stage
		;		is elevators or rivets, so the rest of this function
		;		is only run when on the rivets stage
		; NOTE: May be able to save a byte or two by using RST $30
		ld      a,(CURRENT_STAGE)
        cp      3
        ret     z
		
		; If Mario is on the right side of the screen,
		; jump ahead
        ld      a,(MARIO_X)
        bit     7,a
        jp      nz,l34ed
		
		; Mario is on the left side of the screen
		; Pick a random starting location on the right side of
		; the screen
        ld      hl,L_L_RIVET_SPAWN_COORDS
l34ca:  ld      b,0
        ld      a,(COUNTER_1)
        and     %00000110
        ld      c,a							; bc = random offset (multiple of 2)
        add     hl,bc						; hl = random coordinate

		; Set the fireball's coordinate
        ld      a,(hl)
        ld      (ix+3),a					; X coordinate
        ld      (ix+14),a					; Next intended x coordinate
        inc     hl
        ld      a,(hl)
        ld      (ix+5),a					; Y coordinate
        ld      (ix+15),a					; Next intended y coordinate

		; Mark the fireball as standing still
        xor     a							; a = 0
        ld      (ix+13),a					; Fireball direction
		
		; Mark that the fireball has been initialized
        ld      (ix+24),a					; Not initialized
        
		; Clear the pause timer
		ld      (ix+28),a					; Pause timer
        ret     
		
		; Mario is on the right side of the screen
		; Pick a random starting location on the left side of
		; the screen
l34ed:  ld      hl,L_R_RIVET_SPAWN_COORDS
        jp      l34ca
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Copy the data from the fireball data structures to the fireball sprites
L_UPDATE_FIREBALL_SPRITES:  
		ld      hl,FIREBALL_STRUCTS
        ld      de,FIREBALL_SPRITES
        ld      b,5							; 5 fireballs

		; If this fireball is not active,
		; jump ahead to skip
l34fb:  ld      a,(hl)
        and     a
        jp      z,l351e
		
		; Copy the x coordinate to the spirte
        inc     l
        inc     l
        inc     l							; X coordinate
        ld      a,(hl)
        ld      (de),a						; X coordinate

		; Copy the sprite image number to the sprite
        ld      a,4
        add     a,l
        ld      l,a							; Sprite image number
        inc     e							; Sprite image number
        ld      a,(hl)
        ld      (de),a
		
		; Copy the sprite palette to the sprite
        inc     l							; Sprite palette number
        inc     e							; Sprite palette number
        ld      a,(hl)
        ld      (de),a
		
		; Copy the y coordinate to the sprite
        dec     l
        dec     l
        dec     l							; Y coordinate
        inc     e							; Y coordinate
        ld      a,(hl)
        ld      (de),a

		; Advance to the next fireball sprite 
        inc     de
		
		; Advance to the next fireball data structure
l3517:  ld      a,27
        add     a,l
        ld      l,a
		
		; Process the next fireball data structure
        djnz    l34fb						; Next b
        ret     
		
		; Advance to the next fireball data structure and sprite
l351e:  ld      a,5
        add     a,l
        ld      l,a
        ld      a,4
        add     a,e
        ld      e,a
		
		; Jump back to process the next fireball
        jp      l3517
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Points table
; Lists possible points values to award the player
L_POINT_AWARD_TABLE:  .byte	$00, $00, $00	; Entry 0 (000000)
		
        .byte	$00, $01, $00	; Entry 1 (000100)
		
		.byte	$00, $02, $00	; Entry 2 (000200)
		
		.byte	$00, $03, $00	; Entry 3 (000300)
		
		.byte	$00, $04, $00	; Entry 4 (000400)
		
		.byte	$00, $05, $00	; Entry 5 (000500)
		
		.byte	$00, $06, $00	; Entry 6 (000600)
		
		.byte	$00, $07, $00	; Entry 7 (000700)
		
		.byte	$00, $08, $00	; Entry 8 (000800)
		
		.byte	$00, $09, $00	; Entry 9 (000900)
		
		.byte	$00, $00, $00	; Entry 10 (001000)
		
		.byte	$00, $10, $00	; Entry 11 (001100)
		
		.byte	$00, $20, $00	; Entry 12 (001200)
		
		.byte	$00, $30, $00	; Entry 13 (001300)
		
		.byte	$00, $40, $00	; Entry 14 (001400)
		
		.byte	$00, $50, $00	; Entry 15 (001500)
		
		.byte	$00, $60, $00	; Entry 16 (001500)
		
		.byte	$00, $70, $00	; Entry 17 (001700)
		
		.byte	$00, $80, $00	; Entry 18 (001800)
		
		.byte	$00, $90, $00	; Entry 19 (001900)
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Default high score data
; "1ST  007650              "
L_DEFAULT_HIGH_SCORE_DATA:	
L_DEFAULT_HIGH_SCORE_DATA_1:
		.word	TILE_COORD(28,20)	; High score string coordinate

		.byte 	$01, $23, $24, $10, $10, $00, $00, $07, $06, $05, $00, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte 	$3f		; End string
		
		.byte	$00		; High score player ID ($00 = not earned by any current player)
		
		.byte	$50		; High score (007650)
		.byte	$76
		.byte	$00
		
		.word	TILE_COORD(23,20)	; High score coordinate (23, 20)

; 2ND  006100              "
		.word	TILE_COORD(28,22)	; High score string coordinate (28,22)

		.byte	$02, $1E, $14, $10, $10, $00, $00, $06, $01, $00, $00, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte	$3f		; End string
		
		.byte	$00		; High score player ID ($00 = not earned by any current player)
		
		.byte	$00		; High score (006100)
		.byte	$61
		.byte	$00
		
		.word	TILE_COORD(23,22)	; High score coordinate (23,22)

; "3RD  005950              "
		.word	TILE_COORD(28,24)	; High score string coordinate (28,24)

		.byte	$03, $22, $14, $10, $10, $00, $00, $05, $09, $05, $00, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte	$3f		; End string
		
		.byte	$00		; High score player ID ($00 = not earned by any current player)
		
		.byte	$50		; High score (005950)
		.byte	$59
		.byte	$00
		
		.word	TILE_COORD(23,24)	; High score coordinate (23, 24)
		
; "4TH  005050              "
		.word	TILE_COORD(28,26) 	; High score string coordinate (28,26)
		
		.byte	$04, $24, $18, $10, $10, $00, $00, $05, $00, $05, $00, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte	$3f		; End string
		
		.byte	$00		; High score player ID ($00 = not earned by any current player)
		
		.byte	$50		; High score (005050)
		.byte	$50
		.byte	$00

		.word 	TILE_COORD(23,26) 	; High score coordinate (23,26)		

; "5TH  004300              "
		.word	TILE_COORD(28,28) 	; High score string coordinate (28, 28)
		
		.byte	$05, $24, $18, $10, $10, $00, $00, $04, $03, $00, $00, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte	$3f		; End string
		
		
		.byte	$00		; High score player ID ($00 = not earned by any current player)
				
		.byte	$00		; High score (004300)
		.byte	$43
		.byte	$00
		
		.word 	TILE_COORD(23,28) 	; High score coordinate (23, 28)		
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following data is used on the high score initial entry screen to display
; the letter selection box around $eac letter.  Each two byte pair is an x,y
; coordinate.  
; The MSB is the x coordinate and the LSB is the y coordinate.
; Row 1
L_HS_LETTER_COORD_TABLE:	.word	$5c3b	; 'A' = (59,92)
		.word	$5c4b	; 'B' = (75,92)
		.word	$5c5b	; 'C' =
		.word	$5c6b	; 'D' =
		.word	$5c7b	; 'E' =
		.word	$5c8b	; 'F' =
		.word	$5c9b	; 'G' =
		.word	$5cAb	; 'H' =
		.word	$5cBb	; 'I' =
		.word	$5cCb	; 'J' =

; Row 2
		.word	$6c3b	; 'K' =
		.word	$6c4b	; 'L' =
		.word	$6c5b	; 'M' =
		.word	$6c6b	; 'N' =
		.word	$6c7b	; 'O' =
		.word	$6c8b	; 'P' =
		.word	$6c9b	; 'Q' =
		.word	$6cAb	; 'R' =
		.word	$6cBb	; 'S' =
		.word	$6cCb	; 'T' =

; Row 3
		.word	$7c3b	; 'U' =
		.word	$7c4b	; 'V' =
		.word	$7c5b	; 'W' =
		.word	$7c6b	; 'X' =
		.word	$7c7b	; 'Y' =
		.word	$7c8b	; 'Z' =
		.word	$7c9b	; '.' =
		.word	$7cAb	; '-' =
		.word	$7cBb	; 'RUB' =
		.word	$7cCb	; 'END' =
;------------------------------------------------------------------------------

		
;------------------------------------------------------------------------------
; String table
; Strings are looked up by index number and a memory location is returned 
L_STRING_TABLE:	
		.word	L_GAME_OVER_STRING_DATA 	; 0 = "GAME OVER"
		.word	1 		; unused
		.word	L_PLAYER_1_STRING_DATA 	; 2 = "PLAYER (I)"
		.word	L_PLAYER_2_STRING_DATA 	; 3 = "PLAYER (II)"
		.word	L_HIGH_SCORE_STRING_DATA 	; 4 = "HIGH SCORE"
		.word	L_CREDIT_STRING_DATA 	; 5 = "CREDIT    "
		.word	6 		; unused
		.word	L_HOW_HIGH_STRING_DATA 	; 7 = "HOW HIGH CAN YOU GET ? "
		.word	8 		; unused
		.word	L_ONLY_1_STRING_DATA 	; 9 = "ONLY 1 PlAYER BUTTON"
		.word	L_1_OR_2_STRING_DATA 	; 10 = "1 OR 2 PLAYERS BUTTON"
		.word	11		; unused
		.word	L_PUSH_STRING_DATA 	; 12 = "PUSH"
		.word	L_REGIS_STRING_DATA 	; 13 = "NAME REGISTRATION"
		.word	L_NAME_STRING_DATA 	; 14 = "NAME:"
		.word	L_UNDERLINE_STRING_DATA 	; 15 = "---         "
		.word	L_A_TO_J_STRING_DATA 	; 16 = "A B C D E F G H I J"
		.word	L_K_TO_T_STRING_DATA 	; 17 = "K L M N O P Q R S T"
		.word	L_U_TO_END_STRING_DATA 	; 18 = "U V W X Y Z . -RUBEND "
		.word	L_REGI_TIME_STRING_DATA 	; 19 = "REGI TIME  (30) "
		.word	HIGH_SCORE_TABLE_ENTRY_1 ; 20 = HIGH_SCORE_TABLE_ENTRY_1
		.word	HIGH_SCORE_TABLE_ENTRY_2 ; 21 = HIGH_SCORE_TABLE_ENTRY_2
		.word	HIGH_SCORE_TABLE_ENTRY_3 ; 22 = HIGH_SCORE_TABLE_ENTRY_3
		.word	HIGH_SCORE_TABLE_ENTRY_4 ; 23 = HIGH_SCORE_TABLE_ENTRY_4
		.word	HIGH_SCORE_TABLE_ENTRY_5 ; 24 = HIGH_SCORE_TABLE_ENTRY_5
		.word	l379e 	; 25 = "RANK  SCORE  NAME    "
		.word	l37b6 	; 26 = "YOUR NAME WAS REGISTERED."
		.word	l37d2 	; 27 = "INSERT COIN "
		.word	l37e1 	; 28 = "  PLAYER    COIN"
		.word	29		; unused
		.word	L_1981_STRING_DATA 	; 30 = "1981"
		.word	L_NINTENDO_STRING_DATA 	; 31 = "NINTENDO OF AMERICA"
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Static strings
; "GAME  OVER" 
L_GAME_OVER_STRING_DATA: 	
		.word	TILE_COORD(20,22) 	; (20, 22) 
		.byte	$17, $11, $1d, $15, $10, $10, $1f, $26, $15, $22
		.byte	$3f		; End string
		
; "PLAYER (I)" 
L_PLAYER_1_STRING_DATA: 	
		.word	TILE_COORD(20,20) 	; (20, 20)
		.byte	$20, $1C, $11, $29, $15, $22, $10, $30, $32, $31
		.byte	$3F
				
; "PLAYER (II)"
L_PLAYER_2_STRING_DATA: 	
		.word   TILE_COORD(20,20)	; (20, 20)
		.byte	$20, $1C, $11, $29, $15, $22, $10, $30, $33, $31
		.byte	$3F
				
; "HIGH SCORE" 
L_HIGH_SCORE_STRING_DATA: 	
		.word   TILE_COORD(20,0)	; (20, 0)  
		.byte	$18, $19, $17, $18, $10, $23, $13, $1F, $22, $15
		.byte	$3F
				
; "CREDIT    "
L_CREDIT_STRING_DATA: 	
		.word   TILE_COORD(12,31) 	; (12, 31)
		.byte	$13, $22, $15, $14, $19, $24, $10, $10, $10, $10
		.byte	$3F
				
; "HOW HIGH CAN YOU GET ? "
L_HOW_HIGH_STRING_DATA: 	
		.word   TILE_COORD(26,30)	; (25, 31)
		.byte	$18, $1F, $27, $10, $18, $19, $17, $18, $10, $13, $11, $1E, $10, $29, $1F, $25, $10, $17, $15, $24, $10, $FB, $10
		.byte	$3F
				
; "ONLY 1 PlAYER BUTTON"
L_ONLY_1_STRING_DATA: 	
		.word   TILE_COORD(25,9)	; (25, 9)
		.byte	$1F, $1E, $1C, $29, $10, $01, $10, $20, $1C, $11, $29, $15, $22, $10, $12, $25, $24, $24, $1F, $1E
		.byte	$3F
				
; "1 OR 2 PLAYERS BUTTON"
L_1_OR_2_STRING_DATA: 	
		.word   TILE_COORD(25,9)	; (25, 9)
		.byte	$01, $10, $1F, $22, $10, $02, $10, $20, $1C, $11, $29, $15, $22, $23, $10, $12, $25, $24, $24, $1F, $1E
		.byte	$3F
				
; "PUSH"
L_PUSH_STRING_DATA: 	
		.word   TILE_COORD(17,7)	; (17, 7)
		.byte	$20, $25, $23, $18
		.byte	$3F
		
; "NAME REGISTRATION"
L_REGIS_STRING_DATA: 	
		.word   TILE_COORD(24,6)	; (24, 6)
		.byte	$1E, $11, $1D, $15, $10, $22, $15, $17, $19, $23, $24, $22, $11, $24, $19, $1F, $1E
		.byte	$3F
		
; "NAME:"
L_NAME_STRING_DATA: 	
		.word   TILE_COORD(20,8)	; (20, 8)
		.byte	$1E, $11, $1D, $15, $2E
		.byte	$3F
				
; "---         " ('-''s are underlines)
L_UNDERLINE_STRING_DATA: 	
		.word   TILE_COORD(15,9)	; (15, 9)
		.byte	$2D, $2D, $2D, $10, $10, $10, $10, $10, $10, $10, $10, $10
		.byte	$3F
				
; "A B C D E F G H I J"
L_A_TO_J_STRING_DATA: 	
		.word   TILE_COORD(24,11)	; (24, 11)
		.byte	$11, $10, $12, $10, $13, $10, $14, $10, $15, $10, $16, $10, $17, $10, $18, $10, $19, $10, $1A
		.byte	$3F
		
; "K L M N O P Q R S T"
L_K_TO_T_STRING_DATA: 	
		.word   TILE_COORD(24,13)	; (24, 13)
		.byte	$1B, $10, $1C, $10, $1D, $10, $1E, $10, $1F, $10, $20, $10, $21, $10, $22, $10, $23, $10, $24
		.byte	$3F
				
; "U V W X Y Z . -RUBEND "
L_U_TO_END_STRING_DATA: 	
		.word   TILE_COORD(24,15)	; (24, 15)
		.byte	$25, $10, $26, $10, $27, $10, $28, $10, $29, $10, $2A, $10, $2B, $10, $2C, $44, $45, $46, $47, $48, $10
		.byte	$3F
				
; "REGI TIME  (30) "
L_REGI_TIME_STRING_DATA: 	
		.word   TILE_COORD(23,18)	; (23, 18)
		.byte	$22, $15, $17, $19, $10, $24, $19, $1D, $15, $10, $10, $30, $03, $00, $31, $10
		.byte	$3F
				
; "RANK  SCORE  NAME    "
l379e: 	
		.word   TILE_COORD(28,18)	; (28, 18)
		.byte	$22, $11, $1E, $1B, $10, $10, $23, $13, $1F, $22, $15, $10, $10, $1E, $11, $1D, $15, $10, $10, $10, $10
		.byte	$3F
		
; "YOUR NAME WAS REGISTERED."
l37b6: 	
		.word   TILE_COORD(27,18)	; (27, 18)
		.byte	$29, $1F, $25, $22, $10, $1E, $11, $1D, $15, $10, $27, $11, $23, $10, $22, $15, $17, $19, $23, $24, $15, $22, $15, $14, $42
		.byte	$3F
		
; "INSERT COIN "
l37d2: 	
		.word   TILE_COORD(21,7)	; (21, 7)
		.byte	$19, $1E, $23, $15, $22, $24, $10, $13, $1F, $19, $1E, $10
		.byte	$3F
				
; "  PLAYER    COIN"
l37e1: 	
		.word   TILE_COORD(24,10)	; (24, 10)
		.byte	$10, $10, $20, $1C, $11, $29, $15, $22, $10, $10, $10, $10, $13, $1F, $19, $1E
		.byte	$3F
				
; "© NINTENDO    "
l37f4: 	
		.word   TILE_COORD(23,28)	; (23, 28)
		.byte	$49, $4A, $10, $1E, $19, $1E, $24, $15, $1E, $14, $1F, $10, $10, $10, $10
		.byte	$3F
				
; "1981"
l3806: 	
		.word   TILE_COORD(11,28)	; (11, 28)
		.byte	$01, $09, $08, $01
		.byte	$3F
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Introduction stage data
; (This is essentially the barrels level before Donkey Kong stomps and warps
; it)
L_INTRO_STAGE_DATA: 	
		; Pauline's platform
		.byte	$02		; Barrels girders
		.word	$3897	; (18,7) offset 0
		.word	$3868	; (13,7) offset 0

		; 5th platform		
		.byte	$02		; Barrels girders
		.word	$54DF	; (27,10) offset 4
		.word	$5410	; (2,10) offset 4
		
		; 4th platform
		.byte	$02		; Barrels girders
		.word	$6DEF	; (29,13) offset 5
		.word	$6D20	; (4,13) offset 5
		
		; 3rd platform
		.byte	$02		; Barrels girders
		.word	$8EDF	; (27,17) offset 6
		.word	$8E10	; (2,17) offset 6
		
		; 2nd platform
		.byte	$02		; Barrels girders
		.word	$AFEF	; (29,21) offset 7
		.word	$AF20	; (4,21) offset 7
		
		; 1st platform
		.byte	$02		; Barrels girders
		.word	$D0DF	; (27,26) offset 0
		.word	$D010	; (2,26) offset 0

		; Floor		
		.byte	$02		; Barrels girders
		.word	$F1EF	; (29,30) offset 1
		.word	$F110	; (4,30) offset 1
		
		.byte	$00		; Ladder
		.word	$1853	; (10,3) offset 0
		.word	$5453	; (10,10) offset 4
		
		.byte	$00		; Ladder
		.word	$1863	; (12,3) offset 0
		.word	$5463	; (12,10) offset 4
		
		.byte	$00		; Ladder
		.word	$3893	; (18,7) offset 0
		.word	$5493	; (18,10) offset 4
		
		.byte	$00		; Ladder
		.word	$5483	; (16,10) offset 4
		.word	$F183	; (16,30) offset 1
		
		.byte	$00		; Ladder
		.word	$5493	; (18,10) offset 4
		.word	$F193	; (18,30) offset 1
		
		.byte   $aa		; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The characters that make up the timer display
;					|BONUS|
;					|0000 |
;					 -----
L_TIMER_BOX_TILE_DATA: 	
		.byte   $8D     ; upper-right corner
		.byte   $7D 	; right edge
		.byte   $8C 	; lower-right corner
		.byte   $6F 	; top edge
		.byte   $00 	; '0'
		.byte   $7C 	; bottom edge
		.byte   $6E 	; top edge
		.byte   $00 	; '0'
		.byte   $7C 	; bottom edge
		.byte   $6D 	; top edge
		.byte   $00 	; '0'
		.byte   $7C 	; bottom edge
		.byte   $6C 	; top edge
		.byte   $00 	; '0'
		.byte   $7C 	; bottom edge
		.byte   $8F 	; upper-left corner
		.byte   $7F 	; left edge
		.byte   $8E 	; lower-left corner
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong standing with his left arm raised
L_DK_SPRITES_L_ARM_RAISED:	
		.byte	$47		; DK front right leg 
		.byte	$27
		.byte	$08
		.byte	$50
		
		.byte	$2F		; DK front left leg (flipped h.)
		.byte	$A7 
		.byte	$08 
		.byte	$50 
		
		.byte	$3B		; DK front chest
		.byte	$25 
		.byte	$08 
		.byte	$50 
		
		.byte	$00		; unused
		.byte	$70 
		.byte	$08 
		.byte	$48 
		
		.byte	$3B		; DK front head
		.byte	$23		; Mouth closed 
		.byte	$07 
		.byte	$40 
		
		.byte	$46		; DK front left arm (flipped h.)
		.byte	$A9		; ($29 - right arm lowered and curled)
		.byte	$08 
		.byte	$44 
		
		.byte	$00		; unused
		.byte	$70 
		.byte	$08 
		.byte	$48 
		
		.byte	$30		; DK front right arm
		.byte	$29 
		.byte	$08 
		.byte	$44 
		
		.byte	$00		; unused
		.byte	$70 
		.byte	$08 
		.byte	$48 
		
		.byte	$00		; unused
		.byte	$70 
		.byte	$0A 
		.byte	$48 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Pauline standing, facing right
L_PAULINE_SPRITES_FACE_RIGHT:	
		.byte	$6F
		.byte	$10		; $10 (Pauline's head facing right) 
		.byte	$09 
		.byte	$23 
		
		.byte	$6F
		.byte	$11		; $11 (Pauline's body facing right) 
		.byte	$0A 
		.byte	$33 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong climbing
L_DK_SPRITES_CLIMBING:	
		.byte	$50		; DK Left Arm
		.byte	$34 
		.byte	$08 
		.byte	$3C 
		
		.byte	$00		; DK Right Arm (hidden initially)
		.byte	$35 
		.byte	$08 
		.byte	$3C 
		
		.byte	$53		; DK Left Head
		.byte	$32 
		.byte	$08 
		.byte	$40 
		
		.byte	$63		; DK Right Head
		.byte	$33 
		.byte	$08 
		.byte	$40 
		
		.byte	$00		; 
		.byte	$70 
		.byte	$08 
		.byte	$48 
		
		.byte	$53		; DK Left Leg
		.byte	$36 
		.byte	$08 
		.byte	$50 
		
		.byte	$63		; DK Right Leg
		.byte	$37 
		.byte	$08 
		.byte	$50 
		
		.byte	$6B		; DK Right Arm carrying Pauline
		.byte	$31 
		.byte	$08 
		.byte	$41 
		
		.byte	$00		; 
		.byte	$70 
		.byte	$08 
		.byte	$48 
		
		.byte	$6A		; Pauline being carried
		.byte	$14 
		.byte	$0A 
		.byte	$48 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing Donkey Kong's jump from the top of the ladders onto the top
; platform on the intro screen
L_DK_JUMP_FROM_LADDER_DATA:	
		.byte	-3, -3, -3, -3, -3, -3, -3
		.byte	-2, -2, -2, -2, -2, -2
		.byte	-1, -1, -1, -1
		.byte	 0,  0
		.byte	 1,  1,  1
		.byte	$7F 	; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing Donkey Kong's jumps across the top platform in the intro
; screen
L_DK_JUMP_ACROSS_PLAT_DATA:	
		.byte	-1, -1, -1, -1, -1,  0, -1,  0
		.byte	 0,  1,  0,  1,  1,  1,  1,  1
		.byte	$7f		; End of data

;------------------------------------------------------------------------------
		
		
		
;------------------------------------------------------------------------------
l38dc:	
		; First set of deformation data
		.byte	$04		; Blank tiles
		.word	$F07F	; (15,30)
		.word	$F010	; (2,30)
		     
		.byte	$02		; Barrel girders
		.word	$F2DF	; (27,30) offset 2
		.word	$F870	; (14,31) offset 0
		
		.byte	$02		; Barrel girders
		.word	$F86F	; (13,14) offset 0
		.word	$F810	; (2,14) offset 0
		
		.byte	$AA		; End of data
		
		
		; Second set of deformation data
		.byte	$04		; Blank tiles
		.word	$D0DF	; (27,26)
		.word	$D090	; 18,26)
		
		.byte	$02		; Barrel girders
		.word	$DCDF	; (27,27) offset 4
		.word	$D120	; (4,26) offset 1
		
		.byte	$AA		; End of data
		
		.byte	$FF, $FF, $FF, $FF, $FF	; Filler
		
		
		; Third set of deformation data
		.byte	$04		; Blank tiles
		.word	$A8DF	; (27,21)
		.word	$A820	; (4,21)
		
		.byte	$04		; Blank tiles
		.word	$B05F	; (11,22)
		.word	$B020	; (21,22)
		
		.byte	$02		; Barrel girders
		.word	$B0DF	; (27,22) offset 0
		.word	$BB20	; (21,23) offset 3
		
		.byte	$AA		; End of data
		
		
		; Fourth set of deformation data
		.byte	$04		; Blank tiles
		.word	$88DF	; (27,17)
		.word	$8830	; (6,17)
		
		.byte	$04		; Blank tiles
		.word	$90DF	; (27,18)
		.word	$90B0	; (27,18)
		
		.byte	$02		; Barrel girders
		.word	$9ADF	; (27,19) offset 2
		.word	$8F20	; (21,17) offset 7
		
		.byte	$AA		; End of data
		
		
		; Fifth set of deformation data
		.byte	$04		; Blank tiles
		.word	$68BF	; (23,13)
		.word	$6820	; (21,13)
		
		.byte	$04		; Blank tiles
		.word	$703F	; (7,14)
		.word	$7020	; (21,14)
		
		.byte	$02		; Barrel girders
		.word	$6EDF	; (27,13) offset 6
		.word	$7920	; (21,15) offset 1
		
		.byte	$AA		; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data defining the sloped portion of the 6th platform on the intro and barrels
; stage
L_INTRO_DATA_SLOPE6: 	
		.byte	$02	; Barrels girder
		.word	$58DF	; (27,11) offset 0
		.word	$55A0	; (20,10) offset 5
		.byte	$AA	; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong facing right, left arm reaching out
L_DK_SPRITES_THROW_BARREL: 	
		.byte	$00		; x coord 
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$2B		; x coord 
		.byte	$AC		; sprite number ($2c - left leg back)
		.byte	$08		; palette 
		.byte	$4C		; y coord
		
		.byte	$3B		; x coord 
		.byte	$AE		; sprite number ($2e - body sideways)
		.byte	$08		; palette 
		.byte	$4C		; y coord 
		
		.byte	$3B		; x coord 
		.byte	$AF		; sprite number ($2f - back sideways)
		.byte	$08		; palette 
		.byte	$3C		; y coord
		
		.byte	$4B		; x coord 
		.byte	$B0		; sprite number ($30 - head sideways)
		.byte	$07		; palette 
		.byte	$3C		; y coord
		
		.byte	$4B		; x coord 
		.byte	$AD		; sprite number ($2d - head sideways)
		.byte	$08		; palette 
		.byte	$4C		; y coord
		
		.byte	$00		; x coord 
		.byte	$70		; sprite number 
		.byte	$08		; palette 
		.byte	$44		; y coord 
		
		.byte	$00		; x coord 
		.byte	$70		; sprite number 
		.byte	$08		; palette 
		.byte	$44		; y coord 
		
		.byte	$00		; x coord 
		.byte	$70		; sprite number 
		.byte	$08		; palette 
		.byte	$44		; y coord 
		
		.byte	$00		; x coord 
		.byte	$70		; sprite number 
		.byte	$0A		; palette 
		.byte	$44		; y coord 
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong standing with arms down
L_DK_SPRITES_ARMS_DOWN:	
		.byte	$47		; x coord 
		.byte	$27		; sprite number ($27 - left leg)
		.byte	$08		; palette 
		.byte	$4C		; y coord
		
		.byte	$2F		; x coord 
		.byte	$A7		; sprite number ($27 - right leg)
		.byte	$08		; palette 
		.byte	$4C		; y coord
		
		.byte	$3B		; x coord
		.byte	$25		; sprite number ($25 - torso)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$3B		; x coord
		.byte	$23		; sprite number ($23 - face frowning)
		.byte	$07		; palette
		.byte	$3C		; y coord
		
		.byte	$4B		; x coord
		.byte	$2A		; sprite number ($2a - right shoulder)
		.byte	$08		; palette
		.byte	$3C		; y coord
		
		.byte	$4B		; x coord
		.byte	$2B		; sprite number ($2b - right arm)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$2B		; x coord
		.byte	$AA		; sprite number ($2a - left shoulder)
		.byte	$08		; palette
		.byte	$3C		; y coord
		
		.byte	$2B		; x coord
		.byte	$AB		; sprite number ($2b - left arm)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$0A		; palette
		.byte	$44		; y coord
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Sprite data for Donkey Kong
L_DK_SPRITES_GRAB_BARREL:	
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$4B		; x coord
		.byte	$2C		; sprite number ($2c - left leg back)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$3B		; x coord
		.byte	$2E		; sprite number  ($2e - torso)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$3B		; x coord
		.byte	$2F		; sprite number ($2f - back)
		.byte	$08		; palette
		.byte	$3C		; y coord
		
		.byte	$2B		; x coord
		.byte	$30		; sprite number ($30 - head facing left)
		.byte	$07		; palette
		.byte	$3C		; y coord
		
		.byte	$2B		; x coord
		.byte	$2D		; sprite number ($2d - right leg, left arm forward, reaching)
		.byte	$08		; palette
		.byte	$4C		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$08		; palette
		.byte	$44		; y coord
		
		.byte	$00		; x coord
		.byte	$70		; sprite number
		.byte	$0A		; palette
		.byte	$44		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Vector data describing the bounce of the springs on the elevators stage
L_SPRING_VECTOR_DATA:	
		.byte	-3, -3, -3, -2, -2, -2, -2, -1, -1,  0, -1,  0 ; Rising
		.byte	 0,  1,  0,  1,  1,  2,  2,  2,  2,  3,  3,  3 ; Falling
		.byte	127 ; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l39c3:	
		.byte	$1E
		.byte	$4E
		.byte	$BB
		.byte	$4C
		.byte	$D8
		.byte	$4e
        .byte	$59
        .byte	$4e
        .byte	127 ; End of data
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
l39cc:  .byte   $bb
        .byte   $4d
        .byte   $7f
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong standing grinning with his right leg and left
; arm raised.
L_DK_SPRITES_GRIN_L_STOMP: 	
		.byte	$47		; x coord
		.byte	$27		; sprite number ($27 - left leg)
		.byte	$08		; palette 
		.byte	$50		; y coord 
		
		.byte	$2D		; x coord 
		.byte	$26		; sprite number ($26 - right leg raised)
		.byte	$08		; palette
		.byte	$50		; y coord
		
		.byte	$3B		; x coord
		.byte	$25		; sprite number ($25 - torso)
		.byte	$08		; palette
		.byte	$50		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$3B 	; x coord
		.byte	$24 	; sprite number ($24 - head - grinning)
		.byte	$07 	; palette
		.byte	$40 	; y coord
		
		.byte	$4B 	; x coord
		.byte	$28 	; sprite number ($28 - left arm raised)
		.byte	$08 	; palette
		.byte	$40 	; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$30 	; x coord
		.byte	$29 	; sprite number ($29 - right arm curled)
		.byte	$08 	; palette
		.byte	$44		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$0A 	; palette
		.byte	$48		; y coord
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Sprite data for Donkey Kong standing grinning with his left leg and right
; arm raised.
L_DK_SPRITES_GRIN_R_STOMP:	
		.byte	$49 	; x coord
		.byte	$A6 	; sprite number ($26 - left leg)
		.byte	$08 	; palette
		.byte	$50		; y coord
		
		.byte	$2F 	; x coord
		.byte	$A7 	; sprite number	($27 - right leg raised)
		.byte	$08 	; palette
		.byte	$50		; y coord
		
		.byte	$3B 	; x coord
		.byte	$25 	; sprite number ($25 - torso)
		.byte	$08 	; palette
		.byte	$50		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$3B 	; x coord
		.byte	$24 	; sprite number ($24 - head grinning)
		.byte	$07 	; palette
		.byte	$40		; y coord
		
		.byte	$46 	; x coord
		.byte	$A9 	; sprite number ($29 - left arm curled)
		.byte	$08 	; palette
		.byte	$44		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$2B 	; x coord
		.byte	$A8 	; sprite number ($28 - right arm raised)
		.byte	$08 	; palette
		.byte	$40		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$08 	; palette
		.byte	$48		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$0A 	; palette
		.byte	$48		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for Donkey Kong grinning and falling upside-down
L_DK_SPRITES_GRIN_UD:	
		.byte	$73 	; x coord
		.byte	$A7 	; sprite number ($27 - leg)
		.byte	$88 	; palette
		.byte	$60		; y coord
		
		.byte	$8B 	; x coord
		.byte	$27 	; sprite number ($27 - leg)
		.byte	$88 	; palette
		.byte	$60		; y coord
		
		.byte	$7F 	; x coord
		.byte	$25 	; sprite number ($25 - torso)
		.byte	$88 	; palette
		.byte	$60		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$88 	; palette
		.byte	$68		; y coord
		
		.byte	$7F 	; x coord
		.byte	$24 	; sprite number ($24 - head grinning)
		.byte	$87 	; palette
		.byte	$70		; y coord
		
		.byte	$74 	; x coord
		.byte	$29 	; sprite number ($29 - arm curled)
		.byte	$88 	; palette
		.byte	$6C		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$88 	; palette
		.byte	$68		; y coord
		
		.byte	$8A 	; x coord
		.byte	$A9 	; sprite number ($29 - arm curled)
		.byte	$88 	; palette
		.byte	$6C		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$88 	; palette
		.byte	$68		; y coord
		
		.byte	$00 	; x coord
		.byte	$70 	; sprite number
		.byte	$8A 	; palette
		.byte	$68		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing how to draw the first fallen platform on the pies level when
; the stage has has been completed
L_RIVETS_DATA_FALL1: 	
		.byte	$05 	; Girders with circular holes
		.word	$F0AF	; (21,30)
		.word	$F050	; (10,30)
		.byte	$AA	; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing how to draw the second fallen platform on the pies level when
; the stage has has been completed
L_RIVETS_DATA_FALL2:	
		.byte	$05 	; Girders with circular holes
		.word	$E8AF	; (21,29)
		.word	$E850	; (10,29)
		.byte	$AA	; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing how to draw the third fallen platform on the pies level when
; the stage has has been completed
L_RIVETS_DATA_FALL3:	
		.byte	$05 	; Girders with circular holes
		.word	$E0AF	; (21,28)
		.word	$E050	; (10,28)
		.byte	$AA	; End of data
;------------------------------------------------------------------------------

				

;------------------------------------------------------------------------------
; Data describing how to draw the fourth fallen platform on the pies level when
; the stage has has been completed
L_RIVETS_DATA_FALL4:	
		.byte	$05 	; Girders with circular holes
		.word	$D8AF	; (21,27)
		.word	$D850	; (10,27)
		.byte	$AA	; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Data describing how to draw the top fallen platform on the pies level when
; the stage has has been completed		
L_RIVETS_DATA_FALL_TOP:	
		.byte	$05 	; Girders with circular holes
		.word	$58B7	; (22,11)
		.word	$5848	; (9,11)
		.byte	$AA	; End of data
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Table defining the stages and the order they will appear in each level
; Level 1
L_STAGE_ORDER_TABLE: 	
		.byte	1, 4				; Barrels, Rivets
		
; Level 2	
		.byte	1, 3, 4				; Barrels, Elevators, Rivets

; Level 3
		.byte	1, 2, 3, 4			; Barrels, Mixer, Elevators, Rivets
		
; Level 4
		.byte	1, 2, 1, 3, 4		; Barrels, Mixer, Barrels, Elevators, Rivets

; Level 5+		
L_STAGE_ORDER_TABLE_LAST: 	
		.byte	1, 2, 1, 3, 1, 4	; Barrels, Mixer, Barrels, Elevators, Barrels, Rivets

		.byte	$7F		; End of data marker
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The fireballs in the game don't just move left and right, they
; bob up and down as they do it, so they look more like real fire
; as they travel.  The following table controls this behavior.
L_FIREBALL_BOB_TABLE:	
		.byte	-1        
		.byte	 0        
		.byte	-1        
		.byte	-1        
		.byte	-2
		.byte	-2      
		.byte	-2
		.byte	-2
		.byte	-2
		.byte	-2
		.byte	-2
		.byte	-2      
		.byte	-2
		.byte	-2      
		.byte	-2
		.byte	-1      
		.byte	-1        
		.byte	 0   
FIREBALL_BOB_TABLE_LENGTH = $ - L_FIREBALL_BOB_TABLE
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; The following data contains the y coordinates for the fireballs as they first 
; jump out of the oil barrel on the barrels stage
L_OIL_BARREL_JUMP_TABLE_BARRELS:	
		.byte	232        
		.byte	229        
		.byte	227        
		.byte	226
		.byte	225
		.byte	224    
		.byte	223        
		.byte	222
		.byte	221      
		.byte	221
		.byte	220
		.byte	220
		.byte	220  
		.byte	220
		.byte	220
		.byte	220    
		.byte	221
		.byte	221
		.byte	222
		.byte	223  
		.byte	224        
		.byte	225        
		.byte	226
		.byte	227
		.byte	228    
		.byte	229        
		.byte	231        
		.byte	233        
		.byte	235        
		.byte	237
		.byte	240     
		.byte	$aa							; End of data        
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following data contains the y coordinates for the fireballs as they first 
; jump out of the oil barrel on the barrels stage
L_OIL_BARREL_JUMP_TABLE_MIXER:	
		.byte	128        
		.byte	123        
		.byte	120        
		.byte	118        
		.byte	116        
		.byte	115        
		.byte	114       
		.byte	113        
		.byte	112        
		.byte	112        
		.byte	111        
		.byte	111        
		.byte	111        
		.byte	112        
		.byte	112        
		.byte	113        
		.byte	114        
		.byte	115        
		.byte	116        
		.byte	117        
		.byte	118        
		.byte	119        
		.byte	120        
		.byte	$aa							; End of data        
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The spawning coordinates for fireballs appearing on the right side of the 
; screen on the rivets stage
; NOTE: x,y are reversed?
L_L_RIVET_SPAWN_COORDS:	
		.word	TWO_BYTES(240,238)
		.word	TWO_BYTES(160,219) 
		.word	TWO_BYTES(200,230)
		.word	TWO_BYTES(120,214)    
		.word	TWO_BYTES(240,235)      
		.word	TWO_BYTES(160,219)  
		.word	TWO_BYTES(200,230)
		.word	TWO_BYTES(200,230)  
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The spawning coordinates for fireballs appearing on the left side of the 
; screen on the rivets stage
; NOTE: x,y are reversed?
L_R_RIVET_SPAWN_COORDS:	
		.word	TWO_BYTES(200,27)    
		.word	TWO_BYTES(160,35)     
		.word	TWO_BYTES(120,43)      
		.word	TWO_BYTES(240,18)      
		.word	TWO_BYTES(200,27)     
		.word	TWO_BYTES(160,35)     
		.word	TWO_BYTES(240,18)    
		.word	TWO_BYTES(200,27)
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Stage data for the barrels stage
L_BARRELS_STAGE_DATA:	
		.byte	$02 	; tile type
		.word	$3897 	; coord 1 (13,7)
		.word	$3868 	; coord 2 (18,7)
		
		.byte	$02 	; tile type
		.word	$549F 	; coord 1 (12,10)
		.word	$5410 	; coord 2 (29,10)
		
		.byte	$02 	; tile type
		.word	$58DF 	; coord 1 (4,11)
		.word	$55A0 	; coord 2 (11,10)
		
		.byte	$02 	; tile type
		.word	$6DEF 	; coord 1 (2,13)
		.word	$7920 	; coord 2 (27,15)
		
		.byte	$02 	; tile type
		.word	$9ADF 	; coord 1 (4, 19)
		.word	$8E10 	; coord 2 (29,17)
		
		.byte	$02 	; tile type
		.word	$AFEF 	; coord 1 (2,21)
		.word	$BB20 	; coord 2 (27,23)
		
		.byte	$02 	; tile type
		.word	$DCDF 	; coord 1 (4,27)
		.word	$D010 	; coord 2 (29,26)
		
		.byte	$02 	; tile type
		.word	$F0FF 	; coord 1 (0,30)
		.word	$F780 	; coord 2 (15,30)
		
		.byte	$02 	; tile type
		.word	$F87F 	; coord 1 (16,31)
		.word	$F800 	; coord 2 (31,31)
		
		.byte	$00 
		.word	$57CB 
		.word	$6FCB 
		
		.byte	$00 
		.word	$99CB 
		.word	$B1CB 
		
		.byte	$00 
		.word	$DBCB 
		.word	$F3CB 
		
		.byte	$00 
		.word	$1863 
		.word	$5463 
		
		.byte	$01 
		.word	$D563 
		.word	$F863 
		
		.byte	$00 
		.word	$7833 
		.word	$9033 
		
		.byte	$00 
		.word	$BA33 
		.word	$D233 
		
		.byte	$00 
		.word	$1853 
		.word	$5453 
		
		.byte	$01 
		.word	$9253 
		.word	$B853 
		
		.byte	$00 
		.word	$765B 
		.word	$925B 
		
		.byte	$00 
		.word	$B673 
		.word	$D673 
		
		.byte	$00 
		.word	$9583 
		.word	$B583 
		
		.byte	$00 
		.word	$3893 
		.word	$5493 
		
		.byte	$01 
		.word	$70BB 
		.word	$98BB 
		
		.byte	$01 
		.word	$546B 
		.word	$756B 
		
		.byte	$AA		; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Stage data for the mixer stage
L_MIXER_STAGE_DATA: 	
		.byte	$06 
		.word	$908F 
		.word	$9070
		
		.byte	$06 
		.word	$988F 
		.word	$9870
		
		.byte	$06 
		.word	$A08F 
		.word	$A070
		
		.byte	$00 
		.word	$1863 
		.word	$5863
		
		.byte	$00 
		.word	$8063 
		.word	$A863
		
		.byte	$00 
		.word	$D063 
		.word	$F863
		
		.byte	$00 
		.word	$1853 
		.word	$5853
		
		.byte	$00 
		.word	$A853 
		.word	$D053
		
		.byte	$00 
		.word	$809B 
		.word	$A89B
		
		.byte	$00 
		.word	$D09B 
		.word	$F89B
		
		.byte	$01 
		.word	$5823 
		.word	$8023
		
		.byte	$01 
		.word	$58DB 
		.word	$80DB
		
		.byte	$00 
		.word	$802B 
		.word	$A82B
		
		.byte	$00 
		.word	$80D3 
		.word	$A8D3
		
		.byte	$00 
		.word	$A8A3 
		.word	$D0A3
		
		.byte	$00 
		.word	$D02B 
		.word	$F82B
		
		.byte	$00 
		.word	$D0D3 
		.word	$F8D3
		
		.byte	$00 
		.word	$3893 
		.word	$5893
		
		.byte	$02 
		.word	$3897 
		.word	$3868
		
		.byte	$03 
		.word	$58EF 
		.word	$5810
		
		.byte	$03 
		.word	$80F7 
		.word	$8088
		
		.byte	$03 
		.word	$8077 
		.word	$8008
		
		.byte	$02 
		.word	$A8A7 
		.word	$A850
		
		.byte	$02 
		.word	$A8E7 
		.word	$A8B8
		
		.byte	$02 
		.word	$A83F 
		.word	$A818
		
		.byte	$03 
		.word	$D0EF 
		.word	$D010
		
		.byte	$02 
		.word	$F8EF 
		.word	$F810
		
		.byte	$aa		; End of data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Stage data for the elevators stage
L_ELEVATORS_STAGE_DATA:
		.byte	$00 
		.word	$1863 
		.word	$5863
		
		.byte	$00 
		.word	$8863 
		.word	$D063
		
		.byte	$00 
		.word	$1853 
		.word	$5853
		
		.byte	$00 
		.word	$8853 
		.word	$D053
		
		.byte	$00 
		.word	$68E3 
		.word	$90E3
		
		.byte	$00 
		.word	$B8E3 
		.word	$D0E3
		
		.byte	$00 
		.word	$90CB 
		.word	$B0CB
		
		.byte	$00 
		.word	$58B3 
		.word	$78B3
		
		.byte	$00 
		.word	$809B 
		.word	$A09B
		
		.byte	$00 
		.word	$3893 
		.word	$5893
		
		.byte	$00 
		.word	$8823 
		.word	$C023
		
		.byte	$00 
		.word	$C01B 
		.word	$E81B
		
		.byte	$02 
		.word	$3897 
		.word	$3868
		
		.byte	$02 
		.word	$58B7 
		.word	$5810
		
		.byte	$02 
		.word	$68EF 
		.word	$68E0
		
		.byte	$02 
		.word	$70D7 
		.word	$70C8
		
		.byte	$02 
		.word	$78BF 
		.word	$78B0
		
		.byte	$02 
		.word	$80A7 
		.word	$8090
		
		.byte	$02 
		.word	$8867 
		.word	$8848
		
		.byte	$02 
		.word	$8827 
		.word	$8810
		
		.byte	$02 
		.word	$90EF 
		.word	$90C8
		
		.byte	$02 
		.word	$A0A7 
		.word	$A098
		
		.byte	$02 
		.word	$A8BF 
		.word	$A8B0
		
		.byte	$02 
		.word	$B0D7 
		.word	$B0C8
		
		.byte	$02 
		.word	$B8EF 
		.word	$B8E0
		
		.byte	$02 
		.word	$C027 
		.word	$C010
		
		.byte	$02 
		.word	$D0EF 
		.word	$D0D8
		
		.byte	$02 
		.word	$D067 
		.word	$D050
		
		.byte	$02 
		.word	$D8CF 
		.word	$D8C0
		
		.byte	$02 
		.word	$E0B7 
		.word	$E0A8
		
		.byte	$02 
		.word	$E89F 
		.word	$E888
		
		.byte	$02 
		.word	$E827 
		.word	$E810
		
		.byte	$02 
		.word	$F8EF 
		.word	$F810
		
		.byte	$AA		; End of stage data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Stage data for the rivets stage
L_RIVETS_STAGE_DATA:
		.byte	$00 
		.word	$807B 
		.word	$A87B
		
		.byte	$00 
		.word	$D07B 
		.word	$F87B
		
		.byte	$00 
		.word	$5833 
		.word	$8033
		
		.byte	$00 
		.word	$5853 
		.word	$8053
		
		.byte	$00 
		.word	$58AB 
		.word	$80AB
		
		.byte	$00 
		.word	$58CB 
		.word	$80CB
		
		.byte	$00 
		.word	$802B 
		.word	$A82B
		
		.byte	$00 
		.word	$80D3 
		.word	$A8D3
		
		.byte	$00 
		.word	$A823 
		.word	$D023
		
		.byte	$00 
		.word	$A85B 
		.word	$D05B
		
		.byte	$00 
		.word	$A8A3 
		.word	$D0A3
		
		.byte	$00 
		.word	$A8DB 
		.word	$D0DB
		
		.byte	$00 
		.word	$D01B 
		.word	$F81B
		
		.byte	$00 
		.word	$D0E3 
		.word	$F8E3
		
		.byte	$05 
		.word	$30B7 
		.word	$3048
		
		.byte	$05 
		.word	$58CF 
		.word	$5830
		
		.byte	$05 
		.word	$80D7 
		.word	$8028
		
		.byte	$05 
		.word	$A8DF 
		.word	$A820
		
		.byte	$05 
		.word	$D0E7 
		.word	$D018
		
		.byte	$05 
		.word	$F8EF 
		.word	$F810
		
		.byte	$AA		; End of stage data
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following strings are used to display the height of the next stage on
; the intermission screen
; " 25m"
L_HEIGHT_STRING_TABLE:  
		.byte	$10, $82, $85, $8B

 ; " 50m"
l3cf4:  .byte	$10, $85, $80, $8B

 ; " 75m"
l3cf8:  .byte	$10, $87, $85, $8B

 ; "100m"
l3cfc:  .byte	$81, $80, $80, $8B
		
 ; "125m"
l3d00:  .byte	$81, $82, $85, $8B
		
 ; "150m"
l3d04:  .byte	$81, $85, $80, $8B
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The following data describes how to draw the "DONKEY KONG" title in large
; letters on the title screen.
;
; Each entry consists of a one-byte number of tiles to draw and a two-byte
; screen coordinate.  The tiles are drawn starting at the coordinate and 
; moving down for the indicated number of tiles.
; 
L_LARGE_DK_LETTER_DATA:	
		; 'D'
		.byte	5
		.word	TILE_COORD(28,8)
		.byte	1
		.word	TILE_COORD(27,8)
		.byte	1
		.word	TILE_COORD(27,12)
		.byte	3
		.word	TILE_COORD(26,9)
		
		; 'O'
		.byte	5 
		.word	TILE_COORD(24,8) 
		.byte	1 
		.word	TILE_COORD(23,8) 
		.byte	1 
		.word	TILE_COORD(23,12) 
		.byte	5 
		.word	TILE_COORD(22,8) 

		; 'N'
		.byte	5 
		.word	TILE_COORD(20,8) 
		.byte	2 
		.word	TILE_COORD(19,9) 
		.byte	2 
		.word	TILE_COORD(18,10) 
		.byte	5 
		.word	TILE_COORD(17,8) 

		; 'K'
		.byte	5 
		.word	TILE_COORD(15,8) 
		.byte	1 
		.word	TILE_COORD(14,10) 
		.byte	3 
		.word	TILE_COORD(13,9) 
		.byte	1 
		.word	TILE_COORD(12,8) 
		.byte	1 
		.word	TILE_COORD(12,12) 

		; 'E'
		.byte	5 
		.word	TILE_COORD(10,8) 
		.byte	1 
		.word	TILE_COORD(9,8)
		.byte	1 
		.word	TILE_COORD(9,10)
		.byte	1 
		.word	TILE_COORD(9,12)
		.byte	1 
		.word	TILE_COORD(8,8)
		.byte	1 
		.word	TILE_COORD(8,10)
		.byte	1 
		.word	TILE_COORD(8,12)

		; 'Y'
		.byte	3 
		.word	TILE_COORD(6,8)
		.byte	3 
		.word	TILE_COORD(5,10)
		.byte	3 
		.word	TILE_COORD(4,8)

		; 'K'
		.byte	5 
		.word	TILE_COORD(25,15)
		.byte	5 
		.word	TILE_COORD(24,15)
		.byte	2 
		.word	TILE_COORD(23,16)
		.byte	2 
		.word	TILE_COORD(22,15)
		.byte	2 
		.word	TILE_COORD(22,18)

		; 'O'
		.byte	5 
		.word	TILE_COORD(20,15)
		.byte	5 
		.word	TILE_COORD(19,15)
		.byte	1 
		.word	TILE_COORD(18,15)
		.byte	1 
		.word	TILE_COORD(18,19)
		.byte	5 
		.word	TILE_COORD(17,15)

		; 'N'  
		.byte	5 
		.word	TILE_COORD(15,15)
		.byte	2 
		.word	TILE_COORD(14,16)
		.byte	2 
		.word	TILE_COORD(13,17)
		.byte	5 
		.word	TILE_COORD(12,15)

		; 'G'
		.byte	3 
		.word	TILE_COORD(10,16)
		.byte	5 
		.word	TILE_COORD(9,15)
		.byte	1 
		.word	TILE_COORD(8,15)
		.byte	1 
		.word	TILE_COORD(8,19)
		.byte	1 
		.word	TILE_COORD(7,15)
		.byte	1 
		.word	TILE_COORD(7,17)
		.byte	1 
		.word	TILE_COORD(7,19)
		.byte	2 
		.word	TILE_COORD(6,17)

		.byte	$00		; End of data
;------------------------------------------------------------------------------
 


;------------------------------------------------------------------------------
; The following data is used to initialize the value of game variables ($6280 -
; $62bf) before every stage
L_INITIAL_STAGE_DATA_TABLE:	
		.byte	0	; L_RETRACT_LADDER_STATE = up
		.byte	0	; L_RETRACT_LADDER_DELAY (minimum)
		.byte	35	; L_RETRACT_LADDER_X
		.byte	104	; L_RETRACT_LADDER_Y (all the way up)
		.byte	1	; L_RETRACT_LADDER_MOVE_DELAY
		.byte	17	; $6285
		.byte	0	; $6286
		.byte	0	; $6287
		.byte	0	; R_RETRACT_LADDER_STATE = up
		.byte	16	; R_RETRACT_LADDER_DELAY
		.byte	219	; R_RETRACT_LADDER_X
		.byte	104	; R_RETRACT_LADDER_Y (all the way up)
		.byte	1	; R_RETRACT_LADDER_MOVE_DELAY
		.byte	64	; $628D
		.byte	0	; $628E
		.byte	0	; $628F
		.byte	8	; REMAINING_RIVETS
		.byte	1	; $6291
		.byte	1	; $6292
		.byte	1	; $6293
		.byte	1	; $6294
		.byte	1	; $6295
		.byte	1	; $6296
		.byte	1	; $6297
		.byte	1	; $6298
		.byte	1	; $6299
		.byte	0	; $629A
		.byte	0	; $629B
		.byte	0	; $629C
		.byte	0	; $629D
		.byte	0	; $629E
		.byte	0	; $629F
		.byte	128	; TOP_MASTER_REVERSE_TIMER
		.byte	1	; TOP_MASTER_CONVEYER_DIR (moving right)
		.byte	192	; MID_MASTER_REVERSE_TIMER
		.byte	-1	; RIGHT_MASTER_CONVEYER_DIR (moving left)
		.byte	1	; LEFT_MASTER_CONVEYER_DIR
		.byte	255	; BOT_MASTER_REVERSE_TIMER
		.byte	-1	; BOT_MASTER_CONVEYER_DIR (moving left)
		.byte	52	; $62A7
		.word	l39c3	; $62A8
		.word	BARREL_STRUCTS	; $62AA
		.word	$6980	; $62AC
		.byte	26	; $62AE
		.byte	1 	; DK_CLIMBING_COUNTER
		.byte	0 	; INTERNAL_TIMER
		.byte	0 	; $62B1
		.byte	0 	; $62B2
		.byte	0 	; $62B3
		.byte	0 	; $62B4
		.byte	0 	; $62B5
		.byte	0	; $62B6
		.byte	0 	; $62B7
		.byte	4 	; BARREL_FIRE_FREEZE
		.byte	0 	; BARREL_FIRE_STATE
		.byte	16 	; BARREL_FIRE_FLARE_UP_TIME
		.byte	0 	; $62BB
		.byte	0 	; $62BC
		.byte	0 	; $62BD
		.byte	0 	; $62BE
		.byte	0 	; $62BF
;------------------------------------------------------------------------------
 


;------------------------------------------------------------------------------
; Sprite data for the four upright barrels standing to Donkey Kong's left on the
; barrels stage.
L_STANDING_BARRELS_SPRITE_DATA:	
		.byte	30 		; x coord
		.byte	$18		; sprite number ($18 - upright barrel)
		.byte	$0B 	; palette
		.byte	75 		; y coord

		.byte	20 		; x coord
		.byte	$18		; sprite number ($18 - upright barrel)
		.byte	$0B 	; palette
		.byte	75 		; y coord

		.byte	30 		; x coord
		.byte	$18		; sprite number ($18 - upright barrel)
		.byte	$0B 	; palette
		.byte	59 		; y coord

		.byte	20 		; x coord
		.byte	$18		; sprite number ($18 - upright barrel)
		.byte	$0B 	; palette
		.byte	59 		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial sprite data for fire balls
L_FIREBALL_SPRITE_DATA:	
		.byte	$3D	; Fire ball sprite
		.byte	$01	; Palette
		.byte	3
		.byte	2
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial sprite data for firefoxes
L_FIREFOX_SPRITE_DATA:	
		.byte	$4D	; Firefox sprite
		.byte	$01	; Palette
		.byte	4
		.byte	1
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial sprite data for the oil barrel fire on the barrels stage
; This is before the fire is lit
L_BARRELS_FIRE_SPRITE_DATA:	
		.byte	39	; X coordinate
		.byte	$70	; Blank sprite
		.byte	$01	; Palette
		.byte	224	; Y coordinate
		.byte	0
		.byte	0
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial sprite data for the oil barrel fire on the mixer stage
; The fire is initially burning
L_MIXER_FIRE_SPRITE_DATA:	
		.byte	127	; X coordinate
		.byte	$40	; Burning fire sprite
		.byte	$01	; Palette
		.byte	120	; Y coordinate
		.byte	2
		.byte	0
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for the oil barrel on the barrels stage
L_OIL_BARREL_SPRITE_DATA_1: 
		.byte	39		; x coord 
		.byte	$49		; sprite number 
		.byte	$0C		; palette
		.byte	240		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for the oil can on the mixer stage
L_OIL_BARREL_SPRITE_DATA_2: 	
		.byte	127		; x coord 
		.byte	$49		; sprite number 
		.byte	$0C		; palette
		.byte	136		; y coord
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; Sprite data for the hammers that Mario can grab
L_HAMMER_SPRITE_DATA:	
		.byte	$1E	; Upright Hammer
		.byte	$07	; Palette
		.byte	3
		.byte	9
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial coordinates for the hammers on the barrels stage
L_BARRELS_HAMMER_COORDS:	
		.byte	36	; X coordinate
		.byte	100	; Y coordinate
		
		.byte	187	; X coordinate
		.byte	192	; Y coordinate
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial coordinates for the hammers on the mixer stage
L_MIXER_HAMMER_COORDS:	
		.byte	35	; X coordinate
		.byte	141	; Y coordinate
		
		.byte	123	; X coordinate
		.byte	180	; Y coordinate
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Initial coordinates for the hammers on the rivets stage
L_RIVETS_HAMMER_COORDS:	
		.byte	27	; X coordinate
		.byte	140	; Y coordinate
		
		.byte	124	; X coordinate
		.byte	100	; Y coordinate
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for pies on the mixer stage
L_PIE_SPRITE_DATA:	
		.byte	$4B	; Pie sprite
		.byte	$0E	; Palette
		.byte	4
		.byte	2
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for the retractable ladders on the mixer level
L_RETRACT_LADDER_SPRITE_DATA:	
		.byte	35		; x coord 
		.byte	$46 	; sprite number
		.byte	$03 	; palette
		.byte	104		; y coord
		
		.byte	219		; x coord 
		.byte	$46 	; sprite number
		.byte	$03 	; palette
		.byte	104		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for the conveyer motors on the mixer level
L_MIXER_MOTOR_SPRITE_DATA:	
		; CONV_MOTOR_SPRITE_TL (Top left)
		.byte	23		; x coord 
		.byte	$50 	; sprite number
		.byte	$00 	; palette
		.byte	92		; y coord
		
		; CONV_MOTOR_SPRITE_TR (Top right)
		.byte	231		; x coord 
		.byte	$D0 	; sprite number ($50 - horizontally reversed)
		.byte	$00 	; palette
		.byte	92		; y coord
		
		; CONV_MOTOR_SPRITE_MR (Middle right)
		.byte	140		; x coord 
		.byte	$50 	; sprite number
		.byte	$00 	; palette
		.byte	132		; y coord
		
		; CONV_MOTOR_SPRITE_ML (Middle left)
		.byte	115		; x coord 
		.byte	$D0 	; sprite number ($50 - horizontally reversed)
		.byte	$00 	; palette
		.byte	132		; y coord
		
		; CONV_MOTOR_SPRITE_BL (Bottom left)
		.byte	23		; x coord 
		.byte	$50 	; sprite number
		.byte	$00 	; palette
		.byte	212		; y coord
		
		; CONV_MOTOR_SPRITE_BR (Bottom right)
		.byte	231		; x coord 
		.byte	$D0 	; sprite number ($50 - horizontally reversed)
		.byte	$00 	; palette
		.byte	212		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for bonus prizes on the mixer stage
L_MIXER_PRIZE_SPRITE_DATA:	
		.byte	83		; x coord 
		.byte	$73 	; sprite number (Pauline's hat)
		.byte	$0A 	; palette

		.byte	160		; y coord
		
		.byte	139		; x coord 
		.byte	$74 	; sprite number	(Pauline's purse)
		.byte	$0A 	; palette
		.byte	240		; y coord
		
		.byte	219		; x coord 
		.byte	$75 	; sprite number (Pauline's umbrella)
		.byte	$0A 	; palette
		.byte	160		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for bonus prizes on the elevators stage
L_ELEV_PRIZE_SPRITE_DATA:	
		.byte	91		; x coord 
		.byte	$73 	; sprite number (Pauline's hat)
		.byte	$0A 	; palette
		.byte	200		; y coord
		
		.byte	227		; x coord 
		.byte	$74 	; sprite number	(Pauline's purse)
		.byte	$0A 	; palette
		.byte	96		; y coord
		
		.byte	27		; x coord 
		.byte	$75 	; sprite number (Pauline's umbrella)
		.byte	$0A 	; palette
		.byte	128		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for bonus prizes on the rivets stage
L_RIVETS_PRIZE_SPRITE_DATA:	
		.byte	219		; x coord 
		
.byte	$73 	; sprite number (Pauline's hat)
		.byte	$0A 	; palette
		.byte	200		; y coord
		
		.byte	147		; x coord 
		.byte	$74 	; sprite number	(Pauline's purse)
		.byte	$0A 	; palette
		.byte	240		; y coord
		
		.byte	51		; x coord 
		.byte	$75 	; sprite number (Pauline's umbrella)
		.byte	$0A 	; palette
		.byte	80		; y coord
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Sprite data for the elevator platforms on the elevators stage
L_ELEVATOR_SPRITE_DATA:	
		.byte	$44		; Elevator platform sprite
		.byte	$03		; Palette
		.byte	8
		.byte	4
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; The initial coordinates for the elevators on the elevators stage
L_ELEVATOR_COORDS:	
		.byte	55	; X coordinate
		.byte	244	; Y coordinate
		
		.byte	55	; X coordinate
		.byte	192	; Y coordinate
		
		.byte	55	; X coordinate
		.byte	140	; Y coordinate
		
		.byte	119	; X coordinate
		.byte	112	; Y coordinate
		
		.byte	119	; X coordinate
		.byte	164	; Y coordinate
		
		.byte	119	; X coordinate
		.byte	$D8	; Y coordinate
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Determine the amount of points to award the player
; passed: 	a - (pointAwardType) rotated right 1 bit
; return: 	de - function call to pass to the AddFunctionToUpdateList function
;             	 ($0001 = award 100 points
;             	  $0003 = award 300 points
;             	  $0005 = award 500 points)
;         	b - the point sprite to display
DETERMINE_POINT_AWARD_AMT: 	
		ld		de,1		
		ld		b,$7b						; 200 point award sprite
		rra
		jp		nc,l1e28
		
		ld		e,3
		ld		b,$7d						; 300 point award sprite
		rra
		jp		nc,l1e28
		
		; NOTE: There appears to be a bug here
		;       500 points are awarded, but the
		;       800 point sprite is displayed
		;       (de is set to 5 = 500 points,
		;        but b is set to $7f = 800 point sprite)
		ld		e,5
		ld		b,$7f						; 800 point award sprite
		jp		l1e28
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l3e88: 	ld		a,($6227)
		push	hl
		rst		$28
		; Jump table
		.word	L_ORG	; 0 = reset game
		.word	l3e99	; 1 = 
		.word	L_MIXER_ENEMY_COLLISION	; 2 = 
		.word	L_ELEVATOR_ENEMY_COLLISION	; 3 =
		.word	L_RIVETS_ENEMY_COLLISION	; 4 = 
		.word	L_ORG	; 5 = reset game
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
l3e99:	
		pop		hl
		xor		a
		ld 		($6060),a
		ld 		b,10
		ld 		de,32
		ld 		ix,BARREL_STRUCTS
		call	l3ec3
		ld		b,5
		ld		ix,FIREBALL_STRUCTS
		call	l3ec3
		ld		a,($6060)
		and		a
		ret		z

		cp		$01
		ret		z

		cp		$03
		ld		a,$03
		ret		c

		ld 		a,$07
		ret
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l3ec3:	bit		0,(ix+0)
		jp		z,l3efa
		ld		a,c
		sub		(ix+5)
		jp		nc,l3ed3
		neg
l3ed3:	inc		a
		sub		l
		jp		c,l3ede
		sub		(ix+10)
		jp		nc,l3efa
l3ede:	ld		a,(iy+3)
		sub		(ix+3)
		jp		nc,l3ee9
		neg
l3ee9:	sub		h
		jp		c,l3ef3
		sub		(ix+9)
		jp		nc,l3efa
l3ef3:	ld		a,($6060)
		inc		a
		ld		($6060),a
l3efa:	add		ix,de
		djnz	l3ec3
        ret
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
l3eff:	.byte	$00
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; "1981"
L_1981_STRING_DATA: 	
		.word	TILE_COORD(18, 28)
		.byte	$49, $4A, $01, $09, $08, $01
		.byte	$3F		; End of string
		

; "NINTENDO OF AMERICA INC."
L_NINTENDO_STRING_DATA: 	
		.word	$TILE_COORD(27, 29)
		.byte	$1E
L_NINTENDO_STRING_DATA_1:	
		.byte	$19, $1E, $24, $15, $1E, $14, $1F, $10, $1F, $16, $10, $11, $1d, $15, $22, $19, $13, $11, $10, $19, $1E, $13, $2B
		.byte	$3F		; End of string		
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Display (TM)
L_DISPLAY_TM:	
		ld      hl,TILE_COORD(5,15)
		ld      de,-32
		ld      (hl),$9f    ; Display '(T'
		add     hl,de       ; hl=(4, 15)
		ld      (hl),$9e    ; Display 'M)'
		ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; The following text appears to be an easter egg for code hackers like myself...
; It doesn't appear to have any deeper purpose in the game.
		.text "PROGRAM,WE WOULD TEACH YOU.*****"
		.text "TEL.TOKYO-JAPAN 044(244)2151    "
		.text "EXTENTION 304   SYSTEM DESIGN   "
		.text "IKEGAMI CO. LIM."
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; I don't quite understand why this function is needed
; It just displays the retractable ladders in the mixers level and jumps 
; to the routine that completes the stage initialization
L_WIERD_DISPLAY_STAGE_FN:	
		call	L_DISPLAY_MIXER_LADDERS
		jp		L_COMPLETE_STAGE_INIT
;------------------------------------------------------------------------------
		


;------------------------------------------------------------------------------
; If the current stage is the mixer stage (2), draw the ladders for that level
; otherwise return immediately.
L_DISPLAY_MIXER_LADDERS:  
		; Return unless this is the rivets stage
		ld      a,2		
        rst     $30							
		
        ld      b,2							; For b = 2 to 1
        ld      hl,TILE_COORD(27,12)
l3fae:  ld      (hl),$10					; Display ' ' at hl
        inc     hl			
l3fb1:  inc     hl							; hl += 2 rows
        ld      (hl),$c0					; Display ladder at hl
        ld      hl,TILE_COORD(4,12)
        djnz    l3fae						; next b
        ret     
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
; As far as I can tell, these are unused bytes
		.byte	$00, $00, $00, $00, $00, $00
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Called when Mario starts climbing a ladder.
; Set Mario's sprite to the climbing sprite and returns the address of
; marioSpriteY
;
; passed:	none
; return:	hl - address of Mario's sprite y coordinate
L_SET_MARIO_SPRITE_TO_CLIMBING:  
		; Set Mario's sprite to 3
		ld      hl,MARIO_SPRITE_NUM
        ld      (hl),3
        inc     l
        inc     l							; MARIO_SPRITE_Y
        ret     
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Junk data?
l3fc8:	.byte	$00
		.byte	$00
		.byte	$41
		.byte	$7F
		.byte	$7F
		.byte	$41
		.byte	$00
		.byte	$00
		.byte	$00
		.byte	$7F
		.byte	$7F
		.byte	$18
		.byte	$3C
		.byte	$76
		.byte	$63
		.byte	$41
		.byte	$00
		.byte	$00
		.byte	$7F
		.byte	$7F
		.byte	$49
		.byte	$49
		.byte	$49
		.byte	$41
		.byte	$00
		.byte	$1C
		.byte	$3E
		.byte	$63
		.byte	$41
		.byte	$49
		.byte	$79
		.byte	$79
		.byte	$00
		.byte	$7C
		.byte	$7E
		.byte	$13
		.byte	$11
		.byte	$13
        .byte   $7e
		.byte	$7C
		.byte	$00
		.byte	$7F
		.byte	$7F
		.byte	$0E
		.byte	$1C
		.byte	$0E
		.byte	$7F
		.byte	$7F
		.byte	$00
		.byte	$00
		.byte	$41
		.byte	$7F
		.byte	$7F
		.byte	$41
		.byte	$00
		.byte	$00
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Generate an error if the program goes over the 16K limit
	.echo "NOTE: ROM size is "
	.echo $
	.echo " bytes"
#if ($ > $4000)
	.echo "\nERROR: 16K limit exceeded!\n"
	!!!ERROR:_16K_LIMIT_EXCEEDED!!!
#else
	.echo ", leaving "
	.echo $4000 - $
	.echo " bytes free\n"
#endif
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Many routines jump here to abort the game
		.org $4000
l4000:
        .end
;------------------------------------------------------------------------------

