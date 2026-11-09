
#include "process.h"

/*
 * Return the next runnable process index by scanning the table circularly.
 * If no other process is ready, return the current process.
 * If no process is runnable, return PROCS_MAX.
 */
nes_uint8_t scheduler_next(nes_uint8_t current)
{
    nes_uint8_t step;
    nes_uint8_t index;

    for (step = 1; step <= PROCS_MAX; step++) {
        index = (current + step) % PROCS_MAX;

        if (procs[index].state == PROC_WAITING &&
            *procs[index].wait_flag == 0) {
            procs[index].wait_flag = 0;
            procs[index].state = PROC_RUNNABLE;
        }

        if (procs[index].state == PROC_RUNNABLE) {
            return index;
        }
    }

    return PROCS_MAX;
}
