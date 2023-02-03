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

    reg[31:0]   r_reg_file[32];
    reg[31:0]   r_data1;
    reg[31:0]   r_data2;
    reg[4:0]    r_rs1;
    reg[4:0]    r_rs2;

    always_ff @(posedge i_clk)
    begin
        if (i_reset_n && i_write && (|i_rd))
            r_reg_file[i_rd] <= i_data;
        r_data1 <= r_reg_file[i_rs1];
        r_data2 <= r_reg_file[i_rs2];
        r_rs1 <= i_rs1;
        r_rs2 <= i_rs2;
    end

    assign  o_data1 = (|r_rs1) ? r_data1 : '0;
    assign  o_data2 = (|r_rs2) ? r_data2 : '0;

`ifdef TO_SIM
    assign  o_rd_tr = r_reg_file[i_rd_tr];

    initial begin
        r_reg_file[1] = 0;
        r_reg_file[2] = 0;
        r_reg_file[3] = 0;
    end
`endif

endmodule
