`timescale 1ps/1ps

module rv_regs
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
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

`ifdef ASIC

    reg[31:0]   r_data1;
    reg[31:0]   r_data2;

    logic[31:0] reg_data[32];
    logic[30:0] reg_data1[32];
    logic[30:0] reg_data2[32];

    genvar i, j;
    generate
        for (i=1 ; i<32 ; i++)
        begin : g_word
            logic rs1_sel, rs2_sel, wr_en;

            assign wr_en = i_reset_n & i_write & (i == i_rd);
            assign rs1_sel = (i == i_rs1);
            assign rs2_sel = (i == i_rs2);

            for (j=0 ; j<32 ; j++)
            begin : g_bit
                logic ro;

                reg_e
                r_bit
                (
                    .CLK(i_clk),
                    .D  (i_data[j]),
                    .DE (wr_en),
                    .Q  (ro)
                );

                assign reg_data1[j][i-1] = rs1_sel & ro;
                assign reg_data2[j][i-1] = rs2_sel & ro;

                assign reg_data[i][j] = ro;
            end
        end
    endgenerate

    logic[4:0] rs1;
    logic[4:0] rs2;

    reg_s r_rs1[4:0]
    (
        .CLK(i_clk),
        .D  (i_rs1),
        .Q  (rs1)
    );

    reg_s r_rs2[4:0]
    (
        .CLK(i_clk),
        .D  (i_rs2),
        .Q  (rs2)
    );

    logic[31:0] rdata1;
    logic[31:0] rdata2;

    generate
        for (i=0 ; i<32 ; i++)
        begin : g_mux
            assign rdata1[i] = |reg_data1[i];
            assign rdata2[i] = |reg_data2[i];
        end
    endgenerate

    always_ff @(posedge i_clk)
    begin
        r_data1 <= rdata1;
        r_data2 <= rdata2;
    end

    assign  o_data1 = (|rs1) ? r_data1 : '0;
    assign  o_data2 = (|rs2) ? r_data2 : '0;

    assign reg_data[0] = '0;
`else

    logic       wr_en;
    logic[31:0] reg_data[32];
    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[31:0] rdata1;
    logic[31:0] rdata2;

    assign wr_en = i_reset_n & i_write;

    always_ff @(posedge i_clk)
    begin
        if (wr_en)
        reg_data[i_rd] <= i_data;
        rdata1 <= reg_data[i_rs1];
        rdata2 <= reg_data[i_rs2];
        rs1 <= i_rs1;
        rs2 <= i_rs2;
    end

    assign  o_data1 = (|rs1) ? rdata1 : '0;
    assign  o_data2 = (|rs2) ? rdata2 : '0;

`endif

`ifdef TO_SIM
    assign  o_rd_tr = reg_data[i_rd_tr];
`endif

endmodule
