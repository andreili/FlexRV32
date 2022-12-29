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

    always_ff @(posedge i_clk)
    begin
        pc <= i_bus.pc;
    end

    logic   inst_full, inst_none;

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

    assign  op        = i_bus.instruction[6:0];
    assign  o_bus.rd  = i_bus.instruction[11:7];
    assign  funct3    = i_bus.instruction[14:12];
    assign  o_bus.rs1 = inst_lui ? '0 : i_bus.instruction[19:15];
    assign  o_bus.rs2 = i_bus.instruction[24:20];
    assign  funct7    = i_bus.instruction[31:25];
    assign  funct12   = i_bus.instruction[31:20];

    assign o_bus.imm_i = { {21{i_bus.instruction[31]}}, i_bus.instruction[30:20] };
    assign o_bus.imm_s = { {21{i_bus.instruction[31]}}, i_bus.instruction[30:25], i_bus.instruction[11:7] };
    assign o_bus.imm_b = { {20{i_bus.instruction[31]}}, i_bus.instruction[7], i_bus.instruction[30:25], i_bus.instruction[11:8], 1'b0 };
    assign o_bus.imm_u = { i_bus.instruction[31:12], {12{1'b0}} };
    assign o_bus.imm_j = { {12{i_bus.instruction[31]}}, i_bus.instruction[19:12], i_bus.instruction[20], i_bus.instruction[30:21], 1'b0 };

    assign  inst_full = (op[1:0] == RV32_OPC_DET);
    assign  inst_none = !(|op);

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
            ;

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
    assign  inst_load   = (op[6:2] == RV32_OPC_LD)  & inst_full;
    assign  inst_store  = (op[6:2] == RV32_OPC_STR) & inst_full;
    assign  inst_imm    = (op[6:2] == RV32_OPC_ARI) & inst_full;
    assign  inst_reg    = (op[6:2] == RV32_OPC_ARR) & inst_full;
    assign  inst_branch = (op[6:2] == RV32_OPC_B)   & inst_full;
    assign  inst_slts   = ((op[6:2] == RV32_OPC_ARI) |
                                ( (op[6:2] == RV32_OPC_ARR) & (funct7 == 7'b0000000)))
                                & inst_full & (funct3[2:1] == 2'b01);
    assign  inst_ltu    = ((((op[6:2] == RV32_OPC_ARI) | ((op[6:2] == RV32_OPC_ARR) & (funct7 == 7'b0000000))) & (funct3 == 3'b011)) |
        ((op[6:2] == RV32_OPC_B) & (funct3[2:1] == 2'b11))) & inst_full;

    assign  o_bus.reg_write = inst_load | inst_imm | inst_auipc | inst_reg | inst_lui | inst_jalr | inst_jal;

    assign  o_bus.op1_src.pc = |{inst_auipc,inst_jal};
    assign  o_bus.op1_src.r  = !(|{inst_auipc,inst_jal});

    assign  o_bus.op2_src.j = inst_jal;
    assign  o_bus.op2_src.u = |{inst_lui, inst_auipc};
    assign  o_bus.op2_src.i = |{inst_jalr, inst_load, inst_imm};
    assign  o_bus.op2_src.s = inst_store;
    assign  o_bus.op2_src.r = !(|{inst_jal,inst_lui, inst_auipc,inst_jalr, inst_load, inst_imm,inst_store});

    assign  o_bus.res_src.memory = inst_load;
    assign  o_bus.res_src.pc_p4  = |{inst_jalr,inst_jal};
    assign  o_bus.res_src.alu    = !(|{inst_load,inst_jalr,inst_jal});

    assign  o_bus.alu_ctrl.res_cmp = |{inst_branch,inst_slts};
    assign  o_bus.alu_ctrl.res_bits = |{inst_andi,inst_and,
                                        inst_ori,inst_or,
                                        inst_xori,inst_xor};
    assign  o_bus.alu_ctrl.res_arith = |{inst_slli,inst_sll,
                                         inst_srli,inst_srl,inst_srai,inst_sra,
                                         inst_sub, inst_add};
    assign  o_bus.alu_ctrl.cmp_eq  = |{inst_beq,inst_bne};
    assign  o_bus.alu_ctrl.cmp_lts = |{inst_slti,inst_slt,inst_blt,inst_bge};
    assign  o_bus.alu_ctrl.cmp_ltu = inst_ltu;
    assign  o_bus.alu_ctrl.cmp_inversed = funct3[0];
    assign  o_bus.alu_ctrl.bits_and = |{inst_andi,inst_and};
    assign  o_bus.alu_ctrl.bits_or  = |{inst_ori,inst_or};
    assign  o_bus.alu_ctrl.bits_xor = |{inst_xori,inst_xor};
    assign  o_bus.alu_ctrl.arith_shl = |{inst_slli,inst_sll};
    assign  o_bus.alu_ctrl.arith_shr = |{inst_srli,inst_srl,inst_srai,inst_sra};
    assign  o_bus.alu_ctrl.arith_sub = inst_sub;
    assign  o_bus.alu_ctrl.arith_add = inst_add;
    assign  o_bus.alu_ctrl.shift_arithmetical = |{inst_srai,inst_sra};

    assign  o_bus.pc = pc;
    assign  o_bus.funct3 = funct3;
    assign  o_bus.inst_jalr = inst_jalr;
    assign  o_bus.inst_jal = inst_jal;
    assign  o_bus.inst_branch = inst_branch;
    assign  o_bus.inst_store = inst_store;

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

        if (inst_none)     dbg_ascii_instr = "NONE";

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
    end
/* verilator lint_on UNUSEDSIGNAL */

endmodule
