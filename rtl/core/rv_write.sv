`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_write
(
    input   wire                        i_clk,
    input   wire[2:0]                   i_funct3,
    input   wire[31:0]                  i_alu_result,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   res_src_t                   i_res_src,
    input   wire[31:0]                  i_pc_next,
    input   wire[31:0]                  i_data,
    output  wire[31:0]                  o_data,
    output  wire[4:0]                   o_rd,
    output  wire                        o_write_op
);

    logic[31:0] alu_result;
    logic[31:0] pc_next;
    res_src_t   res_src;
    logic       reg_write;
    logic[4:0]  rd;
    logic[2:0]  funct3;
    logic[31:0] rdata;
    
    always_ff @(posedge i_clk)
    begin
        alu_result <= i_alu_result;
        pc_next <= i_pc_next;
        res_src <= i_res_src;
        reg_write <= i_reg_write;
        rd <= i_rd;
        funct3 <= i_funct3;
        rdata <= i_data;
    end

    logic[7:0]  write_byte;
    logic[15:0] write_half_word;
    logic[31:0] write_rdata;

    always_comb
    begin
        case (alu_result[1:0])
        2'b00: write_byte = rdata[ 0+:8];
        2'b01: write_byte = rdata[ 8+:8];
        2'b10: write_byte = rdata[16+:8];
        2'b11: write_byte = rdata[24+:8];
        endcase
    end

    always_comb
    begin
        case (alu_result[1])
        1'b0: write_half_word = rdata[ 0+:16];
        1'b1: write_half_word = rdata[16+:16];
        endcase
    end

    always_comb
    begin
        case (funct3)
        3'b000: write_rdata = { {24{write_byte[7]}}, write_byte};
        3'b001: write_rdata = { {16{write_half_word[15]}}, write_half_word};
        3'b010: write_rdata = rdata;
        3'b011: write_rdata = '0;
        3'b100: write_rdata = { {24{1'b0}}, write_byte};
        3'b101: write_rdata = { {16{1'b0}}, write_half_word};
        3'b110: write_rdata = '0;
        3'b111: write_rdata = '0;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        res_src.memory:  o_data = write_rdata;
        res_src.pc_next: o_data = pc_next;
        default:         o_data = alu_result;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = res_src.alu;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_rd = rd;
    assign  o_write_op = reg_write;

endmodule
