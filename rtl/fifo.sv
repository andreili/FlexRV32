`timescale 1ps/1ps

module fifo
#(
    parameter WIDTH                     = 8,
    parameter DEPTH_BITS                = 2
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[WIDTH-1:0]             i_data,
    input   wire                        i_push,
    output  wire[WIDTH-1:0]             o_data,
    input   wire                        i_pop,
    output  wire                        o_empty,
    output  wire                        o_full
);

    logic[WIDTH-1:0] data[2**DEPTH_BITS];

    logic[DEPTH_BITS:0] head, tail, head_next, tail_next;
    logic   empty, full;

    assign  head_next = head + 2'd1;
    assign  tail_next = tail + 2'd1;
    assign  empty = (head == tail);
    assign  full = ((head_next == tail_next) &
                    (head_next[DEPTH_BITS] != tail_next[DEPTH_BITS]));

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            head  <= '0;
        else if (i_push)
            head <= head_next;
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            tail  <= '0;
        else if (i_pop)
            tail <= tail_next;
    end

    always_ff @(posedge i_clk)
    begin
        if (i_push)
            data[head[DEPTH_BITS-1:0]] <= i_data;
    end

    assign  o_data = data[tail[DEPTH_BITS-1:0]];
    assign  o_empty = empty;
    assign  o_full = full;

endmodule
