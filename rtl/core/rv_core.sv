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
`ifdef EXTENSION_Zicsr
    // CSR interface
    output  wire[11:0]                  o_csr_idx,
    output  wire[4:0]                   o_csr_imm,
    output  wire                        o_csr_imm_sel,
    output  wire                        o_csr_write,
    output  wire                        o_csr_set,
    output  wire                        o_csr_clear,
    output  wire                        o_csr_read,
    output  wire                        o_csr_ebreak,
    output  wire[31:0]                  o_csr_pc_next,
    input   wire                        i_csr_to_trap,
    input   wire[31:0]                  i_csr_trap_pc,
    input   wire                        i_csr_read,
    input   wire[31:0]                  i_csr_ret_addr,
    input   wire[31:0]                  i_csr_data,
    output  wire[31:0]                  o_reg_rdata1,
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
`ifdef EXTENSION_Zicsr
    logic[31:0] ret_addr;
    assign  o_reg_rdata1 = reg_rdata1;
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
        STATE_FETCH: state_nxt = fetch_ready ? STATE_RS : STATE_FETCH;
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

    assign  o_data_req = (state_cur == STATE_ALU3) & (alu3_res_src.memory | alu3_store);

    logic[31:0] reg_rdata1, reg_rdata2;

    logic[31:0]             fetch_instruction;
    logic[31:0]             fetch_pc;
    logic                   fetch_ready;

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
    `ifdef EXTENSION_Zicsr
        .i_pc_trap                      (i_csr_trap_pc),
        .i_ebreak                       (i_csr_to_trap),
    `endif
        .i_fetch_start                  (state_cur == STATE_WR),
        //.i_pc_inc                       (state_cur == STATE_FETCH),
        //.i_data_latch                   (state_cur == STATE_FETCH),
        .i_instruction                  (i_instr_data),
        .i_ack                          (i_instr_ack),//(state_cur == STATE_FETCH),//(1'b1),
        .o_addr                         (o_instr_addr),
        .o_cyc                          (o_instr_req),
        .o_instruction                  (fetch_instruction),
        .o_pc                           (fetch_pc),
        .o_ready                        (fetch_ready)
    );

    logic[31:0] decode_pc;
    logic[31:0] decode_pc_next;
    logic[4:0]  decode_rs1;
    logic[4:0]  decode_rs2;
    logic[4:0]  decode_rd;
    logic[31:0] decode_imm_i;
    logic[31:0] decode_imm_j;
    alu_res_t   decode_alu_res;
    alu_ctrl_t  decode_alu_ctrl;
    logic[2:0]  decode_funct3;
    res_src_t   decode_res_src;
    logic       decode_reg_write;
    src_op1_t   decode_op1_src;
    src_op2_t   decode_op2_src;
`ifdef EXTENSION_Zicsr
    logic       decode_inst_mret;
`endif
    logic       decode_inst_jalr;
    logic       decode_inst_jal;
    logic       decode_inst_branch;
    logic       decode_inst_store;
    logic       decode_inst_ebreak;
    logic       decode_inst_supported;

    rv_decode
    u_st2_decode
    (
        .i_clk                          (i_clk),
        .i_instruction                  (fetch_instruction),
        .i_pc                           (fetch_pc),
`ifdef EXTENSION_Zicsr
        .o_csr_idx                      (o_csr_idx),
        .o_csr_imm                      (o_csr_imm),
        .o_csr_imm_sel                  (o_csr_imm_sel),
        .o_csr_write                    (o_csr_write),
        .o_csr_set                      (o_csr_set),
        .o_csr_clear                    (o_csr_clear),
        .o_csr_read                     (o_csr_read),
        .o_csr_ebreak                   (o_csr_ebreak),
        .o_csr_pc_next                  (o_csr_pc_next),
`endif
        .o_pc                           (decode_pc),
        .o_pc_next                      (decode_pc_next),
        .o_rs1                          (decode_rs1),
        .o_rs2                          (decode_rs2),
        .o_rd                           (decode_rd),
        .o_imm_i                        (decode_imm_i),
        .o_imm_j                        (decode_imm_j),
        .o_alu_res                      (decode_alu_res),
        .o_alu_ctrl                     (decode_alu_ctrl),
        .o_funct3                       (decode_funct3),
        .o_res_src                      (decode_res_src),
        .o_reg_write                    (decode_reg_write),
        .o_op1_src                      (decode_op1_src),
        .o_op2_src                      (decode_op2_src),
`ifdef EXTENSION_Zicsr
        .o_inst_mret                    (decode_inst_mret),
`endif
        .o_inst_jalr                    (decode_inst_jalr),
        .o_inst_jal                     (decode_inst_jal),
        .o_inst_branch                  (decode_inst_branch),
        .o_inst_store                   (decode_inst_store),
        .o_inst_ebreak                  (decode_inst_ebreak),
        .o_inst_supported               (decode_inst_supported)
    );

    logic[31:0] alu1_op1;
    logic[31:0] alu1_op2;
    alu_res_t   alu1_res;
    alu_ctrl_t  alu1_ctrl;
    logic       alu1_store;
    logic       alu1_reg_write;
    logic[4:0]  alu1_rd;
    logic       alu1_inst_jal_jalr;
    logic       alu1_inst_branch;
    logic[31:0] alu1_pc_next;
    logic[31:0] alu1_pc_target;
    res_src_t   alu1_res_src;
    logic[2:0]  alu1_funct3;
    logic[31:0] alu1_reg_data2;

    rv_alu1
    u_st3_alu1
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc                           (decode_pc),
        .i_pc_next                      (decode_pc_next),
        .i_rd                           (decode_rd),
        .i_imm_i                        (decode_imm_i),
        .i_imm_j                        (decode_imm_j),
        .i_alu_res                      (decode_alu_res),
        .i_alu_ctrl                     (decode_alu_ctrl),
        .i_funct3                       (decode_funct3),
        .i_res_src                      (decode_res_src),
        .i_reg_write                    (decode_reg_write),
        .i_op1_src                      (decode_op1_src),
        .i_op2_src                      (decode_op2_src),
`ifdef EXTENSION_Zicsr
        .i_inst_mret                    (decode_inst_mret),
`endif
        .i_inst_jalr                    (decode_inst_jalr),
        .i_inst_jal                     (decode_inst_jal),
        .i_inst_branch                  (decode_inst_branch),
        .i_inst_store                   (decode_inst_store),
`ifdef EXTENSION_Zicsr
        .i_ret_addr                     (i_csr_ret_addr),
`endif
        .i_reg1_data                    (reg_rdata1),
        .i_reg2_data                    (reg_rdata2),
        .o_op1                          (alu1_op1),
        .o_op2                          (alu1_op2),
        .o_res                          (alu1_res),
        .o_ctrl                         (alu1_ctrl),
        .o_store                        (alu1_store),
        .o_reg_write                    (alu1_reg_write),
        .o_rd                           (alu1_rd),
        .o_inst_jal_jalr                (alu1_inst_jal_jalr),
        .o_inst_branch                  (alu1_inst_branch),
        .o_pc_next                      (alu1_pc_next),
        .o_pc_target                    (alu1_pc_target),
        .o_res_src                      (alu1_res_src),
        .o_funct3                       (alu1_funct3),
        .o_reg_data2                    (alu1_reg_data2)
    );

    logic       alu2_cmp_result;
    logic       alu2_pc_select;
    logic[31:0] alu2_bits_result;
    logic[31:0] alu2_add;
    logic[31:0] alu2_shift_result;
    alu_res_t   alu2_res;
    logic       alu2_store;
    logic       alu2_reg_write;
    logic[4:0]  alu2_rd;
    logic[31:0] alu2_pc_next;
    logic[31:0] alu2_pc_target;
    res_src_t   alu2_res_src;
    logic[2:0]  alu2_funct3;
    logic[31:0] alu2_reg_data2;

    rv_alu2
    u_st4_alu2
    (   
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_op1                          (alu1_op1),
        .i_op2                          (alu1_op2),
        .i_res                          (alu1_res),
        .i_ctrl                         (alu1_ctrl),
        .i_store                        (alu1_store),
        .i_reg_write                    (alu1_reg_write),
        .i_rd                           (alu1_rd),
        .i_inst_jal_jalr                (alu1_inst_jal_jalr),
        .i_inst_branch                  (alu1_inst_branch),
        .i_pc_next                      (alu1_pc_next),
        .i_pc_target                    (alu1_pc_target),
        .i_res_src                      (alu1_res_src),
        .i_funct3                       (alu1_funct3),
        .i_reg_data2                    (alu1_reg_data2),
    `ifdef EXTENSION_Zicsr
        .i_csr_read                     (i_csr_read),
        .i_csr_data                     (i_csr_data),
    `endif
        .o_cmp_result                   (alu2_cmp_result),
        .o_pc_select                    (alu2_pc_select),
        .o_bits_result                  (alu2_bits_result),
        .o_add                          (alu2_add),
        .o_shift_result                 (alu2_shift_result),
        .o_res                          (alu2_res),
        .o_store                        (alu2_store),
        .o_reg_write                    (alu2_reg_write),
        .o_rd                           (alu2_rd),
        .o_pc_next                      (alu2_pc_next),
        .o_pc_target                    (alu2_pc_target),
        .o_res_src                      (alu2_res_src),
        .o_funct3                       (alu2_funct3),
        .o_reg_data2                    (alu2_reg_data2)
    );

    logic[2:0]  alu3_funct3;
    logic[31:0] alu3_result;
    logic[31:0] alu3_add;
    logic       alu3_reg_write;
    logic[4:0]  alu3_rd;
    res_src_t   alu3_res_src;
    logic[31:0] alu3_pc_next;
    logic       alu3_pc_select;
    logic[31:0] alu3_pc_target;
    logic       alu3_store;

    rv_alu3
    u_st4_alu3
    (   
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_cmp_result                   (alu2_cmp_result),
        .i_pc_select                    (alu2_pc_select),
        .i_bits_result                  (alu2_bits_result),
        .i_add                          (alu2_add),
        .i_shift_result                 (alu2_shift_result),
        .i_res                          (alu2_res),
        .i_store                        (alu2_store),
        .i_reg_write                    (alu2_reg_write),
        .i_rd                           (alu2_rd),
        .i_pc_next                      (alu2_pc_next),
        .i_pc_target                    (alu2_pc_target),
        .i_res_src                      (alu2_res_src),
        .i_funct3                       (alu2_funct3),
        .i_reg_data2                    (alu2_reg_data2),
        .o_wdata                        (o_data_wdata),
        .o_wsel                         (o_data_sel),
        .o_funct3                       (alu3_funct3),
        .o_alu_result                   (alu3_result),
        .o_add                          (alu3_add),
        .o_reg_write                    (alu3_reg_write),
        .o_rd                           (alu3_rd),
        .o_res_src                      (alu3_res_src),
        .o_pc_next                      (alu3_pc_next),
        .o_pc_select                    (alu3_pc_select),
        .o_pc_target                    (alu3_pc_target),
        .o_store                        (alu3_store)
    );

    assign  o_data_write = alu3_store;
    assign  o_data_addr = alu3_add;

    logic[2:0]  memory_funct3;
    logic[31:0] memory_result;
    logic       memory_reg_write;
    logic[4:0]  memory_rd;
    res_src_t   memory_res_src;
    logic[31:0] memory_pc_next;

    always_ff @(posedge i_clk)
    begin
        memory_funct3  <= alu3_funct3;
        memory_result <= alu3_result;
        memory_reg_write <= alu3_reg_write;
        memory_rd <= alu3_rd;
        memory_res_src <= alu3_res_src;
        memory_pc_next <= alu3_pc_next;
    end

    logic[31:0] write_data;
    logic[4:0]  write_rd;
    logic       write_op;
    
    rv_write
    u_st6_write
    (
        .i_clk                          (i_clk),
        .i_funct3                       (memory_funct3),
        .i_alu_result                   (memory_result),
        .i_reg_write                    (memory_reg_write),
        .i_rd                           (memory_rd),
        .i_res_src                      (memory_res_src),
        .i_pc_next                      (memory_pc_next),
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
        .i_rs1                          (decode_rs1),
        .i_rs2                          (decode_rs2),
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
    assign  o_debug[0] = (!decode_inst_supported) & (state_nxt == STATE_ALU1);
    assign  o_debug[31:1] = '0;
`endif

endmodule
/* verilator lint_on UNUSEDSIGNAL */
