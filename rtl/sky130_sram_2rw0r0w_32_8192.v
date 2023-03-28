`timescale 1ps/1ps
// OpenRAM SRAM model
// Words: 8192
// Word size: 32
// Write size: 8

module sky130_sram_2rw0r0w_32_8192(
`ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
// Port 0: RW
    clk0,csb0,web0,wmask0,addr0,din0,dout0,
// Port 1: RW
    clk1,csb1,web1,wmask1,addr1,din1,dout1
  );

  parameter NUM_WMASKS = 4 ;
  parameter DATA_WIDTH = 32 ;
  parameter ADDR_WIDTH = 12 ;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;
  // FIXME: This delay is arbitrary.
  parameter DELAY = 3 ;
  parameter VERBOSE = 0 ; //Set to 0 to only display warnings
  parameter T_HOLD = 1 ; //Delay to hold dout value after posedge. Value is arbitrary

`ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
`endif
  input  clk0; // clock
  input   csb0; // active low chip select
  input  web0; // active low write control
  input [ADDR_WIDTH-1:0]  addr0;
  input [NUM_WMASKS-1:0]   wmask0; // write mask
  input [DATA_WIDTH-1:0]  din0;
  output [DATA_WIDTH-1:0] dout0;
  input  clk1; // clock
  input   csb1; // active low chip select
  input  web1; // active low write control
  input [ADDR_WIDTH-1:0]  addr1;
  input [NUM_WMASKS-1:0]   wmask1; // write mask
  input [DATA_WIDTH-1:0]  din1;
  output [DATA_WIDTH-1:0] dout1;

  reg [DATA_WIDTH-1:0]    mem [0:RAM_DEPTH-1];

  reg  csb0_reg;
  reg  web0_reg;
  reg [NUM_WMASKS-1:0]   wmask0_reg;
  reg [ADDR_WIDTH-1:0]  addr0_reg;
  reg [DATA_WIDTH-1:0]  din0_reg;
  reg [DATA_WIDTH-1:0]  dout0;

  // All inputs are registers
  always @(posedge clk0)
  begin
    csb0_reg <= csb0;
    web0_reg <= web0;
    wmask0_reg <= wmask0;
    addr0_reg <= addr0;
    if (!csb1 && !web1 && !csb0 && web0 && (addr1 == addr0))
         $display($time," WARNING: Writing and reading addr1=%b and addr0=%b simultaneously!",addr1,addr0);
    din0_reg <= din0;
    #(T_HOLD) dout0 <= 32'bx;
    if ( !csb0_reg && web0_reg && VERBOSE )
      $display($time," Reading %m addr0=%b dout0=%b",addr0_reg,mem[addr0_reg]);
    if ( !csb0_reg && !web0_reg && VERBOSE )
      $display($time," Writing %m addr0=%b din0=%b wmask0=%b",addr0_reg,din0_reg,wmask0_reg);
  end

  reg  csb1_reg;
  reg  web1_reg;
  reg [NUM_WMASKS-1:0]   wmask1_reg;
  reg [ADDR_WIDTH-1:0]  addr1_reg;
  reg [DATA_WIDTH-1:0]  din1_reg;
  reg [DATA_WIDTH-1:0]  dout1;

  // All inputs are registers
  always @(posedge clk1)
  begin
    csb1_reg <= csb1;
    web1_reg <= web1;
    wmask1_reg <= wmask1;
    addr1_reg <= addr1;
    if (!csb0 && !web0 && !csb1 && web1 && (addr0 == addr1))
         $display($time," WARNING: Writing and reading addr0=%b and addr1=%b simultaneously!",addr0,addr1);
    din1_reg <= din1;
    #(T_HOLD) dout1 <= 32'bx;
    if ( !csb1_reg && web1_reg && VERBOSE )
      $display($time," Reading %m addr1=%b dout1=%b",addr1_reg,mem[addr1_reg]);
    if ( !csb1_reg && !web1_reg && VERBOSE )
      $display($time," Writing %m addr1=%b din1=%b wmask1=%b",addr1_reg,din1_reg,wmask1_reg);
  end


  // Memory Write Block Port 0
  // Write Operation : When web0 = 0, csb0 = 0
  always @ (negedge clk0)
  begin : MEM_WRITE0
    if ( !csb0_reg && !web0_reg ) begin
        if (wmask0_reg[0])
                mem[addr0_reg][7:0] <= din0_reg[7:0];
        if (wmask0_reg[1])
                mem[addr0_reg][15:8] <= din0_reg[15:8];
        if (wmask0_reg[2])
                mem[addr0_reg][23:16] <= din0_reg[23:16];
        if (wmask0_reg[3])
                mem[addr0_reg][31:24] <= din0_reg[31:24];
    end
  end

  // Memory Read Block Port 0
  // Read Operation : When web0 = 1, csb0 = 0
  always @ (negedge clk0)
  begin : MEM_READ0
    if (!csb0_reg && web0_reg)
       dout0 <= #(DELAY) mem[addr0_reg];
  end

  // Memory Write Block Port 1
  // Write Operation : When web1 = 0, csb1 = 0
  always @ (negedge clk1)
  begin : MEM_WRITE1
    if ( !csb1_reg && !web1_reg ) begin
        if (wmask1_reg[0])
                mem[addr1_reg][7:0] <= din1_reg[7:0];
        if (wmask1_reg[1])
                mem[addr1_reg][15:8] <= din1_reg[15:8];
        if (wmask1_reg[2])
                mem[addr1_reg][23:16] <= din1_reg[23:16];
        if (wmask1_reg[3])
                mem[addr1_reg][31:24] <= din1_reg[31:24];
    end
  end

  // Memory Read Block Port 1
  // Read Operation : When web1 = 1, csb1 = 0
  always @ (negedge clk1)
  begin : MEM_READ1
    if (!csb1_reg && web1_reg)
       dout1 <= #(DELAY) mem[addr1_reg];
  end

endmodule
