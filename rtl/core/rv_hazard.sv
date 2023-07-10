`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"

module rv_hazard
(
    input   wire                        i_clk,
    input   wire[4:0]                   i_alu_rs1,
    input   wire[4:0]                   i_alu_rs2,
    input   wire[4:0]                   i_write_rd,
    input   wire                        i_write_reg_write,
    input   wire[31:0]                  i_reg_data1,
    input   wire[31:0]                  i_reg_data2,
    input   wire[31:0]                  i_alu2_data,
    input   wire[31:0]                  i_wr_data,
    output  wire[31:0]                  o_data1,
    output  wire[31:0]                  o_data2,
    output  wire[31:0]                  o_alu2_data,
    output  wire[31:0]                  o_write_data,
    output  wire[31:0]                  o_data2_ex
);

    logic[31:0] wr_back_data;
    logic[4:0]  wr_back_rd;
    logic       wr_back_op;
    always_ff @(posedge i_clk)
    begin
        wr_back_rd <= i_write_rd;
        wr_back_data <= i_wr_data;
        wr_back_op <= i_write_reg_write;
    end

    logic   rs1_on_write, rs1_on_wr_back;
    assign  rs1_on_write   = i_write_reg_write & (|i_alu_rs1) & (!(|(i_alu_rs1 ^ i_write_rd)));
    assign  rs1_on_wr_back = wr_back_op        & (|i_alu_rs1) & (!(|(i_alu_rs1 ^ wr_back_rd)));

    logic   rs2_on_write, rs2_on_wr_back;
    assign  rs2_on_write   = i_write_reg_write & (|i_alu_rs2) & (!(|(i_alu_rs2 ^ i_write_rd)));
    assign  rs2_on_wr_back = wr_back_op        & (|i_alu_rs2) & (!(|(i_alu_rs2 ^ wr_back_rd)));

    logic   rs1_wr_sel, rs1_wrb_sel, rs1_dir_sel;
    assign  rs1_wr_sel   = rs1_on_write;
    assign  rs1_wrb_sel  = !rs1_on_write & rs1_on_wr_back;
    assign  rs1_dir_sel  = !rs1_on_write & !rs1_on_wr_back;

    logic   rs2_wr_sel, rs2_wrb_sel, rs2_dir_sel;
    assign  rs2_wr_sel   = rs2_on_write;
    assign  rs2_wrb_sel  = !rs2_on_write & rs2_on_wr_back;
    assign  rs2_dir_sel  = !rs2_on_write & !rs2_on_wr_back;

    logic[31:0] data1, data2;

    assign data1 = ({ 32{rs1_wr_sel  } } & i_wr_data   ) |
                   ({ 32{rs1_wrb_sel } } & wr_back_data) |
                   ({ 32{rs1_dir_sel } } & i_reg_data1 );
    assign data2 = ({ 32{rs2_wr_sel  } } & i_wr_data   ) |
                   ({ 32{rs2_wrb_sel } } & wr_back_data) |
                   ({ 32{rs2_dir_sel } } & i_reg_data2 );

    assign  o_data1 = data1;
    assign  o_data2 = data2;
    assign  o_alu2_data  = i_alu2_data;
    assign  o_write_data = i_wr_data;
    assign  o_data2_ex   = data2;

endmodule
