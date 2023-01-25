`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch
#(
    parameter   RESET_ADDR              = 32'h0000_0000,
    parameter   BRANCH_PREDICTION       = 1,
    parameter   INSTR_BUF_ADDR_SIZE     = 2,
    parameter   EXTENSION_C             = 1,
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
    input   wire                        i_ra_invalidate,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_reg_wdata,
    output  wire[31:0]                  o_addr,
    output  wire                        o_cyc,
    output  wire[31:0]                  o_instruction,
    output  wire[31:0]                  o_pc,
    output  wire                        o_branch_pred,
    output  wire                        o_ready
);

    logic[31:0] pc;
    logic[31:0] pc_prev;
    logic[31:0] addr;
    logic[31:0] pc_next;
    logic[31:0] pc_incr;
    logic       move_pc;
    logic       bp_need;
    logic       bp_prev;
    logic[31:0] bp_addr;

    logic       pc_next_trap_sel;

    assign  pc_next_trap_sel = i_ebreak & EXTENSION_Zicsr;
    assign  pc_next = (!i_reset_n) ? RESET_ADDR :
                pc_next_trap_sel ? i_pc_trap :
                i_pc_select ? i_pc_target :
                bp_need ? bp_addr :
                (pc + pc_incr);

    always_ff @(posedge i_clk)
    begin
        if (move_pc)
            pc <= pc_next;
        pc_prev <= pc;
    end

    logic   free_dword_or_more;
    logic   ack;

    always_ff @(posedge i_clk)
    begin
        ack <= i_ack & (!i_pc_select);
    end

    logic   pc_need_change;
    assign  pc_need_change = i_pc_select | (!i_reset_n) | (i_ebreak & EXTENSION_Zicsr);

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
        .i_pc_select                    (pc_need_change),
        .i_ack                          (ack),
        .i_data                         (i_instruction),
        .i_fetch_pc1                    (pc[1]),
        .i_fetch_pc_prev                (pc_prev),
        .i_branch_pred                  (bp_need),
        .i_branch_pred_prev             (bp_prev),
        .o_free_dword_or_more           (free_dword_or_more),
        .o_pc_incr                      (pc_incr),
        .o_pc                           (o_pc),
        .o_branch_pred                  (o_branch_pred),
        .o_instruction                  (o_instruction),
        .o_ready                        (o_ready)
    );

    assign  move_pc =  (i_ack & free_dword_or_more) | pc_need_change | bp_need;
    assign  o_cyc = i_reset_n & free_dword_or_more & (!pc_need_change);
    assign  addr = pc;

    generate
        if (BRANCH_PREDICTION)
        begin : pred
            logic       ra_valid;
            logic[6:0]  bp_op;
            //logic[4:0]  bp_rd;
            logic[4:0]  bp_rs;
            logic       bp_b_sign;
            logic[31:0] bp_b_offs;
            logic[31:0] bp_jalr_offs;
            logic[31:0] bp_jal_offs;
            logic[31:0] bp_b_addr;
            logic[31:0] bp_jalr_addr;
            logic[31:0] bp_jal_addr;
            logic       bp_is_b;
            logic       bp_is_jalr;
            logic       bp_is_jal;
            logic[31:0] bp_ra;
            logic[31:0] instr_mux;
            logic[31:0] instr_full;
            logic       reset;
            assign      instr_mux = ack ? i_instruction : '0;
            if (EXTENSION_C)
            begin
                always_comb
                begin
                    case (instr_mux[1:0])
                    RV32_C_Q1_DET:
                    begin
                        case (instr_mux[15:13])
                        3'b001, 3'b101:
                        begin
                            // 001: c.jal -> jal x1, imm
                            // 101: c.j   -> jal x0, imm
                            instr_full = { instr_mux[12], instr_mux[8], instr_mux[10:9], instr_mux[6],
                                        instr_mux[7], instr_mux[2], instr_mux[11], instr_mux[5:3],
                                        {9{instr_mux[12]}}, 4'b0, ~instr_mux[15],
                                        RV32_OPC_JAL, 2'b11 };
                        end
                        3'b110, 3'b111:
                        begin
                            // 0: c.beqz -> beq rs1', x0, imm
                            // 1: c.bnez -> bne rs1', x0, imm
                            instr_full = { {4{instr_mux[12]}}, instr_mux[6:5], instr_mux[2], 5'b0, 2'b01,
                                            instr_mux[9:7], 2'b00, instr_mux[13], instr_mux[11:10],
                                            instr_mux[4:3], instr_mux[12], RV32_OPC_B, 2'b11};
                        end
                        default: instr_full = instr_mux;
                        endcase
                    end
                    RV32_C_Q2_DET:
                    begin
                        case (instr_mux[15:14])
                        2'b10:
                        begin
                            if (instr_mux[12] == 1'b0)
                            begin
                                if (!(|instr_mux[6:2]))
                                begin
                                    // c.jr -> jalr x0, rd/rs1, 0
                                    instr_full = { 12'b0, instr_mux[11:7], 3'b0, 5'b0, RV32_OPC_JALR, 2'b11 };
                                end
                                else instr_full = instr_mux;
                            end
                            else
                            begin
                                if (!(|instr_mux[6:2]))
                                begin
                                    if (|instr_mux[11:7])
                                    begin
                                        // c.jalr -> jalr x1, rs1, 0
                                        instr_full = { 12'b0, instr_mux[11:7], 3'b000, 5'b00001, RV32_OPC_JALR, 2'b11 };
                                    end
                                    else instr_full = instr_mux;
                                end
                                else instr_full = instr_mux;
                            end
                        end
                        default: instr_full = instr_mux;
                        endcase
                    end
                    default: instr_full = instr_mux;
                    endcase
                end
            end
            else
            begin
                assign instr_full = instr_mux;
            end

            always_ff @(posedge i_clk)
            begin
                if (i_ra_invalidate | (!i_reset_n))
                    ra_valid <= '0;
                else if (i_reg_write & (i_rd == 5'h1))
                begin
                    bp_ra <= i_reg_wdata;
                    ra_valid <= '1;
                end
                reset <= i_reset_n;
                bp_prev <= bp_need;
            end

            assign  bp_op        = instr_full[6:0];
            //assign  bp_rd        = instr_full[11:7];
            assign  bp_rs        = instr_full[19:15];
            assign  bp_b_sign    = instr_full[31];
            assign  bp_b_offs    = { {20{instr_full[31]}}, instr_full[7], instr_full[30:25], instr_full[11:8], 1'b0 };
            assign  bp_jalr_offs = { {21{instr_full[31]}}, instr_full[30:20] };
            assign  bp_jal_offs  = { {12{instr_full[31]}}, instr_full[19:12], instr_full[20], instr_full[30:21], 1'b0 };
            assign  bp_b_addr    = pc_prev + bp_b_offs;
            assign  bp_jalr_addr = bp_ra + bp_jalr_offs;
            assign  bp_jal_addr  = pc_prev + bp_jal_offs;
            assign  bp_is_b      = (bp_op == { RV32_OPC_B,    RV32_OPC_DET }) && bp_b_sign;
            assign  bp_is_jalr   = (bp_op == { RV32_OPC_JALR, RV32_OPC_DET }) && (bp_rs == 1) & ra_valid & (!i_ra_invalidate); /*ra, ret*/
            assign  bp_is_jal    = (bp_op == { RV32_OPC_JAL,  RV32_OPC_DET });

            assign  bp_need = (bp_is_jalr | bp_is_jal | bp_is_b) & reset & (!bp_prev);
            always_comb
            begin
                case (1'b1)
                bp_is_b:    bp_addr = bp_b_addr;
                bp_is_jalr: bp_addr = bp_jalr_addr;
                bp_is_jal:  bp_addr = bp_jal_addr;
                endcase
            end
        end
        else
        begin
            assign  bp_need = '0;
            assign  bp_prev = '0;
            assign  bp_addr = '0;
            /* verilator lint_off UNUSEDSIGNAL */
            logic  dummy;
            assign dummy = i_ra_invalidate | (|i_reg_wdata) | (|i_rd) | i_reg_write;
            /* verilator lint_on UNUSEDSIGNAL */
        end
    endgenerate

    assign  o_addr = addr;

initial
begin
    pc = '0;
end

endmodule
