# Use the HW1 permutation and twist numbers to find a shortest 2x2x2 solution.
# Each row is eight bytes. A quarter turn needs one lookup in each table.
    .text
    .balign 4
    .globl rubik_solve_asm
    .type rubik_solve_asm,@function

# Find the permutation, then match the twist to read the low five bits. Return 31 on a miss.
# s7 points to the permutation table and s9 to the dictionary. t0 through t4 are scratch registers.
    .macro probe p, o, tag
    add t0, s7, \p
    lhu t1, 6(t0)
    lhu t2, 14(t0)
    li \tag, 31
    beq t1, t2, .Lmiss\@
    slli t1, t1, 1
    slli t2, t2, 1
    add t1, s9, t1
    add t2, s9, t2
    slli t3, \o, 2
.Lscan\@:
    lhu t4, 0(t1)
    bgeu t4, t3, .Lmaybe\@
    addi t1, t1, 2
    bne t1, t2, .Lscan\@
    j .Lmiss\@
.Lmaybe\@:
    sub t4, t4, t3
    sltiu t0, t4, 32
    beqz t0, .Lmiss\@
    mv \tag, t4
.Lmiss\@:
    .endm

# a0 takes the state string and returns the move count or error. a1 is the output buffer and a2 its capacity.
rubik_solve_asm:
    addi sp, sp, -64
    sw ra, 60(sp)
    sw s0, 56(sp)
    sw s1, 52(sp)
    sw s2, 48(sp)
    sw s3, 44(sp)
    sw s4, 40(sp)
    sw s5, 36(sp)
    sw s6, 32(sp)
    sw s7, 28(sp)
    sw s8, 24(sp)
    sw s9, 20(sp)

    mv s2, a1
    mv s3, a2
    mv s6, sp                 # Room for up to eleven moves
    la s7, .Lperm_rows
    la s8, .Lorient_rows
    la s9, .Ldictionary

    la a3, .Lrank_weights
    la a4, .Lpopcounts
    li s0, 0
    li t0, 0                  # One bit for each corner seen so far
    li t1, 7

# Check the seven corners for repeats while building the permutation number.
.Lperm:
    lbu t2, 0(a0)
    addi t2, t2, -49
    li t3, 7
    bgeu t2, t3, .Lbad
    li t3, 1
    sll t3, t3, t2
    and t4, t0, t3
    bnez t4, .Lbad
    addi t4, t3, -1
    and t4, t0, t4
    or t0, t0, t3
    add t4, a4, t4
    lbu t4, 0(t4)
    sub t2, t2, t4
    slli t2, t2, 1
    add t2, a3, t2
    lhu t2, 0(t2)
    add s0, s0, t2
    addi a3, a3, 16
    addi a0, a0, 1
    addi t1, t1, -1
    bnez t1, .Lperm

    slli s0, s0, 3
    li t0, 0
    li s1, 0
    li t1, 6
    li t3, 3
.Lorient:
    lbu t2, 0(a0)
    addi t2, t2, -49
    bgeu t2, t3, .Lbad
    slli t4, s1, 1
    add s1, s1, t4
    add s1, s1, t2
    add t0, t0, t2
    addi a0, a0, 1
    addi t1, t1, -1
    bnez t1, .Lorient
    lbu t2, 0(a0)
    addi t2, t2, -49
    bgeu t2, t3, .Lbad

    lbu t4, 1(a0)
    bnez t4, .Lbad
    add t0, t0, t2
    li t2, 0x1249
    srl t2, t2, t0
    andi t2, t2, 1
    beqz t2, .Lbad
    slli s1, s1, 3

    li s4, 0                  # Number of moves saved so far
    probe s0, s1, t5
    li t0, 31
    li s5, 1                  # Try a one-move search first
    beq t5, t0, .Ltry_depth
    li t0, 16
    bltu t5, t0, .Ltail
    addi t5, t5, -16
    sb t5, 0(s6)
    li s4, 1
    jal ra, .Lapply_move
    li s5, 5                  # Ten moves left: five moves can reach the five-move table.

# Try one more level at a time until the search reaches the table.
.Ltry_depth:
    mv a0, s0
    mv a1, s1
    mv a2, s5
    add a3, s6, s4
    jal ra, .Lmeet
    bnez a0, .Ljoined
    addi s5, s5, 1
    li t0, 6
    bltu s5, t0, .Ltry_depth
    j .Lbad                   # Every valid state should have a solution by this point.
.Ljoined:
    add s4, s4, s5
    mv s0, a1
    mv s1, a2
    mv t5, a3

# Follow the table for the remaining moves.
.Ltail:
    li t0, 9
    beq t5, t0, .Lformat
    add t1, s6, s4
    sb t5, 0(t1)
    addi s4, s4, 1
    jal ra, .Lapply_move
    probe s0, s1, t5
    j .Ltail

# Apply the move in t5 to the permutation in s0 and the orientation in s1.
.Lapply_move:
    li t0, 0
    li t1, 3
.Lface:
    bltu t5, t1, .Lturn_setup
    addi t5, t5, -3
    addi t0, t0, 2
    j .Lface
.Lturn_setup:
    add t1, s7, t0
    add t2, s8, t0
.Lturn:
    add t3, t1, s0
    add t4, t2, s1
    lhu s0, 0(t3)
    lhu s1, 0(t4)
    addi t5, t5, -1
    bgez t5, .Lturn
    ret

# Check the length before writing anything to the buffer.
.Lformat:
    la a3, .Ltokens
    mv t0, s6
    add t1, s6, s4
    slli t2, s4, 1            # Count face letters, spaces and the null byte first. Add suffixes later.
    bnez s4, .Lmeasure
    li t2, 1                  # Even a solved cube needs room for the null byte.
    j .Lcapacity
.Lmeasure:
    lbu t3, 0(t0)
    slli t3, t3, 1
    add t3, a3, t3
    lbu t4, 1(t3)
    snez t4, t4
    add t2, t2, t4
    addi t0, t0, 1
    bne t0, t1, .Lmeasure
.Lcapacity:
    bltu s3, t2, .Lsmall
    mv t0, s6
    beqz s4, .Lterminate

.Ltoken:
    lbu t3, 0(t0)
    slli t3, t3, 1
    add t3, a3, t3
    lbu t4, 0(t3)
    sb t4, 0(s2)
    addi s2, s2, 1
    lbu t4, 1(t3)
    beqz t4, .Lseparator
    sb t4, 0(s2)
    addi s2, s2, 1
.Lseparator:
    addi t0, t0, 1
    beq t0, t1, .Lterminate
    li t4, 32
    sb t4, 0(s2)
    addi s2, s2, 1
    j .Ltoken
.Lterminate:
    sb zero, 0(s2)
    mv a0, s4
    j .Lexit

.Lbad:
    li a0, -1
    j .Lexit
.Lsmall:
    li a0, -2
    beqz s3, .Lexit
    sb zero, 0(s2)

.Lexit:
    lw ra, 60(sp)
    lw s0, 56(sp)
    lw s1, 52(sp)
    lw s2, 48(sp)
    lw s3, 44(sp)
    lw s4, 40(sp)
    lw s5, 36(sp)
    lw s6, 32(sp)
    lw s7, 28(sp)
    lw s8, 24(sp)
    lw s9, 20(sp)
    addi sp, sp, 64
    ret

# Search to a fixed depth. s0 and s1 hold the start state and s2 and s3 hold the current state.
# s4 is the face offset, s5 counts turns and s6 holds the previous face.
# a4 is the depth left, a5 and a6 point to the move tables and a7 is the next move number.
.Lmeet:
    addi sp, sp, -176
    sw s0, 172(sp)
    sw s1, 168(sp)
    sw s2, 164(sp)
    sw s3, 160(sp)
    sw s4, 156(sp)
    sw s5, 152(sp)
    sw s6, 148(sp)
    sw s10, 144(sp)
    sw s11, 140(sp)

    mv s10, sp
    mv s11, a3
    mv s0, a0
    mv s1, a1
    mv a4, a2
    li s6, -1

.Lfirst_face:

    li s4, 0
    li a7, 0
.Lbegin_face:
    beq s4, s6, .Lskip
    mv s2, s0
    mv s3, s1
    li s5, 0
    add a5, s7, s4
    add a6, s8, s4

.Lcandidate:
    add t0, a5, s2
    add t1, a6, s3
    lhu s2, 0(t0)
    lhu s3, 0(t1)
    addi s5, s5, 1
    li t0, 1
    bne a4, t0, .Ldescend
    probe s2, s3, t5
    sltiu t0, t5, 10
    bnez t0, .Lhit
.Lnext_turn:
    addi a7, a7, 1
    li t0, 3
    bltu s5, t0, .Lcandidate
    j .Lnext_face
.Lskip:
    addi a7, a7, 3

.Lnext_face:
    addi s4, s4, 2
    li t0, 6
    bltu s4, t0, .Lbegin_face
    beq s10, sp, .Lnone

    # All faces at this level have been tried. Go back one level.
    addi s10, s10, -32
    lw s0, 0(s10)
    lw s1, 4(s10)
    lw s2, 8(s10)
    lw s3, 12(s10)
    lw s4, 16(s10)
    lw s5, 20(s10)
    lw s6, 24(s10)
    lw a7, 28(s10)
    add a5, s7, s4
    add a6, s8, s4
    addi a4, a4, 1
    addi s11, s11, -1
    j .Lnext_turn

# Save this level before searching one level deeper.
.Ldescend:
    sb a7, 0(s11)
    sw s0, 0(s10)
    sw s1, 4(s10)
    sw s2, 8(s10)
    sw s3, 12(s10)
    sw s4, 16(s10)
    sw s5, 20(s10)
    sw s6, 24(s10)
    sw a7, 28(s10)
    addi s10, s10, 32
    addi s11, s11, 1
    addi a4, a4, -1
    mv s0, s2
    mv s1, s3
    mv s6, s4
    j .Lfirst_face

.Lhit:
    sb a7, 0(s11)
    li a0, 1
    mv a1, s2
    mv a2, s3
    mv a3, t5
    j .Lleave
.Lnone:
    li a0, 0

.Lleave:
    lw s0, 172(sp)
    lw s1, 168(sp)
    lw s2, 164(sp)
    lw s3, 160(sp)
    lw s4, 156(sp)
    lw s5, 152(sp)
    lw s6, 148(sp)
    lw s10, 144(sp)
    lw s11, 140(sp)
    addi sp, sp, 176
    ret
    .size rubik_solve_asm,.-rubik_solve_asm

    .section .rodata
.Ltokens:
    .byte 82, 0, 82, 50, 82, 39, 66, 0, 66, 50, 66, 39, 68, 0, 68, 50, 68, 39

# Each entry counts the set bits in its index.
.Lpopcounts:
    .byte 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
    .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
    .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
    .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
    .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
    .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
    .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
    .byte 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7

    .balign 2
.Lrank_weights:
    .half 0, 720, 1440, 2160, 2880, 3600, 4320, 5040
    .half 0, 120, 240, 360, 480, 600, 720, 840
    .half 0, 24, 48, 72, 96, 120, 144, 168
    .half 0, 6, 12, 18, 24, 30, 36, 42
    .half 0, 2, 4, 6, 8, 10, 12, 14
    .half 0, 1, 2, 3, 4, 5, 6, 7
    .half 0, 1, 2, 3, 4, 5, 6, 7

    .include "src/rubik/cube_tables.inc"
