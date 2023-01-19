`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu1
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   decode_bus_t                i_bus,
`ifdef EXTENSION_Zicsr
    input   wire[31:0]                  i_ret_addr,
`endif
    input   wire[31:0]                  i_reg1_data,
    input   wire[31:0]                  i_reg2_data,
    output  alu1_bus_t                  o_bus
);

    logic[4:0]  rs1;
    logic[4:0]  rs2;
    logic[4:0]  rd;
    logic[31:0] imm_i;
    logic[31:0] imm_j;
    src_op1_t   op1_sel;
    src_op2_t   op2_sel;
    alu_res_t   alu_res;
    alu_ctrl_t  alu_ctrl;
    logic       inst_jalr, inst_jal, inst_branch;
    logic       inst_mret;
    logic[2:0]  funct3;
    logic       store;
    res_src_t   res_src;
    logic       reg_write;
    logic[31:0] pc;
    logic[31:0] pc_p4;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            inst_jal <= '0;
            inst_jalr <= '0;
            inst_branch <= '0;
            store <= '0;
            reg_write <= '0;
            res_src <= '0;
        end
        else
        begin
            rs1  <= i_bus.rs1;
            rs2  <= i_bus.rs2;
            rd   <= i_bus.rd;
            imm_i  <= i_bus.imm_i;
            imm_j  <= i_bus.imm_j;
            alu_res <= i_bus.alu_res;
            alu_ctrl <= i_bus.alu_ctrl;
            funct3  <= i_bus.funct3;
            res_src <= i_bus.res_src;
            op1_sel <= i_bus.op1_src;
            op2_sel <= i_bus.op2_src;
            reg_write   <= i_bus.reg_write;
            inst_jalr   <= i_bus.inst_jalr;
            inst_jal    <= i_bus.inst_jal;
            inst_branch <= i_bus.inst_branch;
            inst_mret   <= i_bus.inst_mret;
            store <= i_bus.inst_store;
            pc <= i_bus.pc;
            pc_p4 <= i_bus.pc_p4;
        end
    end

    logic[31:0] op1, op2;
    logic[31:0] pc_target;

    logic[31:0] pc_jalr, pc_jal;

    assign  pc_jalr = i_reg1_data + imm_i;
    assign  pc_jal  = pc        + imm_j;

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
        default:    op1 = i_reg1_data;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        op2_sel.i: op2 = imm_i;
        op2_sel.j: op2 = imm_j;
        default:   op2 = i_reg2_data;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = i_bus.inst_supported & op1_sel.r & op2_sel.r & (|rs1) & (|rs2) & i_bus.inst_ebreak
`ifdef EXTENSION_Zicsr
                & i_bus.csr_imm_sel & i_bus.csr_write
                & i_bus.csr_set & i_bus.csr_clear
                & (|i_bus.csr_idx) & (|i_bus.csr_imm)
                & i_bus.csr_read
`endif
                ;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_bus.op1 = op1;
    assign  o_bus.op2 = op2;
    assign  o_bus.alu_res = alu_res;
    assign  o_bus.alu_ctrl = alu_ctrl;
    assign  o_bus.store = store;
    assign  o_bus.reg_write = reg_write;
    assign  o_bus.rd = rd;
    assign  o_bus.inst_jal_jalr = inst_jal | inst_jalr
`ifdef EXTENSION_Zicsr
                | inst_mret
`endif
    ;
    assign  o_bus.inst_branch = inst_branch;
    assign  o_bus.pc_p4 = pc_p4;
    assign  o_bus.pc_target = pc_target;
    assign  o_bus.res_src = res_src;
    assign  o_bus.funct3 = funct3;
    assign  o_bus.reg_data2 = i_reg2_data;

endmodule
