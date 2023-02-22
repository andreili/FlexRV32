`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter logic[31:0]  RESET_ADDR   = 32'h0000_0000,
    parameter int IADDR_SPACE_BITS      = 16,
    parameter logic BRANCH_PREDICTION   = 1,
    parameter int BRANCH_TABLE_SIZE_BITS= 2,
    parameter int INSTR_BUF_ADDR_SIZE   = 2,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_Zicsr     = 1
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
    logic[IADDR_SPACE_BITS-1:0] pc_delta;

    assign  pc_delta = { {(IADDR_SPACE_BITS-3){1'b0}}, (!pc[1]) | (!EXTENSION_C),
                         pc[1] & EXTENSION_C, 1'b0 };

    assign pc_incr = (!full) ? pc_delta : '0;
    assign move_pc = (i_ack & (!full)) | pc_need_change;
    assign o_cyc = (!full) & i_reset_n;
    assign instruction = i_instruction;

    localparam int InsWidth = (EXTENSION_C ? 16 : 32);
    localparam int BufWidth = IADDR_SPACE_BITS + 1 + InsWidth;

    generate
        logic[BufWidth-1:0]         data_lo;
        logic[BufWidth-1:0]         data_hi;
        logic                       buf_pop_single;
        logic                       buf_pop_double;
        logic[IADDR_SPACE_BITS-1:0] addr_lo;
        logic[IADDR_SPACE_BITS-1:0] addr_hi;
        logic[InsWidth-1:0]         instr_lo;
        logic[InsWidth-1:0]         instr_hi;
        logic                       is_comp;
        logic                       is_bp_lo;
        logic                       is_bp_hi;

        if (EXTENSION_C)
        begin : g_comp
            assign  data_lo = { branch_predicted_prev, pc_prev[IADDR_SPACE_BITS-1:2],
                                2'b00, instruction[15: 0] };
            assign  data_hi = { branch_predicted_prev, pc_prev[IADDR_SPACE_BITS-1:2],
                                2'b10, instruction[31:16] };
            assign  is_comp = (instr_lo[1:0] != 2'b11);
            assign  buf_pop_single = (!i_stall) & (!i_flush) & (!empty) & is_comp;
            assign  o_instruction = { instr_hi, instr_lo };
        end
            else
        begin : g_nocomp
            assign  data_lo = { branch_predicted_prev, pc_prev[IADDR_SPACE_BITS-1:2],
                                2'b00, instruction };
            assign  data_hi = '0;
            assign  is_comp = '0;
            assign  buf_pop_single = '0;
            assign  o_instruction = instr_lo;
        end
        assign  buf_pop_double = (!i_stall) & (!i_flush) & (!empty) & (!is_comp);

        rv_fetch_buf
        #(
            .WIDTH                  (BufWidth),
            .DEPTH_BITS             (INSTR_BUF_ADDR_SIZE)
        )
        u_buf
        (
            .i_clk                  (i_clk),
            .i_reset_n              (i_reset_n & (!i_flush)),
            .i_data_lo              (data_lo),
            .i_data_hi              (data_hi),
            .i_push_single          (ack &   pc_prev[1] & EXTENSION_C),
            .i_push_double          (ack & ((!pc_prev[1]) | (!EXTENSION_C))),
            .o_data_lo              ({ is_bp_lo, addr_lo, instr_lo }),
            .o_data_hi              ({ is_bp_hi, addr_hi, instr_hi }),
            .i_pop_single           (buf_pop_single),
            .i_pop_double           (buf_pop_double),
            .o_empty                (empty),
            .o_full                 (full)
        );
    endgenerate

    assign  o_branch_pred = is_bp_lo;
    assign  o_pc = addr_lo;
    assign  o_ready = (!empty);

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_flush | (|i_pc_br) | (|addr_hi) | is_bp_hi | pc_prev[0] | (|instr_hi);
/* verilator lint_on UNUSEDSIGNAL */

    generate
        if (BRANCH_PREDICTION)
        begin : g_pred
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
        begin : g_nopred
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
