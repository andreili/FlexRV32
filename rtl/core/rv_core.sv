`timescale 1ps/1ps

`include "rv_defines.vh"
`include "rv_opcodes.vh"

/* verilator lint_off UNUSEDSIGNAL */

module rv_core
#(
    parameter   RESET_ADDR = 32'h0000_0000
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    //
    output  wire[31:0]                  o_wb_adr,
    output  wire[31:0]                  o_wb_dat,
    input   wire[31:0]                  i_wb_dat,
    output  wire                        o_wb_we,
    output  wire[3:0]                   o_wb_sel,
    output  wire                        o_wb_stb,
    input   wire                        i_wb_ack,
`ifdef TO_SIM
    output  wire[31:0]                  o_debug,
`endif
    output  wire                        o_wb_cyc
);

    logic[3:0]  state_cur, state_nxt;
    localparam  STATE_FETCH = 0;
    localparam  STATE_RS = 1;
    localparam  STATE_ALU1 = 2;
    localparam  STATE_MEM = 3;
    localparam  STATE_WR = 4;

    always_comb
    begin
        case (state_cur)
        STATE_FETCH: state_nxt = i_wb_ack ? STATE_RS : STATE_FETCH;
        STATE_RS: state_nxt = STATE_ALU1;
        STATE_ALU1: state_nxt = STATE_MEM;
        STATE_MEM: state_nxt = STATE_WR;
        STATE_WR: state_nxt = STATE_FETCH;
        default: state_nxt = STATE_FETCH;
        endcase
    end

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            state_cur <= STATE_FETCH;
        else
            state_cur <= state_nxt;
    end

    logic[31:0] reg_rdata1, reg_rdata2;

    logic[31:0] fetch_pc;
    logic[31:0] fetch_pc_next;
    logic[31:0] fetch_data_buf;
    logic[31:0] fetch_data;
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
        alu_pc_select ? alu_pc_target :
`ifdef BRANCH_PREDICTION_SIMPLE
        //fetch_bp_need ? fetch_bp_addr :
`endif
        fetch_pc + 4;

    always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
        begin
            fetch_pc <= RESET_ADDR;
        end
        else if (state_nxt == STATE_FETCH)
        begin
            fetch_pc <= fetch_pc_next;
        end
    end

    always_ff @(posedge i_clk)
    begin
        if (state_cur == STATE_RS)
            fetch_data_buf <= i_wb_dat;
    end

    /*always_ff @(posedge i_clk)
    begin
        if (!i_reset_n)
            fetch_ready <= '0;
        else if ((state_cur == STATE_FETCH) && (i_wb_ack))
            fetch_ready <= '1;
        else
            fetch_ready <= '0;
    end*/

    assign  fetch_data = (state_cur == STATE_RS) ? i_wb_dat : fetch_data_buf;

`ifdef BRANCH_PREDICTION_SIMPLE
    assign  fetch_bp_op        = fetch_data[6:0];
    //assign  fetch_bp_rd        = fetch_data[11:7];
    assign  fetch_bp_rs        = fetch_data[19:15];
    assign  fetch_bp_b_sign    = fetch_data[31];
    assign  fetch_bp_b_offs    = { {20{fetch_data[31]}}, fetch_data[7], fetch_data[30:25], fetch_data[11:8], 1'b0 };
    assign  fetch_bp_jalr_offs = { {21{fetch_data[31]}}, fetch_data[30:20] };
    assign  fetch_bp_jal_offs  = { {12{fetch_data[31]}}, fetch_data[19:12], fetch_data[20], fetch_data[30:21], 1'b0 };
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

    //logic[6:0]  decode_op;
    logic[4:0]  decode_rd;
    logic[2:0]  decode_funct3;
    logic[4:0]  decode_rs1, decode_rs2;
    logic[6:0]  decode_funct7;
    logic[11:0] decode_funct12;

    logic[31:0] decode_imm_i, decode_imm_s, decode_imm_b, decode_imm_u, decode_imm_j;
    logic[31:0] decode_imm;
    logic       decode_reg_write;
    logic[1:0]  decode_res_src;
    logic       decode_alu_op1_sel;
    logic       decode_alu_op2_sel;
    logic[4:0]  decode_alu_ctrl;

    logic   decode_inst_full, decode_inst_none, decode_inst_supported;
    logic   decode_inst_grp_load;
    logic   decode_inst_grp_arif_imm;
    logic   decode_inst_grp_auipc;
    logic   decode_inst_grp_store;
    logic   decode_inst_grp_arif_reg;
    logic   decode_inst_grp_lui;
    logic   decode_inst_grp_branch;
    logic   decode_inst_grp_jalr;
    logic   decode_inst_grp_jal;
    logic   decode_inst_grp_misc_mem;
    logic   decode_inst_grp_system;

    logic   decode_inst_lb, decode_inst_lh, decode_inst_lw, decode_inst_lbu, decode_inst_lhu;
    logic   decode_inst_addi, decode_inst_slli, decode_inst_slti, decode_inst_sltiu;
    logic   decode_inst_xori, decode_inst_srli, decode_inst_srai, decode_inst_ori, decode_inst_andi;
    logic   decode_inst_auipc;
    logic   decode_inst_sb, decode_inst_sh, decode_inst_sw;
    logic   decode_inst_add, decode_inst_sub, decode_inst_sll, decode_inst_slt, decode_inst_sltu;
    logic   decode_inst_xor, decode_inst_srl, decode_inst_sra, decode_inst_or, decode_inst_and;
    logic   decode_inst_lui;
    logic   decode_inst_beq, decode_inst_bne, decode_inst_blt, decode_inst_bge, decode_inst_bltu, decode_inst_bgeu;
    logic   decode_inst_jalr;
    logic   decode_inst_jal;
    logic   decode_inst_ecall, decode_inst_ebreak;
    logic   decode_inst_fence, decode_inst_fence_i;
    logic   decode_inst_load;
    logic   decode_inst_store;
    logic   decode_inst_imm;
    logic   decode_inst_reg;
    logic   decode_inst_branch;

    //assign  decode_op      = fetch_data[6:0];
    assign  decode_rd      = fetch_data[11:7];
    assign  decode_funct3  = fetch_data[14:12];
    assign  decode_rs1     = decode_inst_lui ? '0 : fetch_data[19:15];
    assign  decode_rs2     = fetch_data[24:20];
    assign  decode_funct7  = fetch_data[31:25];
    assign  decode_funct12 = fetch_data[31:20];

    assign  decode_imm_i = { {21{fetch_data[31]}}, fetch_data[30:20] };
    assign  decode_imm_s = { {21{fetch_data[31]}}, fetch_data[30:25], fetch_data[11:7] };
    assign  decode_imm_b = { {20{fetch_data[31]}}, fetch_data[7], fetch_data[30:25], fetch_data[11:8], 1'b0 };
    assign  decode_imm_u = { fetch_data[31:12], {12{1'b0}} };
    assign  decode_imm_j = { {12{fetch_data[31]}}, fetch_data[19:12], fetch_data[20], fetch_data[30:21], 1'b0 };

    always_comb
    begin
        case (1'b1)
        decode_inst_jal:
            decode_imm = decode_imm_j;
        |{decode_inst_lui, decode_inst_auipc}:
            decode_imm = decode_imm_u;
        |{decode_inst_jalr, decode_inst_load, decode_inst_imm}:
            decode_imm = decode_imm_i;
        decode_inst_branch:
            decode_imm = decode_imm_b;
        decode_inst_store:
            decode_imm = decode_imm_s;
        default:decode_imm = 'x;
        endcase
    end

    assign  decode_inst_full = (fetch_data[1:0] == RV32_OPC_DET);
    assign  decode_inst_none = !(|fetch_data);
    // instructions groups
    assign  decode_inst_grp_load     = (fetch_data[6:2] == RV32_OPC_LD)   & decode_inst_full;
    assign  decode_inst_grp_misc_mem = (fetch_data[6:2] == RV32_OPC_MEM)  & decode_inst_full;
    assign  decode_inst_grp_arif_imm = (fetch_data[6:2] == RV32_OPC_ARI)  & decode_inst_full;
    assign  decode_inst_grp_auipc    = (fetch_data[6:2] == RV32_OPC_AUI)  & decode_inst_full;
    assign  decode_inst_grp_store    = (fetch_data[6:2] == RV32_OPC_STR)  & decode_inst_full;
    assign  decode_inst_grp_arif_reg = (fetch_data[6:2] == RV32_OPC_ARR)  & decode_inst_full;
    assign  decode_inst_grp_lui      = (fetch_data[6:2] == RV32_OPC_LUI)  & decode_inst_full;
    assign  decode_inst_grp_branch   = (fetch_data[6:2] == RV32_OPC_B)    & decode_inst_full;
    assign  decode_inst_grp_jalr     = (fetch_data[6:2] == RV32_OPC_JALR) & decode_inst_full;
    assign  decode_inst_grp_jal      = (fetch_data[6:2] == RV32_OPC_JAL)  & decode_inst_full;
    assign  decode_inst_grp_system   = (fetch_data[6:2] == RV32_OPC_SYS)  & decode_inst_full;

    assign  decode_inst_supported = 
            decode_inst_none |
            decode_inst_lb    | decode_inst_lh   | decode_inst_lw   | decode_inst_lbu   | decode_inst_lhu  |
            decode_inst_addi  | decode_inst_slli | decode_inst_slti | decode_inst_sltiu |
            decode_inst_xori  | decode_inst_srli | decode_inst_srai | decode_inst_ori   | decode_inst_andi |
            decode_inst_auipc |
            decode_inst_sb    | decode_inst_sh   | decode_inst_sw   |
            decode_inst_add   | decode_inst_sub  | decode_inst_sll  | decode_inst_slt   | decode_inst_sltu |
            decode_inst_xor   | decode_inst_srl  | decode_inst_sra  | decode_inst_or    | decode_inst_and  |
            decode_inst_lui   |
            decode_inst_beq   | decode_inst_bne  | decode_inst_blt  | decode_inst_bge   | decode_inst_bltu | decode_inst_bgeu |
            decode_inst_jalr  |
            decode_inst_jal   |
            decode_inst_fence | decode_inst_fence_i
            ;

    // memory read operations
    assign  decode_inst_lb       = decode_inst_grp_load & (decode_funct3 == 3'b000);
    assign  decode_inst_lh       = decode_inst_grp_load & (decode_funct3 == 3'b001);
    assign  decode_inst_lw       = decode_inst_grp_load & (decode_funct3 == 3'b010);
    assign  decode_inst_lbu      = decode_inst_grp_load & (decode_funct3 == 3'b100);
    assign  decode_inst_lhu      = decode_inst_grp_load & (decode_funct3 == 3'b101);
    // arifmetical with immediate
    assign  decode_inst_addi     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b000);
    assign  decode_inst_slli     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b001);
    assign  decode_inst_slti     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b010);
    assign  decode_inst_sltiu    = decode_inst_grp_arif_imm & (decode_funct3 == 3'b011);
    assign  decode_inst_xori     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b100);
    assign  decode_inst_srli     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b101) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_srai     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b101) & (decode_funct7 == 7'b0100000);
    assign  decode_inst_ori      = decode_inst_grp_arif_imm & (decode_funct3 == 3'b110);
    assign  decode_inst_andi     = decode_inst_grp_arif_imm & (decode_funct3 == 3'b111);
    // add upper immediate to PC
    assign  decode_inst_auipc    = decode_inst_grp_auipc;
    // memory write operations
    assign  decode_inst_sb       = decode_inst_grp_store & (decode_funct3 == 3'b000);
    assign  decode_inst_sh       = decode_inst_grp_store & (decode_funct3 == 3'b001);
    assign  decode_inst_sw       = decode_inst_grp_store & (decode_funct3 == 3'b010);
    // arifmetical with register
    assign  decode_inst_add      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b000) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_sub      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b000) & (decode_funct7 == 7'b0100000);
    assign  decode_inst_sll      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b001) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_slt      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b010) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_sltu     = decode_inst_grp_arif_reg & (decode_funct3 == 3'b011) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_xor      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b100) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_srl      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b101) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_sra      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b101) & (decode_funct7 == 7'b0100000);
    assign  decode_inst_or       = decode_inst_grp_arif_reg & (decode_funct3 == 3'b110) & (decode_funct7 == 7'b0000000);
    assign  decode_inst_and      = decode_inst_grp_arif_reg & (decode_funct3 == 3'b111) & (decode_funct7 == 7'b0000000);
    // load upper immediate
    assign  decode_inst_lui      = decode_inst_grp_lui;
    // branches
    assign  decode_inst_beq      = decode_inst_grp_branch & (decode_funct3 == 3'b000);
    assign  decode_inst_bne      = decode_inst_grp_branch & (decode_funct3 == 3'b001);
    assign  decode_inst_blt      = decode_inst_grp_branch & (decode_funct3 == 3'b100);
    assign  decode_inst_bge      = decode_inst_grp_branch & (decode_funct3 == 3'b101);
    assign  decode_inst_bltu     = decode_inst_grp_branch & (decode_funct3 == 3'b110);
    assign  decode_inst_bgeu     = decode_inst_grp_branch & (decode_funct3 == 3'b111);
    // jumps
    assign  decode_inst_jalr     = decode_inst_grp_jalr & (decode_funct3 == 3'b000);
    assign  decode_inst_jal      = decode_inst_grp_jal;
    // fence
    assign  decode_inst_fence    = decode_inst_grp_misc_mem & (decode_funct3 == 3'b000);
    assign  decode_inst_fence_i  = decode_inst_grp_misc_mem & (decode_funct3 == 3'b001);
    // system
    assign  decode_inst_ecall    = decode_inst_grp_system & (decode_funct3 == 3'b000) & (decode_funct12 == 12'b000000000000);
    assign  decode_inst_ebreak   = decode_inst_grp_system & (decode_funct3 == 3'b000) & (decode_funct12 == 12'b000000000001);

    assign  decode_inst_load = decode_inst_lb | decode_inst_lh | decode_inst_lw | decode_inst_lbu | decode_inst_lhu;
    assign  decode_inst_store = decode_inst_sb | decode_inst_sh | decode_inst_sw;
    assign  decode_inst_imm  = decode_inst_addi  | decode_inst_slli | decode_inst_slti | decode_inst_sltiu |
                decode_inst_xori  | decode_inst_srli | decode_inst_srai | decode_inst_ori   | decode_inst_andi;
    assign  decode_inst_reg  = decode_inst_add   | decode_inst_sub  | decode_inst_sll  | decode_inst_slt   | decode_inst_sltu |
                decode_inst_xor   | decode_inst_srl  | decode_inst_sra  | decode_inst_or    | decode_inst_and;
    assign  decode_inst_branch =  decode_inst_beq   | decode_inst_bne  | decode_inst_blt  | decode_inst_bge   | decode_inst_bltu | decode_inst_bgeu;

    assign  decode_reg_write = decode_inst_load | decode_inst_imm | decode_inst_auipc | decode_inst_reg | decode_inst_lui | decode_inst_jalr | decode_inst_jal;

    always_comb
    begin
        case (1'b1)
        |{decode_inst_auipc,decode_inst_jal}:
            decode_alu_op1_sel = `ALU_SRC_OP1_PC;
        default:
            decode_alu_op1_sel = `ALU_SRC_OP1_REG;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        |{decode_inst_auipc,decode_inst_jal,decode_inst_jalr,decode_inst_lui,decode_inst_imm,decode_inst_load,decode_inst_store}:
            decode_alu_op2_sel = `ALU_SRC_OP2_IMM;
        default:
            decode_alu_op2_sel = `ALU_SRC_OP2_REG;
        endcase
    end

    always_comb
    begin
        case (1'b1)
        decode_inst_load:
            decode_res_src = `RESULT_SRC_MEMORY;
        |{decode_inst_jalr,decode_inst_jal}:
            decode_res_src = `RESULT_SRC_PC_P4;
        default:
            decode_res_src = `RESULT_SRC_ALU;
        endcase
    end

    assign  decode_alu_ctrl[4] = |{decode_inst_srai,decode_inst_sra};

    always_comb
    begin
        case (1'b1)
        decode_inst_beq:
            decode_alu_ctrl[3:0] = `ALU_CMP_EQ;
        |{decode_inst_slti,decode_inst_slt,decode_inst_blt}:
            decode_alu_ctrl[3:0] = `ALU_CMP_LTS;
        |{decode_inst_sltiu,decode_inst_bltu,decode_inst_sltu}:
            decode_alu_ctrl[3:0] = `ALU_CMP_LTU;
        decode_inst_bne:
            decode_alu_ctrl[3:0] = `ALU_CMP_NEQ;
        decode_inst_bge:
            decode_alu_ctrl[3:0] = `ALU_CMP_NLTS;
        decode_inst_bgeu:
            decode_alu_ctrl[3:0] = `ALU_CMP_NLTU;
        decode_inst_sub:
            decode_alu_ctrl[3:0] = `ALU_CTRL_SUB;
        decode_inst_xori | decode_inst_xor:
            decode_alu_ctrl[3:0] = `ALU_CTRL_XOR;
        decode_inst_ori | decode_inst_or:
            decode_alu_ctrl[3:0] = `ALU_CTRL_OR;
        decode_inst_andi | decode_inst_and:
            decode_alu_ctrl[3:0] = `ALU_CTRL_AND;
        decode_inst_slli | decode_inst_sll:
            decode_alu_ctrl[3:0] = `ALU_CTRL_SHL;
        decode_inst_srli | decode_inst_srl | decode_inst_srai | decode_inst_sra:
            decode_alu_ctrl[3:0] = `ALU_CTRL_SHR;
        default:
            decode_alu_ctrl[3:0] = `ALU_CTRL_ADD;
        endcase
    end

    logic [127:0] dbg_ascii_alu_ctrl;
    always @* begin
        dbg_ascii_alu_ctrl = '0;
        if (decode_alu_ctrl[3:0] == `ALU_CMP_EQ) dbg_ascii_alu_ctrl = "EQ";
        if (decode_alu_ctrl[3:0] == `ALU_CMP_LTS) dbg_ascii_alu_ctrl = "LTS";
        if (decode_alu_ctrl[3:0] == `ALU_CMP_LTU) dbg_ascii_alu_ctrl = "LTU";
        if (decode_alu_ctrl[3:0] == `ALU_CMP_NEQ) dbg_ascii_alu_ctrl = "!EQ";
        if (decode_alu_ctrl[3:0] == `ALU_CMP_NLTS) dbg_ascii_alu_ctrl = "!LTS";
        if (decode_alu_ctrl[3:0] == `ALU_CMP_NLTU) dbg_ascii_alu_ctrl = "!LTU";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_ADD) dbg_ascii_alu_ctrl = "ADD";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_SUB) dbg_ascii_alu_ctrl = "SUB";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_XOR) dbg_ascii_alu_ctrl = "XOR";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_OR) dbg_ascii_alu_ctrl = "OR";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_AND) dbg_ascii_alu_ctrl = "AND";
        if (decode_alu_ctrl[3:0] == `ALU_CTRL_SHL) dbg_ascii_alu_ctrl = "SHL";
        if (decode_alu_ctrl[4:0] == {1'b0,`ALU_CTRL_SHR}) dbg_ascii_alu_ctrl = "L_SHR";
        if (decode_alu_ctrl[4:0] == {1'b1,`ALU_CTRL_SHR}) dbg_ascii_alu_ctrl = "A_SHR";
    end

    logic [127:0] dbg_ascii_instr;
    always @* begin
        dbg_ascii_instr = '0;

        if (decode_inst_none)     dbg_ascii_instr = "NONE";

        if (decode_inst_lui)      dbg_ascii_instr = "lui";
        if (decode_inst_auipc)    dbg_ascii_instr = "auipc";
        if (decode_inst_jal)      dbg_ascii_instr = "jal";
        if (decode_inst_jalr)     dbg_ascii_instr = "jalr";

        if (decode_inst_beq)      dbg_ascii_instr = "beq";
        if (decode_inst_bne)      dbg_ascii_instr = "bne";
        if (decode_inst_blt)      dbg_ascii_instr = "blt";
        if (decode_inst_bge)      dbg_ascii_instr = "bge";
        if (decode_inst_bltu)     dbg_ascii_instr = "bltu";
        if (decode_inst_bgeu)     dbg_ascii_instr = "bgeu";

        if (decode_inst_lb)       dbg_ascii_instr = "lb";
        if (decode_inst_lh)       dbg_ascii_instr = "lh";
        if (decode_inst_lw)       dbg_ascii_instr = "lw";
        if (decode_inst_lbu)      dbg_ascii_instr = "lbu";
        if (decode_inst_lhu)      dbg_ascii_instr = "lhu";
        if (decode_inst_sb)       dbg_ascii_instr = "sb";
        if (decode_inst_sh)       dbg_ascii_instr = "sh";
        if (decode_inst_sw)       dbg_ascii_instr = "sw";

        if (decode_inst_addi)     dbg_ascii_instr = "addi";
        if (decode_inst_slti)     dbg_ascii_instr = "slti";
        if (decode_inst_sltiu)    dbg_ascii_instr = "sltiu";
        if (decode_inst_xori)     dbg_ascii_instr = "xori";
        if (decode_inst_ori)      dbg_ascii_instr = "ori";
        if (decode_inst_andi)     dbg_ascii_instr = "andi";
        if (decode_inst_slli)     dbg_ascii_instr = "slli";
        if (decode_inst_srli)     dbg_ascii_instr = "srli";
        if (decode_inst_srai)     dbg_ascii_instr = "srai";

        if (decode_inst_add)      dbg_ascii_instr = "add";
        if (decode_inst_sub)      dbg_ascii_instr = "sub";
        if (decode_inst_sll)      dbg_ascii_instr = "sll";
        if (decode_inst_slt)      dbg_ascii_instr = "slt";
        if (decode_inst_sltu)     dbg_ascii_instr = "sltu";
        if (decode_inst_xor)      dbg_ascii_instr = "xor";
        if (decode_inst_srl)      dbg_ascii_instr = "srl";
        if (decode_inst_sra)      dbg_ascii_instr = "sra";
        if (decode_inst_or)       dbg_ascii_instr = "or";
        if (decode_inst_and)      dbg_ascii_instr = "and";
        
        if (decode_inst_fence)    dbg_ascii_instr = "fence";
        if (decode_inst_fence_i)  dbg_ascii_instr = "fence.i";
        
        if (decode_inst_ecall)    dbg_ascii_instr = "ecall";
        if (decode_inst_ebreak)   dbg_ascii_instr = "ebreak";
        
    `ifdef EXTENSION_Zicsr
        if (decode_inst_csrrw)    dbg_ascii_instr = "csrrw";
        if (decode_inst_csrrs)    dbg_ascii_instr = "csrrs";
        if (decode_inst_csrrc)    dbg_ascii_instr = "csrrc";
        if (decode_inst_csrrwi)   dbg_ascii_instr = "csrrwi";
        if (decode_inst_csrrsi)   dbg_ascii_instr = "csrrsi";
        if (decode_inst_csrrci)   dbg_ascii_instr = "csrrci";
    `endif
    end

    logic[31:0] alu_reg_data1, alu_reg_data2;
    logic[31:0] alu_op1, alu_op2;
    logic[31:0] alu_result;
    logic       alu_zero;
    logic[31:0] alu_pc_next;
    logic       alu_pc_select;
    logic[31:0] alu_pc_target;

    assign  alu_reg_data1 = (|decode_rs1) ? reg_rdata1 : '0;
    assign  alu_reg_data2 = (|decode_rs2) ? reg_rdata2 : '0;

    assign  alu_op1 = (decode_alu_op1_sel == `ALU_SRC_OP1_PC)  ? fetch_pc : alu_reg_data1;
    assign  alu_op2 = (decode_alu_op2_sel == `ALU_SRC_OP2_IMM) ? decode_imm : alu_reg_data2;

    rv_alu
    u_alu
    (
        .i_src_a                        (alu_op1),
        .i_src_b                        (alu_op2),
        .i_ctrl                         (decode_alu_ctrl),
        .o_result                       (alu_result),
        .o_zero                         (alu_zero)
    );

    assign  alu_pc_next = decode_inst_jalr ? alu_reg_data1 : fetch_pc;
    assign  alu_pc_select = /*(!fetch_bp_need) & */(decode_inst_jalr | decode_inst_jal | (decode_inst_branch & (alu_result[0])));
    assign  alu_pc_target = alu_pc_next + decode_imm;

    logic[31:0] memory_wdata;
    logic[3:0]  memory_sel;

    always_comb
    begin
        case (decode_funct3[1:0])
        2'b00:   memory_wdata = {4{alu_reg_data2[0+: 8]}};
        2'b01:   memory_wdata = {2{alu_reg_data2[0+:16]}};
        default: memory_wdata = alu_reg_data2;
        endcase
    end

    always_comb
    begin
        case (decode_funct3[1:0])
        2'b00: begin
            case (alu_result[1:0])
            2'b00: memory_sel = 4'b0001;
            2'b01: memory_sel = 4'b0010;
            2'b10: memory_sel = 4'b0100;
            2'b11: memory_sel = 4'b1000;
            endcase
        end
        2'b01: begin
            case (alu_result[1])
            1'b0: memory_sel = 4'b0011;
            1'b1: memory_sel = 4'b1100;
            endcase
        end
        default:  memory_sel = 4'b1111;
        endcase
    end

    logic[7:0]  write_byte;
    logic[15:0] write_half_word;
    logic[31:0] write_rdata;
    logic[31:0] write_data;

    always_comb
    begin
        case (alu_result[1:0])
        2'b00: write_byte = i_wb_dat[ 0+:8];
        2'b01: write_byte = i_wb_dat[ 8+:8];
        2'b10: write_byte = i_wb_dat[16+:8];
        2'b11: write_byte = i_wb_dat[24+:8];
        endcase
    end

    always_comb
    begin
        case (alu_result[1])
        1'b0: write_half_word = i_wb_dat[ 0+:16];
        1'b1: write_half_word = i_wb_dat[16+:16];
        endcase
    end

    always_comb
    begin
        case (decode_funct3)
        3'b000: write_rdata = { {24{write_byte[7]}}, write_byte};
        3'b001: write_rdata = { {16{write_half_word[15]}}, write_half_word};
        3'b010: write_rdata = i_wb_dat;
        3'b100: write_rdata = { {24{1'b0}}, write_byte};
        3'b101: write_rdata = { {16{1'b0}}, write_half_word};
        default:write_rdata = '0;
        endcase
    end

    assign  write_data = (decode_res_src == `RESULT_SRC_ALU) ? alu_result :
                     (decode_res_src == `RESULT_SRC_MEMORY) ? write_rdata :
                     (decode_res_src == `RESULT_SRC_PC_P4) ? (fetch_pc + 4) :
                     '0;

    rv_regs
    u_regs
    (
        .i_clk                          (i_clk),
        .i_reset_n                      (i_reset_n),
        .i_rs1                          (decode_rs1),
        .i_rs2                          (decode_rs2),
        .i_rd                           (decode_rd),
        .i_write                        (decode_reg_write && (state_cur == STATE_WR)),
        .i_data                         (write_data),
        .o_data1                        (reg_rdata1),
        .o_data2                        (reg_rdata2)
    );

    assign o_wb_adr = (state_cur == STATE_MEM) ? alu_result : fetch_pc;
    assign o_wb_dat = memory_wdata;
    assign o_wb_we = (state_cur == STATE_MEM) ? decode_inst_store : '0;
    assign o_wb_sel = (state_cur == STATE_MEM) ? memory_sel : '1;
    assign o_wb_stb = '1;
    assign o_wb_cyc = '1;
    assign o_debug = '0;

    logic[127:0] dbg_state;
    always_comb
    begin
        case (state_cur)
        STATE_FETCH: dbg_state = "fetch";
        STATE_RS:    dbg_state = "rs";
        STATE_ALU1:  dbg_state = "alu";
        STATE_MEM:   dbg_state = "mem";
        STATE_WR:    dbg_state = "wr";
        endcase
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
