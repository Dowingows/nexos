#ifndef NEXOS_SHELL_H
#define NEXOS_SHELL_H

void shell_init(void);
/* Shell command executor. */
void shell_execute(const char *command);
/* Consume at most one key without waiting for input. */
void shell_poll_input(void);

#endif
