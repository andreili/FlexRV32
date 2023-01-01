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
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire[31:0]                  o_addr,
    output  wire                        o_cyc,
    output  fetch_bus_t                 o_bus
);

    logic       bus_cyc;
    logic[31:0] fetch_pc;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_pc_incr;
    logic       free_dword_or_more;
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
        (!i_reset_n) ? RESET_ADDR :
        i_pc_select ? i_pc_target :
`ifdef BRANCH_PREDICTION_SIMPLE
        //fetch_bp_need ? fetch_bp_addr :
`endif
        fetch_pc + fetch_pc_incr;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            fetch_pc <= RESET_ADDR;
        else if (i_ack && (free_dword_or_more))
            fetch_pc <= fetch_pc_next;
    end

    /*always_ff @(posedge i_clk)
    begin
        if ((!i_reset_n) | (!free_dword_or_more))
            bus_cyc <= '0;
        else
            bus_cyc <= '1;
    end*/
    assign  bus_cyc = i_reset_n & free_dword_or_more;

    logic   ack_sync;
    always_ff @(posedge i_clk)
    begin
        ack_sync <= i_ack & (!i_pc_select);
    end

    rv_fetch_buf
    u_buf
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc_select                    (i_pc_select),
        .i_ack                          (ack_sync),
        .i_decode_ready                 (i_pc_inc),
        .i_data                         (i_instruction),
        .i_fetch_pc1                    (fetch_pc[1]),
        .i_fetch_pc_next                (fetch_pc_next),
        .o_free_dword_or_more           (free_dword_or_more),
        .o_pc_incr                      (fetch_pc_incr),
        .o_pc                           (o_bus.pc),
        .o_instruction                  (o_bus.instruction)
    );

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

    assign  o_addr = fetch_pc;
    assign  o_cyc = bus_cyc;

endmodule
