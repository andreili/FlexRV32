`timescale 1ps/1ps

module muldiv
(
    input   wire                        i_clk,
    input   wire                        i_on_wait,
    input   wire                        i_op1_signed,
    input   wire                        i_op2_signed,
    input   wire                        i_is_div,
    input   wire[31:0]                  i_op1,
    input   wire                        i_op2_lsb,
    input   wire[32:0]                  i_add,
    input   wire[1:0]                   i_funct3,
    output  wire[31:0]                  o_mod,
    output  wire[32:0]                  o_add_prev,
    output  wire[63:0]                  o_mul
);

    logic[63:0] mul;
    logic[32:0] add_prev;

    always_ff @(posedge i_clk)
    begin
        if (i_on_wait | i_is_div)
        begin
            mul <= { 33'b0, i_add[0], mul[30:1] };
            add_prev <= { 1'b0, i_add[32:1] };
        end
        else
        begin
            mul <= { (i_op1_signed | i_op2_signed) ^ i_add[32], i_add[31:0], mul[30:0] };
            add_prev <= { 1'b0, !(&i_funct3[1:0]), 31'b0 };
        end
    end

    assign  o_mod = { i_op1_signed ^ (i_op1[31] & i_op2_lsb), i_op1[30:0] & {31{i_op2_lsb}} };
    assign  o_add_prev = add_prev;
    assign  o_mul = mul;
    //assign  o_mul = { (i_op1_signed | i_op2_signed) ^ i_add[32], i_add[31:0], mul[30:0] };

    /* verilator lint_off UNUSEDSIGNAL */
    logic[30:0] mul_msb;
    logic[63:0] mul_sh;
    logic[63:0] mul_r;
    logic[1:0]  mul_ch;
    logic       mul_dif;

    always_ff @(posedge i_clk)
    begin
        if (i_on_wait)
            mul_msb <= { i_add[0], mul_msb[30:1] };
        //mul_r <= mul_sh;
        //mul_ch <= { mul_ch[0], i_on_wait };
        //if (mul_ch[1] & (!mul_ch[0]))
        //    mul_dif <= (mul_r != mul);
    end
    assign mul_sh = { (i_op1_signed | i_op2_signed) ^ i_add[32], i_add[31:0], mul_msb };
    //assign  o_mul = mul_sh;
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
