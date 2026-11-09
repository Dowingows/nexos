
.setcpu "6502"

.export __STARTUP__: absolute
__STARTUP__ = 1

.import _kernel_main
.import _context_test

.import __CSTACK_START__
.import __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.import __BSS_RUN__, __BSS_SIZE__
.importzp sp

.export ___BSS_RUN__
.export ___BSS_SIZE__

___BSS_RUN__  = __BSS_RUN__
___BSS_SIZE__ = __BSS_SIZE__

; ==========================================
; Graphics driver variables
; ==========================================

.include "video_config.inc"
.import _gfx_head, _gfx_tail, _gfx_queue, _gfx_waiting
.import _keyboard_waiting

.assert GFX_COMMAND_SIZE = 3, error, "Comando grafico deve ter 3 bytes"
.assert GFX_QUEUE_SIZE >= 2 .and GFX_QUEUE_SIZE <= 64, error, "Tamanho da fila invalido"
.assert (GFX_QUEUE_SIZE & (GFX_QUEUE_SIZE - 1)) = 0, error, "Fila deve ser potencia de dois"
.assert GFX_NMI_BUDGET >= 1 .and GFX_NMI_BUDGET <= 8, error, "Orcamento NMI invalido"

.import irq_handler

; ==========================================
; Temporary boot variables
; Must remain in zero page
; ==========================================

.segment "ZEROPAGE"

boot_src:   .res 2
boot_dst:   .res 2
boot_count: .res 2

; ==========================================
; Global variables
; ==========================================

.segment "BSS"

nmi_count:
    .res 1

; ==========================================
; iNES header
; ==========================================

.segment "HEADER"

    .byte $4E, $45, $53, $1A
    .byte 2, 1
    .byte 0, 0
    .res 8, 0

; ==========================================
; Initialization code
; ==========================================

.segment "CODE"

reset:
    sei
    cld

    ; Initialize the hardware stack
    ldx #$FF
    txs

    ; Disable NMI and rendering
    lda #$00
    sta $2000
    sta $2001

    ; Wait for two VBlanks
wait_vblank_1:
    bit $2002
    bpl wait_vblank_1

wait_vblank_2:
    bit $2002
    bpl wait_vblank_2

    ; Initialize the cc65 software stack
    lda #<__CSTACK_START__
    sta sp

    lda #>__CSTACK_START__
    sta sp+1

    ; ======================================
    ; Copy DATA from ROM to RAM
    ; ======================================

    lda #<__DATA_LOAD__
    sta boot_src

    lda #>__DATA_LOAD__
    sta boot_src+1

    lda #<__DATA_RUN__
    sta boot_dst

    lda #>__DATA_RUN__
    sta boot_dst+1

    lda #<__DATA_SIZE__
    sta boot_count

    lda #>__DATA_SIZE__
    sta boot_count+1

    jsr copy_data

    ; ======================================
    ; Clear BSS
    ; ======================================

    lda #<__BSS_RUN__
    sta boot_dst

    lda #>__BSS_RUN__
    sta boot_dst+1

    lda #<__BSS_SIZE__
    sta boot_count

    lda #>__BSS_SIZE__
    sta boot_count+1

    jsr clear_bss

    ; ======================================
    ; Start the C kernel
    ; ======================================

start_c:
    jsr _kernel_main

forever:
    jmp forever

; ==========================================
; Copy DATA from ROM to RAM
;
; boot_src   = source
; boot_dst   = destination
; boot_count = byte count
; ==========================================

copy_data:
    lda boot_count
    ora boot_count+1
    beq @done

@loop:
    ldy #$00

    lda (boot_src),y
    sta (boot_dst),y

    ; Increment the source pointer
    inc boot_src
    bne :+
    inc boot_src+1
:
    ; Increment the destination pointer
    inc boot_dst
    bne :+
    inc boot_dst+1
:
    jsr decrement_count

    lda boot_count
    ora boot_count+1
    bne @loop

@done:
    rts

; ==========================================
; Clear BSS
; ==========================================

clear_bss:
    lda boot_count
    ora boot_count+1
    beq @done

@loop:
    ldy #$00
    lda #$00
    sta (boot_dst),y

    ; Increment the destination pointer
    inc boot_dst
    bne :+
    inc boot_dst+1
:
    jsr decrement_count

    lda boot_count
    ora boot_count+1
    bne @loop

@done:
    rts

; ==========================================
; Decrement the 16-bit counter
; ==========================================

decrement_count:
    lda boot_count
    bne @low

    dec boot_count+1

@low:
    dec boot_count
    rts

; ==========================================
; NMI - graphics update during VBlank
; ==========================================

nmi:
    ; Preserve A, X, and Y
    pha

    txa
    pha

    tya
    pha

    ; VBlank counter
    inc nmi_count

    ; Wake the input process once per frame.
    lda #$00
    sta _keyboard_waiting

    ; Only commands published by tail are visible.
    lda _gfx_head
    cmp _gfx_tail
    beq @done

    ; Limit commands per frame, even if the queue is larger.
    ldy #GFX_NMI_BUDGET
    bit $2002
@command:
    ; X = head * 3 (x, y, tile). Does not use C zero-page temporaries.
    lda _gfx_head
    asl a
    clc
    adc _gfx_head
    tax

    ; High address byte = $20 | (y >> 3).
    lda _gfx_queue+1,x
    lsr a
    lsr a
    lsr a
    ora #$20
    sta $2006

    ; Low address byte = ((y & 7) << 5) | x.
    lda _gfx_queue+1,x
    asl a
    asl a
    asl a
    asl a
    asl a
    ora _gfx_queue,x
    sta $2006

    lda _gfx_queue+2,x
    sta $2007

    ; Free the slot only after the complete PPU write.
    ; Only this code writes gfx_head; only C writes gfx_tail.
    lda _gfx_head
    clc
    adc #1
    and #(GFX_QUEUE_SIZE - 1)
    sta _gfx_head
    lda #0
    sta _gfx_waiting

    dey
    beq @restore_scroll
    lda _gfx_head
    cmp _gfx_tail
    bne @command

@restore_scroll:
    ; Restore nametable 0, increment by 1, and keep NMI enabled.
    lda #%10000000
    sta $2000

    ; Restore scroll to (0,0).
    ; This driver still uses only nametable 0.
    bit $2002

    lda #$00
    sta $2005
    sta $2005

    ; Do not write to $2006 here; it would change the restored scroll.

@done:
    ; Restore Y.
    pla
    tay

    ; Restore X.
    pla
    tax

    ; Restore A.
    pla

    ; Return from interrupt.
    rti

; ==========================================
; Interrupt vectors
; ==========================================

.segment "VECTORS"

    .word nmi
    .word reset
    .word irq_handler

; ==========================================
; CHR-ROM
; ==========================================

.segment "CHARS"

    ; ASCII 32..126: one tile per code, plus the multiplication sign.
    .incbin "font.chr"
