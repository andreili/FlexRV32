`timescale 1ps/1ps

module reg_s
(
    input   wire        CLK,
    input   wire        D,
    output  wire        Q
);

    logic r;

    always_ff @(posedge CLK)
    begin
        r <= D;
    end

    assign Q = r;

endmodule
