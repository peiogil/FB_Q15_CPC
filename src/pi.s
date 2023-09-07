; ******************************************************************************
; * � 2008 Microchip Technology Inc.
; *
; SOFTWARE LICENSE AGREEMENT:
; Microchip Technology Incorporated ("Microchip") retains all ownership and 
; intellectual property rights in the code accompanying this message and in all 
; derivatives hereto.  You may use this code, and any derivatives created by 
; any person or entity by or on your behalf, exclusively with Microchip's
; proprietary products.  Your acceptance and/or use of this code constitutes 
; agreement to the terms and conditions of this notice.
;
; CODE ACCOMPANYING THIS MESSAGE IS SUPPLIED BY MICROCHIP "AS IS".  NO 
; WARRANTIES, WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, BUT NOT LIMITED 
; TO, IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A 
; PARTICULAR PURPOSE APPLY TO THIS CODE, ITS INTERACTION WITH MICROCHIP'S 
; PRODUCTS, COMBINATION WITH ANY OTHER PRODUCTS, OR USE IN ANY APPLICATION. 
;
; YOU ACKNOWLEDGE AND AGREE THAT, IN NO EVENT, SHALL MICROCHIP BE LIABLE, WHETHER 
; IN CONTRACT, WARRANTY, TORT (INCLUDING NEGLIGENCE OR BREACH OF STATUTORY DUTY), 
; STRICT LIABILITY, INDEMNITY, CONTRIBUTION, OR OTHERWISE, FOR ANY INDIRECT, SPECIAL, 
; PUNITIVE, EXEMPLARY, INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, FOR COST OR EXPENSE OF 
; ANY KIND WHATSOEVER RELATED TO THE CODE, HOWSOEVER CAUSED, EVEN IF MICROCHIP HAS BEEN 
; ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE.  TO THE FULLEST EXTENT 
; ALLOWABLE BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL CLAIMS IN ANY WAY RELATED TO 
; THIS CODE, SHALL NOT EXCEED THE PRICE YOU PAID DIRECTLY TO MICROCHIP SPECIFICALLY TO 
; HAVE THIS CODE DEVELOPED.
;
; You agree that you are solely responsible for testing the code and 
; determining its suitability.  Microchip has no obligation to modify, test, 
; certify, or support the code.
;
; *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        ; Local inclusions.
        .nolist
    	.include        "dspcommon.inc"         ; fractsetup
        .list

        .equ    offsetabcCoefficients, 0
        .equ    offsetcontrolHistory, 2
        .equ    offsetcontrolOutput, 4
        .equ    offsetmeasuredOutput, 6
        .equ    offsetcontrolReference, 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .section .libdsp, code 	; la libreria dsp se a�ade

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; _PIDInitBoost2:
;
; Prototype:
; void PIDInitBuck( tPID *fooPIDStruct )
;
; Operation: This routine clears the delay line elements in the array
;            _ControlHistory, as well as clears the current PID output
;            element, _ControlOutput
;
; Input:
;       w0 = Address of data structure tPID (type defined in dsp.h)
;
; Return:
;       (void)
;
; System resources usage:
;       w0             used, restored
;
; DO and REPEAT instruction usage.
;       0 level DO instruction
;       0 REPEAT intructions
;
; Program words (24-bit instructions):
;       ??
;
; Cycles (including C-function call and return overheads):
;       ??
;............................................................................

; definicion de la funcion _PIDInitBuck
.global _PIDInitBoost
; inicio de la funcion
_PIDInitBoost:
 push    w0
        add     #offsetcontrolOutput, w0 ;clear controlOutput (o sea d)
        clr     [w0]
		pop		w0	;recupera el valor inicial de wo para volver a usarlo
		push	w0	;y lo vuelve a salvar en la cima del stack
                                        ;Set up pointer to the base of
                                        ;controlHistory variables within tPID
        mov     [w0 + #offsetcontrolHistory], w0
                                        ; Clear controlHistory variables (errores)
                                        ; within tPID
        clr     [w0++]                  ; ControlHistory[n]=0
        clr     [w0++]                  ; ControlHistory[n-1] = 0
        clr     [w0]                    ; ControlHistory[n-2] = 0
        pop     w0                      ;Restore pointer to base of tPID
return
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; _PIDBoost:
; Prototype:
;              tPID PID ( tPID *fooPIDStruct )
;
; Operation:
;
;                                           
;Reference                                                        
;Input         ---                    ------------------                 ----------
;     --------| + |  Control         |B0+B1Z^-1+B3Z^-3 | Control       | Output   |       
;             |   |----------|----|  |---------------  | ------------  | Plant    |----
;        -----| - |Difference        | 1+A1Z^-1+A2Z^-2 |      	       |          |     |
;       |      ---  (error)  |        ------------------                -----------     |
;       |                                                                               |
;       | Measured                                                                      |
;       | Outut                                                                         |
;       |                                                                               |
;       |                                                                               |
;       |                                                                               |
;        --------------------------------------------------------------------------------
;
; Input:
;       w0 = Address of tPID data structure

; Return:
;       w0 = Address of tPID data structure
;
; System resources usage:
;       
;       {w..w10}        saved, used, restored
;        AccA, AccB     used, not restored
;        CORCON         saved, used, restored
;
; DO and REPEAT instruction usage.
;       0 level DO instruction
;       0 REPEAT intructions
;
; Program words (24-bit instructions):
;       ??
;
; Cycles (including C-function call and return overheads):
;       ??
;............................................................................

  .global _PIDBoost                   ; provide global scope to routine
_PIDBoost:
        ;btg LATD, #1
        ; Save working registers.
        push.s
        push    w4
        push    w5        
        push    w8
        push    w10       

        	; macro para programar CORCON: fraccional y saturacion
; se toman los valores de los campos de la variable tpid en los siguientes resitros de trabajo
        mov [w0 + #offsetabcCoefficients], w8    ; w8 = Base Address of _abcCoefficients array 
;w10 <----- puntero a la primera posicion de memoria con error o d (memoria y)      
 		mov [w0 + #offsetcontrolHistory], w10    ; w10 = Base Address of _ControlHistory array (state/delay line)
;w1 <----- valor d antes de hacer el nuevo calculo
        mov [w0 + #offsetcontrolOutput], w1
;w2 <----- valor actual de la variable a controlar (vout del reductor 2)
        mov [w0 + #offsetmeasuredOutput], w2
;w3 <----- valor actual de la referencia a alcanzar
        mov [w0 + #offsetcontrolReference], w3
			
;recolocacion de las posiciones de control y error en sus nuevas posiciones
;dejando d(n-1) y e[n] listo para actualizarlo con el valor nuevo de error.
	
		mov [w10],w11
		mov w11, [w10 + #+2] ;e[n]==> e[n-1]

;0.0075 (z-0.64)
;---------------
;     (z-1)
;2.052 z^3 - 1.958 z^2 - 2.051 z + 1.959
;---------------------------------------
; z^3 - 2.858 z^2 + 2.721 z - 0.8629

		; ([W10])-->e[n]<== LIBRE
; Calculate most recent error with saturation, no limit checking required
		; acumulador b<-----w3(referencia), a = tpid.controlreference
		lac w3, b
		; acumulador a<-----w2(valor actual de la variable a controlar), a = tpid.measuredoutput
		lac w2, a
		; acumulador b<-----referencia-valor actual, error [n]
		sub b
		; se redondea sac.r(store acumulator with rounding) 
		;y se mete en [w10], e[n]
		; (se redondea, porque acc 40 bits y [w10], 16 bits---->IMPORTANTE EXAMINAR EL REDONDEO
		sac.r b, [w10]
;-----------------------------------------------------------------
		clr a
		mov [w8++],w4
		mov [w10++], w5 	; w4 = b0, w5 = e[n] [w8]=b1 [w10]=e[n-1]
		; se multiplica y se prepara la siguiente multiplicacion
		; a =  b0 * e[n]
		; w4 = b1, w5 = e[n-1] [w8]=b1 [w10]=d[n-1]
		mac w4*w5, a, [w8], w4, [w10]+=2, w5
;-----------------------------------------------------------------
		; a = b0 * e[n]+ b1 * e[n-1] * e[n-2]
		; w4 = b3, w5 = d[n-1] [w8]=b1 [w10]=d[n-1]
		mac w4*w5, a, [w8], w4, [w10], w5
;--------------------------------------------------------------------
		lac w5,b
		add a
		; a = b0 * e[n] - e[n-1]+ b1 * e[n-1]+d[n-1]
		; se tiene en a, el valor de la ecuacion en diferencias del regulador PI
		; se redondea el valor de d que hay en acc a (40 bits) y se mete la parte mas significativa en w1(16 bits)
		sac.r a, w1
;-------------------------------------------------------------------------------
;antiWindUp
	  	mov #0x3fff,w2
		cpslt w1,w2
		mov w2,w1
		mov #0x48, w2
        cpsgt w1,w2
 		mov w2,w1
		

;---------------------------------------------------------
mov w1,[w10]		;w1==>d[n-1]
mov w1, [w0 + #offsetcontrolOutput]
; se recupera de la pila lo que habia en los registros que han sido usados

pop w10
pop w8
pop w5
pop w4
pop.s
return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OEF

