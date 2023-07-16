`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_trace
#(
    parameter int IADDR_SPACE_BITS      = 32
)
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[IADDR_SPACE_BITS-1:1]  i_pc,
    input   wire[31:0]                  i_instr,
    input   wire[31:0]                  i_bus_data,
    input   wire[31:0]                  i_mem_addr,
    input   wire[3:0]                   i_mem_sel,
    input   wire[31:0]                  i_mem_data,
    input   wire[31:0]                  i_reg_data,
    input   wire                        i_reg_write,
    input   wire                        i_mem_write,
    input   wire                        i_mem_read,
    input   wire                        i_exec2_flush,
    input   wire                        i_exec2_stall,
    input   wire                        i_exec2_ready,
    input   wire                        i_exec_flush,
    input   wire                        i_exec_stall,
    input   wire                        i_write_flush,
    input   wire                        i_write_stall,
    output  wire[4:0]                   o_rd,
    input   wire[31:0]                  i_rd
);

/* verilator lint_off BLKSEQ */

    logic[31:0] r_instr_exec;
    logic[IADDR_SPACE_BITS-1:0] r_pc_exec;
    logic       r_reg_write_exec, r_mem_write_exec, r_mem_read_exec;
    logic[31:0] r_instr_exec2;
    logic[IADDR_SPACE_BITS-1:0] r_pc_exec2;
    logic       r_reg_write_exec2, r_mem_write_exec2, r_mem_read_exec2;
    logic[31:0] r_instr_wr, r_wdata_wr, r_wdata_wr2, r_addr_wr, r_addr_wr2;
    logic[IADDR_SPACE_BITS-1:0] r_pc_wr;
    logic[3:0]  r_sel_wr, r_sel_wr2;
    logic       r_reg_write_wr, r_mem_write_wr, r_mem_read_wr;

    int f;

    function static real get_ts();
        real ts = $time();
        return ts / 1000.0;
    endfunction

    function static void print_head();
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
        $fwrite(f, "| %8s | %8s | %8s | %-53s |\n", "Time", "PC", "Opcode", "Instruction/Event");
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "", "", "Trace started.");
    endfunction

    function static void print_event(input string str);
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "",  "", str);
    endfunction

    function static string reg_number(input logic[4:0] idx);
        string str;
        str.itoa(idx);
        return {"r", str};
    endfunction

    function static string data_masked(input logic[31:0] data);
        string nb0, nb1, nb2, nb3;
        string hw0, hw1;
        string word;
        nb0.hextoa(data[ 7: 0]);
        nb1.hextoa(data[15: 8]);
        nb2.hextoa(data[23:16]);
        nb3.hextoa(data[31:24]);
        hw0.hextoa(data[15: 0]);
        hw1.hextoa(data[31:16]);
        word.hextoa(data);
        case (r_sel_wr)
        4'b0001:    return { "---", nb0, "(---", data[7:0], ")" };
        4'b0010:    return { "--", nb1, "-", "(--", data[15:8], "-)" };
        4'b0100:    return { "-", nb2, "--", "(-", data[23:16], "--)" };
        4'b1000:    return { nb3, "---", "(", data[31:24], "---)" };
        4'b0011:    return { "--", hw0, "(--", data[15:0], ")" };
        4'b1100:    return { hw1, "--", "(", data[31:16], "--)" };
        4'b1111:    return { word, "(", data, ")" };
        default:    return "INVALID_SEL";
        endcase
    endfunction

    function static string rdata_masked();
        return data_masked(i_bus_data);
    endfunction

    function static string wdata_masked();
        return data_masked(r_wdata_wr);
    endfunction

/* verilator lint_off UNUSEDSIGNAL */
    function static string decode_instr_load(input logic[31:0] instr);
        string instr_str, offset;
        case (instr[14:12])
        0:  instr_str = "lb";
        1:  instr_str = "lh";
        2:  instr_str = "lw";
        3:  instr_str = "ERROR";
        4:  instr_str = "lbu";
        5:  instr_str = "lhu";
        6:  instr_str = "ERROR";
        default:  instr_str = "ERROR";
        endcase
        offset.itoa(signed'(instr[31:20]));
        return {instr_str, " ", reg_number(instr[11:7]), ", ", offset,
                "(", reg_number(instr[19:15]), ")"};
    endfunction

    function static string decode_instr_arif_imm(input logic[31:0] instr);
        int imm;
        string imm_str, op;
        case (instr[14:12])
        0:  op = "addi";
        1:  op = "slli";
        2:  op = "slti";
        3:  op = "sltiu";
        4:  op = "xori";
        5:  op = ((instr[31:25]==32) ? "srai" : "srli");
        6:  op = "ori";
        default:  op = "andi";
        endcase
        imm = signed'({ {21{instr[31]}}, instr[30:20] });
        imm_str.itoa(imm);
        return { op, " ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]), ", ", imm_str};
    endfunction

    function static string decode_instr_auipc(input logic[31:0] instr);
        int imm;
        string value;
        imm = { instr[31:12], {12{1'b0}} };
        imm += { {(32-IADDR_SPACE_BITS){1'b0}}, r_pc_wr };
        value.hextoa(imm);
        return { "auipc ", reg_number(instr[11:7]), ", 0x", value};
    endfunction

    function static string decode_instr_store(input logic[31:0] instr);
        string instr_str, offset;
        case (instr[14:12])
        0:  instr_str = "sb";
        1:  instr_str = "sh";
        2:  instr_str = "sw";
        default:instr_str = "ERROR";
        endcase
        offset.itoa(signed'({ {21{instr[31]}}, instr[30:25], instr[11:7] }));
        return {instr_str, " ", reg_number(instr[24:20]), ", ", offset,
                "(", reg_number(instr[19:15]), ")"};
    endfunction

    function static string decode_instr_arif_reg(input logic[31:0] instr);
        string op;
        if (instr[25] == 1'b0)
        begin
            case (instr[14:12])
            0:  op = ((instr[31:25]==32) ? "sub" : "add");
            1:  op = ((instr[31:25]==32) ? "UNDEFINED" : "sll");
            2:  op = ((instr[31:25]==32) ? "UNDEFINED" : "slt");
            3:  op = ((instr[31:25]==32) ? "UNDEFINED" : "sltu");
            4:  op = ((instr[31:25]==32) ? "UNDEFINED" : "xor");
            5:  op = ((instr[31:25]==32) ? "sra" : "srl");
            6:  op = ((instr[31:25]==32) ? "UNDEFINED" : "or");
            default:  op = ((instr[31:25]==32) ? "UNDEFINED" : "and");
            endcase
        end
        else
        begin
            case (instr[14:12])
            0:  op = "mul";
            1:  op = "mulh";
            2:  op = "mulhsu";
            3:  op = "mulhu";
            4:  op = "div";
            5:  op = "divu";
            6:  op = "rem";
            default:  op = "remu";
            endcase
        end
        return { op, " ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]),
                ", ", reg_number(instr[24:20])};
    endfunction

    function static string decode_instr_lui(input logic[31:0] instr);
        string imm;
        imm.hextoa({ instr[31:12], {12{1'b0}} });
        return { "lui ", reg_number(instr[11:7]), ", 0x", imm};
    endfunction

    function static string decode_instr_branch(input logic[31:0] instr);
        int imm;
        string imm_str, op;
        case (instr[14:12])
        0:  op = "beq";
        1:  op = "bne";
        4:  op = "blt";
        5:  op = "bge";
        6:  op = "bltu";
        default:  op = "bgeu";
        endcase
        imm = signed'( { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0 });
        imm_str.hextoa({ {(32-IADDR_SPACE_BITS){1'b0}}, r_pc_wr } + imm);
        return { op, " ", reg_number(instr[19:15]), ", ",
                reg_number(instr[24:20]), ", 0x", imm_str};
    endfunction

    function static string decode_instr_jalr(input logic[31:0] instr);
        int offset;
        string offset_str;
        offset = signed'({ {21{instr[31]}}, instr[30:20] });
        offset_str.itoa(offset);
        return {"jalr ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]), ", ", offset_str};
    endfunction

    function static string decode_instr_jal(input logic[31:0] instr);
        int offset;
        string offset_str;
        offset = signed'({ {12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 });
        offset_str.hextoa({ {(32-IADDR_SPACE_BITS){1'b0}}, r_pc_wr } + offset);
        return {"jal ", reg_number(instr[11:7]), ", 0x", offset_str};
    endfunction

    function static string decode_instr_system(input logic[31:0] instr);
        string op, idx, imm;
        idx.itoa(instr[31:20]);
        imm.itoa(instr[19:15]);
        case (instr[14:12])
        0:  begin
                case (instr[31:20])
                0:      op = "ecall";
                1:      op = "ebreak";
                770:    op = "mret";
                default:op = "UNDEFINED";
                endcase
            end
        1:  op = { "csrrw ",  reg_number(instr[11:7]), ", ", idx, ", ", reg_number(instr[19:15]) };
        2:  op = { "csrrs ",  reg_number(instr[11:7]), ", ", idx, ", ", reg_number(instr[19:15]) };
        3:  op = { "csrrc ",  reg_number(instr[11:7]), ", ", idx, ", ", reg_number(instr[19:15]) };
        5:  op = { "csrrwi ", reg_number(instr[11:7]), ", ", idx, ", ", imm };
        6:  op = { "csrrsi ", reg_number(instr[11:7]), ", ", idx, ", ", imm };
        default:  op = { "csrrci ", reg_number(instr[11:7]), ", ", idx, ", ", imm };
        endcase
        return op;
    endfunction
/* verilator lint_on UNUSEDSIGNAL */

    function static string decode_instr_full(input logic[31:0] instr);
        case (instr[6:2])
        0:  return decode_instr_load(instr);
        4:  return decode_instr_arif_imm(instr);
        5:  return decode_instr_auipc(instr);
        8:  return decode_instr_store(instr);
        12: return decode_instr_arif_reg(instr);
        13: return decode_instr_lui(instr);
        24: return decode_instr_branch(instr);
        25: return decode_instr_jalr(instr);
        27: return decode_instr_jal(instr);
        28: return decode_instr_system(instr);
        default: return "----------";
        endcase
    endfunction

    function static string decode_instr(input logic[31:0] instr);
        case (instr[1:0])
        /*2'b00: $finish;
        2'b01: $finish;
        2'b10: $finish;*/
        2'b11: return decode_instr_full(instr);
        //default: $display("Invalid instruction type! %t\n", $time);
        default return "";
        endcase
    endfunction

    function static void print_decode(input logic[31:0] addr, input logic[31:0] instr,
                               input logic[IADDR_SPACE_BITS-1:0] pc,
                               input logic mem_read, input logic mem_write);
        string reg_op, mem_op, addr_str, opcode;
        string instr_str;
        instr_str = decode_instr(instr);
        addr_str.hextoa(addr);
        opcode.hextoa(instr);
        if (r_reg_write_wr)
        begin
            string data_str, data_str_old;
            data_str.hextoa(i_reg_data);
            data_str_old.hextoa(i_rd);
            reg_op = { reg_number(instr[11:7]), ": 0x", data_str_old, "<=0x", data_str };
        end
        $fwrite(f, "|%8.3fns|0x%08x|0x%-8s| %-24s %-28s |\n", get_ts(),
                pc, opcode, instr_str, reg_op);
        if (mem_read)
        begin
            mem_op = { "MemRd: 0x", addr_str, "=0x", rdata_masked() };
            $fwrite(f, "|%10s|%10s|%10s| %53s |\n", "", "", "", mem_op);
        end
        if (mem_write)
        begin
            mem_op = { "MemWr: 0x", addr_str, "=0x", wdata_masked() };
            $fwrite(f, "|%10s|%10s|%10s| %53s |\n", "", "", "", mem_op);
        end
    endfunction

    logic   r_reset_prev;
    logic   w_reset_falling, w_reset_rising;

    assign  w_reset_falling =   r_reset_prev  & (!i_reset_n);
    assign  w_reset_rising  = (!r_reset_prev) &   i_reset_n;

    always_ff @(posedge i_clk)
    begin
        r_reset_prev <= i_reset_n;
        if (w_reset_falling)
            print_event("Reset de-asserted");
        if (w_reset_rising)
            print_event("Reset asserted");
        if (|r_instr_wr & !i_write_stall)
            print_decode(r_addr_wr, r_instr_wr, r_pc_wr, r_mem_read_wr, r_mem_write_wr);
    end

    always_ff @(posedge i_clk)
    begin
        if (i_exec_flush)
        begin
            r_pc_exec <= '0;
            r_instr_exec <= '0;
            r_reg_write_exec <= '0;
            r_mem_write_exec <= '0;
            r_mem_read_exec <= '0;
        end
        else if (!i_exec_stall)
        begin
            r_pc_exec <= { i_pc,1'b0 };
            r_instr_exec <= i_instr;
            r_reg_write_exec <= i_reg_write;
            r_mem_write_exec <= i_mem_write;
            r_mem_read_exec <= i_mem_read;
        end
    end

    always_ff @(posedge i_clk)
    begin
        if (i_exec2_flush)
        begin
            r_pc_exec2 <= '0;
            r_instr_exec2 <= '0;
            r_reg_write_exec2 <= '0;
            r_mem_write_exec2 <= '0;
            r_mem_read_exec2 <= '0;
        end
        else if (i_exec2_ready & !i_exec2_stall)
        begin
            r_pc_exec2 <= r_pc_exec;
            r_instr_exec2 <= r_instr_exec;
            r_reg_write_exec2 <= r_reg_write_exec;
            r_mem_write_exec2 <= r_mem_write_exec;
            r_mem_read_exec2 <= r_mem_read_exec;
            r_addr_wr2 <= i_mem_addr;
            r_sel_wr2 <= i_mem_sel;
            r_wdata_wr2 <= i_mem_data;
        end
    end

    always_ff @(posedge i_clk)
    begin
        if (i_write_flush)
        begin
            r_pc_wr <= '0;
            r_instr_wr <= '0;
            r_reg_write_wr <= '0;
            r_mem_write_wr <= '0;
            r_mem_read_wr <= '0;
        end
        else if (!i_write_stall)
        begin
            r_pc_wr <= r_pc_exec2;
            r_instr_wr <= r_instr_exec2;
            r_reg_write_wr <= r_reg_write_exec2;
            r_mem_write_wr <= r_mem_write_exec2;
            r_mem_read_wr <= r_mem_read_exec2;
            r_wdata_wr <= r_wdata_wr2;
            r_addr_wr <= r_addr_wr2;
            r_sel_wr <= r_sel_wr2;
        end
    end

    initial
    begin
        f = $fopen("./trace.txt", "w");
        print_head();
        //
        r_instr_exec = '0;
        r_reg_write_exec = '0;
        r_mem_write_exec = '0;
        r_mem_read_exec = '0;
        //
        r_instr_exec2 = '0;
        r_reg_write_exec2 = '0;
        r_mem_write_exec2 = '0;
        r_mem_read_exec2 = '0;
        //
        r_instr_wr = '0;
        r_reg_write_wr = '0;
        r_mem_write_wr = '0;
        r_mem_read_wr = '0;
    end

    logic[4:0]  rd;
    assign      rd = r_instr_wr[11:7];

`ifdef TO_SIM
    final
    begin
        if (|r_instr_wr)
            print_decode(r_addr_wr, r_instr_wr, r_pc_wr, r_mem_read_wr, r_mem_write_wr);
        rd = r_instr_exec2[11:7];
        if (|r_instr_exec2)
            print_decode(i_mem_addr, r_instr_exec2, r_pc_exec2, r_mem_read_exec2,
                r_mem_write_exec2);
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "", "", "Trace finished.");
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
    end
`endif

    assign  o_rd = rd;

/* verilator lint_on  BLKSEQ */

endmodule
