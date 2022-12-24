.section .text
.globl Reset
.globl entry_point

Reset:
    j init


init:
    # initalize stack pointer
    lui x15, %hi(_estack)
    addi sp, x15, %lo(_estack)

    # intialize .BSS
    la a0, _sbss
    la a1, _ebss
bss_loop:
    bge a0, a1, bss_end
    sw zero, 0(a0)
    add a0, a0, 4
    j bss_loop
bss_end:

    # copy .DATA
    # TODO

    j main
