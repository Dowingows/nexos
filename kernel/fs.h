#ifndef NEXOS_FS_H
#define NEXOS_FS_H

struct fs_exec_request {
    const char *path;
    const char *arguments;
};

/* Implementacao interna chamada pelo despachante de syscalls. */
unsigned char fs_cat_kernel(const char *name);
unsigned char fs_list_kernel(void);
unsigned char fs_run_kernel(const struct fs_exec_request *request);
void fs_program_finished(void);

#endif
