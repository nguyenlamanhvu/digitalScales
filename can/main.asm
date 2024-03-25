
/*
-----------------------------------------------------------------
Ph?n th? t?c liên quan ??n LCD4bit 
*/
.EQU LCD=PORTB ;PORTB giao ti?p bus LCD 16 x 2
.EQU LCD_DR=DDRB
.EQU LCD_IN=PINB
.EQU RS=0 ;bit RS
.EQU RW=1 ;bit RW
.EQU E=2 ;bit E
.EQU CR=$0D ;m? xu?ng d?ng
.EQU NULL=$00 ;m? k?t thúc

//-----------------------------------------------------------------
	.EQU	ADC_PORT=PORTA
	.EQU	ADC_DR=DDRA
	.EQU	ADC_IN=PINA
	.EQU	TF=31249			;giá tr? ??t tr??c OCR1A/B t?o tr? 1s
	.ORG	0
	RJMP	MAIN
	.ORG	0X40
MAIN:	
	LDI		R16,HIGH(RAMEND);??a stack lên vùng ?/c cao
	OUT		SPH,R16
	LDI		R16,LOW(RAMEND)
	OUT		SPL,R16

	//----------------------------------------------
// LCD4BIT
	LDI R16,0XFF
	OUT LCD_DR,R16 		;khai báo PORTB là output
	CBI LCD,RS 			;RS=PB0=0
	CBI LCD,RW 			;RW=PB1=0 truy xu?t ghi
	CBI LCD,E 			;E=PB2=0 c?m LCD
	RCALL POWER_RESET_LCD4 	;reset c?p ngu?n LCD 4 bit
	RCALL INIT_LCD4 		;ctc kh?i ??ng LCD 4 bit
	//----------------------------------------------
	CBI LCD,RS
	LDI R17,0x80
	RCALL OUT_LCD4_2
	DISPLAY:
	LDI ZH,HIGH(STRING<<1)
	LDI ZL,LOW(STRING<<1)
LINE1:
	LPM R17,Z+
	CPI R17,CR		;KT KI TU XUONG DONG
	BREQ NEXT
	SBI LCD,RS
	RCALL	OUT_LCD4_2
	RJMP LINE1
NEXT:

	RCALL	USART_Init

	LDI		R16,0XFF			;PortD,B output
	;OUT		DDRD,R16		
	OUT		DDRB,R16

	LDI		R16,0X00			;PortA input
	OUT		ADC_DR,R16
	;OUT		PORTD,R16			;output=0x0000
	OUT		PORTB,R16
			
	LDI		R16,HIGH(TF)		;n?p OCR1A/B byte cao giá tr? ??t tr??c
	STS		OCR1AH,R16
	STS		OCR1BH,R16
		
	LDI		R16,LOW(TF)		;n?p OCR1A/B byte th?p giá tr? ??t tr??c
	STS		OCR1AL,R16
	STS		OCR1BL,R16
					
	LDI		R16,0X00			;Timer1 mode CTC 4
	STS		TCCR1A,R16
	LDI		R16,0B00001100	;Timer1 mode CTC 4,N=256,ch?y Timer1
	STS		TCCR1B,R16

	;ADMUX: ADC Multiplexer Selection Register
	;    7       6      5        4      3        2       1       0  
	;-----------------------------------------------------------------
	;- REFS1 - REFS0 - ADLAR -  MUX4 -  MUX3 -  MUX2 -  MUX1 -  MUX0 -	
	;-----------------------------------------------------------------
	;[7:6] REF[1:0] ->00: AREF, 01: AVCC, 10: Internal 1.1V, 11:Internal 2.56V
	;[5]   ADCLAR	1: left  adjust result (ADCH: [9:2]			ADCL:[1:0]xx xxxx)
	;				0: right adjust result (ADCH: xxxx xx[9:8]	ADCL:[7:0])
	;[4:0] MUX[4:0] 0 0000..0 0111: Single Ended Input: ADC[0:7]
	;				0 1000..1 1101: Differential Mode with gain
	;				1 1110			Single Ended Input: 1.1V
	;				1 1111			Single Ended Input: GND				
	LDI		R16,0B11000000	; Vref=AVcc=2.56V,SE ADC0,d?ch ph?i 
	STS		ADMUX,R16		;
	
	;ADCSRA – ADC Control and Status Register A
	;    7       6      5        4      3        2       1       0  
	;-----------------------------------------------------------------
	;- ADEN  - ADSC  - ADATE -  ADIF -  ADIE - ADPS2 - ADPS1 - ADPS0 -	
	;-----------------------------------------------------------------		
	;[7]	ADEN: ADC Enable 	1:ON , 0:OFF 	
	;[6]	ADSC: ADC Start Conversion 1:START --> DONE:0
	;[5]	ADATE: 1:Auto Trigger mode
	;[4]	ADIF: 1:DONE => Trigger Interrupt (if ADIE=1 and I=1)
	;[3]	ADIE: Enable interrupt
	;[2:0]	ADPS[2:0] fADC=fosc/N: 2-2-4-8  16-32-64-128
	LDI		R16,0B10100110	;cho phép ADC,mode t? kích
	STS		ADCSRA,R16		;f(ADC)=fosc/64=125Khz

	;ADCSRB – ADC Control and Status Register B
	;    7       6      5        4      3        2       1       0  
	;-----------------------------------------------------------------
	;-       -        -       -      -       - ADTS2 - ADTS1 - ADTS0 -	
	;-----------------------------------------------------------------	
	;[2:0] ADTS[2:0]	000:Free Running mode
	;					001:Analog Comparator
	;					010:External Interrupt Request 0 (INT0)
	;					011:Timer/Counter0 Compare Match A
	;					100:Timer/Counter0 Overflow
	;					101:Timer/Counter1 Compare Match B
	;					110:Timer/Counter1 Overflow
	;					111:Timer/Counter1 Capture Event
	LDI		R16,0X05			;ngu?n t?o kích OCF1B
	STS		ADCSRB,R16

LOOP_1:
	;ADCSRA – ADC Control and Status Register A
	;    7       6      5        4      3        2       1       0  
	;-----------------------------------------------------------------
	;- ADEN  - ADSC  - ADATE -  ADIF -  ADIE - ADPS2 - ADPS1 - ADPS0 -	
	;-----------------------------------------------------------------		
	;[4]	ADIF: 1:DONE => Trigger Interrupt (if ADIE=1 and I=1)
	LDS		R16,ADCSRA		;ch? c? ADIF
	SBRS	R16,ADIF			;c? ADIF=1 chuy?n ??i xong
	RJMP	LOOP_1				;chch? c? ADIF=1	
	;Xu ly sau khi ADC hoat dong xong
	STS		ADCSRA,R16		;xóa c? ADIF
	SBI		PINB,0
	;Hien thi gia tri len LCD: V1=x.xx volt
	;V1=ADCH:ADCL*Vref/1024
	RCALL DISPLAY_V
			
	IN		R17,TIFR1			;??c c? OCF1A
	OUT		TIFR1,R17			;xóa c? OCF1A n?u =1
	RJMP	LOOP_1				;ti?p t?c chuy?n ??i


;init UART 0
;CPU clock is 8Mhz
USART_Init:
    ; Set baud rate to 9600 bps with 8MHz clock
    LDI	R16, 103
    STS	UBRR0L, R16
	;set double speed
    LDI	R16,(1 << U2X0)
    STS	UCSR0A,R16
    ; Set frame format: 8 data bits, no parity, 1 stop bit
    LDI	R16,(1 << UCSZ01) | (1 << UCSZ00)
    STS	UCSR0C,R16
    ; Enable transmitter and receiver
    LDI	R16,(1 << RXEN0) | (1 << TXEN0)
    STS	UCSR0B,R16
    RET

;send out 1 byte in r16
USART_SendChar:
    PUSH	R17
    ; Wait for the transmitter to be ready
    USART_SendChar_Wait:
    LDS	R17,UCSR0A
    SBRS	R17,UDRE0		;check USART Data Register Empty bit
    RJMP	USART_SendChar_Wait
    STS	UDR0,R27		;send out
    POP	R17
    RET

;receive 1 byte in r16
USART_ReceiveChar:
    PUSH	R17
    ; Wait for the transmitter to be ready
    USART_ReceiveChar_Wait:
    LDS	R17,UCSR0A
    SBRS	R17, RXC0	;check USART Receive Complete bit
    RJMP	USART_ReceiveChar_Wait
    LDS	R16,UDR0		;get data
    POP	R17
    RET

;-------------
;Display
DISPLAY_V:
;A*Vref = A*2.56

// xet duong am

	LDS AL,ADCL
	LDS AH,ADCH


	MOV R27,AH
	RCALL	USART_SendChar
//	LDI R27,' '
//	RCALL	USART_SendChar
	MOV R27,AL
	RCALL	USART_SendChar


	PUSH AH
	ANDI AH,$02
	BRNE AM
	RJMP DUONG

AM:
	POP AH
	COM AL
	COM AH
	ANDI AH,$01
	LDI R27,1
	ADD AL,R27
	LDI R27,0
	ADC AH,R27
	LDI BL,LOW(5)       ;Load multiplier into BH:BL
    LDI BH,HIGH(5)      ;
	RCALL MUL16x16		;Ket qua: R21,R20
;V=x.----------------------------------------------------------------------------------------
	;A/4000
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.

	LDI R17,$C0
	RCALL CURS_POS

	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	LDI R17,'V'
	RCALL	OUT_LCD4_2
	LDI R17,' '
	RCALL	OUT_LCD4_2
	LDI R17,'='
	RCALL	OUT_LCD4_2
	LDI R17,' '
	RCALL	OUT_LCD4_2
	LDI R17,'-'
	RCALL	OUT_LCD4_2

	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(400)       ;Load multiplier into BH:BL
    LDI BH,HIGH(400)      ;
	RCALL DIV1616

	;Xuat so x._
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2



	LDI		R16,46	;dau "."
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2

;V=x.x----------------------------------------------------------------------------------------

//	LDI R17,$C2
//	RCALL CURS_POS

	;So du*10
	MOV AL,R2
	MOV AH,R3
	LDI BL,LOW(10)       ;Load multiplier into BH:BL
    LDI BH,HIGH(10)      ;
	RCALL MUL16x16		;Ket qua: R21,R20

	;So du*10/1024
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.
	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(400)       ;Load multiplier into BH:BL
    LDI BH,HIGH(400)      ;
	RCALL DIV1616

	;Xuat so _.x
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar


	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2
	
;V=x.xx----------------------------------------------------------------------------------------

//	LDI R17,$C3
//	RCALL CURS_POS

	;So du*10
	MOV AL,R2
	MOV AH,R3
	LDI BL,LOW(10)       ;Load multiplier into BH:BL
    LDI BH,HIGH(10)      ;
	RCALL MUL16x16		;Ket qua: R21,R20

	;So du*10/1024
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.
	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(400)       ;Load multiplier into BH:BL
    LDI BH,HIGH(400)      ;
	RCALL DIV1616

	;Xuat so _._x
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2

;V=x.xxx----------------------------------------------------------------------------------------

//	LDI R17,$C4
//	RCALL CURS_POS

	;So du*10
	MOV AL,R2
	MOV AH,R3
	LDI BL,LOW(10)       ;Load multiplier into BH:BL
    LDI BH,HIGH(10)      ;
	RCALL MUL16x16		;Ket qua: R21,R20

	;So du*10/1024
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.
	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(400)       ;Load multiplier into BH:BL
    LDI BH,HIGH(400)      ;
	RCALL DIV1616

	;Xuat gia tri _.__x
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2

	LDI R17,' '
	RCALL	OUT_LCD4_2
	LDI R17,'V'
	RCALL	OUT_LCD4_2


	;Xuong dong
	LDI		R27,0x0A
	RCALL	USART_SendChar	
	LDI		R27,0x0D
	RCALL	USART_SendChar
RET
	




DUONG:
	POP AH
	
	LDI BL,LOW(1)       ;Load multiplier into BH:BL
    LDI BH,HIGH(1)      ;
	RCALL MUL16x16		;Ket qua: R21,R20
;V=x.----------------------------------------------------------------------------------------
	;A*2.56/512/10 = A/2000
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.

	LDI R17,$C0
	RCALL CURS_POS

	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	LDI R17,'M'
	RCALL	OUT_LCD4_2
	LDI R17,' '
	RCALL	OUT_LCD4_2
	LDI R17,'='
	RCALL	OUT_LCD4_2
	LDI R17,' '
	RCALL	OUT_LCD4_2
	CPI R20,200
	BRNE TT
	LDI R17,'1'
	RCALL OUT_LCD4_2
	LDI R17,'0'
	RCALL OUT_LCD4_2
	LDI R17,'.'
	RCALL OUT_LCD4_2
	LDI R17,'0'
	RCALL OUT_LCD4_2
	LDI R17,'0'
	RCALL OUT_LCD4_2
	RJMP TT1
TT:
	LDI R17,'+'
	RCALL	OUT_LCD4_2

	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(20)       ;Load multiplier into BH:BL
    LDI BH,HIGH(20)      ;
	RCALL DIV1616

	;Xuat so x._
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2



	LDI		R16,46	;dau "."
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2

;V=x.x----------------------------------------------------------------------------------------

//	LDI R17,$C2
//	RCALL CURS_POS

	;So du*10
	MOV AL,R2
	MOV AH,R3
	LDI BL,LOW(10)       ;Load multiplier into BH:BL
    LDI BH,HIGH(10)      ;
	RCALL MUL16x16		;Ket qua: R21,R20

	;So du*10/1024
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.
	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(20)       ;Load multiplier into BH:BL
    LDI BH,HIGH(20)      ;
	RCALL DIV1616

	;Xuat so _.x
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar


	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2
	
;V=x.xx----------------------------------------------------------------------------------------

//	LDI R17,$C3
//	RCALL CURS_POS

	;So du*10
	MOV AL,R2
	MOV AH,R3
	LDI BL,LOW(10)       ;Load multiplier into BH:BL
    LDI BH,HIGH(10)      ;
	RCALL MUL16x16		;Ket qua: R21,R20

	;So du*10/1024
	;Ketqua: R0:gia tri dung, xuat ra LCD. R2,R3 so du.
	MOV AL,R20
	MOV AH,R21
	LDI BL,LOW(20)       ;Load multiplier into BH:BL
    LDI BH,HIGH(20)      ;
	RCALL DIV1616

	;Xuat so _._x
	MOV		R16,R0
	LDI		R17,0x30
	ADD		R16,R17
//	RCALL	USART_SendChar

	MOV		R17,R16
	SBI LCD,RS		;RS=1 ghi data hi?n th? LCD
	RCALL	OUT_LCD4_2
TT1:	
	LDI R17,'K'
	RCALL	OUT_LCD4_2
	LDI R17,'G'
	RCALL	OUT_LCD4_2
RET

;-----------------------------------------------------------------------------
.DEF ZERO = R2               ;To hold Zero
/*.DEF   AL = R16              ;To hold multiplicand
.DEF   AH = R17
.DEF   BL = R18              ;To hold multiplier
.DEF   BH = R19*/
.DEF ANS1 = R20              ;To hold 32 bit answer
.DEF ANS2 = R21
.DEF ANS3 = R22
.DEF ANS4 = R23

        LDI AL,LOW(42)       ;Load multiplicand into AH:AL
        LDI AH,HIGH(42)      ;
        LDI BL,LOW(10)       ;Load multiplier into BH:BL
        LDI BH,HIGH(10)      ;

MUL16x16:
        CLR ZERO             ;Set R2 to zero
        MUL AH,BH            ;Multiply high bytes AHxBH
        MOVW ANS4:ANS3,R1:R0 ;Move two-byte result into answer

        MUL AL,BL            ;Multiply low bytes ALxBL
        MOVW ANS2:ANS1,R1:R0 ;Move two-byte result into answer

        MUL AH,BL            ;Multiply AHxBL
        ADD ANS2,R0          ;Add result to answer
        ADC ANS3,R1          ;
        ADC ANS4,ZERO        ;Add the Carry Bit

        MUL BH,AL            ;Multiply BHxAL
        ADD ANS2,R0          ;Add result to answer
        ADC ANS3,R1          ;
        ADC ANS4,ZERO        ;Add the Carry Bit
RET
;-----------------------------------------------------------------------------
.DEF ANSL = R0            ;To hold low-byte of answer
.DEF ANSH = R1            ;To hold high-byte of answer     
.DEF REML = R2            ;To hold low-byte of remainder
.DEF REMH = R3            ;To hold high-byte of remainder
.DEF   AL = R16           ;To hold low-byte of dividend
.DEF   AH = R17           ;To hold high-byte of dividend
.DEF   BL = R18           ;To hold low-byte of divisor
.DEF   BH = R19           ;To hold high-byte of divisor   
.DEF    C = R20           ;Bit Counter

        LDI AL,LOW(420)   ;Load low-byte of dividend into AL
        LDI AH,HIGH(420)  ;Load HIGH-byte of dividend into AH
        LDI BL,LOW(10)    ;Load low-byte of divisor into BL
        LDI BH,HIGH(10)   ;Load high-byte of divisor into BH
DIV1616:
        MOVW ANSH:ANSL,AH:AL ;Copy dividend into answer
        LDI C,17          ;Load bit counter
        SUB REML,REML     ;Clear Remainder and Carry
        CLR REMH          ;
LOOP:   ROL ANSL          ;Shift the answer to the left
        ROL ANSH          ;
        DEC C             ;Decrement Counter
         BREQ DONE        ;Exit if sixteen bits done
        ROL REML          ;Shift remainder to the left
        ROL REMH          ;
        SUB REML,BL       ;Try to subtract divisor from remainder
        SBC REMH,BH
         BRCC SKIP        ;If the result was negative then
        ADD REML,BL       ;reverse the subtraction to try again
        ADC REMH,BH       ;
        CLC               ;Clear Carry Flag so zero shifted into A 
         RJMP LOOP        ;Loop Back
SKIP:   SEC               ;Set Carry Flag to be shifted into A
         RJMP LOOP
DONE:RET

//----------------------------------------------------------------------------------------------------------

;POWER_RESET_LCD4
;Các l?nh reset c?p ngu?n LCD 4 bit
;Ch? h?n 15ms
;Ghi 4 bit m? l?nh 30H l?n 1, ch? ít nh?t 4.1ms
;Ghi 4 bit m? l?nh 30H l?n 2, ch? ít nh?t 100?s
;Ghi byte m? l?nh 32H, ch? ít nh?t 100?s sau m?i l?n ghi 4 bit
;-------------------------------------------------------
POWER_RESET_LCD4:
	LDI R16,200 		;delay 20ms
	RCALL DELAY_US 		;ctc delay 100?sxR16
;Ghi 4 bit cao m? l?nh 30H l?n 1, ch? 4.2ms
	CBI LCD,RS 			;RS=0 ghi l?nh
	LDI R17,$30 		;m? l?nh=$30 l?n 1,RS=RW=E=0
	RCALL OUT_LCD4 		;ctc ghi ra LCD 4 bit cao
	LDI R16,42 			;delay 4.2ms
	RCALL DELAY_US
;Ghi 4 bit cao m? l?nh 30H l?n 2, ch? 200?s
	CBI LCD,RS 			;RS=0 ghi l?nh
	LDI R17,$30 		;m? l?nh=$30 l?n 2
	RCALL OUT_LCD4 		;ctc ghi ra LCD 4 bit cao
	LDI R16,2 			;delay 200?s
	RCALL DELAY_US
;Ghi byte m? l?nh 32H
	CBI LCD,RS 			;RS=0 ghi l?nh
	LDI R17,$32
	RCALL OUT_LCD4_2		;ctc ghi 1 byte, m?i l?n 4 bit
RET
;-----------------------------------------------------------------



;-----------------------------------------------------------------
;INIT_LCD4 
;Kh?i ??ng LCD ghi 4 byte m? l?nh
;Function set: 0x28: 8 bit, 2 d?ng font 5x8
;Clear display: 0x01: xóa màn h?nh
;Display on/off control: 0x0C: màn h?nh on, con tr? off
;Entry mode set: 0x06: d?ch ph?i con tr?, ??a ch? DDRAM t?ng 1 khi ghi data
;-------------------------------------------------------
INIT_LCD4: CBI LCD,RS 			;RS=0 ghi l?nh
		LDI R17,0x28 		;ch? ?? giao ti?p 8 bit, 2 d?ng font 5x8
		RCALL OUT_LCD4_2
	;-------------------------------------------------------
		CBI LCD,RS 			;RS=0 ghi l?nh
		LDI R17,0x01 		;xóa màn h?nh
		RCALL OUT_LCD4_2
		LDI R16,20 			;ch? 2ms sau l?nh Clear display
		RCALL DELAY_US
	;-------------------------------------------------------
		CBI LCD,RS 			;RS=0 ghi l?nh
		LDI R17,0x0C 		;màn h?nh on, con tr? off
		RCALL OUT_LCD4_2
	;-------------------------------------------------------
		CBI LCD,RS 			;RS=0 ghi l?nh
		LDI R17,0x06 		;d?ch ph?i con tr?, ??a ch? DDRAM t?ng 1 khi ghi data
		RCALL OUT_LCD4_2
	;-------------------------------------------------------
RET
;-----------------------------------------------------------------



;-----------------------------------------------------------------
;OUT_LCD4_2 
;Ghi 1 byte m? l?nh/data ra LCD
;chia làm 2 l?n ghi 4bit: 4 bit cao tr??c, 4 bit th?p sau
;Input: R17 ch?a m? l?nh/data, R16
;bit RS=0/1:l?nh/data,bit RW=0:ghi
;S? d?ng ctc OUT_LCD4
;--------------------------------------------------
OUT_LCD4_2:
	IN R16,LCD 			;??c PORT LCD
	ANDI R16,(1<<RS) 		;l?c bit RS
	PUSH R16 			;c?t R16
	PUSH R17 			;c?t R17
	ANDI R17,$F0 		;l?y 4 bit cao
	OR R17,R16 			;ghép bit RS
	RCALL OUT_LCD4 		;ghi ra LCD
	LDI R16,1 			;ch? 100us
	RCALL DELAY_US
	POP R17 			;ph?c h?i R17
	POP R16 			;ph?c h?i R16
	SWAP R17 			;??o 4 bit
;l?y 4 bit th?p chuy?n thành cao
	ANDI R17,$F0
	OR R17,R16 			;ghép bit RS
	RCALL OUT_LCD4		;ghi ra LCD
	LDI R16,1 			;ch? 100us
	RCALL DELAY_US
RET
;-----------------------------------------------------------------



;-----------------------------------------------------------------
;OUT_LCD4 
;Ghi m? l?nh/data ra LCD
;Input: R17 ch?a m? l?nh/data 4 bit cao
;--------------------------------------------------
OUT_LCD4: 	OUT LCD,R17
		SBI LCD,E
		CBI LCD,E
RET
;-----------------------------------------------------------------


;-----------------------------------------------------------------
;DELAY_US 
;T?o th?i gian tr? =R16x100?s(Fosc=8MHz, CKDIV8 = 1)
;Input:R16 h? s? nhân th?i gian tr? 1 ??n 255
;-------------------------------------------------------
DELAY_US: 	MOV R15,R16 	;1MC n?p data cho R15
		LDI R16,200 	;1MC s? d?ng R16

L1: 		MOV R14,R16 	;1MC n?p data cho R14

L2: 		DEC R14 		;1MC
		NOP ;1MC
		BRNE L2 		;2/1MC
		DEC R15 		;1MC
		BRNE L1 		;2/1MC
RET 					;4MC
;-----------------------------------------------------------------


;------------------------------------------------------------------
;CURS_POS ??t con tr? t?i v? trí có ??a ch? trong R17
;Input: R17=$80 -$8F d?ng 1,$C0-$CF d?ng 2
;R17= ??a ch? v? trí con tr?
;S? d?ng R16,ctc DEAY_US,OUT_LCD
;----------------------------------------------------------
CURS_POS: 
		LDI R16,1 ;ch? 100?s
		RCALL DELAY_US
		CBI LCD,RS ;RS=0 ghi l?nh
		RCALL OUT_LCD4_2
RET
;------------------------------------------------------------------
.ORG $300
STRING: .DB "CAN NANG:",$0D