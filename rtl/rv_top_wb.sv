`timescale 1ps/1ps

`include "rv_defines.vh"

module rv_top_wb
#(
    parameter logic[31:0] RESET_ADDR    = 32'h0000_0000,
`ifdef TO_SIM
    parameter int IADDR_SPACE_BITS      = 22,
`else
    parameter int IADDR_SPACE_BITS      = 16,
`endif
    parameter logic BRANCH_PREDICTION   = 0,
    parameter int BRANCH_TABLE_SIZE_BITS= 3,
    parameter int INSTR_BUF_ADDR_SIZE   = 2,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_F         = 0,
    parameter logic EXTENSION_M         = 1,
    parameter logic EXTENSION_Zicsr     = 1,
    parameter logic EXTENSION_Zicntr    = 1,
    parameter logic EXTENSION_Zihpm     = 0
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

`ifdef TO_SIM
    generate
        if (!EXTENSION_Zicsr)
        begin : g_csr_check
            if (EXTENSION_Zicntr)
                $error("Invalid configuration! Zicntr w/o Zicsr");
            if (EXTENSION_Zihpm)
                $error("Invalid configuration! Zihpm w/o Zicsr");
        end
        if (BRANCH_PREDICTION & EXTENSION_C)
            $error("Invalid configuration! C and branch prediction");
    endgenerate
`endif

    logic       instr_req;
    logic[IADDR_SPACE_BITS-1:1] instr_addr;
    logic       instr_ack;
    logic[31:0] instr_data;
    logic       data_req;
    logic       data_write;
    logic[31:0] data_addr;
    logic       data_ack;
    logic[31:0] data_wdata;
    logic[31:0] data_rdata;
    logic[3:0]  data_sel;

    logic[11:0] csr_idx;
    logic[4:0]  csr_imm;
    logic       csr_imm_sel;
    logic       csr_write;
    logic       csr_set;
    logic       csr_clear;
    logic       csr_read;
    logic       csr_masked;
    logic       csr_ebreak;
    logic[IADDR_SPACE_BITS-1:1] csr_pc_next;
    logic[31:0] csr_rdata;
    logic[IADDR_SPACE_BITS-1:1] ret_addr;
    logic       csr_to_trap;
    logic[IADDR_SPACE_BITS-1:1] csr_trap_pc;
    logic       csr_oread;
    logic[31:0] reg_rdata1;
    logic       instr_issued;

    rv_core
    #(
        .RESET_ADDR                     (RESET_ADDR),
        .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
        .BRANCH_PREDICTION              (BRANCH_PREDICTION),
        .BRANCH_TABLE_SIZE_BITS         (BRANCH_TABLE_SIZE_BITS),
        .INSTR_BUF_ADDR_SIZE            (INSTR_BUF_ADDR_SIZE),
        .EXTENSION_C                    (EXTENSION_C),
        .EXTENSION_F                    (EXTENSION_F),
        .EXTENSION_M                    (EXTENSION_M),
        .EXTENSION_Zicsr                (EXTENSION_Zicsr)
    )
    u_core
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
`ifdef TO_SIM
        .o_debug                        (o_debug),
`endif
        .o_csr_idx                      (csr_idx),
        .o_csr_imm                      (csr_imm),
        .o_csr_imm_sel                  (csr_imm_sel),
        .o_csr_write                    (csr_write),
        .o_csr_set                      (csr_set),
        .o_csr_clear                    (csr_clear),
        .o_csr_read                     (csr_read),
        .o_csr_masked                   (csr_masked),
        .o_csr_ebreak                   (csr_ebreak),
        .o_csr_pc_next                  (csr_pc_next),
        .i_csr_to_trap                  (csr_to_trap),
        .i_csr_trap_pc                  (csr_trap_pc),
        .i_csr_read                     (csr_oread),
        .i_csr_ret_addr                 (ret_addr),
        .i_csr_data                     (csr_rdata),
        .o_reg_rdata1                   (reg_rdata1),
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
        .i_data_rdata                   (data_rdata),
        .o_instr_issued                 (instr_issued)
    );

    generate
        if (EXTENSION_Zicsr)
        begin : g_csr
            rv_csr
            #(
                .IADDR_SPACE_BITS               (IADDR_SPACE_BITS),
                .EXTENSION_C                    (EXTENSION_C),
                .EXTENSION_Zicntr               (EXTENSION_Zicntr),
                .EXTENSION_Zihpm                (EXTENSION_Zihpm)
            )
            u_st3_csr
            (
                .i_clk                          (i_clk),
                .i_reset_n                      (i_reset_n),
                .i_reg_data                     (reg_rdata1),
                .i_idx                          (csr_idx),
                .i_imm                          (csr_imm),
                .i_imm_sel                      (csr_imm_sel),
                .i_write                        (csr_write),
                .i_set                          (csr_set),
                .i_clear                        (csr_clear),
                .i_read                         (csr_read),
                .i_masked                       (csr_masked),
                .i_ebreak                       (csr_ebreak),
                .i_pc_next                      (csr_pc_next),
                .i_instr_issued                 (instr_issued),
                .o_read                         (csr_oread),
                .o_ret_addr                     (ret_addr),
                .o_csr_to_trap                  (csr_to_trap),
                .o_trap_pc                      (csr_trap_pc),
                .o_data                         (csr_rdata)
            );
        end
        else
        begin : g_nocsr
            /* verilator lint_off UNUSEDSIGNAL */
            logic dummy;
            /* verilator lint_on UNUSEDSIGNAL */
            assign csr_oread = '0;
            assign ret_addr = '0;
            assign csr_to_trap = '0;
            assign csr_trap_pc = '0;
            assign csr_rdata = '0;
            assign dummy = (|reg_rdata1) | (|csr_idx) | (|csr_imm) | csr_imm_sel |
                            csr_write | csr_set | csr_clear | csr_read | csr_ebreak |
                            (|csr_pc_next) | instr_issued;
        end
    endgenerate

    assign  instr_data = i_wb_dat;
    assign  data_rdata = i_wb_dat;
    assign  data_ack = i_wb_ack & (!instr_ack);
    assign  instr_ack = i_wb_ack & (!data_req) & instr_req;

    assign o_wb_adr = data_req ? data_addr : { RESET_ADDR[31:IADDR_SPACE_BITS], instr_addr, 1'b0 };
    assign o_wb_dat = data_wdata;
    assign o_wb_we = data_req ? data_write : '0;
    assign o_wb_sel = data_req ? data_sel : '1;
    assign o_wb_stb = '1;
    assign o_wb_cyc = '1;

initial
    instr_data = '0;

endmodule
