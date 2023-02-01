`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_branch_pred
#(
    parameter IADDR_SPACE_BITS          = 32,
    parameter TABLE_SIZE_BITS           = 4
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

    localparam  TABLE_SIZE = 2 ** TABLE_SIZE_BITS;

    logic[IADDR_SPACE_BITS-1:0] tb_pc_cur[TABLE_SIZE];
    logic[IADDR_SPACE_BITS-1:0] tb_pc_tar[TABLE_SIZE];
    logic[2:0]                  tb_valid [TABLE_SIZE];

    logic[TABLE_SIZE_BITS-1:0]  tb_free_idx;
    logic[TABLE_SIZE_BITS-1:0]  tb_win_idx;
    logic                       tb_win_valid;

    assign  tb_free_idx = '0; // TODO - buuble(?) sorting by valid table

    generate
        genvar i;
        for (i=0 ; i<TABLE_SIZE ; ++i)
        begin : btb
            logic[1:0] valid_prev;
            logic      is_predicted;

            assign valid_prev = (i_pc_branch == tb_pc_cur[i]) ? tb_valid[i][2:1] : '0;

            always_ff @(posedge i_clk)
            begin
                if (!i_reset_n)
                begin
                    tb_pc_cur[i] <= '0;
                    tb_pc_tar[i] <= '0;
                    tb_valid [i] <= '0;
                end
                else if ((i == tb_free_idx) & i_pc_select)
                begin
                    tb_pc_cur[i] <= i_pc_branch;
                    tb_pc_tar[i] <= i_pc_target;
                    tb_valid [i] <= { 1'b1, valid_prev };
                end
            end

            assign is_predicted = ((|tb_valid[i]) & (tb_pc_cur[i] == i_pc_current));
            assign tb_win_idx = is_predicted ? i : 'z;
            assign tb_win_valid = is_predicted ? '1 : 'z;
        end
    endgenerate

    assign  o_pc_new = tb_pc_tar[tb_win_idx];
    assign  o_pc_predicted = tb_win_valid;

endmodule
