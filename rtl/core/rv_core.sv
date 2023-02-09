`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"
`include "rv_opcodes.vh"

module rv_core
#(
    parameter logic[31:0] RESET_ADDR    = 32'h0000_0000,
    parameter int IADDR_SPACE_BITS      = 16,
    parameter logic BRANCH_PREDICTION   = 1,
    parameter int BRANCH_TABLE_SIZE_BITS= 2,
    parameter int INSTR_BUF_ADDR_SIZE   = 2, // buffer size is 2**N half-words (16 bit)
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_F         = 1,
    parameter logic EXTENSION_M         = 1,
    parameter logic EXTENSION_Zicsr     = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
`ifdef TO_SIM
    output  wire[31:0]                  o_debug,
`endif
    // CSR interface
    output  wire[11:0]                  o_csr_idx,
    output  wire[4:0]                   o_csr_imm,
    output  wire                        o_csr_imm_sel,
    output  wire                        o_csr_write,
    output  wire                        o_csr_set,
    output  wire                        o_csr_clear,
    output  wire                        o_csr_read,
    output  wire                        o_csr_ebreak,
    output  wire[IADDR_SPACE_BITS-1:0] o_csr_pc_next,
    input   wire                        i_csr_to_trap,
    input   wire[IADDR_SPACE_BITS-1:0]  i_csr_trap_pc,
    input   wire                        i_csr_read,
    input   wire[IADDR_SPACE_BITS-1:0]  i_csr_ret_addr,
    input   wire[31:0]                  i_csr_data,
    output  wire[31:0]                  o_reg_rdata1,
    // instruction interface
    output  wire                        o_instr_req,
    output  wire[IADDR_SPACE_BITS-1:0]  o_instr_addr,
    input   wire                        i_instr_ack,
    input   wire[31:0]                  i_instr_data,
    // data interface
    output  wire                        o_data_req,
    output  wire                        o_data_write,
    output  wire[31:0]                  o_data_addr,
    output  wire[31:0]                  o_data_wdata,
    output  wire[3:0]                   o_data_sel,
    input   wire                        i_data_ack,
    input   wire[31:0]                  i_data_rdata,
    output  wire                        o_instr_issued
);

    logic[31:0] reg_rdata1, reg_rdata2;

    logic[31:0] fetch_instruction;
    logic[IADDR_SPACE_BITS-1:0] fetch_pc;
    logic       fetch_branch_pred;
    logic       fetch_is_compressed;
    logic       fetch_ready;
    logic       fetch_stall;
    logic       fetch_flush;

    rv_fetch
    #(
        .RESET_ADDR                     (RESET_ADDR),
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .BRANCH_PREDICTION              (BRANCH_PREDICTION),
        .BRANCH_TABLE_SIZE_BITS         (BRANCH_TABLE_SIZE_BITS),
        .INSTR_BUF_ADDR_SIZE            (INSTR_BUF_ADDR_SIZE),
        .EXTENSION_C                    (EXTENSION_C),
        .EXTENSION_Zicsr                (EXTENSION_Zicsr)
    )
    u_st1_fetch
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_stall                        (fetch_stall),
        .i_flush                        (fetch_flush),
        .i_pc_br                        (alu2_pc),
        .i_pc_target                    (alu2_pc_target),
        .i_pc_select                    (alu2_pc_select),
        .i_pc_trap                      (i_csr_trap_pc),
        .i_ebreak                       (alu2_to_trap),
        .i_instruction                  (i_instr_data),
        .i_ack                          (i_instr_ack),
        .o_addr                         (o_instr_addr),
        .o_cyc                          (o_instr_req),
        .o_instruction                  (fetch_instruction),
        .o_pc                           (fetch_pc),
        .o_branch_pred                  (fetch_branch_pred),
        .o_is_compressed                (fetch_is_compressed),
        .o_ready                        (fetch_ready)
    );

    logic       decode_stall;
    logic       decode_flush;
    logic[IADDR_SPACE_BITS-1:0] decode_pc;
    logic[IADDR_SPACE_BITS-1:0] decode_pc_next;
    logic[4:0]  decode_rs1;
    logic[4:0]  decode_rs2;
    logic[4:0]  decode_rd;
    logic[31:0] decode_imm_i;
    logic[31:0] decode_imm_j;
    alu_res_t   decode_alu_res;
    logic[2:0]  decode_funct3;
    alu_ctrl_t  decode_alu_ctrl;
    res_src_t   decode_res_src;
    logic       decode_reg_write;
    logic       decode_op1_src;
    src_op2_t   decode_op2_src;
    logic       decode_inst_mret;
    logic       decode_inst_jalr;
    logic       decode_inst_jal;
    logic       decode_inst_branch;
    logic       decode_inst_store;
    logic       decode_inst_supported;
`ifdef TO_SIM
    logic[31:0] decode_instr;
`endif
    logic       decode_to_trap;
    logic       decode_inst_csr_req;
    logic       decode_branch_pred;

    rv_decode
    #(
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .EXTENSION_F                    (EXTENSION_F),
        .EXTENSION_M                    (EXTENSION_M),
        .EXTENSION_Zicsr                (EXTENSION_Zicsr)
    )
    u_st2_decode
    (
        .i_stall                        (decode_stall),
        .i_flush                        (decode_flush),
        .i_instruction                  (fetch_instruction),
        .i_ready                        (fetch_ready),
        .i_pc                           (fetch_pc),
        .i_branch_pred                  (fetch_branch_pred),
        .i_is_compressed                (fetch_is_compressed),
`ifdef TO_SIM
        .o_instr                        (decode_instr),
`endif
        .o_csr_idx                      (o_csr_idx),
        .o_csr_imm                      (o_csr_imm),
        .o_csr_imm_sel                  (o_csr_imm_sel),
        .o_csr_write                    (o_csr_write),
        .o_csr_set                      (o_csr_set),
        .o_csr_clear                    (o_csr_clear),
        .o_csr_read                     (o_csr_read),
        .o_csr_ebreak                   (o_csr_ebreak),
        .o_csr_pc_next                  (o_csr_pc_next),
        .o_pc                           (decode_pc),
        .o_branch_pred                  (decode_branch_pred),
        .o_pc_next                      (decode_pc_next),
        .o_rs1                          (decode_rs1),
        .o_rs2                          (decode_rs2),
        .o_rd                           (decode_rd),
        .o_imm_i                        (decode_imm_i),
        .o_imm_j                        (decode_imm_j),
        .o_alu_res                      (decode_alu_res),
        .o_funct3                       (decode_funct3),
        .o_alu_ctrl                     (decode_alu_ctrl),
        .o_res_src                      (decode_res_src),
        .o_reg_write                    (decode_reg_write),
        .o_op1_src                      (decode_op1_src),
        .o_op2_src                      (decode_op2_src),
        .o_inst_mret                    (decode_inst_mret),
        .o_inst_jalr                    (decode_inst_jalr),
        .o_inst_jal                     (decode_inst_jal),
        .o_inst_branch                  (decode_inst_branch),
        .o_inst_store                   (decode_inst_store),
        .o_inst_supported               (decode_inst_supported),
        .o_inst_csr_req                 (decode_inst_csr_req)
    );

    assign  decode_to_trap = i_csr_to_trap; // TODO - interrupts

    logic[31:0] data_hz1;
    logic[31:0] data_hz2;
    ctrl_rs_bp_t rs1_bp;
    ctrl_rs_bp_t rs2_bp;

    rv_hazard
    u_dhz1
    (
        .i_reg_data                     (reg_rdata1),
        .i_alu2_data                    (alu2_result),
        .i_wr_data                      (write_data),
        .i_wr_back_data                 (wr_back_data),
        .i_bp                           (rs1_bp),
        .o_data                         (data_hz1)
    );

    rv_hazard
    u_dhz2
    (
        .i_reg_data                     (reg_rdata2),
        .i_alu2_data                    (alu2_result),
        .i_wr_data                      (write_data),
        .i_wr_back_data                 (wr_back_data),
        .i_bp                           (rs2_bp),
        .o_data                         (data_hz2)
    );

    logic[31:0] alu1_op1;
    logic[31:0] alu1_op2;
    alu_res_t   alu1_res;
    logic       alu1_store;
    logic       alu1_reg_write;
    logic[4:0]  alu1_rs1;
    logic[4:0]  alu1_rs2;
    logic[4:0]  alu1_rd;
    logic       alu1_inst_jal_jalr;
    logic       alu1_inst_branch;
    logic[IADDR_SPACE_BITS-1:0] alu1_pc;
    logic[IADDR_SPACE_BITS-1:0] alu1_pc_next;
    logic[IADDR_SPACE_BITS-1:0] alu1_pc_target;
    res_src_t   alu1_res_src;
    logic[2:0]  alu1_funct3;
    alu_ctrl_t  alu1_alu_ctrl;
    logic[31:0] alu1_reg_data1;
    logic[31:0] alu1_reg_data2;
    logic       alu1_flush;
    logic       alu1_to_trap;
    logic       alu1_branch_pred;

    rv_alu1
    #(
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS)
    )
    u_st3_alu1
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_flush                        (alu1_flush),
        .i_pc                           (decode_pc),
        .i_pc_next                      (decode_pc_next),
        .i_branch_pred                  (decode_branch_pred),
        .i_rs1                          (decode_rs1),
        .i_rs2                          (decode_rs2),
        .i_rd                           (decode_rd),
        .i_imm_i                        (decode_imm_i),
        .i_imm_j                        (decode_imm_j),
        .i_alu_res                      (decode_alu_res),
        .i_funct3                       (decode_funct3),
        .i_alu_ctrl                     (decode_alu_ctrl),
        .i_res_src                      (decode_res_src),
        .i_reg_write                    (decode_reg_write),
        .i_op1_src                      (decode_op1_src),
        .i_op2_src                      (decode_op2_src),
        .i_inst_mret                    (decode_inst_mret),
        .i_inst_jalr                    (decode_inst_jalr),
        .i_inst_jal                     (decode_inst_jal),
        .i_inst_branch                  (decode_inst_branch),
        .i_inst_store                   (decode_inst_store),
        .i_ret_addr                     (i_csr_ret_addr),
        .i_reg1_data                    (data_hz1),
        .i_reg2_data                    (data_hz2),
        .i_to_trap                      (decode_to_trap),
        .o_op1                          (alu1_op1),
        .o_op2                          (alu1_op2),
        .o_res                          (alu1_res),
        .o_store                        (alu1_store),
        .o_reg_write                    (alu1_reg_write),
        .o_rs1                          (alu1_rs1),
        .o_rs2                          (alu1_rs2),
        .o_rd                           (alu1_rd),
        .o_inst_jal_jalr                (alu1_inst_jal_jalr),
        .o_inst_branch                  (alu1_inst_branch),
        .o_pc                           (alu1_pc),
        .o_pc_next                      (alu1_pc_next),
        .o_branch_pred                  (alu1_branch_pred),
        .o_pc_target                    (alu1_pc_target),
        .o_res_src                      (alu1_res_src),
        .o_funct3                       (alu1_funct3),
        .o_alu_ctrl                     (alu1_alu_ctrl),
        .o_reg_data1                    (alu1_reg_data1),
        .o_reg_data2                    (alu1_reg_data2),
        .o_to_trap                      (alu1_to_trap)
    );

    logic       alu2_pc_select;
    logic[31:0] alu2_result;
    logic[31:0] alu2_add;
    logic       alu2_store;
    logic       alu2_reg_write;
    logic[4:0]  alu2_rd;
    logic[IADDR_SPACE_BITS-1:0] alu2_pc;
    logic[IADDR_SPACE_BITS-1:0] alu2_pc_target;
    res_src_t   alu2_res_src;
    logic[2:0]  alu2_funct3;
    logic       alu2_flush;
    logic       alu2_to_trap;

    rv_alu2
    #(
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .BRANCH_PREDICTION              (BRANCH_PREDICTION),
        .EXTENSION_Zicsr                (EXTENSION_Zicsr),
        .EXTENSION_M                    (EXTENSION_M)
    )
    u_st4_alu2
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_flush                        (alu2_flush),
        .i_op1                          (alu1_op1),
        .i_op2                          (alu1_op2),
        .i_res                          (alu1_res),
        .i_store                        (alu1_store),
        .i_reg_write                    (alu1_reg_write),
        .i_rd                           (alu1_rd),
        .i_inst_jal_jalr                (alu1_inst_jal_jalr),
        .i_inst_branch                  (alu1_inst_branch),
        .i_pc                           (alu1_pc),
        .i_pc_next                      (alu1_pc_next),
        .i_branch_pred                  (alu1_branch_pred),
        .i_pc_target                    (alu1_pc_target),
        .i_res_src                      (alu1_res_src),
        .i_funct3                       (alu1_funct3),
        .i_alu_ctrl                     (alu1_alu_ctrl),
        .i_reg_data2                    (alu1_reg_data2),
        .i_csr_read                     (i_csr_read),
        .i_csr_data                     (i_csr_data),
        .i_to_trap                      (alu1_to_trap),
        .o_pc_select                    (alu2_pc_select),
        .o_result                       (alu2_result),
        .o_add                          (alu2_add),
        .o_store                        (alu2_store),
        .o_reg_write                    (alu2_reg_write),
        .o_rd                           (alu2_rd),
        .o_pc                           (alu2_pc),
        .o_pc_target                    (alu2_pc_target),
        .o_res_src                      (alu2_res_src),
        .o_wdata                        (o_data_wdata),
        .o_wsel                         (o_data_sel),
        .o_funct3                       (alu2_funct3),
        .o_to_trap                      (alu2_to_trap)
    );

    logic[31:0] write_data;
    logic[4:0]  write_rd;
    logic       write_op;

    rv_write
    u_st5_write
    (
        .i_clk                          (i_clk),
        .i_funct3                       (alu2_funct3),
        .i_alu_result                   (alu2_result),
        .i_reg_write                    (alu2_reg_write),
        .i_rd                           (alu2_rd),
        .i_res_src                      (alu2_res_src),
        .i_data                         (i_data_rdata),
        .o_data                         (write_data),
        .o_rd                           (write_rd),
        .o_write_op                     (write_op)
    );

`ifdef TO_SIM
    logic[4:0]  trace_rd;
    logic[31:0] trace_rd_data;
`endif

    logic[31:0] wr_back_data;
    logic[4:0]  wr_back_rd;
    logic       wr_back_op;
    always_ff @(posedge i_clk)
    begin
        wr_back_rd <= write_rd;
        wr_back_data <= write_data;
        wr_back_op <= write_op;
    end

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
`ifdef TO_SIM
        .i_rd_tr                        (trace_rd),
        .o_rd_tr                        (trace_rd_data),
`endif
        .o_data1                        (reg_rdata1),
        .o_data2                        (reg_rdata2)
    );

    logic   inv_inst;
    logic   ctrl_pc_change;
    logic   ctrl_need_pause;
    assign  ctrl_pc_change = alu2_pc_select | (alu2_to_trap & EXTENSION_Zicsr);
    assign  ctrl_need_pause = decode_inst_csr_req & (alu1_inst_jal_jalr | alu1_inst_branch);
    rv_ctrl
    u_ctrl
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc_change                    (ctrl_pc_change),
        .i_decode_inst_sup              (decode_inst_supported),
        .i_decode_rs1                   (decode_rs1),
        .i_decode_rs2                   (decode_rs2),
        .i_alu_rs1                      (alu1_rs1),
        .i_alu_rs2                      (alu1_rs2),
        .i_alu1_mem_rd                  (alu1_res_src.memory),
        .i_alu1_rd                      (alu1_rd),
        .i_alu2_rd                      (alu2_rd),
        .i_alu2_reg_write               (alu2_reg_write),
        .i_write_rd                     (write_rd),
        .i_write_reg_write              (write_op),
        .i_wr_back_rd                   (wr_back_rd),
        .i_wr_back_reg_write            (wr_back_op),
        .i_need_pause                   (ctrl_need_pause),
        .o_fetch_flush                  (fetch_flush),
        .o_fetch_stall                  (fetch_stall),
        .o_decode_flush                 (decode_flush),
        .o_decode_stall                 (decode_stall),
        .o_rs1_bp                       (rs1_bp),
        .o_rs2_bp                       (rs2_bp),
        .o_alu1_flush                   (alu1_flush),
        .o_alu2_flush                   (alu2_flush),
        .o_inv_inst                     (inv_inst)
    );

`ifdef TO_SIM
    rv_trace
    #(
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS)
    )
    u_trace
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc                           (decode_pc),
        .i_instr                        (decode_instr),
        .i_bus_data                     (i_data_rdata),
        .i_mem_addr                     (alu2_add),
        .i_mem_sel                      (o_data_sel),
        .i_mem_data                     (o_data_wdata),
        .i_reg_write                    (decode_reg_write),
        .i_mem_write                    (decode_inst_store),
        .i_mem_read                     (decode_res_src.memory),
        .i_reg_data                     (write_data),
        .i_exec2_flush                  (alu2_flush),
        .i_exec_flush                   (alu1_flush),
        .o_rd                           (trace_rd),
        .i_rd                           (trace_rd_data)
    );
`endif

    logic   data_req;
    assign  data_req = (alu2_res_src.memory | alu2_store);

    assign  o_data_req = data_req;
    assign  o_data_write = alu2_store;
    assign  o_data_addr = alu2_add;
    assign  o_instr_issued = (data_req | alu2_reg_write);
    assign  o_reg_rdata1 = alu1_reg_data1;

`ifdef TO_SIM
    assign  o_debug[0] = inv_inst;
    assign  o_debug[31:1] = '0;
`endif

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_data_ack;
/* verilator lint_on UNUSEDSIGNAL */

endmodule
