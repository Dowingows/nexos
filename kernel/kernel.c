
#include "proc/process.h"
#include "drivers/video.h"
#include "drivers/keyboard.h"
#include "os.h"
#include "shell/shell.h"
#include "terminal/terminal.h"
#include "fs.h"

/* Defined in switch.asm. */
extern nes_uint8_t current_task;

/* Assembly task initialization. */
void start_tasks(void);

/* ==========================================
 * PROCESS ENTRY
 * ========================================== */

void process_entry(void)
{
    struct process *proc;

    proc = &procs[current_task];

    if (proc->flags & PROC_FLAG_USER) {
        ((void (*)(const char *))proc->pc)(proc->arguments);
    } else {
        ((void (*)(void))proc->pc)();
    }

    proc->state = PROC_UNUSED;
    proc->wait_flag = 0;
    if (proc->flags & PROC_FLAG_USER) {
        proc->flags = 0;
        fs_program_finished();
    }

    for (;;) {
        yield();
    }
}

/* ==========================================
 * KERNEL
 * ========================================== */

static void application(void)
{
    shell_init();
    for (;;) {
        shell_poll_input();
        yield();
    }
}

void kernel_main(void)
{
    process_init();
    video_init();
    terminal_init();
    keyboard_init();
    video_enable();

    create_process((nes_uint16_t)application);
    create_process((nes_uint16_t)keyboard_process);

    start_tasks();

    for (;;) {}
}
