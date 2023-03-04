`timescale 1ps/1ps

module pc_sel
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter logic BRANCH_PREDICTION   = 1
)
(
    input   wire                        i_cmp,
    input   wire                        i_branch_pred,
    input   wire                        i_inst_jal_jalr,
    input   wire                        i_inst_branch,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_target,
    output  wire                        o_pc_select,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_target
);

    logic       pc_select, pred_ok;
    logic[IADDR_SPACE_BITS-1:1] pc_out;
    assign      pred_ok = (i_pc_target == i_pc);
    assign      pc_select = (i_inst_jal_jalr | (i_inst_branch & (i_cmp))) ^
                            (i_branch_pred & pred_ok & BRANCH_PREDICTION);
    assign      pc_out = (i_branch_pred & pred_ok) ? i_pc_next : i_pc_target;

    assign  o_pc_select = pc_select;
    assign  o_pc_target = pc_out;

endmodule
