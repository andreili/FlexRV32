//`define PREFETCH_BUFFER
//`define BRANCH_PREDICTION_SIMPLE TODO!

`define EXTENSION_C
`define EXTENSION_Zifencei //TODO - only with cache/multicore
//`define EXTENSION_Zihintntl //TODO - only with cache
`define EXTENSION_Zicsr
`define EXTENSION_Zicntr
//`define EXTENSION_Zihpm

`define SLAVE_SEL_WIDTH                 4
`ifdef TO_SIM
    `define TCM_ADDR_WIDTH              21
`else
    `define TCM_ADDR_WIDTH              13
`endif

`define INSTR_BUF_ADDR_SIZE 2
`define INSTR_BUF_SIZE (2 ** `INSTR_BUF_ADDR_SIZE)
`define INSTR_BUF_SIZE_BITS (16)

