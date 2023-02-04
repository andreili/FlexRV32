`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_hazard
(
    input   wire[31:0]                  i_reg_data,
    input   wire[31:0]                  i_alu2_data,
    input   wire[31:0]                  i_wr_data,
    input   wire[31:0]                  i_wr_back_data,
    input   ctrl_rs_bp_t                i_bp,
    output  wire[31:0]                  o_data
);

    always_comb
    begin
        case (1'b1)
        i_bp.alu2   : o_data = i_alu2_data;
        i_bp.write  : o_data = i_wr_data;
        i_bp.wr_back: o_data = i_wr_back_data;
        default     : o_data = i_reg_data;
        endcase
    end

endmodule
