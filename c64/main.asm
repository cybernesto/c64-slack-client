!cpu 6510
!to "./build/slack-client.prg",cbm
!zone main
!source "macros.asm"


BASIC_START = $0801
CODE_START = $9000

* = BASIC_START
!byte 12,8,0,0,158
!if CODE_START >= 10000 {!byte 48+((CODE_START/10000)%10)}
!if CODE_START >= 1000 {!byte 48+((CODE_START/1000)%10)}
!if CODE_START >= 100 {!byte 48+((CODE_START/100)%10)}
!if CODE_START >= 10 {!byte 48+((CODE_START/10)%10)}
!byte 48+(CODE_START % 10),0,0,0

; load resources into memory
!source "load_resources.asm"


* = CODE_START
	jmp init


screen_update_handler_ptr !word 0
keyboard_handler_ptr !word 0
flash_screen_on_data !byte 0
.dbg_pos !byte 0
.end_of_command !byte 0
.debug_output_offset !byte 0

init
	; disable BASIC rom
	lda $01
	and #%11111110
	sta $01

	jsr screen_clear
	jsr screen_enable_lowercase_chars

	jsr rs232_open
	jsr irq_init
	jsr wait_for_connection_screen_render

	+set16im cmd_buffer, COMMAND_BUFFER_PTR

.main_loop
	jsr keyboard_read
	jsr rs232_try_read_byte
	cmp #0
	bne .got_byte
	; tay 				; if we get \0, it could either be empty buffer or a \0 in the data 
	; lda RSSTAT
	; and #8 		; bit 3 in RSSTAT is high if recv buffer was empty
	; cmp #8
	;beq .main_loop
	;tya
	jmp .main_loop
.got_byte
	ldy flash_screen_on_data
	beq .skip_screen_flash
	inc $d020
.skip_screen_flash

	cmp #COMMAND_TRAILER_CHAR        ; is this the end-of-cmd marker?
	bne .add_byte_to_buffer
	ldy #1          ; if end-of-cmd, then set Y = 1
	sty .end_of_command
	lda #0          ; replace end-of-cmd with \0

.add_byte_to_buffer
	ldy #0
	sta (COMMAND_BUFFER_PTR), y
	+inc16 COMMAND_BUFFER_PTR

	ldy .end_of_command
	cpy #1          ; if not 'end of command', go back around
	bne .main_loop
	lda #14			; reset border color
	sta $d020
	jsr command_handler
	+set16im cmd_buffer, COMMAND_BUFFER_PTR
	ldx #0
	stx .end_of_command
;debugger
	jmp .main_loop


!source "defs.asm"
!source "screen.asm"
!source "rs232.asm"
!source "wait_for_connection_screen.asm"
!source "main_screen.asm"
!source "channels_screen.asm"
!source "message_screen.asm"
!source "string.asm"
!source "cmd_handler.asm"
!source "keyboard_input.asm"
!source "irq.asm"
!source "heartbeat.asm"
!source "memory.asm"
!source "shared_resources.asm"
!source "math.asm"
!source "logo_sprite.asm"

;!if * > $9fff {
;	!error "Program reached ROM: ", * - $d000, " bytes overlap."
;}
