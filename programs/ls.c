#include "nexos.h"

void program_entry(const char *arguments)
{
    (void)arguments;
    if (!nexos_ls()) {
        nexos_write("ls: directory empty\n");
    }
}
