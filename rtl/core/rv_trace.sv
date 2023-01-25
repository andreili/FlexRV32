`timescale 1ps/1ps

`include "../rv_defines.vh"

module rv_trace
(
    input   wire                        i_clk,
    input   wire                        i_reset_n,
    input   wire[31:0]                  i_pc,
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
    input   wire                        i_exec_flush,
    output  wire[4:0]                   o_rd,
    input   wire[31:0]                  i_rd
);

    logic[31:0] r_instr_exec, r_pc_exec;
    logic       r_reg_write_exec, r_mem_write_exec, r_mem_read_exec;
    logic[31:0] r_instr_exec2, r_pc_exec2;
    logic       r_reg_write_exec2, r_mem_write_exec2, r_mem_read_exec2;
    logic[31:0] r_instr_mem, r_pc_mem, r_wdata_mem, r_addr_mem;
    logic[3:0]  r_sel_mem;
    logic       r_reg_write_mem, r_mem_write_mem, r_mem_read_mem;
    logic[31:0] r_instr_wr, r_pc_wr, r_wdata_wr, r_addr_wr, r_rdata_wr;
    logic[3:0]  r_sel_wr;
    logic       r_reg_write_wr, r_mem_write_wr, r_mem_read_wr;

    int f;

    function real get_ts;
        real ts = $time;
        return ts / 1000.0;
    endfunction

    function void print_head;
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
        $fwrite(f, "| %8s | %8s | %8s | %-53s |\n", "Time", "PC", "Opcode", "Instruction/Event");
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "", "", "Trace started.");
    endfunction

    function void print_event(input string str);
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "",  "", str);
    endfunction

    function string reg_number(input [4:0] idx);
        string str;
        str.itoa(idx);
        return {"r", str};
    endfunction

    function string data_masked(input[31:0] data);
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

    function string rdata_masked();
        return data_masked(r_rdata_wr);
    endfunction

    function string wdata_masked();
        return data_masked(r_wdata_wr);
    endfunction

/* verilator lint_off UNUSEDSIGNAL */
    function string decode_instr_load(input[31:0] instr);
        string instr_str, offset;
        case (instr[14:12])
        0:  instr_str = "lb";
        1:  instr_str = "lh";
        2:  instr_str = "lw";
        3:  instr_str = "ERROR";
        4:  instr_str = "lbu";
        5:  instr_str = "lhu";
        6:  instr_str = "ERROR";
        7:  instr_str = "ERROR";
        endcase
        offset.itoa(signed'(instr[31:20]));
        return {instr_str, " ", reg_number(instr[11:7]), ", ", offset, "(", reg_number(instr[19:15]), ")"};
    endfunction

    function string decode_instr_arif_imm(input[31:0] instr);
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
        7:  op = "andi";
        endcase
        imm = signed'({ {21{instr[31]}}, instr[30:20] });
        imm_str.itoa(imm);
        return { op, " ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]), ", ", imm_str};
    endfunction

    function string decode_instr_auipc(input[31:0] instr);
        int imm;
        string value;
        imm = { instr[31:12], {12{1'b0}} };
        imm += r_pc_wr;
        value.hextoa(imm);
        return { "auipc ", reg_number(instr[11:7]), ", 0x", value};
    endfunction

    function string decode_instr_store(input[31:0] instr);
        string instr_str, offset;
        case (instr[14:12])
        0:  instr_str = "sb";
        1:  instr_str = "sh";
        2:  instr_str = "sw";
        default:instr_str = "ERROR";
        endcase
        offset.itoa(signed'({ {21{instr[31]}}, instr[30:25], instr[11:7] }));
        return {instr_str, " ", reg_number(instr[24:20]), ", ", offset, "(", reg_number(instr[19:15]), ")"};
    endfunction

    function string decode_instr_arif_reg(input[31:0] instr);
        string op;
        case (instr[14:12])
        0:  op = ((instr[31:25]==32) ? "sub" : "add");
        1:  op = ((instr[31:25]==32) ? "UNDEFINED" : "sll");
        2:  op = ((instr[31:25]==32) ? "UNDEFINED" : "slt");
        3:  op = ((instr[31:25]==32) ? "UNDEFINED" : "sltu");
        4:  op = ((instr[31:25]==32) ? "UNDEFINED" : "xor");
        5:  op = ((instr[31:25]==32) ? "sra" : "srl");
        6:  op = ((instr[31:25]==32) ? "UNDEFINED" : "or");
        7:  op = ((instr[31:25]==32) ? "UNDEFINED" : "and");
        endcase
        return { op, " ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]), ", ", reg_number(instr[24:20])};
    endfunction

    function string decode_instr_lui(input[31:0] instr);
        string imm;
        imm.hextoa({ instr[31:12], {12{1'b0}} });
        return { "lui ", reg_number(instr[11:7]), ", 0x", imm};
    endfunction

    function string decode_instr_branch(input[31:0] instr);
        int imm;
        string imm_str, op;
        case (instr[14:12])
        0:  op = "beq";
        1:  op = "bne";
        4:  op = "blt";
        5:  op = "bge";
        6:  op = "bltu";
        7:  op = "bgeu";
        endcase
        imm = signed'( { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0 });
        imm_str.hextoa(r_pc_wr + imm);
        return { op, " ", reg_number(instr[19:15]), ", ", reg_number(instr[24:20]), ", 0x", imm_str};
    endfunction

    function string decode_instr_jalr(input[31:0] instr);
        int offset;
        string offset_str;
        offset = signed'({ {21{instr[31]}}, instr[30:20] });
        offset_str.itoa(offset);
        return {"jalr ", reg_number(instr[11:7]), ", ", reg_number(instr[19:15]), ", ", offset_str};
    endfunction

    function string decode_instr_jal(input[31:0] instr);
        int offset;
        string offset_str;
        offset = signed'({ {12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 });
        offset_str.hextoa(r_pc_wr + offset);
        return {"jal ", reg_number(instr[11:7]), ", 0x", offset_str};
    endfunction
/* verilator lint_on UNUSEDSIGNAL */

    function string decode_instr_full(input[31:0] instr);
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
        default: return "----------";
        endcase
    endfunction

    function string decode_instr(input[31:0] instr);
        case (instr[1:0])
        /*2'b00: $finish;
        2'b01: $finish;
        2'b10: $finish;*/
        2'b11: return decode_instr_full(instr);
        //default: $display("Invalid instruction type! %t\n", $time);
        default return "";
        endcase
    endfunction

    function void print_decode(input[31:0] addr, input[31:0] instr, input[31:0] pc, input mem_read, input mem_write);
        string reg_op, mem_op, addr_str, opcode;
        string instr_str = decode_instr(instr);
        addr_str.hextoa(addr);
        opcode.hextoa(instr);
        if (r_reg_write_wr)
        begin
            string data_str, data_str_old;
            data_str.hextoa(i_reg_data);
            data_str_old.hextoa(i_rd);
            reg_op = { reg_number(instr[11:7]), ": 0x", data_str_old, "<=0x", data_str };
        end
        $fwrite(f, "|%8.3fns|0x%08x|0x%-8s| %-24s %-28s |\n", get_ts(), pc, opcode, instr_str, reg_op);
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
        if (|r_instr_wr)
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
        else
        begin
            r_pc_exec <= i_pc;
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
        else
        begin
            r_pc_exec2 <= r_pc_exec;
            r_instr_exec2 <= r_instr_exec;
            r_reg_write_exec2 <= r_reg_write_exec;
            r_mem_write_exec2 <= r_mem_write_exec;
            r_mem_read_exec2 <= r_mem_read_exec;
        end
    end

    always_ff @(posedge i_clk)
    begin
        r_pc_mem <= r_pc_exec2;
        r_instr_mem <= r_instr_exec2;
        r_reg_write_mem <= r_reg_write_exec2;
        r_mem_write_mem <= r_mem_write_exec2;
        r_mem_read_mem <= r_mem_read_exec2;
        r_wdata_mem <= i_mem_data;
        r_addr_mem <= i_mem_addr;
        r_sel_mem <= i_mem_sel;
        //
        r_pc_wr <= r_pc_mem;
        r_instr_wr <= r_instr_mem;
        r_reg_write_wr <= r_reg_write_mem;
        r_mem_write_wr <= r_mem_write_mem;
        r_mem_read_wr <= r_mem_read_mem;
        r_wdata_wr <= r_wdata_mem;
        r_rdata_wr <= i_bus_data;
        r_addr_wr <= r_addr_mem;
        r_sel_wr <= r_sel_mem;
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
        r_instr_mem = '0;
        r_reg_write_mem = '0;
        r_mem_write_mem = '0;
        r_mem_read_mem = '0;
        //
        r_instr_wr = '0;
        r_reg_write_wr = '0;
        r_mem_write_wr = '0;
        r_mem_read_wr = '0;
    end

    logic[4:0]  rd;
    assign      rd = r_instr_wr[11:7];

    final
    begin
        if (|r_instr_wr)
            print_decode(r_addr_wr, r_instr_wr, r_pc_wr, r_mem_read_wr, r_mem_write_wr);
        rd = r_instr_mem[11:7];
        if (|r_instr_mem)
            print_decode(r_addr_mem, r_instr_mem, r_pc_mem, r_mem_read_mem, r_mem_write_mem);
        rd = r_instr_exec2[11:7];
        if (|r_instr_exec2)
            print_decode(i_mem_addr, r_instr_exec2, r_pc_exec2, r_mem_read_exec2, r_mem_write_exec2);
        $fwrite(f, "|%8.3fns|%10s|%10s| %-53s |\n", get_ts(), "", "", "Trace finished.");
        $fwrite(f, "+----------+----------+----------+-------------------------------------------------------+\n");
    end

    assign  o_rd = rd;

endmodule
