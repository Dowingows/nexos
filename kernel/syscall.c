#include "syscall.h"
#include "debug/debug_port.h"
#include "fs.h"
#include "proc/process.h"
#include "terminal/terminal.h"

unsigned char system_call(unsigned char number, const char *argument)
{
    switch (number) {
        case SYS_WRITE:
            if (argument == 0) return 0;
            terminal_write(argument);
            return 1;
        case SYS_CLEAR:
            terminal_clear();
            return 1;
        case SYS_DEBUG_PUTCHAR:
            if (argument == 0) return 0;
            debug_port_putchar((unsigned char)*argument);
            return 1;
        case SYS_FS_CAT:
            return fs_cat_kernel(argument);
        case SYS_FS_LIST:
            return fs_list_kernel();
        case SYS_FS_RUN:
            return fs_run_kernel((const struct fs_exec_request *)argument);
        case SYS_YIELD:
            yield();
            return 1;
        default:
            return 0;
    }
}
