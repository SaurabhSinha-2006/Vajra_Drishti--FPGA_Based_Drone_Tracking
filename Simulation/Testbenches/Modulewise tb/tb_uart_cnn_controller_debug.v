`timescale 1ns / 1ps

module tb_uart_cnn_controller_debug;

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam integer ROI_PIXELS = 1024;

    localparam [7:0] BG_PIXEL = 8'h10;
    localparam [7:0] TARGET_PIXEL = 8'hE0;

    // =========================================================
    // CLOCK / RESET
    // =========================================================

    reg clk;
    reg reset;
    reg start;

    // =========================================================
    // ROI BRAM WRITE
    // =========================================================

    reg        roi_write_en;
    reg [9:0]  roi_write_addr;
    reg [7:0]  roi_write_data;

    // =========================================================
    // ROI BRAM READ
    // =========================================================

    wire       roi_read_en;
    wire [9:0] roi_read_addr;
    wire [7:0] roi_read_data;

    // =========================================================
    // CNN CONTROLLER
    // =========================================================

    wire       cnn_reset;
    wire       cnn_valid;
    wire [7:0] cnn_pixel;

    wire       cnn_done;
    wire       result_seen;

    // =========================================================
    // CNN RESULT
    // =========================================================

    wire       cnn_locked;
    wire [31:0] cnn_score;

    // =========================================================
    // DEBUG VARIABLES
    // =========================================================

    integer errors;
    integer i;

    integer read_count;
    integer valid_count;

    integer e0_count;
    integer bg_count;
    integer other_count;

    reg cnn_done_seen;

    // =========================================================
    // CLOCK
    // =========================================================

    initial begin
        clk = 1'b0;
    end

    always begin
        #5 clk = ~clk;
    end

    // =========================================================
    // EXPECTED ROI FUNCTION
    //
    // Address 0..1023 corresponds to:
    //
    //     row = address / 32
    //     col = address % 32
    //
    // Target occupies rows 1..31 and columns 1..31.
    //
    // Therefore:
    //
    //     31 x 31 = 961 target pixels
    //     63 background pixels
    // =========================================================

    function [7:0] expected_pixel;
        input integer address;

        integer row;
        integer col;

        begin
            row = address / 32;
            col = address % 32;

            if ((row >= 1) &&
                (row <= 31) &&
                (col >= 1) &&
                (col <= 31)) begin

                expected_pixel = TARGET_PIXEL;

            end
            else begin

                expected_pixel = BG_PIXEL;

            end
        end
    endfunction

    // =========================================================
    // ROI BRAM
    // =========================================================

    roi_bram roi_memory (
        .clk(clk),
        .write_en(roi_write_en),
        .write_addr(roi_write_addr),
        .data_in(roi_write_data),
        .read_en(roi_read_en),
        .read_addr(roi_read_addr),
        .data_out(roi_read_data)
    );

    // =========================================================
    // CNN CONTROLLER
    // =========================================================

    uart_cnn_controller controller (
        .clk(clk),
        .reset(reset),
        .start(start),

        .cnn_reset(cnn_reset),

        .roi_read_en(roi_read_en),
        .roi_read_addr(roi_read_addr),
        .roi_read_data(roi_read_data),

        .cnn_valid(cnn_valid),
        .cnn_pixel(cnn_pixel),

        .cnn_done(cnn_done),
        .result_seen(result_seen)
    );

    // =========================================================
    // CNN
    // =========================================================

    vajra_top cnn (
        .clk(clk),
        .reset(cnn_reset),

        .valid_in(cnn_valid),
        .pixel_in(cnn_pixel),

        .done(cnn_done),
        .target_locked(cnn_locked),
        .final_sum(cnn_score)
    );

    // =========================================================
    // LOAD ROI BRAM
    // =========================================================

    task load_roi;

        integer n;

        begin

            $display("");
            $display("================================================");
            $display("STEP 1 - LOAD ROI BRAM");
            $display("================================================");

            roi_write_en = 1'b0;
            roi_write_addr = 10'd0;
            roi_write_data = 8'h00;

            for (n = 0; n < 1024; n = n + 1) begin

                @(posedge clk);

                roi_write_en = 1'b1;
                roi_write_addr = n;
                roi_write_data = expected_pixel(n);

            end

            @(posedge clk);

            roi_write_en = 1'b0;

            $display("ROI loaded.");
            $display("Expected E0 pixels = 961");
            $display("Expected 10 pixels = 63");

        end

    endtask

    // =========================================================
    // VERIFY BRAM
    // =========================================================

    task verify_roi;

        integer n;
        integer bad;

        begin

            $display("");
            $display("================================================");
            $display("STEP 2 - VERIFY ROI BRAM");
            $display("================================================");

            bad = 0;

            for (n = 0; n < 1024; n = n + 1) begin

                if (roi_memory.memory_array[n] !== expected_pixel(n)) begin

                    if (bad < 10) begin
                        $display(
                            "BRAM ERROR addr=%0d expected=%02h actual=%02h",
                            n,
                            expected_pixel(n),
                            roi_memory.memory_array[n]
                        );
                    end

                    bad = bad + 1;

                end

            end

            if (bad == 0) begin
                $display("PASS - all 1024 ROI locations correct.");
            end
            else begin
                $display("FAIL - %0d ROI locations incorrect.", bad);
                errors = errors + bad;
            end

        end

    endtask

    // =========================================================
    // MONITOR ROI READ ADDRESSES
    // =========================================================

    always @(posedge clk) begin

        if (roi_read_en) begin

            #1;

            if (read_count < 5) begin
                $display(
                    "READ %0d : address=%0d",
                    read_count,
                    roi_read_addr
                );
            end

            if (read_count > 1018) begin
                $display(
                    "READ %0d : address=%0d",
                    read_count,
                    roi_read_addr
                );
            end

            if (roi_read_addr != read_count) begin

                $display(
                    "ERROR - ROI address expected %0d but got %0d",
                    read_count,
                    roi_read_addr
                );

                errors = errors + 1;

            end

            read_count = read_count + 1;

        end

    end

    // =========================================================
    // MONITOR CNN INPUT
    // =========================================================

    always @(posedge clk) begin

        if (cnn_valid) begin

            #1;

            if (valid_count < 5) begin
                $display(
                    "CNN %0d : pixel=%02h expected=%02h",
                    valid_count,
                    cnn_pixel,
                    expected_pixel(valid_count)
                );
            end

            if (valid_count > 1018) begin
                $display(
                    "CNN %0d : pixel=%02h expected=%02h",
                    valid_count,
                    cnn_pixel,
                    expected_pixel(valid_count)
                );
            end

            if (cnn_pixel != expected_pixel(valid_count)) begin

                $display(
                    "ERROR - CNN pixel %0d expected %02h got %02h",
                    valid_count,
                    expected_pixel(valid_count),
                    cnn_pixel
                );

                errors = errors + 1;

            end

            if (cnn_pixel == TARGET_PIXEL) begin
                e0_count = e0_count + 1;
            end
            else if (cnn_pixel == BG_PIXEL) begin
                bg_count = bg_count + 1;
            end
            else begin
                other_count = other_count + 1;
            end

            valid_count = valid_count + 1;

        end

        if (cnn_done) begin

            cnn_done_seen = 1'b1;

            $display("");
            $display("================================================");
            $display("CNN DONE");
            $display("================================================");
            $display("Valid pixels = %0d", valid_count);
            $display("LOCK         = %0d", cnn_locked);
            $display("FINAL SUM    = %08h", cnn_score);
            $display("================================================");

        end

    end

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // INITIAL VALUES
        // -----------------------------------------------------

        reset = 1'b1;
        start = 1'b0;

        roi_write_en = 1'b0;
        roi_write_addr = 10'd0;
        roi_write_data = 8'h00;

        errors = 0;

        read_count = 0;
        valid_count = 0;

        e0_count = 0;
        bg_count = 0;
        other_count = 0;

        cnn_done_seen = 1'b0;

        // -----------------------------------------------------
        // HEADER
        // -----------------------------------------------------

        $display("");
        $display("================================================");
        $display("VAJRA DRISHTI CNN DEBUG TEST");
        $display("================================================");
        $display("ROI size       = 32x32");
        $display("ROI pixels     = 1024");
        $display("Target pixel   = E0");
        $display("Background     = 10");
        $display("Expected E0    = 961");
        $display("Expected 10    = 63");
        $display("================================================");

        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        repeat (10) begin
            @(posedge clk);
        end

        reset = 1'b0;

        // -----------------------------------------------------
        // LOAD ROI
        // -----------------------------------------------------

        load_roi();

        // -----------------------------------------------------
        // VERIFY ROI
        // -----------------------------------------------------

        verify_roi();

        // -----------------------------------------------------
        // WAIT
        // -----------------------------------------------------

        repeat (5) begin
            @(posedge clk);
        end

        // -----------------------------------------------------
        // START CNN CONTROLLER
        // -----------------------------------------------------

        $display("");
        $display("================================================");
        $display("STEP 3 - START CNN CONTROLLER");
        $display("================================================");

        start = 1'b1;

        @(posedge clk);

        start = 1'b0;

        $display("CNN controller started at time %0t", $time);

        // -----------------------------------------------------
        // WAIT FOR CNN
        //
        // CNN should finish well before this timeout.
        // -----------------------------------------------------

        i = 0;

        while ((cnn_done_seen == 1'b0) &&
               (i < 500000)) begin

            @(posedge clk);

            i = i + 1;

        end

        // -----------------------------------------------------
        // TIMEOUT CHECK
        // -----------------------------------------------------

        if (cnn_done_seen == 1'b0) begin

            $display("");
            $display("ERROR - CNN TIMEOUT");
            $display("ROI reads  = %0d", read_count);
            $display("CNN valids = %0d", valid_count);

            errors = errors + 1;

        end

        // -----------------------------------------------------
        // FINAL REPORT
        // -----------------------------------------------------

        $display("");
        $display("================================================");
        $display("FINAL DEBUG REPORT");
        $display("================================================");

        $display("");
        $display("ROI READ SIDE");
        $display("Read requests = %0d", read_count);

        $display("");
        $display("CNN INPUT SIDE");
        $display("Valid pulses  = %0d", valid_count);
        $display("E0 pixels     = %0d", e0_count);
        $display("10 pixels     = %0d", bg_count);
        $display("Other pixels  = %0d", other_count);

        $display("");
        $display("CNN RESULT");
        $display("Done          = %0d", cnn_done_seen);
        $display("LOCK          = %0d", cnn_locked);
        $display("FINAL SUM     = %08h", cnn_score);

        $display("");
        $display("================================================");

        // -----------------------------------------------------
        // CHECK READ COUNT
        // -----------------------------------------------------

        if (read_count == 1024) begin
            $display("PASS - exactly 1024 ROI reads.");
        end
        else begin
            $display(
                "FAIL - ROI reads expected 1024, got %0d.",
                read_count
            );

            errors = errors + 1;
        end

        // -----------------------------------------------------
        // CHECK VALID COUNT
        // -----------------------------------------------------

        if (valid_count == 1024) begin
            $display("PASS - exactly 1024 CNN valid pulses.");
        end
        else begin
            $display(
                "FAIL - CNN valid expected 1024, got %0d.",
                valid_count
            );

            errors = errors + 1;
        end

        // -----------------------------------------------------
        // CHECK E0 COUNT
        // -----------------------------------------------------

        if (e0_count == 961) begin
            $display("PASS - CNN received 961 E0 pixels.");
        end
        else begin
            $display(
                "FAIL - CNN E0 expected 961, got %0d.",
                e0_count
            );

            errors = errors + 1;
        end

        // -----------------------------------------------------
        // CHECK BACKGROUND COUNT
        // -----------------------------------------------------

        if (bg_count == 63) begin
            $display("PASS - CNN received 63 background pixels.");
        end
        else begin
            $display(
                "FAIL - CNN background expected 63, got %0d.",
                bg_count
            );

            errors = errors + 1;
        end

        // -----------------------------------------------------
        // CHECK UNKNOWN PIXELS
        // -----------------------------------------------------

        if (other_count == 0) begin
            $display("PASS - no unexpected CNN pixels.");
        end
        else begin
            $display(
                "FAIL - %0d unexpected CNN pixels.",
                other_count
            );

            errors = errors + 1;
        end

        // -----------------------------------------------------
        // FINAL STATUS
        // -----------------------------------------------------

        $display("");
        $display("================================================");

        if (errors == 0) begin

            $display("CNN DATA PATH DEBUG PASS");

        end
        else begin

            $display(
                "CNN DATA PATH DEBUG FAIL - %0d error(s)",
                errors
            );

        end

        $display("================================================");
        $display("");

        $finish;

    end

endmodule