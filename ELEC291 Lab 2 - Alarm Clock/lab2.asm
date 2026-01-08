; ISR_example.asm: a) Increments/decrements a BCD variable every second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'CLEAR' push button connected to P1.5 is pressed.
$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK           EQU 16600000 ; Microcontroller system frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

HOUR_UP_BUTTON equ P3.0
MINUTE_UP_BUTTON equ P1.5
ALARM_HOUR_UP  equ P1.1
ALARM_MINTUE_UP  equ P1.2
TOGGLE_ALARM_BUTTON equ P1.0
SOUND_OUT     equ P1.7

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
MIN_counter: ds 1 ; determines how many minutes have passed
HOUR_counter: ds 1 ; determines how many hours have passed
Alarm_hour_counter: ds 1 ;Alarm timers
Alarm_min_counter: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
is_am: dbit 1 ; set to 1 if am, else if pm set to 0
alarm_on_flag: dbit 1 ; set to 1 if alarm should be playing

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; 1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Time: xx:xx:xxam', 0
Initial_Alarm:  db 'Alarm: 12:00 off', 0
Alarm_On_Message: db 'n ', 0
Alarm_Off_Message: db 'ff', 0
Set_to_a: db 'a', 0
Set_to_p: db 'p', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz wave at pin SOUND_OUT   ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 doesn't have 16-bit auto-reload, so
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), To_Timer_Done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), To_Timer_Done
	
	sjmp Not_Timer_Done

To_Timer_Done:
	ljmp Timer2_ISR_done

Not_Timer_Done:
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb seconds_flag ; Let the main program know second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	add a, #0x01
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a

	; if equal to 60, add a minute
	cjne a, #0x60, tmr_done
	sjmp cnt_not_tmr_done

tmr_done:
	ljmp Timer2_ISR_done

cnt_not_tmr_done:
	; clear seconds
	clr a
	da a 
	mov BCD_counter, a

	;add minute
	mov a, MIN_counter
	add a, #0x01
	da a
	mov MIN_counter, a

add_hour:
	cjne a, #0x60, Timer2_ISR_done ;check if an hour has passed
	
	; clear minutes
	clr a
	da a 
	mov MIN_counter, a
	mov a, HOUR_counter
	add a, #0x01
	da a
	mov HOUR_counter, a
	;if reached 13 hours, switch am/pm
	mov a, HOUR_counter
	cjne a, #0x13, Timer2_ISR_done

check_am:
	;set hours to 01
	mov a, #0x01
	mov HOUR_counter, a

	;check am flag
	jb is_am, change_to_pm
	; write a
	Set_Cursor(1, 15)
	Send_Constant_String(#Set_to_a)
	;update flag
	setb is_am
	sjmp Timer2_ISR_done

change_to_pm:
	; write p
	Set_Cursor(1, 15)
	Send_Constant_String(#Set_to_p)
	;update flag
	clr is_am
	;check if it's thirteen or not
	cjne a, #0x13, not_thirteen
	mov a, #0x01

not_thirteen: 
	mov Alarm_hour_counter, a
	Set_Cursor(2, 8)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(Alarm_hour_counter) ; This macro is also in 'LCD_4bit.inc'

	sjmp Timer2_ISR_done
	
Timer2_ISR_done:
; check if alarm should be on
	jnb alarm_on_flag, alarm_off
	;; COMPARE IF MINUTES AND HOURS MATCH
	mov a, Alarm_min_counter
	cjne a, MIN_counter, alarm_off
	mov a, Alarm_hour_counter
	cjne a, HOUR_counter, alarm_off
	
	setb ET0 ; turn alarm on
	sjmp end_timer

alarm_off: ; turn off alarm
	clr ET0
	
end_timer:
	pop psw
	pop acc
	reti

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00
          
    lcall Timer0_Init 
    lcall Timer2_Init
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
	Set_Cursor(2, 1)
    Send_Constant_String(#Initial_Alarm) 
    setb seconds_flag
	setb is_am
	clr alarm_on_flag
	clr ET0

	;initialize time values
	mov BCD_counter, #0x00
	mov MIN_counter, #0x00
	mov HOUR_counter, #0x11
	mov Alarm_min_counter, #0x00
	mov Alarm_hour_counter, #0x12

	; After initialization the program stays in this 'forever' loop
loop:
	;check if alarm button pressed
	jb TOGGLE_ALARM_BUTTON, hour_add  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb TOGGLE_ALARM_BUTTON, hour_add  ; if the 'CLEAR' button is not pressed skip
	jnb TOGGLE_ALARM_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; Alarm toggle pressed
	; Check if alarm is on or off already
	jb alarm_on_flag, alarm_on
	;alarm is of, turn on
	Set_Cursor(2, 15)
	Send_Constant_String(#Alarm_On_Message)
	setb alarm_on_flag ; set alarm flag to on
	sjmp hour_add ; move on to adding hour
alarm_on:
	Set_Cursor(2, 15)
	Send_Constant_String(#Alarm_Off_Message)
	clr alarm_on_flag

hour_add:
	jb HOUR_UP_BUTTON, minute_add  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb HOUR_UP_BUTTON, minute_add  ; if the 'CLEAR' button is not pressed skip
	jnb HOUR_UP_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	
	; BUTTON PRESSED
	mov a, HOUR_counter
	add a, #0x01
	da a
	cjne a, #0x13, continue_h_add
	mov a, #0x01
	; change am pm
	jb is_am, switch_to_pm
	; is pm
	setb is_am
	Set_Cursor(1,15)
	Send_Constant_String(#Set_to_a)
	sjmp continue_h_add

switch_to_pm:
	clr is_am
	Set_Cursor(1,15)
	Send_Constant_String(#Set_to_p)

continue_h_add:
	mov HOUR_counter, a

minute_add:
	jb MINUTE_UP_BUTTON, alarm_hour_add  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb MINUTE_UP_BUTTON, alarm_hour_add  ; if the 'CLEAR' button is not pressed skip
	jnb MINUTE_UP_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	
	; BUTTON PRESSED
	mov a, MIN_counter
	add a, #0x01
	da a
	cjne a, #0x60, continue_min_add
	mov a, #0x00
continue_min_add:
	mov MIN_counter, a

alarm_hour_add:
	jb ALARM_HOUR_UP, alarm_minute_add ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb ALARM_HOUR_UP, alarm_minute_add ; if the 'CLEAR' button is not pressed skip
	jnb ALARM_HOUR_UP, $		; Wait for button release.  The '$' means: jump to same instruction.
	
	; add an hour
	mov a, Alarm_hour_counter
	add a, #0x01
	da a
	cjne a, #0x13, continue_alarm_h_add
	mov a, #0x01
continue_alarm_h_add:
	mov Alarm_hour_counter, a
	Set_Cursor(2, 8)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(Alarm_hour_counter) ; This macro is also in 'LCD_4bit.inc'

alarm_minute_add:
	jb ALARM_MINTUE_UP, loop_a ; if the 'Alarm hour up' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb ALARM_MINTUE_UP, loop_a ; if button is not pressed skip
	jnb ALARM_MINTUE_UP, $		; Wait for button release.  The '$' means: jump to same instruction.
	
	mov a, Alarm_min_counter
	add a, #0x01
	da a
	; 
	mov Alarm_min_counter, a
	cjne a, #0x60, continue_alarm_min_add
	mov a, #0x00
continue_alarm_min_add:
	mov Alarm_min_counter, a

	Set_Cursor(2, 11)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(Alarm_min_counter) ; This macro is also in 'LCD_4bit.inc'

loop_a:
	jb seconds_flag, loop_b
	ljmp loop

loop_b:
    clr seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
	mov a, BCD_counter

display_stuff:
	Set_Cursor(1, 7)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(HOUR_counter) ; This macro is also in 'LCD_4bit.inc'

	Set_Cursor(1, 10)     
	Display_BCD(MIN_counter) 

	Set_Cursor(1, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'

    ljmp loop
END
