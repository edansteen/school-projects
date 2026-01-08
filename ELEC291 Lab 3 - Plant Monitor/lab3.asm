 	; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14
; This version uses the LM4040 voltage reference connected to pin 6 (P1.7/AIN0)

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

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))

; PINS FOR HARDWARE 
MOISTURE_SENSOR equ P0.3 ; pin 20 on the board = AIN5
LED_PIN equ P1.5

ORG 0x0000
	ljmp main

; 1234567890123456    <- This helps determine the location of the counter
temp_reading_message:    db 'Temp(degC)=     ', 0 
moisture_reading_message:   db 'MoistLvl=       ', 0
moisture_good: db ' Good  ', 0
moisture_low: db ' LOW!!!', 0
new_line: db '\r', '\n', 0
put_dot: db '.', 0
put_tab: db '\t', 0

; ONE BIT FLAGS (FOR TURNING THE BUZZER ON/OFF, ETC)
bseg
moisture_low_flag: dbit 1 ; set to 1 if alarm should be playing

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
VAL_LM4040: ds 2

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST

Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00

    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #200
    mov R0, #104
    djnz R0, $   ; 4 cycles->4*60.285ns*104=25us
    djnz R1, $-4 ; 25us*200=5.0ms
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize the pins used by the ADC (P1.1, P1.7) as input.
	orl	P1M1, #0b10000010
	anl	P1M2, #0b01111101

	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7 (temperature)

	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10100001 ; Activate AIN0, AIN5, and AIN7 analog inputs
	orl ADCCON1, #0x01 ; Enable ADC
	ret
	
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret
; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

;---------------------------------;
; Send a BCD number to PuTTY ;
;---------------------------------;
Send_BCD mac
    push ar0
    mov r0, %0
    lcall ?Send_BCD
    pop ar0
endmac

?Send_BCD:
    push acc
    ; Write most significant digit
    mov a, r0
    swap a
    anl a, #0fh
    orl a, #30h
    lcall putchar
    ; write least significant digit
    mov a, r0
    anl a, #0fh
    orl a, #30h
    lcall putchar
    pop acc
    ret

wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

; We can display a number any way we want. In this case with
; four decimal places.
Display_formated_Temp:
	Set_Cursor(1, 12)
	Display_BCD(bcd+2)
	Display_char(#'.')
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret

; Not used for this program
;Display_formated_moisture:
;	Set_Cursor(2, 10)
;	Display_BCD(bcd+4)
;	Display_BCD(bcd+3)
;	Display_BCD(bcd+2)
;	Display_BCD(bcd+1)
;	ret

Read_ADC:
	clr ADCF
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    mov a, ADCRL
    anl a, #0x0f
    mov R0, a
    mov a, ADCRH   
    swap a
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, R0
    mov R0, A
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Get the temperature and store it in x               ;
; Takes 8 samples and gets the average                ;
;													  ;
;	DNF												  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Get_Temp:
    ;mov r2, #8 
take_temp_reading:
	; Read the 2.08V LM4040 voltage connected to AIN0 on pin 6
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0
	lcall Read_ADC
	; Save result for later use
	mov VAL_LM4040+0, R0
	mov VAL_LM4040+1, R1
	; Read the signal connected to AIN7
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	lcall Read_ADC
	
	;djnz r2, take_reading ; repeat 
    
    ; Convert to voltage
	mov x+0, R0
	mov x+1, R1
	; Pad other bits with zero
	mov x+2, #0
	mov x+3, #0

	Load_y(40959) ; The MEASURED voltage reference: 4.0959V, with 4 decimal places
	lcall mul32
	; Retrive the ADC LM4040 value
	mov y+0, VAL_LM4040+0
	mov y+1, VAL_LM4040+1
	; Pad other bits with zero
	mov y+2, #0
	mov y+3, #0
	lcall div32

    ; CONVERT THE VOLTAGE TO A TEMPERATURE USING temp = (V_reading - 2.73V) * 100
    ; the voltage is already loaded in x
    Load_y(27300) ; load y with 2.73 V
    lcall sub32
    Load_y(100)
    lcall mul32
	; x should now have (V_reading - 2.73) * 100
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Get the moisture lvl & store it in x                ;
; Displays the raw analog reading. Thresholds are 	  ;
; picked manually.									  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Get_Moisture:
	;mov R2, #8
take_moisture_reading:
	; Read the 2.08V LM4040 voltage connected to AIN0 on pin 6
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x00 ; Select channel 0
	lcall Read_ADC
	; Save result
	mov VAL_LM4040+0, R0
	mov VAL_LM4040+1, R1
	
	; Read the signal connected to AIN5
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x05 ; Select channel 5
	lcall Read_ADC

	;djnz R2, take_reading ; repeat 

	; Convert to voltage
	mov x+0, R0
	mov x+1, R1
	; Pad other bits with zero
	mov x+2, #0
	mov x+3, #0

	;Load_y(40959) ; The MEASURED voltage reference: 4.0959V, with 4 decimal places
	;lcall mul32
	; Retrive the ADC LM4040 value
	;mov y+0, VAL_LM4040+0
	;mov y+1, VAL_LM4040+1
	; Pad other bits with zero
	;mov y+2, #0
	;mov y+3, #0
	;lcall div32
	ret

main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT

	clr LED_PIN
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#temp_reading_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#moisture_reading_message)

Forever:
	lcall Get_Temp
    ; Convert to BCD and display
	lcall hex2bcd
	lcall Display_formated_Temp ;display the digits of BCD

    ; Send the temperature to the serial port
    Send_BCD(bcd+2)
    mov DPTR, #put_dot
    lcall SendString
    Send_BCD(bcd+1)
    mov DPTR, #new_line ;add newline
    lcall SendString

	mov R2, #10 ; Small delay for ADC stabilization
    lcall waitms

    ; GET THE MOISTURE READING!!!
    ; IF MOISTURE READING IS BELOWED THRESHOLD, SHOW ERROR!
	lcall Get_Moisture
	lcall hex2bcd
	;lcall Display_formated_moisture

	;if moisture higher than threshold, turn on LED and warning message
	; For testing
	;Send_BCD(bcd+1)
	;Send_BCD(bcd+0)

	Load_y(2000)
	lcall x_lteq_y
	jb mf, too_dry ; if x less than or equal to y, too dry!
	;Moisture level is good
	Set_Cursor(2, 10)
    Send_Constant_String(#moisture_good) ;send message to lcd
	clr LED_PIN ; turn off led
	sjmp continue

too_dry: ; if too dry, turn on LED and print message 
	setb LED_PIN
	Set_Cursor(2, 10)
    Send_Constant_String(#moisture_low)

continue:
	; Wait 500 ms between conversions
	mov R2, #250
	lcall waitms
	mov R2, #250
	lcall waitms
    mov R2, #250
	lcall waitms
	mov R2, #250
	lcall waitms
	
	ljmp Forever
END
