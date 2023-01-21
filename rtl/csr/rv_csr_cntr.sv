`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_csr_cntr
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[7:0]                   i_idx,
    output  wire[31:0]                  o_data
);

`ifdef EXTENSION_Zicntr
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
        begin
            cntr_cycle <= '0;
            cntr_time <= '0;
            cntr_inst_ret <= '0;
        end
        else
        begin
            cntr_cycle <= cntr_cycle + 1'b1;
        end
    end
`endif

    assign  o_data = 
`ifdef EXTENSION_Zicntr
                    sel_cycle ? cntr_cycle[31:0] :
                    sel_time ? cntr_time[31:0] :
                    sel_inst_ret ? cntr_inst_ret[31:0] :
                    sel_cycleh ? cntr_cycle[63:32] :
                    sel_timeh ? cntr_time[63:32] :
                    sel_inst_reth ? cntr_inst_ret[63:32] :
`endif
                    '1;

endmodule
