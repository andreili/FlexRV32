`timescale 1ps/1ps

module rv_fetch_buf
#(
    parameter int WIDTH                 = 8,
    parameter int DEPTH_BITS            = 2
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[WIDTH-1:0]             i_data_lo,
    input   wire[WIDTH-1:0]             i_data_hi,
    input   wire                        i_push_single,
    input   wire                        i_push_double,
    output  wire[WIDTH-1:0]             o_data_lo,
    output  wire[WIDTH-1:0]             o_data_hi,
    input   wire                        i_pop_single,
    input   wire                        i_pop_double,
    output  wire                        o_empty,
    output  wire                        o_full
);

    localparam int QSize = 2 ** DEPTH_BITS;

    logic[DEPTH_BITS:0] delta_pop, delta_push;
    logic[DEPTH_BITS:0] head, head_next;
    logic[WIDTH-1:0]    data_lo;

    assign  delta_pop = { {(DEPTH_BITS){(i_pop_double | i_pop_single)}},
                          ((!i_pop_double) & i_pop_single) };
    assign  delta_push = { {(DEPTH_BITS-1){1'b0}}, i_push_double, i_push_single };
    assign  head_next = (!i_reset_n) ? '0 :
                    head + delta_pop + delta_push;
    always_ff @(posedge i_clk)
    begin
        head <= head_next;
    end

    logic   is_comp;
    logic   empty;
    logic   full;

    assign  is_comp = (data_lo[1:0] != 2'b11);
    assign  empty = (is_comp & (head == 0)) | (!is_comp & (head < 2));
    assign  full = (int'(head) >= (QSize - 2));

    logic[WIDTH-1:0]      data[QSize];

    generate
        genvar i;
        for (i=0 ; i<QSize ; ++i)
        begin : g_data
            logic   update_lo_word;
            logic   update_hi_word;
            assign  update_hi_word = ((i_push_single & (head_next==(i+1))) |
                                      (i_push_double & (head_next==(i+1))));
            assign  update_lo_word = (i_push_double & (head_next==(i+2)));
            logic[WIDTH-1:0] buf_p1;
            logic[WIDTH-1:0] buf_p2;
            logic[WIDTH-1:0] next;
            assign  buf_p1 = (i>=(8-1)) ? '0 : data[i + 1];
            assign  buf_p2 = (i>=(8-2)) ? '0 : data[i + 2];
            assign  next   = update_hi_word ? i_data_hi :
                             update_lo_word ? i_data_lo :
                             i_pop_single ? buf_p1 :
                             buf_p2;

            always_ff @(posedge i_clk)
            begin
                if (!i_reset_n)
                    data[i] <= '0;
                else if (update_hi_word | update_lo_word | i_pop_single | i_pop_double)
                    data[i] <= next;
            end
        end
    endgenerate

    assign  data_lo   = data[0];

    assign  o_data_lo = data_lo;
    assign  o_data_hi = data[1];
    assign  o_empty = empty;
    assign  o_full = full;

endmodule
