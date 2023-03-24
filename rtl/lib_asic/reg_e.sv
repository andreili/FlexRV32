`timescale 1ps/1ps

module reg_e
(
    input   wire        CLK,
    input   wire        D,
    input   wire        DE,
    output  wire        Q
);

    sky130_fd_sc_hd__edfxtp_1
    r_bit
    (
        .Q      (Q),
        .CLK    (CLK),
        .D      (D),
        .DE     (DE)
    );

endmodule
