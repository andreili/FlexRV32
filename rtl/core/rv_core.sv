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
        .i_pc_target                    (alu3_pc_target),
        .i_pc_select                    (alu3_pc_select),
        .i_pc_inc                       (state_cur == STATE_FETCH),
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

    logic[4:0]  alu_rs1;
    logic[4:0]  alu_rs2;
    logic[4:0]  alu_rd;
    logic[31:0] alu_imm_i;
    logic[31:0] alu_imm_j;
`ifdef EXTENSION_C
    logic[31:0] alu_imm_c;
    logic       alu_compressed;
`endif
    src_op1_t   alu_op1_sel;
    src_op2_t   alu_op2_sel;
    alu_ctrl_t  alu_ctrl;
    logic       alu_inst_jalr, alu_inst_jal, alu_inst_branch;
    logic[2:0]  alu_funct3;
    logic       alu_store;
    res_src_t   alu_res_src;
    logic       alu_reg_write;
    logic[31:0] alu_pc;

    always_ff @(posedge i_clk)
    begin
        alu_rs1  <= decode_bus.rs1;
        alu_rs2  <= decode_bus.rs2;
        alu_rd   <= decode_bus.rd;
        alu_imm_i  <= decode_bus.imm_i;
        alu_imm_j  <= decode_bus.imm_j;
    `ifdef EXTENSION_C
        alu_imm_c  <= decode_bus.imm_c;
        alu_compressed <= decode_bus.inst_compressed;
    `endif
        alu_ctrl <= decode_bus.alu_ctrl;
        alu_funct3  <= decode_bus.funct3;
        alu_res_src <= decode_bus.res_src;
        alu_op1_sel <= decode_bus.op1_src;
        alu_op2_sel <= decode_bus.op2_src;
        alu_reg_write   <= decode_bus.reg_write;
        alu_inst_jalr   <= decode_bus.inst_jalr;
        alu_inst_jal    <= decode_bus.inst_jal;
        alu_inst_branch <= decode_bus.inst_branch;
        alu_store <= decode_bus.inst_store;
        alu_pc <= decode_bus.pc;
    end

    logic[31:0] alu_reg_data1, alu_reg_data2;
    logic[31:0] alu_op1, alu_op2;
    logic[31:0] alu_pc_target;

    assign  alu_reg_data1 = (|alu_rs1) ? reg_rdata1 : '0;
    assign  alu_reg_data2 = (|alu_rs2) ? reg_rdata2 : '0;

    logic[31:0] pc_jalr, pc_jal/*, pc_branch*/;

    assign  pc_jalr   = alu_reg_data1 + alu_imm_i;
    assign  pc_jal    = alu_pc + alu_imm_j;

    always_comb
    begin
        case (1'b1)
        alu_inst_jalr:   alu_pc_target = pc_jalr;
        default:    alu_pc_target = pc_jal;
        //default:         alu_pc_target = alu_pc;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        alu_op1_sel.pc: alu_op1 = alu_pc;
        default:        alu_op1 = alu_reg_data1;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        alu_op2_sel.i: alu_op2 = alu_imm_i;
        alu_op2_sel.j: alu_op2 = alu_imm_j;
    `ifdef EXTENSION_C
        alu_op2_sel.c: alu_op2 = alu_imm_c;
    `endif
        default:       alu_op2 = alu_reg_data2;
        endcase
    end

    logic[31:0] alu2_op1, alu2_op2;
    logic       alu2_eq, alu2_lts, alu2_ltu;
    logic[32:0] alu2_add;
    logic[31:0] alu2_xor, alu2_or, alu2_and, alu2_shl;
    logic[32:0] alu2_shr;
    logic[31:0] alu2_shift_result;
    logic       alu2_cmp_result;
    logic[31:0] alu2_bits_result;
    logic       alu2_carry;
    logic       alu2_op_b_sel;
    logic[31:0] alu2_op_b;
    logic       alu2_negative;
    logic       alu2_overflow;
    alu_ctrl_t  alu2_ctrl;
    logic       alu2_store;
    logic       alu2_reg_write;
    logic[4:0]  alu2_rd;
    logic       alu2_inst_jal_jalr, alu2_inst_branch;
    logic[31:0] alu2_pc;
    logic[31:0] alu2_pc_target;
    res_src_t   alu2_res_src;
    logic[2:0]  alu2_funct3;
    logic[31:0] alu2_reg_data2;
`ifdef EXTENSION_C
    logic       alu2_compressed;
`endif
    
    always_ff @(posedge i_clk)
    begin
        alu2_op1 <= alu_op1;
        alu2_op2 <= alu_op2;
        alu2_ctrl <= alu_ctrl;
        alu2_store <= alu_store;
        alu2_reg_write <= alu_reg_write;
        alu2_rd <= alu_rd;
        alu2_inst_jal_jalr <= alu_inst_jal | alu_inst_jalr;
        alu2_inst_branch <= alu_inst_branch;
        alu2_pc <= alu_pc;
        alu2_pc_target <= alu_pc_target;
        alu2_res_src <= alu_res_src;
        alu2_funct3 <= alu_funct3;
        alu2_reg_data2 <= alu_reg_data2;
    `ifdef EXTENSION_C
        alu2_compressed <= alu_compressed;
    `endif
    end

    // adder - for all (add/sub/cmp)
    assign  alu2_op_b_sel = (alu2_ctrl.arith_sub | alu2_ctrl.res_cmp | alu2_ctrl.res_shift);
    assign  alu2_op_b     = alu2_op_b_sel ? (~alu2_op2) : alu2_op2;
    assign  alu2_add      = alu2_op1 + alu2_op_b + { {32{1'b0}}, alu2_op_b_sel};
    assign  alu2_negative = alu2_add[31];
    assign  alu2_overflow = (alu2_op1[31] ^ alu2_op2[31]) & (alu2_op1[31] ^ alu2_add[31]);
    assign  alu2_carry    = alu2_add[32];

    assign  alu2_eq  = alu2_ctrl.cmp_inversed ^ (alu2_op1 == alu2_op2);
    assign  alu2_lts = alu2_ctrl.cmp_inversed ^ (alu2_negative ^ alu2_overflow);
    assign  alu2_ltu = alu2_ctrl.cmp_inversed ^ (!alu2_carry);

    assign  alu2_xor = alu2_op1 ^ alu2_op2;
    assign  alu2_or  = alu2_op1 | alu2_op2;
    assign  alu2_and = alu2_op1 & alu2_op2;
    assign  alu2_shl = alu2_op1 << alu2_op2[4:0];
    assign  alu2_shr = $signed({alu2_ctrl.shift_arithmetical ? alu2_op1[31] : 1'b0, alu2_op1}) >>> alu2_op2[4:0];

    always_comb
    begin
        case (1'b1)
        alu2_ctrl.cmp_lts: alu2_cmp_result = alu2_lts;
        alu2_ctrl.cmp_ltu: alu2_cmp_result = alu2_ltu;
        default:           alu2_cmp_result = alu2_eq;
        endcase
    end

    logic   alu2_pc_select;
    assign  alu2_pc_select = /*(!fetch_bp_need) & */(alu2_inst_jal_jalr | (alu2_inst_branch & (alu2_cmp_result)));

    always_comb
    begin
        case (1'b1)
        alu2_ctrl.bits_xor: alu2_bits_result = alu2_xor;
        alu2_ctrl.bits_or:  alu2_bits_result = alu2_or;
        default:            alu2_bits_result = alu2_and;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        alu2_ctrl.arith_shr: alu2_shift_result = alu2_shr[31:0];
        default:             alu2_shift_result = alu2_shl;
        endcase
    end

    logic       alu3_cmp_result;
    logic       alu3_pc_select;
    logic[31:0] alu3_bits_result;
    logic[31:0] alu3_add;
    logic[31:0] alu3_shift_result;
    logic[31:0] alu3_result;
    alu_ctrl_t  alu3_ctrl;
    logic       alu3_store;
    logic       alu3_reg_write;
    logic[4:0]  alu3_rd;
    logic       alu3_inst_jalr, alu3_inst_jal, alu3_inst_branch;
    logic[31:0] alu3_pc;
    logic[31:0] alu3_pc_target;
    res_src_t   alu3_res_src;
    logic[2:0]  alu3_funct3;
    logic[31:0] alu3_reg_data2;
`ifdef EXTENSION_C
    logic       alu3_compressed;
`endif

    always_ff @(posedge i_clk)
    begin
        alu3_bits_result <= alu2_bits_result;
        alu3_pc_select <= alu2_pc_select;
        alu3_cmp_result <= alu2_cmp_result;
        alu3_add <= alu2_add[31:0];
        alu3_shift_result <= alu2_shift_result;
        alu3_ctrl <= alu2_ctrl;
        alu3_store <= alu2_store;
        alu3_reg_write <= alu2_reg_write;
        alu3_rd <= alu2_rd;
        alu3_pc <= alu2_pc;
        alu3_pc_target <= alu2_pc_target;
        alu3_res_src <= alu2_res_src;
        alu3_funct3 <= alu2_funct3;
        alu3_reg_data2 <= alu2_reg_data2;
    `ifdef EXTENSION_C
        alu3_compressed <= alu2_compressed;
    `endif
    end

    always_comb
    begin
        case (1'b1)
        alu3_ctrl.res_cmp:   alu3_result = { {31{1'b0}}, alu3_cmp_result };
        alu3_ctrl.res_bits:  alu3_result = alu3_bits_result;
        alu3_ctrl.res_shift: alu3_result = alu3_shift_result;
        default:             alu3_result = alu3_add[31:0];
        endcase
    end

    always_comb
    begin
        case (alu3_funct3[1:0])
        2'b00:   memory_wdata = {4{alu3_reg_data2[0+: 8]}};
        2'b01:   memory_wdata = {2{alu3_reg_data2[0+:16]}};
        default: memory_wdata = alu3_reg_data2;
        endcase
    end

    always_comb
    begin
        case (alu3_funct3[1:0])
        2'b00: begin
            case (alu3_result[1:0])
            2'b00: memory_sel = 4'b0001;
            2'b01: memory_sel = 4'b0010;
            2'b10: memory_sel = 4'b0100;
            2'b11: memory_sel = 4'b1000;
            endcase
        end
        2'b01: begin
            case (alu3_result[1])
            1'b0: memory_sel = 4'b0011;
            1'b1: memory_sel = 4'b1100;
            endcase
        end
        default:  memory_sel = 4'b1111;
        endcase
    end

    logic[2:0]  memory_funct3;
    logic[31:0] memory_alu_result;
    logic[31:0] memory_wdata;
    logic[3:0]  memory_sel;
    logic       memory_reg_write;
    logic[4:0]  memory_rd;
    res_src_t   memory_res_src;
    logic[31:0] memory_pc;
`ifdef EXTENSION_C
    logic       memory_compressed;
`endif

    always_ff @(posedge i_clk)
    begin
        memory_funct3  <= alu3_funct3;
        memory_alu_result <= alu3_result;
        memory_reg_write <= alu3_reg_write;
        memory_rd <= alu3_rd;
        memory_res_src <= alu3_res_src;
        memory_pc <= alu3_pc;
    `ifdef EXTENSION_C
        memory_compressed <= alu3_compressed;
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
        //write_wdata <= write_rdata;
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

    assign  bus_data = (state_cur == STATE_ALU3) & (alu3_res_src.memory | alu3_store);

    assign o_wb_adr = bus_data ? alu3_add : fetch_addr;
    assign o_wb_dat = memory_wdata;
    assign o_wb_we = bus_data ? alu3_store : '0;
    assign o_wb_sel = bus_data ? memory_sel : '1;
    assign o_wb_stb = '1;
    assign o_wb_cyc = '1;
    assign o_debug = '0;

    /*always_ff @(posedge i_clk)
    begin
        instr_ack <= i_wb_ack & (!bus_data) & instr_cyc;
    end*/
    assign  instr_ack = i_wb_ack & (!bus_data) & instr_cyc;

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

endmodule
/* verilator lint_on UNUSEDSIGNAL */
