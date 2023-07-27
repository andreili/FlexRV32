`timescale 1ps/1ps

`include "../rv_defines.vh"
`ifndef TO_SIM
`include "../rv_structs.vh"
`endif

module rv_csr_machine
#(
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_M         = 1,
    parameter logic EXTENSION_Zicntr    = 1,
    parameter logic EXTENSION_Zihpm     = 0
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_sel,
    input   wire[31:0]                  i_data,
    input   wire[7:0]                   i_idx,
    input   wire                        i_write,
    input   wire                        i_set,
    input   wire                        i_clear,
    input   wire[31:1]                  i_pc,
    input   wire                        i_ebreak,
    input   wire                        i_int_timer,
    input   wire                        i_int_ext,
    output  wire[31:1]                  o_ret_addr,
    output  wire[31:1]                  o_trap_pc,
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
        .i_reset_n                      (i_reset_n), \
        .i_sel                          (sel), \
        .i_data                         (i_data), \
        .i_write                        (i_write), \
        .i_set                          (i_set), \
        .i_clear                        (i_clear), \
        .o_data                         (name``_data)  \
    );

    //localparam  MODE_U = 2'b00;
    //localparam  MODE_S = 2'b01;
    //localparam  MODE_M = 2'b11;

    logic   sel_mstatus;
    logic   sel_misa;
    logic   sel_mie;
    logic   sel_mtvec;
    logic   sel_mcounteren;
    logic   sel_mstatush;
    logic   sel_mscratch;
    logic   sel_mepc;
    logic   sel_mcause;
    //logic   sel_mtval;
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
    //assign  sel_mtval      = i_sel && (i_idx[7:0] == 8'h43);
    assign  sel_mip        = i_sel && (i_idx[7:0] == 8'h44);

    `CSR_REG(mtvec, 32, sel_mtvec)          // Machine Trap Vector Base Address Register
    `CSR_REG(mscratch, 32, sel_mscratch)
    //`CSR_REG(mtval, 32, sel_mtval)

    /*logic[1:0]  cur_mode;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            cur_mode <= MODE_M;
    end*/

    // Machine mode interrupt enable
    logic   MIE;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            MIE <= '0;
        else if (sel_mstatus & i_write)
            MIE <= i_data[3];
    end

    // Current mode interrupt enable
    logic   xIE;
`ifdef S_MODE
    assign  xIE = (cur_mode == MODE_M) ? MIE : SIE;
`else
    assign  xIE = MIE;
`endif

    logic[31:0] mstatus_data;
    assign mstatus_data =
        {
            28'b0,
            MIE,
            3'b000
        };
    logic[31:0] mstatush_data;
    assign mstatush_data =
        {
            32'b0
        };

    // Machine mode External interrupt enable
    logic   MEIE;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            MEIE <= '0;
        else if (sel_mie & i_write)
            MEIE <= i_data[11];
    end

    // Machine mode Timer interrupt enable
    logic   MTIE;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            MTIE <= '0;
        else if (sel_mie & i_write)
            MTIE <= i_data[7];
    end

    // Machine mode Software interrupt enable
    logic   MSIE;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            MSIE <= '0;
        else if (sel_mie & i_write)
            MSIE <= i_data[3];
    end

    logic[31:0] mie_data;
    assign mie_data =
        {
            20'b0,
            MEIE,
            3'b000,
            MTIE,
            3'b000,
            MSIE,
            3'b000
        };

    logic  int_soft, int_timer, int_ext;
    assign int_soft  = i_ebreak | (1'b0 & & xIE & MSIE); // TODO - software
    assign int_timer = (i_int_timer & & xIE & MTIE);
    assign int_ext   = (i_int_ext & & xIE & MEIE);

    logic[31:1] mepc_data;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            mepc_data <= '0;
        else if (int_soft)
            mepc_data <= i_pc;
        else if (sel_mepc & i_write)
            mepc_data <= i_data[31:1];
    end

    logic[31:0] mcause_data;
    logic       mcause_is_int, mcause_is_int_next;
    logic[3:0]  mcause_code, mcause_code_next;
    assign      mcause_data = { mcause_is_int, {(32-1-4){1'b0}}, mcause_code };
    assign      mcause_is_int_next = 1'b0;
    assign      mcause_code_next =
                    int_soft  ? 4'd3  :
                    int_timer ? 4'd7  :
                    int_ext   ? 4'd11 :
                    '0;
    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            mcause_is_int <= '0;
            mcause_code <= '0;
        end
        else if (int_soft)
        begin
            mcause_is_int <= mcause_is_int_next;
            mcause_code <= mcause_code_next;
        end
    end

    logic[31:0] misa_data;
    assign  misa_data = {
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
            EXTENSION_M,
            1'b0,   // L ext
            1'b0,   // K ext
            1'b0,   // J ext
            1'b1,   // I ext
            1'b0,   // H ext
            1'b0,   // G ext
            1'b0,   // F ext
            1'b0,   // E ext
            1'b0,   // D ext
            EXTENSION_C,
            1'b0,   // B ext
            1'b0    // A ext
            };

    logic[1:0]  trap_bar_mode;
    logic[29:0] trap_bar_base;

    assign  trap_bar_mode = mtvec_data[1:0];
    assign  trap_bar_base = mtvec_data[31:2];

    logic[31:0] mcounteren_lo;
    logic[31:0] mcounteren_hi;
    generate
        if (EXTENSION_Zicntr)
        begin : g_cntr
            `CSR_REG(mcounteren_lo, 3, sel_mcounteren)
            assign  mcounteren_lo = mcounteren_lo_data;
        end
        else
        begin : g_cntr_dummy
            assign mcounteren_lo = '0;
        end

        if (EXTENSION_Zihpm)
        begin : g_hpm
            `CSR_REG(mcounteren_hi, 29, sel_mcounteren)
            assign  mcounteren_hi = { mcounteren_hi_data[28:0], 3'b0 };
        end
        else
        begin : g_hpm_dummy
            assign mcounteren_hi = '0;
        end
    endgenerate

    logic[11:0] mip_data;
    assign  mip_data = {
            i_int_ext,      // 11, MEIP
            1'b0,   // 10
            1'b0,   //  9 SEIP
            1'b0,   //  8
            i_int_timer,    //  7 MTIP
            1'b0,   //  6
            1'b0,   //  5 STIP
            1'b0,   //  4
            1'b0,   //  3 MSIP - not implemented, TODO?
            1'b0,   //  2
            1'b0,   //  1 SSIP
            1'b0    //  0
            };

    logic[31:1] cause_pc;

    assign  cause_pc = { trap_bar_base, 1'b0 } + { mcause_data[29:0], 1'b0 };
    assign  o_trap_pc = (trap_bar_mode == 2'b00) ? { trap_bar_base, 1'b0 } : // Direct
                        (trap_bar_mode == 2'b01) ? cause_pc :  // Vectored
                        '0;
    assign  o_ret_addr = mepc_data;

    assign  o_data = sel_mstatus ? mstatus_data :
                     sel_misa ? misa_data :
                     sel_mie ? mie_data :
                     sel_mtvec ? mtvec_data :
                     sel_mcounteren ? (mcounteren_hi | mcounteren_lo) :
                     sel_mstatush ? mstatush_data :
                     sel_mscratch ? mscratch_data :
                     sel_mepc ? { mepc_data, 1'b0 } :
                     sel_mcause ? mcause_data :
                     //sel_mtval ? mtval_data :
                     sel_mip ? { {20{1'b0}}, mip_data } :
                     '0;

endmodule
