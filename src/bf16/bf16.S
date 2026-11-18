    .text
    .globl bf16_from_f32_asm
    .type bf16_from_f32_asm,@function
# a0 holds the float32 bits on entry and the BF16 bits on return.
bf16_from_f32_asm:
    srli t0, a0, 16
    slli t1, a0, 16
    bgez t1, .Ltop            # Keep the top bits when the discarded part is less than halfway.

    slli t2, a0, 1
    lui t3, 0xff000
    bgeu t2, t3, .Ltop        # Keep the top 16 bits for NaN and infinity.

    slli t1, t1, 1
    snez t1, t1               # Any remaining 1 bit puts the value above the halfway point.
    or t1, t1, t0
    andi t1, t1, 1
    add a0, t0, t1
    ret
.Ltop:
    mv a0, t0
    ret
    .size bf16_from_f32_asm,.-bf16_from_f32_asm

    .globl bf16_mul_asm
    .type bf16_mul_asm,@function
# a2 and a3 hold the magnitudes of a0 and a1. a4 holds the product sign.
bf16_mul_asm:
    li t0, 0x7fff
    and a2, a0, t0
    and a3, a1, t0
    xor a4, a0, a1
    li t0, 0x8000
    and a4, a4, t0

    li a5, 0x7f80
    bgeu a2, a5, .Lspecial_a
    bgeu a3, a5, .Lspecial_b
    beqz a2, .Lsigned_zero
    beqz a3, .Lsigned_zero

    srli t0, a2, 7
    srli t1, a3, 7
    andi a2, a2, 127
    andi a3, a3, 127
    beqz t0, .Ldenorm_a
    ori a2, a2, 128
.Lfirst_ready:
    beqz t1, .Ldenorm_b
    ori a3, a3, 128
.Lsecond_ready:
    add t0, t0, t1
    addi t0, t0, -127

    # Start with the first significand since the leading multiplier bit is 1.
    # Read the other seven bits from high to low. Shift each time and add for a 1.
    mv t2, a2
    slli a3, a3, 25
    .rept 7
    slli t2, t2, 1
    bgez a3, 1f
    add t2, t2, a2
1:
    slli a3, a3, 1
    .endr

    srli t1, t2, 15
    add t0, t0, t1
    srli t2, t2, 7
    srl t2, t2, t1
    blez t0, .Lunderflow
    li t1, 255
    bge t0, t1, .Linfinity
    slli t0, t0, 7
    andi t2, t2, 127
    or t0, t0, t2
    or a0, a4, t0
    ret

.Ldenorm_a:
    li t0, 1
2:
    slli a2, a2, 1
    addi t0, t0, -1
    sltiu t2, a2, 128
    bnez t2, 2b
    j .Lfirst_ready

.Ldenorm_b:
    li t1, 1
3:
    slli a3, a3, 1
    addi t1, t1, -1
    sltiu t2, a3, 128
    bnez t2, 3b
    j .Lsecond_ready

.Lunderflow:
    li t1, -6
    blt t0, t1, .Lsigned_zero
    li t1, 1
    sub t1, t1, t0
    andi t2, t2, 127
    srl t2, t2, t1
    or a0, t2, a4
    ret

.Lspecial_a:
    bne a2, a5, .Lmul_done
    beqz a3, .Linvalid
    j .Linfinity
.Lspecial_b:
    bne a3, a5, .Lnan_b
    beqz a2, .Linvalid
.Linfinity:
    or a0, a4, a5
    ret
.Lnan_b:
    mv a0, a1
.Lmul_done:
    ret
.Linvalid:
    li a0, 0x7fc0
    ret
.Lsigned_zero:
    mv a0, a4
    ret
    .size bf16_mul_asm,.-bf16_mul_asm

    .globl bf16_sqrt_asm
    .type bf16_sqrt_asm,@function
# a0 holds the BF16 input and then its square root. t0 and t1 help build the result.
bf16_sqrt_asm:
    li t0, 0x7f80
    bgeu a0, t0, .Lsqrt_special
    sltiu t0, a0, 128
    bnez t0, .Lsqrt_zero

    # Look up the seven fraction bits for a positive normal input.
    andi t0, a0, 255
    la t1, .Lroots
    add t1, t1, t0
    lbu t1, 0(t1)
    srli a0, a0, 7
    addi a0, a0, 127
    srli a0, a0, 1
    slli a0, a0, 7
    or a0, a0, t1
    ret

.Lsqrt_special:
    li t0, 0x8000
    bltu a0, t0, .Lsqrt_keep
    beq a0, t0, .Lsqrt_zero
    li t0, 0xff80
    bgtu a0, t0, .Lsqrt_keep
    li a0, 0x7fc0
.Lsqrt_keep:
    ret
.Lsqrt_zero:
    li a0, 0
    ret
    .size bf16_sqrt_asm,.-bf16_sqrt_asm

    .section .rodata
# Index the table with the low exponent bit and the seven fraction bits.
# Each entry is floor(sqrt(128 * (m + 1) - 1)) - 128.
.Lroots:
    .byte 53, 54, 54, 55, 56, 56, 57, 58, 58, 59, 60, 60, 61, 62, 62, 63
    .byte 64, 64, 65, 66, 66, 67, 68, 68, 69, 70, 70, 71, 72, 72, 73, 74
    .byte 74, 75, 75, 76, 77, 77, 78, 79, 79, 80, 80, 81, 82, 82, 83, 83
    .byte 84, 85, 85, 86, 86, 87, 88, 88, 89, 89, 90, 91, 91, 92, 92, 93
    .byte 93, 94, 95, 95, 96, 96, 97, 97, 98, 99, 99, 100, 100, 101, 101, 102
    .byte 103, 103, 104, 104, 105, 105, 106, 106, 107, 107, 108, 109, 109, 110, 110, 111
    .byte 111, 112, 112, 113, 113, 114, 114, 115, 115, 116, 117, 117, 118, 118, 119, 119
    .byte 120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 127, 127
    .byte 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7
    .byte 8, 8, 9, 9, 10, 10, 11, 11, 11, 12, 12, 13, 13, 14, 14, 15
    .byte 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 19, 20, 20, 21, 21, 22
    .byte 22, 22, 23, 23, 24, 24, 25, 25, 25, 26, 26, 27, 27, 27, 28, 28
    .byte 29, 29, 29, 30, 30, 31, 31, 31, 32, 32, 33, 33, 33, 34, 34, 35
    .byte 35, 35, 36, 36, 37, 37, 37, 38, 38, 39, 39, 39, 40, 40, 40, 41
    .byte 41, 42, 42, 42, 43, 43, 43, 44, 44, 45, 45, 45, 46, 46, 46, 47
    .byte 47, 47, 48, 48, 49, 49, 49, 50, 50, 50, 51, 51, 51, 52, 52, 53
