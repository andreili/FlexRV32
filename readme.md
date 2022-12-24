
# RISC-V core
This is my hobby project for deeper study of SystemVerilog and CPU architecture

# Overviev
Core supported two modes - staged and pipelined. On staged mode, one instruction executed on 5 ticks of main clock. This behavior controlled by defines on defines.vh (MODE_STAGED).
For instrutions and data, core have a TCM memory with individual bus.

# Perfomance
All perfomance mesured on simulation (DHRYSTONE test), Fmax checked on FPGA synthesis (target - 5CSEMA5F31C6).
|Core type|Fmax,MHz|Dhrystone/sec|DMIPS|DMIPS/MHz|Profit|Profit/MHz|
|-|-|-|-|-|-|-|
|5st|75|160902|91.57769|1.22104|-|-|
|6st|110|198151|112.778|1.0253|+23.15%|-16.03%|
|7st|125|213626|121.586|0.9727|+7.81%|-5.127%|
 
# TODO
- Extensions:
- Zicsr extension (with Zicntr and Zihpm features, WIP).
- M extension.
- F extension.
- Interrupts.
- Add support for all modes on cache.


# Verification
Core have a ready verification envionment (vrf) and using a verilator software.
To run a TOP tests (supported "test", "dhrystone" firmware targets):

    make sim target=top fw=test
To run a architecture test:

    make arch
Validation environment support a output to terminal and simulation termination from FW - see a fw/common/sim.c to more details.