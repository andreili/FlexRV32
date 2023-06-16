`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter logic[31:0]  RESET_ADDR   = 32'h0000_0000,
    parameter int IADDR_SPACE_BITS      = 16,
    parameter int INSTR_BUF_ADDR_SIZE   = 2,
    //parameter logic EXTENSION_C         = 1,
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

    logic       not_full;
    logic       clk, reset_n;

    buf buf_clk(clk, i_clk);
    buf buf_reset(reset_n, i_reset_n);

    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic                       change_pc;

    rv_fetch_addr
    #(
        .RESET_ADDR                     (RESET_ADDR),
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .EXTENSION_Zicsr                (EXTENSION_Zicsr)
    )
    u_addr
    (
        .i_clk                          (clk),
        .i_reset_n                      (reset_n),
        .i_fifo_not_full                (not_full),
        .i_ack                          (i_ack),
        .i_pc_target                    (i_pc_target),
        .i_pc_select                    (i_pc_select),
        .i_pc_trap                      (i_pc_trap),
        .i_ebreak                       (i_ebreak),
        .o_pc                           (pc),
        .o_pc_next                      (pc_next),
        .o_change_pc                    (change_pc)
    );

    logic   push_next, push;
    logic   buf_reset_n;
    logic   not_empty;

    assign  push_next = !(!buf_reset_n | !i_ack);
    always_ff @(posedge clk)
    begin
        push <= push_next;
    end

    // buffer reset logic
    assign  buf_reset_n = !(!reset_n | change_pc);

    rv_fetch_buf
    #(
        .IADDR_SPACE_BITS       (IADDR_SPACE_BITS),
        .WIDTH                  (32),
        .DEPTH_BITS             (INSTR_BUF_ADDR_SIZE)
    )
    u_buf
    (
        .i_clk                  (clk),
        .i_reset_n              (buf_reset_n),
        .i_stall                (i_stall),
        .i_pc                   (pc_next),
        .i_data                 (i_instruction),
        .i_push                 (push),
        .o_data                 (o_instruction),
        .o_pc                   (o_pc),
        .o_pc_next              (o_pc_next),
        .o_not_empty            (not_empty),
        .o_not_full             (not_full)
    );

    assign  o_pc_change = change_pc;
    assign  o_ready     = not_empty;
    // generate bus requests
    assign  o_cyc       = not_full;
    assign  o_addr      = pc;

`ifdef TO_SIM
initial
begin
    pc = '0;
end
`endif

endmodule
