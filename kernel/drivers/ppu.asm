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
    ; Boot has already waited for the two VBlanks required by the PPU.
    ; Initialization leaves rendering and NMI disabled while preparing the screen.
    lda #$00
    sta $2000
    sta $2001
    sta _gfx_head
    sta _gfx_tail
    sta _gfx_waiting

    ; Clear the 960 tiles and 64 attribute bytes in nametable 0.
    jsr _gfx_clear

    ; Initialize all palettes without relying on the current VRAM contents.
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

    ; Select nametable 0 and initialize scroll to (0,0).
    bit $2002
    lda #$00
    sta $2000
    sta $2005
    sta $2005
    rts

_ppu_write:
    ; Reset the write sequence.
    bit $2002

    ; High address byte.
    lda _ppu_addr_hi
    sta $2006

    ; Low address byte.
    lda _ppu_addr_lo
    sta $2006

    ; Tile index.
    lda _ppu_tile
    sta $2007

    rts

_video_enable:
    ; Set scroll to (0,0).
    bit $2002

    lda #$00
    sta $2005
    sta $2005

    ; Select nametable 0, increment by 1, and enable NMI at each VBlank.
    lda #%10000000
    sta $2000

    ; Enable the background, including the leftmost columns.
    lda #%00001010
    sta $2001

    rts

_gfx_clear:
    ; Reset the latch.
    bit $2002

    ; Select nametable 0: $2000.
    lda #$20
    sta $2006

    lda #$00
    sta $2006

    ; Write 1024 zero bytes.
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

; Black background with the first color white; palettes match until themes are added.
default_palette:
    .repeat 8
        .byte $0F, $30, $0F, $0F
    .endrepeat
