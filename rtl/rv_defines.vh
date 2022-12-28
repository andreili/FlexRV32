`define SLAVE_SEL_WIDTH                 4
`define TCM_ADDR_WIDTH                  13

//`define BRANCH_PREDICTION_SIMPLE

`define ALU_SRC_OP2_I       3'd0
`define ALU_SRC_OP2_U       3'd1
`define ALU_SRC_OP2_J       3'd2
//`define ALU_SRC_OP2_B       3'd3
`define ALU_SRC_OP2_S       3'd4
`define ALU_SRC_OP2_REG     3'd5

`define RESULT_SRC_ALU      2'b00
`define RESULT_SRC_MEMORY   2'b01
`define RESULT_SRC_PC_P4    2'b10

`define ALU_SRC_OP1_REG     1'b0
`define ALU_SRC_OP1_PC      1'b1

`define ALU_GRP_CMP         1'b0
`define ALU_CMP_NIN         1'b0
`define ALU_CMP_INV         1'b1
`define ALU_CMP_EQ          2'b00
`define ALU_CMP_LTS         2'b01
`define ALU_CMP_LTU         2'b10
//2'b11

`define ALU_GRP_ARIPH       2'b10
`define ALU_ARIPH_ADD       2'b00
`define ALU_ARIPH_SUB       2'b01
`define ALU_ARIPH_SHL       2'b10
`define ALU_ARIPH_SHR       2'b11

`define ALU_GRP_BITS        2'b11
`define ALU_BITS_XOR        2'b00
`define ALU_BITS_OR         2'b01
`define ALU_BITS_AND        2'b10
//2'b11
