`define SLAVE_SEL_WIDTH                 4
`define TCM_ADDR_WIDTH                  13

//`define BRANCH_PREDICTION_SIMPLE

`define RESULT_SRC_ALU      2'b00
`define RESULT_SRC_MEMORY   2'b01
`define RESULT_SRC_PC_P4    2'b10

`define ALU_SRC_OP1_REG     1'b0
`define ALU_SRC_OP1_PC      1'b1

`define ALU_SRC_OP2_REG     1'b0
`define ALU_SRC_OP2_IMM     1'b1

`define ALU_CMP_EQ          4'b0000
`define ALU_CMP_LTS         4'b0001
`define ALU_CMP_LTU         4'b0010
//4'b0011
`define ALU_CMP_NEQ         4'b0100
`define ALU_CMP_NLTS        4'b0101
`define ALU_CMP_NLTU        4'b0110
//4'b0111

`define ALU_CTRL_ADD        4'b1000
`define ALU_CTRL_SUB        4'b1001
`define ALU_CTRL_SHL        4'b1010
`define ALU_CTRL_SHR        4'b1011
`define ALU_CTRL_XOR        4'b1100
`define ALU_CTRL_OR         4'b1101
`define ALU_CTRL_AND        4'b1110
//4'b1111
