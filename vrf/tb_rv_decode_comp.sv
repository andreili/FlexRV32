`timescale 1ps/1ps

module tb_rv_decode_comp
(
    input   wire[31:0]                  i_instruction,
    output  wire[31:0]                  o_instruction,
    output  wire                        o_illegal_instruction
);

    rv_decode_comp_sch
    u_dut
    (
        .i_instruction          (i_instruction),
        .o_instruction          (o_instruction),
        .o_illegal_instruction  (o_illegal_instruction)
    );

endmodule
