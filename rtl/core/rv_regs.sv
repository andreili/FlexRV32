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

    logic   clk, reset_n;
    buf buf_clk(clk, i_clk);
    buf buf_reset(reset_n, i_reset_n);

`ifndef ASIC
    logic       wr_en;
    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[31:0] rdata1[32];
    logic[31:0] rdata2[32];
    logic[31:0] r_data1;
    logic[31:0] r_data2;
    logic[4:0]  rs1_mux;
    logic[4:0]  rs2_mux;

    assign  wr_en = reset_n & i_write;
    assign  rs1_mux = i_rs_valid ? i_rs1 : rs1;
    assign  rs2_mux = i_rs_valid ? i_rs2 : rs2;

    genvar i, j;
    generate
        for (i=0 ; i<32 ; i++)
        begin : g_bit
            for (j=1 ; j<32 ; j++)
            begin : g_word
                logic rd_sel, rs1_sel, rs2_sel, wr_sel, reg_out;

                assign  rd_sel = (i_rd == j);
                assign  rs1_sel = (rs1_mux == j);
                assign  rs2_sel = (rs2_mux == j);
                assign  wr_sel = wr_en & rd_sel;

                reg_e r_bit
                (
                    .CLK(clk),
                    .D  (i_data[i]),
                    .DE (wr_sel),
                    .Q  (reg_out)
                );

                assign rdata1[i][j] = rs1_sel & reg_out;
                assign rdata2[i][j] = rs2_sel & reg_out;
            end
            assign rdata1[i][0] = '0;
            assign rdata2[i][0] = '0;

            logic dat1, dat2;

            assign dat1 = |rdata1[i];
            assign dat2 = |rdata2[i];

            reg_s r_rs1
            (
                .CLK(clk),
                .D  (dat1),
                .Q  (r_data1[i])
            );

            reg_s r_rs2
            (
                .CLK(clk),
                .D  (dat2),
                .Q  (r_data2[i])
            );
        end
    endgenerate

    reg_e r_rs1[4:0]
    (
        .CLK(clk),
        .D  (i_rs1),
        .DE (i_rs_valid),
        .Q  (rs1)
    );

    reg_e r_rs2[4:0]
    (
        .CLK(clk),
        .D  (i_rs2),
        .DE (i_rs_valid),
        .Q  (rs2)
    );

    assign  o_data1 = r_data1;
    assign  o_data2 = r_data2;
`else

    logic       wr_en;
    logic[31:0] reg_data[32];
    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[31:0] rdata1;
    logic[31:0] rdata2;
    logic[4:0]  rs1_mux;
    logic[4:0]  rs2_mux;

    assign  wr_en = reset_n & i_write;
    assign  rs1_mux = i_rs_valid ? i_rs1 : rs1;
    assign  rs2_mux = i_rs_valid ? i_rs2 : rs2;

    always_ff @(posedge clk)
    begin
        if (wr_en)
        reg_data[i_rd] <= i_data;
        rdata1 <= reg_data[rs1_mux];
        rdata2 <= reg_data[rs2_mux];
        if (i_rs_valid)
        begin
            rs1 <= i_rs1;
            rs2 <= i_rs2;
        end
    end

    assign  o_data1 = (|rs1) ? rdata1 : '0;
    assign  o_data2 = (|rs2) ? rdata2 : '0;

`endif

`ifdef TO_SIM
    assign  o_rd_tr = rdata1[i_rd_tr];
`endif

endmodule
