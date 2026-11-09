
.setcpu "6502"

.export _debug_port_putchar

.segment "CODE"

; Input: A = ASCII character
; Output: write to the virtual port at $5FF0
; Preserves: A, X, and Y
; Flags: unchanged
_debug_port_putchar:
    sta $5FF0
    rts
