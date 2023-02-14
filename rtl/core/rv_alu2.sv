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
    input   alu_res_t                   i_res,
    input   wire                        i_store,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire                        i_inst_jal_jalr,
    input   wire                        i_inst_branch,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_next,
    input   wire                        i_branch_pred,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc_target,
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
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc_target,
    output  res_src_t                   o_res_src,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel,
    output  wire[2:0]                   o_funct3,
    output  wire                        o_to_trap,
    output  wire                        o_ready
);

    logic[31:0] op1, op2;
    logic       eq, lts, ltu;
    logic[32:0] add;
    logic[31:0] xor_, or_, and_, shl;
    logic[32:0] shr;
    logic       carry;
    logic       negative;
    logic       overflow;
    alu_res_t   res;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic       inst_jal_jalr, inst_branch;
    logic[IADDR_SPACE_BITS-1:0] pc;
    logic[IADDR_SPACE_BITS-1:0] pc_next;
    logic[IADDR_SPACE_BITS-1:0] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    alu_ctrl_t  alu_ctrl;
    logic[31:0] reg_data2;
    logic       csr_read;
    logic[31:0] csr_data;
    logic       to_trap;
    logic       branch_pred;
    logic[4:0]  op_cnt;

    alu_state_t state;
    alu_state_t state_next;
    logic       op_end;

    always_comb
    begin
        case (state)
        `ALU_START: state_next = (|i_alu_ctrl.group_mux) ? `ALU_WAIT : `ALU_START;
        `ALU_WAIT : state_next = (op_cnt == 5'd30) ? `ALU_END : `ALU_WAIT;
        `ALU_END  : state_next = `ALU_START;
        default   : state_next = `ALU_START;
        endcase
    end

    logic       ready;
    logic       mul_op1_signed;
    logic       mul_op2_signed;
    assign      ready = (state == `ALU_START);
    assign      mul_op1_signed = !(&funct3[1:0]);
    assign      mul_op2_signed = !funct3[1];

    always_ff @(posedge i_clk)
    begin
        state <= state_next;
        op_end <= (state_next == `ALU_END);
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
            op1 <= '0;
            op2 <= '0;
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
            res <= i_res;
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
        end
        else
        begin
            op2 <= { 1'b0, op2[31:1] };
        end
    end

    logic[32:0] op1_mux;
    logic[31:0] op2_mux;
    logic[32:0] add_prev;

    always_comb
    begin
        case (alu_ctrl.group_mux)
        (EXTENSION_M & `GRP_MUX_MULDIV): op1_mux = add_prev;
        default        : op1_mux = { 1'b0, op1 };
        endcase
    end

    always_comb
    begin
        case (alu_ctrl.group_mux)
        (EXTENSION_M & `GRP_MUX_MULDIV): op2_mux = { mul_op1_signed ^ (op1[31] & op2[0]),
                                                     op1[30:0] & {31{op2[0]}} };
        default        : op2_mux = op2;
        endcase
    end

    // adder - for all (add/sub/cmp)
    logic       op2_inverse;
    logic       zero;
    logic[31:0] opb;
    assign  op2_inverse = alu_ctrl.op2_inverse | (op_end & mul_op2_signed);
    assign  opb      = {32{op2_inverse}} ^ op2_mux;
    assign  add      = op1_mux + opb + { {32{1'b0}}, op2_inverse };
    assign  negative = add[31];
    assign  overflow = (op1_mux[31] ^ op2_mux[31]) & (op1_mux[31] ^ add[31]);
    assign  carry    = add[32];
    assign  zero     = !(|add[31:0]);

    assign  eq  = alu_ctrl.op1_inv_or_ecmp_inv ^ zero;
    assign  lts = alu_ctrl.op1_inv_or_ecmp_inv ^ (negative ^ overflow);
    assign  ltu = alu_ctrl.op1_inv_or_ecmp_inv ^ (!carry);

    assign  xor_ = op1 ^ op2;
    assign  or_  = op1 | op2;
    assign  and_ = op1 & op2;
    assign  shl = op1 << op2[4:0];
    assign  shr = $signed({alu_ctrl.op2_inverse ? op1[31] : 1'b0, op1}) >>> op2[4:0];

    logic       cmp_result;
    logic       pc_select, pred_ok;
    logic[IADDR_SPACE_BITS-1:0] pc_out;
    assign      pred_ok = (pc_target == i_pc);
    assign      pc_select = (inst_jal_jalr | (inst_branch & (cmp_result))) ^
                            (branch_pred & pred_ok & BRANCH_PREDICTION);
    assign      pc_out = (branch_pred & pred_ok) ? pc_next : pc_target;

    always_comb
    begin
        case (funct3[2:1])
        2'b00  : cmp_result = eq;
        2'b10  : cmp_result = lts;
        default: cmp_result = ltu;
        endcase
    end

    logic[63:0] mul;

    always_ff @(posedge i_clk)
    begin
        if (state == `ALU_WAIT)
        begin
            mul <= { 33'b0, add[0], mul[30:1] };
            add_prev <= { 1'b0, add[32:1] };
        end
        else
        begin
            mul <= { (mul_op1_signed | mul_op2_signed) ^ add[32], add[31:0], mul[30:0] };
            add_prev <= { 1'b0, !(&i_funct3[1:0]), 31'b0 };
        end
    end

    logic[31:0] alu_i;
    logic[31:0] alu_res_i;
    logic[31:0] alu_m;
    logic[31:0] result;
    always_comb
    begin
        case (funct3[2:0])
        3'b000 : alu_i = add[31:0];
        3'b001 : alu_i = shl;
        3'b010 : alu_i = { {31{1'b0}}, lts };
        3'b011 : alu_i = { {31{1'b0}}, ltu };
        3'b100 : alu_i = xor_;
        3'b101 : alu_i = shr[31:0];
        3'b110 : alu_i = or_;
        default: alu_i = and_;
        endcase
    end
    always_comb
    begin
        case (alu_ctrl.add_override)
        1'b0   : alu_res_i = alu_i;
        default: alu_res_i = add[31:0];
        endcase
    end
    always_comb
    begin
        case (funct3[2:0])
        3'b000 : alu_m = mul[31: 0];
        3'b001 : alu_m = mul[63:32];
        3'b010 : alu_m = mul[63:32];
        3'b011 : alu_m = mul[63:32];
        //3'b10x : alu_m = div[31:0];
        //3'b11x : alu_m = rem[31:0];
        default: alu_m = '0;
        endcase
    end

    assign  result = res_src.pc_next ? { {(32-IADDR_SPACE_BITS){1'b0}}, pc_next } :
                     (csr_read & EXTENSION_Zicsr) ? csr_data :
                     (EXTENSION_M & (alu_ctrl.group_mux == `GRP_MUX_MULDIV)) ? alu_m :
                     alu_res_i;

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
    assign  dummy = shr[32] & res.arith & res.cmp & res.bits & res.shift;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_pc_select = pc_select;
    assign  o_result = result;
    assign  o_add = add[31:0];
    assign  o_store = store;
    assign  o_reg_write = reg_write;
    assign  o_rd = rd;
    assign  o_pc = pc;
    assign  o_pc_target = pc_out;
    assign  o_res_src = res_src;
    assign  o_funct3 = funct3;
    assign  o_to_trap = to_trap;
    assign  o_ready = ready;

endmodule
