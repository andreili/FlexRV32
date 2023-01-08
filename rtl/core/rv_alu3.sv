`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_alu3
(
    input   wire                        i_clk,
    input   alu2_bus_t                  i_bus,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel,
    output  alu3_bus_t                  o_bus
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
    logic[31:0] pc_p4;
    logic[31:0] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    logic[31:0] reg_data2;

    always_ff @(posedge i_clk)
    begin
        bits_result <= i_bus.bits_result;
        pc_select <= i_bus.pc_select;
        cmp_result <= i_bus.cmp_result;
        add <= i_bus.add;
        shift_result <= i_bus.shift_result;
        res <= i_bus.res;
        store <= i_bus.store;
        reg_write <= i_bus.reg_write;
        rd <= i_bus.rd;
        pc_p4 <= i_bus.pc_p4;
        pc_target <= i_bus.pc_target;
        res_src <= i_bus.res_src;
        funct3 <= i_bus.funct3;
        reg_data2 <= i_bus.reg_data2;
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

    assign  o_bus.funct3 = funct3;
    assign  o_bus.alu_result = result;
    assign  o_bus.add = add;
    assign  o_bus.reg_write = reg_write;
    assign  o_bus.rd = rd;
    assign  o_bus.res_src = res_src;
    assign  o_bus.pc_p4 = pc_p4;
    assign  o_bus.pc_select = pc_select;
    assign  o_bus.pc_target = pc_target;
    assign  o_bus.store = store;

endmodule
