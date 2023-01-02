`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_decode
(
    input   wire                        i_clk,
    input   fetch_bus_t                 i_bus,
    output  decode_bus_t                o_bus
);

    logic[6:0]  op;
    logic[2:0]  funct3;
    logic[6:0]  funct7;
    logic[11:0] funct12;
    logic[31:0] pc;
`ifdef EXTENSION_C
    logic[2:0]  c_funct3;
    logic[3:0]  c_funct4;
    logic[5:0]  c_funct6;
    logic[1:0]  c_funct2;
    logic[1:0]  c_funct;
    logic[4:0]  c_rd;
    logic[2:0]  c_rs1s;
    logic[4:0]  c_rs2;
    logic[2:0]  c_rs2s;
    logic[4:0]  c_rd_mux;
    logic[4:0]  c_rs1_mux;
    logic[4:0]  c_rs2_mux;
`endif

    always_ff @(posedge i_clk)
    begin
        pc <= i_bus.pc;
    end

    logic   inst_full, inst_none;

`ifdef EXTENSION_C
    logic   inst_c_q0, inst_c_q1, inst_c_q2;
    logic   inst_c_addi4spn, inst_c_lw, inst_c_sw;
    logic   inst_c_addi, inst_c_jal, inst_c_li, inst_c_addi16sp;
    logic   inst_c_lui, inst_c_srli, inst_c_srai, inst_c_andi;
    logic   inst_c_sub, inst_c_xor, inst_c_or, inst_c_and;
    logic   inst_c_j, inst_c_beqz, inst_c_bnez;
    logic   inst_c_slli, inst_c_lwsp;
    logic   inst_c_jr, inst_c_mv, inst_c_jalr, inst_c_add;
    logic   inst_c_swsp;
`endif

    logic   inst_lb, inst_lh, inst_lw, inst_lbu, inst_lhu;
    logic   inst_addi, inst_slli, inst_slti, inst_sltiu;
    logic   inst_xori, inst_srli, inst_srai, inst_ori, inst_andi;
    logic   inst_auipc;
    logic   inst_sb, inst_sh, inst_sw;
    logic   inst_add, inst_sub, inst_sll, inst_slt, inst_sltu;
    logic   inst_xor, inst_srl, inst_sra, inst_or, inst_and;
    logic   inst_lui;
    logic   inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;
    logic   inst_jalr;
    logic   inst_jal;
    logic   inst_ecall, inst_ebreak;
    logic   inst_fence, inst_fence_i;

    assign  op        = i_bus.instruction[ 6: 0];
`ifdef EXTENSION_C
    assign  o_bus.rd  = inst_full ? i_bus.instruction[11: 7] : c_rd_mux;
    assign  o_bus.rs1 = inst_lui ? '0 : (inst_full ? i_bus.instruction[19:15] : c_rs1_mux);
    assign  o_bus.rs2 = inst_full ? i_bus.instruction[24:20] : c_rs2_mux;
`else
    assign  o_bus.rd  = i_bus.instruction[11: 7];
    assign  o_bus.rs1 = inst_lui ? '0 : i_bus.instruction[19:15];
    assign  o_bus.rs2 = i_bus.instruction[24:20];
`endif
    assign  funct3    = i_bus.instruction[14:12];
    assign  funct7    = i_bus.instruction[31:25];
    assign  funct12   = i_bus.instruction[31:20];

`ifdef EXTENSION_C
    assign  c_funct3  = i_bus.instruction[15:13];
    assign  c_funct4  = i_bus.instruction[15:12];
    assign  c_funct6  = i_bus.instruction[15:10];
    assign  c_funct   = i_bus.instruction[11:10];
    assign  c_funct2  = i_bus.instruction[ 6: 5];
    assign  c_rd      = i_bus.instruction[11: 7];
    assign  c_rs1s    = i_bus.instruction[ 9: 7];
    assign  c_rs2     = i_bus.instruction[ 6: 2];
    assign  c_rs2s    = i_bus.instruction[ 4: 2];

    assign  c_rd_mux  = (|{inst_c_addi4spn,inst_c_lw}) ? { 2'b01, c_rs2s } :
                        (|{inst_c_addi,inst_c_li,inst_c_addi16sp,inst_c_lui,
                           inst_c_slli,inst_c_lwsp,inst_c_mv,inst_c_add}) ? c_rd :
                        (|{inst_c_jal,inst_c_jalr}) ? 1 :
                        (|{inst_c_srli,inst_c_srai,inst_c_andi,
                           inst_c_sub,inst_c_xor,inst_c_or,inst_c_and}) ? { 2'b01, c_rs1s } :
                        '0;
    assign  c_rs1_mux = (|{inst_c_addi4spn}) ? 2 :
                        (|{inst_c_lw,inst_c_sw,inst_c_srli,inst_c_srai,
                           inst_c_andi,inst_c_sub,inst_c_xor,inst_c_or,
                           inst_c_and,inst_c_beqz,inst_c_bnez}) ? { 2'b01, c_rs1s } :
                        (|{inst_c_addi,inst_c_addi16sp,
                           inst_c_slli,inst_c_jr,inst_c_jalr,inst_c_add}) ? c_rd :
                        (|{inst_c_swsp,inst_c_lwsp}) ? 2 :
                        '0;
    assign  c_rs2_mux = (|{inst_c_sw,inst_c_sub,inst_c_xor,inst_c_or,
                           inst_c_and}) ? { 2'b01, c_rs2s } :
                           (|{inst_c_mv,inst_c_add,inst_c_swsp}) ? c_rs2 :
                        '0;
`endif

    assign o_bus.imm_i = { {21{i_bus.instruction[31]}}, i_bus.instruction[30:20] };
    assign o_bus.imm_s = { {21{i_bus.instruction[31]}}, i_bus.instruction[30:25], i_bus.instruction[11:7] };
    assign o_bus.imm_b = { {20{i_bus.instruction[31]}}, i_bus.instruction[7], i_bus.instruction[30:25], i_bus.instruction[11:8], 1'b0 };
    assign o_bus.imm_u = { i_bus.instruction[31:12], {12{1'b0}} };
    assign o_bus.imm_j = { {12{i_bus.instruction[31]}}, i_bus.instruction[19:12], i_bus.instruction[20], i_bus.instruction[30:21], 1'b0 };

`ifdef EXTENSION_C
    assign  inst_c_q0 = (op[1:0] == RV32_C_Q0_DET);
    assign  inst_c_q1 = (op[1:0] == RV32_C_Q1_DET);
    assign  inst_c_q2 = (op[1:0] == RV32_C_Q2_DET);
    assign  inst_full = (op[1:0] == RV32_OPC_DET);

    logic[31:0] imm_c_lx;
    logic[31:0] imm_c_sx;
    logic[31:0] imm_c_lw;
    logic[31:0] imm_c_j;
    logic[31:0] imm_c_b;
    logic[31:0] imm_c_li;
    logic[31:0] imm_c_lui;
    logic[31:0] imm_c_a16s;
    logic[31:0] imm_c_a4s;
    logic[31:0] imm_c_sh;

    assign  imm_c_lx = { 24'b0, i_bus.instruction[3:2], i_bus.instruction[12],
                        i_bus.instruction[6:4], 2'b0 }; // CI, c.lwsp
    assign  imm_c_sx = { 24'b0, i_bus.instruction[8:7], i_bus.instruction[12:9], 2'b0 }; // CSS, c.swsp
    assign  imm_c_lw = { 25'b0, i_bus.instruction[5], i_bus.instruction[12:10],
                        i_bus.instruction[6], 2'b0 }; // CL, c.LW/c.SW
    assign  imm_c_j  = { {21{i_bus.instruction[12]}}, i_bus.instruction[8],
                        i_bus.instruction[10:9], i_bus.instruction[6],
                        i_bus.instruction[7], i_bus.instruction[2],
                        i_bus.instruction[11], i_bus.instruction[5:3], 1'b0 }; // CJ, c.j/c.jal
    assign  imm_c_b = { {24{i_bus.instruction[12]}}, i_bus.instruction[6:5],
                        i_bus.instruction[2], i_bus.instruction[11:10],
                        i_bus.instruction[4:3], 1'b0 }; // CB, c.beqz/c.bnez
    assign  imm_c_li  = { {27{i_bus.instruction[12]}}, i_bus.instruction[6:2] }; // CI, c.li/c.addi/c.andi
    assign  imm_c_lui = { {15{i_bus.instruction[12]}}, i_bus.instruction[6:2], 12'b0 }; // CI, c.lui
    assign  imm_c_a16s = { {23{i_bus.instruction[12]}}, i_bus.instruction[4:3],
                        i_bus.instruction[5], i_bus.instruction[2],
                        i_bus.instruction[6], 4'b0 }; // CI, c.addi16sp
    assign  imm_c_a4s = { 22'b0, i_bus.instruction[10:7], i_bus.instruction[12:11],
                        i_bus.instruction[5], i_bus.instruction[6], 2'b0 }; // CI, c.addi14spn
    assign  imm_c_sh  = { 26'b0, i_bus.instruction[12], i_bus.instruction[6:2] }; // CI, c.slli/c.srli/c.srai

    assign  o_bus.imm_c = (inst_c_lwsp) ? imm_c_lx :
                    (inst_c_swsp) ? imm_c_sx :
                    (inst_c_lw | inst_c_sw) ? imm_c_lw :
                    (inst_c_j | inst_c_jal) ? imm_c_j :
                    (inst_c_beqz | inst_c_bnez) ? imm_c_b :
                    (inst_c_li | inst_c_addi | inst_c_andi) ? imm_c_li :
                    (inst_c_lui) ? imm_c_lui :
                    (inst_c_addi16sp) ? imm_c_a16s :
                    (inst_c_addi4spn) ? imm_c_a4s :
                    (inst_c_slli | inst_c_srli | inst_c_srai) ? imm_c_sh :
                    '0;
`endif

    assign  inst_none = !(|i_bus.instruction);

    assign  o_bus.inst_supported = 
            inst_none |
            inst_lb    | inst_lh   | inst_lw   | inst_lbu   | inst_lhu  |
            inst_addi  | inst_slli | inst_slti | inst_sltiu |
            inst_xori  | inst_srli | inst_srai | inst_ori   | inst_andi |
            inst_auipc |
            inst_sb    | inst_sh   | inst_sw   |
            inst_add   | inst_sub  | inst_sll  | inst_slt   | inst_sltu |
            inst_xor   | inst_srl  | inst_sra  | inst_or    | inst_and  |
            inst_lui   |
            inst_beq   | inst_bne  | inst_blt  | inst_bge   | inst_bltu | inst_bgeu |
            inst_jalr  |
            inst_jal   |
            inst_fence | inst_fence_i
        `ifdef EXTENSION_C
            |
            inst_c_addi4spn | inst_c_lw | inst_c_sw |
            inst_c_addi | inst_c_jal | inst_c_li | inst_c_addi16sp |
            inst_c_lui | inst_c_srli | inst_c_srai | inst_c_andi |
            inst_c_sub | inst_c_xor | inst_c_or | inst_c_and |
            inst_c_j | inst_c_beqz | inst_c_bnez |
            inst_c_slli | inst_c_lwsp |
            inst_c_jr | inst_c_mv | inst_c_jalr | inst_c_add |
            inst_c_swsp
        `endif
            ;

`ifdef EXTENSION_C
    assign  inst_c_addi4spn = (c_funct3 == 3'b000) & inst_c_q0;
    assign  inst_c_lw       = (c_funct3 == 3'b010) & inst_c_q0;
    assign  inst_c_sw       = (c_funct3 == 3'b110) & inst_c_q0;

    assign  inst_c_addi     = (c_funct3 == 3'b000) & inst_c_q1;
    assign  inst_c_jal      = (c_funct3 == 3'b001) & inst_c_q1;
    assign  inst_c_li       = (c_funct3 == 3'b010) & inst_c_q1;
    assign  inst_c_addi16sp = (c_funct3 == 3'b011) & inst_c_q1 & (c_rd == 2);
    assign  inst_c_lui      = (c_funct3 == 3'b011) & inst_c_q1 & (c_rd != 2);
    assign  inst_c_srli     = (c_funct3 == 3'b100) & inst_c_q1 & (c_funct == 2'b00);
    assign  inst_c_srai     = (c_funct3 == 3'b100) & inst_c_q1 & (c_funct == 2'b01);
    assign  inst_c_andi     = (c_funct3 == 3'b100) & inst_c_q1 & (c_funct == 2'b10);
    assign  inst_c_sub      = (c_funct6 == 6'b100011) & inst_c_q1 & (c_funct2 == 2'b00);
    assign  inst_c_xor      = (c_funct6 == 6'b100011) & inst_c_q1 & (c_funct2 == 2'b01);
    assign  inst_c_or       = (c_funct6 == 6'b100011) & inst_c_q1 & (c_funct2 == 2'b10);
    assign  inst_c_and      = (c_funct6 == 6'b100011) & inst_c_q1 & (c_funct2 == 2'b11);
    assign  inst_c_j        = (c_funct3 == 3'b101) & inst_c_q1;
    assign  inst_c_beqz     = (c_funct3 == 3'b110) & inst_c_q1;
    assign  inst_c_bnez     = (c_funct3 == 3'b111) & inst_c_q1;
    assign  inst_c_slli     = (c_funct3 == 3'b000) & inst_c_q2;
    assign  inst_c_lwsp     = (c_funct3 == 3'b010) & inst_c_q2;
    assign  inst_c_jr       = (c_funct4 == 4'b1000) & inst_c_q2 & (c_rd != 0) & (c_rs2 == 0);
    assign  inst_c_mv       = (c_funct4 == 4'b1000) & inst_c_q2 & (c_rs2 != 0);
    assign  inst_c_jalr     = (c_funct4 == 4'b1001) & inst_c_q2 & (c_rd != 0) & (c_rs2 == 0);
    assign  inst_c_add      = (c_funct4 == 4'b1001) & inst_c_q2 & (c_rs2 != 0);
    assign  inst_c_swsp     = (c_funct3 == 3'b110) & inst_c_q2;
`endif

    // memory read operations
    assign  inst_lb       = (op[6:2] == RV32_OPC_LD)   & inst_full & (funct3 == 3'b000);
    assign  inst_lh       = (op[6:2] == RV32_OPC_LD)   & inst_full & (funct3 == 3'b001);
    assign  inst_lw       = (op[6:2] == RV32_OPC_LD)   & inst_full & (funct3 == 3'b010);
    assign  inst_lbu      = (op[6:2] == RV32_OPC_LD)   & inst_full & (funct3 == 3'b100);
    assign  inst_lhu      = (op[6:2] == RV32_OPC_LD)   & inst_full & (funct3 == 3'b101);
    // arifmetical with immediate
    assign  inst_addi     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b000);
    assign  inst_slli     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b001);
    assign  inst_slti     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b010);
    assign  inst_sltiu    = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b011);
    assign  inst_xori     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b100);
    assign  inst_srli     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b101) & (funct7 == 7'b0000000);
    assign  inst_srai     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b101) & (funct7 == 7'b0100000);
    assign  inst_ori      = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b110);
    assign  inst_andi     = (op[6:2] == RV32_OPC_ARI) & inst_full & (funct3 == 3'b111);
    // add upper immediate to PC
    assign  inst_auipc    = (op[6:2] == RV32_OPC_AUI) & inst_full;
    // memory write operations
    assign  inst_sb       = (op[6:2] == RV32_OPC_STR) & inst_full & (funct3 == 3'b000);
    assign  inst_sh       = (op[6:2] == RV32_OPC_STR) & inst_full & (funct3 == 3'b001);
    assign  inst_sw       = (op[6:2] == RV32_OPC_STR) & inst_full & (funct3 == 3'b010);
    // arifmetical with register
    assign  inst_add      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b000) & (funct7 == 7'b0000000);
    assign  inst_sub      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b000) & (funct7 == 7'b0100000);
    assign  inst_sll      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b001) & (funct7 == 7'b0000000);
    assign  inst_slt      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b010) & (funct7 == 7'b0000000);
    assign  inst_sltu     = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b011) & (funct7 == 7'b0000000);
    assign  inst_xor      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b100) & (funct7 == 7'b0000000);
    assign  inst_srl      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b101) & (funct7 == 7'b0000000);
    assign  inst_sra      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b101) & (funct7 == 7'b0100000);
    assign  inst_or       = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b110) & (funct7 == 7'b0000000);
    assign  inst_and      = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct3 == 3'b111) & (funct7 == 7'b0000000);
    // load upper immediate
    assign  inst_lui      = (op[6:2] == RV32_OPC_LUI) & inst_full;
    // branches
    assign  inst_beq      = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b000);
    assign  inst_bne      = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b001);
    assign  inst_blt      = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b100);
    assign  inst_bge      = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b101);
    assign  inst_bltu     = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b110);
    assign  inst_bgeu     = (op[6:2] == RV32_OPC_B) & inst_full & (funct3 == 3'b111);
    // jumps
    assign  inst_jalr     = (op[6:2] == RV32_OPC_JALR) & inst_full & (funct3 == 3'b000);
    assign  inst_jal      = (op[6:2] == RV32_OPC_JAL)  & inst_full;
    // fence
    assign  inst_fence    = (op[6:2] == RV32_OPC_MEM) & inst_full & (funct3 == 3'b000);
    assign  inst_fence_i  = (op[6:2] == RV32_OPC_MEM) & inst_full & (funct3 == 3'b001);
    // system
    assign  inst_ecall    = (op[6:2] == RV32_OPC_SYS) & inst_full & (funct3 == 3'b000) & (funct12 == 12'b000000000000);
    assign  inst_ebreak   = (op[6:2] == RV32_OPC_SYS) & inst_full & (funct3 == 3'b000) & (funct12 == 12'b000000000001);

    logic   inst_load;
    logic   inst_store;
    logic   inst_imm;
    logic   inst_reg;
    logic   inst_branch;
    logic   inst_slts;
    logic   inst_ltu;
    assign  inst_load   = ((op[6:2] == RV32_OPC_LD)  & inst_full)
`ifdef EXTENSION_C
                            | inst_c_lw | inst_c_lwsp
`endif
                            ;
    assign  inst_store  = ((op[6:2] == RV32_OPC_STR) & inst_full);
    assign  inst_imm    = (op[6:2] == RV32_OPC_ARI) & inst_full;
    assign  inst_reg    = (op[6:2] == RV32_OPC_ARR) & inst_full;
    assign  inst_branch = ((op[6:2] == RV32_OPC_B)   & inst_full)
`ifdef EXTENSION_C
                            | inst_c_beqz | inst_c_bnez
`endif
                            ;
    assign  inst_slts   = ((op[6:2] == RV32_OPC_ARI) |
                                ( (op[6:2] == RV32_OPC_ARR) & (funct7 == 7'b0000000)))
                                & inst_full & (funct3[2:1] == 2'b01);
    assign  inst_ltu    = ((((op[6:2] == RV32_OPC_ARI) | ((op[6:2] == RV32_OPC_ARR) & (funct7 == 7'b0000000))) & (funct3 == 3'b011)) |
        ((op[6:2] == RV32_OPC_B) & (funct3[2:1] == 2'b11))) & inst_full;

    assign  o_bus.reg_write = inst_load | inst_imm | inst_auipc | inst_reg | inst_lui | inst_jalr | inst_jal
`ifdef EXTENSION_C
                                | ((inst_c_jal | inst_c_j | inst_c_jalr | inst_c_jr | inst_c_addi4spn | inst_c_lw
                                | inst_c_addi | inst_c_jal | inst_c_li | inst_c_lui | inst_c_addi16sp
                                | inst_c_srli | inst_c_srai | inst_c_andi | inst_c_sub | inst_c_xor
                                | inst_c_or | inst_c_and | inst_c_slli | inst_c_lw | inst_c_lwsp | inst_c_mv
                                | inst_c_jalr | inst_c_add | inst_c_swsp) & (!inst_none))
`endif
                            ;

    assign  o_bus.op1_src.pc = |{inst_auipc,inst_jal
`ifdef EXTENSION_C
                                ,inst_c_jal,inst_c_j
`endif
                                };
    assign  o_bus.op1_src.r  = !(|{inst_auipc,inst_jal
`ifdef EXTENSION_C
                                ,inst_c_jal,inst_c_j
`endif
                                    });

    assign  o_bus.op2_src.j = inst_jal;
    assign  o_bus.op2_src.u = |{inst_lui, inst_auipc};
    assign  o_bus.op2_src.i = (|{inst_jalr, inst_load, inst_imm})
`ifdef EXTENSION_C
                                & (!(|{inst_c_lwsp,inst_c_swsp}))
`endif
                                    ;
    assign  o_bus.op2_src.s = inst_store;
    assign  o_bus.op2_src.r = !(|{inst_jal,inst_lui, inst_auipc,inst_jalr, inst_load, inst_imm,inst_store})
`ifdef EXTENSION_C
                                    & (!imm_is_c);
    logic   imm_is_c;
    assign  imm_is_c = (!inst_full) & (!(inst_c_jr | inst_c_mv | inst_c_jalr | inst_c_add |
                                         inst_c_sub | inst_c_xor | inst_c_or | inst_c_and |
                                         inst_c_beqz | inst_c_bnez));
    assign  o_bus.inst_compressed = (!inst_full) & (!inst_none);
    assign  o_bus.op2_src.c = imm_is_c
`endif
                                    ;

    assign  o_bus.res_src.memory = inst_load;
    assign  o_bus.res_src.pc_p4  = |{inst_jalr,inst_jal
`ifdef EXTENSION_C
                                ,inst_c_jal,inst_c_j,inst_c_jalr,inst_c_jr
`endif
                                    };
    assign  o_bus.res_src.alu    = !(|{inst_load,inst_jalr,inst_jal
`ifdef EXTENSION_C
                                ,inst_c_jal,inst_c_j,inst_c_jalr,inst_c_jr
`endif
                                    });

    assign  o_bus.alu_ctrl.res_cmp = |{inst_branch,inst_slts
`ifdef EXTENSION_C
                                ,inst_c_beqz,inst_c_bnez
`endif
                                    };
    assign  o_bus.alu_ctrl.res_bits = |{inst_andi,inst_and,
                                        inst_ori,inst_or,
                                        inst_xori,inst_xor
`ifdef EXTENSION_C
                                        ,inst_c_andi,inst_c_and,
                                        inst_c_xor,inst_c_or
`endif
                                    };
    assign  o_bus.alu_ctrl.res_arith = |{inst_slli,inst_sll,
                                         inst_srli,inst_srl,inst_srai,inst_sra,
                                         inst_sub, inst_add
`ifdef EXTENSION_C
                                        ,inst_c_addi16sp,inst_c_addi4spn,
                                        inst_c_addi,inst_c_add,
                                        inst_c_li, inst_c_mv
`endif
                                    };
    assign  o_bus.alu_ctrl.cmp_eq  = |{inst_beq,inst_bne
`ifdef EXTENSION_C
                                        ,inst_c_beqz,inst_c_bnez
`endif
                                    };
    assign  o_bus.alu_ctrl.cmp_lts = |{inst_slti,inst_slt,inst_blt,inst_bge};
    assign  o_bus.alu_ctrl.cmp_ltu = inst_ltu;
    assign  o_bus.alu_ctrl.cmp_inversed = (funct3[0] & inst_branch)
`ifdef EXTENSION_C
                                        | inst_c_bnez
`endif
                                    ;
    assign  o_bus.alu_ctrl.bits_and = |{inst_andi,inst_and
`ifdef EXTENSION_C
                                        ,inst_c_and,inst_c_andi
`endif
                                        };
    assign  o_bus.alu_ctrl.bits_or  = |{inst_ori,inst_or
`ifdef EXTENSION_C
                                        ,inst_c_or
`endif
                                        };
    assign  o_bus.alu_ctrl.bits_xor = |{inst_xori,inst_xor
`ifdef EXTENSION_C
                                        ,inst_c_xor
`endif
                                        };
    assign  o_bus.alu_ctrl.arith_shl = |{inst_slli,inst_sll
`ifdef EXTENSION_C
                                        ,inst_c_slli
`endif
                                        };
    assign  o_bus.alu_ctrl.arith_shr = |{inst_srli,inst_srl,inst_srai,inst_sra
`ifdef EXTENSION_C
                                        ,inst_c_srai,inst_c_srli
`endif
                                        };
    assign  o_bus.alu_ctrl.arith_sub = |{inst_sub
`ifdef EXTENSION_C
                                        ,inst_c_sub
`endif
                                        };
    assign  o_bus.alu_ctrl.arith_add = |{inst_add,inst_addi
`ifdef EXTENSION_C
                                        ,inst_c_addi16sp,inst_c_addi4spn,
                                        inst_c_addi,inst_c_add,
                                        inst_c_li, inst_c_mv
`endif
                                            };
    assign  o_bus.alu_ctrl.shift_arithmetical = |{inst_srai,inst_sra
`ifdef EXTENSION_C
                                        ,inst_c_srai
`endif
                                        };

    assign  o_bus.pc = pc;
    assign  o_bus.funct3 = (inst_full) ? funct3 : (3'b010);
    assign  o_bus.inst_jalr = inst_jalr
`ifdef EXTENSION_C
                                | inst_c_jalr | inst_c_jr
`endif
                                ;
    assign  o_bus.inst_jal = inst_jal
`ifdef EXTENSION_C
                                | inst_c_jal | inst_c_j
`endif
                                ;
    assign  o_bus.inst_branch = inst_branch
`ifdef EXTENSION_C
                                | inst_c_beqz | inst_c_bnez
`endif
                                ;
    assign  o_bus.inst_store = inst_store
`ifdef EXTENSION_C
                            | inst_c_sw | inst_c_swsp
`endif
                                ;

    /*logic [127:0] dbg_ascii_alu_ctrl;
    always @* begin
        dbg_ascii_alu_ctrl = '0;
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_NIN, `ALU_CMP_EQ })  dbg_ascii_alu_ctrl = "EQ";
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_NIN, `ALU_CMP_LTS }) dbg_ascii_alu_ctrl = "LTS";
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_NIN, `ALU_CMP_LTU }) dbg_ascii_alu_ctrl = "LTU";
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_INV, `ALU_CMP_EQ })  dbg_ascii_alu_ctrl = "!EQ";
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_INV, `ALU_CMP_LTS }) dbg_ascii_alu_ctrl = "!LTS";
        if (alu_ctrl[3:0] == { `ALU_GRP_CMP, `ALU_CMP_INV, `ALU_CMP_LTU }) dbg_ascii_alu_ctrl = "!LTU";
        if (alu_ctrl[3:0] == { `ALU_GRP_ARIPH, `ALU_ARIPH_ADD }) dbg_ascii_alu_ctrl = "ADD";
        if (alu_ctrl[3:0] == { `ALU_GRP_ARIPH, `ALU_ARIPH_SUB }) dbg_ascii_alu_ctrl = "SUB";
        if (alu_ctrl[3:0] == { `ALU_GRP_ARIPH, `ALU_ARIPH_SHL }) dbg_ascii_alu_ctrl = "SHL";
        if (alu_ctrl[4:0] == {1'b0, `ALU_GRP_ARIPH, `ALU_ARIPH_SHR}) dbg_ascii_alu_ctrl = "L_SHR";
        if (alu_ctrl[4:0] == {1'b1, `ALU_GRP_ARIPH, `ALU_ARIPH_SHR}) dbg_ascii_alu_ctrl = "A_SHR";
        if (alu_ctrl[3:0] == { `ALU_GRP_BITS, `ALU_BITS_XOR }) dbg_ascii_alu_ctrl = "XOR";
        if (alu_ctrl[3:0] == { `ALU_GRP_BITS, `ALU_BITS_OR })  dbg_ascii_alu_ctrl = "OR";
        if (alu_ctrl[3:0] == { `ALU_GRP_BITS, `ALU_BITS_AND }) dbg_ascii_alu_ctrl = "AND";
    end*/

/* verilator lint_off UNUSEDSIGNAL */
    logic [127:0] dbg_ascii_instr;
    always @* begin
        dbg_ascii_instr = '0;

    `ifdef EXTENSION_C
        if (inst_c_addi4spn) dbg_ascii_instr = "c.addi4spn";
        if (inst_c_lw)       dbg_ascii_instr = "c.lw";
        if (inst_c_sw)       dbg_ascii_instr = "c.sw";
        if (inst_c_addi)     dbg_ascii_instr = "c.addi";
        if (inst_c_jal)      dbg_ascii_instr = "c.jal";
        if (inst_c_li)       dbg_ascii_instr = "c.li";
        if (inst_c_addi16sp) dbg_ascii_instr = "c.addi16sp";
        if (inst_c_lui)      dbg_ascii_instr = "c.lui";
        if (inst_c_srli)     dbg_ascii_instr = "c.srli";
        if (inst_c_srai)     dbg_ascii_instr = "c.srai";
        if (inst_c_andi)     dbg_ascii_instr = "c.andi";
        if (inst_c_sub)      dbg_ascii_instr = "c.sub";
        if (inst_c_xor)      dbg_ascii_instr = "c.xor";
        if (inst_c_or)       dbg_ascii_instr = "c.or";
        if (inst_c_and)      dbg_ascii_instr = "c.and";
        if (inst_c_j)        dbg_ascii_instr = "c.j";
        if (inst_c_beqz)     dbg_ascii_instr = "c.beqz";
        if (inst_c_bnez)     dbg_ascii_instr = "c.bnez";
        if (inst_c_slli)     dbg_ascii_instr = "c.slli";
        if (inst_c_lwsp)     dbg_ascii_instr = "c.lwsp";
        if (inst_c_jr)       dbg_ascii_instr = "c.jr";
        if (inst_c_mv)       dbg_ascii_instr = "c.mv";
        if (inst_c_jalr)     dbg_ascii_instr = "c.jalr";
        if (inst_c_add)      dbg_ascii_instr = "c.add";
        if (inst_c_swsp)     dbg_ascii_instr = "c.swsp";
    `endif

        if (inst_lui)      dbg_ascii_instr = "lui";
        if (inst_auipc)    dbg_ascii_instr = "auipc";
        if (inst_jal)      dbg_ascii_instr = "jal";
        if (inst_jalr)     dbg_ascii_instr = "jalr";

        if (inst_beq)      dbg_ascii_instr = "beq";
        if (inst_bne)      dbg_ascii_instr = "bne";
        if (inst_blt)      dbg_ascii_instr = "blt";
        if (inst_bge)      dbg_ascii_instr = "bge";
        if (inst_bltu)     dbg_ascii_instr = "bltu";
        if (inst_bgeu)     dbg_ascii_instr = "bgeu";

        if (inst_lb)       dbg_ascii_instr = "lb";
        if (inst_lh)       dbg_ascii_instr = "lh";
        if (inst_lw)       dbg_ascii_instr = "lw";
        if (inst_lbu)      dbg_ascii_instr = "lbu";
        if (inst_lhu)      dbg_ascii_instr = "lhu";
        if (inst_sb)       dbg_ascii_instr = "sb";
        if (inst_sh)       dbg_ascii_instr = "sh";
        if (inst_sw)       dbg_ascii_instr = "sw";

        if (inst_addi)     dbg_ascii_instr = "addi";
        if (inst_slti)     dbg_ascii_instr = "slti";
        if (inst_sltiu)    dbg_ascii_instr = "sltiu";
        if (inst_xori)     dbg_ascii_instr = "xori";
        if (inst_ori)      dbg_ascii_instr = "ori";
        if (inst_andi)     dbg_ascii_instr = "andi";
        if (inst_slli)     dbg_ascii_instr = "slli";
        if (inst_srli)     dbg_ascii_instr = "srli";
        if (inst_srai)     dbg_ascii_instr = "srai";

        if (inst_add)      dbg_ascii_instr = "add";
        if (inst_sub)      dbg_ascii_instr = "sub";
        if (inst_sll)      dbg_ascii_instr = "sll";
        if (inst_slt)      dbg_ascii_instr = "slt";
        if (inst_sltu)     dbg_ascii_instr = "sltu";
        if (inst_xor)      dbg_ascii_instr = "xor";
        if (inst_srl)      dbg_ascii_instr = "srl";
        if (inst_sra)      dbg_ascii_instr = "sra";
        if (inst_or)       dbg_ascii_instr = "or";
        if (inst_and)      dbg_ascii_instr = "and";
        
        if (inst_fence)    dbg_ascii_instr = "fence";
        if (inst_fence_i)  dbg_ascii_instr = "fence.i";
        
        if (inst_ecall)    dbg_ascii_instr = "ecall";
        if (inst_ebreak)   dbg_ascii_instr = "ebreak";
        
    `ifdef EXTENSION_Zicsr
        if (inst_csrrw)    dbg_ascii_instr = "csrrw";
        if (inst_csrrs)    dbg_ascii_instr = "csrrs";
        if (inst_csrrc)    dbg_ascii_instr = "csrrc";
        if (inst_csrrwi)   dbg_ascii_instr = "csrrwi";
        if (inst_csrrsi)   dbg_ascii_instr = "csrrsi";
        if (inst_csrrci)   dbg_ascii_instr = "csrrci";
    `endif

        if (inst_none)     dbg_ascii_instr = "NONE";
    end
/* verilator lint_on UNUSEDSIGNAL */

endmodule
