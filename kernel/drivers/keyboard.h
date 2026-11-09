#ifndef NEXOS_KEYBOARD_H
#define NEXOS_KEYBOARD_H

extern volatile unsigned char keyboard_waiting;

/* Inicializa o teclado Family BASIC e fila de caracteres. */
void keyboard_init(void);

/* Processo cooperativo: varre o teclado e cede a CPU a cada leitura. */
void keyboard_process(void);

/* Retira uma tecla da fila; retorna zero imediatamente se estiver vazia. */
char keyboard_read_char(void);

#endif
