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
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_target,
    input   wire                        i_pc_select,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_trap,
    input   wire                        i_ebreak,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire                        o_pc_change,
    output  wire[IADDR_SPACE_BITS-1:1]  o_addr,
    output  wire                        o_cyc,
    output  wire[31:0]                  o_instruction,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_next,
    output  wire                        o_ready
);

    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_sum;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic[IADDR_SPACE_BITS-1:1] pc_incr;
    logic                       move_pc;
    logic                       change_pc;
    logic                       update_pc;
    logic                       pc_prev1;

    logic       pc_next_trap_sel;
    logic       empty, full;
    logic[31:0] instruction;
    logic       ack;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  move_pc = (i_ack & (!full));
    assign  change_pc = pc_next_trap_sel | i_pc_select;
    assign  update_pc = (!i_reset_n) | change_pc | move_pc;
    assign  pc_incr = { {(IADDR_SPACE_BITS-3){1'b0}}, !pc[1], pc[1] };

/* verilator lint_off PINCONNECTEMPTY */
    add
    #(
        .WIDTH                          (IADDR_SPACE_BITS - 1)
    )
    u_pc_inc
    (
        .i_carry                        (1'b0),
        .i_op1                          (pc),
        .i_op2                          (pc_incr),
        .o_add                          (pc_sum),
        .o_carry                        ()
    );
/* verilator lint_on  PINCONNECTEMPTY */

    assign  pc_next = (!i_reset_n) ? RESET_ADDR[IADDR_SPACE_BITS-1:1] :
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
        ack <= i_ack & (!change_pc);
    end

    assign instruction = i_instruction;

    localparam int BufWidth = (EXTENSION_C ? 16 : 32);

    generate
        logic[BufWidth-1:0]         data_lo;
        logic[BufWidth-1:0]         data_hi;
        logic                       buf_pop;
        logic[BufWidth-1:0]         instr_lo;
        logic[BufWidth-1:0]         instr_hi;

        assign  buf_pop = !(i_stall | empty);
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
    endgenerate

    rv_fetch_buf
    #(
        .IADDR_SPACE_BITS       (IADDR_SPACE_BITS),
        .WIDTH                  (BufWidth),
        .DEPTH_BITS             (INSTR_BUF_ADDR_SIZE)
    )
    u_buf
    (
        .i_clk                  (i_clk),
        .i_reset_n              (i_reset_n & (!change_pc)),
        .i_pc                   (pc_next),
        .i_data_lo              (data_lo),
        .i_data_hi              (data_hi),
        .i_push_single          (ack &   pc_prev1 & EXTENSION_C),
        .i_push_double          (ack & ((!pc_prev1) | (!EXTENSION_C))),
        .o_data_lo              (instr_lo),
        .o_data_hi              (instr_hi),
        .o_pc                   (o_pc),
        .o_pc_next              (o_pc_next),
        .i_pop                  (buf_pop),
        .o_empty                (empty),
        .o_full                 (full)
    );

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = (|instr_hi);
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_pc_change = change_pc;
    assign  o_cyc = (!full) & i_reset_n;
    assign  o_addr = pc;

    assign  o_ready = (!empty);

initial
begin
    pc = '0;
end

endmodule
