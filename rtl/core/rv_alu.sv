`timescale 1ps/1ps

module rv_alu
(
    input   wire[31:0]                  i_src_a,
    input   wire[31:0]                  i_src_b,
    input   wire[4:0]                   i_ctrl,
    output  wire[31:0]                  o_result,
    output  wire                        o_zero
);

`include "rv_defines.vh"

    wire        w_eq, w_lts, w_ltu;
    wire[32:0]  w_add;
    wire[31:0]  w_xor, w_or, w_and, w_shl;
    wire[32:0]  w_shr;
    reg[31:0]   r_out;
    logic       w_cmp_result;
    logic[31:0] w_ariph_result;
    logic       w_carry;
    logic       w_op_b_sel;
    logic[31:0] w_op_b;
    logic       w_negative;
    logic       w_overflow;

    /*
    adder_ks
    u_mod
    (
        .i_a                            (i_src_a),
        .i_b                            (w_op_b),
        .i_c                            (i_ctrl[0]),
        .o_sum                          (w_add),
        .o_and                          (w_and),
        .o_xor                          (w_xor),
        .o_carry                        (w_carry)
    );*/

    // adder - for all (add/sub/cmp)
    assign  w_op_b_sel = (i_ctrl[0] | (!i_ctrl[3]));
    assign  w_op_b     = w_op_b_sel ? (~i_src_b) : i_src_b;
    assign  w_add      = i_src_a + w_op_b + { {32{1'b0}}, w_op_b_sel};
    assign  w_negative = w_add[31];
    //assign  w_zero     = !(|w_add[31:0]);
    assign  w_overflow = (i_src_a[31] ^ i_src_b[31]) & (i_src_a[31] ^ w_add[31]);
    assign  w_carry    = w_add[32];

    assign  w_eq  = (i_src_a == i_src_b);//w_zero;
    assign  w_lts = (w_negative ^ w_overflow);
    assign  w_ltu = !w_carry;

    assign  w_xor = i_src_a ^ i_src_b;
    assign  w_or  = i_src_a | i_src_b;
    assign  w_and = i_src_a & i_src_b;
    assign  w_shl = i_src_a << i_src_b[4:0];
    assign  w_shr = $signed({i_ctrl[4] ? i_src_a[31] : 1'b0, i_src_a}) >>> i_src_b[4:0];

    always_comb
    begin
        case (i_ctrl[3:0])
        `ALU_CMP_EQ:   w_cmp_result = w_eq;
        `ALU_CMP_LTS:  w_cmp_result = w_lts;
        `ALU_CMP_LTU:  w_cmp_result = w_ltu;
        `ALU_CMP_NEQ:  w_cmp_result = !w_eq;
        `ALU_CMP_NLTS: w_cmp_result = !w_lts;
        `ALU_CMP_NLTU: w_cmp_result = !w_ltu;
        default:       w_cmp_result = 'x;
        endcase
    end

    always_comb
    begin
        case (i_ctrl[3:0])
        `ALU_CTRL_ADD: w_ariph_result = w_add[31:0];
        `ALU_CTRL_SUB: w_ariph_result = w_add[31:0];
        `ALU_CTRL_XOR: w_ariph_result = w_xor;
        `ALU_CTRL_OR:  w_ariph_result = w_or;
        `ALU_CTRL_AND: w_ariph_result = w_and;
        `ALU_CTRL_SHL: w_ariph_result = w_shl;
        `ALU_CTRL_SHR: w_ariph_result = w_shr[31:0];
        default:       w_ariph_result = {32{w_shr[32]}};
        endcase
    end

    always_comb
    begin
        case (i_ctrl[3])
        1'b0:   r_out = { {31{1'b0}}, w_cmp_result };
        1'b1:   r_out = w_ariph_result;
        endcase
    end

    assign  o_result = r_out;
    assign  o_zero = !(|r_out);

endmodule
