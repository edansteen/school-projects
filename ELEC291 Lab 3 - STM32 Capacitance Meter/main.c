// LAB 6        March 2025
//
// Edan Steen
// Ashley Kim
//
// LQFP32 pinout
//             ----------
//       VDD -|1       32|- VSS
//      PC14 -|2       31|- BOOT0
//      PC15 -|3       30|- PB7
//      NRST -|4       29|- PB6
//      VDDA -|5       28|- PB5
//       PA0 -|6       27|- PB4
//       PA1 -|7       26|- PB3
//       PA2 -|8       25|- PA15
//       PA3 -|9       24|- PA14
//       PA4 -|10      23|- PA13
//       PA5 -|11      22|- PA12
//       PA6 -|12      21|- PA11
//       PA7 -|13      20|- PA10 (Reserved for RXD)
//       PB0 -|14      19|- PA9  (Reserved for TXD)
//       PB1 -|15      18|- PA8  (Measure the period at this pin)
//       VSS -|16      17|- VDD
//             ----------
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "./Common/Include/stm32l051xx.h"
#include "lcd.h"
#include "adc.h"

#define F_CPU 32000000L
#define PIN_PERIOD (GPIOA->IDR&BIT8)
#define R1 10000
#define R2 1000
#define VDIV_VCC 3.297 //////////measure for more accurate results!
#define VDIV_R1 1000

//function definitions

//Period
void delay(int dly);
void wait_1ms(void);
void delayms(int len);
long int GetPeriod(int n);
//pin inits
void Configure_Pins(void);

void main (void) {
    double capacitance;
    char buffer[17];
	//FROM PERIOD CODE
	long int count;
	int i;
	double T, f;
	//For ADC
	float a;
	int j;
	float resistance;
	//check if both disconnected
	short disconnected = 2;

	delayms(500); // Wait for putty to start.
	printf("\x1b[2J\x1b[1;1H"); // Clear screen using ANSI escape sequence.
	
	//initialize pins 
    Configure_Pins();
	LCD_4BIT();
	initADC();

    // Loop
    while (1) {
		//set disconnected to true
		disconnected = 0;

        //get the period
        count=GetPeriod(50);
        if(count>0) {
            T=(float) count/(F_CPU*50.0); // Since we have the time of 50 periods, we need to divide by 50
            f=1.0/T;
            printf("f=%.2f Hz, count=%d            \r\n", f, count);
        }
        else {
            printf("NO SIGNAL                     \r\n");
			T = 0.0;
			f = 0.0;
			disconnected++;
        }

        fflush(stdout); // GCC printf wants a \n in order to send something.  If \n is not present, we fflush(stdout)
        waitms(200);
		
        // Send the period to the serial port
		printf( "T=%f s    \r", T);
        fflush(stdout);

        // Calculations
        capacitance = 1.44 * T * 1000 / (R1 + 2*R2);
		capacitance -= (0.9164 * 0.000001); //subtract parallel capacitor value

		printf("Capacitance: %f mF\r\n", capacitance);
        
		fflush(stdout);
		//egets_echo(buffer, sizeof(buffer));

		// determine whether to show the value in nF, uF or mF
		if (capacitance < 0.0000008) {
			//capacitor likely not attached
			sprintf(buffer, "Attach capacitor");
			disconnected++;
		}
		else if (capacitance < 0.0001) {
			//display in nanoFarads
			capacitance *= 1000000;
			sprintf(buffer, "%3.4f nF      ", capacitance);
		}
		else if (capacitance < 1) {
			//display in microFarads
			capacitance *= 1000;
			sprintf(buffer, "%3.4f uF      ", capacitance);
		}
		else {
			//display in milliFarads
			sprintf(buffer, "%3.4f mF      ", capacitance); 
		}
		
		for(i=0; i<sizeof(buffer); i++) {
			if(buffer[i] == '\n') buffer[i] = 0;
			if(buffer[i] == '\r') buffer[i] = 0;
		}

        LCDprint(buffer, 1, 1); //print the buffer value

		//resistance meter (ADC on pin 15):
		//use voltage divider, measure the 2nd resistor going to ground
		// R2 = R1 / ((Vcc/Vadc) - 1)
		j = 0;
		//take multiple samples for a more accurate reading!
		for (i = 0; i < 50; i++) {
			j +=readADC(ADC_CHSELR_CHSEL9);
		}
		j /= 50.0;
		a=(j*3.3)/0x1000;
		printf("ADC[9]=0x%04x V=%f V\r\n\n", j, a);
		fflush(stdout);

		resistance = VDIV_R1 / ((VDIV_VCC/a) - 1);
	
		//print to LCD
		if (resistance < 0) {
			sprintf(buffer, "Attach resistor "); //otherwise value is too high
			disconnected++;
		}
		else if (resistance < 1000.0) {
			sprintf(buffer, "%.3f Ohms       ", resistance);
		}
		else if (resistance < 100000) { //only print if the resistor is actually connected
			resistance /= 1000.0;
			sprintf(buffer, "%.3f kOhms     ", resistance);
		}
		else {
			sprintf(buffer, "Attach resistor "); //otherwise value is too high
			disconnected++;
		}
		
		for(i=0; i<sizeof(buffer); i++) {
			if(buffer[i] == '\n') buffer[i] = 0;
			if(buffer[i] == '\r') buffer[i] = 0;
		}
		LCDprint(buffer, 2, 1); //print the buffer value
		
		//BONUS FEATURE - turn on the LED if neither are connected
		if (disconnected > 0) {
			GPIOA->ODR |= BIT7; // turn off PA7
		}
		else {
			GPIOA->ODR &= ~BIT7; // Toggle PA7
		}
		
        // delay to not spam the result
		delayms(500);
    }
}


void delay(int dly) {
	while( dly--);
}

void wait_1ms(void) {
	// For SysTick info check the STM32L0xxx Cortex-M0 programming manual page 85.
	SysTick->LOAD = (F_CPU/1000L) - 1;  // set reload register, counter rolls over from zero, hence -1
	SysTick->VAL = 0; // load the SysTick counter
	SysTick->CTRL  = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
	while((SysTick->CTRL & BIT16)==0); // Bit 16 is the COUNTFLAG.  True when counter rolls over from zero.
	SysTick->CTRL = 0x00; // Disable Systick counter
}

void delayms(int len) {
	while(len--) wait_1ms();
}

// GetPeriod() seems to work fine for frequencies between 300Hz and 600kHz.
// 'n' is used to measure the time of 'n' periods; this increases accuracy.
long int GetPeriod (int n) {
	int i;
	unsigned int saved_TCNT1a, saved_TCNT1b;
	
	SysTick->LOAD = 0xffffff;  // 24-bit counter set to check for signal present
	SysTick->VAL = 0xffffff; // load the SysTick counter
	SysTick->CTRL  = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
	while (PIN_PERIOD!=0) // Wait for square wave to be 0
	{
		if(SysTick->CTRL & BIT16) return 0;
	}
	SysTick->CTRL = 0x00; // Disable Systick counter

	SysTick->LOAD = 0xffffff;  // 24-bit counter set to check for signal present
	SysTick->VAL = 0xffffff; // load the SysTick counter
	SysTick->CTRL  = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
	while (PIN_PERIOD==0) // Wait for square wave to be 1
	{
		if(SysTick->CTRL & BIT16) return 0;
	}
	SysTick->CTRL = 0x00; // Disable Systick counter
	
	SysTick->LOAD = 0xffffff;  // 24-bit counter reset
	SysTick->VAL = 0xffffff; // load the SysTick counter to initial value
	SysTick->CTRL  = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
	for(i=0; i<n; i++) // Measure the time of 'n' periods
	{
		while (PIN_PERIOD!=0) // Wait for square wave to be 0
		{
			if(SysTick->CTRL & BIT16) return 0;
		}
		while (PIN_PERIOD==0) // Wait for square wave to be 1
		{
			if(SysTick->CTRL & BIT16) return 0;
		}
	}
	SysTick->CTRL = 0x00; // Disable Systick counter

	return 0xffffff-SysTick->VAL;
}

// Set up the pins for each of the inputs
void Configure_Pins (void) {
	/* CODE FROM THE PERIOD*/
	RCC->IOPENR |= 0x00000001; // peripheral clock enable for port A
	//Configure capacitor reading pin
	GPIOA->MODER &= ~(BIT16 | BIT17); // Make pin PA8 input
	// Activate pull up for pin PA8:
	GPIOA->PUPDR |= BIT16; 
	GPIOA->PUPDR &= ~(BIT17); 

	/*CODE FROM THE ADC*/

	// Configure the pin used for analog input: PB1 (pin 15)
	RCC->IOPENR  |= BIT1;         // peripheral clock enable for port B
	GPIOB->MODER |= (BIT2|BIT3);  // Select analog mode for PB1 (pin 15 of LQFP32 package)

	/* CODE FROM LCD */
	RCC->IOPENR |= BIT0; // peripheral clock enable for port A
	
	// Make pins PA0 to PA5 outputs (page 200 of RM0451, two bits used to configure: bit0=1, bit1=0)
    GPIOA->MODER = (GPIOA->MODER & ~(BIT0|BIT1)) | BIT0; // PA0
	GPIOA->OTYPER &= ~BIT0; // Push-pull
    
    GPIOA->MODER = (GPIOA->MODER & ~(BIT2|BIT3)) | BIT2; // PA1
	GPIOA->OTYPER &= ~BIT1; // Push-pull
    
    GPIOA->MODER = (GPIOA->MODER & ~(BIT4|BIT5)) | BIT4; // PA2
	GPIOA->OTYPER &= ~BIT2; // Push-pull
    
    GPIOA->MODER = (GPIOA->MODER & ~(BIT6|BIT7)) | BIT6; // PA3
	GPIOA->OTYPER &= ~BIT3; // Push-pull
    
    GPIOA->MODER = (GPIOA->MODER & ~(BIT8|BIT9)) | BIT8; // PA4
	GPIOA->OTYPER &= ~BIT4; // Push-pull
    
    GPIOA->MODER = (GPIOA->MODER & ~(BIT10|BIT11)) | BIT10; // PA5
	GPIOA->OTYPER &= ~BIT5; // Push-pull

	//LED
	RCC->IOPENR |= BIT0; // peripheral clock enable for port A
	GPIOA->MODER = (GPIOA->MODER & ~(BIT15 | BIT14)) | BIT14; // Make pin PA7 output
}