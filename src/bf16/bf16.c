#include "bf16.h"

uint16_t bf16_from_f32(uint32_t bits)
{
    uint32_t top = bits >> 16;

    /* For infinity and NaN, keep the top 16 bits. */
    if ((top & 0x7f80u) == 0x7f80u)
        return (uint16_t) top;

    /* On a tie, pick the value with an even low bit. */
    return (uint16_t) ((bits + 0x7fffu + (top & 1u)) >> 16);
}

static unsigned normalize_mantissa(unsigned fraction, int *exp)
{
    if (*exp)
        return fraction + 128;

    /* Shift the leading 1 into bit 7. Each shift lowers the exponent by one. */
    *exp = 1;
    while (fraction < 128) {
        fraction <<= 1;
        --*exp;
    }

    return fraction;
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    unsigned x = a & 0x7fffu;
    unsigned y = b & 0x7fffu;
    unsigned sign = (a ^ b) & 0x8000u;

    /* Check a first: infinity times NaN gives infinity in this assignment. */
    if (x >= 0x7f80u) {
        if (x > 0x7f80u)
            return a;
        return y ? (uint16_t) (sign | x) : 0x7fc0u;
    }

    if (y >= 0x7f80u) {
        if (y > 0x7f80u)
            return b;
        return x ? (uint16_t) (sign | y) : 0x7fc0u;
    }

    if (!x || !y)
        return (uint16_t) sign;

    int ex = (int) (x >> 7);
    int ey = (int) (y >> 7);
    unsigned ma = normalize_mantissa(x & 127, &ex);
    unsigned mb = normalize_mantissa(y & 127, &ey);

    /* If bit 15 of the product is set, shift once more and raise the exponent. */
    unsigned product = ma * mb;
    unsigned carry = product >> 15;
    int exp = ex + ey - 127 + (int) carry;
    unsigned mant = product >> (7 + carry);

    if (exp >= 255)
        return (uint16_t) (sign | 0x7f80u);
    if (exp <= 0)
        return (uint16_t) (sign | (exp < -6 ? 0u : (mant & 127u) >> (1 - exp)));

    return (uint16_t) (sign | ((unsigned) exp << 7) | (mant & 127));
}

uint16_t bf16_sqrt(uint16_t a)
{
    unsigned mag = a & 0x7fffu;

    if (mag > 0x7f80u || a == 0x7f80u)
        return a;
    if (mag && (a & 0x8000u))
        return 0x7fc0u;
    if (mag < 128)
        return 0;

    unsigned exp = a >> 7;
    unsigned mant = (128u + (a & 127u)) << ((exp ^ 1u) & 1u);
    unsigned rem = ((mant + 1u) << 7) - 1;

    /* Use two input bits at a time to find the next bit of the square root. */
    unsigned root = 0;
    for (unsigned bit = 1u << 14; bit; bit >>= 2) {
        unsigned trial = root + bit;
        root >>= 1;
        if (rem >= trial) {
            rem -= trial;
            root += bit;
        }
    }

    return (uint16_t) ((((exp + 127u) >> 1) << 7) | (root - 128u));
}
