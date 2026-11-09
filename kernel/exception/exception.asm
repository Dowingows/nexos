.setcpu "6502"

; ==========================================
; NexOS - Exception / Interrupt Handler
; ==========================================

.export _trigger_exception
.export irq_handler

; Variáveis globais definidas em exception.c
.import _exception_a
.import _exception_x
.import _exception_y
.import _exception_status
.import _exception_pc

; Handler de exceção implementado em C
.import _exception_handler

.segment "CODE"

; ==========================================
; TRIGGER EXCEPTION
;
; Dispara uma interrupção de software usando BRK.
; Não altera A, X ou Y intencionalmente.
;
; BRK empilha PC + 2 e STATUS automaticamente.
; ==========================================

_trigger_exception:
    brk
    .byte $EA           ; Byte de assinatura ignorado pelo BRK
    rts                 ; Executado se o handler retornar


; ==========================================
; IRQ / BRK HANDLER
;
; Entrada pelo vetor IRQ/BRK ($FFFE).
;
; A CPU já empilhou:
;   PC alto
;   PC baixo
;   STATUS
;
; Salvamos manualmente:
;   A, X, Y
; ==========================================

irq_handler:
    ; 1. Preservar registradores
    pha                 ; Salva A

    txa
    pha                 ; Salva X

    tya
    pha                 ; Salva Y

    ; 2. Obter o SP da pilha de hardware
    tsx

    ; Layout da pilha após os três PHA:
    ;
    ; $0101,X = Y
    ; $0102,X = X
    ; $0103,X = A
    ; $0104,X = STATUS
    ; $0105,X = PC baixo
    ; $0106,X = PC alto

    ; 3. Capturar registradores para a BSS

    lda $0103,x
    sta _exception_a

    lda $0102,x
    sta _exception_x

    lda $0101,x
    sta _exception_y

    ; 4. Capturar STATUS

    lda $0104,x
    sta _exception_status

    ; 5. Identificar BRK ou IRQ
    ;
    ; Bit 4 do STATUS empilhado:
    ; 1 = BRK
    ; 0 = IRQ de hardware

    and #$10
    beq @hardware_irq

; ==========================================
; SOFTWARE EXCEPTION (BRK)
; ==========================================

@software_brk:
    ; 6. Capturar PC salvo pela CPU

    lda $0105,x
    sta _exception_pc

    lda $0106,x
    sta _exception_pc+1

    ; 7. Corrigir o PC.
    ;
    ; BRK salva o endereço de dois bytes
    ; após o opcode BRK.
    ;
    ; exception_pc = PC_salvo - 2

    sec
    lda _exception_pc
    sbc #2
    sta _exception_pc

    lda _exception_pc+1
    sbc #0
    sta _exception_pc+1

    ; 8. Chamar o handler em C.
    ;
    ; exception_handler() imprime o relatório
    ; e entra em loop infinito.
    ;
    ; Não restauramos os registradores aqui,
    ; pois a exceção é fatal.

    jsr _exception_handler

@halt:
    jmp @halt

; ==========================================
; HARDWARE IRQ
; ==========================================

@hardware_irq:
    ; 9. Restaurar Y, X e A.
    ;
    ; Ordem inversa do empilhamento.

    pla
    tay                 ; Restaura Y

    pla
    tax                 ; Restaura X

    pla                 ; Restaura A

    ; 10. RTI restaura STATUS e PC.
    ;
    ; A execução continua no endereço
    ; interrompido pela IRQ.

    rti