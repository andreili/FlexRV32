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
    //
    output  wire[31:0]                  o_wb_adr,
    output  wire[31:0]                  o_wb_dat,
    input   wire[31:0]                  i_wb_dat,
    output  wire                        o_wb_we,
    output  wire[3:0]                   o_wb_sel,
    output  wire                        o_wb_stb,
    input   wire                        i_wb_ack,
`ifdef TO_SIM
    output  wire[31:0]                  o_debug,
`endif
    output  wire                        o_wb_cyc
);

    logic   instr_cyc;
    fetch_bus_t fetch_bus;
    decode_bus_t decode_bus;
    alu1_bus_t  alu1_bus;
    alu2_bus_t  alu2_bus;
    alu3_bus_t  alu3_bus;

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
        STATE_FETCH: state_nxt = i_wb_ack ? STATE_RS : STATE_FETCH;
        STATE_RS: state_nxt = fetch_bus.ready ? STATE_ALU1 : STATE_RS;
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

    logic[31:0] reg_rdata1, reg_rdata2;
    logic[31:0] fetch_addr;

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
        .i_fetch_start                  (state_cur == STATE_WR),
        //.i_pc_inc                       (state_cur == STATE_FETCH),
        //.i_data_latch                   (state_cur == STATE_FETCH),
        .i_instruction                  (i_wb_dat),
        .i_ack                          (instr_ack),//(state_cur == STATE_FETCH),//(1'b1),
        .o_addr                         (fetch_addr),
        .o_cyc                          (instr_cyc),
        .o_bus                          (fetch_bus)
    );

    rv_decode
    u_st2_decode
    (
        .i_clk                          (i_clk),
        .i_bus                          (fetch_bus),
        .o_bus                          (decode_bus)
    );

    rv_alu1
    u_st3_alu1
    (
        .i_clk                          (i_clk),
        .i_bus                          (decode_bus),
        .i_reg1_data                    (reg_rdata1),
        .i_reg2_data                    (reg_rdata2),
        .o_bus                          (alu1_bus)
    );

    rv_alu2
    u_st4_alu2
    (   
        .i_clk                          (i_clk),
        .i_bus                          (alu1_bus),
        .o_bus                          (alu2_bus)
    );

    logic[31:0] wdata;
    logic[3:0]  wsel;

    rv_alu3
    u_st4_alu3
    (   
        .i_clk                          (i_clk),
        .i_bus                          (alu2_bus),
        .o_wdata                        (wdata),
        .o_wsel                         (wsel),
        .o_bus                          (alu3_bus)
    );

    logic[2:0]  memory_funct3;
    logic[31:0] memory_alu_result;
    logic       memory_reg_write;
    logic[4:0]  memory_rd;
    res_src_t   memory_res_src;
    logic[31:0] memory_pc;
`ifdef EXTENSION_C
    logic       memory_compressed;
`endif

    always_ff @(posedge i_clk)
    begin
        memory_funct3  <= alu3_bus.funct3;
        memory_alu_result <= alu3_bus.alu_result;
        memory_reg_write <= alu3_bus.reg_write;
        memory_rd <= alu3_bus.rd;
        memory_res_src <= alu3_bus.res_src;
        memory_pc <= alu3_bus.pc;
    `ifdef EXTENSION_C
        memory_compressed <= alu3_bus.compressed;
    `endif
    end

    logic[31:0] mem_rdata;
    logic[31:0] write_alu_result;
    logic[31:0] write_pc;
    res_src_t   write_res_src;
    logic       write_reg_write;
    logic[4:0]  write_rd;
    logic[2:0]  write_funct3;
`ifdef EXTENSION_C
    logic       write_compressed;
`endif
    
    always_ff @(posedge i_clk)
    begin
        write_alu_result <= memory_alu_result;
        write_pc <= memory_pc;
        write_res_src <= memory_res_src;
        write_reg_write <= memory_reg_write;
        write_rd <= memory_rd;
        write_funct3 <= memory_funct3;
        mem_rdata <= i_wb_dat;
    `ifdef EXTENSION_C
        write_compressed <= memory_compressed;
    `endif
    end

    logic[7:0]  write_byte;
    logic[15:0] write_half_word;
    logic[31:0] write_rdata;
    logic[31:0] write_data;

    always_comb
    begin
        case (write_alu_result[1:0])
        2'b00: write_byte = mem_rdata[ 0+:8];
        2'b01: write_byte = mem_rdata[ 8+:8];
        2'b10: write_byte = mem_rdata[16+:8];
        2'b11: write_byte = mem_rdata[24+:8];
        endcase
    end

    always_comb
    begin
        case (write_alu_result[1])
        1'b0: write_half_word = mem_rdata[ 0+:16];
        1'b1: write_half_word = mem_rdata[16+:16];
        endcase
    end

    always_comb
    begin
        case (write_funct3)
        3'b000: write_rdata = { {24{write_byte[7]}}, write_byte};
        3'b001: write_rdata = { {16{write_half_word[15]}}, write_half_word};
        3'b010: write_rdata = mem_rdata;
        3'b011: write_rdata = '0;
        3'b100: write_rdata = { {24{1'b0}}, write_byte};
        3'b101: write_rdata = { {16{1'b0}}, write_half_word};
        3'b110: write_rdata = '0;
        3'b111: write_rdata = '0;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        write_res_src.memory: write_data = write_rdata;
        write_res_src.pc_p4:  write_data = (write_pc + 
`ifdef EXTENSION_C
                (write_compressed ? 2 : 4)
`else
                4
`endif
            );
        default:              write_data = write_alu_result;
        endcase
    end

    rv_regs
    u_regs
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_rs1                          (decode_bus.rs1),
        .i_rs2                          (decode_bus.rs2),
        .i_rd                           (write_rd),
        .i_write                        (write_reg_write),
        .i_data                         (write_data),
        .o_data1                        (reg_rdata1),
        .o_data2                        (reg_rdata2)
    );

    logic   instr_ack;
    logic   bus_data;

    assign  bus_data = (state_cur == STATE_ALU3) & (alu3_bus.res_src.memory | alu3_bus.store);

    assign o_wb_adr = bus_data ? alu3_bus.add : fetch_addr;
    assign o_wb_dat = wdata;
    assign o_wb_we = bus_data ? alu3_bus.store : '0;
    assign o_wb_sel = bus_data ? wsel : '1;
    assign o_wb_stb = '1;
    assign o_wb_cyc = '1;
    assign o_debug = '0;

    always_ff @(posedge i_clk)
    begin
        instr_ack <= i_wb_ack & (!bus_data) & instr_cyc;
    end

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

`ifdef TO_SIM
    assign  o_debug[0] = (!decode_bus.inst_supported) & (state_cur == STATE_RS);
`endif

endmodule
/* verilator lint_on UNUSEDSIGNAL */
