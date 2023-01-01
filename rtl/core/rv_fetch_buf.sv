`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_buf
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_pc_select,
    input   wire                        i_ack,
    input   wire                        i_decode_ready,
    input   wire[31:0]                  i_data,
    input   wire                        i_fetch_pc1,
    input   wire[31:0]                  i_fetch_pc_next,
    output  wire                        o_free_dword_or_more,
    output  wire[31:0]                  o_pc_incr,
    output  wire[31:0]                  o_pc,
    output  wire[31:0]                  o_instruction
);

    logic[`INSTR_BUF_SIZE_BITS-1:0] buffer[`INSTR_BUF_SIZE];
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt;
    logic[`INSTR_BUF_ADDR_SIZE:0] cnt;
    logic   nearfull;
    logic   full;
    logic   free_dword_or_more;
    logic   empty;
    logic[31:0] pc;

    assign  free_dword_or_more  = (free_cnt_next > 1);
    assign  nearfull     = (free_cnt == 1);
    assign  full         = !(|free_cnt);
    assign  empty        = free_cnt[`INSTR_BUF_ADDR_SIZE];

    logic[1:0]  instr_type;
    logic       instr_comp;

    assign  instr_type = i_data[1:0];
    assign  instr_comp = !(&instr_type);

    logic   push_double_word;
    logic   push_word;
    logic   pop_double_word;
    logic   pop_word;

    assign  push_double_word = i_ack & (!full) & (!nearfull) & (!i_fetch_pc1);
    assign  push_word        = i_ack & (!full) & instr_comp & i_fetch_pc1;
    assign  pop_double_word  = move & (!out_comp) & (!empty);
    assign  pop_word         = move & out_comp & (!empty);

    logic[`INSTR_BUF_SIZE_BITS-1:0] next[`INSTR_BUF_SIZE];
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_delta1;
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_delta2;
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_delta3;
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_delta4;
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_delta;
    logic[`INSTR_BUF_ADDR_SIZE:0] free_cnt_next;
    logic[31:0] pc_next;

    //assign  next = { buffer[3], buffer[1], i_data[31:16], i_data[15:0] };
    assign  next[0] = ((!i_reset_n) | i_pc_select) ? '0 :
                        (push_word & (free_cnt==4)) ? i_data[31:16] :
                        (push_double_word & (free_cnt==4)) ? i_data[15:0] :
                        pop_word ? buffer[1] :
                        pop_double_word ? buffer[2] :
                        buffer[0];
    //assign  next[1] = ((!i_reset_n) | i_pc_select) ? '0 : i_data[31:16];
    assign  next[1] = ((!i_reset_n) | i_pc_select) ? '0 :
                        (push_word & (free_cnt==3)) ? i_data[31:16] :
                        (push_double_word & empty) ? i_data[31:16] :
                        (push_double_word & (free_cnt==3)) ? i_data[15:0] :
                        pop_word ? buffer[2] :
                        pop_double_word ? buffer[3] :
                        buffer[1];
    assign  next[2] = ((!i_reset_n) | i_pc_select) ? '0 :
                        (push_word & (free_cnt==2)) ? i_data[31:16] :
                        (push_double_word & (free_cnt==3)) ? i_data[31:16] :
                        (push_double_word & (free_cnt==2)) ? i_data[15:0] :
                        pop_word ? buffer[3] :
                        pop_double_word ? '0 :
                        buffer[2];
    assign  next[3] = ((!i_reset_n) | i_pc_select) ? '0 :
                        (push_word & (free_cnt==1)) ? i_data[31:16] :
                        (push_double_word & (free_cnt==2)) ? i_data[31:16] :
                        (push_double_word & (free_cnt==1)) ? i_data[15:0] :
                        (pop_word | pop_double_word) ? '0 :
                        buffer[3];
    assign  pc_next = ((!i_reset_n) | i_pc_select) ? i_fetch_pc_next :
                                (pop_double_word) ? pc + 4 :
                                (pop_word) ? pc + 2 :
                                pc;
    assign  free_cnt_delta1 = push_double_word ? -2 : '0;
    assign  free_cnt_delta2 = push_word ? -1 : '0;
    assign  free_cnt_delta3 = pop_double_word ? 2 : '0;
    assign  free_cnt_delta4 = pop_word ? 1 : '0;
    assign  free_cnt_delta =  (free_cnt_delta1 + free_cnt_delta2 +
                                         free_cnt_delta3 + free_cnt_delta4);
    assign  free_cnt_next = ((!i_reset_n) | i_pc_select) ? `INSTR_BUF_SIZE :
                                        free_cnt + free_cnt_delta;

    always_ff @(posedge i_clk)
    begin
        buffer <= next;
        free_cnt <= free_cnt_next;
        cnt <= `INSTR_BUF_SIZE - free_cnt_next;
        pc <= pc_next;
    end

    logic       move;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            move <= '0;
        else
            move <= i_decode_ready & have_valid_instr;
    end

    logic[1:0]  out_type;
    logic       out_comp;
    logic       have_valid_instr;
    assign  out_type = buffer[0][1:0];
    assign  out_comp = !(&out_type);
    assign  have_valid_instr = (out_comp & (!empty)) | ((!out_comp) & (cnt > 1));

    assign  o_pc_incr = (empty & instr_comp & i_fetch_pc1) ? 2 : 4;
    assign  o_free_dword_or_more = free_dword_or_more;

    assign  o_pc = pc;
    assign  o_instruction = move ? {buffer[1], buffer[0] } : '0;

endmodule
