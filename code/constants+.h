; Various constants used in Donkey Kong

; The following macro allows tile coordinates to be entered as x,y coordinates rather
; than bare memory addresses
#define		TILE_COORD(x,y)			$7400 + (x * 32) + y

; The following macro combines two bytes into a single word
;#define		TWO_BYTES(a,b)			(b & $ff) | ((a & $ff) << 8) & $ffff
#define		TWO_BYTES(a,b)			(a * 256) + b

; The following macro assembles a block of stage data given:
;	t - the tile type
;	x1, y1 - the starting coordinate of the line of tiles
;	x2, y2 - the ending coordinate of the line of tiles
#define		STAGE_DATA(t,x1,y1,x2,y2) .byte (t)\ .word ((y1<<11) | (x1<<3) & $ffff) \ .word ((y2<<11) + (x2<<3) & $ffff)
#define		NRM_LAD_STAGE_DATA(x1,y1,x2,y2) .byte 0\ .word ((y1<<11) | (x1<<3 | 0011) & $ffff) \ .word ((y2<<11) | (x2<<3 | 0011) & $ffff)
#define		BRK_LAD_STAGE_DATA(x1,y1,x2,y2) .byte 1\ .word ((y1<<11) | (x1<<3 | 0011) & $ffff) \ .word ((y2<<11) | (x2<<3 | 0011) & $ffff)
#define		X_STAGE_DATA(x1,y1,x2,y2) .byte 6\ .word ((y1<<11) | (x1<<3 | 0011) & $ffff) \ .word ((y2<<11) | (x2<<3 | 0011) & $ffff)
; The following macro converts an x,y coordinate into a stage data location
#define		STAGE_COORD(x,y)		((y<<11) | (x<<3)) & $ffff
#define		STAGE_DATA_END 			.byte 	$AA

; Collision area sprites
K_COLLISION_SPRITE_NUM				= $3f	; The sprite number used for the collision sprites aroung Donkey Kong
K_COLLISION_SPRITE_PAL				= $0c
K_COLLISION_SPRITE_WIDTH			= 8
K_COLLISION_SPRITE_HEIGHT			= 8

K_COLLISION_1_X_RIVETS				= 115	; X coordinate of the 1st collision sprite
K_COLLISION_1_Y_RIVETS				= 80	; Y coordinate of the 1st collision sprite
K_COLLISION_2_X_RIVETS				= 141	; X coordinate of the 2nd collision sprite
K_COLLISION_2_Y_RIVETS				= 80	; Y coordinate of the 2nd collision sprite

K_COLLISION_X_BARRELS				= 70	; X coordinate of the collision sprite on the barrels and elevators stages
K_COLLISION_Y_BARRELS				= 76	; Y coordinate of the collision sprite on the barrels and elevators stages

K_COLLISION_X_ELEVATORS				= 70	; X coordinate of the collision sprite on the barrels and elevators stages
K_COLLISION_Y_ELEVATORS				= 80	; Y coordinate of the collision sprite on the barrels and elevators stages

; Mario's starting coordinate on the barrels, mixer, and rivets stages
MARIO_START_COORD					= TWO_BYTES(240,63) ; (63,240)

; Mario's starting coordinate on the elevators stage
MARIO_START_COORD_ELEVATORS			= TWO_BYTES(224,22)	; (22,224)
