
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
; Variaveis do driver grafico
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
; Variaveis temporarias do boot
; Devem permanecer na Zero Page
; ==========================================

.segment "ZEROPAGE"

boot_src:   .res 2
boot_dst:   .res 2
boot_count: .res 2

; ==========================================
; Variaveis globais
; ==========================================

.segment "BSS"

nmi_count:
    .res 1

; ==========================================
; Cabecalho iNES
; ==========================================

.segment "HEADER"

    .byte $4E, $45, $53, $1A
    .byte 2, 1
    .byte 0, 0
    .res 8, 0

; ==========================================
; Codigo de inicializacao
; ==========================================

.segment "CODE"

reset:
    sei
    cld

    ; Inicializa a pilha de hardware
    ldx #$FF
    txs

    ; Desabilita NMI e renderizacao
    lda #$00
    sta $2000
    sta $2001

    ; Aguarda dois VBlanks
wait_vblank_1:
    bit $2002
    bpl wait_vblank_1

wait_vblank_2:
    bit $2002
    bpl wait_vblank_2

    ; Inicializa a pilha de software do cc65
    lda #<__CSTACK_START__
    sta sp

    lda #>__CSTACK_START__
    sta sp+1

    ; ======================================
    ; Copia DATA da ROM para RAM
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
    ; Zera BSS
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
    ; Inicia o kernel em C
    ; ======================================

start_c:
    jsr _kernel_main

forever:
    jmp forever

; ==========================================
; Copia DATA da ROM para RAM
;
; boot_src   = origem
; boot_dst   = destino
; boot_count = quantidade de bytes
; ==========================================

copy_data:
    lda boot_count
    ora boot_count+1
    beq @done

@loop:
    ldy #$00

    lda (boot_src),y
    sta (boot_dst),y

    ; Incrementa ponteiro de origem
    inc boot_src
    bne :+
    inc boot_src+1
:
    ; Incrementa ponteiro de destino
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
; Zera BSS
; ==========================================

clear_bss:
    lda boot_count
    ora boot_count+1
    beq @done

@loop:
    ldy #$00
    lda #$00
    sta (boot_dst),y

    ; Incrementa ponteiro de destino
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
; Decrementa contador de 16 bits
; ==========================================

decrement_count:
    lda boot_count
    bne @low

    dec boot_count+1

@low:
    dec boot_count
    rts

; ==========================================
; NMI - Atualizacao grafica no VBlank
; ==========================================

nmi:
    ; Preserva A, X e Y
    pha

    txa
    pha

    tya
    pha

    ; Contador de VBlanks
    inc nmi_count

    ; Libera o processo de entrada uma vez por quadro.
    lda #$00
    sta _keyboard_waiting

    ; Somente comandos publicados por tail sao visiveis.
    lda _gfx_head
    cmp _gfx_tail
    beq @done

    ; O numero de comandos por frame e limitado mesmo com fila maior.
    ldy #GFX_NMI_BUDGET
    bit $2002
@command:
    ; X = head * 3 (x, y, tile). Nao usa temporarios da zero page do C.
    lda _gfx_head
    asl a
    clc
    adc _gfx_head
    tax

    ; Endereco alto = $20 | (y >> 3).
    lda _gfx_queue+1,x
    lsr a
    lsr a
    lsr a
    ora #$20
    sta $2006

    ; Endereco baixo = ((y & 7) << 5) | x.
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

    ; Libera a vaga apenas depois da escrita completa na PPU.
    ; gfx_head e escrito somente aqui; gfx_tail e escrito somente pelo C.
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
    ; Restaura nametable 0, incremento de 1 e NMI habilitada.
    lda #%10000000
    sta $2000

    ; Restaura o scroll para (0,0)
    ; Nosso driver ainda usa apenas a nametable 0
    bit $2002

    lda #$00
    sta $2005
    sta $2005

    ; Nao escrever em $2006 aqui: isso alteraria o scroll restaurado.

@done:
    ; Restaura Y
    pla
    tay

    ; Restaura X
    pla
    tax

    ; Restaura A
    pla

    ; Retorna da interrupcao
    rti

; ==========================================
; Vetores de interrupcao
; ==========================================

.segment "VECTORS"

    .word nmi
    .word reset
    .word irq_handler

; ==========================================
; CHR-ROM
; ==========================================

.segment "CHARS"

    ; ASCII 32..126: um tile por codigo, mais o simbolo de multiplicacao.
    .incbin "font.chr"
