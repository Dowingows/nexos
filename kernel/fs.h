#ifndef NEXOS_FS_H
#define NEXOS_FS_H

struct fs_exec_request {
    const char *path;
    const char *arguments;
};

/* Internal implementation called by the system-call dispatcher. */
unsigned char fs_cat_kernel(const char *name);
unsigned char fs_list_kernel(void);
unsigned char fs_run_kernel(const struct fs_exec_request *request);
void fs_program_finished(void);

#endif
