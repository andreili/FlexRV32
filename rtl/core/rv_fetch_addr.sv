`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_addr
#(
    parameter logic[31:0]  RESET_ADDR   = 32'h0000_0000,
    parameter int IADDR_SPACE_BITS      = 16,
    parameter logic EXTENSION_Zicsr     = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_fifo_not_full,
    input   wire                        i_ack,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_target,
    input   wire                        i_pc_select,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_trap,
    input   wire                        i_ebreak,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_next,
    output  wire                        o_change_pc
);

    logic                       pc_select;
    logic[IADDR_SPACE_BITS-1:1] pc_target;

    always_ff @(posedge i_clk)
    begin
        pc_select <= i_pc_select;
        pc_target <= i_pc_target;
    end

    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_sum;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic[IADDR_SPACE_BITS-1:1] pc_incr;
    logic                       move_pc;
    logic                       change_pc;
    logic                       update_pc;

    logic       pc_next_trap_sel;

    // logic for change PC value (interrupts, jumps/branches, bus wait)
    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  move_pc          = (i_ack & i_fifo_not_full);
    assign  change_pc        = pc_next_trap_sel | pc_select;
    assign  update_pc        = (!i_reset_n) | change_pc | move_pc;
    assign  pc_incr          = { {(IADDR_SPACE_BITS-3){1'b0}}, !pc[1], pc[1] };

/* verilator lint_off PINCONNECTEMPTY */
    // adder - implementation defined
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

    // mux for PC pointer
    assign  pc_next = (!i_reset_n) ? RESET_ADDR[IADDR_SPACE_BITS-1:1] :
                pc_next_trap_sel ? i_pc_trap :
                pc_select        ? pc_target :
                pc_sum;

    always_ff @(posedge i_clk)
    begin
        if (update_pc)
            pc <= pc_next;
    end

    assign  o_pc        = pc;
    assign  o_pc_next   = pc_next;
    assign  o_change_pc = change_pc;

initial
begin
    pc = '0;
end

endmodule
