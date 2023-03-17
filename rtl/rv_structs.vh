

typedef struct packed
{
    logic                   memory;
    logic                   pc_next;
    // always latest - it's default
    logic                   alu;
} res_src_t;

typedef struct packed
{
    logic                   cmp;
    logic                   bits;
    logic                   shift;
    // always latest of result - it's default
    logic                   arith;
} alu_res_t;

typedef struct packed
{
    logic       add_override;
    logic       sh_ar;
    logic       op1_inv_or_ecmp_inv;
    logic       op2_inverse;
    logic       group_mux;
    logic       div_mux;
} alu_ctrl_t;

`define GRP_MUX_MULDIV 1'b1

typedef struct packed
{
    logic       start;
    logic       wait_op;
    logic       end_op;
} alu_state_t;

`define ALU_START 3'b100
`define ALU_WAIT  3'b010
`define ALU_END   3'b001

typedef struct packed
{
    logic   alu2;
    logic   write;
    logic   wr_back;
} ctrl_rs_bp_t;

typedef struct packed
{
    logic   enable_external;
    logic   enable_timer;
    logic   enable_soft;
} int_ctrl_csr_t;

typedef struct packed
{
    logic   pending_external;
    logic   pending_timer;
    logic   pending_soft;
} int_ctrl_state_csr_t;
