#include "common.h"
#include "os.h"
#include "syscall.h"
#include <stdarg.h>

void __fastcall__ debug_putchar(unsigned char character)
{
    system_call(SYS_DEBUG_PUTCHAR, (const char *)&character);
}

void debug_puts(const char *text)
{
    while (*text) {
        debug_putchar((unsigned char)*text++);
    }
}

void putchar(unsigned char character)
{
    char text[2];

    text[0] = character;
    text[1] = '\0';
    os_write(text);
}

static void debug_emit(unsigned char character)
{
    debug_putchar(character);
}

/* Um unico formatador; a saida e escolhida pelo chamador. */
static void print_format(const char *fmt, va_list vargs,
                         void (*emit)(unsigned char))
{
    char spec;

    while (*fmt)
    {
        if (*fmt != '%')
        {
            emit(*fmt);
            fmt++;
            continue;
        }

        fmt++;
        spec = *fmt;

        switch (spec)
        {
            case '\0':
                emit('%');
                goto end;

            case '%':
                emit('%');
                break;

            case 's':
            {
                const char *s;

                s = va_arg(vargs, const char *);

                if (s == 0)
                    s = "(null)";

                while (*s)
                {
                    emit(*s);
                    s++;
                }

                break;
            }

            case 'd':
            {
                int value;
                unsigned int magnitude;
                unsigned int divisor;

                value = va_arg(vargs, int);
                magnitude = (unsigned int)value;

                if (value < 0)
                {
                    emit('-');
                    magnitude = 0u - magnitude;
                }

                divisor = 1;

                while (magnitude / divisor > 9)
                {
                    divisor *= 10;
                }

                while (divisor > 0)
                {
                    emit((char)('0' + magnitude / divisor));
                    magnitude %= divisor;
                    divisor /= 10;
                }

                break;
            }

            case 'x':
            {
                unsigned int value;
                int i;
                unsigned char nibble;

                value = va_arg(vargs, unsigned int);

                /* 16 bits = 4 digitos hexadecimais */
                for (i = 3; i >= 0; i--)
                {
                    nibble = (unsigned char)
                        ((value >> (i * 4)) & 0x0F);

                    emit("0123456789abcdef"[nibble]);
                }

                break;
            }

            case 'u':
            {
                unsigned int value;
                unsigned int divisor;

                value = va_arg(vargs, unsigned int);
                divisor = 1;

                while (value / divisor > 9)
                    divisor *= 10;

                while (divisor > 0)
                {
                    emit((char)('0' + value / divisor));
                    value %= divisor;
                    divisor /= 10;
                }

                break;
            }

            default:
                emit('%');
                emit(spec);
                break;
        }

        fmt++;
    }

end:
    return;
}

void printf(const char *fmt, ...)
{
    va_list vargs;
    va_start(vargs, fmt);
    print_format(fmt, vargs, putchar);
    va_end(vargs);
}

void debug_printf(const char *fmt, ...)
{
    va_list vargs;
    va_start(vargs, fmt);
    print_format(fmt, vargs, debug_emit);
    va_end(vargs);
}

void panic(const char *file, unsigned int line, const char *message)
{
    debug_printf("PANIC: %s:%u: %s\n", file, line, message);

    for (;;) {
    }
}
