`timescale 1ps/1ps

module reg_s
(
    input   wire        CLK,
    input   wire        D,
    output  wire        Q
);

    sky130_fd_sc_hd__dfxtp_1
    r_bit
    (
        .Q      (Q),
        .CLK    (CLK),
        .D      (D),
    );

endmodule
