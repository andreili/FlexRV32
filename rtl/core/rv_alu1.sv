`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu1
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   ctrl_rs_bp_t                i_rs1_bp,
    input   ctrl_rs_bp_t                i_rs2_bp,
    input   wire[31:0]                  i_alu2_data,
    input   wire[31:0]                  i_memory_data,
    input   wire[31:0]                  i_write_data,
    input   wire[31:0]                  i_wr_back_data,
    input   wire[31:0]                  i_pc,
    input   wire[31:0]                  i_pc_next,
    input   wire[4:0]                   i_rs1,
    input   wire[4:0]                   i_rs2,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_imm_i,
    input   wire[31:0]                  i_imm_j,
    input   alu_res_t                   i_alu_res,
    input   alu_ctrl_t                  i_alu_ctrl,
    input   wire[2:0]                   i_funct3,
    input   res_src_t                   i_res_src,
    input   wire                        i_reg_write,
    input   src_op1_t                   i_op1_src,
    input   src_op2_t                   i_op2_src,
`ifdef EXTENSION_Zicsr
    input   wire                        i_inst_mret,
`endif
    input   wire                        i_inst_jalr,
    input   wire                        i_inst_jal,
    input   wire                        i_inst_branch,
    input   wire                        i_inst_store,
`ifdef EXTENSION_Zicsr
    input   wire[31:0]                  i_ret_addr,
`endif
    input   wire[31:0]                  i_reg1_data,
    input   wire[31:0]                  i_reg2_data,
    output  wire[31:0]                  o_op1,
    output  wire[31:0]                  o_op2,
    output  alu_res_t                   o_res,
    output  alu_ctrl_t                  o_ctrl,
    output  wire                        o_store,
    output  wire                        o_reg_write,
    output  wire[4:0]                   o_rs1,
    output  wire[4:0]                   o_rs2,
    output  wire[4:0]                   o_rd,
    output  wire                        o_inst_jal_jalr,
    output  wire                        o_inst_branch,
    output  wire[31:0]                  o_pc_next,
    output  wire[31:0]                  o_pc_target,
    output  res_src_t                   o_res_src,
    output  wire[2:0]                   o_funct3,
    output  wire[31:0]                  o_reg_data2
);

    logic[4:0]  rs1, rs2;
    logic[4:0]  rd;
    logic[31:0] imm_i;
    logic[31:0] imm_j;
    src_op1_t   op1_sel;
    src_op2_t   op2_sel;
    alu_res_t   res;
    alu_ctrl_t  ctrl;
    logic       inst_jalr, inst_jal, inst_branch;
`ifdef EXTENSION_Zicsr
    logic       inst_mret;
`endif
    logic[2:0]  funct3;
    logic       store;
    res_src_t   res_src;
    logic       reg_write;
    logic[31:0] pc;
    logic[31:0] pc_next;

    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | i_flush)
        begin
            rs1 <= '0;
            rs2 <= '0;
            rd <= '0;
            inst_jal <= '0;
            inst_jalr <= '0;
            inst_branch <= '0;
            store <= '0;
            reg_write <= '0;
            res_src <= '0;
`ifdef EXTENSION_Zicsr
            inst_mret <= '0;
`endif
        end
        else if (!i_stall)
        begin
            rs1 <= i_rs1;
            rs2 <= i_rs2;
            rd   <= i_rd;
            imm_i  <= i_imm_i;
            imm_j  <= i_imm_j;
            res <= i_alu_res;
            ctrl <= i_alu_ctrl;
            funct3  <= i_funct3;
            res_src <= i_res_src;
            op1_sel <= i_op1_src;
            op2_sel <= i_op2_src;
            reg_write   <= i_reg_write;
            inst_jalr   <= i_inst_jalr;
            inst_jal    <= i_inst_jal;
            inst_branch <= i_inst_branch;
`ifdef EXTENSION_Zicsr
            inst_mret   <= i_inst_mret;
`endif
            store <= i_inst_store;
            pc <= i_pc;
            pc_next <= i_pc_next;
        end
    end

    logic[31:0] bp1, bp2;

    always_comb
    begin
        case (1'b1)
        i_rs1_bp.alu2:    bp1 = i_alu2_data;
        i_rs1_bp.memory:  bp1 = i_memory_data;
        i_rs1_bp.write:   bp1 = i_write_data;
        i_rs1_bp.wr_back: bp1 = i_wr_back_data;
        default:          bp1 = i_reg1_data;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        i_rs2_bp.alu2:    bp2 = i_alu2_data;
        i_rs2_bp.memory:  bp2 = i_memory_data;
        i_rs2_bp.write:   bp2 = i_write_data;
        i_rs2_bp.wr_back: bp2 = i_wr_back_data;
        default:          bp2 = i_reg2_data;
        endcase
    end

    logic[31:0] op1, op2;
    logic[31:0] pc_target;

    logic[31:0] pc_jalr, pc_jal;

    assign  pc_jalr = bp1 + imm_i;
    assign  pc_jal  = pc  + imm_j;

    always_comb
    begin
        case (1'b1)
`ifdef EXTENSION_Zicsr
        inst_mret: pc_target = i_ret_addr;
`endif
        inst_jalr: pc_target = pc_jalr;
        default:   pc_target = pc_jal;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        op1_sel.pc: op1 = pc;
        default:    op1 = bp1;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        op2_sel.i: op2 = imm_i;
        op2_sel.j: op2 = imm_j;
        default:   op2 = bp2;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = op1_sel.r & op2_sel.r;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_op1 = op1;
    assign  o_op2 = op2;
    assign  o_res = res;
    assign  o_ctrl = ctrl;
    assign  o_store = store;
    assign  o_reg_write = reg_write;
    assign  o_rs1 = rs1;
    assign  o_rs2 = rs2;
    assign  o_rd = rd;
    assign  o_inst_jal_jalr = inst_jal | inst_jalr
`ifdef EXTENSION_Zicsr
                | inst_mret
`endif
    ;
    assign  o_inst_branch = inst_branch;
    assign  o_pc_next = pc_next;
    assign  o_pc_target = pc_target;
    assign  o_res_src = res_src;
    assign  o_funct3 = funct3;
    assign  o_reg_data2 = bp2;

endmodule
