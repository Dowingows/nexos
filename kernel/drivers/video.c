#include "video.h"
#include "../common.h"
#define NAMETABLE_BASE 0x2000

unsigned char ppu_addr_hi;
unsigned char ppu_addr_lo;
unsigned char ppu_tile;

/* C publica tail; apenas a NMI avanca head. Nao ha contador compartilhado. */
volatile unsigned char gfx_head;
volatile unsigned char gfx_tail;
volatile unsigned char gfx_waiting;
volatile gfx_command_t gfx_queue[GFX_QUEUE_SIZE];

void ppu_write(void);

void gfx_set_tile(unsigned char x,
                  unsigned char y,
                  unsigned char tile){
    nes_uint16_t address;

    address = NAMETABLE_BASE + (y * 32u) + x;

    ppu_addr_hi = (unsigned char)(address >> 8);
    ppu_addr_lo = (unsigned char)(address & 0xFF);
    ppu_tile = tile;

    ppu_write();
}

unsigned char gfx_enqueue_tile(
    unsigned char x,
    unsigned char y,
    unsigned char tile
)
{
    unsigned char tail;
    unsigned char next;

    /* Valida as coordenadas */
    if (x >= 32 || y >= 30) {
        return 0;
    }

    tail = gfx_tail;

    /* Calcula a proxima posicao */
    next = (tail + 1) & (GFX_QUEUE_SIZE - 1);

    /* Verifica se a fila esta cheia */
    if (next == gfx_head) {
        return 0;
    }

    /* Prepara o comando */
    gfx_queue[tail].x = x;
    gfx_queue[tail].y = y;
    gfx_queue[tail].tile = tile;

    /* Publica o comando */
    gfx_tail = next;

    return 1;
}
