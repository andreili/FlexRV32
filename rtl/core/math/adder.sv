`timescale 1ps/1ps

module adder
(
    input   wire                        i_is_sub,
    input   wire[32:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[32:0]                  o_add,
    output  wire                        o_overflow,
    output  wire                        o_negative,
    output  wire                        o_zero,
    output  wire                        o_carry
);

    logic[31:0] opb;
    logic[32:0] add;

    assign  opb      = {32{i_is_sub}} ^ i_op2;
    assign  add      = i_op1 + opb + { {32{1'b0}}, i_is_sub };

    assign  o_add      = add;
    assign  o_overflow = (i_op1[31] ^ i_op2[31]) & (i_op1[31] ^ add[31]);
    assign  o_negative = add[31];
    assign  o_zero     = !(|add[31:0]);
    assign  o_carry    = add[32];

endmodule
