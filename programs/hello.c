#include "nexos.h"

void program_entry(const char *arguments)
{
    (void)arguments;
    nexos_write("Hello from a C program in NexOS!\n");
    nexos_yield();
}
