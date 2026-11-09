#include <stddef.h>

extern char __HEAP_START__;
extern char __HEAP_SIZE__;

static unsigned int heap_used = 0;

void *kmalloc(unsigned int size){
    unsigned int capacity =
        (unsigned int)&__HEAP_SIZE__;

    unsigned char *base =
        (unsigned char *)&__HEAP_START__;

    void *result;

    if (size == 0)
        return NULL;

    if (heap_used > capacity)
        return NULL;

    if (size > capacity - heap_used)
        return NULL;

    result = base + heap_used;
    heap_used += size;

    return result;
}