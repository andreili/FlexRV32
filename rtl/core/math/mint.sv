`timescale 1ps/1ps

/* verilator lint_off UNUSEDSIGNAL */
module mint
(
    input   wire                        i_clk,
    input   wire                        i_start,
    input   wire                        i_op1_signed,
    input   wire                        i_op2_signed,
    input   wire[31:0]                  i_op1,
    input   wire[31:0]                  i_op2,
    output  wire[31:0]                  o_div,
    output  wire[63:0]                  o_mul,
    output  wire[31:0]                  o_rem
);
/* verilator lint_on UNUSEDSIGNAL */

    logic[31:0] op_a, op_b;
    logic[32:0] op1_m, op2_m;
    logic[31:0] div;
    logic[31:0] rem;
    logic       m_sign;
    assign      op_a  = ((i_op1_signed & i_op1[31]) ? (~i_op1) : i_op1) +
                        { {31{1'b0}}, (i_op1_signed & i_op1[31]) };
    assign      op_b  = ((i_op2_signed & i_op2[31]) ? (~i_op2) : i_op2) +
                        { {31{1'b0}}, (i_op2_signed & i_op2[31]) };
    assign      op1_m = $signed({i_op1_signed ? i_op1[31] : 1'b0, op_a});
    assign      op2_m = $signed({i_op2_signed ? i_op2[31] : 1'b0, op_b});
    assign      div = op1_m[31:0] / op2_m[31:0];
    assign      rem = op1_m[31:0] % op2_m[31:0];
    assign      m_sign = (i_op1_signed & op1_m[32]) ^ (i_op2_signed & op2_m[32]);

    assign  o_div = m_sign ? ((~div) - '1) : div;
    assign  o_rem = m_sign ? ((~rem) - '1) : rem;

/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNOPTFLAT */
    logic[63:0] result;
    logic[31:0] work[31];
    logic[31:0] mod2;

    logic[31:0] mod00;
    logic[32:0] sum00;
    assign      mod00   = { ~(i_op1[31] & i_op2[0]),
                            i_op1[30:0] & {31{i_op2[0]}} };
    assign      sum00   = { 1'b0, mod00 } + { i_op1_signed, 32'b0 };
    assign      work[0] = sum00[32:1];
    assign      result[0] = sum00[0];

    generate
        genvar i;
        for (i=1 ; i<31 ; ++i)
        begin : g_mul
            logic[31:0] mod;
            logic[32:0] sum;
            assign      mod  = { i_op1_signed ^ (i_op1[31] & i_op2[i]),
                                 i_op1[30:0] & {31{i_op2[i]}} };
            assign      sum = mod + work[i-1];
            assign      work[i] = sum[32:1];
            assign      result[i] = sum[0];
            if (i == 30)
            begin : g_m2
                assign mod2 = ~mod;
            end
        end
    endgenerate

    logic[32:0] sum2;
    assign      sum2 = mod2 + work[30];
    assign      result[63:31] = { ~sum2[32], sum2[31:0] };

    assign  o_mul = result;

/* verilator lint_on UNOPTFLAT */
/* verilator lint_on UNUSEDSIGNAL */

endmodule
