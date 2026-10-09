
module fifo_sva #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input logic clk,
    input logic rst,
    input logic full,
    input logic empty,
    input logic [$clog2(DEPTH+1)-1:0] count,
    input logic [((DEPTH > 1) ? $clog2(DEPTH) : 1)-1:0] wr_ptr,
    input logic [((DEPTH > 1) ? $clog2(DEPTH) : 1)-1:0] rd_ptr
);

    // Property 1: empty must agree with occupancy.
    property p_empty_matches_count;
        @(posedge clk)
        disable iff (rst)
        empty == (count == 0);
    endproperty

    a_empty_matches_count:
        assert property (p_empty_matches_count)
        else $error("SVA FAILED: empty/count mismatch");

    // Property 2: full must agree with occupancy.
    property p_full_matches_count;
        @(posedge clk)
        disable iff (rst)
        full == (count == DEPTH);
    endproperty

    a_full_matches_count:
        assert property (p_full_matches_count)
        else $error("SVA FAILED: full/count mismatch");

    // Property 3: occupancy must stay within capacity.
    property p_count_in_range;
        @(posedge clk)
        disable iff (rst)
        count <= DEPTH;
    endproperty

    a_count_in_range:
        assert property (p_count_in_range)
        else $error("SVA FAILED: occupancy out of range");

    // Property 4: both pointers must address valid entries.
    property p_pointers_in_range;
        @(posedge clk)
        disable iff (rst)
        (wr_ptr < DEPTH) && (rd_ptr < DEPTH);
    endproperty

    a_pointers_in_range:
        assert property (p_pointers_in_range)
        else $error("SVA FAILED: pointer out of range");

endmodule