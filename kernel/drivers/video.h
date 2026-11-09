#ifndef NEXOS_VIDEO_H
#define NEXOS_VIDEO_H

/* Inicializa nametable 0, paletas e scroll; deixa exibicao/NMI desligadas.
 * Chamar no boot, depois da espera de estabilizacao da PPU.
 */
void video_init(void);
void video_enable(void);

/* Layout compartilhado com a NMI (Makefile gera video_config.inc).
 * Uma posicao fica vazia: capacidade util = GFX_QUEUE_SIZE - 1.
 */
#define GFX_QUEUE_SIZE 16
#define GFX_COMMAND_SIZE 3
#define GFX_NMI_BUDGET 8

#if GFX_QUEUE_SIZE < 2 || GFX_QUEUE_SIZE > 64 || (GFX_QUEUE_SIZE & (GFX_QUEUE_SIZE - 1))
#error GFX_QUEUE_SIZE deve ser potencia de dois entre 2 e 64
#endif

typedef struct {
    unsigned char x;
    unsigned char y;
    unsigned char tile;
} gfx_command_t;

extern volatile unsigned char gfx_head;
extern volatile unsigned char gfx_tail;
extern volatile gfx_command_t gfx_queue[GFX_QUEUE_SIZE];
/* Evento de espera: produtor arma antes de tentar; NMI libera ao consumir. */
extern volatile unsigned char gfx_waiting;

/* Escrita imediata: usar com renderizacao e NMI desligadas. */
void gfx_set_tile(unsigned char x,
                  unsigned char y,
                  unsigned char tile);

/* Nao bloqueia: retorna 1 se aceito; 0 se cheia ou fora da tela.
 * Apenas tarefas cooperativas; nao chamar de IRQ/NMI nem ceder no produtor.
 */
unsigned char gfx_enqueue_tile(unsigned char x,
                             unsigned char y,
                             unsigned char tile);

/* Limpa a nametable 0 e atributos; requer renderizacao/NMI desligadas. */
void gfx_clear(void);

#endif
