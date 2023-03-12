`timescale 1ps/1ps

module muldiv
(
    input   wire                        i_clk,
    input   wire                        i_on_wait,
    input   wire                        i_on_end,
    input   wire                        i_op1_signed,
    input   wire                        i_op2_signed,
    input   wire                        i_dr_signed,
    input   wire                        i_div_signed,
    input   wire                        i_rem_signed,
    input   wire                        i_is_div,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    input   wire                        i_op2_lsb,
    input   wire[32:0]                  i_add,
    input   wire[1:0]                   i_funct3,
    output  wire[31:0]                  o_mod,
    output  wire[32:0]                  o_add_prev,
    output  wire[63:0]                  o_mul,
    output  wire[31:0]                  o_div,
    output  wire[31:0]                  o_rem
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

/* verilator lint_off UNUSEDSIGNAL */
    logic[62:0] tmp_d;
/* verilator lint_on  UNUSEDSIGNAL */
    logic[31:0] dividend;
    logic[62:0] divisor;
    logic[31:0] quotient;
    logic[31:0] quotient_msk;
    logic       outsign;
    logic       on_wait;

    assign  tmp_d = { {31{1'b0}}, dividend } - divisor;

    always_ff @(posedge i_clk)
    begin
        if (i_on_end)
        begin
            quotient <= outsign ? -quotient : quotient;
            dividend <= outsign ? -dividend : dividend;
        end
        else if (on_wait)
        begin
            if (divisor <= { {31{1'b0}}, dividend })
            begin
                dividend <= tmp_d[31:0];
                quotient <= quotient | quotient_msk;
            end
            divisor <= divisor >> 1;
            quotient_msk <= quotient_msk >> 1;
        end
        else
        begin
            dividend <= (i_dr_signed && i_op1[31]) ? -i_op1 : i_op1;
            divisor <= {((i_dr_signed && i_op2[31]) ? -i_op2 : i_op2), {31{1'b0}} };
            outsign <= (i_div_signed && (i_op1[31] != i_op2[31]) && (|i_op2)) ||
                        (i_rem_signed && i_op1[31]);
            quotient <= 0;
            quotient_msk <= 1 << 31;
        end
        on_wait <= i_on_wait;
    end

    assign  o_div = quotient;
    assign  o_rem = dividend;

endmodule
