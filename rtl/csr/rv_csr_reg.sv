`timescale 1ps/1ps

module rv_csr_reg
#(
    parameter int WIDTH                 = 32
)
(
    input   wire                        i_clk,
    input   wire                        i_sel,
    input   wire[31:0]                  i_data,
    input   wire                        i_write,
    input   wire                        i_set,
    input   wire                        i_clear,
    output  wire[31:0]                  o_data
);

    logic[(WIDTH-1):0] in_data;
    logic[(WIDTH-1):0] data_set;
    logic[(WIDTH-1):0] data_clear;
    logic[(WIDTH-1):0] data;
    logic[(WIDTH-1):0] data_next;

    assign  in_data    = i_data[(WIDTH-1):0];
    assign  data_set   = data | in_data;
    assign  data_clear = data & (~in_data);
    assign  data_next = i_clear ? data_clear :
                        i_set ? data_set :
                        in_data;

    always_ff @(posedge i_clk)
    begin
        if (i_sel & (i_write | i_set | i_clear))
            data <= data_next;
    end

    generate
        if (WIDTH == 32)
            assign  o_data = data;
        else
        begin : g_out
            assign  o_data = { {(32-WIDTH){1'b0}}, data};
        /* verilator lint_off UNUSEDSIGNAL */
            logic  dummy;
            assign  dummy = |i_data[31:WIDTH];
        /* verilator lint_on UNUSEDSIGNAL */
        end
    endgenerate

endmodule
