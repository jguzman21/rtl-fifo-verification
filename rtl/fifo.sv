
module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  full,
    output logic                  empty
);

    localparam int PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;
    logic [COUNT_WIDTH-1:0] count;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    logic do_write;
    logic do_read;

    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            rd_data <= '0;
        end else begin

            if (do_write) begin
                mem[wr_ptr] <= wr_data;

                if (wr_ptr == DEPTH - 1)
                    wr_ptr <= '0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            if (do_read) begin
                rd_data <= mem[rd_ptr];

                if (rd_ptr == DEPTH - 1)
                    rd_ptr <= '0;
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    initial begin
        if (DEPTH < 1)
            $fatal(1, "DEPTH must be at least 1");
        if (DATA_WIDTH < 1)
            $fatal(1, "DATA_WIDTH must be at least 1");
    end

endmodule