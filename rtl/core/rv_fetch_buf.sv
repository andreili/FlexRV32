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
    input   wire                        i_pc_select,
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

    localparam  INSTR_BUF_SIZE =  (2 ** INSTR_BUF_ADDR_SIZE);
    localparam  INSTR_BUF_SIZE_BITS =  16;

    logic[INSTR_BUF_SIZE_BITS-1:0] buffer[INSTR_BUF_SIZE];
    logic[32:0] buffer_addr[INSTR_BUF_SIZE];
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt;
    logic[INSTR_BUF_ADDR_SIZE:0] cnt;
    logic   nearfull;
    logic   full;
    logic   free_dword_or_more;
    logic   empty;

    assign  free_dword_or_more  = (free_cnt_next > 1);
    assign  nearfull     = (free_cnt == 1);
    assign  full         = !(|free_cnt);
    assign  empty        = free_cnt[INSTR_BUF_ADDR_SIZE];

    logic[31:0] fetch_pc_p2;
    logic       push_double_word;
    logic       push_word;
    logic       pop_double_word;
    logic       pop_word;

    assign  push_double_word = (!i_branch_pred_prev) & i_ack & (!full) & (!nearfull) & (!i_fetch_pc_prev[1]);
    assign  push_word        = (!i_branch_pred_prev) & i_ack & (!full) & i_fetch_pc_prev[1];
    assign  pop_double_word  = move & (!out_comp) & (!empty);
    assign  pop_word         = move & out_comp & (!empty);

    logic[INSTR_BUF_SIZE_BITS-1:0] next[INSTR_BUF_SIZE];
    logic[32:0]                    next_addr[INSTR_BUF_SIZE];
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta1;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta2;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta3;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta4;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta_push;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta_pop;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next_pop;

    assign  free_cnt_delta1 = push_double_word ? -2 : '0;
    assign  free_cnt_delta2 = push_word ? -1 : '0;
    assign  free_cnt_delta3 = pop_double_word ? 2 : '0;
    assign  free_cnt_delta4 = pop_word ? 1 : '0;
    assign  free_cnt_delta_push = free_cnt_delta1 + free_cnt_delta2;
    assign  free_cnt_delta_pop  = free_cnt_delta3 + free_cnt_delta4;
    assign  free_cnt_next_pop = free_cnt + free_cnt_delta_pop;
    assign  free_cnt_next = ((!i_reset_n) | i_pc_select | i_flush) ? INSTR_BUF_SIZE :
                                        (free_cnt_next_pop + free_cnt_delta_push);

    genvar  i;
    generate
        for (i=0 ; i<INSTR_BUF_SIZE ; i++)
        begin : gen_buf
            logic   update_1_word;
            logic   update_2_word;
            assign  update_2_word = ((push_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i))) |
                                    (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i+1))));
            assign  update_1_word = (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i)));
            logic[15:0] buf_p1;
            logic[15:0] buf_p2;
            assign  buf_p1 = (i>=(INSTR_BUF_SIZE-1)) ? '0 : buffer[i + 1];
            assign  buf_p2 = (i>=(INSTR_BUF_SIZE-2)) ? '0 : buffer[i + 2];
            logic[32:0] addr_p1;
            logic[32:0] addr_p2;
            assign  addr_p1 = (i>=(INSTR_BUF_SIZE-1)) ? '0 : buffer_addr[i + 1];
            assign  addr_p2 = (i>=(INSTR_BUF_SIZE-2)) ? '0 : buffer_addr[i + 2];
            assign  next[i] = ((!i_reset_n) | i_pc_select) ? '0 :
                                update_2_word ? i_data[31:16] :
                                update_1_word ? i_data[15:0] :
                                pop_word ? buf_p1 :
                                buf_p2;
            assign  next_addr[i] = (update_2_word & (!i_fetch_pc_prev[1])) ? { i_branch_pred, fetch_pc_p2 } :
                                (update_1_word | i_fetch_pc_prev[1]) ? { i_branch_pred, i_fetch_pc_prev } :
                                pop_word ? addr_p1 :
                                addr_p2;
            always_ff @(posedge i_clk)
            begin
                if ((!i_reset_n) | i_pc_select)
                begin
                    buffer[i] <= '0;
                    buffer_addr[i] <= '0;
                end
                else if (update_2_word | update_1_word | pop_word | pop_double_word)
                begin
                    buffer[i] <= next[i];
                    buffer_addr[i] <= next_addr[i];
                end
            end
        end
    endgenerate

    always_ff @(posedge i_clk)
    begin
        free_cnt <= free_cnt_next;
        cnt <= INSTR_BUF_SIZE - free_cnt_next;
    end

    logic   move;
    assign  move = i_reset_n & have_valid_instr & (!i_stall);
    assign  fetch_pc_p2 = i_fetch_pc_prev + 32'd2;

    logic[1:0]  out_type;
    logic       out_comp;
    logic       have_valid_instr;
    assign  out_type = buffer[0][1:0];
    assign  out_comp = !(&out_type);
    assign  have_valid_instr = (out_comp & (!empty)) | ((!out_comp) & (cnt > 1));

    assign  o_pc_incr = (empty & i_fetch_pc1) ? 2 : 4;
    assign  o_free_dword_or_more = free_dword_or_more;

    assign  o_pc = buffer_addr[0][31:0];
    assign  o_branch_pred = buffer_addr[0][32];
    assign  o_instruction = (move & (!(i_flush | i_stall))) ? { buffer[1], buffer[0] } : '0;
    assign  o_ready = have_valid_instr;

endmodule
