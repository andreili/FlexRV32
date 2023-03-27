`timescale 1ps/1ps

module rv_regs
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_rs_valid,
    input   wire[4:0]                   i_rs1,
    input   wire[4:0]                   i_rs2,
    input   wire[4:0]                   i_rd,
    input   wire                        i_write,
    input   wire[31:0]                  i_data,
`ifdef TO_SIM
    input   wire[4:0]                   i_rd_tr,
    output  wire[31:0]                  o_rd_tr,
`endif
    output  wire[31:0]                  o_data1,
    output  wire[31:0]                  o_data2
);

    logic       wr_en;
    logic[31:0] reg_data[31];
    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[31:0] rdata1;
    logic[31:0] rdata2;
    logic[4:0]  rs1_mux;
    logic[4:0]  rs2_mux;

    logic[4:0]  rs1e;
    logic[4:0]  rs2e;
    logic[4:0]  rde;
    assign      rs1e = i_rs1 - 1;
    assign      rs2e = i_rs2 - 1;
    assign      rde  = i_rd  - 1;

    assign  wr_en = i_reset_n & i_write;
    assign  rs1_mux = i_rs_valid ? rs1e : rs1;
    assign  rs2_mux = i_rs_valid ? rs2e : rs2;

    always_ff @(posedge i_clk)
    begin
        if (wr_en)
            reg_data[rde] <= i_data;
        rdata1 <= reg_data[rs1_mux];
        rdata2 <= reg_data[rs2_mux];
        if (i_rs_valid)
        begin
            rs1 <= rs1e;
            rs2 <= rs2e;
        end
    end

    assign  o_data1 = (&rs1) ? '0 : rdata1;
    assign  o_data2 = (&rs2) ? '0 : rdata2;

`ifdef TO_SIM
    assign  o_rd_tr = reg_data[i_rd_tr-1];
`endif

endmodule
