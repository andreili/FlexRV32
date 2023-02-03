`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter   RESET_ADDR              = 32'h0000_0000,
    parameter   IADDR_SPACE_BITS        = 16,
    parameter   BRANCH_PREDICTION       = 1,
    parameter   BRANCH_TABLE_SIZE_BITS  = 2,
    parameter   INSTR_BUF_ADDR_SIZE     = 2,
    parameter   EXTENSION_C             = 1,
    parameter   EXTENSION_Zicsr         = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_br,
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
    output  wire                        o_is_compressed,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);

    logic[IADDR_SPACE_BITS-1:0] pc;
    logic[IADDR_SPACE_BITS-1:0] pc_next;
    logic[IADDR_SPACE_BITS-1:0] pc_incr;
    logic                       move_pc;
    logic[IADDR_SPACE_BITS-1:0] pc_prev;
    logic[IADDR_SPACE_BITS-1:0] pc_bp;
    logic                       branch_predicted;
    logic                       branch_predicted_prev;

    logic       pc_next_trap_sel;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  pc_next = (!i_reset_n) ? RESET_ADDR[IADDR_SPACE_BITS-1:0] :
                pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
                branch_predicted ? pc_bp :
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

    logic       empty, full;
    logic[31:0] instruction;

    generate
        if (EXTENSION_C)
        begin
            /* verilator lint_off UNUSEDSIGNAL */
            logic[15:0] inst_prev_hi;
            logic       buf_hi_valid;
            logic[31:0] inst_mux;
            logic       cillegal;

            always_ff @(posedge i_clk)
            begin
                if (ack & pc_prev[1])
                begin
                    inst_prev_hi <= i_instruction[31:16];
                    buf_hi_valid <= '1;
                end
                else
                begin
                    buf_hi_valid <= '0;
                end
            end
            /* verilator lint_on UNUSEDSIGNAL */

            assign inst_mux = buf_hi_valid ? { i_instruction[15:0], inst_prev_hi } : i_instruction;

            rv_decode_comp
            u_comp
            (
                .i_instruction                  (inst_mux),
                .o_instruction                  (instruction),
                .o_illegal_instruction          (cillegal)
            );

            assign pc_incr = (!full) ? 2 : 0;
            assign move_pc = (i_ack & (!full)) | pc_need_change;
            assign o_cyc = (!full) & i_reset_n;
        end
        else
        begin
            assign pc_incr = (!full) ? 4 : 0;
            assign move_pc = (i_ack & (!full)) | pc_need_change;
            assign o_cyc = (!full) & i_reset_n;
            assign instruction = i_instruction;
        end
    endgenerate

    fifo
    #(
        .WIDTH                  (IADDR_SPACE_BITS+32+2),
        .DEPTH_BITS             (INSTR_BUF_ADDR_SIZE)
    )
    u_fifo
    (
        .i_clk                  (i_clk),
        .i_reset_n              (i_reset_n & (!i_flush)),
        .i_data                 ({ branch_predicted_prev, 1'b0, pc_prev, instruction }),
        .i_push                 (ack),
        .o_data                 ({ o_branch_pred, o_is_compressed, o_pc, o_instruction }),
        .i_pop                  ((!i_stall) & (!i_flush) & (!empty)),
        .o_empty                (empty),
        .o_full                 (full)
    );

    assign o_ready = (!empty);

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_flush | (|i_pc_br);
/* verilator lint_on UNUSEDSIGNAL */

    generate
        if (BRANCH_PREDICTION)
        begin : pred
            rv_fetch_branch_pred
            #(
                .IADDR_SPACE_BITS       (IADDR_SPACE_BITS),
                .TABLE_SIZE_BITS        (BRANCH_TABLE_SIZE_BITS)
            )
            u_pred
            (
                .i_clk                  (i_clk),
                .i_reset_n              (i_reset_n),
                .i_pc_current           (pc),
                .i_pc_select            (i_pc_select),
                .i_pc_branch            (i_pc_br),
                .i_pc_target            (i_pc_target),
                .o_pc_new               (pc_bp),
                .o_pc_predicted         (branch_predicted)
            );
        end
        else
        begin
            assign branch_predicted = '0;
            assign pc_bp = '0;
        end
    endgenerate

    always_ff @(posedge i_clk)
    begin
        branch_predicted_prev <= branch_predicted;
    end

    assign  o_addr = pc;

initial
begin
    pc = '0;
end

endmodule
