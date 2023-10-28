; PIC12F675 Software PWM using Timer Interrupt
; Author: Bing

    list p=12f675
    #include <p12f675.inc>
    __CONFIG _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _BODEN_OFF

; Define constants
#define LED GP0 ; LED pin
#define TMR0_VAL 155 ; Timer0 reload value for 100us interrupt
#define PWM_MAX 255 ; Maximum PWM value

; Define variables
    cblock 0x20 ; Start of general purpose registers
        pwm_val ; PWM value (0-255)
        pwm_cnt ; PWM counter (0-255)
        dir ; Direction of PWM change (0 or 1)
    endc

; Interrupt service routine
    org 0x04 ; Interrupt vector
    movwf w_temp ; Save W register
    swapf STATUS, W ; Swap nibbles of STATUS
    clrf STATUS ; Clear STATUS
    movwf s_temp ; Save STATUS

; Reload Timer0 and clear interrupt flag
    movlw TMR0_VAL ; Load Timer0 value
    movwf TMR0 ; Write to Timer0 register
    bcf INTCON, T0IF ; Clear Timer0 interrupt flag

; Compare PWM value and counter
    movf pwm_val, W ; Load PWM value
    subwf pwm_cnt, W ; Subtract from PWM counter
    btfss STATUS, C ; Check if carry bit is set
    goto skip_on ; Skip turning on LED if no carry

; Turn on LED and reset counter
    bsf GPIO, LED ; Set LED pin high
    clrf pwm_cnt ; Clear PWM counter
    goto skip_off ; Skip turning off LED

skip_on:
; Turn off LED and increment counter
    bcf GPIO, LED ; Set LED pin low
    incf pwm_cnt, F ; Increment PWM counter

skip_off:
; Restore W and STATUS registers
    swapf s_temp, W ; Swap nibbles of saved STATUS
    movwf STATUS ; Restore STATUS register
    swapf w_temp, F ; Swap nibbles of saved W
    swapf w_temp, W ; Restore W register

; Return from interrupt
    retfie

; Main program loop
    org 0x00 ; Reset vector
    goto start ; Jump to start of program

start:
; Initialize GPIO pins and registers
    bsf STATUS, RP0 ; Select bank 1
    movlw b'00001000' ; Set GP3 as input, GP2 as output, GP1 as input, GP0 as output
    movwf TRISIO ; Write to TRISIO register
    movlw b'00000000' ; Set all GPIO pins low
    movwf GPIO ; Write to GPIO register
    bcf STATUS, RP0 ; Select bank 0

; Initialize Timer0 and interrupt
    option_reg = b'11010111' ; Set prescaler to 1:256, assign to Timer0, enable pull-ups, increment on low-to-high transition, disable comparator outputs 
    intcon = b'10100000' ; Enable global and Timer0 interrupts, clear interrupt flags 
    movlw TMR0_VAL ; Load Timer0 value 
    movwf TMR0 ; Write to Timer0 register 

; Initialize variables 
    clrf pwm_val ; Clear PWM value 
    clrf pwm_cnt ; Clear PWM counter 
    bsf dir ; Set direction bit 

loop:
; Change PWM value according to direction 
    btfsc dir ; Check direction bit 
    goto up ; Go to increment PWM value 
down: 
; Decrement PWM value 
    decfsz pwm_val, F ; Decrement PWM value and check if zero 
    goto loop2 ; Go to next loop iteration if not zero 
bcf dir ; Clear direction bit if zero 
goto loop2 ; Go to next loop iteration 
up: 
; Increment PWM value 
incfsz pwm_val, F ; Increment PWM value and check if 255 
goto loop2 ; Go to next loop iteration if not 255 
bsf dir ; Set direction bit if 255 
goto loop2 ; Go to next loop iteration 

loop2: 
; Wait for some time 
movlw .100 ; Load delay count 
call delay_ms ; Call delay subroutine 

goto loop ; Go to main loop 

delay_ms: 
; Delay subroutine (1 ms per count) 
movwf count1 ; Store count in count1 register 

delay_1: 
movlw .250 ; Load inner loop count 
movwf count2 ; Store count in count2 register 

delay_2: 
nop ; No operation 
decfsz count2, F ; Decrement count2 and check if zero 
goto delay_2 ; Repeat inner loop if not zero 

decfsz count1, F ; Decrement count1 and check if zero 
goto delay_1 ; Repeat outer loop if not zero 

return ; Return from subroutine 

    end ; End of program
    
