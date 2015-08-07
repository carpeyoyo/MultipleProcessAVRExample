; Joshua Mazur
; Ripple Program for avr microcontroller attiny2313

.include "tn4313def.inc"
	
.cseg
.org 0

; Jump Table
rjmp reset
.org OC1Aaddr
rjmp scheduler

; Variable defintions, small enough to act like registers are variables.
.def offset = r16
.def count1 = r17
.def count2 = r18
.def count3 = r19
.def led = r20 ; used for loading led value to port
.def temp = r21 ; used for stack intialization
.def temp2 = r22
.def temp3 = r23

reset:
	; Setting output ports
	ldi led,0xFF  
	out ddrb,led
	out ddrd,led

	; Real stack, not really used during actual program. 
	ldi temp,low(RAMEND)
	out SPL,temp
	ldi temp,high(RAMEND)
	out SPH,temp

	; Configuring timer interrupt

	.equ PRESCALE=0b101
	.equ PRESCALE_DIV=1
	.equ WGM=0b011
	.equ TOP = 65535
	.if TOP>65535
	.error "Top is out of range"
	.endif

	ldi temp,high(TOP)
	out OCR1AH,temp
	ldi temp,low(TOP)
	out OCR1AL,temp
	ldi temp, ((WGM&0b11) << WGM10)
	out TCCR1A,temp
	ldi temp,((WGM>>2)<<WGM12)|(PRESCALE<<CS10)
	out TCCR1B,temp

	ldi temp,1<<OCIE1A
	out TIFR,temp
	out TIMSK,temp

	; Setting up sram

	.dseg
	lights: .byte 10
	.cseg

	ldi YL,low(lights)
	ldi YH,high(lights)
	
	ldi temp,0b00000001 ; first
	st Y+,temp

	ldi temp,0b00000010 ; second
	st Y+,temp

	ldi temp,0b00000100 ; third
	st Y+,temp

	ldi temp,0b00001000 ; fourth
	st Y+,temp

	ldi temp,0b00010000 ; fifth
	st Y+,temp

	ldi temp,0b00100000 ; sixth
	st Y+,temp

	ldi temp,0b00010000 ; seventh
	st Y+,temp

	ldi temp,0b00001000 ; eighth
	st Y+,temp

	ldi temp,0b00000100 ; ninth
	st Y+,temp

	ldi temp,0b00000010 ; tenth
	st Y+,temp

	; tempary bit flip
	clr temp2
	ldi temp3,0x01

	; Setting intial properites for process
	; set up first process last so right stack is in place
	rcall send_out_init
	rcall send_out_setup

	;rjmp first_process

scheduler: ; this is called by the timer interrupt

	in temp,SREG

	eor temp2,temp3
	out PORTD,temp2

	out SREG,temp

	reti

send_out_init:

	pop ZH
	pop ZL

	.equ stack_size = 50
	; tempary stack sort of
	.dseg
	temp_stack: .byte stack_size
	.cseg

	; Intializing stack this stack
	ldi temp,low((temp_stack + (stack_size -1)))
	out SPL,temp
	ldi temp,high((temp_stack + (stack_size -1)))
	out SPH,temp

	; first thing on stack in address of sendout
	ldi temp,low(send_out)
	push temp
	ldi temp,high(send_out)
	push temp
	
	; creating initial values
	clr XL
	clr XH

	; getting current sreg
	in temp,SREG

	; setting up initial stack
	push temp ; for sreg
	push YH
	push YL
	push XL
	push XH
	push led
	push count1
	push count2
	push count3

	; storing stack location
	.dseg
	temp_stack_address: .byte 2
	.cseg

	ldi YL,low(temp_stack_address)
	ldi YH,high(temp_stack_address)

	in temp,SPL
	st Y+,temp
	in temp,SPH
	st Y,temp

	ijmp

send_out_setup:
	pop ZH ; these will be for the scheduler
	pop ZL

	; retrieve stack address
	ldi YL,low(temp_stack_address)
	ldi YH,high(temp_stack_address)

	; setting stack pointer back to last position
	ld temp,Y+
	out SPL,temp
	ld temp,Y
	out SPH,temp	

	; retrieving variables
	pop count3
	pop count2
	pop count1
	pop led
	pop XH
	pop XL
	pop YL
	pop YH
	pop temp ; for SREG

	; setting SREG
	out SREG,temp

	;returning to last address on stack
	reti

send_out:
	; retrieving base address
	ldi YH, high(lights)
	ldi YL, low(lights)

	; finding offset
	add YL,XL
	adc YH,XH

	; outputting state
	ld led,Y
	out PORTB,led

	; wasting time
	clr count1
	clr count2
	clr count3
	
	send_out_loop_1:
		send_out_loop_2:
			send_out_loop_3:
				inc count3
				cpi count3,0x00
				breq send_out_loop_3_end
				rjmp send_out_loop_3
			send_out_loop_3_end:
			inc count2
			cpi count2,0x00
			breq send_out_loop_2_end
			rjmp send_out_loop_2
		send_out_loop_2_end:
		inc count1
		cpi count1,0x03
		breq send_out_loop_1_end
		rjmp send_out_loop_1
	send_out_loop_1_end:

	; finding next offset
	inc XL
	cpi XL,0x0a
	brne send_out
	clr XL
	rjmp send_out


