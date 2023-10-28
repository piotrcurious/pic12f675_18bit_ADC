; PIC12F675
; 18-bit DAC using 10-bit PWM and 8-bit software PWM
; AN0, AN1, AN2 are analog inputs
; GP2 is PWM output
; GP0 is software PWM output

#include <p12f675.inc>

__CONFIG _CP_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF

#define PWM_PERIOD 0x3FF ; 10-bit PWM period
#define SW_PWM_PERIOD 0xFF ; 8-bit software PWM period

; Variables
cblock 0x20
    sw_pwm_duty ; software PWM duty cycle
    sw_pwm_count ; software PWM counter
    adc_value ; ADC result
    dac_value_l ; DAC value low byte (18 bits)
    dac_value_h ; DAC value high byte (18 bits)
    dac_value_u ; DAC value upper byte (18 bits)
endc

; Interrupt service routine
org 0x04
    btfss INTCON, T0IF ; check if timer0 overflowed
    goto main_isr ; if not, go to main isr
    bcf INTCON, T0IF ; clear timer0 flag
    incf sw_pwm_count, F ; increment software PWM counter
    movf sw_pwm_count, W ; compare with duty cycle
    subwf sw_pwm_duty, W 
    btfss STATUS, C 
    bsf GPIO, 0 ; set GP0 if duty cycle > counter
    btfsc STATUS, C 
    bcf GPIO, 0 ; clear GP0 if duty cycle < counter
main_isr:
    retfie ; return from interrupt

; Main program
org 0x00
    movlw b'00000111' ; set GP2 as output, GP1 as input, GP0 as output
    tris GPIO 
    movlw b'00000111' ; enable weak pull-ups on GP1:GP0
    option 
    movlw b'00001000' ; enable timer0 interrupt and global interrupt
    movwf INTCON 
    movlw b'00000101' ; set timer0 prescaler to 1:64
    option 
    clrf sw_pwm_duty ; clear software PWM duty cycle
    clrf sw_pwm_count ; clear software PWM counter

; Initialize ADC module    
    movlw b'00000111' ; select AN3 as input channel (Vref+)
    movwf ADCON0 
    bsf ADCON0, ADFM ; right justify ADC result
    bsf ADCON0, ADON ; turn on ADC module

; Initialize CCP module    
    movlw b'00001100' ; select CCP mode as PWM
    movwf CCP1CON 
    movlw PWM_PERIOD & 0xFF ; set PWM period low byte
    movwf PR2 
    movlw PWM_PERIOD >> 2 & 0x03 ; set PWM period high bits in CCP1CON<5:4>
    iorwf CCP1CON, F 
    clrf CCPR1L ; clear PWM duty cycle low byte
    clrf CCP1CON & 0x30 ; clear PWM duty cycle high bits in CCP1CON<5:4>
    
loop:
; Read AN0 and store high byte in dac_value_l    
    bcf ADCON0, CHS1 ; select AN0 as input channel
    bsf ADCON0, CHS0 
    bsf ADCON0, GO ; start ADC conversion
wait_an0:
    btfsc ADCON0, GO ; wait for conversion to finish
    goto wait_an0 
    movf ADRESH, W ; move high byte of ADC result to W register
    movwf dac_value_l 

; Read AN1 and store high byte in dac_value_h    
    bsf ADCON0, CHS1 ; select AN1 as input channel
    bcf ADCON0, CHS0 
    bsf ADCON0, GO ; start ADC conversion
wait_an1:
    btfsc ADCON0, GO ; wait for conversion to finish
    goto wait_an1 
    movf ADRESH, W ; move high byte of ADC result to W register
    movwf dac_value_h

; Read AN2 and store high byte in dac_value_u    
    bsf ADCON0, CHS1 ; select AN2 as input channel
    bsf ADCON0, CHS0 
    bsf ADCON0, GO ; start ADC conversion
wait_an2:
    btfsc ADCON0, GO ; wait for conversion to finish
    goto wait_an2 
    movf ADRESH, W ; move high byte of ADC result to W register
    
; Extract two least significant bits of AN2 high byte and store in dac_value_u    
    andlw b'00000011' ; mask out all but two LSBs
    movwf dac_value_u

; Set PWM duty cycle from dac_value_l and dac_value_h (10 bits)    
    movf dac_value_l, W ; move low byte of dac_value to W register
    movwf CCPR1L ; set PWM duty cycle low byte
    swapf dac_value_h, W ; swap nibbles of high byte of dac_value
    andlw b'00001100' ; mask out all but two MSBs
    iorwf CCP1CON, F ; set PWM duty cycle high bits in CCP1CON<5:4>

; Set software PWM duty cycle from dac_value_h (8 bits)    
    movf dac_value_h, W ; move high byte of dac_value to W register
    movwf sw_pwm_duty ; set software PWM duty cycle

    goto loop ; repeat forever
    end
    
