
# RISC-V core
This is my hobby project for deeper study of SystemVerilog and CPU architecture

# Dependencies
- RISC-V GCC >= 12 (riscv64-unknown-elf)
- Verilator >= 4.226
- Make

# Performance
All performance measured on simulation (DHRYSTONE test), Fmax checked on FPGA synthesis (target - EP4CE6F17C8).

Pipelined core:
|Type|LEs|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|
|-|-|-|-|-|-|
|RV32IC+PB(2)|1924|82|217836|123.98|1.060|
|RV32IC+PB(2)+ALU2_isol|1856|110|190206|108.25|0.925|
|RV32IMC+PB(2)+ALU2_isol|2567|90|190206|108.25|0.925|
|PB(2)+BTB|833|120|261880|149.05|1.242|

Agenda:
- PB - Prefetch buffer. Number - size of buffer addres bits, e.g. "2" - for 4 half-word buffer.
- BTB - Branch Target Buffer.

# Features
- Prefetch buffer - need to pipelined architecture for more performance.
- Extensions:
  - C extension.
  - Zicsr extension (with Zicntr and Zihpm features).
  - M extension (need to optimize).
 
# TODO
- Extensions:
  - F extension.
  - Interrupts.


# Verification
Core have a ready verification envionment (vrf) and using a verilator software.
All processing launched via make, with following format:

    make TARGET [parameter=value]

Currently supported targets:

    sim - to run a TOP-level simulation with a custom firmware.
    arch - to run a TOP-level simulation for architecture tests.

Parameters:

    fw=<name> - point to name a firmware, needs to run a simulation, Firmware must build before a simulation phase.
    trace=1 - store all signal on FST-file and open it after a simulation finished.
    cycles=<number> - point to a maximum simulation cycles to run.

Validation environment support a output to terminal and simulation termination from FW - see a fw/common/sim.c to more details.
