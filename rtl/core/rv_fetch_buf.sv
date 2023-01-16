`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_buf
#(
    parameter   INSTR_BUF_ADDR_SIZE = 2
)
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
    output  wire[31:0]                  o_instruction,
    output  wire                        o_ready
);

    localparam  INSTR_BUF_SIZE =  (2 ** INSTR_BUF_ADDR_SIZE);
    localparam  INSTR_BUF_SIZE_BITS =  16;

    logic[INSTR_BUF_SIZE_BITS-1:0] buffer[INSTR_BUF_SIZE];
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt;
    logic[INSTR_BUF_ADDR_SIZE:0] cnt;
    logic   nearfull;
    logic   full;
    logic   free_dword_or_more;
    logic   empty;
    logic[31:0] pc;

    assign  free_dword_or_more  = (free_cnt_next > 1);
    assign  nearfull     = (free_cnt == 1);
    assign  full         = !(|free_cnt);
    assign  empty        = free_cnt[INSTR_BUF_ADDR_SIZE];

    logic   fetch_pc1;
    logic   push_double_word;
    logic   push_word;
    logic   pop_double_word;
    logic   pop_word;

    assign  push_double_word = i_ack & (!full) & (!nearfull) & (!fetch_pc1);
    assign  push_word        = i_ack & (!full) & fetch_pc1;
    assign  pop_double_word  = move & (!out_comp) & (!empty);
    assign  pop_word         = move & out_comp & (!empty);

    logic[INSTR_BUF_SIZE_BITS-1:0] next[INSTR_BUF_SIZE];
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta1;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta2;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta3;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta4;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta_push;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_delta_pop;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next;
    logic[INSTR_BUF_ADDR_SIZE:0] free_cnt_next_pop;
    logic[31:0] pc_next;

    assign  pc_next = ((!i_reset_n) | i_pc_select) ? i_fetch_pc_next :
                                (pop_double_word) ? pc + 4 :
                                (pop_word) ? pc + 2 :
                                pc;
    assign  free_cnt_delta1 = push_double_word ? -2 : '0;
    assign  free_cnt_delta2 = push_word ? -1 : '0;
    assign  free_cnt_delta3 = pop_double_word ? 2 : '0;
    assign  free_cnt_delta4 = pop_word ? 1 : '0;
    assign  free_cnt_delta_push = free_cnt_delta1 + free_cnt_delta2;
    assign  free_cnt_delta_pop  = free_cnt_delta3 + free_cnt_delta4;
    assign  free_cnt_next_pop = free_cnt + free_cnt_delta_pop;
    assign  free_cnt_next = ((!i_reset_n) | i_pc_select) ? INSTR_BUF_SIZE :
                                        (free_cnt_next_pop + free_cnt_delta_push);

    genvar  i;
    generate
        for (i=0 ; i<INSTR_BUF_SIZE ; i++)
        begin : gen_buf
            logic   update_1_word;
            logic   update_2_word;
            assign  update_2_word = (push_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i))) |
                                    (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i+1)));
            assign  update_1_word = (push_double_word & (free_cnt_next_pop==(INSTR_BUF_SIZE-i)));
            logic[15:0] buf_p1;
            logic[15:0] buf_p2;
            assign  buf_p1 = (i>=(INSTR_BUF_SIZE-1)) ? '0 : buffer[i + 1];
            assign  buf_p2 = (i>=(INSTR_BUF_SIZE-2)) ? '0 : buffer[i + 2];
            assign  next[i] = ((!i_reset_n) | i_pc_select) ? '0 :
                                update_2_word ? i_data[31:16] :
                                update_1_word ? i_data[15:0] :
                                pop_word ? buf_p1 :
                                buf_p2;
            always_ff @(posedge i_clk)
            begin
                if ((!i_reset_n) | i_pc_select)
                    buffer[i] <= '0;
                else if (update_2_word | update_1_word | pop_word | pop_double_word)
                    buffer[i] <= next[i];
            end
        end
    endgenerate

    always_ff @(posedge i_clk)
    begin
        fetch_pc1 <= i_fetch_pc1;
        free_cnt <= free_cnt_next;
        cnt <= INSTR_BUF_SIZE - free_cnt_next;
        pc <= pc_next;
    end

    logic       move;
    logic       decode_ready;

    always_ff @(posedge i_clk)
    begin
        decode_ready <= i_decode_ready;
        if (!i_reset_n)
            move <= '0;
        else
            move <= decode_ready & have_valid_instr;
    end

    logic[1:0]  out_type;
    logic       out_comp;
    logic       have_valid_instr;
    assign  out_type = buffer[0][1:0];
    assign  out_comp = !(&out_type);
    assign  have_valid_instr = (out_comp & (!empty)) | ((!out_comp) & (cnt > 1));

    assign  o_pc_incr = (empty /*& instr_comp*/ & i_fetch_pc1) ? 2 : 4;
    assign  o_free_dword_or_more = free_dword_or_more;

    assign  o_pc = pc;
    //assign  o_instruction = move ? {buffer[1], buffer[0] } : '0;
    assign  o_instruction[31:16] = (move & (!out_comp)) ? buffer[1] : '0;
    assign  o_instruction[15: 0] = move ? buffer[0] : '0;
    assign  o_ready = have_valid_instr;

endmodule
