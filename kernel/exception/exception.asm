.setcpu "6502"

; ==========================================
; NexOS - Exception / Interrupt Handler
; ==========================================

.export _trigger_exception
.export irq_handler

; Global variables defined in exception.c
.import _exception_a
.import _exception_x
.import _exception_y
.import _exception_status
.import _exception_pc

; Exception handler implemented in C
.import _exception_handler

.segment "CODE"

; ==========================================
; TRIGGER EXCEPTION
;
; Trigger a software interrupt with BRK.
; Does not intentionally modify A, X, or Y.
;
; BRK automatically pushes PC + 2 and STATUS.
; ==========================================

_trigger_exception:
    brk
    .byte $EA           ; Byte de assinatura ignorado pelo BRK
    rts                 ; Executado se o handler retornar


; ==========================================
; IRQ / BRK HANDLER
;
; Entry through the IRQ/BRK vector ($FFFE).
;
; The CPU has already pushed:
;   PC alto
;   PC baixo
;   STATUS
;
; Save manually:
;   A, X, Y
; ==========================================

irq_handler:
    ; 1. Preserve registers
    pha                 ; Salva A

    txa
    pha                 ; Salva X

    tya
    pha                 ; Salva Y

    ; 2. Read the hardware stack pointer
    tsx

    ; Stack layout after the three PHA instructions:
    ;
    ; $0101,X = Y
    ; $0102,X = X
    ; $0103,X = A
    ; $0104,X = STATUS
    ; $0105,X = PC baixo
    ; $0106,X = PC alto

    ; 3. Save registers to BSS

    lda $0103,x
    sta _exception_a

    lda $0102,x
    sta _exception_x

    lda $0101,x
    sta _exception_y

    ; 4. Save STATUS

    lda $0104,x
    sta _exception_status

    ; 5. Identify BRK or IRQ
    ;
    ; Bit 4 of the pushed STATUS:
    ; 1 = BRK
    ; 0 = IRQ de hardware

    and #$10
    beq @hardware_irq

; ==========================================
; SOFTWARE EXCEPTION (BRK)
; ==========================================

@software_brk:
    ; 6. Read the PC saved by the CPU

    lda $0105,x
    sta _exception_pc

    lda $0106,x
    sta _exception_pc+1

    ; 7. Correct the PC.
    ;
    ; BRK saves the address two bytes
    ; after the BRK opcode.
    ;
    ; exception_pc = saved_PC - 2

    sec
    lda _exception_pc
    sbc #2
    sta _exception_pc

    lda _exception_pc+1
    sbc #0
    sta _exception_pc+1

    ; 8. Call the C handler.
    ;
    ; exception_handler() prints the report
    ; and enters an infinite loop.
    ;
    ; Do not restore registers here,
    ; because the exception is fatal.

    jsr _exception_handler

@halt:
    jmp @halt

; ==========================================
; HARDWARE IRQ
; ==========================================

@hardware_irq:
    ; 9. Restore Y, X, and A.
    ;
    ; Reverse the push order.

    pla
    tay                 ; Restore Y.

    pla
    tax                 ; Restore X.

    pla                 ; Restore A.

    ; 10. RTI restores STATUS and PC.
    ;
    ; Execution resumes at the address
    ; interrupted by the IRQ.

    rti