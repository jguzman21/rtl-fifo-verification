
module fifo_assertions #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input logic clk,
    input logic rst,

    input logic full,
    input logic empty,
    input logic [DATA_WIDTH-1:0] rd_data,

    input logic [$clog2(DEPTH+1)-1:0] count,
    input logic [((DEPTH > 1) ? $clog2(DEPTH) : 1)-1:0] wr_ptr,
    input logic [((DEPTH > 1) ? $clog2(DEPTH) : 1)-1:0] rd_ptr
);

    integer assertion_errors = 0;

    // Sample the registered state after the rising clock edge.
    always @(posedge clk) begin
        #1;

        if (rst) begin
            // Reset must clear the FIFO's state.
            assert (count == 0)
            else begin
                $error("ASSERTION FAILED: count not zero after reset");
                assertion_errors = assertion_errors + 1;
            end

            assert (empty && !full)
            else begin
                $error("ASSERTION FAILED: incorrect flags after reset");
                assertion_errors = assertion_errors + 1;
            end

            assert (wr_ptr == 0 && rd_ptr == 0)
            else begin
                $error("ASSERTION FAILED: pointers not reset");
                assertion_errors = assertion_errors + 1;
            end
        end else begin
            // Occupancy must never exceed capacity.
            assert (count <= DEPTH)
            else begin
                $error("ASSERTION FAILED: occupancy out of range");
                assertion_errors = assertion_errors + 1;
            end

            // Status flags must agree with occupancy.
            assert (empty == (count == 0))
            else begin
                $error("ASSERTION FAILED: empty/count mismatch");
                assertion_errors = assertion_errors + 1;
            end

            assert (full == (count == DEPTH))
            else begin
                $error("ASSERTION FAILED: full/count mismatch");
                assertion_errors = assertion_errors + 1;
            end

            // Pointers must address valid memory entries.
            assert (wr_ptr < DEPTH)
            else begin
                $error("ASSERTION FAILED: write pointer out of range");
                assertion_errors = assertion_errors + 1;
            end

            assert (rd_ptr < DEPTH)
            else begin
                $error("ASSERTION FAILED: read pointer out of range");
                assertion_errors = assertion_errors + 1;
            end
        end
    end

endmodule