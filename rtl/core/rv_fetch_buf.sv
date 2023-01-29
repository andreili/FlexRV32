`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_buf
#(
    parameter   INSTR_BUF_ADDR_SIZE = 2
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_flush,
    input   wire                        i_stall,
    input   wire                        i_ack,
    input   wire[31:0]                  i_data,
    input   wire                        i_fetch_pc1,
    input   wire[31:0]                  i_fetch_pc_prev,
    input   wire                        i_branch_pred,
    input   wire                        i_branch_pred_prev,
    output  wire                        o_free_dword_or_more,
    output  wire[31:0]                  o_pc_incr,
    output  wire[31:0]                  o_pc,
    output  wire[31:0]                  o_instruction,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);

    logic       full;
    logic       empty;
    logic       push_double_word;
    logic       push_word;
    logic       pop_double_word;
    logic       pop_word;
    logic       move;
    logic       have_valid_instr;
    logic       has_double;
    logic[47:0] idata_lo, idata_hi;
    logic[47:0] odata_lo, odata_hi;

    assign  push_double_word = (!i_branch_pred_prev) & i_ack & (!i_fetch_pc_prev[1]);
    assign  push_word        = (!i_branch_pred_prev) & i_ack & i_fetch_pc_prev[1];
    assign  pop_double_word  = move & (&odata_lo[1:0]) & (!empty);
    assign  pop_word         = move & (!(&odata_lo[1:0])) & (!empty);

    assign  idata_lo = i_fetch_pc_prev[1] ? { i_branch_pred, i_fetch_pc_prev[31:2], 1'b1, i_data[31:16] } :
                                            { i_branch_pred, i_fetch_pc_prev[31:2], 1'b0, i_data[15: 0] };
    assign  idata_hi = { i_branch_pred, i_fetch_pc_prev[31:2], 1'b1, i_data[31:16] };

    assign  move = i_reset_n & have_valid_instr & (!i_stall);

    assign  have_valid_instr = ((!(&odata_lo[1:0])) & (!empty)) | ((!(!(&odata_lo[1:0]))) & has_double);

    fifo_dual
    #(
        .WIDTH                          (16+31+1),
        .DEPTH_BITS                     (INSTR_BUF_ADDR_SIZE)
    )
    u_fifo
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n & (!i_flush)),
        .i_data0                        (idata_lo),
        .i_data1                        (idata_hi),
        .i_push_single                  (push_word),
        .i_push_double                  (push_double_word),
        .o_data0                        (odata_lo),
        .o_data1                        (odata_hi),
        .i_pop_single                   (pop_word),
        .i_pop_double                   (pop_double_word),
        .o_empty                        (empty),
        .o_has_double                   (has_double),
        .o_full                         (full)
    );

    assign  o_free_dword_or_more = (!full);
    assign  o_pc_incr = (empty & i_fetch_pc1) ? 2 : 4;
    assign  o_pc = { odata_lo[46:16], 1'b0 };
    assign  o_instruction = { odata_hi[15:0], odata_lo[15:0] };
    assign  o_branch_pred = odata_lo[47];
    assign  o_ready = have_valid_instr;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_fetch_pc_prev[0] | (|odata_hi[47:16]);
/* verilator lint_on UNUSEDSIGNAL */

    /*logic[INSTR_BUF_SIZE_BITS-1:0] next[INSTR_BUF_SIZE];
    logic[32:0]                    next_addr[INSTR_BUF_SIZE];
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta_push;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next_pop;

    assign  free_cnt_delta_push = { {(INSTR_BUF_ADDR_SIZE){(push_double_word | push_word)}}, ((!push_double_word) & push_word) };
    assign  free_cnt_next_pop = free_cnt + { 1'b0, pop_double_word, pop_word };
    assign  free_cnt_next =  (free_cnt_next_pop + free_cnt_delta_push);

    genvar  i;
    generate
        for (i=0 ; i<INSTR_BUF_SIZE ; i++)
        begin : gen_buf
            logic   update_lo_word;
            logic   update_hi_word;
            assign  update_hi_word = ((push_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i))) |
                                      (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i+1))));
            assign  update_lo_word = (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i)));
            logic[15:0] buf_p1;
            logic[15:0] buf_p2;
            assign  buf_p1 = (i>=(INSTR_BUF_SIZE-1)) ? '0 : buffer[i + 1];
            assign  buf_p2 = (i>=(INSTR_BUF_SIZE-2)) ? '0 : buffer[i + 2];
            logic[32:0] addr_p1;
            logic[32:0] addr_p2;
            assign  addr_p1 = (i>=(INSTR_BUF_SIZE-1)) ? '0 : buffer_addr[i + 1];
            assign  addr_p2 = (i>=(INSTR_BUF_SIZE-2)) ? '0 : buffer_addr[i + 2];
            assign  next[i] = update_hi_word ? i_data[31:16] :
                              update_lo_word ? i_data[15:0] :
                              pop_word ? buf_p1 :
                              buf_p2;
            assign  next_addr[i] = (update_hi_word & (!i_fetch_pc_prev[1])) ? { i_branch_pred, fetch_pc_p2 } :
                                (update_lo_word | i_fetch_pc_prev[1]) ? { i_branch_pred, i_fetch_pc_prev } :
                                pop_word ? addr_p1 :
                                addr_p2;
            always_ff @(posedge i_clk)
            begin
                if ((!i_reset_n) | i_flush)
                begin
                    buffer[i] <= '0;
                    buffer_addr[i] <= '0;
                end
                else if (update_hi_word | update_lo_word | pop_word | pop_double_word)
                begin
                    buffer[i] <= next[i];
                    buffer_addr[i] <= next_addr[i];
                end
            end
        end
    endgenerate

    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | i_flush)
        begin
            free_cnt <= INSTR_BUF_SIZE;
            cnt <= '0;
        end
        else
        begin
            free_cnt <= free_cnt_next;
            cnt <= INSTR_BUF_SIZE - free_cnt_next;
        end
    end

    logic   move;
    assign  move = i_reset_n & have_valid_instr & (!i_stall);
    assign  fetch_pc_p2 = i_fetch_pc_prev + 32'd2;

    logic       have_valid_instr;
    assign  have_valid_instr = ((!(&buffer[0][1:0])) & (!empty)) | ((!(!(&buffer[0][1:0]))) & (cnt > 1));

    assign  o_pc_incr = (empty & i_fetch_pc1) ? 2 : 4;
    assign  o_free_dword_or_more = free_dword_or_more;

    assign  o_pc = buffer_addr[0][31:0];
    assign  o_branch_pred = buffer_addr[0][32];
    assign  o_instruction = (move & (!(i_flush | i_stall))) ? { buffer[1], buffer[0] } : '0;
    assign  o_ready = have_valid_instr;*/

endmodule
