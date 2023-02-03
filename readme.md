
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

Multi-cycle core, for comparasion only:
|Type|ALMs|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|
|-|-|-|-|-|-|
|Minimal|510|182|87226|49.64|0.273|
|Prefetch(2)|645|187|89622|51.01|0.273|
|C|621|171|78026|44.41|0.260|
|Prefetch(2)+C|733|177|83156|47.33|0.267|

Pipelined core:
|Type|ALMs|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|
|-|-|-|-|-|-|
|RV32I+PB(2)|647|120|232053|132.07|1.101|
|PB(2)+BTB|833|120|261880|149.05|1.242|

Agenda:
- PB - Prefetch buffer. Number - size of buffer addres bits, e.g. "2" - for 4 half-word buffer.
- BTB - Branch Target Buffer.

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
