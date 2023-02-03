`timescale 1ps/1ps

module min_idx
#(
    parameter int ELEMENT_WIDTH         = 2,
    parameter int INDEX_WIDTH           = 2,
    parameter int ELEMENT_COUNT         = 2,
    parameter int DATA_SIZE             = (ELEMENT_WIDTH * ELEMENT_COUNT),
    parameter int INDEX_SIZE            = (INDEX_WIDTH   * ELEMENT_COUNT)
)
(
    input   wire[DATA_SIZE-1:0]         i_elements,
    input   wire[INDEX_SIZE-1:0]        i_idx,
    output  wire[ELEMENT_WIDTH-1:0]     o_min_val,
    output  wire[INDEX_WIDTH-1:0]       o_min_idx
);

    logic[ELEMENT_WIDTH-1:0] el0,  el1;
    logic[INDEX_WIDTH  -1:0] idx0, idx1;
    logic                    is_lo;

    generate
        if (ELEMENT_COUNT > 2)
        begin : g_tree
            localparam int HalfData = DATA_SIZE  / 2;
            localparam int HalfIdx  = INDEX_SIZE / 2;
            logic[HalfData-1:0] el_lo,  el_hi;
            logic[HalfIdx -1:0] idx_lo, idx_hi;

            assign el_lo  = i_elements[0*HalfData +: HalfData];
            assign el_hi  = i_elements[1*HalfData +: HalfData];
            assign idx_lo = i_idx     [0*HalfIdx  +: HalfIdx ];
            assign idx_hi = i_idx     [1*HalfIdx  +: HalfIdx ];

            min_idx
            #(
                .ELEMENT_WIDTH          (ELEMENT_WIDTH),
                .INDEX_WIDTH            (INDEX_WIDTH),
                .ELEMENT_COUNT          (ELEMENT_COUNT / 2)
            )
            u_min_lo
            (
                .i_elements             (el_lo),
                .i_idx                  (idx_lo),
                .o_min_val              (el0),
                .o_min_idx              (idx0)
            );

            min_idx
            #(
                .ELEMENT_WIDTH          (ELEMENT_WIDTH),
                .INDEX_WIDTH            (INDEX_WIDTH),
                .ELEMENT_COUNT          (ELEMENT_COUNT / 2)
            )
            u_min_hi
            (
                .i_elements             (el_hi),
                .i_idx                  (idx_hi),
                .o_min_val              (el1),
                .o_min_idx              (idx1)
            );
        end
        else
        begin : g_end
            assign el0  = i_elements[0*ELEMENT_WIDTH +: ELEMENT_WIDTH];
            assign el1  = i_elements[1*ELEMENT_WIDTH +: ELEMENT_WIDTH];
            assign idx0 = i_idx     [0*INDEX_WIDTH   +: INDEX_WIDTH  ];
            assign idx1 = i_idx     [1*INDEX_WIDTH   +: INDEX_WIDTH  ];
        end
    endgenerate

    assign  is_lo = (el0 < el1);
    assign  o_min_val = is_lo ? el0  : el1 ;
    assign  o_min_idx = is_lo ? idx0 : idx1;

endmodule
