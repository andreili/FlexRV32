`ifndef __RV_OPCODES__
`define __RV_OPCODES__

/* verilator lint_off UNUSEDPARAM */
localparam  logic[1:0] RV32_C_Q0_DET = 2'b00;
localparam  logic[1:0] RV32_C_Q1_DET = 2'b01;
localparam  logic[1:0] RV32_C_Q2_DET = 2'b10;
localparam  logic[1:0] RV32_OPC_DET  = 2'b11;

localparam  logic[4:0] RV32_OPC_LOAD     = 5'b00000;    // 0
localparam  logic[4:0] RV32_OPC_LOAD_FP  = 5'b00001;    // 1
localparam  logic[4:0] RV32_OPC_CUSTOM0  = 5'b00010;    // 2
localparam  logic[4:0] RV32_OPC_MISC_MEM = 5'b00011;    // 3
localparam  logic[4:0] RV32_OPC_OP_IMM   = 5'b00100;    // 4
localparam  logic[4:0] RV32_OPC_AUIPC    = 5'b00101;    // 5

localparam  logic[4:0] RV32_OPC_STORE    = 5'b01000;    // 8
localparam  logic[4:0] RV32_OPC_STORE_FP = 5'b01001;    // 9
localparam  logic[4:0] RV32_OPC_CUSTOM1  = 5'b01010;    // 10
localparam  logic[4:0] RV32_OPC_AMO      = 5'b01011;    // 11
localparam  logic[4:0] RV32_OPC_OP       = 5'b01100;    // 12
localparam  logic[4:0] RV32_OPC_LUI      = 5'b01101;    // 13
localparam  logic[4:0] RV32_OPC_OP_32    = 5'b01110;    // 14

localparam  logic[4:0] RV32_OPC_MADD     = 5'b10000;    // 16
localparam  logic[4:0] RV32_OPC_MSUB     = 5'b10001;    // 17
localparam  logic[4:0] RV32_OPC_NMSUB    = 5'b10010;    // 18
localparam  logic[4:0] RV32_OPC_NMADD    = 5'b10011;    // 19
localparam  logic[4:0] RV32_OPC_OP_FP    = 5'b10100;    // 20
localparam  logic[4:0] RV32_OPC_OP_V     = 5'b10101;    // 21
localparam  logic[4:0] RV32_OPC_CUSTOM2  = 5'b10110;    // 22

localparam  logic[4:0] RV32_OPC_BRANCH   = 5'b11000;    // 24
localparam  logic[4:0] RV32_OPC_JALR     = 5'b11001;    // 25
localparam  logic[4:0] RV32_OPC_RESERVED1= 5'b11010;    // 26
localparam  logic[4:0] RV32_OPC_JAL      = 5'b11011;    // 27
localparam  logic[4:0] RV32_OPC_SYSTEM   = 5'b11100;    // 28
localparam  logic[4:0] RV32_OPC_RESERVED2= 5'b11101;    // 29
localparam  logic[4:0] RV32_OPC_CUSTOM3  = 5'b11110;    // 30
/* verilator lint_on UNUSEDPARAM */

`endif // __RV_OPCODES__
