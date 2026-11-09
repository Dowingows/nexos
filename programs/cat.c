#include "nexos.h"

void program_entry(const char *arguments)
{
    if (!nexos_cat(arguments)) {
        nexos_write("cat: file not found\n");
    }
}
