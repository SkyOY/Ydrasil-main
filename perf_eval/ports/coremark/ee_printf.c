#include "coremark.h"
#include <stdarg.h>

#define UART_ADDR ((volatile ee_u32 *)0x80200080u)

static void putch(char c) {
    *UART_ADDR = (ee_u32)(ee_u8)c;
}

static void puts_local(const char *s) {
    while (*s) {
        putch(*s++);
    }
}

static void put_unsigned(unsigned long value, unsigned base, int width, int zero_pad) {
    char buf[32];
    int pos = 0;
    if (value == 0) {
        buf[pos++] = '0';
    } else {
        while (value != 0 && pos < (int)sizeof(buf)) {
            unsigned digit = value % base;
            buf[pos++] = (char)(digit < 10 ? '0' + digit : 'a' + digit - 10);
            value /= base;
        }
    }
    while (pos < width) {
        putch(zero_pad ? '0' : ' ');
        width--;
    }
    while (pos > 0) {
        putch(buf[--pos]);
    }
}

static void put_signed(long value, int width, int zero_pad) {
    if (value < 0) {
        putch('-');
        put_unsigned((unsigned long)(-value), 10, width, zero_pad);
    } else {
        put_unsigned((unsigned long)value, 10, width, zero_pad);
    }
}

int ee_printf(const char *fmt, ...) {
    va_list ap;
    int count = 0;
    va_start(ap, fmt);

    while (*fmt) {
        if (*fmt != '%') {
            putch(*fmt++);
            count++;
            continue;
        }

        fmt++;
        int zero_pad = 0;
        int width = 0;
        int long_arg = 0;

        if (*fmt == '0') {
            zero_pad = 1;
            fmt++;
        }
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }
        if (*fmt == 'l') {
            long_arg = 1;
            fmt++;
        }

        switch (*fmt) {
        case 'd':
            put_signed(long_arg ? va_arg(ap, long) : va_arg(ap, int), width, zero_pad);
            break;
        case 'u':
            put_unsigned(long_arg ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int), 10, width, zero_pad);
            break;
        case 'x':
            put_unsigned(long_arg ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int), 16, width, zero_pad);
            break;
        case 's':
            puts_local(va_arg(ap, const char *));
            break;
        case 'c':
            putch((char)va_arg(ap, int));
            break;
        case '%':
            putch('%');
            break;
        default:
            putch('%');
            putch(*fmt);
            break;
        }
        if (*fmt) {
            fmt++;
        }
    }

    va_end(ap);
    return count;
}
