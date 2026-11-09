#ifndef NEXOS_PROGRAM_API_H
#define NEXOS_PROGRAM_API_H

typedef unsigned char (*nexos_write_service)(const char *text);
typedef unsigned char (*nexos_yield_service)(void);
typedef unsigned char (*nexos_cat_service)(const char *path);
typedef unsigned char (*nexos_ls_service)(void);

/* Chamadas fixas na ROM: saída, yield cooperativo e leitura de arquivo. */
#define nexos_write \
    (*(nexos_write_service)0xFF00)
#define nexos_yield \
    (*(nexos_yield_service)0xFF03)
#define nexos_cat \
    (*(nexos_cat_service)0xFF06)
#define nexos_ls \
    (*(nexos_ls_service)0xFF09)

#endif
