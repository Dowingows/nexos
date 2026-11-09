#ifndef NEXOS_SHELL_H
#define NEXOS_SHELL_H

void shell_init(void);
/* Executor de comandos para o shell. */
void shell_execute(const char *command);
/* Consome no maximo uma tecla sem esperar por entrada. */
void shell_poll_input(void);

#endif
