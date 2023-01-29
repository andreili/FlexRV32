`timescale 1ps/1ps

`include "../rv_defines.vh"

/* verilator lint_off UNUSEDPARAM */
module rv_fetch
#(
    parameter   RESET_ADDR              = 32'h0000_0000,
    parameter   IADDR_SPACE_BITS        = 16,
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
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_target,
    input   wire                        i_pc_select,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_trap,
    input   wire                        i_ebreak,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire[IADDR_SPACE_BITS-1:0]  o_addr,
    output  wire                        o_cyc,
    output  wire[31:0]                  o_instruction,
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);
/* verilator lint_on UNUSEDPARAM */

    logic[IADDR_SPACE_BITS-1:0] pc;
    logic[IADDR_SPACE_BITS-1:0] addr;
    logic[IADDR_SPACE_BITS-1:0] pc_next;
    logic[IADDR_SPACE_BITS-1:0] pc_incr;
    logic       move_pc;
    logic[IADDR_SPACE_BITS-1:0] pc_prev;

    logic       pc_next_trap_sel;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  pc_next = (!i_reset_n) ? RESET_ADDR[IADDR_SPACE_BITS-1:0] :
                pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
                (pc + pc_incr);

    always_ff @(posedge i_clk)
    begin
        if (move_pc)
            pc <= pc_next;
        pc_prev <= pc;
    end
    logic   ack;

    always_ff @(posedge i_clk)
    begin
        ack <= i_ack & (!i_pc_select);
    end

    logic   pc_need_change;
    assign  pc_need_change = i_pc_select | (!i_reset_n) | (i_ebreak & EXTENSION_Zicsr);

    logic   empty, full;

    assign pc_incr = (!full) ? 4 : 0;
    assign move_pc = (i_ack & (!full)) | pc_need_change;
    assign o_cyc = (!full) & i_reset_n;

    fifo
    #(
        .WIDTH                  (IADDR_SPACE_BITS+32),
        .DEPTH_BITS             (2)
    )
    u_fifo
    (
        .i_clk                  (i_clk),
        .i_reset_n              (i_reset_n & (!i_flush)),
        .i_data                 ({ pc_prev, i_instruction }),
        .i_push                 (ack),
        .o_data                 ({ o_pc, o_instruction }),
        .i_pop                  ((!i_stall) & (!i_flush) & (!empty)),
        .o_empty                (empty),
        .o_full                 (full)
    );

    assign o_ready = (!empty);

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_flush;
/* verilator lint_on UNUSEDSIGNAL */

    assign  addr = pc;

    generate
        if (BRANCH_PREDICTION)
        begin : pred
            /*rv_fetch_branch_pred
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
            );*/
        end
        else
        begin
            assign o_branch_pred = '0;
        end
    endgenerate

    assign  o_addr = addr;

initial
begin
    pc = '0;
end

endmodule
