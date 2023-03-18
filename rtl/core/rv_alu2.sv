`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu2
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter logic BRANCH_PREDICTION   = 1,
    parameter logic EXTENSION_Zicsr     = 1,
    parameter logic EXTENSION_M         = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_flush,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    input   wire                        i_store,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire                        i_inst_jal_jalr,
    input   wire                        i_inst_branch,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
    input   wire                        i_branch_pred,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_target,
    input   res_src_t                   i_res_src,
    input   wire[2:0]                   i_funct3,
    input   alu_ctrl_t                  i_alu_ctrl,
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
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_target,
    output  res_src_t                   o_res_src,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel,
    output  wire[2:0]                   o_funct3,
    output  wire                        o_to_trap,
    output  wire                        o_ready
);

    logic[31:0] op1, op2;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic       inst_jal_jalr, inst_branch;
    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_next;
    logic[IADDR_SPACE_BITS-1:1] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    alu_ctrl_t  alu_ctrl;
    logic[31:0] reg_data2;
    logic       csr_read;
    logic[31:0] csr_data;
    logic       to_trap;
    logic       branch_pred;
    logic[5:0]  op_cnt;
    logic       cmp_inv;

    alu_state_t state;
    alu_state_t state_next;

    always_comb
    begin
        case (state)
        `ALU_START: state_next = (|i_alu_ctrl.group_mux & EXTENSION_M) ? `ALU_WAIT : `ALU_START;
        `ALU_WAIT : state_next = (((op_cnt == 6'd30) && (!alu_ctrl.div_mux)) |
                                  ((op_cnt == 6'd32) && ( alu_ctrl.div_mux)))  ? `ALU_END : `ALU_WAIT;
        `ALU_END  : state_next = `ALU_START;
        default   : state_next = `ALU_START;
        endcase
    end

    logic       ready;
    logic       mul_op1_signed;
    logic       mul_op2_signed_next;
    logic       mul_op2_signed;
    logic       div_rem_signed;
    logic       div_signed;
    logic       rem_signed;
    logic       cmp_inv_next;
    assign      ready = (state == `ALU_START) | (!EXTENSION_M);
    assign      mul_op1_signed = !(&funct3[1:0]);
    assign      div_rem_signed = !funct3[0];
    assign      div_signed = (funct3[1:0] == 2'b00);
    assign      rem_signed = (funct3[1:0] == 2'b10);
    assign      mul_op2_signed_next = (state_next == `ALU_END) & !funct3[1];
    assign      cmp_inv_next = i_funct3[0] & i_inst_branch;

    always_ff @(posedge i_clk)
    begin
        if (i_flush)
            state <= `ALU_START;
        else
            state <= state_next;
        mul_op2_signed <= mul_op2_signed_next;
    end

    always_ff @(posedge i_clk)
    begin
        if (state == `ALU_START)
            op_cnt <= '0;
        else
            op_cnt <= op_cnt + 1'b1;
    end

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
        else if (ready)
        begin
            op1 <= i_op1;
            op2 <= i_op2;
            store <= i_store;
            reg_write <= i_reg_write;
            rd <= i_rd;
            inst_jal_jalr <= i_inst_jal_jalr;
            inst_branch <= i_inst_branch;
            pc <= i_pc;
            pc_next <= i_pc_next;
            pc_target <= i_pc_target;
            res_src <= i_res_src;
            funct3 <= i_funct3;
            alu_ctrl <= i_alu_ctrl;
            reg_data2 <= i_reg_data2;
            csr_read <= i_csr_read;
            csr_data <= i_csr_data;
            to_trap <= i_to_trap;
            branch_pred <= i_branch_pred;
            cmp_inv <= cmp_inv_next;
        end
        else
        begin
            op2 <= alu_ctrl.div_mux ? { op2[30:0], 1'b0 } : { 1'b0, op2[31:1] };
        end
    end

    logic[32:0] op1_mux;
    logic[31:0] op2_mux;
    logic[32:0] add_prev;
    logic[31:0] mul_mod;

    assign  op1_mux = (EXTENSION_M & (alu_ctrl.group_mux == `GRP_MUX_MULDIV)) ? add_prev :
                      { 1'b0, op1 };
    assign  op2_mux = (EXTENSION_M & (alu_ctrl.group_mux == `GRP_MUX_MULDIV)) ? mul_mod :
                      op2;

    // adder - for all (add/sub/cmp)
    logic   op2_inverse;
    assign  op2_inverse = alu_ctrl.op2_inverse | mul_op2_signed;

    // adder - for all (add/sub/cmp/mul)
    logic[32:0] add;
    logic       eq, lts, ltu;
    adder
    u_adder
    (
        .i_is_sub                       (op2_inverse),
        .i_cmp_inverse                  (cmp_inv),
        .i_op1                          (op1_mux),
        .i_op2                          (op2_mux),
        .o_add                          (add),
        .o_eq                           (eq),
        .o_lts                          (lts),
        .o_ltu                          (ltu)
    );

    logic[31:0] xor_, or_, and_, shl;
    logic[32:0] shr;
    bitwise
    u_bits
    (
        .i_sra                          (alu_ctrl.sh_ar),
        .i_op1                          (op1),
        .i_op2                          (op2),
        .o_xor                          (xor_),
        .o_or                           (or_),
        .o_and                          (and_),
        .o_shl                          (shl),
        .o_shr                          (shr)
    );

    logic       cmp_result;
    always_comb
    begin
        case (funct3[2:1])
        2'b00  : cmp_result = eq;
        2'b10  : cmp_result = lts;
        default: cmp_result = ltu;
        endcase
    end

    pc_sel
    #(
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .BRANCH_PREDICTION              (BRANCH_PREDICTION)
    )
    u_pc_sel
    (
        .i_cmp                          (cmp_result),
        .i_branch_pred                  (branch_pred),
        .i_inst_jal_jalr                (inst_jal_jalr),
        .i_inst_branch                  (inst_branch),
        .i_pc                           (pc),
        .i_pc_next                      (pc_next),
        .i_pc_target                    (pc_target),
        .o_pc_select                    (o_pc_select),
        .o_pc_target                    (o_pc_target)
    );

    logic[63:0] mul;
    logic[31:0] div, rem;
    logic       md_op2;
    assign      md_op2 = alu_ctrl.div_mux ? op2[31] : op2[0];
    muldiv
    u_muldiv
    (
        .i_clk                          (i_clk),
        .i_on_wait                      (state == `ALU_WAIT),
        .i_on_end                       (state == `ALU_END),
        .i_op1_signed                   (mul_op1_signed),
        .i_op2_signed                   (mul_op2_signed),
        .i_dr_signed                    (div_rem_signed),
        .i_div_signed                   (div_signed),
        .i_rem_signed                   (rem_signed),
        .i_is_div                       (alu_ctrl.div_mux),
        .i_op1                          (op1),
        .i_op2                          (op2),
        .i_op2_lsb                      (md_op2),
        .i_add                          (add),
        .i_funct3                       (i_funct3[1:0]),
        .o_mod                          (mul_mod),
        .o_add_prev                     (add_prev),
        .o_mul                          (mul),
        .o_div                          (div),
        .o_rem                          (rem)
    );

    logic[31:0] alu_result;
    logic[31:0] result;
    alu_mux
    #(
        .EXTENSION_M                    (EXTENSION_M)
    )
    u_mux
    (
        .i_add                          (add[31:0]),
        .i_xor                          (xor_),
        .i_or                           (or_),
        .i_and                          (and_),
        .i_shl                          (shl),
        .i_shr                          (shr[31:0]),
        .i_lts                          (lts),
        .i_ltu                          (ltu),
        .i_mul                          (mul),
        .i_div                          (div),
        .i_rem                          (rem),
        .i_funct3                       (funct3),
        .i_add_override                 (alu_ctrl.add_override),
        .i_group_mux                    (alu_ctrl.group_mux),
        .o_out                          (alu_result)
    );

    wr_mux
    u_wr_mux
    (
        .i_funct3                       (funct3[1:0]),
        .i_add_lo                       (add[1:0]),
        .i_reg_data2                    (reg_data2),
        .o_wdata                        (o_wdata),
        .o_wsel                         (o_wsel)
    );

    assign  result = res_src.pc_next ? { {(32-IADDR_SPACE_BITS){1'b0}}, pc_next, 1'b0 } :
                     (csr_read & EXTENSION_Zicsr) ? csr_data :
                     alu_result;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = shr[32] & alu_ctrl.div_mux;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_result = result;
    assign  o_add = add[31:0];
    assign  o_store = store;
    assign  o_reg_write = reg_write;
    assign  o_rd = rd;
    assign  o_res_src = res_src;
    assign  o_funct3 = funct3;
    assign  o_to_trap = to_trap;
    assign  o_ready = ready;

endmodule
