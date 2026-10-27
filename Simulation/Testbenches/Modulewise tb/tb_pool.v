`timescale 1ns / 1ps

module tb_max_pool;

    reg clk;
    reg reset;
    reg valid_in;
    reg [7:0] pixel_in;

    wire valid_out;
    wire [7:0] pixel_out;

    integer x;
    integer y;
    integer count;
    integer errors;

    reg [7:0] expected_value;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    max_pool #(
        .WIDTH(30),
        .HEIGHT(30)
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
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
    // Send pixel
    // ------------------------------------------------------------

    task send_pixel;
        input [7:0] value;

        begin

            @(negedge clk);

            valid_in = 1'b1;
            pixel_in = value;

            @(negedge clk);

            valid_in = 1'b0;
            pixel_in = 8'd0;

        end
    endtask

    // ------------------------------------------------------------
    // Monitor output
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (valid_out) begin

            count = count + 1;

            // ----------------------------------------------------
            // Our test image is:
            //
            // pixel(x,y) = y*30+x
            //
            // modulo 256 because pixel is 8-bit.
            //
            // First pooling window:
            //
            // 0   1
            // 30  31
            //
            // max = 31
            // ----------------------------------------------------

            if (count == 1) begin

                expected_value = 8'd31;

                if (pixel_out !== expected_value) begin

                    $display(
                        "ERROR: First pool output. Expected %0d, got %0d",
                        expected_value,
                        pixel_out
                    );

                    errors = errors + 1;

                end
                else begin

                    $display(
                        "PASS: First pool output = %0d",
                        pixel_out
                    );

                end
            end

            // ----------------------------------------------------
            // Second output:
            //
            // 2 3
            // 32 33
            //
            // max = 33
            // ----------------------------------------------------

            if (count == 2) begin

                if (pixel_out !== 8'd33) begin

                    $display(
                        "ERROR: Second pool output. Expected 33, got %0d",
                        pixel_out
                    );

                    errors = errors + 1;

                end
                else begin

                    $display("PASS: Second pool output = 33.");
                end
            end

            // ----------------------------------------------------
            // Final output
            //
            // x = 28,29
            // y = 28,29
            //
            // values:
            //
            // 868 869
            // 898 899
            //
            // modulo 256:
            //
            // 100 101
            // 130 131
            //
            // max = 131
            // ----------------------------------------------------

            if (count == 225) begin

                if (pixel_out !== 8'd131) begin

                    $display(
                        "ERROR: Last pool output. Expected 131, got %0d",
                        pixel_out
                    );

                    errors = errors + 1;

                end
                else begin

                    $display(
                        "PASS: Last pool output = %0d",
                        pixel_out
                    );

                end
            end
        end
    end

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    initial begin

        reset    = 1'b1;
        valid_in = 1'b0;
        pixel_in = 8'd0;

        count  = 0;
        errors = 0;

        repeat (5)
            @(posedge clk);

        reset = 1'b0;

        // --------------------------------------------------------
        // Send 30x30 feature map
        // --------------------------------------------------------

        for (y = 0; y < 30; y = y + 1) begin

            for (x = 0; x < 30; x = x + 1) begin

                send_pixel((y * 30 + x) & 8'hFF);

            end
        end

        repeat (10)
            @(posedge clk);

        // --------------------------------------------------------
        // Final count check
        // --------------------------------------------------------

        if (count != 225) begin

            $display(
                "ERROR: Expected 225 pool outputs, got %0d",
                count
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: Exactly 225 pooling outputs generated."
            );

        end

        if (errors == 0) begin

            $display("======================================");
            $display("MAX POOL TEST PASS");
            $display("======================================");

        end
        else begin

            $display("======================================");
            $display("MAX POOL TEST FAIL");
            $display("Errors = %0d", errors);
            $display("======================================");

        end

        $finish;
    end

endmodule