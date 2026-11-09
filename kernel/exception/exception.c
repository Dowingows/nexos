#include "exception.h"

#include "../common.h"

/*
 * Variáveis globais armazenadas na BSS.
 *
 * O linker reserva espaço para elas na RAM.
 * O handler Assembly escreve diretamente nesses símbolos.
 */
unsigned char exception_a;
unsigned char exception_x;
unsigned char exception_y;
unsigned char exception_status;
unsigned int exception_pc;

/*
 * Chamado pelo handler Assembly após capturar
 * o estado da CPU.
 *
 * Esta primeira versão trata exceções fatais:
 * imprime o diagnóstico e interrompe o kernel.
 */
void exception_handler(void)
{
    debug_printf("\n=== NexOS EXCEPTION ===\n");

    debug_printf("A:      %x\n", (unsigned int)exception_a);
    debug_printf("X:      %x\n", (unsigned int)exception_x);
    debug_printf("Y:      %x\n", (unsigned int)exception_y);
    debug_printf("STATUS: %x\n", (unsigned int)exception_status);
    debug_printf("PC:     %x\n", exception_pc);

    debug_printf("Kernel halted.\n");

    for (;;) {
        /* Exceção fatal: não retorna */
    }
}
