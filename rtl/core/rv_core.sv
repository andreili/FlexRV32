`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"
`include "rv_opcodes.vh"

/* verilator lint_off UNUSEDSIGNAL */

module rv_core
#(
    parameter   RESET_ADDR = 32'h0000_0000
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
`ifdef TO_SIM
    output  wire[31:0]                  o_debug,
`endif
    // instruction interface
    output  wire                        o_instr_req,
    output  wire[31:0]                  o_instr_addr,
    input   wire                        i_instr_ack,
    input   wire[31:0]                  i_instr_data,
    // data interface
    output  wire                        o_data_req,
    output  wire                        o_data_write,
    output  wire[31:0]                  o_data_addr,
    output  wire[31:0]                  o_data_wdata,
    output  wire[3:0]                   o_data_sel,
    input   wire                        i_data_ack,
    input   wire[31:0]                  i_data_rdata
);

    logic   instr_cyc;
    fetch_bus_t fetch_bus;
    decode_bus_t decode_bus;
    alu1_bus_t  alu1_bus;
    alu2_bus_t  alu2_bus;
    alu3_bus_t  alu3_bus;
    memory_bus_t memory_bus;
    write_bus_t write_bus;
`ifdef EXTENSION_Zicsr
    logic[31:0] ret_addr;
    csr_bus_t   csr_bus;
`endif

    logic[3:0]  state_cur, state_nxt;
    localparam  STATE_FETCH = 0;
    localparam  STATE_RS = 1;
    localparam  STATE_ALU1 = 2;
    localparam  STATE_ALU2 = 3;
    localparam  STATE_ALU3 = 4;
    localparam  STATE_MEM = 5;
    localparam  STATE_WR = 6;

    always_comb
    begin
        case (state_cur)
        STATE_FETCH: state_nxt = fetch_bus.ready ? STATE_RS : STATE_FETCH;
        STATE_RS: state_nxt = STATE_ALU1;
        STATE_ALU1: state_nxt = STATE_ALU2;
        STATE_ALU2: state_nxt = STATE_ALU3;
        STATE_ALU3: state_nxt = STATE_MEM;
        STATE_MEM: state_nxt = STATE_WR;
        STATE_WR: state_nxt = STATE_FETCH;
        default: state_nxt = STATE_FETCH;
        endcase
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            state_cur <= STATE_ALU3;
        else
            state_cur <= state_nxt;
    end

    assign  o_data_req = (state_cur == STATE_ALU3) & (alu3_bus.res_src.memory | alu3_bus.store);

    logic[31:0] reg_rdata1, reg_rdata2;

    rv_fetch
    #(
        .RESET_ADDR                     (RESET_ADDR)
    )
    u_st1_fetch
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc_target                    (alu3_bus.pc_target),
        .i_pc_select                    (alu3_bus.pc_select),
    `ifdef EXTENSION_Zicsr
        .i_pc_trap                      (trap_pc),
        .i_ebreak                       (decode_bus.inst_ebreak),
    `endif
        .i_fetch_start                  (state_cur == STATE_WR),
        //.i_pc_inc                       (state_cur == STATE_FETCH),
        //.i_data_latch                   (state_cur == STATE_FETCH),
        .i_instruction                  (i_instr_data),
        .i_ack                          (i_instr_ack),//(state_cur == STATE_FETCH),//(1'b1),
        .o_addr                         (o_instr_addr),
        .o_cyc                          (o_instr_req),
        .o_bus                          (fetch_bus)
    );

    rv_decode
    u_st2_decode
    (
        .i_clk                          (i_clk),
        .i_bus                          (fetch_bus),
`ifdef EXTENSION_Zicsr
        .o_csr                          (csr_bus),
`endif
        .o_bus                          (decode_bus)
    );

    rv_alu1
    u_st3_alu1
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_bus                          (decode_bus),
`ifdef EXTENSION_Zicsr
        .i_ret_addr                     (ret_addr),
`endif
        .i_reg1_data                    (reg_rdata1),
        .i_reg2_data                    (reg_rdata2),
        .o_bus                          (alu1_bus)
    );

`ifdef EXTENSION_Zicsr
    logic       csr_read;
    logic[31:0] csr_rdata;
    logic[31:0] trap_pc;
    rv_csr
    u_st3_csr
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_reg_data                     (reg_rdata1),
        .i_bus                          (csr_bus),
        .o_read                         (csr_read),
        .o_ret_addr                     (ret_addr),
        .o_trap_pc                      (trap_pc),
        .o_data                         (csr_rdata)
    );
`endif

    rv_alu2
    u_st4_alu2
    (   
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_bus                          (alu1_bus),
    `ifdef EXTENSION_Zicsr
        .i_csr_read                     (csr_read),
        .i_csr_data                     (csr_rdata),
    `endif
        .o_bus                          (alu2_bus)
    );

    rv_alu3
    u_st4_alu3
    (   
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_bus                          (alu2_bus),
        .o_wdata                        (o_data_wdata),
        .o_wsel                         (o_data_sel),
        .o_bus                          (alu3_bus)
    );

    assign  o_data_write = alu3_bus.store;
    assign  o_data_addr = alu3_bus.add;

    always_ff @(posedge i_clk)
    begin
        memory_bus.funct3  <= alu3_bus.funct3;
        memory_bus.alu_result <= alu3_bus.alu_result;
        memory_bus.reg_write <= alu3_bus.reg_write;
        memory_bus.rd <= alu3_bus.rd;
        memory_bus.res_src <= alu3_bus.res_src;
        memory_bus.pc_p4 <= alu3_bus.pc_p4;
    end

    logic[31:0] write_data;
    logic[4:0]  write_rd;
    logic       write_op;
    
    rv_write
    u_st6_write
    (
        .i_clk                          (i_clk),
        .i_bus                          (memory_bus),
        .i_data                         (i_data_rdata),
        .o_data                         (write_data),
        .o_rd                           (write_rd),
        .o_write_op                     (write_op)
    );

    rv_regs
    u_regs
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_rs1                          (decode_bus.rs1),
        .i_rs2                          (decode_bus.rs2),
        .i_rd                           (write_rd),
        .i_write                        (write_op),
        .i_data                         (write_data),
        .o_data1                        (reg_rdata1),
        .o_data2                        (reg_rdata2)
    );

`ifdef TO_SIM
    logic[127:0] dbg_state;
    always_comb
    begin
        case (state_cur)
        STATE_FETCH: dbg_state = "fetch";
        STATE_RS:    dbg_state = "rs";
        STATE_ALU1:  dbg_state = "alu#1";
        STATE_ALU2:  dbg_state = "alu#2";
        STATE_ALU3:  dbg_state = "alu#3";
        STATE_MEM:   dbg_state = "mem";
        STATE_WR:    dbg_state = "wr";
        endcase
    end
`endif

`ifdef TO_SIM
    assign  o_debug[0] = (!decode_bus.inst_supported) & (state_nxt == STATE_ALU1);
    assign  o_debug[31:1] = '0;
`endif

endmodule
/* verilator lint_on UNUSEDSIGNAL */
