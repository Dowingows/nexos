#include "syscall.h"

/* ABI C chamado pelo trampoline fixo disponível aos executáveis NEX1. */
unsigned char nexos_write_impl(const char *text)
{
    return system_call(SYS_WRITE, text);
}

unsigned char nexos_yield_impl(void)
{
    return system_call(SYS_YIELD, 0);
}

unsigned char nexos_cat_impl(const char *name)
{
    return system_call(SYS_FS_CAT, name);
}

unsigned char nexos_ls_impl(void)
{
    return system_call(SYS_FS_LIST, 0);
}
