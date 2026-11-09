#include "fs.h"
#include "proc/process.h"
#include "terminal/terminal.h"

#define TAR_BLOCK_SIZE 512
#define TAR_NAME_SIZE 100
#define TAR_SIZE_OFFSET 124
#define TAR_SIZE_LENGTH 12

extern const unsigned char filesystem_start[];
extern const unsigned char filesystem_end[];

#define NEX_EXEC_LOAD_ADDR 0x0540
#define NEX_EXEC_MAX_SIZE 192
#define NEX_EXEC_ARGS_ADDR 0x0500
#define NEX_EXEC_ARGS_SIZE 32

static unsigned char user_program_active;

static unsigned char same_name(const char *left, const unsigned char *right)
{
    unsigned char i;

    for (i = 0; i < TAR_NAME_SIZE; ++i) {
        if ((left[i] == ' ' || left[i] == '\0') && right[i] == '\0') {
            return 1;
        }
        if (left[i] != (char)right[i]) return 0;
    }
    return left[TAR_NAME_SIZE] == '\0';
}

static unsigned int tar_size(const unsigned char *header)
{
    unsigned char i;
    unsigned int size = 0;

    for (i = 0; i < TAR_SIZE_LENGTH; ++i) {
        unsigned char digit = header[TAR_SIZE_OFFSET + i];
        if (digit == '\0' || digit == ' ') break;
        if (digit < '0' || digit > '7') return 0;
        size = (unsigned int)(size * 8 + digit - '0');
    }
    return size;
}

unsigned char fs_cat_kernel(const char *name)
{
    const unsigned char *header = filesystem_start;
    const unsigned char *data;
    unsigned int size;
    unsigned int remaining;
    unsigned char chunk[16];
    unsigned char used;

    if (name == 0 || *name == '\0') return 0;

    while (header + TAR_BLOCK_SIZE <= filesystem_end) {
        if (header[0] == 0) break;

        size = tar_size(header);
        data = header + TAR_BLOCK_SIZE;
        if (data + size > filesystem_end) return 0;

        if (same_name(name, header) &&
            (header[156] == '0' || header[156] == '\0')) {
            remaining = size;
            while (remaining != 0) {
                used = 0;
                while (used < sizeof(chunk) - 1 && remaining != 0) {
                    chunk[used++] = *data++;
                    --remaining;
                }
                chunk[used] = '\0';
                terminal_write((const char *)chunk);
            }
            terminal_write("\n");
            return 1;
        }

        size = (unsigned int)((size + TAR_BLOCK_SIZE - 1) & 0xfe00);
        header = data + size;
    }

    return 0;
}

unsigned char fs_list_kernel(void)
{
    const unsigned char *header = filesystem_start;
    const unsigned char *data;
    unsigned int size;
    unsigned char i;
    unsigned char found = 0;

    while (header + TAR_BLOCK_SIZE <= filesystem_end) {
        if (header[0] == 0) break;

        size = tar_size(header);
        data = header + TAR_BLOCK_SIZE;
        if (data + size > filesystem_end) return 0;

        if (header[156] == '0' || header[156] == '\0') {
            for (i = 0; i < TAR_NAME_SIZE && header[i] != '\0'; ++i) {
                terminal_putc(header[i]);
            }
            terminal_putc('\n');
            found = 1;
        }

        size = (unsigned int)((size + TAR_BLOCK_SIZE - 1) & 0xfe00);
        header = data + size;
    }

    return found;
}

/* NEX1 signature and file/BSS sizes; the program loads at $0540. */
unsigned char fs_run_kernel(const struct fs_exec_request *request)
{
    const unsigned char *header = filesystem_start;
    const unsigned char *data;
    struct process *process;
    unsigned int size;
    unsigned int program_size;
    unsigned int bss_size;
    unsigned int i;
    static const unsigned char signature[] = "NEX1";
    const char *path;
    const char *arguments;

    if (request == 0) return 0;
    path = request->path;
    arguments = request->arguments;
    if (path == 0 || *path == '\0') return 0;
    if (user_program_active) return 0;

    while (header + TAR_BLOCK_SIZE <= filesystem_end) {
        if (header[0] == 0) break;

        size = tar_size(header);
        data = header + TAR_BLOCK_SIZE;
        if (data + size > filesystem_end) return 0;

        if (same_name(path, header) &&
            (header[156] == '0' || header[156] == '\0')) {
            if (size < 8) return 0;
            for (i = 0; i < sizeof(signature) - 1; ++i) {
                if (data[i] != signature[i]) return 0;
            }

            program_size = (unsigned int)data[4] |
                           ((unsigned int)data[5] << 8);
            bss_size = (unsigned int)data[6] |
                       ((unsigned int)data[7] << 8);
            if (program_size == 0 || program_size > NEX_EXEC_MAX_SIZE ||
                bss_size > NEX_EXEC_MAX_SIZE - program_size ||
                size != program_size + 8) return 0;

            {
                unsigned char *destination =
                    (unsigned char *)NEX_EXEC_LOAD_ADDR;
                for (i = 0; i < program_size; ++i) {
                    destination[i] = data[i + 8];
                }
                for (i = 0; i < bss_size; ++i) {
                    destination[program_size + i] = 0;
                }
            }

            {
                unsigned char *argument_buffer =
                    (unsigned char *)NEX_EXEC_ARGS_ADDR;
                for (i = 0; i < NEX_EXEC_ARGS_SIZE - 1; ++i) {
                    if (arguments == 0 || arguments[i] == '\0') break;
                    argument_buffer[i] = (unsigned char)arguments[i];
                }
                argument_buffer[i] = '\0';
            }

            process = create_user_process(
                NEX_EXEC_LOAD_ADDR, (const char *)NEX_EXEC_ARGS_ADDR);
            if (process == 0) return 0;
            user_program_active = 1;
            return 1;
        }

        size = (unsigned int)((size + TAR_BLOCK_SIZE - 1) & 0xfe00);
        header = data + size;
    }

    return 0;
}

void fs_program_finished(void)
{
    user_program_active = 0;
}
