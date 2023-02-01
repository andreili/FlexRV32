`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_hazard
(
    input   wire                        i_clk,
    input   wire[31:0]                  i_reg_data,
    input   wire[31:0]                  i_alu2_data,
    input   wire[31:0]                  i_mem_data,
    input   wire[31:0]                  i_wr_data,
    input   ctrl_rs_bp_t                i_bp,
    output  wire[31:0]                  o_data
);

    logic[31:0] bp_data;
    logic[31:0] bp_reg;
    logic       bp_active;

    assign  bp_data = i_bp.alu2 ? i_alu2_data :
                      i_bp.memory ? i_mem_data :
                      i_wr_data;

    always_ff @(posedge i_clk)
    begin
        bp_active <= |i_bp;
        bp_reg <= bp_data;
    end

    assign  o_data = bp_active ? bp_reg : i_reg_data;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_bp.write;
/* verilator lint_on UNUSEDSIGNAL */

endmodule
