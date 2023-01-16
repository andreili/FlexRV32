`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_csr_machine
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_sel,
    input   wire[31:0]                  i_data,
    input   wire[7:0]                   i_idx,
    input   wire                        i_write,
    input   wire                        i_set,
    input   wire                        i_clear,
    input   int_ctrl_state_csr_t        i_int_ctr_state,
    input   wire[31:0]                  i_pc,
    input   wire                        i_ebreak,
    output  int_ctrl_csr_t              o_int_ctr,
    output  wire[31:0]                  o_trap_pc,
    output  wire[31:0]                  o_data
);

`define CSR_REG(name, width, sel) \
    logic[31:0] name``_data; \
    rv_csr_reg \
    #( \
        .WIDTH  (width) \
    ) \
    u_``name \
    ( \
        .i_clk                          (i_clk), \
        .i_sel                          (sel), \
        .i_data                         (i_data), \
        .i_write                        (i_write), \
        .i_set                          (i_set), \
        .i_clear                        (i_clear), \
        .o_data                         (name``_data)  \
    );

    logic   sel_mstatus;
    logic   sel_misa;
    logic   sel_mie;
    logic   sel_mtvec;
    logic   sel_mcounteren;
    logic   sel_mstatush;
    logic   sel_mscratch;
    logic   sel_mepc;
    logic   sel_mcause;
    logic   sel_mtval;
    logic   sel_mip;

    assign  sel_mstatus    = i_sel && (i_idx[7:0] == 8'h00);
    assign  sel_misa       = i_sel && (i_idx[7:0] == 8'h01);
    assign  sel_mie        = i_sel && (i_idx[7:0] == 8'h04);
    assign  sel_mtvec      = i_sel && (i_idx[7:0] == 8'h05);
    assign  sel_mcounteren = i_sel && (i_idx[7:0] == 8'h06);
    assign  sel_mstatush   = i_sel && (i_idx[7:0] == 8'h10);
    assign  sel_mscratch   = i_sel && (i_idx[7:0] == 8'h40);
    assign  sel_mepc       = i_sel && (i_idx[7:0] == 8'h41);
    assign  sel_mcause     = i_sel && (i_idx[7:0] == 8'h42);
    assign  sel_mtval      = i_sel && (i_idx[7:0] == 8'h43);
    assign  sel_mip        = i_sel && (i_idx[7:0] == 8'h44);

    `CSR_REG(mstatus, 32, sel_mstatus)
    `CSR_REG(mie, 12, sel_mie)  // Machine Interrupt Enable
    `CSR_REG(mtvec, 32, sel_mtvec)
`ifdef EXTENSION_Zicntr
    `CSR_REG(mcounteren_lo, 3, sel_mcounteren)
`endif
    `CSR_REG(mstatush, 32, sel_mstatush)
    `CSR_REG(mscratch, 32, sel_mscratch)
    //`CSR_REG(mepc, 32, sel_mepc)
    `CSR_REG(mcause, 32, sel_mcause)
    `CSR_REG(mtval, 32, sel_mtval)
    //`CSR_REG(mip, 12, sel_mip)  // Machine Interrupt Pending

    logic[31:0] mepc_data;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            mepc_data <= '0;
        else if (i_ebreak)
            mepc_data <= i_pc;
        else if (sel_mepc & i_write)
            mepc_data <= i_data;
    end

    logic[31:0] misa_data = {
            2'b01,  // MXL - XLEN=32
            4'b0,
            1'b0,   // Z ext
            1'b0,   // Y ext
            1'b0,   // X ext
            1'b0,   // W ext
            1'b0,   // V ext
            1'b0,   // U ext
            1'b0,   // T ext
            1'b0,   // S ext
            1'b0,   // R ext
            1'b0,   // Q ext
            1'b0,   // P ext
            1'b0,   // O ext
            1'b0,   // N ext
            1'b0,   // M ext
            1'b0,   // L ext
            1'b0,   // K ext
            1'b0,   // J ext
            1'b1,   // I ext
            1'b0,   // H ext
            1'b0,   // G ext
            1'b0,   // F ext
            1'b0,   // E ext
            1'b0,   // D ext
        `ifdef EXTENSION_C
            1'b1,   // C ext
        `else
            1'b0,   // C ext
        `endif
            1'b0,   // B ext
            1'b0    // A ext
            };

    logic[1:0]  trap_bar_mode;
    logic[29:0] trap_bar_base;

    assign  trap_bar_mode = mtvec_data[1:0];
    assign  trap_bar_base = mtvec_data[31:2];

    logic[31:0]  mcounteren_lo;
    logic[31:0] mcounteren_hi;
`ifdef EXTENSION_Zicntr
    assign  mcounteren_lo = mcounteren_lo_data;
`else
    assign  mcounteren_lo = '0;
`endif
`ifdef EXTENSION_Zihpm
    assign  mcounteren_hi = mcounteren_hi_data;
`else
    assign  mcounteren_hi = '0;
`endif

    logic[11:0] mip_data;
    assign  mip_data = {
            i_int_ctr_state.pending_external,   // 11, MEIP
            1'b0,   // 10
            1'b0,   //  9 SEIP
            1'b0,   //  8
            i_int_ctr_state.pending_timer,      //  7 MTIP
            1'b0,   //  6
            1'b0,   //  5 STIP
            1'b0,   //  4
            i_int_ctr_state.pending_soft,       //  3 MSIP
            1'b0,   //  2
            1'b0,   //  1 SSIP
            1'b0    //  0
            };

    assign  o_int_ctr.enable_external = mie_data[11]; // 11, MEIE
    // 9 SEIE
    assign  o_int_ctr.enable_timer    = mie_data[ 7]; //  7 MTIE
    //  5 STIE
    assign  o_int_ctr.enable_soft     = mie_data[ 3]; //  3 MSIE
    //  1 SSIE

    logic[31:0] cause_pc;

    assign  cause_pc = { trap_bar_base, 2'b00 } + { mcause_data[29:0], 2'b00 };
    assign  o_trap_pc = (trap_bar_mode == 2'b00) ? { trap_bar_base, 2'b00 } : // Direct
                        (trap_bar_mode == 2'b01) ? cause_pc :  // Vectored
                        '0;

    assign  o_data = sel_mstatus ? mstatus_data :
                     sel_misa ? misa_data :
                     sel_mie ? mie_data :
                     sel_mtvec ? mtvec_data :
                     sel_mcounteren ? (mcounteren_hi | mcounteren_lo) :
                     sel_mstatush ? mstatush_data :
                     sel_mscratch ? mscratch_data :
                     sel_mepc ? mepc_data :
                     sel_mcause ? mcause_data :
                     sel_mtval ? mtval_data :
                     sel_mip ? { {20{1'b0}}, mip_data } :
                     '0;

endmodule
