
.setcpu "6502"

.export _debug_port_putchar

.segment "CODE"

; Entrada: A = caractere ASCII
; Saída: escreve na porta virtual $5FF0
; Preserva: A, X, Y
; Flags: não modificadas
_debug_port_putchar:
    sta $5FF0
    rts
