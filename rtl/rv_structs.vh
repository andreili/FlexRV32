`ifndef __RV_STRUCTS__
`define __RV_STRUCTS__

typedef struct packed
{
    logic                   memory;
    logic                   pc_next;
    // always latest - it's default
    logic                   alu;
} res_src_t;

typedef struct packed
{
    logic       add_override;
    logic       sh_ar;
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
    logic   reg_f;
} ctrl_rs_bp_t;

typedef struct packed
{
    logic   external;
    logic   timer;
    logic   soft_;
} int_csr_t;

`endif // __RV_STRUCTS__
