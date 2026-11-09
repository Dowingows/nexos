.setcpu "6502"

.export _ppu_write

.import _ppu_addr_hi
.import _ppu_addr_lo
.import _ppu_tile
.import _gfx_head, _gfx_tail, _gfx_waiting

.export _video_init
.export _video_enable
.export _gfx_clear

.segment "CODE"

_video_init:
    ; Boot ja aguardou os dois VBlanks exigidos pela PPU.
    ; Inicializacao deixa exibicao e NMI desligadas para preparar a tela.
    lda #$00
    sta $2000
    sta $2001
    sta _gfx_head
    sta _gfx_tail
    sta _gfx_waiting

    ; Limpa os 960 tiles e os 64 bytes de atributos da nametable 0.
    jsr _gfx_clear

    ; Inicializa todas as paletas, sem depender do estado da VRAM.
    bit $2002
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$00
@palette:
    lda default_palette,x
    sta $2007
    inx
    cpx #32
    bne @palette

    ; Nametable 0 e scroll inicial (0,0).
    bit $2002
    lda #$00
    sta $2000
    sta $2005
    sta $2005
    rts

_ppu_write:
    ; Reinicia a sequencia de escrita
    bit $2002

    ; Byte alto do endereco
    lda _ppu_addr_hi
    sta $2006

    ; Byte baixo do endereco
    lda _ppu_addr_lo
    sta $2006

    ; Indice do tile
    lda _ppu_tile
    sta $2007

    rts

_video_enable:
    ; Configura o scroll para (0,0)
    bit $2002

    lda #$00
    sta $2005
    sta $2005

    ; Nametable 0, incremento de 1 e NMI no inicio de cada VBlank.
    lda #%10000000
    sta $2000

    ; Habilita o fundo, inclusive na esquerda
    lda #%00001010
    sta $2001

    rts

_gfx_clear:
    ; Reinicia o latch
    bit $2002

    ; Seleciona a nametable 0: $2000
    lda #$20
    sta $2006

    lda #$00
    sta $2006

    ; Escreveremos 1024 bytes com valor zero
    lda #$00
    ldx #$04

@page:
    ldy #$00

@byte:
    sta $2007
    iny
    bne @byte

    dex
    bne @page

    rts

.segment "RODATA"

; Fundo preto, primeiro pixel branco; paletas iguais ate haver temas.
default_palette:
    .repeat 8
        .byte $0F, $30, $0F, $0F
    .endrepeat
