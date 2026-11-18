#include "gcd.h"

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (!a || !b)
        return a | b;

    /* While both numbers are even, divide them by two and count the shifts. */
    unsigned common = 0;
    while (((a | b) & 1u) == 0) {
        a >>= 1;
        b >>= 1;
        ++common;
    }

    while ((a & 1u) == 0)
        a >>= 1;

    /* Make both numbers odd, then subtract the smaller one from the larger one. */
    do {
        while ((b & 1u) == 0)
            b >>= 1;

        if (a > b) {
            uint32_t tmp = a;
            a = b;
            b = tmp;
        }

        b -= a;
    } while (b);

    /* Put back the factors of two removed at the start. */
    return a << common;
}
