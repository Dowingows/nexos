#ifndef NEXOS_EXCEPTION_H
#define NEXOS_EXCEPTION_H

/* Estado da CPU capturado durante a exceção */
extern unsigned char exception_a;
extern unsigned char exception_x;
extern unsigned char exception_y;
extern unsigned char exception_status;
extern unsigned int exception_pc;

/* Dispara uma exceção usando a instrução BRK */
void trigger_exception(void);

/* Trata a exceção capturada pelo Assembly */
void exception_handler(void);

#endif