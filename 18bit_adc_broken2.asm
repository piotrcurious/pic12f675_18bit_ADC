; PIC12F675 18-bit DAC using internal 10-bit PWM and software 8-bit PWM
; GPASM assembler code
; Timer interrupt for software PWM
; Main loop for testing the combined PWM

    list    p=12f675    ; list directive to define processor
    #include <p12f675.inc> ; processor specific variable definitions

    __CONFIG _CP_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF ; configuration word

    errorlevel -302 ; suppress bank selection messages

; Define pins
PWM_PIN     equ GPIO,2 ; internal PWM output pin
SW_PWM_PIN  equ GPIO,5 ; software PWM output pin

; Define registers
cblock 0x20 ; start of general purpose registers
    countL   ; low byte of software PWM counter
    countH   ; high byte of software PWM counter
    dutyL    ; low byte of software PWM duty cycle
    dutyH    ; high byte of software PWM duty cycle
    temp     ; temporary register
endc

; Interrupt vector
    org 0x00 ; processor reset vector
    goto    main    ; go to main program

    org 0x04 ; interrupt vector
    goto    isr     ; go to interrupt service routine

; Main program
main
; Initialize GPIO
    movlw   b'00100000'   ; set GP5 as output, GP2 as input (CCP1)
    tris    GPIO

; Initialize internal PWM (CCP1)
    movlw   b'00001100'   ; set CCP1 as PWM mode
    movwf   CCP1CON
    movlw   b'00000001'   ; set TMR2 prescaler as 1
    movwf   T2CON
    movlw   d'249'        ; set PR2 as 249 for 10 kHz PWM frequency (Fosc/4/(PR2+1))
    movwf   PR2

; Initialize timer interrupt (TMR0)
    bsf     INTCON,GIE    ; enable global interrupt
    bsf     INTCON,T0IE   ; enable timer0 interrupt
    bcf     OPTION_REG,T0CS   ; select internal instruction cycle clock
    bcf     OPTION_REG,PSA    ; assign prescaler to timer0
    movlw   b'00000111'   ; set prescaler as 256 for 61 Hz interrupt frequency (Fosc/4/256/256)
    movwf   OPTION_REG

; Main loop
loop
; Test the combined PWM by varying the input value from 0 to 262143 (18 bits)
; The input value is composed of CCPR1L (high byte of internal PWM duty cycle), CCP1CON<5:4> (low two bits of internal PWM duty cycle) and dutyH:dutyL (software PWM duty cycle)
; For example, input value = 131071 (binary 01_11111111_11111111) means CCPR1L = 255, CCP1CON<5:4> = 3 and dutyH:dutyL = 65535

; Set input value as 0 (minimum)
    clrf    CCPR1L        ; clear internal PWM duty cycle high byte
    bcf     CCP1CON,5     ; clear internal PWM duty cycle low bit 1
    bcf     CCP1CON,4     ; clear internal PWM duty cycle low bit 0
    clrf    dutyH         ; clear software PWM duty cycle high byte
    clrf    dutyL         ; clear software PWM duty cycle low byte

; Wait for about 1 second
    movlw   d'200'
    call    delay

; Set input value as 65535 (binary 00_11111111_11111111)
    movlw   d'255'
    movwf   CCPR1L        ; set internal PWM duty cycle high byte as 255
    bcf     CCP1CON,5     ; clear internal PWM duty cycle low bit 1
    bcf     CCP1CON,4     ; clear internal PWM duty cycle low bit 0
    movlw   d'255'
    movwf   dutyH         ; set software PWM duty cycle high byte as 255
    movlw   d'255'
    movwf   dutyL         ; set software PWM duty cycle low byte as 255

; Wait for about 1 second
    movlw   d'200'
    call    delay

; Set input value as 131071 (binary 01_11111111_11111111)
    movlw   d'255'
    movwf   CCPR1L        ; set internal PWM duty cycle high byte as 255
    bsf     CCP1CON,5     ; set internal PWM duty cycle low bit 1
    bsf     CCP1CON,4     ; set internal PWM duty cycle low bit 0
    movlw   d'255'
    movwf   dutyH         ; set software PWM duty cycle high byte as 255
    movlw   d'255'
    movwf   dutyL         ; set software PWM duty cycle low byte as 255

; Wait for about 1 second
    movlw   d'200'
    call    delay

; Set input value as 196607 (binary 10_11111111_11111111)
    movlw   d'255'
    movwf   CCPR1L        ; set internal PWM duty cycle high byte as 255
    bcf     CCP1CON,5     ; clear internal PWM duty cycle low bit 1
    bsf     CCP1CON,4     ; set internal PWM duty cycle low bit 0
    movlw   d'255'
    movwf   dutyH         ; set software PWM duty cycle high byte as 255
    movlw   d'255'
    movwf   dutyL         ; set software PWM duty cycle low byte as 255

; Wait for about 1 second
    movlw   d'200'
    call    delay

; Set input value as 262143 (binary 11_11111111_11111111, maximum)
    movlw   d'255'
    movwf   CCPR1L        ; set internal PWM duty cycle high byte as 255
    bsf     CCP1CON,5     ; set internal PWM duty cycle low bit 1
    bsf     CCP1CON,4     ; set internal PWM duty cycle low bit 0
    movlw   d'255'
    movwf   dutyH         ; set software PWM duty cycle high byte as 255
    movlw   d'255'
    movwf   dutyL         ; set software PWM duty cycle low byte as 255

; Wait for about 1 second
    movlw   d'200'
    call    delay

; Repeat the test
    goto loop

; Delay subroutine
; Input: W register (delay count)
; Output: None
; Registers used: temp
delay
    movwf   temp       ; save delay count to temp register
dloop
    nop                ; no operation (one instruction cycle)
    decfsz  temp,f     ; decrement temp and skip next instruction if zero
    goto    dloop      ; repeat until temp is zero
    return             ; return from subroutine

; Interrupt service routine
isr 
; Save context
    movwf   temp       ; save W register to temp register
    swapf   STATUS,w   ; swap STATUS register to W register
    clrf    STATUS     ; clear STATUS register (select bank0)
    movwf   W_TEMP     ; save W register to W_TEMP register (STATUS copy)

; Increment software PWM counter
    incf    countL,f   ; increment low byte of counter
    btfsc   STATUS,Z   ; test zero flag and skip next instruction if clear
    incf    countH,f   ; increment high byte of counter if low byte is zero

; Compare software PWM counter with software PWM duty cycle and set or clear software PWM output pin accordingly
    movf    countL,w   ; move low byte of counter to W register
    subwf   dutyL,w    ; subtract low byte of duty cycle from W register
    btfss   STATUS,C   ; test carry flag and skip next instruction if set
    goto over          ; go to over label if carry flag is clear (counter < duty cycle)
under                   ; under label (counter >= duty cycle)
    
; Compare high bytes of counter and duty cycle 
movf countH,w       ; move high byte of counter to W register 
subwf dutyH,w       ; subtract high byte of duty cycle from W register 
btfss STATUS,C      ; test carry flag and skip next instruction if set 
goto over           ; go to over label if carry flag is clear (counter < duty cycle) 

over                    ; over label (counter >= duty cycle) 
bcf SW_PWM_PIN      ; clear software PWM output pin 
btfsc countH,7      ; test MSB of high byte of counter and skip next instruction if clear 
bsf SW_PWM_PIN       ; set software PWM output pin if
