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

`define INSTR_BUF_ADDR_SIZE 3
`define INSTR_BUF_SIZE (2 ** `INSTR_BUF_ADDR_SIZE)
`define INSTR_BUF_SIZE_BITS (16)

    logic       bus_cyc;
    logic[31:0] fetch_pc;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_pc_incr;
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
        begin
            fetch_pc <= RESET_ADDR;
            bus_cyc <= '1;
        end
        else if (i_pc_inc && (!instr_buf_free_1dword))
        begin
            fetch_pc <= fetch_pc_next;
            bus_cyc <= '1;
        end
        else if (bus_cyc & i_ack)
        begin
            bus_cyc <= '0;
        end
    end

    logic[`INSTR_BUF_SIZE_BITS-1:0] instr_buf[`INSTR_BUF_SIZE];
    logic[`INSTR_BUF_ADDR_SIZE:0] instr_buf_free_cnt;
    logic   instr_buf_nearfull;
    logic   instr_buf_full;
    logic   instr_buf_free_1dword;
    logic   instr_buf_empty;
    logic[31:0] instr_buf_pc;

    assign  instr_buf_free_1dword  = (instr_buf_free_cnt == 2);
    assign  instr_buf_nearfull     = (instr_buf_free_cnt == 1);
    assign  instr_buf_full         = !(|instr_buf_free_cnt);
    assign  instr_buf_empty        = instr_buf_free_cnt[`INSTR_BUF_ADDR_SIZE];

    logic[1:0]  instr_type;
    logic       instr_comp;

    assign  instr_type = i_instruction[1:0];
    assign  instr_comp = !(&instr_type);

    assign  fetch_pc_incr = (instr_buf_empty & instr_comp & fetch_pc[1]) ? 2 : 4;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n | i_pc_select)
        begin
            instr_buf_free_cnt <= `INSTR_BUF_SIZE;
            instr_buf[0] <= '0;
            instr_buf[1] <= '0;
            instr_buf_pc <= fetch_pc_next;
        end
        else if (i_ack & (!instr_buf_full) && (!instr_buf_nearfull) & (!fetch_pc[1]))
        begin
            { instr_buf[`INSTR_BUF_SIZE-instr_buf_free_cnt+1], instr_buf[`INSTR_BUF_SIZE-instr_buf_free_cnt] } <= i_instruction;
            instr_buf_free_cnt <= instr_buf_free_cnt - 2;
        end
        else if (i_ack & (!instr_buf_full) & instr_comp)
        begin
            instr_buf[`INSTR_BUF_SIZE-instr_buf_free_cnt] <= fetch_pc[1] ? i_instruction[31:16] : i_instruction[15:0];
            instr_buf_free_cnt <= instr_buf_free_cnt - 1;
        end
        else if (instr_buf_move & instr_buf_comp & (!instr_buf_empty))
        begin
            instr_buf_free_cnt <= instr_buf_free_cnt + 1;
            instr_buf_pc <= instr_buf_pc + 2;
            instr_buf[0:`INSTR_BUF_SIZE-2] <= instr_buf[1:`INSTR_BUF_SIZE-1];
        end
        else if (instr_buf_move & (!instr_buf_comp) & (!instr_buf_empty))
        begin
            instr_buf_free_cnt <= instr_buf_free_cnt + 2;
            instr_buf_pc <= instr_buf_pc + 4;
            instr_buf[0:`INSTR_BUF_SIZE-3] <= instr_buf[2:`INSTR_BUF_SIZE-1];
        end
    end

    logic       instr_buf_move;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            instr_buf_move <= '0;
        else
            instr_buf_move <= i_ack;
    end

    logic[1:0]  instr_buf_type;
    logic       instr_buf_comp;
    assign  instr_buf_type = instr_buf[0][1:0];
    assign  instr_buf_comp = !(&instr_buf_type);

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
    assign  o_bus.pc = instr_buf_pc;
    assign  o_bus.instruction = instr_buf_move ? {instr_buf[1], instr_buf[0] } : '0;

endmodule
