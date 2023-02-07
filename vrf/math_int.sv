`timescale 1ps/1ps

module math_int
(
    input   wire                        i_op1_signed,
    input   wire                        i_op2_signed,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[31:0]                  o_div,
    output  wire[63:0]                  o_mul,
    output  wire[31:0]                  o_rem
);

    mint
    u_int
    (
        .i_op1_signed                   (i_op1_signed),
        .i_op2_signed                   (i_op2_signed),
        .i_op1                          (i_op1),
        .i_op2                          (i_op2),
        .o_div                          (o_div),
        .o_mul                          (o_mul),
        .o_rem                          (o_rem)
    );

endmodule
