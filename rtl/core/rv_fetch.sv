`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter   RESET_ADDR = 32'h0000_0000
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[31:0]                  i_pc_target,
    input   wire                        i_pc_select,
    input   wire                        i_pc_inc,
    input   wire                        i_data_latch,
    input   wire[31:0]                  i_instruction,
    output  fetch_bus_t                 o_bus
);

    logic[31:0] fetch_pc;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_data_buf;
    //logic       fetch_ready;
`ifdef BRANCH_PREDICTION_SIMPLE
    logic[31:0] fetch_bp_lr;    // TODO
    logic[6:0]  fetch_bp_op;
    //logic[4:0]  fetch_bp_rd;
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

    assign  fetch_bp_lr = 32'h0000_0010;
`endif

    assign  fetch_pc_next = 
        i_pc_select ? i_pc_target :
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
        else if (i_pc_inc)
        begin
            fetch_pc <= fetch_pc_next;
        end
    end

    always_ff @(posedge i_clk)
    begin
        if (i_data_latch && (i_reset_n))
            fetch_data_buf <= i_instruction;
        else
            fetch_data_buf <= '0;
    end

    /*always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            fetch_ready <= '0;
        else if ((state_cur == STATE_FETCH) && (i_wb_ack))
            fetch_ready <= '1;
        else
            fetch_ready <= '0;
    end*/

`ifdef BRANCH_PREDICTION_SIMPLE
    assign  fetch_bp_op        = fetch_data_buf[6:0];
    //assign  fetch_bp_rd        = fetch_data_buf[11:7];
    assign  fetch_bp_rs        = fetch_data_buf[19:15];
    assign  fetch_bp_b_sign    = fetch_data_buf[31];
    assign  fetch_bp_b_offs    = { {20{fetch_data_buf[31]}}, fetch_data_buf[7], fetch_data_buf[30:25], fetch_data_buf[11:8], 1'b0 };
    assign  fetch_bp_jalr_offs = { {21{fetch_data_buf[31]}}, fetch_data_buf[30:20] };
    assign  fetch_bp_jal_offs  = { {12{fetch_data_buf[31]}}, fetch_data_buf[19:12], fetch_data_buf[20], fetch_data_buf[30:21], 1'b0 };
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

    assign  o_bus.pc = fetch_pc;
    assign  o_bus.instruction = fetch_data_buf;

endmodule
