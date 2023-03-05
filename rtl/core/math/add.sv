`timescale 1ps/1ps

module add
#(
    parameter int WIDTH                 = 4
)
(
    input   wire                        i_carry,
    input   wire[WIDTH-1:0]             i_op1,
    input   wire[WIDTH-1:0]             i_op2,
    output  wire[WIDTH-1:0]             o_add,
    output  wire                        o_carry
);

    logic[WIDTH:0] add;

    assign  add      = i_op1 + i_op2 + { {(WIDTH-1){1'b0}}, i_carry };

    assign  o_add   = add[WIDTH-1:0];
    assign  o_carry = add[WIDTH];

endmodule
