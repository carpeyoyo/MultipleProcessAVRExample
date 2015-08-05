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

reset:
	; Setting output port
	ldi led,0xFF  
	out ddrb,led

	; Intializing stack.
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
	clr XH
	clr XL
	ldi YH, high(lights)
	ldi YL, low(lights)
	
	ldi temp,0b00000001 ; first
	st Y,temp

	ldi temp,0b00000010 ; second
	inc XL
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00000100 ; third
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00001000 ; fourth
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00010000 ; fifth
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00100000 ; sixth
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00010000 ; seventh
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00001000 ; eighth
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00000100 ; ninth
	add YL,XL
	adc YH,XH
	st Y,temp

	ldi temp,0b00000010 ; tenth
	add YL,XL
	adc YH,XH
	st Y,temp

	clr XL

	;ldi led,0xff
	;out PORTB,led

	; enable global interrupts
	sei

main:
	rcall send_out
	rjmp main

scheduler: ; this is called by the timer interrupt
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
	brne send_out_end
	clr XL

	send_out_end:
	ret


