`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

/* verilator lint_off UNUSEDSIGNAL */
module rv_csr
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter logic TIMER_ENABLE        = 0,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_M         = 1,
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
    input   wire                        i_timer_tick,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
    output  wire[31:0]                  o_data,
    output  wire[IADDR_SPACE_BITS-1:1]  o_ret_addr,
    output  wire                        o_csr_to_trap,
    output  wire[IADDR_SPACE_BITS-1:1]  o_trap_pc,
    output  wire                        o_read
);

    logic[11:0] idx;
    logic[4:0]  imm;
    logic       imm_sel;
    logic       write;
    logic       set;
    logic       clear;
    logic       read;
    logic       ebreak;
    logic[IADDR_SPACE_BITS-1:1] pc;

    always_ff @(posedge i_clk)
    begin
        if (!i_masked)
        begin
            write <= i_write;
            set <= i_set;
            clear <= i_clear;
            read <= i_read;
        end
        else
        begin
            write <= '0;
            set <= '0;
            clear <= '0;
            read <= '0;
        end
        idx <= i_idx;
        imm <= i_imm;
        imm_sel <= i_imm_sel;
        pc <= i_pc_next;
        ebreak <= i_ebreak;
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

    generate
        if (EXTENSION_Zicntr)
        begin : g_cntr
            rv_csr_cntr
            #(
                .TIMER_ENABLE                   (TIMER_ENABLE)
            )
            u_cntr
            (
                .i_clk                          (i_clk),
                .i_reset_n                      (i_reset_n),
                .i_idx                          (idx[7:0]),
                .i_instr_issued                 (i_instr_issued),
                .i_timer_tick                   (i_timer_tick),
                .o_data                         (rdata_user)
            );
        end
        else
        begin : g_cntr_dummy
            assign rdata_user = '0;
        end
    endgenerate

    logic[31:1] ret_addr, trap_pc;
    rv_csr_machine
    #(
        .EXTENSION_C                    (EXTENSION_C),
        .EXTENSION_M                    (EXTENSION_M),
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
        .i_pc                           ({ {(32-IADDR_SPACE_BITS){1'b0}}, pc }),
        .i_ebreak                       (ebreak),
        .i_int_timer                    ('0),   // TODO
        .i_int_ext                      ('0),   // TODO
        .o_ret_addr                     (ret_addr),
        .o_trap_pc                      (trap_pc),
        .o_data                         (rdata_machine)
    );

    assign  o_ret_addr = ret_addr[IADDR_SPACE_BITS-1:1];
    assign  o_trap_pc = trap_pc[IADDR_SPACE_BITS-1:1];
    logic[31:0] data;
    assign  data = user_level_category ? rdata_user :
                   supervisor_level_category ? rdata_supervisor :
                   hypervisor_level_category ? rdata_hypervisor :
                   rdata_machine;
                
    logic[31:0] r_data;
    logic       r_read, r_trap;
    always_ff @(posedge i_clk)
    begin
        r_data <= data;
        r_read <= read;
        r_trap <= i_ebreak;
    end
    assign  o_data = r_data;
    assign  o_read = r_read;
    assign  o_csr_to_trap = r_trap;

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;

    assign  dummy = user_level_category | supervisor_level_category | hypervisor_level_category |
                    (|ret_addr) | (|trap_pc);
/* verilator lint_on UNUSEDSIGNAL */

endmodule
