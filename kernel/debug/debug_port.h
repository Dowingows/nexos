#ifndef NEXOS_DEBUG_PORT_H
#define NEXOS_DEBUG_PORT_H

/* Internal driver used only by the system-call dispatcher. */
void __fastcall__ debug_port_putchar(unsigned char character);

#endif
