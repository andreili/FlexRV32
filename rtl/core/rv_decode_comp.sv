`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_decode_comp
(
    input   wire[31:0]                  i_instruction,
    output  wire[31:0]                  o_instruction,
    output  wire                        o_illegal_instruction
);

    logic[31:0] instruction;
    logic   illegal_instruction;
    logic   inst_c_addi4spn, inst_c_lw, inst_c_sw;
    logic   inst_c_addi, inst_c_jal, inst_c_j, inst_c_li;
    logic   inst_c_lui, inst_c_addi16sp, inst_c_srli, inst_c_srai;
    logic   inst_c_andi, inst_c_sub, inst_c_xor, inst_c_or, inst_c_and;
    logic   inst_c_beqz, inst_c_bnez;
    logic   inst_c_slli, inst_c_lwsp;
    logic   inst_c_mv, inst_c_jr, inst_c_add, inst_c_ebreak, inst_c_jalr;
    logic   inst_c_swsp;

    always_comb
    begin
        inst_c_addi4spn = '0;
        inst_c_lw = '0;
        inst_c_sw = '0;
        inst_c_addi = '0;
        inst_c_addi = '0;
        inst_c_jal = '0;
        inst_c_j = '0;
        inst_c_li = '0;
        inst_c_lui = '0;
        inst_c_addi16sp = '0;
        inst_c_srli = '0;
        inst_c_srai = '0;
        inst_c_andi = '0;
        inst_c_sub = '0;
        inst_c_xor = '0;
        inst_c_or = '0;
        inst_c_and = '0;
        inst_c_beqz = '0;
        inst_c_bnez = '0;
        inst_c_slli = '0;
        inst_c_lwsp = '0;
        inst_c_mv = '0;
        inst_c_swsp = '0;
        inst_c_jr = '0;
        inst_c_add = '0;
        inst_c_ebreak = '0;
        inst_c_jalr = '0;
        illegal_instruction = '0;
        case (i_instruction[1:0])
        RV32_C_Q0_DET:
        begin
            case (i_instruction[15:14])
            2'b00:
            begin
                // c.addi4spn -> addi rd', x2, imm
                inst_c_addi4spn = |i_instruction[12:5];
                instruction = (|i_instruction[12:5]) ? { 2'b00, i_instruction[10:7], i_instruction[12:11],
                                i_instruction[5], i_instruction[6], 2'b00, 5'h2, 3'b000, 2'b01,
                                i_instruction[4:2], RV32_OPC_ARI, 2'b11 } : '0;
            end
            2'b01:
            begin
                // c.lw -> lw rd', imm(rs1')
                inst_c_lw = '1;
                instruction = { 5'b0, i_instruction[5], i_instruction[12:10], i_instruction[6],
                                2'b00, 2'b01, i_instruction[9:7], 3'b010, 2'b01, i_instruction[4:2],
                                RV32_OPC_LD, 2'b11 };
            end
            2'b11:
            begin
                // c.sw -> sw rs2', imm(rs1')
                inst_c_sw = '1;
                instruction = { 5'b0, i_instruction[5], i_instruction[12], 2'b01, i_instruction[4:2], 2'b01,
                                i_instruction[9:7], 3'b010, i_instruction[11:10], i_instruction[6], 2'b00,
                                RV32_OPC_STR, 2'b11 };
            end
            2'b10:
            begin
                illegal_instruction = '1;
                instruction = i_instruction;
            end
            endcase
        end
        RV32_C_Q1_DET:
        begin
            case (i_instruction[15:13])
            3'b000:
            begin
                // c.addi -> addi rd, rd, nzimm
                // c.nop
                inst_c_addi = '1;
                instruction = { {6{i_instruction[12]}}, i_instruction[12], i_instruction[6:2],
                                i_instruction[11:7], 3'b0, i_instruction[11:7],
                                RV32_OPC_ARI, 2'b11 };
            end
            3'b001, 3'b101:
            begin
                // 001: c.jal -> jal x1, imm
                // 101: c.j   -> jal x0, imm
                inst_c_jal = !i_instruction[15];
                inst_c_j   =  i_instruction[15];
                instruction = { i_instruction[12], i_instruction[8], i_instruction[10:9], i_instruction[6],
                                i_instruction[7], i_instruction[2], i_instruction[11], i_instruction[5:3],
                                {9{i_instruction[12]}}, 4'b0, ~i_instruction[15],
                                RV32_OPC_JAL, 2'b11 };
            end
            3'b010:
            begin
                // c.li -> addi rd, x0, nzimm
                inst_c_li = '1;
                instruction = { {6{i_instruction[12]}}, i_instruction[12], i_instruction[6:2], 5'b0,
                                3'b0, i_instruction[11:7],
                                RV32_OPC_ARI, 2'b11 };
            end
            3'b011:
            begin
                // c.lui -> lui rd, imm
                instruction = { {15{i_instruction[12]}}, i_instruction[6:2], i_instruction[11:7],
                                RV32_OPC_LUI, 2'b11 };

                if (i_instruction[11:7] == 5'h02)
                begin
                    // c.addi16sp -> addi x2, x2, nzimm
                    inst_c_addi16sp = '0;
                    instruction = { {3{i_instruction[12]}}, i_instruction[4:3], i_instruction[5], i_instruction[2],
                                    i_instruction[6], 4'b0, 5'h02, 3'b000, 5'h02,
                                    RV32_OPC_ARI, 2'b11 };
                end
                else
                    inst_c_lui = '1;
            end
            3'b100:
            begin
                case (i_instruction[11:10])
                2'b00, 2'b01:
                begin
                    // 00: c.srli -> srli rd, rd, shamt
                    // 01: c.srai -> srai rd, rd, shamt
                    inst_c_srli = !i_instruction[10];
                    inst_c_srai =  i_instruction[10];
                    instruction = { 1'b0, i_instruction[10], 5'b0, i_instruction[6:2], 2'b01,
                                    i_instruction[9:7], 3'b101, 2'b01, i_instruction[9:7],
                                    RV32_OPC_ARI, 2'b11 };
                end
                2'b10:
                begin
                    // c.andi -> andi rd, rd, imm
                    inst_c_andi = '1;
                    instruction = { {6{i_instruction[12]}}, i_instruction[12], i_instruction[6:2],
                                    2'b01, i_instruction[9:7], 3'b111, 2'b01, i_instruction[9:7],
                                    RV32_OPC_ARI, 2'b11 };
                end
                2'b11:
                begin
                    case (i_instruction[6:5])
                    2'b00:
                    begin
                        // c.sub -> sub rd', rd', rs2'
                        inst_c_sub = '1;
                        instruction = { 2'b01, 5'b0, 2'b01, i_instruction[4:2], 2'b01,
                        i_instruction[9:7], 3'b000, 2'b01, i_instruction[9:7],
                                        RV32_OPC_ARR, 2'b11 };
                    end
                    2'b01:
                    begin
                        // c.xor -> xor rd', rd', rs2'
                        inst_c_xor = '1;
                        instruction = { 7'b0, 2'b01, i_instruction[4:2], 2'b01, i_instruction[9:7],
                                        3'b100, 2'b01, i_instruction[9:7],
                                        RV32_OPC_ARR, 2'b11 };
                    end
                    2'b10:
                    begin
                        // c.or  -> or  rd', rd', rs2'
                        inst_c_or = '1;
                        instruction = { 7'b0, 2'b01, i_instruction[4:2], 2'b01, i_instruction[9:7],
                                        3'b110, 2'b01, i_instruction[9:7],
                                        RV32_OPC_ARR, 2'b11 };
                    end
                    2'b11:
                    begin
                        // c.and -> and rd', rd', rs2'
                        inst_c_and = '1;
                        instruction = { 7'b0, 2'b01, i_instruction[4:2], 2'b01, i_instruction[9:7],
                                        3'b111, 2'b01, i_instruction[9:7],
                                        RV32_OPC_ARR, 2'b11 };
                    end
                    endcase
                end
                endcase
            end
            3'b110, 3'b111:
            begin
                // 0: c.beqz -> beq rs1', x0, imm
                // 1: c.bnez -> bne rs1', x0, imm
                inst_c_beqz = !i_instruction[13];
                inst_c_bnez =  i_instruction[13];
                instruction = { {4{i_instruction[12]}}, i_instruction[6:5], i_instruction[2], 5'b0, 2'b01,
                                i_instruction[9:7], 2'b00, i_instruction[13], i_instruction[11:10],
                                i_instruction[4:3], i_instruction[12], RV32_OPC_B, 2'b11};
            end
            endcase
        end
        RV32_C_Q2_DET:
        begin
            case (i_instruction[15:14])
            2'b00:
            begin
                // c.slli -> slli rd, rd, shamt
                inst_c_slli = '1;
                instruction = { 7'b0, i_instruction[6:2], i_instruction[11:7], 3'b001, i_instruction[11:7],
                                RV32_OPC_ARI, 2'b11 };
            end
            2'b01:
            begin
                // c.lwsp -> lw rd, imm(x2 )
                inst_c_lwsp = '1;
                instruction = { 4'b0, i_instruction[3:2], i_instruction[12], i_instruction[6:4], 2'b00, 5'h02,
                                3'b010, i_instruction[11:7], RV32_OPC_LD, 2'b11};
            end
            2'b10:
            begin
                if (i_instruction[12] == 1'b0)
                begin
                    if (|i_instruction[6:2])
                    begin
                        // c.mv -> add rd/rs1, x0, rs2
                        inst_c_mv = '1;
                        instruction = { 7'b0, i_instruction[6:2], 5'b0, 3'b0, i_instruction[11:7],
                                        RV32_OPC_ARR, 2'b11 };
                    end
                    else
                    begin
                        // c.jr -> jalr x0, rd/rs1, 0
                        inst_c_jr = '1;
                        instruction = { 12'b0, i_instruction[11:7], 3'b0, 5'b0, RV32_OPC_JALR, 2'b11 };
                    end
                end
                else
                begin
                    if (|i_instruction[6:2])
                    begin
                        // c.add -> add rd, rd, rs2
                        inst_c_add = '1;
                        instruction = { 7'b0, i_instruction[6:2], i_instruction[11:7], 3'b0,
                                        i_instruction[11:7], RV32_OPC_ARR, 2'b11 };
                    end
                    else
                    begin
                        if (!(|i_instruction[11:7]))
                        begin
                            // c.ebreak -> ebreak
                            inst_c_ebreak = '1;
                            instruction = { 32'h00_10_00_73 };
                        end
                        else
                        begin
                            // c.jalr -> jalr x1, rs1, 0
                            inst_c_jalr = '1;
                            instruction = { 12'b0, i_instruction[11:7], 3'b000, 5'b00001, RV32_OPC_JALR, 2'b11 };
                        end
                    end
                end
            end
            2'b11:
            begin
                // c.swsp -> sw rs2, imm(x2)
                inst_c_swsp = '1;
                instruction = { 4'b0, i_instruction[8:7], i_instruction[12], i_instruction[6:2], 5'h02,
                                3'b010, i_instruction[11:9], 2'b00, RV32_OPC_STR, 2'b11 };
            end
            endcase
        end
        2'b11:
        begin
            // not compressed
            illegal_instruction = '1;
            instruction = i_instruction;
        end
        endcase
    end

    assign  o_instruction = instruction;
    assign  o_illegal_instruction = illegal_instruction;

`ifdef TO_SIM
/* verilator lint_off UNUSEDSIGNAL */
    logic [127:0] dbg_ascii_cinstr;
    always_comb
    begin
        dbg_ascii_cinstr = '0;

        if (inst_c_addi4spn) dbg_ascii_cinstr = "c.addi4spn";
        if (inst_c_lw)       dbg_ascii_cinstr = "c.lw";
        if (inst_c_sw)       dbg_ascii_cinstr = "c.sw";
        if (inst_c_addi)     dbg_ascii_cinstr = "c.addi";
        if (inst_c_jal)      dbg_ascii_cinstr = "c.jal";
        if (inst_c_j)        dbg_ascii_cinstr = "c.j";
        if (inst_c_li)       dbg_ascii_cinstr = "c.li";
        if (inst_c_lui)      dbg_ascii_cinstr = "c.lui";
        if (inst_c_addi16sp) dbg_ascii_cinstr = "c.addi16sp";
        if (inst_c_srli)     dbg_ascii_cinstr = "c.srli";
        if (inst_c_srai)     dbg_ascii_cinstr = "c.srai";
        if (inst_c_andi)     dbg_ascii_cinstr = "c.andi";
        if (inst_c_sub)      dbg_ascii_cinstr = "c.sub";
        if (inst_c_xor)      dbg_ascii_cinstr = "c.xor";
        if (inst_c_or)       dbg_ascii_cinstr = "c.or";
        if (inst_c_and)      dbg_ascii_cinstr = "c.and";
        if (inst_c_beqz)     dbg_ascii_cinstr = "c.beqz";
        if (inst_c_bnez)     dbg_ascii_cinstr = "c.bnez";
        if (inst_c_slli)     dbg_ascii_cinstr = "c.slli";
        if (inst_c_lwsp)     dbg_ascii_cinstr = "c.lwsp";
        if (inst_c_swsp)     dbg_ascii_cinstr = "c.swsp";
        if (inst_c_mv)       dbg_ascii_cinstr = "c.mv";
        if (inst_c_jr)       dbg_ascii_cinstr = "c.jr";
        if (inst_c_ebreak)   dbg_ascii_cinstr = "c.ebreak";
        if (inst_c_jalr)     dbg_ascii_cinstr = "c.jalr";
        if (inst_c_add)      dbg_ascii_cinstr = "c.add";

        if (!(|i_instruction[15:0])) dbg_ascii_cinstr = '0;
    end
/* verilator lint_on UNUSEDSIGNAL */
`endif

endmodule
