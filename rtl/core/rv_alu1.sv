`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"

module rv_alu1
#(
    parameter int IADDR_SPACE_BITS      = 16
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_flush,
    input   wire                        i_stall,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
    input   wire[4:0]                   i_rs1,
    input   wire[4:0]                   i_rs2,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_imm_i,
    input   wire[2:0]                   i_funct3,
    input   alu_ctrl_t                  i_alu_ctrl,
    input   res_src_t                   i_res_src,
    input   wire                        i_reg_write,
    input   wire                        i_op1_src,
    input   wire                        i_op2_src,
    input   wire                        i_inst_mret,
    input   wire                        i_inst_jalr,
    input   wire                        i_inst_jal,
    input   wire                        i_inst_branch,
    input   wire                        i_inst_store,
    input   wire[IADDR_SPACE_BITS-1:1]  i_ret_addr,
    input   wire[31:0]                  i_reg1_data,
    input   wire[31:0]                  i_reg2_data,
    input   wire                        i_to_trap,
    output  wire[31:0]                  o_op1,
    output  wire[31:0]                  o_op2,
    output  wire                        o_store,
    output  wire                        o_reg_write,
    output  wire[4:0]                   o_rs1,
    output  wire[4:0]                   o_rs2,
    output  wire[4:0]                   o_rd,
    output  wire                        o_inst_jal_jalr,
    output  wire                        o_inst_branch,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_next,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_target,
    output  res_src_t                   o_res_src,
    output  wire[2:0]                   o_funct3,
    output  alu_ctrl_t                  o_alu_ctrl,
    output  wire                        o_to_trap
);

    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[4:0]  rd;
    logic[31:0] imm_i;
    logic       op1_sel;
    logic       op2_sel;
    logic       inst_jalr, inst_jal, inst_branch;
    logic       inst_mret;
    logic[2:0]  funct3;
    alu_ctrl_t  alu_ctrl;
    logic       store;
    res_src_t   res_src;
    logic       reg_write;
    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic       to_trap;

    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | i_flush)
        begin
            rd <= '0;
            rs1 <= '0;
            rs2 <= '0;
            inst_jal <= '0;
            inst_jalr <= '0;
            inst_branch <= '0;
            store <= '0;
            reg_write <= '0;
            res_src <= '0;
            inst_mret <= '0;
            to_trap <= '0;
            alu_ctrl <= '0;
        end
        else if (!i_stall)
        begin
            rs1  <= i_rs1;
            rs2  <= i_rs2;
            rd   <= i_rd;
            imm_i  <= i_imm_i;
            funct3  <= i_funct3;
            alu_ctrl <= i_alu_ctrl;
            res_src <= i_res_src;
            op1_sel <= i_op1_src;
            op2_sel <= i_op2_src;
            reg_write   <= i_reg_write;
            inst_jalr   <= i_inst_jalr;
            inst_jal    <= i_inst_jal;
            inst_branch <= i_inst_branch;
            inst_mret   <= i_inst_mret;
            store <= i_inst_store;
            pc <= i_pc;
            pc_next <= i_pc_next;
            to_trap <= i_to_trap;
        end
    end

    logic[31:0] op1, op2;

    assign  op1 = op1_sel ? { {(32-IADDR_SPACE_BITS){1'b0}}, pc, 1'b0 } :
                  //alu_ctrl.div_mux ? i_reg2_data :
                  i_reg1_data;
    assign  op2 = op2_sel  ? imm_i :
                  //alu_ctrl.div_mux ? i_reg1_data :
                  i_reg2_data;

    logic[IADDR_SPACE_BITS-1:1] pc_target_base, pc_target_offset, pc_target;

    assign  pc_target_base   = inst_mret ? i_ret_addr :
                               inst_jalr ? i_reg1_data[IADDR_SPACE_BITS-1:1] :
                               pc;
    assign  pc_target_offset = inst_mret ? '0 : imm_i[IADDR_SPACE_BITS-1:1];
/* verilator lint_off PINCONNECTEMPTY */
    add
    #(
        .WIDTH                          (IADDR_SPACE_BITS - 1)
    )
    u_pc_inc
    (
        .i_carry                        (1'b0),
        .i_op1                          (pc_target_base),
        .i_op2                          (pc_target_offset),
        .o_add                          (pc_target),
        .o_carry                        ()
    );
/* verilator lint_on  PINCONNECTEMPTY */

    assign  o_op1 = op1;
    assign  o_op2 = op2;
    assign  o_store = store;
    assign  o_reg_write = reg_write;
    assign  o_rs1 = rs1;
    assign  o_rs2 = rs2;
    assign  o_rd = rd;
    assign  o_inst_jal_jalr = inst_jal | inst_jalr | inst_mret;
    assign  o_inst_branch = inst_branch;
    assign  o_pc = pc;
    assign  o_pc_next = pc_next;
    assign  o_pc_target = pc_target;
    assign  o_res_src = res_src;
    assign  o_funct3 = funct3;
    assign  o_alu_ctrl = alu_ctrl;
    assign  o_to_trap = to_trap;

endmodule
