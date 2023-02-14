`timescale 1ps/1ps

module adder
(
    input   wire                        i_is_sub,
    input   wire                        i_cmp_inverse,
    input   wire[32:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[32:0]                  o_add,
    output  wire                        o_eq,
    output  wire                        o_lts,
    output  wire                        o_ltu
);

    logic[31:0] opb;
    logic[32:0] add;
    logic       overflow;
    logic       negative;
    logic       zero;
    logic       carry;

    assign  opb      = {32{i_is_sub}} ^ i_op2;
    assign  add      = i_op1 + opb + { {32{1'b0}}, i_is_sub };
    assign  overflow = (i_op1[31] ^ i_op2[31]) & (i_op1[31] ^ add[31]);
    assign  negative = add[31];
    assign  zero     = !(|add[31:0]);
    assign  carry    = add[32];

    assign  o_add = add;
    assign  o_eq  = i_cmp_inverse ^ zero;
    assign  o_lts = i_cmp_inverse ^ (negative ^ overflow);
    assign  o_ltu = i_cmp_inverse ^ (!carry);

endmodule
