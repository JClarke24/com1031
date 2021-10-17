;;;  YOUR CODE SHOULD GO INTO THIS FILE.
	
;;; Morse code decoder, using content from previous labs in order to
;;; make use of the timers and interrupt routines.
;;; Works for every letter in the alphabet and display an error if
;;; signal is incorrect. Additional comments have been added throughout
;;; the file.

	
;;; First of all the timer prescaler is set to 1024, ie one timer tick
;;; is 1024 CPU clock ticks. Then we only lock at the high byte of the
;;; 16 bit timer1, which is the basis for all timing. One tick at the
;;; high byte is 1024*256 CPU clock ticks. With a CPU clock of 16MHz,
;;; ie 16,000,000 CPU clock ticks per second, this means one tick in
;;; the high byte of timer1 corresponds to 256*1024 / 16.000.000 Hz =
;;; 16ms. So 16ms is the basis of all our timings, about 61 ticks per second:

	CPU_FREQ = 16000000
	TICKS_PER_SEC = CPU_FREQ / (256 * 1024)

	DECISION_LIMIT = TICKS_PER_SEC / 5 ; 200ms
	TIMEOUT = 2 * TICKS_PER_SEC / 5	   ; 400ms

#define __SFR_OFFSET 0
#include <avr/io.h> 				

;;; Button is connected to PIN 8, PORTB, Bit 0, because that doubles as the ICP1 for timer 1
	BUTTON = 0

	SEG_A = 7		; top
	SEG_B = 1 		; upper right
	SEG_C = 2		; lower right
	SEG_D = 3		; buttom
	SEG_E = 4		; lower left
	SEG_F = 5		; upper right
	SEG_G = 6		; middle


	//7segment mapping for alphabet
	ALL_SEGS = _BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G)

	CHAR_A = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_B = (_BV(SEG_C) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_C = (_BV(SEG_A) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F))
	CHAR_D = (_BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_G))
	CHAR_E = (_BV(SEG_A) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_F = (_BV(SEG_A) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_G = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_H = (_BV(SEG_C) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_I = (_BV(SEG_B) | _BV(SEG_C))
	CHAR_J = (_BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D))
	CHAR_K = (_BV(SEG_B) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_L = (_BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F))
	CHAR_M = (_BV(SEG_A) | _BV(SEG_C) | _BV(SEG_E))
	CHAR_N = (_BV(SEG_C) | _BV(SEG_E) | _BV(SEG_G))
	CHAR_O = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F))
	CHAR_P = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_Q = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_R = (_BV(SEG_E) | _BV(SEG_G))
	CHAR_S = (_BV(SEG_A) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_T = (_BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_U = (_BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_F))
	CHAR_V = (_BV(SEG_B) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_W = (_BV(SEG_B) | _BV(SEG_D) | _BV(SEG_F))
	CHAR_X = (_BV(SEG_B) | _BV(SEG_C) | _BV(SEG_E) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_Y = (_BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_F) | _BV(SEG_G))
	CHAR_Z = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_D) | _BV(SEG_E) | _BV(SEG_G))
	ERROR = (_BV(SEG_A) | _BV(SEG_B) | _BV(SEG_C) | _BV(SEG_D) | _BV(SEG_G))

	
	.section .text


;;; this is the entry point to the user code, called from init.S. We
;;; do the setup of ports, timer and interrupts, then we go to an
;;; eternal loop because all the work is done in the interrupt service
;;; routines.

;;; Timer1 capture interrupt is used to record the length of button
;;; presses and button releases. 
;;; 
;;; r19: used a flag that indicates whether the timer has overrun its
;;; max value while a button has been held pressed.
	
	.global main
main:	
	;; output/counter setup
	ldi r20, 0x00		;setting up the register that will be used
	ldi r21, 0x00
	clr r25
	clr r22

	;; setup for button, DDRB0 is automatically an input.
	sbi PORTB, BUTTON 	; switch on the pull-up. Released
				; button is 1, depressed button read as 0.

	;; setup the timer ([ATmega328p], Section 15.11.1, p126)

	clr r16
	sts TCCR1A, r16 	; setting timer output mode: no output
				; pin used, normal counting up. 

	ldi r16, TIMEOUT	; time in 16ms ticks to detect a TIMEOUT,
				; about 400ms.
				; long and short button presses. 
	sts OCR1AH, r16		; move into high byte of compare match
				; register A
	
	clr r16			; low byte of compare match is just 0.
	sts OCR1AL, r16         ; note 16bit registers always have to
				; be written high byte first, see
				; [ATmega328p], Chapter 15.3, p 106

	;; enable input capture interrupt (to time button presses) and
	;; compare match interrupt (the time-out to display letter:
	ldi r16, _BV(ICIE1) | _BV(OCIE1A)
	sts TIMSK1, r16

	;; enable noise canceller, set prescaler to 1024, and start
	;; timer in CTC mode, [ATmega328p] section  15.11.2, p128
 
	ldi r16,  _BV(ICNC1) | _BV(CS12) | _BV(CS10) | _BV(WGM12)
	sts TCCR1B, r16

	clr r19			; reset overflow flag to defined state

	sei			; enable interrupts globally.

fourE4:	rjmp fourE4 		; do nothing :-) just wait for the
				; interrupts to occur -- forever.

;;; This interrupt service routine is called whenever timer1 has
;;; counted up to match the value stored in OCA1, ie when more then
;;; GAP_LIMIT time has elapses since the last button press or release.
	
	.global timer1_compa_isr  ; export symbol to overwrite weak
				; definition in init.S
	
timer1_compa_isr:			

	push r16	
	in r16, SREG		; save the status register.
	push r16

	;; check whether we are waiting for a button press or release:
	lds r16, TCCR1B
	sbrs r16, ICES1 	; skip if waiting for postive edge (ie for button release)
	rjmp awaiting_press

awaiting_release:
	;;  make sure also an overly long press is always recognised
	;;  as a long press, irrespective of a timer overrun:

	ser r19 		; using r19 as a flag to indicate a
				; timer overflow has occured.
	rjmp 1f

awaiting_press:	
	;; if we are waiting for a button press, then more time than
	;; TIME-OUT has elasped since the last release -- in this case
	;; we display letter and reset counters
		
	ldi r16, _BV(BUTTON)	
				
	out PORTB, r16		;reset button
	out DDRD, r25		;display letter
	clr r20			;clear dot counter
	clr r21			;clear dash counter
	clr r22			;clear total counter
	
1:	pop r16
	out SREG, r16 		;restore status register
	pop r16
	
	reti


;;; This interrupt service routine times the duration of button
;;; presses. It is also involved in timing button releases as it
;;; always resets timer1 when called.
;;; It is called whenever the signal at ICP1 (PORTB0) changes in a
;;; certain direction. If we are called for a negative edge (button
;;; has just been depressed), we go on waiting for a positive edge
;;; (button will be released) and vice-versa.
	
	.global timer1_cpt_isr

timer1_cpt_isr:

	push r8

	in r8, SREG 		; save the status register.
	push r8

	lds r8, ICR1L		; get the timer count when the capture event happened.
	lds r8, ICR1H           ; we discard the low part, only
				; interested in the high part, but
				; reading low byte is necessary to get
				; a correct high byte in ICR1H, see
				; documentation [ATmega328p] Section 15.3 p106
	push r17				


	or r17, r8

	mov r17,r19		;  debounce. If there is no timer overflow and
	or r17,r8		;  ICR1H is still zero, then 
				;  less than 16ms have elapsed since
				;  last release or press
	breq debounce		;  and we do nothing



	clr r17
	sts TCNT1H, r17 	; reset timer, first writing the high byte to the latch
	sts TCNT1L, r17		; then the low byte -- Section 15.11.4 of [ATmega328p] p130.

	;; check whether we were looking for a positive or a negative edge:
	lds r17, TCCR1B
	sbrs  r17, ICES1	; skip next instruction if positive edge dedection.
	
	rjmp pressed		; we have a negative edge ie button
				; has been pressed

	;; positive edge, button has been released
	rcall released

	andi r17, ~(_BV(ICES1)) ; we have had positive edge, so next
				; time looking for negative edge
	rjmp end_isr

	
pressed:

	ori r17, _BV(ICES1)	; next time detect positive edge, ie a
				; button release.

end_isr:
	sts TCCR1B, r17 	; write r17 to TCCR1B to activate the
				; change in edge detection.
	
debounce:
	pop r17
	pop r8
	out SREG, r8		; restore status register
	pop r8

	reti

;;; This subroutine handles the detection of the end of a morse
;;; signal.
;;; It expects the durations of button presses in 16ms ticks in r8


released:

	push r16

	tst r19 		; Did we have a timer overflow
				; (ie more than TIMEOUT time since the
				; last released of the button?
	brne long_press		; if yes, then signal is a long
				; press in any case

	;; is the signal longer then DECISION_LIMIT?
	ldi r16, DECISION_LIMIT
	cp r8,r16
	brcs short_press		; if it is shorter jump to label short


	
long_press:
	clr r25			
	out DDRD, r25		;clears display
	ldi r16, _BV(BUTTON)	
	out PORTB, r16		;reset button
	clr r22
	add r22, r20		;clear total counter and add both dot and dash counter to it
	add r22, r21
	cpi r22, 0x01		;check if total counter is 1 (if this is the second signal)
	breq 1f			
	cpi r22, 0x03		;check if total counter is 3 (if this is the third signal)
	breq 2f
	cpi r22, 0x07		;check if total counter is 7 (if this is the fourth signal)
	breq 3f
	inc r21			;if its the first signal, increment dash counter
	rjmp checkE

1:
	ori r21, 0x02		;for second signal, set the second bit value of dash counter
	rjmp checkE

2:
	ori r21, 0x04		;for third signal, set the third bit value of dash counter
	rjmp checkE

3:	ori r21, 0x08		;for fourth signal, set the fourth bit value of dash counter
	rjmp checkE
	
short_press:
	clr r25
	out DDRD, r25		;clears display
	ldi r16, _BV(BUTTON)
	out PORTB, r16		;reset button
	clr r22
	add r22, r20		;clear total counter and add both dot and dash counter to it
	add r22, r21
	cpi r22, 0x01		;check if total counter is 1 (if this is the second signal)
	breq 1f
	cpi r22, 0x03		;check if total counter is 3 (if this is the third signal)
	breq 2f
	cpi r22, 0x07		;check if total counter is 7 (if this is the fourth signal)
	breq 3f
	inc r20			;if its the first signal, increment dot counter
	rjmp checkE

1:
	ori r20, 0x02		;for second signal, set the second bit value of dot counter
	rjmp checkE

2:
	ori r20, 0x04		;for third signal, set the second bit value of dot counter
	rjmp checkE

3:	ori r20, 0x08		;for fourth signal, set the second bit value of dot counter
	rjmp checkE
	
checkE:
	cpi r20, 0x01		;checks if counter combination matches
	brne checkT		;the signal combination for morse code A
	cpi r21, 0x00		; if not, check next letter
	brne checkT

combinationE:
	ldi r16, _BV(BUTTON)	
	out PORTB, r16		;reset button
	clr r25
	ldi r25, CHAR_E		;loads CHAR_E into register
	rjmp finish

checkT:
	cpi r20, 0x00	     	;checks if counter combination matches
	brne checkA		;the signal combination for morse code A
	cpi r21, 0x01		; if not, check next letter
	brne checkA

combinationT:
	ldi r16, _BV(BUTTON)
	out PORTB, r16		;reset button
	clr r25
	ldi r25, CHAR_T		;loads CHAR_T into register
	rjmp finish

checkA:				;REPEAT THIS FOR EVERY LETTER
	cpi r20, 0x01		
	brne checkN		
	cpi r21, 0x02		
	brne checkN

combinationA:
	ldi r16, _BV(BUTTON)	
	out PORTB, r16		
	clr r25
	ldi r25, CHAR_A		
	rjmp finish

checkN:
	cpi r20, 0x02		
	brne checkI		
	cpi r21, 0x01		
	brne checkI

combinationN:
	ldi r16, _BV(BUTTON)	
	out PORTB, r16		
	clr r25
	ldi r25, CHAR_N		
	rjmp finish

checkI:
	cpi r20, 0x03	     	
	brne checkM		
	cpi r21, 0x00		
	brne checkM

combinationI:
	ldi r16, _BV(BUTTON)
	out PORTB, r16		
	clr r25
	ldi r25, CHAR_I		
	rjmp finish


checkM:	cpi r20, 0x00	    	
	brne checkD		
	cpi r21, 0x03		
	brne checkD		

combinationM:
	ldi r16, _BV(BUTTON)
	out PORTB, r16		
	clr r25
	ldi r25, CHAR_M		
	rjmp finish

checkD:	cpi r20, 0x06
	brne checkG
	cpi r21, 0x01
	brne checkG

combinationD:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_D
	rjmp finish

checkG:	cpi r20, 0x04
	brne checkK
	cpi r21, 0x03
	brne checkK

combinationG:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_G
	rjmp finish

checkK:	cpi r20, 0x02
	brne checkO
	cpi r21, 0x05
	brne checkO

combinationK:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_K
	rjmp finish

checkO:	cpi r20, 0x00
	brne checkR
	cpi r21, 0x07
	brne checkR

combinationO:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_O
	rjmp finish

checkR:	cpi r20, 0x05
	brne checkS
	cpi r21, 0x02
	brne checkS

combinationR:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_R
	rjmp finish

checkS:	cpi r20, 0x07
	brne checkU
	cpi r21, 0x00
	brne checkU

combinationS:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_S
	rjmp finish

checkU:	cpi r20,0x03
	brne checkW
	cpi r21, 0x04
	brne checkW

combinationU:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_U
	rjmp finish

checkW:	cpi r20, 0x01
	brne checkB
	cpi r21, 0x06
	brne checkB

combinationW:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_W
	rjmp finish

checkB:	cpi r20, 0x0e
	brne checkC
	cpi r21, 0x01
	brne checkC

combinationB:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_B
	rjmp finish
	
checkC:	cpi r20, 0x0a
	brne checkF
	cpi r21, 0x05
	brne checkF

combinationC:
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_C
	rjmp finish

checkF:	cpi r20, 0x0b
	brne checkH
	cpi r21, 0x04
	brne checkH

combinationF:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_F
	rjmp finish

checkH:	cpi r20, 0x0f
	brne checkJ
	cpi r21, 0x00
	brne checkJ

combinationH:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_H
	rjmp finish

checkJ:	cpi r20, 0x01
	brne checkL
	cpi r21, 0x0e
	brne checkL

combinationJ:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_J
	rjmp finish

checkL:	cpi r20, 0x0d
	brne checkP
	cpi r21, 0x02
	brne checkP

combinationL:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_L
	rjmp finish

checkP:	cpi r20, 0x09
	brne checkQ
	cpi r21, 0x06
	brne checkQ

combinationP:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_P
	rjmp finish

checkQ:	cpi r20, 0x04
	brne checkV
	cpi r21, 0x0b
	brne checkV

combinationQ:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_Q
	rjmp finish

checkV:	cpi r20, 0x07
	brne checkX
	cpi r21, 0x08
	brne checkX

combinationV:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_V
	rjmp finish

checkX:	cpi r20, 0x06
	brne checkY
	cpi r21, 0x09
	brne checkY

combinationX:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_X
	rjmp finish

checkY:	cpi r20, 0x02
	brne checkZ
	cpi r21, 0x0d
	brne checkZ

combinationY:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_Y
	rjmp finish

checkZ:	cpi r20, 0x0c	   	;checks if counter combination matches 
	brne error	   	;the signal combination for morse code Z (last letter)
	cpi r21, 0x03	  	;if not, this mean that signal does not
	brne error		;correspond to any letter, hence, go to error

combinationZ:	
	ldi r16, _BV(BUTTON)
	out PORTB, r16
	clr r25
	ldi r25, CHAR_Z
	rjmp finish

error:
	ldi r16,_BV(BUTTON)
	out PORTB, r16
	ldi r25, ERROR		;loads ERROR into register
	rjmp finish

finish:	
	pop r16
	clr r19			;clear overflow flag in case it was set
	ret			

