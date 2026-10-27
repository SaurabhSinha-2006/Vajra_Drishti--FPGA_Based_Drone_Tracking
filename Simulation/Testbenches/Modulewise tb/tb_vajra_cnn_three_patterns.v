`timescale 1ns / 1ps

// ============================================================
// VAJRA DRISHTI
// CNN NUMERICAL BEHAVIOUR TEST
//
// This testbench DIRECTLY tests vajra_top.
//
// It intentionally removes:
//   - UART
//   - frame buffer
//   - motion detector
//   - ROI extractor
//   - ROI BRAM
//   - CNN controller
//
// We feed exactly 1024 pixels directly into the CNN.
//
// TESTS:
//
//   TEST 1:
//       1024 x 0x10
//       Expected: background-only response
//
//   TEST 2:
//       1024 x 0xE0
//       Expected: bright/full response
//
//   TEST 3:
//       Exact ROI from full-system test:
//
//       Source target:
//           x = 304..335
//           y = 224..255
//
//       Extracted ROI:
//           x = 303..334
//           y = 223..254
//
//       Therefore:
//           961 x 0xE0
//            63 x 0x10
//
// This test will tell us whether the CNN numerical pipeline
// responds sensibly to different input patterns.
// ============================================================

module tb_vajra_cnn_three_patterns;

    // ========================================================
    // CONSTANTS
    // ========================================================

    localparam integer ROI_PIXELS = 1024;

    localparam [7:0] BACKGROUND = 8'h10;
    localparam [7:0] TARGET     = 8'hE0;

    // ========================================================
    // CLOCK / RESET
    // ========================================================

    reg clk;
    reg reset;

    // ========================================================
    // CNN INPUT
    // ========================================================

    reg        valid_in;
    reg [7:0]  pixel_in;

    // ========================================================
    // CNN OUTPUT
    // ========================================================

    wire       done;
    wire       target_locked;
    wire [31:0] final_sum;

    // ========================================================
    // TEST VARIABLES
    // ========================================================

    integer i;
    integer errors;

    integer timeout_count;

    integer score1;
    integer score2;
    integer score3;

    reg lock1;
    reg lock2;
    reg lock3;

    // ========================================================
    // DUT
    // ========================================================

    vajra_top cnn (
        .clk(clk),
        .reset(reset),

        .valid_in(valid_in),
        .pixel_in(pixel_in),

        .done(done),
        .target_locked(target_locked),
        .final_sum(final_sum)
    );

    // ========================================================
    // CLOCK
    // ========================================================

    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;       // 100 MHz

    // ========================================================
    // HELPER TASK:
    // RESET CNN
    // ========================================================

    task reset_cnn;
        begin

            reset    = 1'b1;
            valid_in = 1'b0;
            pixel_in = 8'h00;

            repeat (10)
                @(posedge clk);

            reset = 1'b0;

            repeat (5)
                @(posedge clk);

        end
    endtask

    // ========================================================
    // HELPER TASK:
    // WAIT FOR DONE
    // ========================================================

    task wait_for_done;

        begin

            timeout_count = 0;

            while ((done !== 1'b1) &&
                   (timeout_count < 100000)) begin

                @(posedge clk);

                timeout_count = timeout_count + 1;

            end

            if (done !== 1'b1) begin

                $display("");
                $display("############################################################");
                $display("ERROR: CNN TIMEOUT");
                $display("############################################################");
                $display("CNN did not assert done.");
                $display("Timeout cycles = %0d", timeout_count);
                $display("############################################################");

                errors = errors + 1;

            end

        end

    endtask

    // ========================================================
    // TEST 1
    //
    // ALL BACKGROUND
    //
    // 1024 x 0x10
    // ========================================================

    task test_background;

        begin

            $display("");
            $display("============================================================");
            $display(" TEST 1: ALL BACKGROUND");
            $display("============================================================");
            $display("Pixels = 1024");
            $display("Value  = 0x10");
            $display("============================================================");

            reset_cnn();

            // ------------------------------------------------
            // Feed 1024 pixels
            // ------------------------------------------------

            for (i = 0; i < ROI_PIXELS; i = i + 1) begin

                @(posedge clk);

                valid_in = 1'b1;
                pixel_in = BACKGROUND;

            end

            // Stop input
            @(posedge clk);

            valid_in = 1'b0;
            pixel_in = 8'h00;

            // ------------------------------------------------
            // Wait for CNN completion
            // ------------------------------------------------

            wait_for_done();

            // Give output one extra clock to settle
            @(posedge clk);

            score1 = $signed(final_sum);
            lock1  = target_locked;

            // ------------------------------------------------
            // Report
            // ------------------------------------------------

            $display("");
            $display("--------------- TEST 1 RESULT ----------------");
            $display("DONE          = %0d", done);
            $display("TARGET_LOCKED = %0d", lock1);
            $display("FINAL_SUM HEX = %08h", final_sum);
            $display("FINAL_SUM DEC = %0d", score1);
            $display("-----------------------------------------------");

        end

    endtask

    // ========================================================
    // TEST 2
    //
    // ALL BRIGHT
    //
    // 1024 x 0xE0
    // ========================================================

    task test_all_bright;

        begin

            $display("");
            $display("============================================================");
            $display(" TEST 2: ALL BRIGHT");
            $display("============================================================");
            $display("Pixels = 1024");
            $display("Value  = 0xE0");
            $display("============================================================");

            reset_cnn();

            // ------------------------------------------------
            // Feed 1024 pixels
            // ------------------------------------------------

            for (i = 0; i < ROI_PIXELS; i = i + 1) begin

                @(posedge clk);

                valid_in = 1'b1;
                pixel_in = TARGET;

            end

            // Stop input
            @(posedge clk);

            valid_in = 1'b0;
            pixel_in = 8'h00;

            // ------------------------------------------------
            // Wait for CNN completion
            // ------------------------------------------------

            wait_for_done();

            @(posedge clk);

            score2 = $signed(final_sum);
            lock2  = target_locked;

            // ------------------------------------------------
            // Report
            // ------------------------------------------------

            $display("");
            $display("--------------- TEST 2 RESULT ----------------");
            $display("DONE          = %0d", done);
            $display("TARGET_LOCKED = %0d", lock2);
            $display("FINAL_SUM HEX = %08h", final_sum);
            $display("FINAL_SUM DEC = %0d", score2);
            $display("-----------------------------------------------");

        end

    endtask

    // ========================================================
    // TEST 3
    //
    // EXACT ROI FROM FULL UART SYSTEM
    //
    // ROI:
    //
    //   row 0:       all 0x10
    //   rows 1..31:
    //       col 0  = 0x10
    //       col 1..31 = 0xE0
    //
    // Therefore:
    //
    //   31 x 31 = 961 target pixels
    //   1024 - 961 = 63 background pixels
    // ========================================================

    task test_actual_roi;

        integer row;
        integer col;

        begin

            $display("");
            $display("============================================================");
            $display(" TEST 3: ACTUAL FULL-SYSTEM ROI");
            $display("============================================================");
            $display("ROI = 32 x 32");
            $display("Target pixels     = 961");
            $display("Background pixels = 63");
            $display("============================================================");

            reset_cnn();

            // ------------------------------------------------
            // Feed exact ROI
            // ------------------------------------------------

            for (row = 0; row < 32; row = row + 1) begin

                for (col = 0; col < 32; col = col + 1) begin

                    @(posedge clk);

                    valid_in = 1'b1;

                    // Top row is background
                    // Left column is background
                    //
                    // Everything else is target.

                    if ((row >= 1) &&
                        (row <= 31) &&
                        (col >= 1) &&
                        (col <= 31))

                        pixel_in = TARGET;

                    else

                        pixel_in = BACKGROUND;

                end

            end

            // Stop input
            @(posedge clk);

            valid_in = 1'b0;
            pixel_in = 8'h00;

            // ------------------------------------------------
            // Wait for CNN completion
            // ------------------------------------------------

            wait_for_done();

            @(posedge clk);

            score3 = $signed(final_sum);
            lock3  = target_locked;

            // ------------------------------------------------
            // Report
            // ------------------------------------------------

            $display("");
            $display("--------------- TEST 3 RESULT ----------------");
            $display("DONE          = %0d", done);
            $display("TARGET_LOCKED = %0d", lock3);
            $display("FINAL_SUM HEX = %08h", final_sum);
            $display("FINAL_SUM DEC = %0d", score3);
            $display("-----------------------------------------------");

        end

    endtask

    // ========================================================
    // MAIN TEST
    // ========================================================

    initial begin

        errors = 0;

        clk = 1'b0;

        reset    = 1'b1;
        valid_in = 1'b0;
        pixel_in = 8'h00;

        // ----------------------------------------------------
        // Banner
        // ----------------------------------------------------

        $display("");
        $display("");
        $display("############################################################");
        $display(" VAJRA DRISHTI - CNN THREE PATTERN TEST");
        $display("############################################################");
        $display("");
        $display("This test directly drives vajra_top.");
        $display("");
        $display("TEST 1 = 1024 x 0x10");
        $display("TEST 2 = 1024 x 0xE0");
        $display("TEST 3 = 961 x 0xE0 + 63 x 0x10");
        $display("");
        $display("############################################################");

        // ----------------------------------------------------
        // Run tests
        // ----------------------------------------------------

        test_background();

        test_all_bright();

        test_actual_roi();

        // ----------------------------------------------------
        // FINAL COMPARISON
        // ----------------------------------------------------

        $display("");
        $display("");
        $display("############################################################");
        $display(" FINAL CNN COMPARISON");
        $display("############################################################");

        $display("");
        $display("TEST 1 - ALL BACKGROUND");
        $display("    SCORE = %0d", score1);
        $display("    LOCK  = %0d", lock1);

        $display("");
        $display("TEST 2 - ALL BRIGHT");
        $display("    SCORE = %0d", score2);
        $display("    LOCK  = %0d", lock2);

        $display("");
        $display("TEST 3 - ACTUAL ROI");
        $display("    SCORE = %0d", score3);
        $display("    LOCK  = %0d", lock3);

        $display("");
        $display("############################################################");
        $display(" SCORE DIFFERENCES");
        $display("############################################################");

        $display("TEST2 - TEST1 = %0d", score2 - score1);
        $display("TEST3 - TEST1 = %0d", score3 - score1);
        $display("TEST3 - TEST2 = %0d", score3 - score2);

        $display("");
        $display("LOCK THRESHOLD = -150000");

        // ----------------------------------------------------
        // Basic sanity checks
        // ----------------------------------------------------

        if (score1 == score2) begin

            $display("");
            $display("WARNING:");
            $display("ALL-BACKGROUND and ALL-BRIGHT produced");
            $display("the SAME score.");
            $display("");
            $display("This is highly suspicious and needs");
            $display("immediate CNN datapath investigation.");

        end
        else begin

            $display("");
            $display("PASS:");
            $display("CNN output changes when input changes.");

        end

        // ----------------------------------------------------
        // Final
        // ----------------------------------------------------

        $display("");
        $display("############################################################");

        if (errors == 0) begin
            $display(" CNN THREE-PATTERN TEST COMPLETED");
        end
        else begin
            $display(" CNN THREE-PATTERN TEST FAILED");
            $display(" Errors = %0d", errors);
        end

        $display("############################################################");
        $display("");

        $finish;

    end

endmodule