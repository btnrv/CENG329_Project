;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file

;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.
;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer
;----------------------------------------------------------------------------

;; Game initialization
;; P1.0, P1.6 player LEDs
;; P1.1, P1.2, P1.3, P1.4, P1.5, P1.7, P2.0, P2.5 -> 7-segment display
;; P2.3, P2.4 player buttons
;; R4: Counter, counts 3-2-1-0
;; R6: Reset flag 1=Resetting 0=Playing

	bic.b #01000001b, &P1SEL               ; P1.0, P1.6 -> Digital I/O
    bic.b #01000001b, &P1SEL2

    bis.b #11111111b, &P1DIR               ; Set P1.1, 2, 4, 5, 7 -> Output
    bis.b #00100001b, &P2DIR               ; Set P2.0 and P2.5 -> Output

    bic.b #00011000b, &P2DIR               ; P2.3, P2.4 -> Input
    bis.b #00011000b, &P2REN               ; Enable pull-up/down resistors
    bis.b #00011000b, &P2OUT               ; Enable pull-up resistors

    bis.w #GIE,SR                          ; Enable global interrupts

START_GAME:
	; Clear all LEDs
    bis.b #10111110b, &P1OUT
    bic.b #01000001b, &P1OUT
	bis.b #00100001b, &P2OUT
	call #DELAY ; Delay to prevent button double clicking issues

    bic.b #00011000b, &P2IFG               ; Clear interrupt flags
    bis.b #00011000b, &P2IE                ; Enable interrupts on buttons
    bis.b #00011000b, &P2IES               ; High-to-low transition
	mov.w #0, r6 ; Reset reset flag
    call #COUNTER                          ; Start countdown

GAME_LOOP:
    jmp GAME_LOOP

RESET_MODE:
    call #DISPLAY_DASH
    call #DELAY
	call #TOGGLE_DOT
	mov.w #1, r6 						   ; Set reset flag
	bic.b #00011000b, &P2IFG
	bis.b #00011000b, &P2IE 			   ; enable interrupts for early reset mechanism. dot on = can early reset
    call #DELAY
    call #DELAY
	call #TOGGLE_DOT
    jmp START_GAME

; Countdown timer
COUNTER:
    mov.w #3,r4
    call #DISPLAY_3
    call #DELAY
    dec.w r4
    call #DISPLAY_2
    call #DELAY
    dec.w r4
    call #DISPLAY_1
    call #DELAY
    dec.w r4
    call #DISPLAY_0
    ret

; Player 1 wins when counter is 0
PLAYER1_IN:
    cmp #0,r4
    jne PLAYER2_WIN
PLAYER1_WIN:
    bis.b #00000001b, &P1OUT               ; P1 wins, light up P1.0 LED
    ret

; Player 2 wins when counter is 0
PLAYER2_IN:
    cmp #0,r4
    jne PLAYER1_WIN
PLAYER2_WIN:
    bis.b #01000000b, &P1OUT               ; P2 wins, light up P1.6 LED
    ret

; Delay subroutine
DELAY:
    mov.w #65000, r10
DELAY_L1:
    dec.w r10
    jnz DELAY_L1
    mov.w #65000, r10
DELAY_L2:
    dec.w r10
    jnz DELAY_L2
    mov.w #65000, r10
DELAY_L3:
    dec.w r10
    jnz DELAY_L3
    mov.w #65000, r10
DELAY_L4:
    dec.w r10
    jnz DELAY_L4
    mov.w #65000, r10
DELAY_L5:
    dec.w r10
    jnz DELAY_L5
    ret

; 7-segment display routines
TURN_OFF:
    bis.b #10111110b, &P1OUT               ; Turn off segments
    bis.b #00100000b, &P2OUT
    ret
DISPLAY_1:
    call #TURN_OFF
    bic.b #00001100b, &P1OUT               ; Segments b, c
    ret
DISPLAY_2:
    call #TURN_OFF
    bic.b #00110110b, &P1OUT
    bic.b #00100000b, &P2OUT
    ret
DISPLAY_3:
    call #TURN_OFF
    bic.b #00100000b, &P2OUT
    bic.b #00011110b, &P1OUT
    ret
DISPLAY_0:
    call #TURN_OFF
    bic.b #10111110b, &P1OUT
    ret
DISPLAY_DASH:
    call #TURN_OFF
    bic.b #00100000b, &P2OUT
    ret
TOGGLE_DOT:
    xor.b #00000001b, &P2OUT    ; Toggle P2.0 in P2OUT
    ret
; Button interrupt service routine
PORT2_ISR:
    bic.b #00011000b, &P2IE                ; Disable button interrupts

	cmp.w #1, r6 ; Check reset flag
	jne PROCESS_GAME
	mov.w #0, r6 ; Reset reset flag
	bic.b #00011000b, &P2IFG               ; Clear interrupt flags
	mov.w #START_GAME, 2(sp)               ; Modify saved PC for RESET_MODE
    reti

PROCESS_GAME:
    bit.b #00011000b, &P2IFG
    jne NOT_DRAW
    bis.b #01000001b, &P1OUT
    jmp AFTER_2_4
NOT_DRAW:
    bit.b #00001000b, &P2IFG
    jne HANDLE_2_3
    bit.b #00010000b, &P2IFG
    jne HANDLE_2_4
HANDLE_2_3:
    call #PLAYER1_IN
    jmp AFTER_2_4
HANDLE_2_4:
    call #PLAYER2_IN
AFTER_2_4:
    mov.w #RESET_MODE, 2(sp)               ; Modify saved PC for RESET_MODE
    reti

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack

;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            .sect ".int03"
            .short PORT2_ISR