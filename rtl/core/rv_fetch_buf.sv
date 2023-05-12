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
    logic   not_full;

    logic[WIDTH-1:0]    data[QSize];
    logic[QSize:0]      is_head;

    assign  not_full  = !(is_head[QSize] |
                          !(!is_head[QSize-1] | !i_push | pop)
                         );
    assign  pop       = !(i_stall | is_head[0]);

    logic  latch_dn, latch_up;
    logic  latch_m_dn, latch_m_up;
    
    assign latch_dn = !(!(pop & !pc[1]) &
                        !(pop & !(hi_valid & is_comp))
                       );
    assign latch_up =   !(pop & !pc[1]) & i_push;
    assign latch_m_dn = !(!latch_dn |  i_push);
    assign latch_m_up = !( latch_dn | !i_push);

    // 0
    logic  is_head_next_0;
    assign is_head_next_0 = !(i_reset_n &
                              !( latch_m_dn & is_head[1]) &
                              !(!latch_m_up & is_head[0])
                             );
    always_ff @(posedge i_clk)
    begin
        is_head[0] <= is_head_next_0;
    end

    generate
        genvar i;
        for (i=0 ; i<QSize ; i++)
        begin : g_data
            logic  h_next, h_move;
            logic  d_latch_new, d_move;
            logic[31:0] d_next;
            if (i == (QSize-1))
            begin
                assign h_move = !(i_reset_n & !latch_m_dn & !(latch_m_up & is_head[i + 0]));
                assign h_next = !(!i_reset_n | latch_m_dn | !is_head[i]);
                assign d_next = {32{d_latch_new}} & i_data;
            end
            else
            begin
                assign h_move = !(i_reset_n & !latch_m_dn & !latch_m_up);
                assign h_next = !(!i_reset_n |
                                  !(
                                    ( latch_m_dn & is_head[i + 2]) |
                                    (!latch_m_dn & is_head[i])
                                   )
                                 );
                assign d_next = d_latch_new ? i_data : data[i + 1];
            end
            assign d_latch_new = !(
                                   !(is_head[i + 1] & latch_dn) &
                                   !(is_head[i + 0] & latch_up)
                                  );
            assign d_move = !(!d_latch_new & !latch_dn);

            always_ff @(posedge i_clk)
            begin
                if (h_move)
                    is_head[i + 1] <= h_next;
                if (d_move)
                    data[i] <= d_next;
            end
        end
    endgenerate

    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_incr;
    logic[IADDR_SPACE_BITS-1:1] pc_add;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic                       pc_update;

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
        .o_add                          (pc_add),
        .o_carry                        ()
    );
/* verilator lint_on  PINCONNECTEMPTY */

    assign pc_update = !(i_reset_n & !(pop & !first_half));
    assign pc_next = i_reset_n ? pc_add : i_pc;

    always_ff @(posedge i_clk)
    begin
        if (pc_update)
            pc <= pc_next;
    end

    logic       half_aligned_access;
    logic[15:0] data_lo, data_hi, latch_hi;
    logic       hi_update, hi_next, hi_valid;
    logic       first_half;

    assign hi_update = !( i_reset_n & !(i_push & pop));
    assign hi_next   = !(!i_reset_n | is_head[0]);

    always_ff @(posedge i_clk)
    begin
        if (pop)
            latch_hi <= data[0][31:16];
        if (hi_update)
            hi_valid <= hi_next;
        first_half <= !(!is_head[0] | !pc[1] | hi_valid);
    end

    assign  half_aligned_access = pc[1];
    assign  data_lo = half_aligned_access ? latch_hi      : data[0][15: 0];
    assign  data_hi = half_aligned_access ? data[0][15:0] : data[0][31:16];
    assign  is_comp = !(data_lo[1] & data_lo[0]);

    assign  o_data = { data_hi, data_lo };
    assign  o_pc = pc;
    assign  o_pc_next = pc_next;
    assign  o_not_empty = !(is_head[0] | first_half);
    assign  o_not_full = not_full;

endmodule
