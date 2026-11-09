#ifndef NEXOS_VIDEO_H
#define NEXOS_VIDEO_H

/* Initialize nametable 0, palettes, and scroll; leave rendering/NMI disabled.
 * Call during boot, after the PPU stabilization delay.
 */
void video_init(void);
void video_enable(void);

/* Layout shared with the NMI; Makefile generates video_config.inc.
 * One slot remains empty: usable capacity is GFX_QUEUE_SIZE - 1.
 */
#define GFX_QUEUE_SIZE 16
#define GFX_COMMAND_SIZE 3
#define GFX_NMI_BUDGET 8

#if GFX_QUEUE_SIZE < 2 || GFX_QUEUE_SIZE > 64 || (GFX_QUEUE_SIZE & (GFX_QUEUE_SIZE - 1))
#error GFX_QUEUE_SIZE must be a power of two between 2 and 64
#endif

typedef struct {
    unsigned char x;
    unsigned char y;
    unsigned char tile;
} gfx_command_t;

extern volatile unsigned char gfx_head;
extern volatile unsigned char gfx_tail;
extern volatile gfx_command_t gfx_queue[GFX_QUEUE_SIZE];
/* Wait event: the producer arms it before trying; the NMI clears it after consuming. */
extern volatile unsigned char gfx_waiting;

/* Immediate write; use while rendering and NMI are disabled. */
void gfx_set_tile(unsigned char x,
                  unsigned char y,
                  unsigned char tile);

/* Nonblocking: return 1 if accepted, 0 if full or out of bounds.
 * For cooperative tasks only; do not call from IRQ/NMI or yield in the producer.
 */
unsigned char gfx_enqueue_tile(unsigned char x,
                             unsigned char y,
                             unsigned char tile);

/* Clear nametable 0 and attributes; requires rendering/NMI to be disabled. */
void gfx_clear(void);

#endif
