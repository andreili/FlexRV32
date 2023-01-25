`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu2
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_flush,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    input   alu_res_t                   i_res,
    input   alu_ctrl_t                  i_ctrl,
    input   wire                        i_store,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire                        i_inst_jal_jalr,
    input   wire                        i_inst_branch,
    input   wire[31:0]                  i_pc_next,
    input   wire                        i_branch_pred,
    input   wire[31:0]                  i_pc_target_base,
    input   wire[31:0]                  i_pc_target_offset,
    input   res_src_t                   i_res_src,
    input   wire[2:0]                   i_funct3,
    input   wire[31:0]                  i_reg_data2,
    input   wire                        i_csr_read,
    input   wire[31:0]                  i_csr_data,
    input   wire                        i_to_trap,
    output  wire                        o_pc_select,
    output  wire[31:0]                  o_result,
    output  wire[31:0]                  o_add,
    output  wire                        o_store,
    output  wire                        o_reg_write,
    output  wire[4:0]                   o_rd,
    output  wire[31:0]                  o_pc_next,
    output  wire[31:0]                  o_pc_target,
    output  res_src_t                   o_res_src,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel,
    output  wire[2:0]                   o_funct3,
    output  wire                        o_to_trap
);

    logic[31:0] op1, op2;
    logic       eq, lts, ltu;
    logic[32:0] add;
    logic[31:0] xor_, or_, and_, shl;
    logic[32:0] shr;
    logic[31:0] shift_result;
    logic       cmp_result;
    logic[31:0] bits_result;
    logic       carry;
    logic       op_b_sel;
    logic[31:0] op_b;
    logic       negative;
    logic       overflow;
    alu_res_t   res;
    alu_ctrl_t  ctrl;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic       inst_jal_jalr, inst_branch;
    logic[31:0] pc_next;
    logic[31:0] pc_target_base;
    logic[31:0] pc_target_offset;
    res_src_t   res_src;
    logic[2:0]  funct3;
    logic[31:0] reg_data2;
    logic       csr_read;
    logic[31:0] csr_data;
    logic       to_trap;
    logic       branch_pred;

    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | i_flush)
        begin
            rd <= '0;
            inst_jal_jalr <= '0;
            inst_branch <= '0;
            store <= '0;
            reg_write <= '0;
            res_src <= '0;
            to_trap <= '0;
            branch_pred <= '0;
        end
        else
        begin
            op1 <= i_op1;
            op2 <= i_op2;
            res <= i_res;
            ctrl <= i_ctrl;
            store <= i_store;
            reg_write <= i_reg_write;
            rd <= i_rd;
            inst_jal_jalr <= i_inst_jal_jalr;
            inst_branch <= i_inst_branch;
            pc_next <= i_pc_next;
            pc_target_base <= i_pc_target_base;
            pc_target_offset <= i_pc_target_offset;
            res_src <= i_res_src;
            funct3 <= i_funct3;
            reg_data2 <= i_reg_data2;
            csr_read <= i_csr_read;
            csr_data <= i_csr_data;
            to_trap <= i_to_trap;
            branch_pred <= i_branch_pred;
        end
    end

    // adder - for all (add/sub/cmp)
    assign  op_b_sel = (ctrl.arith_sub | res.cmp);
    assign  op_b     = op_b_sel ? (~op2) : op2;
    assign  add      = op1 + op_b + { {32{1'b0}}, op_b_sel};
    assign  negative = add[31];
    assign  overflow = (op1[31] ^ op2[31]) & (op1[31] ^ add[31]);
    assign  carry    = add[32];

    assign  eq  = ctrl.cmp_inversed ^ (op1 == op2);
    assign  lts = ctrl.cmp_inversed ^ (negative ^ overflow);
    assign  ltu = ctrl.cmp_inversed ^ (!carry);

    assign  xor_ = op1 ^ op2;
    assign  or_  = op1 | op2;
    assign  and_ = op1 & op2;
    assign  shl = op1 << op2[4:0];
    assign  shr = $signed({ctrl.shift_arithmetical ? op1[31] : 1'b0, op1}) >>> op2[4:0];

    always_comb
    begin
        case (1'b1)
        ctrl.cmp_lts: cmp_result = lts;
        ctrl.cmp_ltu: cmp_result = ltu;
        default:      cmp_result = eq;
        endcase
    end

    logic       pc_select;
    logic[31:0] pc_target;
    assign      pc_select = /*(!fetch_bp_need) & */(inst_jal_jalr | (inst_branch & (cmp_result)));
    assign      pc_target = pc_target_base + pc_target_offset;

    always_comb
    begin
        case (1'b1)
        ctrl.bits_xor: bits_result = xor_;
        ctrl.bits_or:  bits_result = or_;
        default:       bits_result = and_;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        ctrl.arith_shr: shift_result = shr[31:0];
        default:        shift_result = shl;
        endcase
    end

    logic[31:0] result;

    always_comb
    begin
        case (1'b1)
        csr_read:  result = csr_data;
        res.cmp:   result = { {31{1'b0}}, cmp_result };
        res.bits:  result = bits_result;
        res.shift: result = shift_result;
        default:   result = add[31:0];
        endcase
    end

    always_comb
    begin
        case (funct3[1:0])
        2'b00:   o_wdata = {4{reg_data2[0+: 8]}};
        2'b01:   o_wdata = {2{reg_data2[0+:16]}};
        default: o_wdata = reg_data2;
        endcase
    end

    always_comb
    begin
        case (funct3[1:0])
        2'b00: begin
            case (add[1:0])
            2'b00: o_wsel = 4'b0001;
            2'b01: o_wsel = 4'b0010;
            2'b10: o_wsel = 4'b0100;
            2'b11: o_wsel = 4'b1000;
            endcase
        end
        2'b01: begin
            case (add[1])
            1'b0: o_wsel = 4'b0011;
            1'b1: o_wsel = 4'b1100;
            endcase
        end
        default:  o_wsel = 4'b1111;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = ctrl.cmp_eq & ctrl.bits_and & ctrl.arith_shl & ctrl.arith_add & shr[32] & res.arith & branch_pred;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_pc_select = pc_select;
    assign  o_result = result;
    assign  o_add = add[31:0];
    assign  o_store = store;
    assign  o_reg_write = reg_write;
    assign  o_rd = rd;
    assign  o_pc_next = pc_next;
    assign  o_pc_target = pc_target;
    assign  o_res_src = res_src;
    assign  o_funct3 = funct3;
    assign  o_to_trap = to_trap;

endmodule
