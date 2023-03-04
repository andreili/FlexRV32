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

    logic[31:0] data;
    always_comb
    begin
        case (1'b1)
        i_bp.alu2   : data = i_alu2_data;
        i_bp.write  : data = i_wr_data;
        i_bp.wr_back: data = i_wr_back_data;
        default     : data = i_reg_data;
        endcase
    end

    assign  o_data = data;

endmodule
