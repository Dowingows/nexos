
#ifndef NEXOS_PROCESS_H
#define NEXOS_PROCESS_H

#include "../common.h"

#include "config.h"
#define PROC_UNUSED 0
#define PROC_RUNNABLE 1
#define PROC_WAITING 2
#define PROC_FLAG_USER 1

struct process {
    nes_uint8_t pid;
    nes_uint8_t state;
    nes_uint8_t flags;
    nes_uint16_t pc;
    const char *arguments;
    volatile nes_uint8_t *wait_flag;
};

/* Tabela global de processos */
extern struct process procs[PROCS_MAX];

void process_init(void);
struct process *create_process(nes_uint16_t pc);
struct process *create_user_process(nes_uint16_t pc, const char *arguments);
void run_process(struct process *proc);
nes_uint8_t scheduler_next(nes_uint8_t current);
void yield(void);
/* Bloqueia ate a flag compartilhada ficar zero. Apenas dentro de processos. */
void process_wait(volatile nes_uint8_t *flag);

#endif
