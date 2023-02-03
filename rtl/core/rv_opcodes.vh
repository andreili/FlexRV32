/* verilator lint_off UNUSEDPARAM */
localparam  logic[1:0] RV32_C_Q0_DET = 2'b00;
localparam  logic[1:0] RV32_C_Q1_DET = 2'b01;
localparam  logic[1:0] RV32_C_Q2_DET = 2'b10;
localparam  logic[1:0] RV32_OPC_DET  = 2'b11;

localparam  logic[4:0] RV32_OPC_LD   = 5'b00000;
localparam  logic[4:0] RV32_OPC_MEM  = 5'b00011;
localparam  logic[4:0] RV32_OPC_ARI  = 5'b00100;
localparam  logic[4:0] RV32_OPC_AUI  = 5'b00101;
localparam  logic[4:0] RV32_OPC_STR  = 5'b01000;
localparam  logic[4:0] RV32_OPC_ARR  = 5'b01100;
localparam  logic[4:0] RV32_OPC_LUI  = 5'b01101;
localparam  logic[4:0] RV32_OPC_B    = 5'b11000;
localparam  logic[4:0] RV32_OPC_JALR = 5'b11001;
localparam  logic[4:0] RV32_OPC_JAL  = 5'b11011;
localparam  logic[4:0] RV32_OPC_SYS  = 5'b11100;
/* verilator lint_on UNUSEDPARAM */
