`timescale 1ps/1ps

`include "rv_defines.vh"
`include "rv_opcodes.vh"

module rv_core
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

    logic[3:0]  state_cur, state_nxt;
    localparam  STATE_FETCH = 0;
    localparam  STATE_RS = 1;
    localparam  STATE_ALU1 = 2;
    localparam  STATE_MEM = 3;
    localparam  STATE_WR = 4;

    always_comb
    begin
        case (state_cur)
        STATE_FETCH: state_nxt = i_wb_ack ? STATE_RS : STATE_FETCH;
        STATE_RS: state_nxt = STATE_ALU1;
        STATE_ALU1: state_nxt = STATE_MEM;
        STATE_MEM: state_nxt = STATE_WR;
        STATE_WR: state_nxt = STATE_FETCH;
        default: state_nxt = STATE_FETCH;
        endcase
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            state_cur <= STATE_FETCH;
        else
            state_cur <= state_nxt;
    end

    logic[31:0] fetch_pc;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_data_buf;
    logic[31:0] fetch_data;
    logic       fetch_ready;
`ifdef BRANCH_PREDICTION_SIMPLE
    logic[31:0] fetch_bp_lr;    // TODO
    logic[6:0]  fetch_bp_op;
    logic[4:0]  fetch_bp_rd;
    logic[4:0]  fetch_bp_rs;
    logic       fetch_bp_b_sign;
    logic[31:0] fetch_bp_b_offs;
    logic[31:0] fetch_bp_jalr_offs;
    logic[31:0] fetch_bp_jal_offs;
    logic[31:0] fetch_bp_b_addr;
    logic[31:0] fetch_bp_jalr_addr;
    logic[31:0] fetch_bp_jal_addr;
    logic[31:0] fetch_bp_addr;
    logic       fetch_bp_is_b;
    logic       fetch_bp_is_jalr;
    logic       fetch_bp_is_jal;
    logic       fetch_bp_need;
`endif

    assign  fetch_pc_next = 
`ifdef BRANCH_PREDICTION_SIMPLE
        //fetch_bp_need ? fetch_bp_addr :
`endif
        fetch_pc + 4;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            fetch_pc <= RESET_ADDR;
        end
        else if (state_nxt == STATE_FETCH)
        begin
            fetch_pc <= fetch_pc_next;
        end
    end

    always_ff @(posedge i_clk)
    begin
        if (state_cur == STATE_RS)
            fetch_data_buf <= i_wb_dat;
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            fetch_ready <= '0;
        else if ((state_cur == STATE_FETCH) && (i_wb_ack))
            fetch_ready <= '1;
        else
            fetch_ready <= '0;
    end

    assign  fetch_data = (state_cur == STATE_RS) ? i_wb_dat : fetch_data_buf;

`ifdef BRANCH_PREDICTION_SIMPLE
    assign  fetch_bp_op        = fetch_data[6:0];
    assign  fetch_bp_rd        = fetch_data[11:7];
    assign  fetch_bp_rs        = fetch_data[19:15];
    assign  fetch_bp_b_sign    = fetch_data[31];
    assign  fetch_bp_b_offs    = { {20{fetch_data[31]}}, fetch_data[7], fetch_data[30:25], fetch_data[11:8], 1'b0 };
    assign  fetch_bp_jalr_offs = { {21{fetch_data[31]}}, fetch_data[30:20] };
    assign  fetch_bp_jal_offs  = { {12{fetch_data[31]}}, fetch_data[19:12], fetch_data[20], fetch_data[30:21], 1'b0 };
    assign  fetch_bp_b_addr    = fetch_pc + fetch_bp_b_offs;
    assign  fetch_bp_jalr_addr = fetch_bp_lr + fetch_bp_jalr_offs;
    assign  fetch_bp_jal_addr  = fetch_pc + fetch_bp_jal_offs;
    assign  fetch_bp_is_b      = (fetch_bp_op == { RV32_OPC_B,    RV32_OPC_DET }) && fetch_bp_b_sign;
    assign  fetch_bp_is_jalr   = (fetch_bp_op == { RV32_OPC_JALR, RV32_OPC_DET }) && (fetch_bp_rs == 1); /*ra, ret*/
    assign  fetch_bp_is_jal    = (fetch_bp_op == { RV32_OPC_JAL,  RV32_OPC_DET });

    assign  fetch_bp_need = (fetch_bp_is_jalr | fetch_bp_is_jal | fetch_bp_is_b);
    always_comb
    begin
        case (1'b1)
        fetch_bp_is_b:    fetch_bp_addr = fetch_bp_b_addr;
        fetch_bp_is_jalr: fetch_bp_addr = fetch_bp_jalr_addr;
        fetch_bp_is_jal:  fetch_bp_addr = fetch_bp_jal_addr;
        endcase
    end
`endif

    assign o_wb_adr = fetch_pc;
    assign o_wb_dat = '0;
    assign o_wb_we = '0;
    assign o_wb_sel = '0;
    assign o_wb_stb = '0;
    assign o_debug = '0;
    assign o_wb_cyc = '0;

    assign  fetch_bp_lr = 32'h0000_0010;

    logic[127:0] dbg_state;
    always_comb
    begin
        case (state_cur)
        STATE_FETCH: dbg_state = "fetch";
        STATE_RS:    dbg_state = "rs";
        STATE_ALU1:  dbg_state = "alu";
        STATE_MEM:   dbg_state = "mem";
        STATE_WR:    dbg_state = "wr";
        endcase
    end

endmodule
