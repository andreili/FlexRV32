`timescale 1ps/1ps

module wr_mux
(
    input   wire[1:0]                   i_funct3,
    input   wire[1:0]                   i_add_lo,
    input   wire[31:0]                  i_reg_data2,
    output  wire[31:0]                  o_wdata,
    output  wire[3:0]                   o_wsel
);

    logic[31:0] wdata;
    logic[3:0]  wsel;

    always_comb
    begin
        case (i_funct3[1:0])
        2'b00:   wdata = {4{i_reg_data2[0+: 8]}};
        2'b01:   wdata = {2{i_reg_data2[0+:16]}};
        default: wdata = i_reg_data2;
        endcase
    end

    always_comb
    begin
        case (i_funct3[1:0])
        2'b00: begin
            case (i_add_lo)
            2'b00: wsel = 4'b0001;
            2'b01: wsel = 4'b0010;
            2'b10: wsel = 4'b0100;
            2'b11: wsel = 4'b1000;
            endcase
        end
        2'b01: begin
            case (i_add_lo[1])
            1'b0: wsel = 4'b0011;
            1'b1: wsel = 4'b1100;
            endcase
        end
        default:  wsel = 4'b1111;
        endcase
    end

    assign  o_wdata = wdata;
    assign  o_wsel  = wsel;

endmodule
