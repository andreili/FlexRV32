`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_csr_cntr
#(
    parameter logic TIMER_ENABLE        = 0
)
/* verilator lint_off UNUSEDSIGNAL */
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[7:0]                   i_idx,
    input   wire                        i_instr_issued,
    input   wire                        i_timer_tick,
    output  wire[31:0]                  o_data
);
/* verilator lint_on UNUSEDSIGNAL */

    logic   sel_cycle;
    logic   sel_time;
    logic   sel_inst_ret;
    logic   sel_cycleh;
    logic   sel_timeh;
    logic   sel_inst_reth;

    assign  sel_cycle     = (i_idx[7:0] == 8'h00);
    assign  sel_time      = (i_idx[7:0] == 8'h01);
    assign  sel_inst_ret  = (i_idx[7:0] == 8'h02);
    assign  sel_cycleh    = (i_idx[7:0] == 8'h80);
    assign  sel_timeh     = (i_idx[7:0] == 8'h81);
    assign  sel_inst_reth = (i_idx[7:0] == 8'h82);

    logic[63:0] cntr_cycle;
    logic[63:0] cntr_time;
    logic[63:0] cntr_inst_ret;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            cntr_cycle <= '0;
        else
            cntr_cycle <= cntr_cycle + 1'b1;
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            cntr_inst_ret <= '0;
        else if (i_instr_issued)
            cntr_inst_ret <= cntr_inst_ret + 1'b1;
    end

    generate
        if (TIMER_ENABLE)
        begin : g_timer
            always_ff @(posedge i_clk)
            begin
                if (!i_reset_n)
                    cntr_time <= '0;
                else if (i_timer_tick)
                    cntr_time <= cntr_time + 1'b1;
            end
        end
        else
        begin : g_timer_dummy
            assign cntr_time = '0;
        end
    endgenerate

    assign  o_data =
                    sel_cycle ? cntr_cycle[31:0] :
                    sel_time ? cntr_time[31:0] :
                    sel_inst_ret ? cntr_inst_ret[31:0] :
                    sel_cycleh ? cntr_cycle[63:32] :
                    sel_timeh ? cntr_time[63:32] :
                    sel_inst_reth ? cntr_inst_ret[63:32] :
                    '0;

endmodule
