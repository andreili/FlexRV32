

typedef struct packed
{
    logic                   memory;
    logic                   pc_p4;
    // always latest - it's default
    logic                   alu;
} res_src_t;

typedef struct packed
{
    logic                   pc;
    // always latest - it's default
    logic                   r;
} src_op1_t;

typedef struct packed
{
    logic                   i;
    logic                   j;
`ifdef EXTENSION_C
    logic                   c;
`endif
    // always latest - it's default
    logic                   r;
} src_op2_t;

typedef struct packed
{
    logic                   res_cmp;
    logic                   res_bits;
    logic                   res_shift;
    // always latest of result - it's default
    logic                   res_arith;

    logic                   cmp_lts;
    logic                   cmp_ltu;
    // always latest of compare - it's default
    logic                   cmp_eq;
    logic                   cmp_inversed;

    logic                   bits_or;
    logic                   bits_xor;
    // always latest of bits - it's default
    logic                   bits_and;

    logic                   arith_shl;
    logic                   arith_shr;
    logic                   arith_sub;
    // always latest of arithmetical - it's default
    logic                   arith_add;
    logic                   shift_arithmetical;
} alu_ctrl_t;

typedef struct packed
{
    logic[31:0]             instruction;
    logic[31:0]             pc;
    logic                   ready;
} fetch_bus_t;

typedef struct packed
{
    logic[31:0]             pc;
    logic[4:0]              rs1;
    logic[4:0]              rs2;
    logic[4:0]              rd;
    logic[31:0]             imm_i;
    logic[31:0]             imm_j;
`ifdef EXTENSION_C
    logic[31:0]             imm_c;
`endif
    alu_ctrl_t              alu_ctrl;
    logic[2:0]              funct3;
    res_src_t               res_src;
    logic                   reg_write;
    src_op1_t               op1_src;
    src_op2_t               op2_src;
    logic                   inst_jalr;
    logic                   inst_jal;
    logic                   inst_branch;
    logic                   inst_store;
    logic                   inst_supported;
`ifdef EXTENSION_C
    logic                   inst_compressed;
`endif
} decode_bus_t;

typedef struct packed
{
    logic[31:0] op1;
    logic[31:0] op2;
    alu_ctrl_t  alu_ctrl;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic       inst_jal_jalr;
    logic       inst_branch;
    logic[31:0] pc;
    logic[31:0] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    logic[31:0] reg_data2;
`ifdef EXTENSION_C
    logic       compressed;
`endif
} alu1_bus_t;

typedef struct packed
{
    logic       cmp_result;
    logic       pc_select;
    logic[31:0] bits_result;
    logic[31:0] add;
    logic[31:0] shift_result;
    alu_ctrl_t  ctrl;
    logic       store;
    logic       reg_write;
    logic[4:0]  rd;
    logic[31:0] pc;
    logic[31:0] pc_target;
    res_src_t   res_src;
    logic[2:0]  funct3;
    logic[31:0] reg_data2;
`ifdef EXTENSION_C
    logic       compressed;
`endif
} alu2_bus_t;

/*typedef struct packed
{
    logic[31:0] alu_result;
    logic[31:0] pc;
    res_src_t   res_src;
    logic       reg_write;
    logic[4:0]  rd;
    logic[2:0]  funct3;
    logic       store;
    logic[31:0] reg_data2;
    logic[31:0] wdata;
    logic[3:0]  sel;
} memory_data_t;

typedef struct packed
{
    logic[31:0] alu_result;
    logic[31:0] pc;
    res_src_t   res_src;
    logic       reg_write;
    logic[4:0]  rd;
    logic[2:0]  funct3;
} write_data_t;*/
