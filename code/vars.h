; The following macro allows tile coordinates to be entered as x,y coordinates rather
; than bare memory addresses
#define		TILE_COORD(x,y)			$7400 + (x * 32) + y

; The following macro combines two bytes into a single word
#define		TWO_BYTES(a,b)			(b & $ff) | ((a & $ff) << 8) & $ffff

; The following macro assembles a block of stage data given:
;	t - the tile type
;	x1, y1 - the starting coordinate of the line of tiles
;	x2, y2 - the ending coordinate of the line of tiles
#define		STAGE_DATA(t,x1,y1,x2,y2) .byte (t)\ .word ((y1<<11) | (x1<<3) & $ffff) \ .word ((y2<<11) + (x2<<3) & $ffff)
#define		NRM_LAD_STAGE_DATA(x1,y1,x2,y2) .byte 0\ .word ((y1<<11) | (x1<<3 | 0011) & $ffff) \ .word ((y2<<11) | (x2<<3 | 0011) & $ffff)
#define		BRK_LAD_STAGE_DATA(x1,y1,x2,y2) .byte 1\ .word ((y1<<11) | (x1<<3 | 0011) & $ffff) \ .word ((y2<<11) | (x2<<3 | 0011) & $ffff)
; The following macro converts an x,y coordinate into a stage data location
#define		STAGE_COORD(x,y)		((y<<11) | (x<<3)) & $ffff
#define		STAGE_DATA_END 			.byte 	$AA

LADDER_TILE							= 0
BRK_LADDER_TILE						= 1
SLP_GIRDER_TILE						= 2
SQR_GIRDER_TILE						= 3
BLANK_TILE							= 4
CIR_GIRDER_TILE						= 5
X_TILE								= 6

NUM_PLAYS	                 		= $6001		; The number of game plays that have been paid for
NUM_COINS_PENDING           		= $6002  	; Keeps track of the number of coins entered until there are enough for a credit
COIN_VALID                    		= $6003  	; Prevents 1 coin entry from being processed more than once

GAME_STATE             				= $6005  
GAME_STATE_INIT							= 0		; Preparing the game
GAME_STATE_ATTRACT						= 1		; Running attract mode
GAME_STATE_COIN							= 2		; Coin(s) inserted, waiting for player to push start
GAME_STATE_PLAY							= 3		; The game is being played
    
NO_COINS_INSERTED           		= $6007  	; becomes 0 when a coin is inserted
MAJOR_TIMER                 		= $6008
MINOR_TIMER                 		= $6009

GAME_SUBSTATE						= $600a
; If GAME_STATE == GAME_STATE_ATTRACT
GAME_SUBSTATE_ATTRACT_COIN				= 0		; Display insert coin screen
GAME_SUBSTATE_ATTRACT_INIT				= 1		; Initialize the attract mode
GAME_SUBSTATE_ATTRACT_MARIO		 		= 2 	; Initialize the Mario sprite 
GAME_SUBSTATE_ATTRACT_RUN				= 3		; Run the attract mode
	
; If GAME_STATE == GAME_STATE_COIN_INSERTED

; If GAME_STATE == GAME_STATE_PLAYING
GAME_SUBSTATE_PLAY_ORIENT				= 0		; Orienting the screen
GAME_SUBSTATE_PLAY_INIT_P1				= 1		; Initialize player 1
GAME_SUBSTATE_PLAY_START_P1				= 2		; Display player 1 start prompt
GAME_SUBSTATE_PLAY_INIT_P2				= 3 	; Initialize player 2
GAME_SUBSTATE_PLAY_START_P2				= 4		; Display player 2 start prompt
GAME_SUBSTATE_PLAY_PLAYER_INFO			= 5		; Display information for the player
GAME_SUBSTATE_PLAY_PREPARE				= 6		; Prepare to display either intro or intermission
GAME_SUBSTATE_PLAY_INTRO				= 7		; Run the introduction screen
GAME_SUBSTATE_PLAY_INTERMISSION			= 8		; Run the intermission screen
GAME_SUBSTATE_PLAY_STAGE				= 10	; Display the current stage
GAME_SUBSTATE_PLAY_MARIO				= 11	; Initialize the Mario sprite
	
CURRENT_PLAYER						= $600d
PLAYER_1								= 0		; Player 1's turn
PLAYER_2								= 1		; Player 2's turn

SECOND_PLAYER						= $600e		; 1 if the second player is the current player
TWO_PLAYERS							= $600f		; = 1 if two players are playing
PLAYER_INPUT						= $6010
PLAYER_INPUT_JUMP_BIT					= 7
PLAYER_INPUT_DOWN_BIT					= 3
PLAYER_INPUT_UP_BIT						= 2
PLAYER_INPUT_LEFT_BIT					= 1
PLAYER_INPUT_RIGHT_BIT					= 0
PLAYER_INPUT_LAG					= $6011		; Prevents input (specifically the jump button) from being processed twice

RANDOM_NUMBER						= $6018		
COUNTER_1							= $6019
COUNTER_2							= $601a		; Decremented on every interrupt

DIP_NUM_LIVES						= $6020		; The number of lives setting from the DIP switches
DIP_BONUS_LIFE						= $6021		; The number of points for the life bonus from the DIP switches
NUM_COINS_FOR_1P					= $6022		; The number of coins required for 1 player to play
NUM_COINS_FOR_2P					= $6023		; The number of coins required for 2 players to play
DIP_COINS_PER_CREDIT				= $6024		; The number of coins required for 1 credit
DIP_PLAYS_PER_CREDIT				= $6025		; The number of plays given for each credit earned
CABINET_TYPE						= $6026
CABINET_TYPE_COCKTAIL					= 0
CABINET_TYPE_UPRIGHT					= 1

JOYSTICK_INPUT_DELAY				= $6030	; Prevents the joystick from scrolling through the letters too quickly on the high score initials entry screen
BLANK_CP_HIGH_SCORE					= $6031	; Makes the score display blink (0 = display score, 1 = blank it)
BLINK_SCORE_TIMER					= $6032	; The score starts to blink when this reaches 0
INITIALS_TIMER_VALUE				= $6033	; The time remaining to enter initials
INITIALS_TIMER_DELAY				= $6034	; The delay between ticks of the initials timer
SELECTED_LETTER						= $6035	; The letter currently selected for high score entry
INITIALS_COORD						= $6036	; 2 byte screen coordinate the next initial letter will be displayed at for high score entry
PLAYER_ID_ADDRESS					= $6038	; 2 byte address of the player's high score entry - determined when it's time for the player to enter initials
INITIALS_ADDRESS					= $603a	; The memory address to write the player's initials to for the high score

P1_DATA								= $6040
	; This is an 8 byte block of data for player 1
	; The individual data items are listed below
P1_NUMBER_LIVES						= $6040	; The number of lives for player 1
P1_LEVEL_NUMBER						= $6041	; Player 1's level number
P1_STAGE_ORDER_POINTER				= $6042	; The address of the stage data for player 1's current stage
P1_INTRO_NOT_DISPLAYED				= $6044	; 1 if the intro has not been displayed for player 1
P1_BONUS_AWARDED					= $6045	; 1 if player 1 has been awarded a bonus life
P1_HEIGHT_INDEX						= $6046	; The index to the current height that player 1 has achieved
P1_STAGE_ORDER_POINTER_LAG			= $6047
P2_DATA								= $6048
	; This is an 8 byte block of data for player 2
	; The individual data items are listed below
P2_NUMBER_LIVES						= $6048	; The number of lives for player 2
P2_LEVEL_NUMBER						= $6049	; Player 2's level number
P2_STAGE_ORDER_POINTER				= $604a	; The address of the stage data for player 2's current stage
P2_INTRO_NOT_DISPLAYED				= $604c	; 1 if the intro has not been displayed
P2_BONUS_AWARDED					= $604d	; 1 if player 2 has been awarded a bonus life
P2_HEIGHT_INDEX						= $604e	; The index to the current height that player 2 has achieved
P2_STAGE_ORDER_POINTER_LAG			= $604f

WALK_SOUND_TRIGGER					= $6080	; Triggers the Mario walking sound
JUMP_SOUND_TRIGGER					= $6081	; Triggers the Mario jumping sound
STOMP_SOUND_TRIGGER					= $6082	; Triggers the Donkey Kong stomping sound
SPRING_SOUND_TRIGGER				= $6083	; Triggers the spring bounce sound
FALL_SOUND_TRIGGER					= $6084	; Triggers the falling spring sound
AWARD_SOUND_TRIGGER					= $6085	; Triggers the point award sound (Mario jumps a barrel, smashes a barrel/fire, grabs the hammer)

DEATH_SOUND_TRIGGER					= $6088
SONG_TRIGGER						= $6089	; Songs are played whenever this is set to non-zero
SONG_TRIGGER_NONE						= 0
SONG_TRIGGER_INTRODUCTION				= 1
SONG_TRIGGER_INTERMISSION				= 2
SONG_TRIGGER_OUT_OF_TIME				= 3
SONG_TRIGGER_HAMMER						= 4
SONG_TRIGGER_LEVEL_END_2				= 5
SONG_TRIGGER_HAMMER_HIT					= 6
SONG_TRIGGER_STAGE_END					= 7
SONG_TRIGGER_BG_BARRELS					= 8	
SONG_TRIGGER_BG_MIXER					= 9
SONG_TRIGGER_BG_ELEVATORS				= 10
SONG_TRIGGER_BG_RIVETS					= 11
SONG_TRIGGER_LEVEL_END_1				= 12
SONG_TRIGGER_RIVET_REMOVED				= 13
SONG_TRIGGER_RIVET_END					= 14
SONG_TRIGGER_ROAR						= 15
PENDING_SONG_TRIGGER				= $608a	; The current song being played
PENDING_SONG_TRIGGER_REPEAT			= $608b		; The number of times to repeat the pending song trigger

ACTION_BUFFER_WRITE_POS				= $60b0
ACTION_BUFFER_READ_POS				= $60b1
PREV_P1_SCORE						= $60b2		; The remembered player 1 score displayed during attract mode
PREV_P2_SCORE						= $60b5		; The remembered player 2 score
PREV_HIGH_SCORE						= $60b8		; The remembered high score

HIGH_SCORE_TABLE					= $6100
	; Each entry in the table has the following format
	; Bytes 0-1 = Coord of the high score string representation
	; Bytes 2-27 = High score string representation
	; Byte 28 = Player ID
	;	0 = No current player
	;	1 = Player 1
	;	2 = Player 2
	; Bytes 29-31 = High score entry (BCD)
	; Bytes 32-33 = High score coord
HIGH_SCORE_TABLE_ENTRY_1			= $6100
HIGH_SCORE_TABLE_ENTRY_2			= $6122
HIGH_SCORE_TABLE_ENTRY_3			= $6144
HIGH_SCORE_TABLE_ENTRY_4			= $6166
HIGH_SCORE_TABLE_ENTRY_5			= $6188

CURRENT_SCORE_STRING				= $61b1	; The string representation of the current player's score including room for initials (18 bytes long) (ends at $61c3)

MARIO_DATA_STRUCT					= $6200
	; This is the start of Mario's 39 byte data structure
	; The structure consists of the following data items
	; (Each item also has a separate variable defined below):
	;  0 - Mario is alive (1 or 0)
	; 
	;  3 - Mario's x coordinate
	; 
	;  5 - Mario's y coordinate
	;
	;  7 - Mario's sprite number
	;  8 - Mario's palette
	;
	; 14 - The y coordinate that Mario started jumping from
	;
	; 16 - Mario is jumping left if this equals $FF
	; 17 - Mario is jumping right if this equals $80
	;
	; 21 - Mario is climbing a ladder (1 or 0)
	; 22 - Mario is jumping (1 or 0)
	; 23 - The hammer cycle is active (1 or 0)
	; 24 - The hammer has been grabbed (1 or 0)
	; 
	; 27 - The y coordinate of the top of the ladder being currently climbed
	; 28 - The y coordinate of the bottom of the ladder being currently climbed
	;
	; 33 - Mario is falling (1 or 0)
MARIO_ALIVE							= $6200

MARIO_X								= $6203

MARIO_Y								= $6205			

MARIO_DATA_SPRITE_NUM				= $6207
MARIO_DATA_PALETTE					= $6208

MARIO_JUMP_Y_COORD					= $620e	; The y coordinate of the start of Mario's current jump

MARIO_JUMPING_LEFT					= $6210	; $FF if Mario is jumping left
MARIO_JUMPING_RIGHT				 	= $6211	; $80 if Mario is jumping right

MARIO_IS_CLIMBING					= $6215 ; 1 if Mario is climbing a ladder
MARIO_IS_JUMPING					= $6216	; 1 if Mario is jumping
HAMMER_CYCLE_ACTIVE					= $6217	; This is set to 1 if Mario has the hammer and the up/down cycle is active
HAMMER_GRABBED						= $6218 ; This is set to 1 when Mario initially jumps up and grabs the hammer, and is set to 0 when Mario comes back down and the hammer cycle starts

TOP_OF_CURRENT_LADDER				= $621b	; The y coordinate of the top of the current ladder being climbed
BOT_OF_CURRENT_LADDER				= $621c	; The y coordinate of the bottom of the current ladder being climbed

MARIO_HAMMER_CYCLE_DELAY			= $621e	; Small delay between when the hammer is grabbed and the hammer cycle begins (countdown from 4 to 0)

MARIO_IS_FALLING					= $6221	; 1 when Mario is in free fall

CURRENT_STAGE						= $6227	; The stage that the current player is at
STAGE_BARRELS							= 1		
STAGE_MIXER								= 2
STAGE_ELEVATORS							= 3
STAGE_RIVETS							= 4

CP_DATA								= $6228
	; This is an 8 byte block of data for the current player
	; The individual data items are listed below
CP_NUMBER_LIVES						= $6228	; The number of lives for the current player
CP_LEVEL_NUMBER						= $6229	; The level number for the current player
CP_STAGE_ORDER_POINTER				= $622a
CP_INTRO_NOT_DISPLAYED				= $622c ; 1 if the current player has seen the intro screen
CP_BONUS_LIFE_AWARDED				= $622d	; 1 if the current player has earned the bonus life
CP_HEIGHT_INDEX						= $622e
HEIGHT_25M								= 0
HEIGHT_50M								= 1
HEIGHT_75M								= 2
HEIGHT_100M								= 3
HEIGHT_125M								= 4
HEIGHT_150M								= 5
CP_STAGE_ORDER_POINTER_LAG			= $622f

; This is the start of 64 bytes of data used in the stage game play
STAGE_DATA_BLOCK					= $6280

RETRACTABLE_LADDER_DATA				= $6280		
; The start of the 8 byte data for the two retractable ladders on the mixer stage
; The data structure is as follows:
;
;  0 - The ladder state
;		0 = ladder in up position
;		1 = ladder moving down
;		2 = ladder in down position
;		3 = ladder moving up
;  1 - The ladder up delay - the time before the ladder starts to descend
;  2 - The ladder x coordinate
;  3 - 
;  4 - The ladder move delay - the ladder is moved down one pixel when
;		this reaches 0
L_RETRACT_LADDER_DATA				= $6280
L_RETRACT_LADDER_STATE				= $6280
L_RETRACT_LADDER_DELAY				= $6281
L_RETRACT_LADDER_X					= $6282
L_RETRACT_LADDER_Y					= $6283
L_RETRACT_LADDER_MOVE_DELAY			= $6284

R_RETRACT_LADDER_STATE				= $6288
R_RETRACT_LADDER_DELAY				= $6289
R_RETRACT_LADDER_X					= $628a
R_RETRACT_LADDER_Y					= $628b
R_RETRACT_LADDER_MOVE_DELAY			= $628c

REMAINING_RIVETS					= $6290	; The number of rivets that have not been removed

TOP_MASTER_REVERSE_TIMER			= $62a0	; When this reaches 0, the mixer stage conveyer directions are reversed
TOP_MASTER_CONVEYER_DIR				= $62a1	; The direction of the top conveyer belt in the mixer stage
MID_MASTER_REVERSE_TIMER			= $62a2	; When this reaches 0, the middle conveyers (left and right) change direction
RIGHT_MASTER_CONVEYER_DIR			= $62a3	; The direction of the right conveyer belt
LEFT_MASTER_CONVEYER_DIR			= $62a4	; The direction of the left conveyer belt
BOT_MASTER_REVERSE_TIMER			= $62a5	; When this reaches 0, the bottom conveyer change direction
BOT_MASTER_CONVEYER_DIR				= $62a6	; The direction of the bottom conveyer belt in the mixer stage
ELEVATOR_SPAWN_TIMER				= $62a7	; Counts down from 52 to 0 and then a new elevator is spawned in the left column on the elevators stage

DK_CLIMBING_COUNTER					= $62af	; Used to delay between advancing Donkey Kong's climbing animation

INTERNAL_TIMER						= $62b0	; The internal stage timer (in hex)

BARREL_FIRE_FREEZE					= $62b8	; Counts down from 4 to 0 between updates of the barrel fire
BARREL_FIRE_STATE					= $62b9		
	; 3 = Initial flare up
	; 1 = Normal burning
	; 0 = Not burning
BARREL_FIRE_FLARE_UP_TIME			= $62ba	; The time remaining until the initial flare up subsides

NORMAL_LADDER_X_COORD_DATA			= $6300	; The start of x coordinate data for the normal ladders in the current stage
	; 15 bytes total (max of 15 normal ladders)
BROKEN_LADDER_X_COORD_DATA			= $6310	; The start of x coordinate data for the broken ladders in the current stage
	; 5 bytes total (max of 5 broken ladders)
NORMAL_LADDER_Y1_COORD_DATA			= $6315	; The start of y1 coordinate data for the normal ladders in the current stage
	; 15 bytes total (max of 15 broken ladders)
BROKEN_LADDER_Y1_COORD_DATA			= $6325	; The start of y1 coordinate data for broken ladders in the current stage
	; 5 bytes total (max of 5 broken ladders)
NORMAL_LADDER_Y2_COORD_DATA			= $632A	; The start of y2 coordinate data for the normal ladders in the current stage
	; 15 bytes total (max of 15 normal ladders)
BROKEN_LADDER_Y2_COORD_DATA			= $633A	; The start of y2 coordinate data for the broken ladders in the current stage
	; 5 bytes total (max of 5 broken ladders)
POINT_AWARD_STATE					= $6340		
	; 0 = No points have been awarded
	; 1 = Award points to the player
	; 2 = Display the point award
POINT_AWARD_DISPLAY_TIMER			= $6341	; The current point award sprite is displayed until this timer reaches 0	
POINT_AWARD_TYPE					= $6342 ; The type of point award that Mario has earned
	; 0 = award points based on the level number
	;	level 1 = 300 points
	;	level 2 = 500 points
	;	level 3+ = 800 points
	; 1 = 200 points
	; 2 = 300 points
	; 3 = 300 points
	; 4 = random 300, 500, or 800
	; 5 = 500 points (800 point sprite is displayed)
SMASHED_SPRITE_POINTER				= $6343	; The address of the sprite that was smashed by the hammer(2 bytes)
SMASH_ANIMATION_STATE				= $6345	; The state of the smash animation
	; 0 = 
	; 1 = 
	; 2 = 
SMASH_ANIMATION_FRAME_DELAY			= $6346	; The current animation frame is displayed until this counts down to 0
SMASH_ANIMATION_CYCLE_COUNTER		= $6347	; The smash animation cycles between the first two sprite images in the smash animation until this counts down to 0
BARREL_FIRE_STATUS					= $6348	; 1 if the barrel fire has been lit

SMASH_ANIMATION_ACTIVE				= $6350	; 1 when an object has been smashed and the animation is in effect (everything else pauses)
SMASH_ENEMY_CLASS_POINTER			= $6351 ; (2 bytes) pointer to the start of the data structures for the enemy's class (used to find the correct enemy data structure)
SMASH_ENEMY_DATA_SIZE				= $6353	; The size of the data structure of the enemy that was struck by the hammer (used to find the correct enemy data structure)
SMASH_ANIMATION_ENEMY_INDEX			= $6354	; The index number (within the enemy's class) of the enemy that was struck by the hammer

CP_DIFFICULTY						= $6380
MAJOR_COUNTER						= $6381

MINOR_COUNTER						= $6384
INTRODUCTION_STATE					= $6385
	; 0 = display introduction screen
	; 1 = prepare sprites
	; 2 = animate the climbing sequence
	; 3 = pause
	; 4 = animate intro screen
	; 5 = pause
	; 6 = animate Donkey Kong jumping
	; 7 = Donkey Kong grins and laughs
	
WIN_ANIMATION_STATE					= $6388	; State of the win stage animation
PRE_HAMMER_TUNE						= $6389 ; Saves the tune that was playing before the hammer was grabbed
TITLE_PALETTE_CYCLE_COUNTER			= $638a	; Used to cycle the palette colors on the "DONKEY KONG" title screen
TITLE_PALETTE_PATTERN				= $638b	; The currently used palette on the "DONKEY KONG" title screen
ONSCREEN_TIMER						= $638c	; The internal timer converted to BCD for display
STAGE_DEFORM_INDEX					= $638d	; Keeps track of the next stage data to display when Donkey Kong completes a jump in the introduction stage and causes the platforms to deform
LADDER_ROW_TO_ERASE					= $638e	; The ladder row to erase as the ladder is being pulled up on the introduction stage
ANIMATION_TIMER						= $6390	; Manages the animation state for Donkey Kong and Pauline
TIME_FOR_DK_ACTION					= $6391	; Indicates that a Donkey Kong action is being animated

DK_STOMPING							= $6393	; Donkey Kong starts stomping when this is 1
HAMMER_CYCLE_COUNTER				= $6394	; Counter that controls the cycle of raising and lowering the hammer cycle when Mario has the hammer
HAMMER_CYCLE_WRAP_COUNTER			= $6395	; Keeps track of the number of times the hammer cycle counter wraps back around to 0 - the hammer is released after 2 wraps
RELEASE_SPRING						= $6396

MARIO_ON_ELEVATOR					= $6398	; 1 if Mario is riding up or down an elevator platform

DEATH_ANIMATION_STATE				= $639d
DEATH_ANIMATION_COUNTER				= $639e

RELEASE_A_FIREBALL					= $63a0	; A fireball is released when this equals 1
ACTIVE_FIREBALL_COUNT				= $63a1 ; The number of fireballs active on the current level
UPDATED_FIREBALL_COUNT				= $63a2	; The number of fireballs that have been updated (counts up to 5)
TOP_CONVEYER_DIR					= $63a3	; The direction that the top conveyer belt on the mixer level is moving
LEFT_CONVEYER_DIR					= $63a4
RIGHT_CONVEYER_DIR					= $63a5
BOT_CONVEYER_DIR					= $63a6

INTERM_HEIGHT_STRING_INDEX			= $63a7	; Index to the string representing the current height in the height string table for the intermission screen
INTERM_HEIGHT_STRING_COORD			= $63a8	; (2 bytes) The coordinate that the current height string should be displayed at on the intermission screen

STAGE_DATA_START_ADDRESS			= $63ab	; The tile memory address where the first tile in a tile line is to be drawn
STAGE_DATA_END_ADDRESS				= $63ad	; The tile memory address where the last tile in a tile line is to be drawn
STAGE_DATA_FIRST_Y_OFFSET			= $63af
STAGE_DATA_LAST_Y_OFFSET			= $63b0
STAGE_DATA_X_DIFF					= $63b1
STAGE_DATA_Y_DIFF					= $63b2
STAGE_DATA_TILE_ID					= $63b3
STAGE_DATA_UNKNOWN					= $63b4
STAGE_DATA_CURRENT_TILE				= $63b5

DK_DISTANCE_TO_LADDER				= $63b7 ; The distance between Donkey Kongs head? and the ladder on the mixer level
TIMER_HAS_RUN_DOWN					= $63b8	; Set to 1 to distinguish between the onscreen timer being zero because it needs to be initialized and being zero because it has legitimately run down
NUM_ENEMIES_OF_CURRENT_CLASS		= $63b9	; The number of enemies in the enemy class that was struck by the hammer (used to identify which enemy data structure was struck)

CURRENT_STATE_VAR_POINTER			= $63c0	; Points to the variable that controls the current game state

LADDER_JUMP_VECTOR_POINTER			= $63c2	; Points to the current vector data for Donkey Kong's jump from the ladder to the platform on the introduction stage
PLATFORM_JUMP_VECTOR_POINTER		= $63c4	; Points to the current vector data for Donkey Kong's jumps across the platform on the introduction stage

CURRENT_FIREBALL					= $63c8	; Points to the fireball currently being processed (2 bytes)

DEMO_INPUT_INDEX					= $63cc
DEMO_INPUT_REPEAT					= $63cd

FIREBALL_STRUCTS					= $6400
	; This is the start of a series of 5 32-byte data structures representing 
	; the state of the active fire balls on a stage
	; The structure layout is as follows:
	;
	;  0 - Fire ball active (0 or 1)?
	;
	;  3 - x coordinate of the fire ball
	;  
	;  5 - y coordinate of the fire ball
	;
	;  7 - The sprite number of the fire ball sprite
	;  8 - The sprite palette 
	;
	; 13 - The fireball direction
	;		0 - standing still
	;		1 - moving right
	;		2 - moving left
	;		4 - moving down
	;		8 - moving up
	; 14 - The next intended x coordinate
	; 15 - The next intended y coordinate
	;
	; 19 - The bob table index - controls how the fireball seems to bob as it moves
	; 20 - The climb update counter - the fireball is moved up or down the current ladder when this reaches 0
	; 21 - The sprite update counter - the sprite image is updated when this reaches 0
	; 22 - The direction counter - the fireball continues in the current diection (left or right) until this reaches 0 - it may still go up and down ladders, however
	;
	; 24 - Not initialized - the fireball has not been initialized yet if this is 1
	; 25 - Pause mode - the fireball pauses for a while when this equals 2
	; 26,27 - The oil barrel jump pointer - pointer to the entry in a table of y coodinates for the fireball as it initially jumps out of the oil barrel on the barrels stage
	; 28 - Pause timer - the fireball stops being paused when this reaches 0
	; 29 - Pause mode (2) - the fireball is paused when this equals 1
	;
	; 31 - The y coordinate of the other end of the ladder currently being climbed
FIREBALL_STRUCT_1					= $6400
FIREBALL_STRUCT_2					= $6420
FIREBALL_STRUCT_3					= $6440
FIREBALL_STRUCT_4					= $6460
FIREBALL_STRUCT_5					= $6480

COLLISION_AREA_STRUCT				= $64a0
	; This is the start of 2 32-byte data structures representing 
	; invisible collision detection sprites
	;
	;  0 - Sprite active (0 or 1)?
	;
	;  3 - x coordinate of the sprite
	;  
	;  5 - y coordinate of the sprite
	;
	;  7 - The sprite number of the sprite
	;  8 - The sprite palette 
	
SPRING_STRUCTS						= $6500
	; This is the start of a series of 10 16-byte data structures representing 
	; the state of the active springs on the elevators stage
	; The structure layout is as follows:
	;
	;  0 - Spring active (0 or 1)?
	;
	;  3 - x coordinate of the spring?
	;  
	;  5 - y coordinate of the spring
	;
	;  7 - The sprite number of the spring sprite
	;  8 - The sprite palette 
	; 
	; 13 - The spring state
	;	1 = bouncing
	;	4 = falling
	; 14 - The most significant byte of the address of the next bounce vector
	; 15 - The least significant byte of the address of the next bounce vector

PIE_STRUCTS							= $65A0
	; This is the start of a series of 6 16-byte data structures representing 
	; the state of the pies on the mixer stage
	; The structure layout is as follows:
	;
	;  0 - pie active (0 or 1)
	; 
	;  3 - x coordinate of the pie
	;  
	;  5 - y coordinate of the pie
	;
	;  7 - The sprite number of the pie sprite
	;  8 - The sprite palette 
	;
	
ELEVATOR_STRUCTS					= $6600
	; This is the start of a series of 6 16-byte data structures representing 
	; the state of the elevator platforms on a stage
	; The structure layout is as follows:
	;
	;  0 - elevator active (0 or 1)
	; 
	;  3 - x coordinate of the elevator
	;  
	;  5 - y coordinate of the elevator
	;
	;  7 - The sprite number of the elevator sprite
	;  8 - The sprite palette 
	;  9 - The radial width of the elevator's collision boundary
	; 10 - The radial height of the elevator's collision boundary
	;
	; 12 - The move counter of the elevators on the secret stage
	; 13 - The direction (8 if the elevator is moving up, 4 if it is moving down)
	;      The direction of rotation on the secret stage
	;	      (0 = clockwise, 1 = counter-clockwise)
	; 14 - The current quadrant of movement for the secret stage
	;         1 | 2
	;	      --+--
	;	      0 | 3
ELEVATOR_STRUCT_1					= $6600
ELEVATOR_STRUCT_2					= $6610
ELEVATOR_STRUCT_3					= $6620
ELEVATOR_STRUCT_4					= $6630
ELEVATOR_STRUCT_5					= $6640
ELEVATOR_STRUCT_6					= $6650

HAMMER_STRUCTS						= $6680
	; This is the start of a series of 2 16-byte data structures representing 
	; the state of the hammers on a stage
	; The structure layout is as follows:
	;
	;  0 - hammer active (0 or 1)
	;  1 - Mario has hammer (0 or 1) 
	; 
	;  3 - x coordinate of the hammer
	;  
	;  5 - y coordinate of the hammer
	;
	;  7 - The sprite number of the hammer sprite
	;  8 - The sprite palette 
	;  9 - Collision boundary x radius (distance from the center of the sprite)
	; 10 - Collision boundary y radius (distance from the center of the sprite)
	;
	; 14 - X coordinate offset from Mario (-16 = to Mario's left, 16 = to Mario's right, 0 = above Mario)
	; 15 - Y coordinate offset from Mario (-16 = above Mario, 0 = to Mario's left or right)
	; 
HAMMER_STRUCT_1						= $6680	
HAMMER_STRUCT_2						= $6690
BARREL_FIRE_STRUCT					= $66a0
	; This is a 32-byte data structure representing the state of the barrel fire
	; on the barrels and mixer stages
	; The structure layout is as follows:
	;
	;  0 - Barrel fire active (0 or 1)?
	;
	;  3 - Barrel fire sprite x coordinate
	;
	;  5 - Barrel fire sprite y coordinate
	;
	;  7 - Barrel fire sprite number
	;  8 - Barrel fire sprite palette

BARREL_STRUCTS						= $6700
	; This is the start of 10 32-byte data structures 
	; representing the state of the barrels on the barrels stage
	; The structure layout is as follows:
	;
	;  0 - Barrel active (0 or 1)?
	;
	;  3 - Barrel sprite x coordinate
	;
	;  5 - Barrel sprite y coordinate
	;
	;  7 - Barrel sprite number
	;  8 - Barrel sprite palette
	;
	; 21 - Barrel type (0 = normal barrel, 1 = oil barrel)

SPRITE_STRUCTS						= $6900
	; This is the start of a series of ??? 4-byte data structures for the 
	; active sprites in the game.
	; The Sprite data structures continue to $6a7f
	; The structure layout is as follows:
	;
	;  0 - The x coordinate of the sprite
	;  1 - The sprite graphic number
	;      If bit 1 of this byte is 1 then the graphic is flipped horizontally
	;  2 - The palette to use for the sprite
	;      If bit 1 of this byte is 1 then the graphic is flipped vertically
	;  3 - The y coordinate of the sprite

PAULINE_SPRITES						= $6900
	; The 2 sprites that make up PAULINE
PAULINE_UPPER_SPRITE_X				= $6900
PAULINE_UPPER_SPRITE_NUM			= $6901
PAULINE_UPPER_SPRITE_PAL			= $6902
PAULINE_UPPER_SPRITE_Y				= $6903
PAULINE_LOWER_SPRITE_X				= $6904
PAULINE_LOWER_SPRITE_NUM			= $6905
PAULINE_LOWER_SPRITE_PAL			= $6906
PAULINE_LOWER_SPRITE_Y				= $6907

DK_SPRITES							= $6908
	; This marks the start of the 10 sprites that 
	; make up Donkey Kong.  The last sprite ends at
	; $6929.
DK_SPRITE_1_X						= $6908
DK_SPRITE_1_NUM						= $6909
DK_SPRITE_1_PAL						= $690a
DK_SPRITE_1_Y						= $690b
DK_SPRITE_2_X						= $690c
DK_SPRITE_2_NUM						= $690d
DK_SPRITE_2_PAL						= $690e
DK_SPRITE_2_Y						= $690f
DK_SPRITE_3_X						= $6910
DK_SPRITE_3_NUM						= $6911
DK_SPRITE_3_PAL						= $6912
DK_SPRITE_3_Y						= $6913
DK_SPRITE_4_X						= $6914
DK_SPRITE_4_NUM						= $6915
DK_SPRITE_4_PAL						= $6916
DK_SPRITE_4_Y						= $6917
DK_SPRITE_5_X						= $6918
DK_SPRITE_5_NUM						= $6919
DK_SPRITE_5_PAL						= $691a
DK_SPRITE_5_Y						= $691b
DK_SPRITE_6_X						= $691c
DK_SPRITE_6_NUM						= $691d
DK_SPRITE_6_PAL						= $691e
DK_SPRITE_6_Y						= $691f
DK_SPRITE_7_X						= $6920
DK_SPRITE_7_NUM						= $6921
DK_SPRITE_7_PAL						= $6922
DK_SPRITE_7_Y						= $6923
DK_SPRITE_8_X						= $6924
DK_SPRITE_8_NUM						= $6925
DK_SPRITE_8_PAL						= $6926
DK_SPRITE_8_Y						= $6927
DK_SPRITE_9_X						= $6928
DK_SPRITE_9_NUM						= $6929
DK_SPRITE_9_PAL						= $692a
DK_SPRITE_9_Y						= $692b
DK_SPRITE_10_X						= $692c
DK_SPRITE_10_NUM					= $692d
DK_SPRITE_10_PAL					= $692e
DK_SPRITE_10_Y						= $692f
; Start of the two retractable ladder sprites on the mixer level
RETRACTABLE_LADDER_SPRITES			= $6944
L_RETRACT_LADDER_SPRITE				= $6944
L_RETRACT_LADDER_SPRITE_X			= $6944
L_RETRACT_LADDER_SPRITE_NUM			= $6945
L_RETRACT_LADDER_SPRITE_PAL			= $6946
L_RETRACT_LADDER_SPRITE_Y			= $6947
R_RETRACT_LADDER_SPRITE				= $6948
R_RETRACT_LADDER_SPRITE_X			= $6948
R_RETRACT_LADDER_SPRITE_NUM			= $6949
R_RETRACT_LADDER_SPRITE_PAL			= $694a
R_RETRACT_LADDER_SPRITE_Y			= $694b
; Start of Mario's sprite
MARIO_SPRITE						= $694c
MARIO_SPRITE_X						= $694c
MARIO_SPRITE_NUM					= $694d
MARIO_SPRITE_PAL					= $694e
MARIO_SPRITE_Y						= $694f
; Sprite data for two invisible collision detection sprites
COLLISION_AREA_SPRITES				= $6950
COLLISION_AREA_SPRITE_1				= $6950
COLLISION_AREA_SPRITE_2				= $6954
; Sprite data for the elevator platforms on the elevators stage
; 6 sprites
ELEVATOR_PLATFORM_SPRITES			= $6958
ELEVATOR_PLATFORM_SPRITE_1			= $6958
ELEVATOR_PLATFORM_SPRITE_2			= $695c
ELEVATOR_PLATFORM_SPRITE_3			= $6960
ELEVATOR_PLATFORM_SPRITE_4			= $6964
ELEVATOR_PLATFORM_SPRITE_5			= $6968
ELEVATOR_PLATFORM_SPRITE_6			= $696c
; Sprite data for the 4 evelator motors on the elevators stage
; 16 bytes
ELEVATOR_MOTOR_SPRITE_DATA			= $6970
ELEVATOR_MOTOR_SPRITE_1				= $6970
ELEVATOR_MOTOR_SPRITE_1_X			= $6970
ELEVATOR_MOTOR_SPRITE_1_NUM			= $6971
ELEVATOR_MOTOR_SPRITE_1_PAL			= $6972
ELEVATOR_MOTOR_SPRITE_1_Y			= $6973
ELEVATOR_MOTOR_SPRITE_2				= $6974
ELEVATOR_MOTOR_SPRITE_2_X			= $6974
ELEVATOR_MOTOR_SPRITE_2_NUM			= $6975
ELEVATOR_MOTOR_SPRITE_2_PAL			= $6976
ELEVATOR_MOTOR_SPRITE_2_Y			= $6977
ELEVATOR_MOTOR_SPRITE_3				= $6978
ELEVATOR_MOTOR_SPRITE_3_X			= $6978
ELEVATOR_MOTOR_SPRITE_3_NUM			= $6979
ELEVATOR_MOTOR_SPRITE_3_PAL			= $697a
ELEVATOR_MOTOR_SPRITE_3_Y			= $697b
ELEVATOR_MOTOR_SPRITE_4				= $697c
ELEVATOR_MOTOR_SPRITE_4_X			= $697c
ELEVATOR_MOTOR_SPRITE_4_NUM			= $697d
ELEVATOR_MOTOR_SPRITE_4_PAL			= $697e
ELEVATOR_MOTOR_SPRITE_4_Y			= $697f
; Start of the 10 spring sprites
SPRING_SPRITES						= $6980		; This is the start of the spring sprite data
SPRING_SPRITE_1						= $6980		
SPRING_SPRITE_2						= $6984		
SPRING_SPRITE_3						= $6988		
SPRING_SPRITE_4						= $698c		
SPRING_SPRITE_5						= $6990		
SPRING_SPRITE_6						= $6994		
SPRING_SPRITE_7						= $6998		
SPRING_SPRITE_8						= $699c		
SPRING_SPRITE_9						= $69a0		
SPRING_SPRITE_10					= $69a4
; Sprite data for the four standing barrels on the barrels stage
STANDING_BARREL_SPRITE_DATA			= $69a8
STANDING_BARREL_SPRITE_1			= $69a8
STANDING_BARREL_SPRITE_1_X			= $69a8
STANDING_BARREL_SPRITE_1_NUM		= $69a9
STANDING_BARREL_SPRITE_1_PAL		= $69aa
STANDING_BARREL_SPRITE_1_Y			= $69ab
STANDING_BARREL_SPRITE_2			= $69ac
STANDING_BARREL_SPRITE_2_X			= $69ac
STANDING_BARREL_SPRITE_2_NUM		= $69ad
STANDING_BARREL_SPRITE_2_PAL		= $69ae
STANDING_BARREL_SPRITE_2_Y			= $69af
STANDING_BARREL_SPRITE_3			= $69b0
STANDING_BARREL_SPRITE_3_X			= $69b0
STANDING_BARREL_SPRITE_3_NUM		= $69b1
STANDING_BARREL_SPRITE_3_PAL		= $69b2
STANDING_BARREL_SPRITE_3_Y			= $69b3
STANDING_BARREL_SPRITE_4			= $69b4
STANDING_BARREL_SPRITE_4_X			= $69b4
STANDING_BARREL_SPRITE_4_NUM		= $69b5
STANDING_BARREL_SPRITE_4_PAL		= $69b6
STANDING_BARREL_SPRITE_4_Y			= $69b7
; Pie sprites (6 sprites in all)
PIE_SPRITES							= $69b8
PIE_SPRITE_1						= $69b8
PIE_SPRITE_2						= $69bc
PIE_SPRITE_3						= $69c0
PIE_SPRITE_4						= $69c4
PIE_SPRITE_5						= $69c8
PIE_SPRITE_6						= $69cc
; Fireball sprites (5 sprites in all)
FIREBALL_SPRITES					= $69d0
FIREBALL_SPRITE_1					= $69d0
FIREBALL_SPRITE_2					= $69d4
FIREBALL_SPRITE_3					= $69d8
FIREBALL_SPRITE_4					= $69dc
FIREBALL_SPRITE_5					= $69e0
; Conveyer belt motor sprites (6 sprites)
CONVEYER_MOTOR_SPRITES				= $69e4
; Top left conveyer motor
CONV_MOTOR_SPRITE_TL				= $69e4
CONV_MOTOR_SPRITE_TL_X				= $69e4
CONV_MOTOR_SPRITE_TL_NUM			= $69e5
CONV_MOTOR_SPRITE_TL_PAL			= $69e6
CONV_MOTOR_SPRITE_TL_Y				= $69e7
; Top right conveyer motor
CONV_MOTOR_SPRITE_TR				= $69e8
CONV_MOTOR_SPRITE_TR_X				= $69e8
CONV_MOTOR_SPRITE_TR_NUM			= $69e9
CONV_MOTOR_SPRITE_TR_PAL			= $69ea
CONV_MOTOR_SPRITE_TR_Y				= $69eb
; Middle right conveyer motor
CONV_MOTOR_SPRITE_MR				= $69ec
CONV_MOTOR_SPRITE_MR_X				= $69ec
CONV_MOTOR_SPRITE_MR_NUM			= $69ed
CONV_MOTOR_SPRITE_MR_PAL			= $69ee
CONV_MOTOR_SPRITE_MR_Y				= $69ef
; Middle left conveyer motor
CONV_MOTOR_SPRITE_ML				= $69f0
CONV_MOTOR_SPRITE_ML_X				= $69f0
CONV_MOTOR_SPRITE_ML_NUM			= $69f1
CONV_MOTOR_SPRITE_ML_PAL			= $69f2
CONV_MOTOR_SPRITE_ML_Y				= $69f3
; Bottom left conveyer motor
CONV_MOTOR_SPRITE_BL				= $69f4
CONV_MOTOR_SPRITE_BL_X				= $69f4
CONV_MOTOR_SPRITE_BL_NUM			= $69f5
CONV_MOTOR_SPRITE_BL_PAL			= $69f6
CONV_MOTOR_SPRITE_BL_Y				= $69f7
; Bottom right conveyer motor
CONV_MOTOR_SPRITE_BR				= $69f8
CONV_MOTOR_SPRITE_BR_X				= $69f8
CONV_MOTOR_SPRITE_BR_NUM			= $69f9
CONV_MOTOR_SPRITE_BR_PAL			= $69fa
CONV_MOTOR_SPRITE_BR_Y				= $69fb
; The oil barrel sprite
OIL_BARREL_SPRITE					= $69fc
OIL_BARREL_SPRITE_X					= $69fc
OIL_BARREL_SPRITE_NUM				= $69fd
OIL_BARREL_SPRITE_PAL				= $69fe
OIL_BARREL_SPRITE_Y					= $69ff

; Prize sprites (3 sprites)
PRIZE_SPRITES						= $6a0c
PRIZE_SPRITE_1						= $6a0c
PRIZE_SPRITE_2						= $6a10
PRIZE_SPRITE_3						= $6a14
; The start of the two hammer sprites on a level
HAMMER_SPRITES						= $6a18
HAMMER_SPRITE_1						= $6a18
HAMMER_SPRITE_2						= $6a1c

HEART_SPRITE						= $6a20
HEART_SPRITE_X						= $6a20
HEART_SPRITE_NUM					= $6a21
HEART_SPRITE_PAL					= $6a22
HEART_SPRITE_Y						= $6a23
DK_STARS_SPRITE						= $6a24
DK_STARS_SPRITE_X					= $6a24
DK_STARS_SPRITE_NUM					= $6a25
DK_STARS_SPRITE_PAL					= $6a26
DK_STARS_SPRITE_Y					= $6a27
BARREL_FIRE_SPRITE					= $6a28	; The oil barrel fire sprite
BARREL_FIRE_SPRITE_X				= $6a28			
BARREL_FIRE_SPRITE_NUM				= $6a29
BARREL_FIRE_SPRITE_PAL				= $6a2a
BARREL_FIRE_SPRITE_Y				= $6a2b
SMASH_SPRITE						= $6a2c	; The smash animation sprite (displayed when Mario hits an enemy with the hammer)
SMASH_SPRITE_X						= $6a2c
SMASH_SPRITE_NUM					= $6a2d
SMASH_SPRITE_PAL					= $6a2e
SMASH_SPRITE_Y						= $6a2f
AWARD_SPRITE						= $6a30
AWARD_SPRITE_X						= $6a30
AWARD_SPRITE_NUM					= $6a31
AWARD_SPRITE_PAL					= $6a32
AWARD_SPRITE_Y						= $6a33
	
P1_INPUT							= $7c00
P1_INPUT_RESET_BIT						= 6		; Reset game?
P1_INPUT_JUMP_BIT						= 5		; Jump button
P1_INPUT_DOWN_BIT						= 3
P1_INPUT_UP_BIT							= 2
P1_INPUT_LEFT_BIT						= 1
P1_INPUT_RIGHT_BIT						= 0

SONG_OUTPUT							= $7c00

P2_INPUT							= $7c80
P2_INPUT_RESET_BIT						= 6		; Reset game?
P2_INPUT_JUMP_BIT						= 5		; Jump button
P2_INPUT_DOWN_BIT						= 3
P2_INPUT_UP_BIT							= 2
P2_INPUT_LEFT_BIT						= 1
P2_INPUT_RIGHT_BIT						= 0

MISC_INPUT							= $7d00
MISC_INPUT_COIN_BIT						= 7		; Coin entered
MISC_INPUT_START_2P_BIT					= 3		; 2 player start
MISC_INPUT_START_1P_BIT					= 2		; 1 player start
MISC_INPUT_TAMPER_BIT					= 0		; If this is 1, the code jumps to l4000

WALK_SOUND_OUTPUT					= $7d00		; Causes the walking sound to play
JUMP_SOUND_OUTPUT					= $7d01		; Causes the jumping sound to play
STOMP_SOUND_OUTPUT					= $7d02		; Causes the Donkey Kong stomping sound to play
SPRING_SOUND_OUTPUT					= $7d03		; Causes the spring bounce sound to play
FALL_SOUND_OUTPUT					= $7d04		; Causes the falling spring sound to play

TIME_RUNNING_OUT_SOUND_OUTPUT		= $7d09		; Causes the time running out sound to play

DIP_INPUT							= $7d80
	; Bit 7 Cocktail (0) or Upright (1)
	; Bit 6 \ 000 = 1 coin/1 play  001 = 1 coin/2 play  010 = 1 coin/3 play
	; Bit 5 | 011 = 1 coin/4 play  100 = 2 coin/1 play  101 = 3 coin/1 play
	; Bit 4 / 110 = 4 coin/1 play  111 = 5 coin/1 play
	; Bit 3 \ Bonus at
	; Bit 2 / 00 = 7000  01 = 10000  10 = 15000  11 = 20000
	; Bit 1 \ 00 = 3 lives  01 = 4 lives
	; Bit 0 / 10 = 5 lives  11 = 6 lives

DEATH_SOUND_OUTPUT					= $7d80

SCREEN_ORIENTATION					= $7d82
	; 0 = flipped
	; 1 = standard

INTERRUPT_ENABLE            		= $7d84

PALETTE_1_OUTPUT					= $7d86
PALETTE_2_OUTPUT					= $7d87

