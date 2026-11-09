#include "terminal.h"
#include "../os.h"

/* Apenas o shell e dono do cursor nesta primeira versao. Sem framebuffer RAM. */
static unsigned char column;
static unsigned char row;

void terminal_init(void)
{
    column = 0;
    row = 0;
}

void terminal_clear(void)
{
    unsigned char x;
    unsigned char y;

    for (y = 0; y < TERMINAL_ROWS; y++) {
        for (x = 0; x < TERMINAL_COLUMNS; x++) {
            os_draw_tile(x, y, ' ');
        }
    }
    terminal_init();
}

void terminal_putc(unsigned char character)
{
    unsigned char tile;

    if (character == '\r') {
        column = 0;
        return;
    }
    if (character == '\b') {
        if (column != 0) {
            column--;
        } else if (row != 0) {
            row--;
            column = TERMINAL_COLUMNS - 1;
        } else {
            return;
        }
        os_draw_tile(column, row, ' ');
        return;
    }
    if (character == '\n') {
        column = 0;
        row++;
    } else {
        tile = character;
        if (character == 0xD7) {
            tile = 127; /* Multiplicacao do titulo; extensao ao ASCII. */
        } else if (character < 32 || character > 126) {
            tile = '?';
        }
        os_draw_tile(column, row, tile);
        column++;
        if (column == TERMINAL_COLUMNS) {
            column = 0;
            row++;
        }
    }
    if (row == TERMINAL_ROWS) {
        /* Primeira versao: uma pagina nova, sem framebuffer para scroll. */
        terminal_clear();
    }
}

void terminal_write(const char *text)
{
    while (*text) {
        terminal_putc((unsigned char)*text++);
    }
}
