`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu3
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_flush,
    input   wire                        i_cmp_result,
    input   wire                        i_pc_select,
    input   wire[31:0]                  i_bits_result,
    input   wire[31:0]                  i_add,
    input   wire[31:0]                  i_shift_result,
    input   alu_res_t                   i_res,
    input   wire                        i_store,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_pc_next,
    input   wire[31:0]                  i_pc_target,
    input   res_src_t                   i_res_src,
    input   wire[2:0]                   i_funct3,
    input   wire[31:0]                  i_reg_data2,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel,
    output  [2:0]                       o_funct3,
    output  [31:0]                      o_alu_result,
    output  [31:0]                      o_add,
    output                              o_reg_write,
    output  [4:0]                       o_rd,
    output  res_src_t                   o_res_src,
    output  [31:0]                      o_pc_next,
    output                              o_pc_select,
    output  [31:0]                      o_pc_target,
    output                              o_store
);

    logic       cmp_result;
    logic       pc_select;
    logic[31:0] bits_result;
    logic[31:0] add;
    logic[31:0] shift_result;
    logic[31:0] result;
    alu_res_t   res;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic[31:0] pc_next;
    logic[31:0] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    logic[31:0] reg_data2;

    always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | i_flush)
        begin
            rd <= '0;
            pc_select <= '0;
            store <= '0;
            reg_write <= '0;
            res_src <= '0;
        end
        else
        begin
            bits_result <= i_bits_result;
            pc_select <= i_pc_select;
            cmp_result <= i_cmp_result;
            add <= i_add;
            shift_result <= i_shift_result;
            res <= i_res;
            store <= i_store;
            reg_write <= i_reg_write;
            rd <= i_rd;
            pc_next <= i_pc_next;
            pc_target <= i_pc_target;
            res_src <= i_res_src;
            funct3 <= i_funct3;
            reg_data2 <= i_reg_data2;
        end
    end

    always_comb
    begin
        case (1'b1)
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
            case (result[1:0])
            2'b00: o_wsel = 4'b0001;
            2'b01: o_wsel = 4'b0010;
            2'b10: o_wsel = 4'b0100;
            2'b11: o_wsel = 4'b1000;
            endcase
        end
        2'b01: begin
            case (result[1])
            1'b0: o_wsel = 4'b0011;
            1'b1: o_wsel = 4'b1100;
            endcase
        end
        default:  o_wsel = 4'b1111;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = res.arith;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_funct3 = funct3;
    assign  o_alu_result = result;
    assign  o_add = add;
    assign  o_reg_write = reg_write;
    assign  o_rd = rd;
    assign  o_res_src = res_src;
    assign  o_pc_next = pc_next;
    assign  o_pc_select = pc_select;
    assign  o_pc_target = pc_target;
    assign  o_store = store;

endmodule
