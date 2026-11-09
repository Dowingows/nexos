#include "process.h"

struct process procs[PROCS_MAX];
extern nes_uint8_t process_contexts_ready;
void process_context_init(nes_uint8_t index);

void process_init(void)
{
    nes_uint8_t i;

    for (i = 0; i < PROCS_MAX; i++) {
        procs[i].pid = 0;
        procs[i].state = PROC_UNUSED;
        procs[i].flags = 0;
        procs[i].pc = 0;
        procs[i].arguments = 0;
        procs[i].wait_flag = 0;
    }
}

struct process *create_process(nes_uint16_t pc)
{
    nes_uint8_t i;
    struct process *proc;

    for (i = 0; i < PROCS_MAX; i++) {
        if (procs[i].state == PROC_UNUSED) {
            proc = &procs[i];

            proc->pid = i + 1;
            proc->state = PROC_RUNNABLE;
            proc->flags = 0;
            proc->pc = pc;
            proc->arguments = 0;

            if (process_contexts_ready) {
                process_context_init(i);
            }

            return proc;
        }
    }

    return 0;
}

struct process *create_user_process(nes_uint16_t pc, const char *arguments)
{
    struct process *proc = create_process(pc);

    if (proc != 0) {
        proc->flags = PROC_FLAG_USER;
        proc->arguments = arguments;
    }

    return proc;
}

void run_process(struct process *proc)
{
    void (*entry)(void);

    if (proc == 0 || proc->state != PROC_RUNNABLE) {
        PANIC("invalid process");
    }

    entry = (void (*)(void))proc->pc;
    entry();

    proc->state = PROC_UNUSED;
}

extern nes_uint8_t current_task;
extern nes_uint8_t next_task;

void switch_context(void);

void process_wait(volatile nes_uint8_t *flag)
{
    procs[current_task].wait_flag = flag;
    procs[current_task].state = PROC_WAITING;
    /* The scheduler rechecks the flag, so an NMI between publishing and yielding is not lost. */
    yield();
}

void yield(void)
{
    /* If all processes are waiting, the kernel rechecks events until an NMI releases one.
     * trabalho. Nenhuma aplicacao fica repetindo a operacao bloqueada.
     */
    do {
        next_task = scheduler_next(current_task);
    } while (next_task >= PROCS_MAX);

    /* Validate stacks before continuing, even when no other task is ready. */
    switch_context();
}
