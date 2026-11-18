#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    /* XOR adds without carries. Shift the carries left for the next round. */
    while (b) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        ++passes;
    }

    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    /* Count shared bits in full and halve the differing bits to avoid overflow. */
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    /* Split each input into two 16-bit halves so the products fit in 32 bits. */
    uint32_t x = (uint32_t) a;
    uint32_t y = (uint32_t) b;
    uint32_t xl = x & 0xffffu;
    uint32_t xh = x >> 16;
    uint32_t yl = y & 0xffffu;
    uint32_t yh = y >> 16;

    /* Combine the four partial products and their carries into two 32-bit halves. */
    uint32_t bottom = xl * yl;
    uint32_t middle = xh * yl + (bottom >> 16);
    uint32_t cross = xl * yh + (middle & 0xffffu);
    uint32_t low = (cross << 16) | (bottom & 0xffffu);
    uint32_t high = xh * yh + (middle >> 16) + (cross >> 16);

    /* The products above are unsigned. For each negative input, subtract the other input from the high half. */
    if (a < 0)
        high -= y;
    if (b < 0)
        high -= x;

    /* Keep bits 20 through 51. Round up if bit 19 is set, even for a negative result. */
    uint32_t truncated = (high << (32 - Q)) | (low >> Q);
    return (int32_t) (truncated + ((low >> (Q - 1)) & 1u));
}
