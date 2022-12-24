`timescale 1ps/1ps

module debounce
#(
    parameter   LENGTH = 6,
    parameter   ACTIVE_LEVEL = 1'b0
)
(
    input   wire                        i_clk,
    input   wire                        i_sig,
    output  wire                        o_sig
);

    logic   r_prev;
    logic[LENGTH:0] r_cnt;
    logic   w_lact_seg;
    logic   r_out;

    assign  w_lact_seg = r_cnt[LENGTH];

    always_ff @(posedge i_clk)
    begin
        r_prev <= i_sig;
    end

    always_ff @(posedge i_clk)
    begin
        if ((r_prev != i_sig) || (i_sig == ACTIVE_LEVEL))
            r_cnt <= '0;
        else if (!w_lact_seg)
            r_cnt <= r_cnt + 1'b1;
    end

    always_ff @(posedge i_clk)
    begin
        r_out <= w_lact_seg;
    end

    assign  o_sig = r_out;

endmodule
