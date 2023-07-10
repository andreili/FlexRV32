`timescale 1ps/1ps

module tcm
#
(
    parameter int MEM_ADDR_WIDTH        = 8
)
(
    input   wire                        i_clk,
    input   wire                        i_dev_sel,
    input   wire[(MEM_ADDR_WIDTH+1):2]  i_addr,
    input   wire[3:0]                   i_sel,
    input   wire                        i_write,
    input   wire[31:0]                  i_data,
    output  wire                        o_ack,
    output  wire[31:0]                  o_data
);

    localparam  int MemSize = 2 ** MEM_ADDR_WIDTH;
    //logic[31:0] r_out;
    logic       r_ack;
    logic[(MEM_ADDR_WIDTH+1):2] addr;
    logic[3:0]                  sel;
    logic[31:0]                 wdata;
    logic                       write;

    always_ff @(posedge i_clk)
    begin
        addr <= i_addr;
        sel <= i_sel;
        wdata <= i_data;
        write <= i_write;
    end

`ifdef QUARTUS
    `define MEM_DEF [3:0][7:0]
    `define QUADRANT_0 0
    `define QUADRANT_1 1
    `define QUADRANT_2 2
    `define QUADRANT_3 3
`else
    `define MEM_DEF [31:0]
    `define QUADRANT_0  0+:8
    `define QUADRANT_1  8+:8
    `define QUADRANT_2 16+:8
    `define QUADRANT_3 24+:8
`endif

    logic `MEM_DEF r_mem[MemSize];

    always_ff @(posedge i_clk)
    begin
        begin
            if (write & r_ack)
            begin
                if (sel[0]) r_mem[addr][`QUADRANT_0] <= wdata[ 0+:8];
                if (sel[1]) r_mem[addr][`QUADRANT_1] <= wdata[ 8+:8];
                if (sel[2]) r_mem[addr][`QUADRANT_2] <= wdata[16+:8];
                if (sel[3]) r_mem[addr][`QUADRANT_3] <= wdata[24+:8];
            end
            //r_out <= r_mem[i_addr];
        end;
    end

    always_ff @(posedge i_clk)
    begin
        r_ack <= i_dev_sel;
    end

    assign o_data = r_mem[addr];
    assign  o_ack = r_ack;

    initial
    begin
    `ifdef TO_SIM
        string fw_file;
        if ($value$plusargs("TEST_FW=%s", fw_file))
            $readmemh(fw_file, r_mem);
        else
            $readmemh("fw.vh", r_mem);
    `else
      `ifndef QUARTUS
            $readmemh("../fw/test/out/riscv.vh", r_mem);
      `endif
    `endif
    end

endmodule
