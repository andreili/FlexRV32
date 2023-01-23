`timescale 1ps/1ps

`include "../rv_defines.vh"

/* verilator lint_off UNUSEDSIGNAL */
module rv_ctrl
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_pc_change,
    input   wire[4:0]                   i_decode_rs1,
    input   wire[4:0]                   i_decode_rs2,
    input   wire[4:0]                   i_alu1_rs1,
    input   wire[4:0]                   i_alu1_rs2,
    input   wire                        i_alu1_mem_rd,
    input   wire[4:0]                   i_alu1_rd,
    input   wire                        i_alu2_mem_rd,
    input   wire[4:0]                   i_alu2_rd,
    input   wire                        i_alu2_reg_write,
    input   wire                        i_memory_mem_rd,
    input   wire[4:0]                   i_memory_rd,
    input   wire                        i_memory_reg_write,
    input   wire[4:0]                   i_write_rd,
    input   wire                        i_write_reg_write,
    input   wire[4:0]                   i_wr_back_rd,
    input   wire                        i_wr_back_reg_write,
    output  wire                        o_decode_flush,
    output  wire                        o_decode_stall,
    output  ctrl_rs_bp_t                o_rs1_bp,
    output  ctrl_rs_bp_t                o_rs2_bp,
    output  wire                        o_alu1_stall,
    output  wire                        o_alu1_flush,
    output  wire                        o_alu2_flush,
    output  wire                        o_mem_flush
);

    logic   rs1_on_alu2, rs1_on_memory, rs1_on_write, rs1_on_wr_back;
    assign  rs1_on_alu2    = i_alu2_reg_write & (|i_alu1_rs1) & (i_alu1_rs1 == i_alu2_rd   );
    assign  rs1_on_memory  = i_memory_reg_write & (|i_alu1_rs1) & (i_alu1_rs1 == i_memory_rd );
    assign  rs1_on_write   = i_write_reg_write & (|i_alu1_rs1) & (i_alu1_rs1 == i_write_rd  );
    assign  rs1_on_wr_back = i_wr_back_reg_write & (|i_alu1_rs1) & (i_alu1_rs1 == i_wr_back_rd);
    logic   rs2_on_alu2, rs2_on_memory, rs2_on_write, rs2_on_wr_back;
    assign  rs2_on_alu2    = i_alu2_reg_write & (|i_alu1_rs2) & (i_alu1_rs2 == i_alu2_rd   );
    assign  rs2_on_memory  = i_memory_reg_write & (|i_alu1_rs2) & (i_alu1_rs2 == i_memory_rd );
    assign  rs2_on_write   = i_write_reg_write & (|i_alu1_rs2) & (i_alu1_rs2 == i_write_rd  );
    assign  rs2_on_wr_back = i_wr_back_reg_write & (|i_alu1_rs2) & (i_alu1_rs2 == i_wr_back_rd);

    logic   rs_on_alu2, rs_on_memory, rs_on_write, rs_on_wr_back;
    assign  rs_on_alu2    = (|i_alu2_rd  ) & ((i_alu1_rs1 == i_alu2_rd  ) | (i_alu1_rs2 == i_alu2_rd  ));
    assign  rs_on_memory  = (rs1_on_memory  | rs2_on_memory );
    assign  rs_on_write   = (rs1_on_write   | rs2_on_write  );
    assign  rs_on_wr_back = (rs1_on_wr_back | rs2_on_wr_back);

    logic   need_mem_data1, need_mem_data2;
    assign  need_mem_data1 = i_alu1_mem_rd & (|i_alu1_rd) & ((i_decode_rs1 == i_alu1_rd) | (i_decode_rs2 == i_alu1_rd));
    assign  need_mem_data2 = i_alu2_mem_rd & (|i_alu2_rd) & ((i_decode_rs1 == i_alu2_rd) | (i_decode_rs2 == i_alu2_rd));

    logic   decode_stall, alu1_stall;
    assign  decode_stall = need_mem_data2 | need_mem_data1;
    assign  alu1_stall   = '0;//decode_stall | need_mem_data2;

    logic   decode_flush, alu1_flush, alu2_flush;
    assign  decode_flush = i_pc_change;
    assign  alu1_flush   = i_pc_change | decode_stall;
    assign  alu2_flush   = i_pc_change;

    assign  o_decode_flush = decode_flush;
    assign  o_decode_stall = decode_stall;
    assign  o_alu1_stall = alu1_stall;
    assign  o_alu1_flush = alu1_flush;
    assign  o_alu2_flush = alu2_flush;
    assign  o_mem_flush = '0;//i_pc_change;

    assign  o_rs1_bp.alu2    = rs1_on_alu2;
    assign  o_rs1_bp.memory  = rs1_on_memory  & (!rs1_on_alu2);
    assign  o_rs1_bp.write   = rs1_on_write   & (!rs1_on_alu2) & (!rs1_on_memory);
    assign  o_rs1_bp.wr_back = rs1_on_wr_back & (!rs1_on_alu2) & (!rs1_on_memory) & (!rs1_on_write);

    assign  o_rs2_bp.alu2 = rs2_on_alu2;
    assign  o_rs2_bp.memory  = rs2_on_memory  & (!rs2_on_alu2);
    assign  o_rs2_bp.write   = rs2_on_write   & (!rs2_on_alu2) & (!rs2_on_memory);
    assign  o_rs2_bp.wr_back = rs2_on_wr_back & (!rs2_on_alu2) & (!rs2_on_memory) & (!rs2_on_write);

endmodule
/* verilator lint_on UNUSEDSIGNAL */
