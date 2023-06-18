`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

/* verilator lint_off UNUSEDSIGNAL */
module rv_csr
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_Zicntr    = 1,
    parameter logic EXTENSION_Zihpm     = 0
)
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
    input   wire                        i_masked,
    input   wire                        i_ebreak,
    input   wire                        i_instr_issued,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
    output  wire[31:0]                  o_data,
    output  wire[IADDR_SPACE_BITS-1:1]  o_ret_addr,
    output  wire                        o_csr_to_trap,
    output  wire[IADDR_SPACE_BITS-1:1]  o_trap_pc,
    output  wire                        o_read
);

    logic[11:0] idx, buf_idx;
    logic[4:0]  imm, buf_imm;
    logic       imm_sel, buf_imm_sel;
    logic       write, buf_write;
    logic       set, buf_set;
    logic       clear, buf_clear;
    logic       read, buf_read;
    logic       ebreak, buf_ebreak;
    logic[IADDR_SPACE_BITS-1:1] pc, buf_pc;
    logic[31:0] reg_data;//, buf_reg_data;

    always_ff @(posedge i_clk)
    begin
        if (!i_masked)
        begin
            buf_write <= i_write;
            buf_set <= i_set;
            buf_clear <= i_clear;
            buf_read <= i_read;
        end
        else
        begin
            buf_write <= '0;
            buf_set <= '0;
            buf_clear <= '0;
            buf_read <= '0;
        end
        buf_idx <= i_idx;
        buf_imm <= i_imm;
        buf_imm_sel <= i_imm_sel;
        buf_pc <= i_pc_next;
        buf_ebreak <= i_ebreak;
        //buf_reg_data <= i_reg_data;
    end

    always_ff @(posedge i_clk)
    begin
        write <= buf_write;
        set <= buf_set;
        clear <= buf_clear;
        read <= buf_read;
        idx <= buf_idx;
        imm <= buf_imm;
        imm_sel <= buf_imm_sel;
        pc <= buf_pc;
        ebreak <= buf_ebreak;
        reg_data <= i_reg_data;
    end

    logic[31:0] write_value;

    assign  write_value = imm_sel ? { {27{1'b0}}, imm } : reg_data;

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

    generate
        if (EXTENSION_Zicntr)
        begin : g_cntr
            rv_csr_cntr
            u_cntr
            (
                .i_clk                          (i_clk),
                .i_reset_n                      (i_reset_n),
                .i_idx                          (idx[7:0]),
                .i_instr_issued                 (i_instr_issued),
                .o_data                         (rdata_user)
            );
        end
        else
            assign rdata_user = '0;
    endgenerate

    logic[31:1] ret_addr, trap_pc;
    int_ctrl_csr_t o_int_ctr; // TODO
    rv_csr_machine
    #(
        .EXTENSION_C                    (EXTENSION_C),
        .EXTENSION_Zicntr               (EXTENSION_Zicntr),
        .EXTENSION_Zihpm                (EXTENSION_Zihpm)
    )
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
        .i_pc                           ({ {(32-IADDR_SPACE_BITS){1'b0}}, pc }),
        .i_ebreak                       (ebreak),
        .o_int_ctr                      (o_int_ctr),
        .o_ret_addr                     (ret_addr),
        .o_trap_pc                      (trap_pc),
        .o_data                         (rdata_machine)
    );

    assign  o_ret_addr = ret_addr[IADDR_SPACE_BITS-1:1];
    assign  o_trap_pc = trap_pc[IADDR_SPACE_BITS-1:1];
    assign  o_csr_to_trap = i_ebreak;
    assign  o_data = user_level_category ? rdata_user :
                     supervisor_level_category ? rdata_supervisor :
                     hypervisor_level_category ? rdata_hypervisor :
                     rdata_machine;
    assign  o_read = read;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;

    assign  dummy = user_level_category | supervisor_level_category | hypervisor_level_category |
                    (|o_int_ctr) | (|ret_addr) | (|trap_pc);
/* verilator lint_on UNUSEDSIGNAL */

endmodule
