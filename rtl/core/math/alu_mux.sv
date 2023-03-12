`timescale 1ps/1ps

`include "../../rv_defines.vh"
`ifndef TO_SIM
`include "../../rv_structs.vh"
`endif

module alu_mux
#(
    parameter logic EXTENSION_M         = 1
)
(
    input   wire[31:0]                  i_add,
    input   wire[31:0]                  i_xor,
    input   wire[31:0]                  i_or,
    input   wire[31:0]                  i_and,
    input   wire[31:0]                  i_shl,
    input   wire[31:0]                  i_shr,
    input   wire                        i_lts,
    input   wire                        i_ltu,
    input   wire[63:0]                  i_mul,
    input   wire[31:0]                  i_div,
    input   wire[31:0]                  i_rem,
    input   wire[2:0]                   i_funct3,
    input   wire                        i_add_override,
    input   wire                        i_group_mux,
    output  wire[31:0]                  o_out
);

    logic[31:0] alu_i;
    logic[31:0] alu_res_i;
    logic[31:0] alu_m;

    always_comb
    begin
        case (i_funct3[2:0])
        3'b000 : alu_i = i_add;
        3'b001 : alu_i = i_shl;
        3'b010 : alu_i = { {31{1'b0}}, i_lts };
        3'b011 : alu_i = { {31{1'b0}}, i_ltu };
        3'b100 : alu_i = i_xor;
        3'b101 : alu_i = i_shr;
        3'b110 : alu_i = i_or;
        default: alu_i = i_and;
        endcase
    end
    always_comb
    begin
        case (i_add_override)
        1'b0   : alu_res_i = alu_i;
        default: alu_res_i = i_add;
        endcase
    end
    always_comb
    begin
        case (i_funct3[2:0])
        3'b000 : alu_m = i_mul[31: 0];
        3'b001 : alu_m = i_mul[63:32];
        3'b010 : alu_m = i_mul[63:32];
        3'b011 : alu_m = i_mul[63:32];
        3'b100 : alu_m = i_div;
        3'b101 : alu_m = i_div;
        3'b110 : alu_m = i_rem;
        3'b111 : alu_m = i_rem;
        default: alu_m = '0;
        endcase
    end

    assign  o_out = (EXTENSION_M & (i_group_mux == `GRP_MUX_MULDIV)) ? alu_m :
                    alu_res_i;

endmodule
