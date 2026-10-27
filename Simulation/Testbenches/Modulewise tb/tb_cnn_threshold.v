`timescale 1ns / 1ps

// ================================================================
// VAJRA DRISHTI
// CNN THRESHOLD FINDER
//
// Tests the actual vajra_top CNN with:
//
//   1. All-background ROI
//   2. Exact target ROI
//   3. All-bright ROI
//
// Current dense decision:
//
//   target_locked = (score > THRESHOLD)
//
// This test determines whether a useful threshold exists.
// ================================================================

module tb_cnn_threshold;

    // ============================================================
    // PARAMETERS
    // ============================================================

    localparam integer ROI_SIZE   = 32;
    localparam integer ROI_PIXELS = 1024;

    localparam [7:0] BG_VALUE     = 8'h10;
    localparam [7:0] TARGET_VALUE = 8'hE0;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;

    initial
        clk = 1'b0;

    always #5 clk = ~clk;

    // ============================================================
    // CNN INPUT
    // ============================================================

    reg       valid_in;
    reg [7:0] pixel_in;

    // ============================================================
    // CNN OUTPUTS
    //
    // IMPORTANT:
    // vajra_top DOES NOT have valid_out.
    // ============================================================

    wire        done;
    wire        target_locked;
    wire [31:0] final_sum;

    // ============================================================
    // DUT
    // ============================================================

    vajra_top dut (

        .clk(clk),
        .reset(reset),

        .valid_in(valid_in),
        .pixel_in(pixel_in),

        .done(done),
        .target_locked(target_locked),
        .final_sum(final_sum)

    );

    // ============================================================
    // SCORE STORAGE
    // ============================================================

    integer background_score;
    integer target_score;
    integer bright_score;

    integer threshold_low;
    integer threshold_high;
    integer recommended_threshold;

    // ============================================================
    // TEST CONTROL
    // ============================================================

    integer timeout_count;

    integer errors;

    // ============================================================
    // FEED ONE PIXEL
    // ============================================================

    task feed_pixel;

        input [7:0] pixel;

        begin

            @(posedge clk);

            valid_in <= 1'b1;
            pixel_in <= pixel;

        end

    endtask

    // ============================================================
    // STOP INPUT
    // ============================================================

    task stop_input;

        begin

            @(posedge clk);

            valid_in <= 1'b0;
            pixel_in <= 8'h00;

        end

    endtask

    // ============================================================
    // WAIT FOR CNN DONE
    // ============================================================

    task wait_for_cnn_done;

        begin

            timeout_count = 0;

            while ((!done) &&
                   (timeout_count < 100000)) begin

                @(posedge clk);

                timeout_count = timeout_count + 1;

            end

            if (!done) begin

                $display("");
                $display("ERROR: CNN TIMEOUT");
                $display("");

                errors = errors + 1;

            end

        end

    endtask

    // ============================================================
    // RESET CNN
    // ============================================================

    task reset_cnn;

        begin

            reset = 1'b1;

            valid_in = 1'b0;
            pixel_in = 8'h00;

            repeat (10)
                @(posedge clk);

            reset = 1'b0;

            repeat (5)
                @(posedge clk);

        end

    endtask

    // ============================================================
    // TEST 1
    //
    // ALL BACKGROUND
    //
    // 1024 x 10h
    // ============================================================

    task run_background;

        integer i;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 1 : ALL BACKGROUND");
            $display("============================================================");
            $display("");

            reset_cnn();

            for (i = 0; i < ROI_PIXELS; i = i + 1) begin

                feed_pixel(BG_VALUE);

            end

            stop_input();

            wait_for_cnn_done();

            if (done) begin

                background_score = $signed(final_sum);

                $display("");
                $display("BACKGROUND RESULT");
                $display("----------------------------");
                $display("Score HEX = %08h", final_sum);
                $display("Score DEC = %0d", background_score);
                $display("Locked    = %0d", target_locked);
                $display("");

            end

        end

    endtask

    // ============================================================
    // TEST 2
    //
    // EXACT TARGET ROI
    //
    // 32x32 ROI
    //
    // Target occupies:
    //
    // local X = 1..31
    // local Y = 1..31
    //
    // Therefore:
    //
    // 31 x 31 = 961 target pixels
    // 63 background pixels
    // ============================================================

    task run_target;

        integer tx;
        integer ty;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 2 : EXACT TARGET ROI");
            $display("============================================================");
            $display("");

            $display("ROI size       = 32 x 32");
            $display("Target pixels  = 961");
            $display("Background     = 63");
            $display("");

            reset_cnn();

            for (ty = 0; ty < ROI_SIZE; ty = ty + 1) begin

                for (tx = 0; tx < ROI_SIZE; tx = tx + 1) begin

                    if ((tx >= 1) && (tx <= 31) &&
                        (ty >= 1) && (ty <= 31)) begin

                        feed_pixel(TARGET_VALUE);

                    end
                    else begin

                        feed_pixel(BG_VALUE);

                    end

                end

            end

            stop_input();

            wait_for_cnn_done();

            if (done) begin

                target_score = $signed(final_sum);

                $display("");
                $display("TARGET RESULT");
                $display("----------------------------");
                $display("Score HEX = %08h", final_sum);
                $display("Score DEC = %0d", target_score);
                $display("Locked    = %0d", target_locked);
                $display("");

            end

        end

    endtask

    // ============================================================
    // TEST 3
    //
    // ALL BRIGHT
    //
    // 1024 x E0
    // ============================================================

    task run_bright;

        integer i;

        begin

            $display("");
            $display("============================================================");
            $display("TEST 3 : ALL BRIGHT");
            $display("============================================================");
            $display("");

            reset_cnn();

            for (i = 0; i < ROI_PIXELS; i = i + 1) begin

                feed_pixel(TARGET_VALUE);

            end

            stop_input();

            wait_for_cnn_done();

            if (done) begin

                bright_score = $signed(final_sum);

                $display("");
                $display("ALL-BRIGHT RESULT");
                $display("----------------------------");
                $display("Score HEX = %08h", final_sum);
                $display("Score DEC = %0d", bright_score);
                $display("Locked    = %0d", target_locked);
                $display("");

            end

        end

    endtask

    // ============================================================
    // MAIN
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // INITIALIZATION
        // --------------------------------------------------------

        reset    = 1'b1;
        valid_in = 1'b0;
        pixel_in = 8'h00;

        background_score = 0;
        target_score     = 0;
        bright_score     = 0;

        threshold_low  = 0;
        threshold_high = 0;
        recommended_threshold = 0;

        errors = 0;

        // --------------------------------------------------------
        // HEADER
        // --------------------------------------------------------

        $display("");
        $display("");
        $display("################################################################");
        $display("#                                                              #");
        $display("#                 VAJRA DRISHTI                                #");
        $display("#              CNN THRESHOLD FINDER                            #");
        $display("#                                                              #");
        $display("################################################################");
        $display("");
        $display("CNN input = 32 x 32 = 1024 pixels");
        $display("");
        $display("Background = 10h");
        $display("Target     = E0h");
        $display("");
        $display("Current decision:");
        $display("");
        $display("       target_locked = (score > THRESHOLD)");
        $display("");
        $display("################################################################");

        // --------------------------------------------------------
        // INITIAL RESET
        // --------------------------------------------------------

        repeat (20)
            @(posedge clk);

        reset = 1'b0;

        repeat (10)
            @(posedge clk);

        // ========================================================
        // TEST 1
        // ========================================================

        run_background();

        // ========================================================
        // TEST 2
        // ========================================================

        run_target();

        // ========================================================
        // TEST 3
        // ========================================================

        run_bright();

        // ========================================================
        // SCORE SUMMARY
        // ========================================================

        $display("");
        $display("");
        $display("################################################################");
        $display("#                    SCORE SUMMARY                             #");
        $display("################################################################");
        $display("");

        $display("BACKGROUND = %0d", background_score);
        $display("TARGET     = %0d", target_score);
        $display("ALL BRIGHT = %0d", bright_score);

        $display("");

        // ========================================================
        // DETERMINE WHETHER THRESHOLD CAN WORK
        // ========================================================

        if (target_score > background_score) begin

            // ----------------------------------------------------
            // TARGET IS ABOVE BACKGROUND
            //
            // Since:
            //
            // target_locked = score > threshold
            //
            // we need:
            //
            // background <= threshold < target
            // ----------------------------------------------------

            threshold_low = background_score;

            threshold_high = target_score - 1;

            recommended_threshold =
                (threshold_low + threshold_high) / 2;

            $display("============================================================");
            $display("A VALID THRESHOLD EXISTS");
            $display("============================================================");
            $display("");

            $display("Target score is HIGHER than background score.");
            $display("");

            $display("Valid threshold range:");
            $display("");

            $display("LOW  = %0d", threshold_low);
            $display("HIGH = %0d", threshold_high);

            $display("");

            $display("Recommended threshold = %0d",
                     recommended_threshold);

            $display("");

            // ----------------------------------------------------
            // CHECK CURRENT THRESHOLD
            // ----------------------------------------------------

            $display("CURRENT THRESHOLD = -150000");
            $display("");

            if (background_score > -150000)

                $display(
                    "Background -> TARGET"
                );

            else

                $display(
                    "Background -> NOT TARGET"
                );


            if (target_score > -150000)

                $display(
                    "Target -> TARGET"
                );

            else

                $display(
                    "Target -> NOT TARGET"
                );


            if (bright_score > -150000)

                $display(
                    "All Bright -> TARGET"
                );

            else

                $display(
                    "All Bright -> NOT TARGET"
                );

            $display("");

        end

        // ========================================================
        // TARGET BELOW BACKGROUND
        // ========================================================

        else if (target_score < background_score) begin

            $display("============================================================");
            $display("NO VALID THRESHOLD WITH CURRENT COMPARATOR");
            $display("============================================================");
            $display("");

            $display("Target score     = %0d", target_score);
            $display("Background score = %0d", background_score);
            $display("");

            $display("Current comparator:");
            $display("");
            $display("    score > THRESHOLD");
            $display("");

            $display("Because target < background, no threshold");
            $display("can simultaneously reject background and");
            $display("accept target.");
            $display("");

            $display("This DOES NOT automatically mean retraining.");
            $display("");

            $display("Next things to investigate:");
            $display("1. CNN signed arithmetic");
            $display("2. CNN feature-map values");
            $display("3. CNN weights");
            $display("4. Serializer ordering");
            $display("5. Dense weights");
            $display("6. Decision direction");
            $display("");

            errors = errors + 1;

        end

        // ========================================================
        // EQUAL
        // ========================================================

        else begin

            $display("============================================================");
            $display("TARGET AND BACKGROUND SCORES ARE IDENTICAL");
            $display("============================================================");
            $display("");

            $display("Threshold cannot solve this.");

            errors = errors + 1;

        end

        // ========================================================
        // BRIGHTNESS CHECK
        // ========================================================

        $display("");
        $display("################################################################");
        $display("#                  BRIGHTNESS CHECK                            #");
        $display("################################################################");
        $display("");

        if (target_score > background_score) begin

            if (bright_score > recommended_threshold) begin

                $display("WARNING:");
                $display("All-bright ROI ALSO classifies as TARGET.");
                $display("");
                $display("The CNN may be responding primarily to");
                $display("pixel brightness rather than target structure.");
                $display("");

            end
            else begin

                $display("PASS:");
                $display("All-bright ROI does not cross the recommended threshold.");
                $display("");

            end

        end

        // ========================================================
        // FINAL REPORT
        // ========================================================

        $display("");
        $display("");
        $display("################################################################");
        $display("#                       FINAL REPORT                           #");
        $display("################################################################");
        $display("");

        $display("Background score = %0d", background_score);
        $display("Target score     = %0d", target_score);
        $display("Bright score     = %0d", bright_score);

        $display("");

        if (target_score > background_score) begin

            $display("CONCLUSION:");
            $display("");
            $display("The CNN DOES have target/background score separation.");
            $display("");
            $display("Retraining is NOT required just to choose a threshold.");
            $display("");
            $display("Recommended starting threshold = %0d",
                     recommended_threshold);
            $display("");

        end
        else begin

            $display("CONCLUSION:");
            $display("");
            $display("Threshold alone cannot solve the classification.");
            $display("");
            $display("Do NOT retrain yet.");
            $display("We should inspect the existing CNN implementation");
            $display("and weights first.");
            $display("");

        end

        $display("Errors = %0d", errors);

        $display("");
        $display("################################################################");

        $finish;

    end

endmodule