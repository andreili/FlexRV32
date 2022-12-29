`define SLAVE_SEL_WIDTH                 4
`define TCM_ADDR_WIDTH                  13

//`define BRANCH_PREDICTION_SIMPLE

typedef struct packed
{
    logic                   memory;
    logic                   pc_p4;
    // always latest - it's default
    logic                   alu;
} res_src_t;

typedef struct packed
{
    logic                   i;
    logic                   u;
    logic                   j;
    logic                   s;
    // always latest - it's default
    logic                   r;
} src_op2_t;

typedef struct packed
{
    logic                   pc;
    // always latest - it's default
    logic                   r;
} src_op1_t;

typedef struct packed
{
    logic                   res_cmp;
    logic                   res_bits;
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
