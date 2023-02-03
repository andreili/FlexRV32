

typedef struct packed
{
    logic                   memory;
    logic                   pc_next;
    // always latest - it's default
    logic                   alu;
} res_src_t;

typedef struct packed
{
    logic                   pc;
    logic                   zero;
    // always latest - it's default
    logic                   r;
} src_op1_t;

typedef struct packed
{
    logic                   i;
    logic                   j;
    // always latest - it's default
    logic                   r;
} src_op2_t;

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
    logic   alu2;
    logic   memory;
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
