
# RISC-V core
This is my hobby project for deeper study of SystemVerilog and CPU architecture

# Overviev
Core supported one modes - staged. On staged mode, one instruction executed on 5 ticks of main clock.
Piplined mode must be implemented on future, after finished all extensions and features on staged mode.

# Perfomance
All perfomance measured on simulation (DHRYSTONE test), Fmax checked on FPGA synthesis (target - 5CSEMA5F31C6).
|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|
|-|-|-|-|
|162|77640|44.19|0.273|
 
# TODO
- Extensions:
  - C extension.
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
