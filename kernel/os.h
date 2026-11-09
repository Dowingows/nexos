#ifndef NEXOS_OS_H
#define NEXOS_OS_H

/* Chamar de um processo, com video habilitado.
 * Espera cooperativamente por espaco; retorna 1 ao enfileirar ou 0 se invalido.
 * Nao espera o tile ser efetivamente exibido.
 */
unsigned char os_draw_tile(unsigned char x,
                           unsigned char y,
                           unsigned char tile);

/* Chamadas de sistema: imprimir texto e limpar o terminal do shell.
 * Apenas dentro de processos, com video inicializado e habilitado.
 */
unsigned char os_write(const char *text);
unsigned char os_clear(void);
unsigned char os_fs_cat(const char *name);
unsigned char os_fs_list(void);
unsigned char os_fs_run(const char *path, const char *arguments);

#endif
