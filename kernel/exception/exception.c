#include "exception.h"

#include "../common.h"

/*
 * Global variables stored in BSS.
 *
 * The linker reserves RAM space for them.
 * The Assembly handler writes directly to these symbols.
 */
unsigned char exception_a;
unsigned char exception_x;
unsigned char exception_y;
unsigned char exception_status;
unsigned int exception_pc;

/*
 * Called by the Assembly handler after capturing
 * the CPU state.
 *
 * This first version handles fatal exceptions:
 * it prints diagnostics and halts the kernel.
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
        /* Fatal exception: this function does not return. */
    }
}
