`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_branch_pred
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter int TABLE_SIZE_BITS       = 4
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_current,
    input   wire                        i_pc_select,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_branch,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_target,
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc_new,
    output  wire                        o_pc_predicted
);

    localparam int TABLE_SIZE = 2 ** TABLE_SIZE_BITS;
    localparam int VALID_SIZE = TABLE_SIZE;

    logic[IADDR_SPACE_BITS-1:0] tb_pc_cur[TABLE_SIZE];
    logic[IADDR_SPACE_BITS-1:0] tb_pc_tar[TABLE_SIZE];
    logic[(VALID_SIZE*TABLE_SIZE-1):0]  tb_valid;

    logic[TABLE_SIZE_BITS-1:0]  tb_free_idx;
    logic[TABLE_SIZE_BITS-1:0]  tb_same_idx;
    logic[TABLE_SIZE_BITS-1:0]  tb_win_idx;
    logic                       tb_win_valid;
    logic[(TABLE_SIZE_BITS*TABLE_SIZE-1):0] tb_idx;
    logic                       tb_is_update;
    logic                       tb_have_same;

    genvar i;
    generate
        for (i=0 ; i<TABLE_SIZE ; i++)
        begin : g_idx
            assign tb_idx[(i * TABLE_SIZE_BITS)+:TABLE_SIZE_BITS] = i;
        end
    endgenerate

/* verilator lint_off PINCONNECTEMPTY */
    min_idx
    #(
        .ELEMENT_WIDTH                  (VALID_SIZE),
        .INDEX_WIDTH                    (TABLE_SIZE_BITS),
        .ELEMENT_COUNT                  (TABLE_SIZE)
    )
    u_min
    (
        .i_elements                     (tb_valid),
        .i_idx                          (tb_idx),
        .o_min_val                      (),
        .o_min_idx                      (tb_free_idx)
    );
/* verilator lint_on PINCONNECTEMPTY */

    generate
        for (i=0 ; i<TABLE_SIZE ; i++)
        begin : g_btb
            logic[(VALID_SIZE-1):0] valid_cur;
            logic[(VALID_SIZE-2):0] valid_prev;
            logic      have_entry;
            logic      to_update;
            logic      is_predicted;

            assign valid_cur  = tb_valid[(i*VALID_SIZE)+:VALID_SIZE];
            assign valid_prev = (i_pc_branch == tb_pc_cur[i]) ? valid_cur[VALID_SIZE-1:1] : '0;

            always_ff @(posedge i_clk)
            begin
                if (!i_reset_n)
                begin
                    tb_pc_cur[i] <= '0;
                    tb_pc_tar[i] <= '0;
                    tb_valid[(i*VALID_SIZE)+:VALID_SIZE] <= '0;
                end
                else if (to_update)
                begin
                    tb_pc_cur[i] <= i_pc_branch;
                    tb_pc_tar[i] <= i_pc_target;
                    tb_valid[(i*VALID_SIZE)+:VALID_SIZE] <= { 1'b1, valid_prev };
                end
                else if (tb_is_update)
                begin
                    tb_valid[(i*VALID_SIZE)+:VALID_SIZE] <= { 1'b0,
                        tb_valid[(i*VALID_SIZE+1)+:(VALID_SIZE-1)] };
                end
            end

            assign to_update = ((i == tb_free_idx) & (!tb_have_same) & i_pc_select) |
                (i_pc_select & tb_have_same & (i == tb_same_idx));
            assign is_predicted = ((|valid_cur) & (tb_pc_cur[i] == i_pc_current));
            assign tb_is_update = (to_update & (tb_pc_tar[i] != i_pc_target)) ? '1 : 'z;
            assign tb_win_idx = is_predicted ? i : 'z;
            assign tb_win_valid = is_predicted ? '1 : 'z;

            assign have_entry = ((|valid_cur) & (tb_pc_cur[i] == i_pc_branch));
            assign tb_same_idx = have_entry ? i : 'z;
            assign tb_have_same = have_entry ? '1 : 'z;
        end
    endgenerate

    assign  o_pc_new = tb_pc_tar[tb_win_idx];
    assign  o_pc_predicted = tb_win_valid;

endmodule
