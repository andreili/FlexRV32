//`define PREFETCH_BUFFER

//`define EXTENSION_C

`define SLAVE_SEL_WIDTH                 4
`ifdef TO_SIM
    `define TCM_ADDR_WIDTH              21
`else
    `define TCM_ADDR_WIDTH              13
`endif

`define INSTR_BUF_ADDR_SIZE 2
`define INSTR_BUF_SIZE (2 ** `INSTR_BUF_ADDR_SIZE)
`define INSTR_BUF_SIZE_BITS (16)

//`define BRANCH_PREDICTION_SIMPLE

`ifndef PREFETCH_BUFFER
    `ifdef EXTENSION_C
        $error("Unsupported!");
    `endif
`endif
