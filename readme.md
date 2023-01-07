
# RISC-V core
This is my hobby project for deeper study of SystemVerilog and CPU architecture

# Overviev
Core supported one modes - staged. On staged mode, one instruction executed on 5 ticks of main clock.
Piplined mode must be implemented on future, after finished all extensions and features on staged mode.

# Dependencies
- RISC-V GCC >= 12 (riscv64-unknown-elf)
- Verilator >= 4.226
- Make

# Performance
All performance measured on simulation (DHRYSTONE test), Fmax checked on FPGA synthesis (target - 5CSEMA5F31C6).
|Type|ALMs|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|
|-|-|-|-|-|-|
|Minimal|563|166|79557|45.28|0.273|
|Prefetch(2)|706|179|85788|48.83|0.273|
|C|705|166|75744|43.11|0.26|
|Prefetch(2)+C|779|165|77518|44.12|0.26|

# Features
- Prefetch buffer - need to pipelined architecture for more performance.
- Extensions:
  - C extension.
 
# TODO
- Extensions:
  - Zicsr extension (with Zicntr and Zihpm features, WIP).
  - M extension.
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
