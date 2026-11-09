#include "os.h"
#include "syscall.h"
#include "fs.h"
#include "drivers/video.h"
#include "proc/process.h"

unsigned char os_draw_tile(unsigned char x,
                           unsigned char y,
                           unsigned char tile)
{
    if (x >= 32 || y >= 30) {
        return 0;
    }

    for (;;) {
        /* Arma ANTES de testar: uma NMI entre falha e espera nao se perde. */
        gfx_waiting = 1;
        if (gfx_enqueue_tile(x, y, tile)) {
            gfx_waiting = 0;
            return 1;
        }
        process_wait(&gfx_waiting);
    }
}

unsigned char os_write(const char *text)
{
    return system_call(SYS_WRITE, text);
}

unsigned char os_clear(void)
{
    return system_call(SYS_CLEAR, 0);
}

unsigned char os_fs_cat(const char *name)
{
    return system_call(SYS_FS_CAT, name);
}

unsigned char os_fs_list(void)
{
    return system_call(SYS_FS_LIST, 0);
}

unsigned char os_fs_run(const char *path, const char *arguments)
{
    static struct fs_exec_request request;

    request.path = path;
    request.arguments = arguments;
    return system_call(SYS_FS_RUN, (const char *)&request);
}
