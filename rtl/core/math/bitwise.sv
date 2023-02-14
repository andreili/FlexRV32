`timescale 1ps/1ps

module bitwise
(
    input   wire                        i_sra,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[31:0]                  o_xor,
    output  wire[31:0]                  o_or,
    output  wire[31:0]                  o_and,
    output  wire[31:0]                  o_shl,
    output  wire[32:0]                  o_shr
);

    assign  o_xor = i_op1 ^ i_op2;
    assign  o_or  = i_op1 | i_op2;
    assign  o_and = i_op1 & i_op2;
    assign  o_shl = i_op1 << i_op2[4:0];
    assign  o_shr = $signed({i_sra ? i_op1[31] : 1'b0, i_op1}) >>> i_op2[4:0];

endmodule
