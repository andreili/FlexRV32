`timescale 1ps/1ps

`include "../rv_defines.vh"
`include "../rv_structs.vh"
`include "rv_opcodes.vh"

module rv_decode
#(
    parameter int IADDR_SPACE_BITS      = 16,
    parameter logic BRANCH_PREDICTION   = 0,
    parameter int BRANCH_TABLE_SIZE_BITS= 2,
    parameter logic EXTENSION_C         = 1,
    parameter logic EXTENSION_F         = 0,
    parameter logic EXTENSION_M         = 1,
    parameter logic EXTENSION_Zicsr     = 1,
    parameter logic BUFFERED            = 1
)
(
    input   wire                        i_clk,
    input   wire                        i_stall,
    input   wire                        i_flush,
    input   wire[31:0]                  i_instruction,
    input   wire                        i_ready,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc_next,
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
    output  wire[IADDR_SPACE_BITS-1:1]  o_csr_pc_next,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc,
    output  wire[IADDR_SPACE_BITS-1:1]  o_pc_next,
    output  wire[4:0]                   o_rs1,
    output  wire[4:0]                   o_rs2,
    output  wire[4:0]                   o_rd,
    output  wire[31:0]                  o_imm_i,
    output  wire[2:0]                   o_funct3,
    output  alu_ctrl_t                  o_alu_ctrl,
    output  res_src_t                   o_res_src,
    output  wire                        o_reg_write,
    output  wire                        o_op1_src,
    output  wire                        o_op2_src,
    output  wire                        o_inst_mret,
    output  wire                        o_inst_jalr,
    output  wire                        o_inst_jal,
    output  wire                        o_inst_branch,
    output  wire                        o_inst_store,
    output  wire                        o_inst_supported,
    output  wire                        o_inst_csr_req
);

/* verilator lint_off UNUSEDSIGNAL */
    logic   clk;
    buf buf_clk(clk, i_clk);
/* verilator lint_on  UNUSEDSIGNAL */

    logic[31:0] instruction_c;
    logic[31:0] instruction_unc;

    logic       valid_input;
    logic[31:0] instruction;
    logic[IADDR_SPACE_BITS-1:1] pc;
    logic[IADDR_SPACE_BITS-1:1] pc_next;

    assign  instruction_c = i_ready ? i_instruction : '0;
    generate
        if (EXTENSION_C)
        begin
            /* verilator lint_off PINCONNECTEMPTY */
            rv_decode_comp
            u_comp
            (
                .i_instruction                  (instruction_c),
                .o_instruction                  (instruction_unc),
                .o_illegal_instruction          ()
            );
            /* verilator lint_on  PINCONNECTEMPTY */

            if (BUFFERED)
            begin
                always_ff @(posedge clk)
                begin
                    if (i_flush)
                    begin
                        instruction   <= '0;
                        valid_input   <= '0;
                    end
                    else if (!i_stall)
                    begin
                        instruction   <= instruction_unc;
                        valid_input   <= i_ready;
                        pc <= i_pc;
                        pc_next <= i_pc_next;
                    end
                end
            end
            else
            begin
                assign instruction = instruction_unc;
                assign pc = i_pc;
                assign pc_next = i_pc_next;
                assign valid_input = !i_stall & i_ready;
            end
        end
        else
        begin
            assign instruction = instruction_c;
            assign pc = i_pc;
            assign pc_next = i_pc_next;
            assign valid_input = !i_flush & i_ready;
        end
    endgenerate

    // get a parts of opcode
    logic[4:0]  rd, rs1, rs2;
    logic[1:0]  op_det;
    logic[4:0]  op;
    logic[6:0]  funct7;
    logic[2:0]  funct3;
    assign  op_det    = instruction[ 1: 0];
    assign  op        = instruction[ 6: 2];
    assign  rd        = instruction[11: 7];
    assign  rs1       = instruction[19:15];
    assign  rs2       = instruction[24:20];
    assign  funct3    = instruction[14:12];
    assign  funct7    = instruction[31:25];

    // get immediate values
    logic[31:0] imm_i, imm_j, imm_s, imm_b, imm_u;
    assign  imm_i = { {21{instruction[31]}}, instruction[30:20] };
    assign  imm_s = { {21{instruction[31]}}, instruction[30:25], instruction[11:7] };
    assign  imm_b = { {20{instruction[31]}}, instruction[7], instruction[30:25],
                      instruction[11:8], 1'b0 };
    assign  imm_u = { instruction[31:12], {12{1'b0}} };
    assign  imm_j = { {12{instruction[31]}}, instruction[19:12], instruction[20],
                      instruction[30:21], 1'b0 };

    logic   inst_full;
    assign  inst_full = (op_det == RV32_OPC_DET);

    // memory read operations
    logic   inst_grp_load, inst_grp_load_fp;
    assign  inst_grp_load    = (op == RV32_OPC_LOAD) & inst_full;
    assign  inst_grp_load_fp = (op == RV32_OPC_LOAD_FP) & inst_full & EXTENSION_F;

    // arifmetical with immediate
    logic   inst_grp_ari;
    logic   inst_slli, inst_slti, inst_sltiu;
    logic   inst_xori, inst_srli, inst_srai, inst_ori, inst_andi;
    assign  inst_grp_ari  = (op == RV32_OPC_OP_IMM) & inst_full;
    assign  inst_slli     = inst_grp_ari & (funct3 == 3'b001);
    assign  inst_slti     = inst_grp_ari & (funct3 == 3'b010);
    assign  inst_sltiu    = inst_grp_ari & (funct3 == 3'b011);
    assign  inst_xori     = inst_grp_ari & (funct3 == 3'b100);
    assign  inst_srli     = inst_grp_ari & (funct3 == 3'b101) & (funct7[5] == 1'b0);
    assign  inst_srai     = inst_grp_ari & (funct3 == 3'b101) & (funct7[5] == 1'b1);
    assign  inst_ori      = inst_grp_ari & (funct3 == 3'b110);
    assign  inst_andi     = inst_grp_ari & (funct3 == 3'b111);

    // add upper immediate to PC
    logic   inst_auipc;
    assign  inst_auipc    = (op == RV32_OPC_AUIPC) & inst_full;

    // memory write operations
    logic   inst_grp_store, inst_grp_store_fp;
    assign  inst_grp_store    = (op == RV32_OPC_STORE   ) & inst_full;
    assign  inst_grp_store_fp = (op == RV32_OPC_STORE_FP) & inst_full & EXTENSION_F;

    // arifmetical with register
    logic   inst_grp_reg, inst_grp_arr, inst_grp_mul;
    logic   inst_add, inst_sub, inst_sll, inst_slt, inst_sltu;
    logic   inst_xor, inst_srl, inst_sra, inst_or, inst_and;
    assign  inst_grp_reg = (op == RV32_OPC_OP) & inst_full;
    assign  inst_grp_arr  = inst_grp_reg & (funct7[0] == 1'b0);
    assign  inst_grp_mul  = inst_grp_reg & (funct7[0] == 1'b1) & EXTENSION_M;
    assign  inst_add      = inst_grp_arr & (funct3 == 3'b000) & (funct7[5] == 1'b0);
    assign  inst_sub      = inst_grp_arr & (funct3 == 3'b000) & (funct7[5] == 1'b1);
    assign  inst_sll      = inst_grp_arr & (funct3 == 3'b001);
    assign  inst_slt      = inst_grp_arr & (funct3 == 3'b010);
    assign  inst_sltu     = inst_grp_arr & (funct3 == 3'b011);
    assign  inst_xor      = inst_grp_arr & (funct3 == 3'b100);
    assign  inst_srl      = inst_grp_arr & (funct3 == 3'b101) & (funct7[5] == 1'b0);
    assign  inst_sra      = inst_grp_arr & (funct3 == 3'b101) & (funct7[5] == 1'b1);
    assign  inst_or       = inst_grp_arr & (funct3 == 3'b110);
    assign  inst_and      = inst_grp_arr & (funct3 == 3'b111);

    logic   inst_grp_arf;
    assign  inst_grp_arf  = (op == RV32_OPC_OP_FP) & inst_full &
                            (funct7[0] == 1'b0) & EXTENSION_F;

    logic   inst_grp_fmadd, inst_grp_fmsub;
    logic   inst_grp_fnmsub, inst_grp_fnmadd;
    assign  inst_grp_fmadd  = (op == RV32_OPC_MADD ) & inst_full & EXTENSION_F;
    assign  inst_grp_fmsub  = (op == RV32_OPC_MSUB ) & inst_full & EXTENSION_F;
    assign  inst_grp_fnmsub = (op == RV32_OPC_NMSUB) & inst_full & EXTENSION_F;
    assign  inst_grp_fnmadd = (op == RV32_OPC_NMADD) & inst_full & EXTENSION_F;

    // load upper immediate
    logic   inst_lui;
    assign  inst_lui      = (op == RV32_OPC_LUI) & inst_full;
    // branches
    logic   inst_grp_branch;
    assign  inst_grp_branch = (op == RV32_OPC_BRANCH) & inst_full;
    // jumps
    logic   inst_jalr, inst_jal;
    assign  inst_jalr     = (op == RV32_OPC_JALR) & inst_full & (funct3 == 3'b000);
    assign  inst_jal      = (op == RV32_OPC_JAL)  & inst_full;
    // system
    logic   inst_grp_sys;
    logic   inst_grp_trap, inst_ecall, inst_ebreak;
    logic   inst_mret, inst_csr_req;
    assign  inst_grp_sys  = (op == RV32_OPC_SYSTEM) & inst_full;
    assign  inst_grp_trap = inst_grp_sys  & !(|funct3);
    assign  inst_csr_req  = inst_grp_sys  &  (|funct3) & EXTENSION_Zicsr;
    assign  inst_ecall    = inst_grp_trap & (!funct7[3]) && (!rs2[0]);
    assign  inst_ebreak   = inst_grp_trap & (!funct7[3]) &&   rs2[0];
    assign  inst_mret     = inst_grp_trap &   funct7[4]  && (rs2[2:1] == 2'b01);

`ifdef EXTENSION_Zifencei
    logic   inst_fence, inst_fence_i;
    assign  inst_fence    = (op == RV32_OPC_MISC_MEM) & inst_full & (funct3 == 3'b000);
    assign  inst_fence_i  = (op == RV32_OPC_MISC_MEM) & inst_full & (funct3 == 3'b001);
`endif

`ifdef EXTENSION_Zihintntl
    logic   inst_ntl, inst_ntl_p1, inst_ntl_pall, inst_ntl_s1, inst_ntl_all;
    assign  inst_ntl      = inst_add & (rd=='0) & (rs1=='0);
    assign  inst_ntl_p1   = inst_ntl & (rs2==5'h2);
    assign  inst_ntl_pall = inst_ntl & (rs2==5'h3);
    assign  inst_ntl_s1   = inst_ntl & (rs2==5'h4);
    assign  inst_ntl_all  = inst_ntl & (rs2==5'h5);
`endif

    logic   rs1_zeroize, op1_src_pc;
    logic   ariph_add, ariph_inv, ariph_m;
    logic   op2_inv, imm_sel_r, inst_store;
    logic   res_src_mem, res_src_pc_next;

    assign  rs1_zeroize = op[2] & !op[1] & op[0];
    assign  op1_src_pc = (op == RV32_OPC_AUIPC) | (op == RV32_OPC_JAL);
    assign  ariph_m   = (op == RV32_OPC_OP) & funct7[0] & EXTENSION_M;
    assign  ariph_add = (!op[4] &          !op[2] & !op[1]) |
                        ( op[4] &  op[3] & !op[2] &  op[1] &  op[0]) |
                        (                   op[2] & !op[1] &  op[0]);
    assign  ariph_inv = ( op[4] &  op[3] & !op[2] & !op[1] & !op[0]) |
                        ((op == RV32_OPC_OP_IMM) & (funct3[2:1] == 2'b01)) |
                        ((op == RV32_OPC_OP)     & (funct3[2:1] == 2'b01) & !funct7[0]);
    assign  op2_inv = ariph_add | (op == RV32_OPC_OP_IMM);
    assign  imm_sel_r = (op == RV32_OPC_OP) |        // 5'b01100
                        (op == RV32_OPC_OP_FP) |     // 5'b10100
                        (op == RV32_OPC_BRANCH);     // 5'b11000
    assign  res_src_mem     = inst_full & !op[4] & !op[3] & !op[2] & !op[1];
    assign  res_src_pc_next = (op == RV32_OPC_JALR) |  // 5'b11001
                              (op == RV32_OPC_JAL);    // 5'b11011
    assign  inst_store  = !op[4] & op[3] & !op[2] & !op[1];

    assign  o_alu_ctrl.add_override = ariph_add;
    assign  o_alu_ctrl.op2_inverse  = ariph_inv ? '1 :
                                      op2_inv   ? '0 :
                                                  funct7[5];
    assign  o_alu_ctrl.sh_ar        = funct7[5];
    assign  o_alu_ctrl.group_mux    = ariph_m;
    assign  o_alu_ctrl.div_mux      = ariph_m & funct3[2];
    assign  o_csr_idx     = instruction[31:20];
    assign  o_csr_imm     = instruction[19:15];
    assign  o_csr_imm_sel = funct3[2];
    assign  o_csr_write   = inst_grp_sys & (funct3[1:0] == 2'b01);
    assign  o_csr_set     = inst_grp_sys & (funct3[1:0] == 2'b10);
    assign  o_csr_clear   = inst_grp_sys & (funct3[1:0] == 2'b11);
    assign  o_csr_read    = inst_grp_sys & (|funct3);
    assign  o_csr_ebreak  = inst_ebreak;
    assign  o_csr_pc_next = pc_next;
    assign  o_inst_mret   = inst_mret;
    assign  o_reg_write   = inst_full & ((op[3:1] != 3'b100) | op[0]);
    assign  o_rd          = rd;
    assign  o_rs1         = rs1_zeroize ? '0 : rs1;
    assign  o_rs2         = rs2;
    assign  o_op1_src     = op1_src_pc;
    assign  o_imm_i = (op[2:0] == 3'b101)       ? imm_u :
                      (op[4:1] == 4'b1101)      ? imm_j :
                      (op == RV32_OPC_STORE)    ? imm_s :
                      (op == RV32_OPC_STORE_FP) ? imm_s :
                      inst_grp_branch           ? imm_b :
                                                  imm_i;
    assign  o_op2_src         = !imm_sel_r;
    assign  o_res_src.memory  = res_src_mem;
    assign  o_res_src.pc_next = res_src_pc_next;
    assign  o_res_src.alu     = !(res_src_mem | res_src_pc_next);
    assign  o_pc              = pc;
    assign  o_funct3          = funct3;
    assign  o_inst_jalr       = (op == RV32_OPC_JALR);
    assign  o_inst_jal        = (op == RV32_OPC_JAL);
    assign  o_inst_branch     = (op == RV32_OPC_BRANCH);
    assign  o_inst_store      = inst_store;
    assign  o_pc_next         = pc_next;
`ifdef TO_SIM
    assign  o_instr        = instruction;
`endif
    assign  o_inst_csr_req = inst_csr_req;

    assign  o_inst_supported =
            (!valid_input) |
            inst_grp_load  | inst_grp_arr | inst_grp_mul |
            inst_auipc | inst_grp_store | inst_grp_ari  |
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

/* verilator lint_off UNUSEDSIGNAL */
    logic   dummy;
    assign  dummy = (|funct7) | BRANCH_PREDICTION | (|BRANCH_TABLE_SIZE_BITS);
/* verilator lint_on UNUSEDSIGNAL */

`ifdef TO_SIM
    logic   inst_addi;
    assign  inst_addi     = inst_grp_ari & (funct3 == 3'b000);
    logic   inst_lb, inst_lh, inst_lw, inst_lbu, inst_lhu;
    assign  inst_lb       = inst_grp_load  & (funct3 == 3'b000);
    assign  inst_lh       = inst_grp_load  & (funct3 == 3'b001);
    assign  inst_lw       = inst_grp_load  & (funct3 == 3'b010);
    assign  inst_lbu      = inst_grp_load  & (funct3 == 3'b100);
    assign  inst_lhu      = inst_grp_load  & (funct3 == 3'b101);
    logic   inst_flw;
    assign  inst_flw      = inst_grp_load_fp & (funct3 == 3'b010);
    logic   inst_sb, inst_sh, inst_sw;
    assign  inst_sb       = inst_grp_store & (funct3 == 3'b000);
    assign  inst_sh       = inst_grp_store & (funct3 == 3'b001);
    assign  inst_sw       = inst_grp_store & (funct3 == 3'b010);
    logic   inst_fsw;
    assign  inst_fsw      = inst_grp_store_fp & (funct3 == 3'b010);
    logic   inst_csrrw, inst_csrrs, inst_csrrc, inst_csrrwi, inst_csrrsi, inst_csrrci;
    assign  inst_csrrw    = inst_grp_sys & (funct3 == 3'b001);
    assign  inst_csrrs    = inst_grp_sys & (funct3 == 3'b010);
    assign  inst_csrrc    = inst_grp_sys & (funct3 == 3'b011);
    assign  inst_csrrwi   = inst_grp_sys & (funct3 == 3'b101);
    assign  inst_csrrsi   = inst_grp_sys & (funct3 == 3'b110);
    assign  inst_csrrci   = inst_grp_sys & (funct3 == 3'b111);
    logic   inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;
    assign  inst_beq      = inst_grp_branch & (funct3 == 3'b000);
    assign  inst_bne      = inst_grp_branch & (funct3 == 3'b001);
    assign  inst_blt      = inst_grp_branch & (funct3 == 3'b100);
    assign  inst_bge      = inst_grp_branch & (funct3 == 3'b101);
    assign  inst_bltu     = inst_grp_branch & (funct3 == 3'b110);
    assign  inst_bgeu     = inst_grp_branch & (funct3 == 3'b111);
    logic   inst_mul, inst_mulh, inst_mulhsu, inst_mulhu;
    logic   inst_div, inst_divu, inst_rem, inst_remu;
    assign  inst_mul      = inst_grp_mul    & (funct3 == 3'b000);
    assign  inst_mulh     = inst_grp_mul    & (funct3 == 3'b001);
    assign  inst_mulhsu   = inst_grp_mul    & (funct3 == 3'b010);
    assign  inst_mulhu    = inst_grp_mul    & (funct3 == 3'b011);
    assign  inst_div      = inst_grp_mul    & (funct3 == 3'b100);
    assign  inst_divu     = inst_grp_mul    & (funct3 == 3'b101);
    assign  inst_rem      = inst_grp_mul    & (funct3 == 3'b110);
    assign  inst_remu     = inst_grp_mul    & (funct3 == 3'b111);
    logic   inst_fmadds, inst_fmsubs;
    logic   inst_fnmsubs, inst_fnmadds;
    assign  inst_fmadds   = inst_grp_fmadd  & (funct7[1:0] == 2'b00);
    assign  inst_fmsubs   = inst_grp_fmsub  & (funct7[1:0] == 2'b00);
    assign  inst_fnmsubs  = inst_grp_fnmsub & (funct7[1:0] == 2'b00);
    assign  inst_fnmadds  = inst_grp_fnmadd & (funct7[1:0] == 2'b00);
    logic   inst_fadds, inst_fsubs, inst_fmuls, inst_fdivs;
    logic   inst_fsqrts, inst_fsgnjs, inst_fsgnjns, inst_fsgnjxs;
    logic   inst_fmins, inst_fmaxs, inst_fcvtws, inst_fcvtwus;
    logic   inst_fmvxw, inst_feqs, inst_flts, inst_fles;
    logic   inst_fclasss, inst_fcvtsw, inst_fcvtswu, inst_fmvwx;
    assign  inst_fadds    = inst_grp_arf & (funct7 == 7'b0000000);
    assign  inst_fsubs    = inst_grp_arf & (funct7 == 7'b0000100);
    assign  inst_fmuls    = inst_grp_arf & (funct7 == 7'b0001000);
    assign  inst_fdivs    = inst_grp_arf & (funct7 == 7'b0001100);
    assign  inst_fsqrts   = inst_grp_arf & (funct7 == 7'b0101100);
    assign  inst_fsgnjs   = inst_grp_arf & (funct7 == 7'b0010000) & (funct3 == 3'b000);
    assign  inst_fsgnjns  = inst_grp_arf & (funct7 == 7'b0010000) & (funct3 == 3'b001);
    assign  inst_fsgnjxs  = inst_grp_arf & (funct7 == 7'b0010000) & (funct3 == 3'b010);
    assign  inst_fmins    = inst_grp_arf & (funct7 == 7'b0010100) & (funct3 == 3'b000);
    assign  inst_fmaxs    = inst_grp_arf & (funct7 == 7'b0010100) & (funct3 == 3'b001);
    assign  inst_fcvtws   = inst_grp_arf & (funct7 == 7'b1100000) & (rs2 == 5'b00000);
    assign  inst_fcvtwus  = inst_grp_arf & (funct7 == 7'b1100000) & (rs2 == 5'b00001);
    assign  inst_fmvxw    = inst_grp_arf & (funct7 == 7'b1110000) &
                            (rs2 == 5'b00000) & (funct3 == 3'b000);
    assign  inst_feqs     = inst_grp_arf & (funct7 == 7'b1010000) & (funct3 == 3'b010);
    assign  inst_flts     = inst_grp_arf & (funct7 == 7'b1010000) & (funct3 == 3'b001);
    assign  inst_fles     = inst_grp_arf & (funct7 == 7'b1010000) & (funct3 == 3'b000);
    assign  inst_fclasss  = inst_grp_arf & (funct7 == 7'b1110000) &
                            (rs2 == 5'b00000) & (funct3 == 3'b001);
    assign  inst_fcvtsw   = inst_grp_arf & (funct7 == 7'b1101000) &
                            (rs2 == 5'b00000);
    assign  inst_fcvtswu  = inst_grp_arf & (funct7 == 7'b1101000) &
                            (rs2 == 5'b00001);
    assign  inst_fmvwx    = inst_grp_arf & (funct7 == 7'b1111000) &
                            (rs2 == 5'b00000) & (funct3 == 3'b000);
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

        if (inst_flw)      dbg_ascii_instr = "flw";
        if (inst_fsw)      dbg_ascii_instr = "fsw";
        if (inst_fmadds)   dbg_ascii_instr = "fmadd.s";
        if (inst_fmsubs)   dbg_ascii_instr = "fmsub.s";
        if (inst_fnmsubs)  dbg_ascii_instr = "fnmsub.s";
        if (inst_fnmadds)  dbg_ascii_instr = "fnmadd.s";
        if (inst_fadds)    dbg_ascii_instr = "fadd.s";
        if (inst_fsubs)    dbg_ascii_instr = "fsub.s";
        if (inst_fmuls)    dbg_ascii_instr = "fmul.s";
        if (inst_fdivs)    dbg_ascii_instr = "fdiv.s";
        if (inst_fsqrts)   dbg_ascii_instr = "fsqrt.s";
        if (inst_fsgnjs)   dbg_ascii_instr = "fsgnj.s";
        if (inst_fsgnjns)  dbg_ascii_instr = "fsgnjn.s";
        if (inst_fsgnjxs)  dbg_ascii_instr = "fsgnjx.s";
        if (inst_fmins)    dbg_ascii_instr = "fmin.s";
        if (inst_fmaxs)    dbg_ascii_instr = "fmax.s";
        if (inst_fcvtws)   dbg_ascii_instr = "fcvt.w.s";
        if (inst_fcvtwus)  dbg_ascii_instr = "fcvt.wu.s";
        if (inst_fmvxw)    dbg_ascii_instr = "fmv.x.s";
        if (inst_feqs)     dbg_ascii_instr = "feq.s";
        if (inst_flts)     dbg_ascii_instr = "flt.s";
        if (inst_fles)     dbg_ascii_instr = "fle.s";
        if (inst_fclasss)  dbg_ascii_instr = "fclass.s";
        if (inst_fcvtsw)   dbg_ascii_instr = "fcvt.s.w";
        if (inst_fcvtswu)  dbg_ascii_instr = "fcvt.s.wu";
        if (inst_fmvwx)    dbg_ascii_instr = "fmv.w.x";

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

        if (inst_mul)      dbg_ascii_instr = "mul";
        if (inst_mulh)     dbg_ascii_instr = "mulh";
        if (inst_mulhsu)   dbg_ascii_instr = "mulhsu";
        if (inst_mulhu)    dbg_ascii_instr = "mulhu";
        if (inst_div)      dbg_ascii_instr = "div";
        if (inst_divu)     dbg_ascii_instr = "divu";
        if (inst_rem)      dbg_ascii_instr = "rem";
        if (inst_remu)     dbg_ascii_instr = "remu";

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

`ifdef TO_SIM
initial
begin
    o_inst_store = '0;
    o_reg_write = '0;
end
`endif

endmodule
