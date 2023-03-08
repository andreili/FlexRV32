`timescale 1ps/1ps

module reg_e
(
    input   wire        CLK,
    input   wire        D,
    input   wire        DE,
    output  wire        Q
);

    logic r;

    always_ff @(posedge CLK)
    begin
        r <= DE ? D : r;
    end

    assign Q = r;

endmodule
