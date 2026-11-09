#ifndef NEXOS_OS_H
#define NEXOS_OS_H

/* Call from a process with video enabled.
 * Wait cooperatively for space; return 1 when queued or 0 if invalid.
 * Does not wait for the tile to be displayed.
 */
unsigned char os_draw_tile(unsigned char x,
                           unsigned char y,
                           unsigned char tile);

/* System calls for printing text and clearing the shell terminal.
 * Call only from processes, with video initialized and enabled.
 */
unsigned char os_write(const char *text);
unsigned char os_clear(void);
unsigned char os_fs_cat(const char *name);
unsigned char os_fs_list(void);
unsigned char os_fs_run(const char *path, const char *arguments);

#endif
