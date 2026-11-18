    .text
    .globl op1_asm
    .type op1_asm,@function
# a0 holds the sum so far and a1 holds the carry. Store the round count from t0 at (a2).
op1_asm:
    li t0, 0
    beqz a1, .Lsum_done

    # Check the carry after each addition so the count is right even if only one round is needed.
.Lcarry:
    and t1, a0, a1
    xor a0, a0, a1
    slli a1, t1, 1
    beqz a1, .Lodd

    and t1, a0, a1
    xor a0, a0, a1
    slli a1, t1, 1
    addi t0, t0, 2
    bnez a1, .Lcarry
    sw t0, 0(a2)
    ret

.Lodd:
    addi t0, t0, 1
.Lsum_done:
    sw t0, 0(a2)
    ret
    .size op1_asm,.-op1_asm

    .globl op2_asm
    .type op2_asm,@function
# Subtract a1 from a0 and return the difference in a0.
op2_asm:
    sub a0, a0, a1
    ret
    .size op2_asm,.-op2_asm

    .globl op3_asm
    .type op3_asm,@function
# Keep the differing bits in t0 to work out the average of a0 and a1.
op3_asm:
    xor t0, a0, a1
    and a0, a0, a1
    srli t0, t0, 1
    add a0, a0, t0
    ret
    .size op3_asm,.-op3_asm

    # Booth multiplication turns a run of 1s into a difference of two powers of two.
    # Sign extension takes care of the top bit, so there is no extra term at bit 32.
    .globl q_mul_asm
    .type q_mul_asm,@function
# Multiply a0 by a1. Accumulate the high half in a3 and the low half in a2.
q_mul_asm:
    slli t0, a1, 1
    xor t0, t0, a1            # A 1 marks a change between adjacent multiplier bits.
    li a2, 0x80000            # Add half a unit now so the final shift rounds the product.
    li a3, 0
    la a4, .Lctz8
    li a5, 0                  # Bit position where this byte starts

.Lbyte:
    andi t1, t0, 255
    beqz t1, .Ladvance

.Lterm:
    add t2, a4, t1
    lbu t2, 0(t2)
    add t3, a5, t2
    sll t4, a0, t3            # Low 32 bits of the shifted multiplicand
    neg t5, t3
    sra t5, a0, t5
    bnez t3, .Lsign
    srai t5, a0, 31           # For a zero shift, fill the high half with the sign bit.

.Lsign:
    srl t6, a1, t2
    andi t6, t6, 1
    beqz t6, .Lplus
    sltu t6, a2, t4
    sub a2, a2, t4
    sub a3, a3, t5
    sub a3, a3, t6
    j .Lclear

.Lplus:
    add a2, a2, t4
    sltu t6, a2, t4
    add a3, a3, t5
    add a3, a3, t6
.Lclear:
    addi t2, t1, -1
    and t1, t1, t2
    bnez t1, .Lterm

.Ladvance:
    srli t0, t0, 8
    srli a1, a1, 8
    addi a5, a5, 8
    bnez t0, .Lbyte

    # Bits 20 through 51 give the Q11.20 result.
    srli a0, a2, 20
    slli a3, a3, 12
    or a0, a0, a3
    ret
    .size q_mul_asm,.-q_mul_asm

    .section .rodata
# For each nonzero byte, look up the position of its lowest set bit.
.Lctz8:
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
