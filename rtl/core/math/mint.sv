`timescale 1ps/1ps

module mint
(
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
    logic[63:0] mul;
    logic[31:0] div;
    logic[31:0] rem;
    logic       m_sign;
    assign      op_a  = ((i_op1_signed & i_op1[31]) ? (~i_op1) : i_op1) +
                        { {31{1'b0}}, (i_op1_signed & i_op1[31]) };
    assign      op_b  = ((i_op2_signed & i_op2[31]) ? (~i_op2) : i_op2) +
                        { {31{1'b0}}, (i_op2_signed & i_op2[31]) };
    assign      op1_m = $signed({i_op1_signed ? i_op1[31] : 1'b0, op_a});
    assign      op2_m = $signed({i_op2_signed ? i_op2[31] : 1'b0, op_b});
    assign      mul = op1_m[31:0] * op2_m[31:0];
    assign      div = op1_m[31:0] / op2_m[31:0];
    assign      rem = op1_m[31:0] % op2_m[31:0];
    assign      m_sign = (i_op1_signed & op1_m[32]) ^ (i_op2_signed & op2_m[32]);

    assign  o_div = m_sign ? ((~div) - '1) : div;
    assign  o_mul = m_sign ? ((~mul) - '1) : mul;
    assign  o_rem = m_sign ? ((~rem) - '1) : rem;

endmodule
