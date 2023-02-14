`timescale 1ps/1ps

module mint
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_start,
    input   wire                        i_op1_signed,
    input   wire                        i_op2_signed,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[31:0]                  o_div,
    output  wire[63:0]                  o_mul,
    output  wire[31:0]                  o_rem
);

    logic[31:0] op_a, op_b;
    logic[32:0] op1_m, op2_m;
    logic[31:0] div;
    logic[31:0] rem;
    logic       m_sign;
    assign      op_a  = ((i_op1_signed & i_op1[31]) ? (~i_op1) : i_op1) +
                        { {31{1'b0}}, (i_op1_signed & i_op1[31]) };
    assign      op_b  = ((i_op2_signed & i_op2[31]) ? (~i_op2) : i_op2) +
                        { {31{1'b0}}, (i_op2_signed & i_op2[31]) };
    assign      op1_m = $signed({i_op1_signed ? i_op1[31] : 1'b0, op_a});
    assign      op2_m = $signed({i_op2_signed ? i_op2[31] : 1'b0, op_b});
    assign      div = op1_m[31:0] / op2_m[31:0];
    assign      rem = op1_m[31:0] % op2_m[31:0];
    assign      m_sign = (i_op1_signed & op1_m[32]) ^ (i_op2_signed & op2_m[32]);

    assign  o_div = m_sign ? ((~div) - '1) : div;
    assign  o_rem = m_sign ? ((~rem) - '1) : rem;

    logic       mul_last, start;
    logic[5:0]  op_cnt;
    logic[31:0] op1, op2;
    logic[63:0] mul;

    assign  mul_last = (op_cnt == 6'd31);

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            op_cnt <= 6'd31;
            start <= '0;
        end
        else if (mul_last & i_start)
        begin
            op1 <= i_op1;
            op2 <= i_op2;
            start <= '1;
            op_cnt <= '0;
        end
        else if (!mul_last)
        begin
            op2 <= { 1'b0, op2[31:1] };
            start <= '0;
            op_cnt <= op_cnt + 1'b1;
        end
    end

    logic[31:0] mmod;
    logic[32:0] msum;
    logic[32:0] sum_prev;

    assign  mmod = {32{mul_last}} ^ { (start | i_op1_signed) ^ (op1[31] & op2[0]),
                   op1[30:0] & {31{op2[0]}} };
    assign  msum = mmod + sum_prev;

    always_ff @(posedge i_clk)
    begin
        if (!mul_last)
        begin
            mul <= { 33'b0, msum[0], mul[30:1] };
            sum_prev <= { 1'b0, msum[32:1] };
        end
        else
        begin
            mul <= { ~msum[32], msum[31:0], mul[30:0] };
            sum_prev <= { i_op1_signed, 32'b0 };
        end
    end

    assign  o_mul = mul;

endmodule
