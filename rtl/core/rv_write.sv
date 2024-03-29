`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"

module rv_write
(
    input   wire                        i_clk,
    input   wire                        i_flush,
    input   wire                        i_stall,
    input   wire[2:0]                   i_funct3,
    input   wire[31:0]                  i_alu_result,
    input   wire[31:0]                  i_alu_ext,
    input   wire                        i_alu_is_ext,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   res_src_t                   i_res_src,
    input   wire[31:0]                  i_data,
    output  wire[31:0]                  o_data,
    output  wire[4:0]                   o_rd,
    output  wire                        o_write_op
);

    logic[31:0] alu_result;
    logic[31:0] alu_ext;
    logic       alu_is_ext;
    res_src_t   res_src;
    logic       reg_write;
    logic[4:0]  rd;
    logic[2:0]  funct3;

    always_ff @(posedge i_clk)
    begin
        if (i_flush)
        begin
            res_src <= '0;
            reg_write <= '0;
        end
        else if (!i_stall)
        begin
            alu_result <= i_alu_result;
            alu_ext <= i_alu_ext;
            alu_is_ext <= i_alu_is_ext;
            res_src <= i_res_src;
            reg_write <= i_reg_write;
            rd <= i_rd;
            funct3 <= i_funct3;
        end
    end

    logic[31:0] in_data;

    assign  in_data = alu_is_ext ? alu_ext : alu_result;

    logic[7:0]  write_byte;
    logic[15:0] write_half_word;
    logic[31:0] write_rdata;

    always_comb
    begin
        case (alu_result[1:0])
        2'b00  : write_byte = i_data[ 0+:8];
        2'b01  : write_byte = i_data[ 8+:8];
        2'b10  : write_byte = i_data[16+:8];
        default: write_byte = i_data[24+:8];
        endcase
    end

    always_comb
    begin
        case (alu_result[1])
        1'b0   : write_half_word = i_data[ 0+:16];
        default: write_half_word = i_data[16+:16];
        endcase
    end

    always_comb
    begin
        case (funct3)
        3'b000 : write_rdata = { {24{write_byte[7]}}, write_byte};
        3'b001 : write_rdata = { {16{write_half_word[15]}}, write_half_word};
        3'b010 : write_rdata = i_data;
        3'b100 : write_rdata = { {24{1'b0}}, write_byte};
        3'b101 : write_rdata = { {16{1'b0}}, write_half_word};
        default: write_rdata = '0;
        endcase
    end

    logic[31:0] data;
    always_comb
    begin
        case (1'b1)
        res_src.memory: data = write_rdata;
        alu_is_ext    : data = in_data;
        default       : data = alu_result;
        endcase
    end

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = res_src.alu | res_src.pc_next;
/* verilator lint_on UNUSEDSIGNAL */

    assign  o_data = data;
    assign  o_rd = rd;
    assign  o_write_op = reg_write & !i_stall;

endmodule
