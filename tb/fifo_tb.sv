
`timescale 1ns/1ps

module fifo_tb;

    // Match the default FIFO configuration.
    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 4;

    logic clk = 0;
    logic rst = 0;

    logic wr_en = 0;
    logic [DATA_WIDTH-1:0] wr_data = 0;

    logic rd_en = 0;
    logic [DATA_WIDTH-1:0] rd_data;

    logic full;
    logic empty;

    // Device under test (DUT).
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    // Independent assertion checker.
    fifo_assertions #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) assertions (
        .clk(clk),
        .rst(rst),
        .full(full),
        .empty(empty),
        .rd_data(rd_data),
        .count(dut.count),
        .wr_ptr(dut.wr_ptr),
        .rd_ptr(dut.rd_ptr)
    );

    `ifdef USE_SVA
        ifo_sva sva_checker (
            .clk(clk),
            .rst(rst),
            .count(dut.count),
            .wr_ptr(dut.wr_ptr),
            .rd_ptr(dut.rd_ptr),
            .empty(dut.empty),
            .full(dut.full)
        );
    `endif

    // Generate a 10 ns clock period.
    always #5 clk = ~clk;

    // Reference model: a software queue implemented as an array.
    logic [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    integer model_wr_ptr = 0;
    integer model_rd_ptr = 0;
    integer model_count  = 0;

    integer tests_passed = 0;
    integer errors = 0;

    logic accept_write;
    logic accept_read;
    logic [DATA_WIDTH-1:0] expected_data;

    // Execute one transaction and compare DUT against the model.
    task automatic transact(
        input logic write_request,
        input logic read_request,
        input logic [DATA_WIDTH-1:0] write_value
    );
        begin
            // Drive inputs away from the active clock edge.
            @(negedge clk);
            wr_en = write_request;
            rd_en = read_request;
            wr_data = write_value;

            // Determine which operations the DUT will accept.
            #1;
            accept_write = write_request && !full;
            accept_read  = read_request && !empty;

            if (accept_read)
                expected_data = model_mem[model_rd_ptr];

            // Let the DUT process the transaction.
            @(posedge clk);

            // Update the reference model using accepted operations.
            if (accept_read) begin
                model_rd_ptr =
                    (model_rd_ptr == DEPTH-1) ? 0 : model_rd_ptr + 1;
            end

            if (accept_write) begin
                model_mem[model_wr_ptr] = write_value;
                model_wr_ptr =
                    (model_wr_ptr == DEPTH-1) ? 0 : model_wr_ptr + 1;
            end

            model_count = model_count + accept_write - accept_read;

            // Allow nonblocking assignments in the DUT to settle.
            #1;

            // Verify the DUT occupancy against the reference model.
            if (dut.count !== model_count) begin
                $display(
                    "FAIL: expected count=%0d, got=%0d",
                    model_count, dut.count
            );
            errors = errors + 1;
            end

            if (empty !== (model_count == 0)) begin
                $display("FAIL: empty flag incorrect");
                errors = errors + 1;
            end

            if (full !== (model_count == DEPTH)) begin
                $display("FAIL: full flag incorrect");
                errors = errors + 1;
            end

            if (accept_read && rd_data !== expected_data) begin
                $display(
                    "FAIL: expected data=%h, got=%h",
                    expected_data, rd_data
                );
                errors = errors + 1;
            end

            if (accept_read && rd_data === expected_data) begin
                tests_passed = tests_passed + 1;
            end

            if (!accept_read && !accept_write)
                tests_passed = tests_passed + 1;

            // Deassert requests before the next transaction.
            wr_en = 0;
            rd_en = 0;
        end
    endtask

    integer i;
    integer operation;
    integer random_data;

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, fifo_tb);

        $display("Starting FIFO verification...");

        // Reset the DUT and reference model.
        rst = 1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        model_wr_ptr = 0;
        model_rd_ptr = 0;
        model_count  = 0;

        #1;
        if (empty !== 1'b1 || full !== 1'b0) begin
            $display("FAIL: incorrect flags after reset");
            errors = errors + 1;
        end else begin
            $display("PASS: reset");
            tests_passed = tests_passed + 1;
        end

        // Test 1: read while empty should be rejected.
        transact(0, 1, 8'h00);
        $display("Completed empty-read test");

        // Test 2: write and read a single value.
        transact(1, 0, 8'hA5);
        transact(0, 1, 8'h00);
        $display("Completed single-item test");

        // Test 3: verify FIFO ordering.
        transact(1, 0, 8'h11);
        transact(1, 0, 8'h22);
        transact(1, 0, 8'h33);

        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        $display("Completed ordering test");

        // Test 4: fill the FIFO and reject an extra write.
        transact(1, 0, 8'h40);
        transact(1, 0, 8'h41);
        transact(1, 0, 8'h42);
        transact(1, 0, 8'h43);

        if (full !== 1'b1) begin
            $display("FAIL: FIFO did not become full");
            errors = errors + 1;
        end else begin
            $display("PASS: FIFO full condition");
            tests_passed = tests_passed + 1;
        end

        transact(1, 0, 8'hFF);
        $display("Completed overflow test");

        // Test 5: drain the FIFO and reject an extra read.
        repeat (DEPTH)
            transact(0, 1, 8'h00);

        if (empty !== 1'b1) begin
            $display("FAIL: FIFO did not become empty");
            errors = errors + 1;
        end else begin
            $display("PASS: FIFO empty condition");
            tests_passed = tests_passed + 1;
        end

        transact(0, 1, 8'h00);
        $display("Completed underflow test");

        
        // Test 6A: simultaneous read/write while EMPTY.
        // Read is rejected; write is accepted.
        $display("Test 6A: simultaneous read/write while empty");

        transact(1, 1, 8'h50);

        if (model_count != 1) begin
            $display("FAIL: empty boundary should leave 1 item");
            errors = errors + 1;
        end else begin
            $display("PASS: empty boundary occupancy");
            tests_passed = tests_passed + 1;
        end

        // The newly written item must be readable next.
        transact(0, 1, 8'h00);

        // Test 6B: simultaneous read/write while PARTIALLY FULL.
        // Both operations are accepted; occupancy stays at 2.
        $display("Test 6B: simultaneous read/write while partially full");

        transact(1, 0, 8'h51);
        transact(1, 0, 8'h52);
        transact(1, 1, 8'h53);

        if (model_count != 2) begin
            $display("FAIL: partial boundary should leave 2 items");
            errors = errors + 1;
        end else begin
            $display("PASS: partial boundary occupancy");
            tests_passed = tests_passed + 1;
        end

        // Check that the original second item and new item remain ordered.
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);

        // Test 6C: simultaneous read/write while FULL.
        // Read is accepted; write is rejected by our FIFO policy.
        $display("Test 6C: simultaneous read/write while full");

        transact(1, 0, 8'h60);
        transact(1, 0, 8'h61);
        transact(1, 0, 8'h62);
        transact(1, 0, 8'h63);

        if (full !== 1'b1) begin
            $display("FAIL: setup for full boundary failed");
            errors = errors + 1;
        end else begin
            $display("PASS: full boundary setup");
            tests_passed = tests_passed + 1;
        end

        transact(1, 1, 8'hFF);

        if (model_count != DEPTH - 1) begin
            $display("FAIL: full boundary should leave 3 items");
            errors = errors + 1;
        end else begin
            $display("PASS: full boundary occupancy");
            tests_passed = tests_passed + 1;
        end

        // The rejected 8'hFF write must not replace the queued data.
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);

        $display("Completed all simultaneous boundary tests");
        // Test 7: deterministic randomized traffic.
        for (i = 0; i < 200; i = i + 1) begin
            operation = $urandom_range(0, 3);
            random_data = $urandom_range(0, 255);

            case (operation)
                0: transact(1, 0, random_data);
                1: transact(0, 1, 0);
                2: transact(1, 1, random_data);
                3: transact(0, 0, 0);
            endcase
        end

        // Drain remaining data to verify ordering.
        while (model_count > 0)
            transact(0, 1, 0);

        $display("");
        $display("================================");
        $display("Tests passed: %0d", tests_passed);
        $display("Errors:       %0d", errors);
        $display("================================");

        if (errors == 0) begin
            $display("ALL CHECKS PASSED");
        end else begin
            $display("VERIFICATION FAILED");
            $fatal(1, "FIFO testbench detected errors");
        end

        $finish;
    end

endmodule