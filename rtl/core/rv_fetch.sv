`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter   RESET_ADDR              = 32'h0000_0000,
    parameter   BRANCH_PREDICTION       = 1,
    parameter   INSTR_BUF_ADDR_SIZE     = 2,
    parameter   EXTENSION_C             = 1,
    parameter   EXTENSION_Zicsr         = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   wire[31:0]                  i_pc_target,
    input   wire                        i_pc_select,
    input   wire[31:0]                  i_pc_trap,
    input   wire                        i_ebreak,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    input   wire                        i_ra_invalidate,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_reg_wdata,
    output  wire[31:0]                  o_addr,
    output  wire                        o_cyc,
    output  wire[31:0]                  o_instruction,
    output  wire[31:0]                  o_pc,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);

    logic[31:0] pc;
    logic[31:0] pc_prev;
    logic[31:0] addr;
    logic[31:0] pc_next;
    logic[31:0] pc_incr;
    logic       move_pc;
    logic       bp_need;
    logic       bp_prev;
    logic[31:0] bp_addr;

    logic       pc_next_trap_sel;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  pc_next = (!i_reset_n) ? RESET_ADDR :
                pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
                bp_need ? bp_addr :
                (pc + pc_incr);

    always_ff @(posedge i_clk)
    begin
        if (move_pc)
            pc <= pc_next;
        pc_prev <= pc;
    end

    logic   free_dword_or_more;
    logic   ack;

    always_ff @(posedge i_clk)
    begin
        ack <= i_ack & (!i_pc_select);
    end

    logic   pc_need_change;
    assign  pc_need_change = i_pc_select | (!i_reset_n) | (i_ebreak & EXTENSION_Zicsr);

    rv_fetch_buf
    #(
        .INSTR_BUF_ADDR_SIZE            (INSTR_BUF_ADDR_SIZE)
    )
    u_buf
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_flush                        (i_flush),
        .i_stall                        (i_stall),
        .i_pc_select                    (pc_need_change),
        .i_ack                          (ack),
        .i_data                         (i_instruction),
        .i_fetch_pc1                    (pc[1]),
        .i_fetch_pc_prev                (pc_prev),
        .i_branch_pred                  (bp_need),
        .i_branch_pred_prev             (bp_prev),
        .o_free_dword_or_more           (free_dword_or_more),
        .o_pc_incr                      (pc_incr),
        .o_pc                           (o_pc),
        .o_branch_pred                  (o_branch_pred),
        .o_instruction                  (o_instruction),
        .o_ready                        (o_ready)
    );

    assign  move_pc =  (i_ack & free_dword_or_more) | pc_need_change | bp_need;
    assign  o_cyc = i_reset_n & free_dword_or_more & (!pc_need_change);
    assign  addr = pc;

    generate
        if (BRANCH_PREDICTION)
        begin : pred
            rv_fetch_branch_pred
            #(
                .EXTENSION_C            (EXTENSION_C)
            )
            u_pred
            (
                .i_clk                  (i_clk),
                .i_reset_n              (i_reset_n),
                .i_instruction          (i_instruction),
                .i_ack                  (ack),
                .i_ra_invalidate        (i_ra_invalidate),
                .i_reg_write            (i_reg_write),
                .i_rd                   (i_rd),
                .i_reg_wdata            (i_reg_wdata),
                .i_pc_prev              (pc_prev),
                .o_bp_need              (bp_need),
                .o_bp_need_prev         (bp_prev),
                .o_bp_addr              (bp_addr)
            );
        end
        else
        begin
            assign  bp_need = '0;
            assign  bp_prev = '0;
            assign  bp_addr = '0;
            /* verilator lint_off UNUSEDSIGNAL */
            logic  dummy;
            assign dummy = i_ra_invalidate | (|i_reg_wdata) | (|i_rd) | i_reg_write;
            /* verilator lint_on UNUSEDSIGNAL */
        end
    endgenerate

    assign  o_addr = addr;

initial
begin
    pc = '0;
end

endmodule
