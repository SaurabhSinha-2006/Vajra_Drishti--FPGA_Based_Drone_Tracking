`timescale 1ns / 1ps

module tb_serializer;

    reg clk;
    reg reset;
    reg valid_in;

    reg [7:0] p0;
    reg [7:0] p1;
    reg [7:0] p2;
    reg [7:0] p3;

    wire valid_out;
    wire [7:0] pixel_out;

    integer batch;
    integer output_count;
    integer errors;

    reg [7:0] expected_pixel;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    serializer #(
        .FIFO_DEPTH(128)
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),

        .p0(p0),
        .p1(p1),
        .p2(p2),
        .p3(p3),

        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------

    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Send one batch
    // ------------------------------------------------------------

    task send_batch;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        input [7:0] d;

        begin

            @(negedge clk);

            valid_in = 1'b1;

            p0 = a;
            p1 = b;
            p2 = c;
            p3 = d;

            @(negedge clk);

            valid_in = 1'b0;

            p0 = 8'd0;
            p1 = 8'd0;
            p2 = 8'd0;
            p3 = 8'd0;

        end
    endtask

    // ------------------------------------------------------------
    // Check every output
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (valid_out) begin

            expected_pixel =
                output_count[7:0];

            if (pixel_out !== expected_pixel) begin

                $display(
                    "ERROR: Output %0d: expected %0d, got %0d",
                    output_count,
                    expected_pixel,
                    pixel_out
                );

                errors = errors + 1;

            end

            output_count = output_count + 1;

        end
    end

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    initial begin

        reset = 1'b1;

        valid_in = 1'b0;

        p0 = 0;
        p1 = 0;
        p2 = 0;
        p3 = 0;

        batch = 0;
        output_count = 0;
        errors = 0;

        repeat (5)
            @(posedge clk);

        reset = 1'b0;

        // --------------------------------------------------------
        // Send 225 batches.
        //
        // Batch 0:
        //   0 1 2 3
        //
        // Batch 1:
        //   4 5 6 7
        //
        // ...
        //
        // Batch 224:
        //   128 129 130 131
        //
        // Values intentionally wrap at 255.
        // --------------------------------------------------------

        for (batch = 0; batch < 225; batch = batch + 1) begin

            send_batch(
                (batch * 4 + 0) & 8'hFF,
                (batch * 4 + 1) & 8'hFF,
                (batch * 4 + 2) & 8'hFF,
                (batch * 4 + 3) & 8'hFF
            );

        end

        // Give serializer enough time to drain FIFO.
        //
        // Maximum backlog is significant because producer
        // is faster than consumer.
        repeat (1000)
            @(posedge clk);

        // --------------------------------------------------------
        // Final check
        // --------------------------------------------------------

        if (output_count != 900) begin

            $display(
                "ERROR: Expected 900 output pixels, got %0d",
                output_count
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: Exactly 900 serializer outputs generated."
            );

        end

        if (errors == 0) begin

            $display("======================================");
            $display("SERIALIZER TEST PASS");
            $display("900/900 pixels correct");
            $display("======================================");

        end
        else begin

            $display("======================================");
            $display("SERIALIZER TEST FAIL");
            $display("Errors = %0d", errors);
            $display("======================================");

        end

        $finish;
    end

endmodule