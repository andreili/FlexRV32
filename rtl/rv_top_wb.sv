`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_top_wb
#(
    parameter   RESET_ADDR = 32'h0000_0000
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    //
    output  wire[31:0]                  o_wb_adr,
    output  wire[31:0]                  o_wb_dat,
    input   wire[31:0]                  i_wb_dat,
    output  wire                        o_wb_we,
    output  wire[3:0]                   o_wb_sel,
    output  wire                        o_wb_stb,
    input   wire                        i_wb_ack,
`ifdef TO_SIM
    output  wire[31:0]                  o_debug,
`endif
    output  wire                        o_wb_cyc
);

    wire        instr_req;
    wire[31:0]  instr_addr;
    wire        instr_ack;
    wire[31:0]  instr_data;
    wire        data_req;
    wire        data_write;
    wire[31:0]  data_addr;
    wire        data_ack;
    wire[31:0]  data_wdata;
    wire[31:0]  data_rdata;
    wire[3:0]   data_sel;

    assign  instr_data = i_wb_dat;
    assign  data_rdata = i_wb_dat;
    assign  data_ack = i_wb_ack & (!instr_ack);

    rv_core
    #(
        .RESET_ADDR                     (RESET_ADDR)
    )
    u_core
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
    `ifdef TO_SIM
        .o_debug                        (o_debug),
    `endif
        .o_instr_req                    (instr_req),
        .o_instr_addr                   (instr_addr),
        .i_instr_ack                    (instr_ack),
        .i_instr_data                   (instr_data),
        .o_data_req                     (data_req),
        .o_data_write                   (data_write),
        .o_data_addr                    (data_addr),
        .o_data_wdata                   (data_wdata),
        .o_data_sel                     (data_sel),
        .i_data_ack                     (data_ack),
        .i_data_rdata                   (data_rdata)
    );

    logic   instr_ack;

    always_ff @(posedge i_clk)
    begin
        instr_ack <= i_wb_ack & (!data_req) & instr_req;
    end

    assign o_wb_adr = data_req ? data_addr : instr_addr;
    assign o_wb_dat = data_wdata;
    assign o_wb_we = data_req ? data_write : '0;
    assign o_wb_sel = data_req ? data_sel : '1;
    assign o_wb_stb = '1;
    assign o_wb_cyc = '1;

endmodule
