`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_hazard
(
    input   wire[31:0]                  i_reg_data1,
    input   wire[31:0]                  i_reg_data2,
    input   wire[31:0]                  i_alu2_data,
    input   wire[31:0]                  i_wr_data,
    input   wire[31:0]                  i_wr_back_data,
    input   ctrl_rs_bp_t                i_bp1,
    input   ctrl_rs_bp_t                i_bp2,
    output  wire[31:0]                  o_data1,
    output  wire[31:0]                  o_data2
);

    logic[31:0] data1;
    always_comb
    begin
        case (1'b1)
        i_bp1.alu2   : data1 = i_alu2_data;
        i_bp1.write  : data1 = i_wr_data;
        i_bp1.wr_back: data1 = i_wr_back_data;
        default      : data1 = i_reg_data1;
        endcase
    end

    logic[31:0] data2;
    always_comb
    begin
        case (1'b1)
        i_bp2.alu2   : data2 = i_alu2_data;
        i_bp2.write  : data2 = i_wr_data;
        i_bp2.wr_back: data2 = i_wr_back_data;
        default      : data2 = i_reg_data2;
        endcase
    end

    assign  o_data1 = data1;
    assign  o_data2 = data2;

endmodule
