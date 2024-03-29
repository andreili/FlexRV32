`timescale 1ps/1ps

`include "../rv_defines.vh"

/* verilator lint_off UNUSEDSIGNAL */
module rv_ctrl
#(
    parameter logic ALU2_ISOLATED       = 0
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_pc_change,
    input   wire                        i_data_ack,
    input   wire                        i_decode_inst_sup,
    input   wire[4:0]                   i_decode_rs1,
    input   wire[4:0]                   i_decode_rs2,
    input   wire                        i_alu1_mem_rd,
    input   wire[4:0]                   i_alu1_rd,
    input   wire                        i_alu2_mem_rd,
    input   wire[4:0]                   i_alu2_rd,
    input   wire                        i_alu2_ready,
    input   wire                        i_need_pause,
    output  wire                        o_fetch_stall,
    output  wire                        o_decode_flush,
    output  wire                        o_decode_stall,
    output  wire                        o_alu1_flush,
    output  wire                        o_alu1_stall,
    output  wire                        o_alu2_flush,
    output  wire                        o_alu2_stall,
    output  wire                        o_write_flush,
    output  wire                        o_write_stall,
    output  wire                        o_inv_inst
);
/* verilator lint_on UNUSEDSIGNAL */

    logic[1:0]  need_mem_data;
    logic       wait_write;

    assign  need_mem_data[0] = (i_alu1_mem_rd | ALU2_ISOLATED) &
                               (|i_alu1_rd  ) &
                               ((i_decode_rs1 == i_alu1_rd  ) |
                                (i_decode_rs2 == i_alu1_rd  ));
    assign  need_mem_data[1] = ALU2_ISOLATED & i_alu2_mem_rd  &
                               (|i_alu2_rd  ) &
                               ((i_decode_rs1 == i_alu2_rd  ) |
                                (i_decode_rs2 == i_alu2_rd  ));

    always_ff @(posedge i_clk)
    begin
        wait_write <= i_alu2_mem_rd & ALU2_ISOLATED;
    end

    logic   decode_stall, alu1_stall, alu2_stall, write_stall;
    assign  decode_stall = need_mem_data[0] | i_need_pause | (!i_alu2_ready) | need_mem_data[1]
                           | (i_alu1_mem_rd & ALU2_ISOLATED);
    assign  alu1_stall   = !i_alu2_ready;
    assign  alu2_stall   = '0;
    assign  write_stall  = wait_write;

    logic   global_flush, alu1_flush, alu2_flush, write_flush;
    assign  global_flush = (!i_reset_n) | i_pc_change;
    assign  alu1_flush   = global_flush | (decode_stall & i_alu2_ready);
    assign  alu2_flush   = global_flush;
    assign  write_flush  = global_flush | !i_alu2_ready;

    logic[1:0]  inst_sup;
    always_ff @(posedge i_clk)
    begin
        if (global_flush)
            inst_sup <= '1;
        else if (!decode_stall)
            inst_sup <= { inst_sup[0], i_decode_inst_sup };
    end

    assign  o_fetch_stall  = decode_stall;
    assign  o_decode_flush = global_flush;
    assign  o_decode_stall = decode_stall;
    assign  o_alu1_flush  = alu1_flush;
    assign  o_alu1_stall  = alu1_stall;
    assign  o_alu2_flush  = alu2_flush;
    assign  o_alu2_stall  = alu2_stall;
    assign  o_write_flush = write_flush;
    assign  o_write_stall = write_stall;

    assign  o_inv_inst = !inst_sup[1];

endmodule
