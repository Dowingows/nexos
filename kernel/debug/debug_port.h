#ifndef NEXOS_DEBUG_PORT_H
#define NEXOS_DEBUG_PORT_H

/* Driver interno: usado somente pelo despachante de syscalls. */
void __fastcall__ debug_port_putchar(unsigned char character);

#endif
