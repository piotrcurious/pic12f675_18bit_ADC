; PIC12F675 18-bit DAC using internal 10-bit PWM and software 8-bit PWM
; Author: Bing
; Date: 27/10/2023

    LIST    p=12F675
    INCLUDE "p12f675.inc"
    __CONFIG _CP_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF

; Define macros for bank selection
    #define BANK0   bcf STATUS,RP0
    #define BANK1   bsf STATUS,RP0

; Define constants for pin assignments
    #define PWM_PIN GPIO,2 ; CCP1 output pin
    #define SWM_PIN GPIO,4 ; Software PWM output pin

; Define variables for software PWM
    cblock  0x20
        swm_duty ; Software PWM duty cycle (0-255)
        swm_count ; Software PWM counter (0-255)
        dac_value ; Combined DAC value (18 bits)
        dac_value_hi ; High byte of DAC value
        dac_value_lo ; Low byte of DAC value
    endc

; Initialize the device
    org     0x000
    BANK1
    movlw   b'00001000' ; Set GP2 as output, GP3 as input, GP4 as output, GP5 as input
    movwf   TRISIO
    movlw   b'00000000' ; Disable comparators and enable pins for digital I/O
    movwf   CMCON
    BANK0
    clrf    GPIO ; Clear GPIO pins

; Initialize the timer interrupt for software PWM
    BANK1
    movlw   b'00000100' ; Set prescaler to 1:32 (Fosc/4)
    movwf   OPTION_REG
    BANK0
    movlw   .249 ; Load TMR0 with 249 to get an interrupt every 256 us (Fosc = 4 MHz)
    movwf   TMR0
    bsf     INTCON,GIE ; Enable global interrupts
    bsf     INTCON,T0IE ; Enable timer interrupt

; Initialize the internal PWM module for 10-bit resolution
    BANK1
    movlw   b'00000000' ; Set TMR2 prescaler to 1:1 and postscaler to 1:1
    movwf   T2CON
    BANK0
    movlw   .249 ; Load PR2 with 249 to get a PWM period of 250 us (Fosc = 4 MHz)
    movwf   PR2
    clrf    CCPR1L ; Clear CCP1 duty cycle register low byte
    clrf    CCPR1H ; Clear CCP1 duty cycle register high byte
    BANK1
    movlw   b'00001100' ; Set CCP1 mode to PWM and select P1A as output pin (GP2)
    movwf   CCP1CON

; Start the main loop
main_loop:
    
; Test the DAC by varying the input value from 0 to 262143 (18 bits)
; This will produce a ramp waveform on the DAC output pin (GP4)

; Increment the DAC value by 1 and check for overflow    
    incf    dac_value,f ; Increment low byte of DAC value 
    btfsc   STATUS,Z ; Check if low byte is zero (overflow)
        incf dac_value_hi,f ; Increment high byte of DAC value 
        btfsc STATUS,Z ; Check if high byte is zero (overflow)
            incf dac_value_lo,f ; Increment high byte of DAC value 

; Update the internal PWM duty cycle with the lower 10 bits of the DAC value    
    BANK0    
    movf    dac_value,w ; Copy low byte of DAC value to W register 
    andlw   b'00000011' ; Mask out the lower two bits 
    movwf   CCP1CON ; Store them in CCP1CON<5:4> 
    rlf     CCP1CON,f ; Rotate left twice 
    rlf     CCP1CON,f 
    swapf   dac_value,w ; Swap nibbles of low byte of DAC value 
    andlw   b'11111100' ; Mask out the upper six bits 
    iorwf   CCP1CON,f ; OR them with CCP1CON<5:4> 
    movf    dac_value,w ; Copy low byte of DAC value to W register 
    andlw   b'11111100' ; Mask out the lower two bits 
    movwf   CCPR1L ; Store them in CCPR1L<7:2> 

; Update the software PWM duty cycle with the upper 8 bits of the DAC value
    movf    dac_value_hi,w ; Copy high byte of DAC value to W register
    movwf   swm_duty ; Store it in software PWM duty cycle variable

; Wait for 10 ms before repeating the loop
    call    delay_10ms

; Go back to the start of the loop
    goto    main_loop

; Interrupt service routine for software PWM
isr:
    
; Check if timer interrupt flag is set
    btfss   INTCON,T0IF
        goto    isr_end ; If not, go to the end of ISR

; Clear timer interrupt flag
    bcf     INTCON,T0IF

; Reload TMR0 with 249 to get an interrupt every 256 us
    movlw   .249
    movwf   TMR0

; Increment software PWM counter by 1 and check for overflow
    incf    swm_count,f
    btfss   STATUS,Z
        goto    swm_update ; If not, go to update software PWM output

; Reset software PWM counter to 0
    clrf    swm_count

swm_update:

; Compare software PWM counter with software PWM duty cycle
    movf    swm_count,w
    subwf   swm_duty,w
    btfss   STATUS,C
        goto    swm_high ; If counter < duty cycle, go to set software PWM output high

swm_low:

; Clear software PWM output pin (GP4)
    bcf     SWM_PIN
    goto    isr_end ; Go to the end of ISR

swm_high:

; Set software PWM output pin (GP4)
    bsf     SWM_PIN

isr_end:

; Return from interrupt
    retfie

; Subroutine for 10 ms delay (Fosc = 4 MHz)
delay_10ms:
    
; Load counter values for inner and outer loops
    movlw   .39
    movwf   0x21
    movlw   .250
    movwf   0x22

delay_loop:

; Decrement counter for inner loop and check for zero
    decfsz  0x21,f
        goto    $+2
    goto    delay_loop_end

; Decrement counter for outer loop and check for zero    
    decfsz  0x22,f
        goto    delay_loop

delay_loop_end:

; Return from subroutine    
    return
    
; End of program    
    end

    
