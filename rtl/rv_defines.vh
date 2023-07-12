`define EXTENSION_Zifencei //TODO - only with cache/multicore
//`define EXTENSION_Zihintntl //TODO - only with cache

//`define U_MODE // TODO
`ifdef U_MODE
//`define S_MODE // TODO
`endif // U_MODE

`define SLAVE_SEL_WIDTH                 4
`ifdef TO_SIM
    `define TCM_ADDR_WIDTH              21
`else
    `define TCM_ADDR_WIDTH              12
`endif

//`define ALU2_ISOLATED
//`define USE_SCHEMATIC
