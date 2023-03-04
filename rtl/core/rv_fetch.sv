`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter logic[31:0]  RESET_ADDR   = 32'h0000_0000,
    parameter int IADDR_SPACE_BITS      = 16,
    parameter int INSTR_BUF_ADDR_SIZE   = 2,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_Zicsr     = 1
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
    output  wire                        o_ready
);

    logic[IADDR_SPACE_BITS-1:0] pc;
    logic[IADDR_SPACE_BITS-1:0] pc_sum;
    logic[IADDR_SPACE_BITS-1:0] pc_next;
    logic[IADDR_SPACE_BITS-1:0] pc_incr;
    logic                       move_pc;
    logic                       update_pc;
    logic                       pc_prev1;

    logic       pc_next_trap_sel;
    logic       empty, full;
    logic[31:0] instruction;
    logic       ack;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  move_pc = (i_ack & (!full));
    assign  update_pc = (!i_reset_n) | pc_next_trap_sel | i_pc_select | move_pc;
    assign  pc_incr = { {(IADDR_SPACE_BITS-3){1'b0}}, !pc[1], pc[1], 1'b0 };
    assign  pc_sum = pc + pc_incr;

    assign  pc_next = (!i_reset_n) ? RESET_ADDR[IADDR_SPACE_BITS-1:0] :
                pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
                pc_sum;

    always_ff @(posedge i_clk)
    begin
        if (update_pc)
            pc <= pc_next;
        pc_prev1 <= pc[1];
    end

    always_ff @(posedge i_clk)
    begin
        ack <= i_ack & (!i_pc_select);
    end

    assign instruction = i_instruction;

    localparam int BufWidth = (EXTENSION_C ? 16 : 32);

    generate
        logic[BufWidth-1:0]         data_lo;
        logic[BufWidth-1:0]         data_hi;
        logic                       buf_pop;
        logic[BufWidth-1:0]         instr_lo;
        logic[BufWidth-1:0]         instr_hi;

        assign  buf_pop = !(i_stall | i_flush | empty);
        if (EXTENSION_C)
        begin : g_comp
            assign  data_lo = instruction[15: 0];
            assign  data_hi = instruction[31:16];
            assign  o_instruction = { instr_hi, instr_lo };
        end
            else
        begin : g_nocomp
            assign  data_lo = instruction;
            assign  data_hi = '0;
            assign  o_instruction = instr_lo;
        end

        rv_fetch_buf
        #(
            .IADDR_SPACE_BITS       (IADDR_SPACE_BITS),
            .WIDTH                  (BufWidth),
            .DEPTH_BITS             (INSTR_BUF_ADDR_SIZE)
        )
        u_buf
        (
            .i_clk                  (i_clk),
            .i_reset_n              (i_reset_n & (!i_flush)),
            .i_pc                   (pc_next),
            .i_data_lo              (data_lo),
            .i_data_hi              (data_hi),
            .i_push_single          (ack &   pc_prev1 & EXTENSION_C),
            .i_push_double          (ack & ((!pc_prev1) | (!EXTENSION_C))),
            .o_data_lo              (instr_lo),
            .o_data_hi              (instr_hi),
            .o_pc                   (o_pc),
            .i_pop                  (buf_pop),
            .o_empty                (empty),
            .o_full                 (full)
        );
    endgenerate

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_flush | (|instr_hi);
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_cyc = (!full) & i_reset_n;
    assign  o_addr = pc;

    assign  o_ready = (!empty);

initial
begin
    pc = '0;
end

endmodule
