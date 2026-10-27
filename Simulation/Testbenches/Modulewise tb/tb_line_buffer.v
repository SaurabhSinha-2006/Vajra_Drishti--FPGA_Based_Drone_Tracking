`timescale 1ns / 1ps

module tb_line_buffer;

    reg clk;
    reg reset;
    reg valid_in;
    reg [7:0] pixel_in;

    wire valid_out;
    wire [71:0] window_out;

    integer x;
    integer y;
    integer count;
    integer errors;

    // ============================================================
    // DUT
    // ============================================================

    line_buffer #(
        .WIDTH(32)
    ) dut (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (valid_in),
        .pixel_in   (pixel_in),
        .valid_out  (valid_out),
        .window_out (window_out)
    );

    // ============================================================
    // Clock
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Send one pixel
    // ============================================================

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

    // ============================================================
    // Monitor valid windows
    // ============================================================

    always @(posedge clk) begin

        if (valid_out) begin

            count = count + 1;

            // ----------------------------------------------------
            // First valid 3x3 window
            //
            // Input image:
            //
            // row 0:  0   1   2
            // row 1: 32  33  34
            // row 2: 64  65  66
            //
            // Therefore:
            //
            // window =
            //
            //  0   1   2
            // 32  33  34
            // 64  65  66
            // ----------------------------------------------------

            if (count == 1) begin

                if (window_out !== {
                    8'd0,   8'd1,   8'd2,
                    8'd32,  8'd33,  8'd34,
                    8'd64,  8'd65,  8'd66
                }) begin

                    $display("ERROR: First 3x3 window is WRONG.");

                    $display(
                        "Got = %02h %02h %02h / %02h %02h %02h / %02h %02h %02h",
                        window_out[71:64],
                        window_out[63:56],
                        window_out[55:48],
                        window_out[47:40],
                        window_out[39:32],
                        window_out[31:24],
                        window_out[23:16],
                        window_out[15:8],
                        window_out[7:0]
                    );

                    errors = errors + 1;

                end
                else begin

                    $display("PASS: First 3x3 window is correct.");

                end
            end

            // ----------------------------------------------------
            // Second valid window
            //
            // At x=3, y=2:
            //
            //  1   2   3
            // 33  34  35
            // 65  66  67
            // ----------------------------------------------------

            if (count == 2) begin

                if (window_out !== {
                    8'd1,   8'd2,   8'd3,
                    8'd33,  8'd34,  8'd35,
                    8'd65,  8'd66,  8'd67
                }) begin

                    $display("ERROR: Second 3x3 window is WRONG.");

                    errors = errors + 1;

                end
                else begin

                    $display("PASS: Second 3x3 window is correct.");

                end
            end

            // ----------------------------------------------------
            // 30th window of first valid row
            //
            // x = 31, y = 2
            //
            // 29  30  31
            // 61  62  63
            // 93  94  95
            // ----------------------------------------------------

            if (count == 30) begin

                if (window_out !== {
                    8'd29,  8'd30,  8'd31,
                    8'd61,  8'd62,  8'd63,
                    8'd93,  8'd94,  8'd95
                }) begin

                    $display("ERROR: 30th 3x3 window is WRONG.");

                    errors = errors + 1;

                end
                else begin

                    $display("PASS: Last window of first valid row correct.");

                end
            end

            // ----------------------------------------------------
            // Final valid window
            //
            // x = 31, y = 31
            //
            // 957  958  959
            // 989  990  991
            //1021 1022 1023
            //
            // Since pixel is 8-bit, values wrap:
            //
            // 957  = 189
            // 958  = 190
            // 959  = 191
            //
            // 989  = 221
            // 990  = 222
            // 991  = 223
            //
            //1021  = 253
            //1022  = 254
            //1023  = 255
            // ----------------------------------------------------

            if (count == 900) begin

                if (window_out !== {
                    8'd189, 8'd190, 8'd191,
                    8'd221, 8'd222, 8'd223,
                    8'd253, 8'd254, 8'd255
                }) begin

                    $display("ERROR: Final 3x3 window is WRONG.");

                    $display(
                        "Got = %02h %02h %02h / %02h %02h %02h / %02h %02h %02h",
                        window_out[71:64],
                        window_out[63:56],
                        window_out[55:48],
                        window_out[47:40],
                        window_out[39:32],
                        window_out[31:24],
                        window_out[23:16],
                        window_out[15:8],
                        window_out[7:0]
                    );

                    errors = errors + 1;

                end
                else begin

                    $display("PASS: Final 3x3 window is correct.");

                end
            end
        end
    end

    // ============================================================
    // Main test
    // ============================================================

    initial begin

        reset    = 1'b1;
        valid_in = 1'b0;
        pixel_in = 8'd0;

        count  = 0;
        errors = 0;

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        repeat (5)
            @(posedge clk);

        reset = 1'b0;

        // --------------------------------------------------------
        // Send complete 32x32 image
        //
        // Pixel value = y*32+x
        // --------------------------------------------------------

        for (y = 0; y < 32; y = y + 1) begin

            for (x = 0; x < 32; x = x + 1) begin

                send_pixel(
                    (y * 32 + x) & 8'hFF
                );

            end
        end

        // --------------------------------------------------------
        // Allow final output to propagate
        // --------------------------------------------------------

        repeat (10)
            @(posedge clk);

        // --------------------------------------------------------
        // Check number of windows
        // --------------------------------------------------------

        if (count != 900) begin

            $display(
                "ERROR: Expected 900 valid windows, got %0d",
                count
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: Exactly 900 valid 3x3 windows generated."
            );

        end

        // --------------------------------------------------------
        // Final result
        // --------------------------------------------------------

        if (errors == 0) begin

            $display("");
            $display("========================================");
            $display("LINE BUFFER TEST PASS");
            $display("========================================");
            $display("900/900 windows generated correctly.");
            $display("");

        end
        else begin

            $display("");
            $display("========================================");
            $display("LINE BUFFER TEST FAIL");
            $display("Errors = %0d", errors);
            $display("========================================");
            $display("");

        end

        $finish;

    end

endmodule