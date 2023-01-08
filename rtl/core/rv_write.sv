`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_write
(
    input   wire                        i_clk,
    input   memory_bus_t                i_bus,
    input   wire[31:0]                  i_data,
    output  wire[31:0]                  o_data,
    output  wire[4:0]                   o_rd,
    output  wire                        o_write_op
);

    write_bus_t bus_reg;
    
    always_ff @(posedge i_clk)
    begin
        bus_reg.alu_result <= i_bus.alu_result;
        bus_reg.pc <= i_bus.pc;
        bus_reg.res_src <= i_bus.res_src;
        bus_reg.reg_write <= i_bus.reg_write;
        bus_reg.rd <= i_bus.rd;
        bus_reg.funct3 <= i_bus.funct3;
        bus_reg.rdata <= i_data;
    `ifdef EXTENSION_C
        bus_reg.compressed <= i_bus.compressed;
    `endif
    end

    logic[7:0]  write_byte;
    logic[15:0] write_half_word;
    logic[31:0] write_rdata;

    always_comb
    begin
        case (bus_reg.alu_result[1:0])
        2'b00: write_byte = bus_reg.rdata[ 0+:8];
        2'b01: write_byte = bus_reg.rdata[ 8+:8];
        2'b10: write_byte = bus_reg.rdata[16+:8];
        2'b11: write_byte = bus_reg.rdata[24+:8];
        endcase
    end

    always_comb
    begin
        case (bus_reg.alu_result[1])
        1'b0: write_half_word = bus_reg.rdata[ 0+:16];
        1'b1: write_half_word = bus_reg.rdata[16+:16];
        endcase
    end

    always_comb
    begin
        case (bus_reg.funct3)
        3'b000: write_rdata = { {24{write_byte[7]}}, write_byte};
        3'b001: write_rdata = { {16{write_half_word[15]}}, write_half_word};
        3'b010: write_rdata = bus_reg.rdata;
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
        bus_reg.res_src.memory: o_data = write_rdata;
        bus_reg.res_src.pc_p4:  o_data = (bus_reg.pc + 
`ifdef EXTENSION_C
                (bus_reg.compressed ? 2 : 4)
`else
                4
`endif
            );
        default:              o_data = bus_reg.alu_result;
        endcase
    end

    assign  o_rd = bus_reg.rd;
    assign  o_write_op = bus_reg.reg_write;

endmodule
