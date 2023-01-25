`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter   RESET_ADDR              = 32'h0000_0000,
    parameter   BRANCH_PREDICTION       = 1,
    parameter   INSTR_BUF_ADDR_SIZE     = 2,
    parameter   EXTENSION_Zicsr         = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   wire[31:0]                  i_pc_target,
    input   wire                        i_pc_select,
    input   wire[31:0]                  i_pc_trap,
    input   wire                        i_ebreak,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire[31:0]                  o_addr,
    output  wire                        o_cyc,
    output  wire[31:0]                  o_instruction,
    output  wire[31:0]                  o_pc,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);

    logic[31:0] fetch_pc;
    logic[31:0] fetch_addr;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_pc_incr;
    logic       move_pc;
    logic       branch_pred;
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

    logic       fetch_pc_next_trap_sel;

    assign  fetch_pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  fetch_pc_next = (!i_reset_n) ? RESET_ADDR :
                fetch_pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
`ifdef BRANCH_PREDICTION_SIMPLE
        //fetch_bp_need ? fetch_bp_addr :
`endif
                (fetch_pc + fetch_pc_incr);

    always_ff @(posedge i_clk)
    begin
        if (move_pc)
            fetch_pc <= fetch_pc_next;
    end

    logic   free_dword_or_more;
    logic   ack;

    always_ff @(posedge i_clk)
    begin
        ack <= i_ack & (!i_pc_select);
    end

    logic   fetch_pc_need_change;
    assign  fetch_pc_need_change = i_pc_select | (!i_reset_n) | (i_ebreak & EXTENSION_Zicsr);

    rv_fetch_buf
    #(
        .INSTR_BUF_ADDR_SIZE            (INSTR_BUF_ADDR_SIZE)
    )
    u_buf
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_flush                        (i_flush),
        .i_stall                        (i_stall),
        .i_pc_select                    (fetch_pc_need_change),
        .i_ack                          (ack),
        .i_data                         (i_instruction),
        .i_fetch_pc                     (fetch_pc),
        .i_branch_pred                  (branch_pred),
        .o_free_dword_or_more           (free_dword_or_more),
        .o_pc_incr                      (fetch_pc_incr),
        .o_pc                           (o_pc),
        .o_branch_pred                  (o_branch_pred),
        .o_instruction                  (o_instruction),
        .o_ready                        (o_ready)
    );

    assign  move_pc =  (i_ack & free_dword_or_more) | fetch_pc_need_change;
    assign  o_cyc = i_reset_n & free_dword_or_more & (!fetch_pc_need_change);
    assign  fetch_addr = fetch_pc;

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
`else
    assign  branch_pred = '0;
`endif // BRANCH_PREDICTION_SIMPLE

    assign  o_addr = fetch_addr;

initial
begin
    fetch_pc = '0;
end

endmodule
