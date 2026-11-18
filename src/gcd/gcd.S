# Shift away the trailing zeros to get the odd part of each number.
# Subtracting two odd numbers gives an even number we can shift again.
    .text
    .globl gcd_u32_asm
    .type gcd_u32_asm,@function

# Skip zero bytes first, then look up the trailing zeros in the next byte.
    .macro strip value, count
    li \count, 0
1:
    andi t0, \value, 255
    bnez t0, 2f
    srli \value, \value, 8
    addi \count, \count, 8
    j 1b
2:
    add t0, a4, t0
    lbu t0, 0(t0)
    srl \value, \value, t0
    add \count, \count, t0
    .endm

# a0 and a1 are the inputs. a2 counts shared shifts. Return the GCD in a0.
gcd_u32_asm:
    beqz a0, .Lright
    beqz a1, .Lreturn
    beq a0, a1, .Lreturn

    la a4, .Lctz
    strip a0, a2
    strip a1, a3
    bleu a2, a3, .Lcompare
    mv a2, a3

.Lcompare:
    beq a0, a1, .Ldone
    bltu a1, a0, .Lordered
    mv t0, a0
    mv a0, a1
    mv a1, t0

.Lordered:
    sub a0, a0, a1
.Lstrip_diff:
    andi t0, a0, 255
    bnez t0, .Lshift
    srli a0, a0, 8
    j .Lstrip_diff
.Lshift:
    add t0, a4, t0
    lbu t0, 0(t0)
    srl a0, a0, t0
    j .Lcompare

.Lone:
    li a0, 1
.Ldone:
    sll a0, a0, a2
.Lreturn:
    ret
.Lright:
    mv a0, a1
    ret
    .size gcd_u32_asm,.-gcd_u32_asm

    .section .rodata

# Each entry gives the position of the lowest set bit in a nonzero byte.
.Lctz:
    .byte 0, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 7, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte 4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
