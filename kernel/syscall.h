#ifndef NEXOS_SYSCALL_H
#define NEXOS_SYSCALL_H

#define SYS_WRITE 1
#define SYS_CLEAR 2
#define SYS_DEBUG_PUTCHAR 3
#define SYS_FS_CAT 4
#define SYS_FS_LIST 5
#define SYS_FS_RUN 6
#define SYS_YIELD 7

/* Porta de entrada C didatica; nao usa BRK nem cria modo privilegiado. */
unsigned char system_call(unsigned char number, const char *argument);

#endif
