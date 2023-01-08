`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_aligner
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[31:0]                  i_pc,
    input   wire                        i_start,
    input   wire                        i_pc_select,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire                        o_cyc,
    output  wire                        o_move,
    output  wire[31:0]                  o_pc_incr,
    output  wire[31:0]                  o_addr,
    output  wire                        o_ready,
    output  wire[31:0]                  o_pc,
    output  wire[31:0]                  o_instruction
);

    // latch and alignment logic
    logic       bus_cyc;
    logic       misal;
    logic       misal_prev;
    logic       ready_en;
    logic       instr_ready;
    logic[15:0] instr_lo_hw;
    logic[31:0] instr_concat;
    logic[31:0] instr_mux;
    logic[31:0] instruction;
    logic[31:0] fetch_addr;
    logic       fetch_inc_bit;
    logic       ready;
    logic[31:0] pc;

    assign  fetch_inc_bit = (!misal) & bus_cyc & i_pc[1];

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            misal <= '0;
        else if (bus_cyc & i_pc[1])
            misal <= !misal;
        fetch_addr <= i_pc + { 29'b0, fetch_inc_bit, 2'b0 };
    end
    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | misal_prev)
            misal_prev <= '0;
        else if (misal)
            misal_prev <= '1;
    end

    assign  ready_en = !(i_pc[1] & misal);
    assign  instr_ready = i_ack & ready_en;

    always_ff @(posedge i_clk)
    begin
        if (i_ack)
            instr_lo_hw <= i_instruction[31:16];
    end

    assign  instr_concat = { i_instruction[15:0], instr_lo_hw };
    assign  instr_mux = misal_prev ? instr_concat : i_instruction;

    always_ff @(posedge i_clk)
    begin
        ready <= instr_ready;
        pc <= i_pc;
        if (instr_ready & i_reset_n)
            instruction <= instr_mux;
        else
            instruction <= '0;
    end

    assign  bus_cyc = i_start | misal;

    assign  o_cyc = bus_cyc;
    assign  o_move = instr_ready | i_pc_select;
    assign  o_pc_incr = (instr_mux[1:0] == 2'b11) ? 4 : 2;
    assign  o_addr = fetch_addr;
    assign  o_ready = ready;
    assign  o_pc = pc;
    assign  o_instruction = instruction;

endmodule
