`timescale 1ps/1ps

module rv_fetch_buf
#(
    parameter int IADDR_SPACE_BITS      = 16,
    parameter int WIDTH                 = 32,
    parameter int DEPTH_BITS            = 2
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_stall,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[WIDTH-1:0]             i_data,
    input   wire                        i_push,
    output  wire[WIDTH-1:0]             o_data,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_next,
    output  wire                        o_not_empty,
    output  wire                        o_not_full
);

    localparam int QSize = 2 ** DEPTH_BITS;

    logic   pop;
    logic   is_comp;
    logic   not_empty;
    logic   full;

    logic[WIDTH-1:0]    data[QSize];
    logic[QSize:0]      is_head;

    assign  full      = is_head[QSize] | (is_head[QSize-1] & i_push & !pop);
    assign  not_empty = !is_head[0];
    assign  pop       = (!i_stall) & not_empty;

    logic  latch_dn, latch_up;
    logic  latch_m_dn, latch_m_up;
    
    assign latch_dn = !(!pop | (pc[1] & hi_valid & is_comp));
    assign latch_up = (!pop | (pc[1] & hi_valid)) & i_push;
    assign latch_m_dn = latch_dn & !i_push;
    assign latch_m_up = !latch_dn & i_push;

    // 0
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            is_head[0] <= '1;
        else if (latch_m_dn)
            is_head[0] <= is_head[1];
        else if (latch_m_up)
            is_head[0] <= '0;
    end

    generate
        genvar i;
        for (i=0 ; i<QSize ; i++)
        begin : g_data
            logic  latch_m_up_ex;
            logic  head_next;
            assign latch_m_up_ex = (i == (QSize-1)) ? (latch_m_up & is_head[i + 0]) : latch_m_up;
            assign head_next = (i == (QSize-1)) ? '0 : is_head[i + 2];

            always_ff @(posedge i_clk)
            begin
                if (!i_reset_n)
                    is_head[i + 1] <= '0;
                else if (latch_m_dn)
                    is_head[i + 1] <= head_next;
                else if (latch_m_up_ex)
                    is_head[i + 1] <= is_head[i + 0];
            end

            always_ff @(posedge i_clk)
            begin
                if ((is_head[i + 1] & latch_dn) | (is_head[i + 0] & latch_up))
                    data[i] <= i_data;
                else if (latch_dn)
                    data[i] <= (i == (QSize-1)) ? '0 : data[i + 1];
            end
        end
    endgenerate

    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_incr;
    logic[IADDR_SPACE_BITS-1:1] pc_next;

    assign  pc_incr = is_comp ? 1 : 2;
/* verilator lint_off PINCONNECTEMPTY */
    add
    #(
        .WIDTH                          (IADDR_SPACE_BITS - 1)
    )
    u_pc_inc
    (
        .i_carry                        (1'b0),
        .i_op1                          (pc),
        .i_op2                          (pc_incr),
        .o_add                          (pc_next),
        .o_carry                        ()
    );
/* verilator lint_on  PINCONNECTEMPTY */

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            pc <= i_pc;
        else if (pop & !first_half)
            pc <= pc_next;
    end

    logic       half_aligned_access;
    logic[15:0] data_lo, data_hi, latch_hi;
    logic       hi_valid;
    logic       first_half;

    always_ff @(posedge i_clk)
    begin
        if (pop)
            latch_hi <= data[0][31:16];
        if (!i_reset_n)
            hi_valid <= '0;
        else if (i_push & pop)
            hi_valid <= !is_head[0];
        first_half <= is_head[0] & pc[1] & !hi_valid;
    end

    assign  half_aligned_access = pc[1];
    assign  data_lo = half_aligned_access ? latch_hi      : data[0][15: 0];
    assign  data_hi = half_aligned_access ? data[0][15:0] : data[0][31:16];
    assign  is_comp = (data_lo[1:0] != 2'b11);

    assign  o_data = { data_hi, data_lo };
    assign  o_pc = pc;
    assign  o_pc_next = pc_next;
    assign  o_not_empty = !is_head[0] & !first_half;
    assign  o_not_full = !full;

endmodule
