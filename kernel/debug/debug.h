#ifndef NEXOS_DEBUG_H
#define NEXOS_DEBUG_H

/* Diagnostico via SYS_DEBUG_PUTCHAR; nao depende da PPU nem cede a CPU. */
void __fastcall__ debug_putchar(unsigned char character);
void debug_puts(const char *text);
void debug_printf(const char *format, ...);

#endif
