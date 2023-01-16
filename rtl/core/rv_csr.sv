`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

/* verilator lint_off UNUSEDSIGNAL */
module rv_csr
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[31:0]                  i_reg_data,
    input   wire[11:0]                  i_idx,
    input   wire[4:0]                   i_imm,
    input   wire                        i_imm_sel,
    input   wire                        i_write,
    input   wire                        i_set,
    input   wire                        i_clear,
    input   wire                        i_read,
    input   wire[31:0]                  i_pc,
    input   wire                        i_ebreak,
    output  wire[31:0]                  o_data,
    output  wire[31:0]                  o_trap_pc,
    output  wire                        o_read
);

    logic[11:0] idx;
    logic[4:0]  imm;
    logic       imm_sel;
    logic       write;
    logic       set;
    logic       clear;
    logic       read;

    always_ff @(posedge i_clk)
    begin
        idx <= i_idx;
        imm <= i_imm;
        imm_sel <= i_imm_sel;
        write <= i_write;
        set <= i_set;
        clear <= i_clear;
        read <= i_read;
    end

    logic[31:0] write_value;

    assign  write_value = imm_sel ? { {27{1'b0}}, imm } : i_reg_data;

    logic[1:0]  idx_category;
    logic[1:0]  idx_sub_category;

    assign  idx_category = idx[9:8];
    assign  idx_sub_category = idx[11:10];

    logic   user_level_category;
    logic   supervisor_level_category;
    logic   hypervisor_level_category;
    logic   machine_level_category;

    assign  user_level_category       = (idx_category == 2'b00);
    assign  supervisor_level_category = (idx_category == 2'b01);
    assign  hypervisor_level_category = (idx_category == 2'b10);
    assign  machine_level_category    = (idx_category == 2'b11);

/* verilator lint_on UNUSEDSIGNAL */

    logic[31:0] rdata_user, rdata_supervisor, rdata_hypervisor, rdata_machine;

    assign  rdata_supervisor = '0;
    assign  rdata_hypervisor = '0;

`ifdef EXTENSION_Zicntr
    rv_csr_cntr
    u_cntr
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_idx                          (idx[7:0]),
        .o_data                         (rdata_user)
    );
`endif

    int_ctrl_csr_t o_int_ctr; // TODO
    rv_csr_machine
    u_machine
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_sel                          (machine_level_category),
        .i_data                         (write_value),
        .i_idx                          (idx[7:0]),
        .i_write                        (write),
        .i_set                          (set),
        .i_clear                        (clear),
        .i_int_ctr_state                ('0),
        .i_pc                           (i_pc),
        .i_ebreak                       (i_ebreak),
        .o_int_ctr                      (o_int_ctr),
        .o_trap_pc                      (o_trap_pc),
        .o_data                         (rdata_machine)
    );

    assign  o_data = user_level_category ? rdata_user :
                     supervisor_level_category ? rdata_supervisor :
                     hypervisor_level_category ? rdata_hypervisor :
                     rdata_machine;
    assign  o_read = read;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;

    assign  dummy = user_level_category | supervisor_level_category | hypervisor_level_category | (|o_int_ctr);
/* verilator lint_on UNUSEDSIGNAL */

endmodule
