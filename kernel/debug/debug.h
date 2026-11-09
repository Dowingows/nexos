#ifndef NEXOS_DEBUG_H
#define NEXOS_DEBUG_H

/* SYS_DEBUG_PUTCHAR diagnostics; independent of the PPU and does not yield. */
void __fastcall__ debug_putchar(unsigned char character);
void debug_puts(const char *text);
void debug_printf(const char *format, ...);

#endif
