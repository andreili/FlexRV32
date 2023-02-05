`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_decode
#(
    parameter int IADDR_SPACE_BITS      = 32,
    parameter logic EXTENSION_Zicsr     = 1
)
(
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ready,
    input   wire[IADDR_SPACE_BITS-1:0]  i_pc,
    input   wire                        i_branch_pred,
    input   wire                        i_is_compressed,
`ifdef TO_SIM
    output  wire[31:0]                  o_instr,
`endif
    // CSR interface
    output  wire[11:0]                  o_csr_idx,
    output  wire[4:0]                   o_csr_imm,
    output  wire                        o_csr_imm_sel,
    output  wire                        o_csr_write,
    output  wire                        o_csr_set,
    output  wire                        o_csr_clear,
    output  wire                        o_csr_read,
    output  wire                        o_csr_ebreak,
    output  wire[IADDR_SPACE_BITS-1:0]  o_csr_pc_next,
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc,
    output  wire                        o_branch_pred,
    output  wire[IADDR_SPACE_BITS-1:0]  o_pc_next,
    output  wire[4:0]                   o_rs1,
    output  wire[4:0]                   o_rs2,
    output  wire[4:0]                   o_rd,
    output  wire[31:0]                  o_imm_i,
    output  wire[31:0]                  o_imm_j,
    output  alu_res_t                   o_alu_res,
    output  alu_ctrl_t                  o_alu_ctrl,
    output  wire[2:0]                   o_funct3,
    output  res_src_t                   o_res_src,
    output  wire                        o_reg_write,
    output  wire                        o_op1_src,
    output  src_op2_t                   o_op2_src,
    output  wire                        o_inst_mret,
    output  wire                        o_inst_jalr,
    output  wire                        o_inst_jal,
    output  wire                        o_inst_branch,
    output  wire                        o_inst_store,
    output  wire                        o_inst_supported,
    output  wire                        o_inst_csr_req
);

    logic       valid_input;
    logic[31:0] instruction;
    logic       branch_pred;

    // flush logic
    assign  valid_input = (i_ready & (!i_flush));
    assign  instruction = valid_input ? i_instruction : 0;
    assign  branch_pred = valid_input ? i_branch_pred : 0;

    // get a parts of opcode
    logic[4:0]  rd, rs1, rs2;
    logic[6:0]  op, funct7;
    logic[2:0]  funct3;
    logic[11:0] funct12;
    assign  op        = instruction[ 6: 0];
    assign  rd        = instruction[11: 7];
    assign  rs1       = instruction[19:15];
    assign  rs2       = instruction[24:20];
    assign  funct3    = instruction[14:12];
    assign  funct7    = instruction[31:25];
    assign  funct12   = instruction[31:20];

    // get immediate values
    logic[31:0] imm_i, imm_j, imm_s, imm_b, imm_u;
    logic[31:0] imm_mux;
    assign  imm_i = { {21{instruction[31]}}, instruction[30:20] };
    assign  imm_s = { {21{instruction[31]}}, instruction[30:25], instruction[11:7] };
    assign  imm_b = { {20{instruction[31]}}, instruction[7], instruction[30:25],
                      instruction[11:8], 1'b0 };
    assign  imm_u = { instruction[31:12], {12{1'b0}} };
    assign  imm_j = { {12{instruction[31]}}, instruction[19:12], instruction[20],
                      instruction[30:21], 1'b0 };

    logic   inst_full;
    assign  inst_full = (op[1:0] == RV32_OPC_DET);

    // memory read operations
    logic   inst_grp_load;
    logic   inst_lb, inst_lh, inst_lw, inst_lbu, inst_lhu;
    assign  inst_grp_load = (op[6:2] == RV32_OPC_LD) & inst_full;
    assign  inst_lb       = inst_grp_load & (funct3 == 3'b000);
    assign  inst_lh       = inst_grp_load & (funct3 == 3'b001);
    assign  inst_lw       = inst_grp_load & (funct3 == 3'b010);
    assign  inst_lbu      = inst_grp_load & (funct3 == 3'b100);
    assign  inst_lhu      = inst_grp_load & (funct3 == 3'b101);
    // arifmetical with immediate
    logic   inst_grp_arr;
    logic   inst_addi, inst_slli, inst_slti, inst_sltiu;
    logic   inst_xori, inst_srli, inst_srai, inst_ori, inst_andi;
    assign  inst_grp_arr  = (op[6:2] == RV32_OPC_ARI) & inst_full;
    assign  inst_addi     = inst_grp_arr & (funct3 == 3'b000);
    assign  inst_slli     = inst_grp_arr & (funct3 == 3'b001);
    assign  inst_slti     = inst_grp_arr & (funct3 == 3'b010);
    assign  inst_sltiu    = inst_grp_arr & (funct3 == 3'b011);
    assign  inst_xori     = inst_grp_arr & (funct3 == 3'b100);
    assign  inst_srli     = inst_grp_arr & (funct3 == 3'b101) & (funct7 == 7'b0000000);
    assign  inst_srai     = inst_grp_arr & (funct3 == 3'b101) & (funct7 == 7'b0100000);
    assign  inst_ori      = inst_grp_arr & (funct3 == 3'b110);
    assign  inst_andi     = inst_grp_arr & (funct3 == 3'b111);

    // add upper immediate to PC
    logic   inst_auipc;
    assign  inst_auipc    = (op[6:2] == RV32_OPC_AUI) & inst_full;

    // memory write operations
    logic   inst_grp_store;
    logic   inst_sb, inst_sh, inst_sw;
    assign  inst_grp_store = (op[6:2] == RV32_OPC_STR) & inst_full;
    assign  inst_sb        = inst_grp_store & (funct3 == 3'b000);
    assign  inst_sh        = inst_grp_store & (funct3 == 3'b001);
    assign  inst_sw        = inst_grp_store & (funct3 == 3'b010);

    // arifmetical with register
    logic   inst_grp_arri;
    logic   inst_grp_arri_ex;
    logic   inst_add, inst_sub, inst_sll, inst_slt, inst_sltu;
    logic   inst_xor, inst_srl, inst_sra, inst_or, inst_and;
    assign  inst_grp_arri    = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct7 == 7'b0000000);
    assign  inst_grp_arri_ex = (op[6:2] == RV32_OPC_ARR) & inst_full & (funct7 == 7'b0100000);
    assign  inst_add      = inst_grp_arri    & (funct3 == 3'b000);
    assign  inst_sub      = inst_grp_arri_ex & (funct3 == 3'b000);
    assign  inst_sll      = inst_grp_arri    & (funct3 == 3'b001);
    assign  inst_slt      = inst_grp_arri    & (funct3 == 3'b010);
    assign  inst_sltu     = inst_grp_arri    & (funct3 == 3'b011);
    assign  inst_xor      = inst_grp_arri    & (funct3 == 3'b100);
    assign  inst_srl      = inst_grp_arri    & (funct3 == 3'b101);
    assign  inst_sra      = inst_grp_arri_ex & (funct3 == 3'b101);
    assign  inst_or       = inst_grp_arri    & (funct3 == 3'b110);
    assign  inst_and      = inst_grp_arri    & (funct3 == 3'b111);

    // load upper immediate
    logic   inst_lui;
    assign  inst_lui      = (op[6:2] == RV32_OPC_LUI) & inst_full;

    // branches
    logic   inst_grp_branch;
    logic   inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;
    assign  inst_grp_branch = (op[6:2] == RV32_OPC_B) & inst_full;
    assign  inst_beq      = inst_grp_branch & (funct3 == 3'b000);
    assign  inst_bne      = inst_grp_branch & (funct3 == 3'b001);
    assign  inst_blt      = inst_grp_branch & (funct3 == 3'b100);
    assign  inst_bge      = inst_grp_branch & (funct3 == 3'b101);
    assign  inst_bltu     = inst_grp_branch & (funct3 == 3'b110);
    assign  inst_bgeu     = inst_grp_branch & (funct3 == 3'b111);

    // jumps
    logic   inst_jalr, inst_jal;
    assign  inst_jalr     = (op[6:2] == RV32_OPC_JALR) & inst_full & (funct3 == 3'b000);
    assign  inst_jal      = (op[6:2] == RV32_OPC_JAL)  & inst_full;

    // system
    logic   inst_grp_sys;
    logic   inst_ecall, inst_ebreak;
    assign  inst_grp_sys  = (op[6:2] == RV32_OPC_SYS) & inst_full;
    assign  inst_ecall    = inst_grp_sys & (funct3 == 3'b000) & (funct12 == 12'b000000000000);
    assign  inst_ebreak   = inst_grp_sys & (funct3 == 3'b000) & (funct12 == 12'b000000000001);

`ifdef EXTENSION_Zifencei
    logic   inst_fence, inst_fence_i;
    assign  inst_fence    = (op[6:2] == RV32_OPC_MEM) & inst_full & (funct3 == 3'b000);
    assign  inst_fence_i  = (op[6:2] == RV32_OPC_MEM) & inst_full & (funct3 == 3'b001);
`endif

`ifdef EXTENSION_Zihintntl
    logic   inst_ntl, inst_ntl_p1, inst_ntl_pall, inst_ntl_s1, inst_ntl_all;
    assign  inst_ntl      = inst_add & (rd=='0) & (rs1=='0);
    assign  inst_ntl_p1   = inst_ntl & (rs2==5'h2);
    assign  inst_ntl_pall = inst_ntl & (rs2==5'h3);
    assign  inst_ntl_s1   = inst_ntl & (rs2==5'h4);
    assign  inst_ntl_all  = inst_ntl & (rs2==5'h5);
`endif

    logic   inst_mret, inst_csrrw, inst_csrrs, inst_csrrc, inst_csrrwi, inst_csrrsi, inst_csrrci;
    logic   inst_csr_req;
    assign  inst_mret       = inst_grp_sys & (funct3 == 3'b000) & (funct12 == 12'b001100000010);
    assign  inst_csrrw      = inst_grp_sys & (funct3 == 3'b001);
    assign  inst_csrrs      = inst_grp_sys & (funct3 == 3'b010);
    assign  inst_csrrc      = inst_grp_sys & (funct3 == 3'b011);
    assign  inst_csrrwi     = inst_grp_sys & (funct3 == 3'b101);
    assign  inst_csrrsi     = inst_grp_sys & (funct3 == 3'b110);
    assign  inst_csrrci     = inst_grp_sys & (funct3 == 3'b111);

    assign  o_imm_j = inst_jal ? imm_j : imm_b;
    assign  o_imm_i = imm_mux;

    assign  o_csr_idx     = instruction[31:20];
    assign  o_csr_imm     = instruction[19:15];
    assign  o_csr_imm_sel = funct3[2];
    assign  o_csr_write   = (inst_csrrw | inst_csrrwi) & (!i_stall);
    assign  o_csr_set     = (inst_csrrs | inst_csrrsi) & (!i_stall);
    assign  o_csr_clear   = (inst_csrrc | inst_csrrci) & (!i_stall);
    assign  o_csr_read    = inst_grp_sys;
    assign  o_csr_ebreak  = inst_ebreak;
    assign  o_csr_pc_next = pc_next;
    assign  o_inst_mret   = inst_mret;

    assign  o_reg_write = inst_full & (!((op[6:2] == RV32_OPC_B) | (op[6:2] == RV32_OPC_STR) |
                                         (op[6:2] == RV32_OPC_STF)));

    assign  o_rd  = rd;
    assign  o_rs1 = inst_lui ? '0 : rs1;
    assign  o_rs2 = rs2;
    assign  o_op1_src = |{inst_auipc,inst_jal};

    assign  o_op2_src.j = inst_jal;
    assign  o_op2_src.i = (|{inst_jalr, inst_grp_load, inst_grp_arr, inst_lui,
                             inst_auipc, inst_grp_store});
    assign  o_op2_src.r = !(|{inst_jal,inst_lui, inst_auipc,inst_jalr, inst_grp_load,
                              inst_grp_arr,inst_grp_store});

    assign  o_res_src.memory = inst_grp_load;
    assign  o_res_src.pc_next  = |{inst_jalr,inst_jal};
    assign  o_res_src.alu    = !(|{inst_grp_load,inst_jalr,inst_jal});

    assign  o_alu_res.cmp = |{inst_grp_branch,inst_slti,inst_sltiu,inst_slt,inst_sltu};
    assign  o_alu_res.bits = |{inst_andi,inst_and,
                                        inst_ori,inst_or,
                                        inst_xori,inst_xor};
    assign  o_alu_res.shift = |{inst_slli,inst_sll,inst_srli,inst_srl,inst_srai,inst_sra};
    assign  o_alu_res.arith = |{inst_sub, inst_add, inst_grp_load, inst_grp_store};

    assign  o_alu_ctrl.cmp_eq  = |{inst_beq,inst_bne};
    assign  o_alu_ctrl.cmp_lts = |{inst_slti,inst_slt,inst_blt,inst_bge};
    assign  o_alu_ctrl.cmp_ltu = |{inst_sltu,inst_sltiu,inst_bltu,inst_bgeu};
    assign  o_alu_ctrl.cmp_inversed = (funct3[0] & inst_grp_branch);
    assign  o_alu_ctrl.bits_and = |{inst_andi,inst_and};
    assign  o_alu_ctrl.bits_or  = |{inst_ori,inst_or};
    assign  o_alu_ctrl.bits_xor = |{inst_xori,inst_xor};
    assign  o_alu_ctrl.arith_shl = |{inst_slli,inst_sll};
    assign  o_alu_ctrl.arith_shr = |{inst_srli,inst_srl,inst_srai,inst_sra};
    assign  o_alu_ctrl.arith_sub = inst_sub;
    assign  o_alu_ctrl.arith_add = |{inst_add,inst_addi,inst_grp_load,inst_grp_store};
    assign  o_alu_ctrl.shift_arithmetical = |{inst_srai,inst_sra};

    assign  o_pc = i_pc;
    assign  o_funct3 = (inst_full) ? funct3 : (3'b010);
    assign  o_inst_jalr = inst_jalr;
    assign  o_inst_jal = inst_jal;
    assign  o_inst_branch = inst_grp_branch;
    assign  o_inst_store = inst_grp_store;

    logic[IADDR_SPACE_BITS-1:0] pc_next;
    assign  pc_next = (i_pc + { {(IADDR_SPACE_BITS-3){1'b0}},
                       (!i_is_compressed), i_is_compressed, 1'b0 });
    assign  o_pc_next = pc_next;
`ifdef TO_SIM
    assign  o_instr = instruction;
`endif
    assign  o_branch_pred = branch_pred;
    assign  o_inst_csr_req = inst_csr_req;

    assign  imm_mux = (|{inst_lui, inst_auipc}) ? imm_u :
                      (inst_grp_store) ? imm_s : imm_i;

    assign  inst_csr_req = ((inst_csrrw | inst_csrrs | inst_csrrc | inst_csrrwi |
                             inst_csrrsi | inst_csrrci) & EXTENSION_Zicsr);
    assign  o_inst_supported =
            (!valid_input) |
            inst_grp_load  | inst_grp_arri | inst_grp_arri_ex |
            inst_auipc | inst_grp_store | inst_grp_arr  |
            inst_lui   |
            inst_grp_branch |
            inst_jalr  |
            inst_jal   |
            inst_ecall | inst_ebreak
        `ifdef EXTENSION_Zifencei
            | inst_fence | inst_fence_i
        `endif
        `ifdef EXTENSION_Zihintntl
            | inst_ntl_p1 | inst_ntl_pall | inst_ntl_s1 | inst_ntl_all
        `endif
            | inst_csr_req | (inst_mret & EXTENSION_Zicsr)
            ;

`ifdef EXTENSION_Zifencei
    //inst_fence inst_fence_i
`endif

`ifdef EXTENSION_Zihintntl
    //inst_ntl_p1 inst_ntl_pall inst_ntl_s1 inst_ntl_all
`endif

`ifdef TO_SIM
/* verilator lint_off UNUSEDSIGNAL */
    logic [127:0] dbg_ascii_instr;
    /* verilator lint_on UNUSEDSIGNAL */
    always_comb
    begin
        dbg_ascii_instr = '0;

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

        if (inst_ecall)    dbg_ascii_instr = "ecall";
        if (inst_ebreak)   dbg_ascii_instr = "ebreak";

    `ifdef EXTENSION_Zifencei
        if (inst_fence)    dbg_ascii_instr = "fence";
        if (inst_fence_i)  dbg_ascii_instr = "fence.i";
    `endif

        if (inst_csrrw)    dbg_ascii_instr = "csrrw";
        if (inst_csrrs)    dbg_ascii_instr = "csrrs";
        if (inst_csrrc)    dbg_ascii_instr = "csrrc";
        if (inst_csrrwi)   dbg_ascii_instr = "csrrwi";
        if (inst_csrrsi)   dbg_ascii_instr = "csrrsi";
        if (inst_csrrci)   dbg_ascii_instr = "csrrci";
        if (inst_mret)     dbg_ascii_instr = "mret";

    `ifdef EXTENSION_Zihintntl
        if (inst_ntl_p1)   dbg_ascii_instr = "ntl.p1";
        if (inst_ntl_pall) dbg_ascii_instr = "ntl.pall";
        if (inst_ntl_s1)   dbg_ascii_instr = "ntl.s1";
        if (inst_ntl_all)  dbg_ascii_instr = "ntl.all";
    `endif
    end
`endif

initial
begin
    o_inst_store = '0;
    o_reg_write = '0;
end

endmodule
