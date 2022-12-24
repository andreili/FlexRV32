`timescale 1ps/1ps

module top
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
`ifdef TO_SIM
    output  wire[31:0]                  o_wb_addr,
    output  wire                        o_wb_we,
    output  wire[31:0]                  o_wb_wdata,
    output  wire[31:0]                  o_debug,
`endif
    input   wire                        i_rx,
    output  wire                        o_tx
);

`include "../rtl/rv_defines.vh"

    logic       w_clk, w_locked;
    wire        w_reset_n;
    wire[31:0]  w_wb_addr;
    wire[31:0]  w_wb_wdata;
    wire[31:0]  w_wb_rdata;
    wire        w_wb_we;
    wire[3:0]   w_wb_sel;
    wire        w_wb_stb;
    wire        w_wb_cyc;
    wire        w_wb_ack;

`ifndef TO_SIM
  `ifdef QUARTUS
    pll
    u_pll
    (
        .refclk                         (i_clk),
        .rst                            ('0),
        .outclk_0                       (w_clk),
        .locked                         (w_locked)
    );
  `else
    clk_wiz_0
    u_pll
    (
        .clk_in1                        (i_clk),
        .clk_out1                       (w_clk),
        .locked                         (w_locked)
    );
  `endif
`else
    assign  w_clk = i_clk;
    assign  w_locked = '1;
    assign  o_wb_addr = w_wb_addr;
    assign  o_wb_we = w_wb_we;
    assign  o_wb_wdata = w_wb_wdata;
`endif

    debounce
    #(
        .LENGTH                         (4),
        .ACTIVE_LEVEL                   (1'b0)
    )
    u_deb_reset
    (
        .i_clk                          (w_clk),
        .i_sig                          (i_reset_n & w_locked),
        .o_sig                          (w_reset_n)
    );

    //rv_core_mini
    rv_core
    //core
    u_rv
    (
        .i_clk                          (w_clk),
        .i_reset_n                      (w_reset_n),
        .o_wb_adr                       (w_wb_addr),
        .o_wb_dat                       (w_wb_wdata),
        .i_wb_dat                       (w_wb_rdata),
        .o_wb_we                        (w_wb_we),
        .o_wb_sel                       (w_wb_sel),
        .o_wb_stb                       (w_wb_stb),
        .i_wb_ack                       (w_wb_ack),
    `ifdef TO_SIM
        .o_debug                        (o_debug),
    `endif
        .o_wb_cyc                       (w_wb_cyc)
    );

    localparam MAIN_NIC_SLAVES_COUNT    = 2 ** `SLAVE_SEL_WIDTH;
    localparam MAIN_NIC_SLAVE_TCM       = 0;
    localparam MAIN_NIC_SLAVE_UART      = 1;
    //localparam MAIN_NIC_SLAVE_I2C       = 2;
    //localparam MAIN_NIC_SLAVE_CCM       = 3;

    wire[(MAIN_NIC_SLAVES_COUNT-1):0]   w_main_slave_sel;
    wire[(MAIN_NIC_SLAVES_COUNT-1):0]   w_main_slave_ack;
    wire[(MAIN_NIC_SLAVES_COUNT-1):0][31:0]	w_main_slave_rdata;

    assign  w_main_slave_rdata[(MAIN_NIC_SLAVES_COUNT-1):3] = '0;
    assign  w_main_slave_ack  [(MAIN_NIC_SLAVES_COUNT-2):3] = '0;
    assign  w_main_slave_ack[15] = '1;

    nic
    #(
        .ADDR_SEL_WIDTH                 (`SLAVE_SEL_WIDTH),
        .DATA_WIDTH                     (32)
    )
    u_nic_main
    (
        .i_clk                          (w_clk),
        .i_nic_sel                      (1'b1),
        .i_addr_sel                     (w_wb_addr[31:28]),
        .i_rdata                        (w_main_slave_rdata),
        .i_ack                          (w_main_slave_ack),
        .o_slave_sel                    (w_main_slave_sel),
        .o_rdata                        (w_wb_rdata),
        .o_ack                          (w_wb_ack)
    );

    tcm
    #(
        .MEM_ADDR_WIDTH                 (`TCM_ADDR_WIDTH)
    )
    u_tcm
    (
        .i_clk                          (w_clk),
        .i_dev_sel                      (w_main_slave_sel[MAIN_NIC_SLAVE_TCM]),
        .i_addr                         (w_wb_addr[(`TCM_ADDR_WIDTH+1):2]),
        .i_sel                          (w_wb_sel),
        .i_write                        (w_wb_we),
        .i_data                         (w_wb_wdata),
        .o_ack                          (w_main_slave_ack[MAIN_NIC_SLAVE_TCM]),
        .o_data                         (w_main_slave_rdata[MAIN_NIC_SLAVE_TCM])
    );

    wire    w_uart_txen;

    cmsdk_wb_uart
    U_UART
    (
        .i_clk                          (w_clk),
        .i_reset_n                      (w_reset_n),
        .i_dev_sel                      (w_main_slave_sel[MAIN_NIC_SLAVE_UART]),
        .i_wb_adr                       (w_wb_addr[11:2]),
        .o_wb_dat                       (w_main_slave_rdata[MAIN_NIC_SLAVE_UART]),
        .i_wb_dat                       (w_wb_wdata[19:0]),
        .i_wb_we                        (w_wb_we),
        //.i_wb_sel                       (w_wb_sel),
        //.i_wb_stb                       (w_wb_stb),
        .o_wb_ack                       (w_main_slave_ack[MAIN_NIC_SLAVE_UART]),
        .i_wb_cyc                       (w_wb_cyc),
        .i_rxd                          (i_rx),
        .o_txd                          (o_tx),
        .o_txen                         (w_uart_txen)
    );

    reg[31:0]   r_cnt;
    always_ff @(posedge w_clk)
    begin
        r_cnt <= r_cnt + 1'b1;
    end

    assign  w_main_slave_ack[2] = '1;
    assign  w_main_slave_rdata[2] = r_cnt;

initial
begin
    r_cnt = '0;
end

endmodule
