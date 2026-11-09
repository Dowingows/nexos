#ifndef NEXOS_COMMON_H
#define NEXOS_COMMON_H

#include "debug/debug.h"

typedef unsigned char nes_uint8_t;
typedef unsigned int nes_uint16_t;
typedef nes_uint16_t nes_size_t;

#define PANIC(message) panic(__FILE__, __LINE__, message)

/* Saida principal: requer processo ativo e video habilitado. */
void printf(const char *fmt, ...);
void panic(const char *file, unsigned int line, const char *message);

#endif
