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
`ifdef EXTENSION_Zicsr
    input   wire[31:0]                  i_pc_trap,
    input   wire                        i_ebreak,
`endif
    input   wire                        i_fetch_start,
    //input   wire                        i_pc_inc,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    output  wire[31:0]                  o_addr,
    output  wire                        o_cyc,
    output  fetch_bus_t                 o_bus
);

    logic[31:0] fetch_pc;
    logic[31:0] fetch_addr;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_pc_incr;
    logic       move_pc;
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
`ifdef EXTENSION_Zicsr
    logic       ebreak;
    always_ff @(posedge i_clk)
    begin
        ebreak <= i_ebreak;
    end
`endif

    assign  fetch_pc_next = 
        (!i_reset_n) ? RESET_ADDR :
`ifdef EXTENSION_Zicsr
        ebreak ? i_pc_trap :
`endif
        i_pc_select ? i_pc_target :
`ifdef BRANCH_PREDICTION_SIMPLE
        //fetch_bp_need ? fetch_bp_addr :
`endif
        fetch_pc + fetch_pc_incr;

    always_ff @(posedge i_clk)
    begin
        if (move_pc)
            fetch_pc <= fetch_pc_next;
    end

`ifdef PREFETCH_BUFFER
    logic   free_dword_or_more;
    logic   ack_sync;

    always_ff @(posedge i_clk)
    begin
        ack_sync <= i_ack & (!i_pc_select);
    end

    rv_fetch_buf
    #(
        .INSTR_BUF_ADDR_SIZE            (2)
    )
    u_buf
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc_select                    (i_pc_select),
        .i_ack                          (ack_sync),
        .i_decode_ready                 (i_fetch_start),
        .i_data                         (i_instruction),
        .i_fetch_pc1                    (fetch_pc[1]),
        .i_fetch_pc_next                (fetch_pc_next),
        .o_free_dword_or_more           (free_dword_or_more),
        .o_pc_incr                      (fetch_pc_incr),
        .o_pc                           (o_bus.pc),
        .o_instruction                  (o_bus.instruction),
        .o_ready                        (o_bus.ready)
    );

    assign  move_pc = (i_ack & free_dword_or_more) | i_pc_select
`ifdef EXTENSION_Zicsr
            | ebreak
`endif
            ;
    assign  o_cyc = i_reset_n & free_dword_or_more;
    assign  fetch_addr = fetch_pc;
`else // PREFETCH_BUFFER
  `ifdef EXTENSION_C
    rv_fetch_aligner
    u_aligner
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_pc                           (fetch_pc),
        .i_start                        (i_fetch_start),
        .i_pc_select                    (i_pc_select),
    `ifdef EXTENSION_Zicsr
        .i_ebreak                       (ebreak),
    `endif
        .i_instruction                  (i_instruction),
        .i_ack                          (i_ack),
        .o_cyc                          (o_cyc),
        .o_move                         (move_pc),
        .o_addr                         (fetch_addr),
        .o_pc_incr                      (fetch_pc_incr),
        .o_ready                        (o_bus.ready),
        .o_pc                           (o_bus.pc),
        .o_instruction                  (o_bus.instruction)
    );
  `else // EXTENSION_C

    assign  fetch_addr = fetch_pc;
    assign  fetch_pc_incr = 32'd4;
    assign  move_pc = i_ack | i_pc_select | (!i_reset_n)
`ifdef EXTENSION_Zicsr
                | ebreak
`endif
                ;
    assign  o_cyc = i_fetch_start;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            o_bus.ready <= '0;
            o_bus.pc <= '0;
            o_bus.instruction <= '0;
        end
        else
        begin
            o_bus.ready <= i_ack;
            o_bus.pc <= fetch_pc;
            if (i_ack & i_reset_n)
                o_bus.instruction <= i_instruction;
            else
                o_bus.instruction <= '0;
        end
    end

  `endif // EXTENSION_C
`endif // PREFETCH_BUFFER

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
`endif // BRANCH_PREDICTION_SIMPLE

    assign  o_addr = fetch_addr;

initial
begin
    fetch_pc = '0;
    o_bus = '0;
end

endmodule
