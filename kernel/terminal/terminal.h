#ifndef NEXOS_TERMINAL_H
#define NEXOS_TERMINAL_H

#define TERMINAL_COLUMNS 32
#define TERMINAL_ROWS 30

void terminal_init(void);
void terminal_clear(void);
void terminal_putc(unsigned char character);
void terminal_write(const char *text);

#endif
