`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_fetch_branch_pred
#(
    parameter   EXTENSION_C             = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ack,
    input   wire                        i_ra_invalidate,
    input   wire                        i_reg_write,
    input   wire[4:0]                   i_rd,
    input   wire[31:0]                  i_reg_wdata,
    input   wire[31:0]                  i_pc_prev,
    output  wire                        o_bp_need,
    output  wire                        o_bp_need_prev,
    output  wire[31:0]                  o_bp_addr
);
    logic       ra_valid;
    logic       bp_need;
    logic       bp_prev;
    logic[31:0] bp_ra;
    logic[31:0] instr_mux;
    logic[31:0] instr_full;
    logic       reset;

    assign      instr_mux = i_ack ? i_instruction : '0;
    generate
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
    endgenerate

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

    logic[6:0]  bp_op;
    logic[4:0]  bp_rs;
    logic       bp_b_sign;
    logic       is_branch;
    logic       bp_is_b;
    logic       bp_is_jalr;
    logic       bp_is_jal;

    assign  bp_op        = instr_full[6:0];
    assign  bp_rs        = instr_full[19:15];
    assign  bp_b_sign    = instr_full[31];
    assign  is_branch    = ({ bp_op[6:4], bp_op[1:0] } == 5'b11011);
    assign  bp_is_b      = (bp_op[3:2] == 2'b00) && bp_b_sign;
    assign  bp_is_jalr   = (bp_op[3:2] == 2'b01) && (bp_rs == 5'd1) & ra_valid & (!i_ra_invalidate); /*ra, ret*/
    //assign  bp_is_res    = (bp_op[3:2] == 2'b10);
    assign  bp_is_jal    = (bp_op[3:2] == 2'b11);

    logic[31:0] base, offset;
    always_comb
    begin
        case (1'b1)
        bp_is_b:    base = i_pc_prev;
        bp_is_jalr: base = bp_ra;
        bp_is_jal:  base = i_pc_prev;
        default:    base = '0;
        endcase
    end
    always_comb
    begin
        case (1'b1)
        bp_is_b:    offset[19:0] = { {8{instr_full[31]}}, instr_full[7], instr_full[30:25], instr_full[11:8], 1'b0 };
        bp_is_jalr: offset[19:0] = { {9{instr_full[31]}}, instr_full[30:20] };
        bp_is_jal:  offset[19:0] = { instr_full[19:12], instr_full[20], instr_full[30:21], 1'b0 };
        default:    offset[19:0] = '0;
        endcase
    end
    assign  offset[31:20] = { 12{instr_full[31]} };

    logic[31:0] bp_addr;
    assign  bp_need = (bp_is_jalr | bp_is_jal | bp_is_b) & is_branch & reset & (!bp_prev);
    assign  bp_addr = base + offset;

    assign  o_bp_need = bp_need;
    assign  o_bp_need_prev = bp_prev;
    assign  o_bp_addr = bp_addr;

endmodule
