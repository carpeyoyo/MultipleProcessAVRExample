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
	out ddra,led

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
	rcall send_out_portd_init
	rcall send_out_init

	; entering scheduler in correct place
	rjmp scheduler_entrance

scheduler: ; this is called by the timer interrupt

	in temp,SREG
	
	; creating blink
	push temp2
	push temp3
	in temp2,PORTA
	ldi temp3,0x01
	eor temp2,temp3
	out PORTA,temp2
	pop temp3
	pop temp2

	; going to correct place in this scheduler
	ijmp ; going to value stored in last init

	; actual scheduling
	scheduler_entrance:

	; first process
	rcall send_out_setup
	rcall scheduler_go_again
	rcall send_out_cleanup

	; second process
	rcall send_out_portd_setup
	rcall send_out_portd_cleanup

	rjmp scheduler_entrance


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The following functions are for the the send out to port b process.

scheduler_go_again:
	pop ZH
	pop ZL
	reti

send_out_init:

	pop ZH ; these are used to return at end of function
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

send_out_cleanup:
	; these will be used to go back to scheduler
	; at the end of this function
	pop ZH
	pop ZL

	push temp ; should contain SREG
	push YH
	push YL
	push XL
	push XH
	push led
	push count1
	push count2
	push count3

	; storing stack address
	ldi YL,low(temp_stack_address)
	ldi YH,high(temp_stack_address)

	in temp,SPL
	st Y+,temp
	in temp,SPH
	st Y,temp

	ijmp ; jump back to place in scheduler

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The following functions are for the the send out to port d process.

send_out_portd_init:

	pop ZH ; these are used to return at end of function
	pop ZL

	.equ stack_size_portd = 50
	; tempary stack sort of
	.dseg
	temp_stack_portd: .byte stack_size_portd
	.cseg

	; Intializing stack this stack
	ldi temp,low((temp_stack_portd + (stack_size_portd -1)))
	out SPL,temp
	ldi temp,high((temp_stack_portd + (stack_size_portd -1)))
	out SPH,temp

	; first thing on stack in address of send_out_portd
	ldi temp,low(send_out_portd)
	push temp
	ldi temp,high(send_out_portd)
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
	temp_stack_portd_address: .byte 2
	.cseg

	ldi YL,low(temp_stack_portd_address)
	ldi YH,high(temp_stack_portd_address)

	in temp,SPL
	st Y+,temp
	in temp,SPH
	st Y,temp

	ijmp

send_out_portd_setup:
	pop ZH ; these will be for the scheduler
	pop ZL

	; retrieve stack address
	ldi YL,low(temp_stack_portd_address)
	ldi YH,high(temp_stack_portd_address)

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

send_out_portd_cleanup:
	; these will be used to go back to scheduler
	; at the end of this function
	pop ZH
	pop ZL

	push temp ; should contain SREG
	push YH
	push YL
	push XL
	push XH
	push led
	push count1
	push count2
	push count3

	; storing stack address
	ldi YL,low(temp_stack_portd_address)
	ldi YH,high(temp_stack_portd_address)

	in temp,SPL
	st Y+,temp
	in temp,SPH
	st Y,temp

	ijmp ; jump back to place in scheduler

send_out_portd:
	; retrieving base address
	ldi YH, high(lights)
	ldi YL, low(lights)

	; finding offset
	add YL,XL
	adc YH,XH

	; outputting state
	ld led,Y
	out PORTD,led

	; wasting time
	clr count1
	clr count2
	clr count3
	
	send_out_portd_loop_1:
		send_out_portd_loop_2:
			send_out_portd_loop_3:
				inc count3
				cpi count3,0x00
				breq send_out_portd_loop_3_end
				rjmp send_out_portd_loop_3
			send_out_portd_loop_3_end:
			inc count2
			cpi count2,0x00
			breq send_out_portd_loop_2_end
			rjmp send_out_portd_loop_2
		send_out_portd_loop_2_end:
		inc count1
		cpi count1,0x03
		breq send_out_portd_loop_1_end
		rjmp send_out_portd_loop_1
	send_out_portd_loop_1_end:

	; finding next offset
	inc XL
	cpi XL,0x0a
	brne send_out_portd
	clr XL
	rjmp send_out_portd


