`timescale 1ns / 1ps

// ================================================================
// VAJRA DRISHTI
// MASTER FULL-SYSTEM DEBUG TESTBENCH
//
// PURPOSE:
//   1. Send background frame
//   2. Establish frame history
//   3. Send target frame
//   4. Verify motion detection
//   5. Verify ROI extraction
//   6. Verify CNN receives exactly 1024 pixels
//   7. Verify CNN pipeline counts
//   8. Verify final result / UART packet
//
// IMPORTANT:
//   This TB intentionally does NOT access:
//       line_buffer_inst
//       roi_memory.memory_array
//
//   Those internal names were not confirmed.
// ================================================================

module tb_vajra_master_debug;

    // ============================================================
    // PARAMETERS
    // ============================================================

    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer BAUD_RATE   = 20_000_000;

    localparam integer WIDTH  = 640;
    localparam integer HEIGHT = 480;

    localparam integer FRAME_PIXELS = 307200;
    localparam integer ROI_PIXELS   = 1024;

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
    // UART
    // ============================================================

    reg  uart_rx_pin;
    wire uart_tx_pin;

    wire pwm_pan;
    wire pwm_tilt;
    wire system_state_led;

    // ============================================================
    // DUT
    // ============================================================

    vajra_uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .reset(reset),

        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),

        .pwm_pan(pwm_pan),
        .pwm_tilt(pwm_tilt),
        .system_state_led(system_state_led)
    );

    // ============================================================
    // TEST CONTROL
    // ============================================================

    integer current_frame;
    integer errors;

    reg test_finished;

    // ============================================================
    // FRAME COUNTERS
    // ============================================================

    integer frame_write_index;

    integer frame1_writes;
    integer frame2_writes;

    integer frame1_motion_hits;
    integer frame2_motion_hits;

    // ============================================================
    // ROI COUNTERS
    // ============================================================

    integer roi_write_count;
    integer roi_read_count;

    integer roi_write_e0;
    integer roi_write_bg;
    integer roi_write_other;

    // ============================================================
    // CNN INPUT COUNTERS
    // ============================================================

    integer cnn_valid_count;
    integer cnn_e0_count;
    integer cnn_bg_count;
    integer cnn_other_count;

    // ============================================================
    // CNN PIPELINE COUNTERS
    // ============================================================

    integer conv_valid_count;
    integer pool_valid_count;
    integer serial_valid_count;
    integer dense_valid_count;

    // ============================================================
    // UART RESULT COUNTER
    // ============================================================

    integer tx_start_count;

    reg [7:0] tx_bytes [0:31];

    // ============================================================
    // EVENT FLAGS
    // ============================================================

    reg frame1_result_seen;
    reg frame2_result_seen;

    reg frame_done_seen;
    reg roi_start_seen;
    reg roi_done_seen;

    reg cnn_start_seen;
    reg cnn_reset_seen;
    reg cnn_done_seen;

    // ============================================================
    // UART BYTE TRANSMITTER
    //
    // 100 MHz clock
    // 20 MHz UART
    //
    // 1 bit = 50 ns
    // ============================================================

    task uart_send_byte;

        input [7:0] data;

        integer i;

        begin

            // START BIT
            uart_rx_pin = 1'b0;
            #50;

            // DATA BITS
            for (i = 0; i < 8; i = i + 1) begin

                uart_rx_pin = data[i];
                #50;

            end

            // STOP BIT
            uart_rx_pin = 1'b1;
            #50;

        end

    endtask

    // ============================================================
    // SEND BACKGROUND FRAME
    // ============================================================

    task send_background_frame;

        integer x;
        integer y;

        begin

            current_frame = 1;
            frame_write_index = 0;

            $display("");
            $display("============================================================");
            $display("FRAME 1 : BACKGROUND");
            $display("============================================================");
            $display("640 x 480");
            $display("All pixels = 10h");
            $display("");

            // HEADER
            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);

            // IMAGE
            for (y = 0; y < HEIGHT; y = y + 1) begin

                for (x = 0; x < WIDTH; x = x + 1) begin

                    uart_send_byte(BG_VALUE);

                end

            end

            uart_rx_pin = 1'b1;

            $display("FRAME 1 TRANSMISSION COMPLETE");
            $display("");

        end

    endtask

    // ============================================================
    // SEND TARGET FRAME
    //
    // Target:
    //
    // X = 304..335
    // Y = 224..255
    //
    // 32 x 32 = 1024 pixels
    // ============================================================

    task send_target_frame;

        integer x;
        integer y;

        begin

            current_frame = 2;
            frame_write_index = 0;

            $display("");
            $display("============================================================");
            $display("FRAME 2 : TARGET");
            $display("============================================================");
            $display("Background = 10h");
            $display("Target     = E0h");
            $display("Target X   = 304..335");
            $display("Target Y   = 224..255");
            $display("Target size = 32 x 32");
            $display("");

            // HEADER
            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);

            // IMAGE
            for (y = 0; y < HEIGHT; y = y + 1) begin

                for (x = 0; x < WIDTH; x = x + 1) begin

                    if ((x >= 304) && (x <= 335) &&
                        (y >= 224) && (y <= 255)) begin

                        uart_send_byte(TARGET_VALUE);

                    end
                    else begin

                        uart_send_byte(BG_VALUE);

                    end

                end

            end

            uart_rx_pin = 1'b1;

            $display("FRAME 2 TRANSMISSION COMPLETE");
            $display("");

        end

    endtask

    // ============================================================
    // WAIT FOR RESULT
    //
    // Uses global watchdog below.
    // ============================================================

    task wait_for_result;

        begin

            wait (dut.result_valid === 1'b1);

            @(posedge clk);

        end

    endtask

    // ============================================================
    // CHECK FRAME BUFFER
    //
    // Reads the actual DUT frame_buffer.
    //
    // frame_number = 1:
    //     expected all 10h
    //
    // frame_number = 2:
    //     target at 304..335 / 224..255
    // ============================================================

    task check_frame_buffer;

        input integer frame_number;

        integer i;
        integer x;
        integer y;
        integer mismatch_count;
        reg [7:0] expected_pixel;

        begin

            mismatch_count = 0;

            $display("");
            $display("------------------------------------------------------------");
            $display("CHECKING FRAME BUFFER : FRAME %0d", frame_number);
            $display("------------------------------------------------------------");

            for (i = 0; i < FRAME_PIXELS; i = i + 1) begin

                x = i % WIDTH;
                y = i / WIDTH;

                expected_pixel = BG_VALUE;

                if ((frame_number == 2) &&
                    (x >= 304) &&
                    (x <= 335) &&
                    (y >= 224) &&
                    (y <= 255)) begin

                    expected_pixel = TARGET_VALUE;

                end

                if (dut.frame_buffer[i] !== expected_pixel) begin

                    mismatch_count = mismatch_count + 1;

                    if (mismatch_count <= 10) begin

                        $display(
                            "FRAME BUFFER MISMATCH addr=%0d x=%0d y=%0d expected=%02h actual=%02h",
                            i,
                            x,
                            y,
                            expected_pixel,
                            dut.frame_buffer[i]
                        );

                    end

                end

            end

            $display("");
            $display("Frame buffer mismatches = %0d",
                     mismatch_count);

            if (mismatch_count == 0) begin

                $display("PASS: frame buffer contents are correct.");

            end
            else begin

                $display("FAIL: frame buffer contents are incorrect.");

                errors = errors + 1;

            end

        end

    endtask

    // ============================================================
    // TOP LEVEL EVENT MONITOR
    // ============================================================

    always @(posedge clk) begin

        if (!reset) begin

            // ----------------------------------------------------
            // FRAME DONE
            // ----------------------------------------------------

            if (dut.frame_done) begin

                frame_done_seen = 1'b1;

                $display("");
                $display("============================================================");
                $display("[FRAME DONE]");
                $display("time         = %0t", $time);
                $display("current_frame= %0d", current_frame);

                $display("motion_flag  = %0d",
                         dut.motion_flag);

                $display("motion_x     = %0d",
                         dut.motion_x);

                $display("motion_y     = %0d",
                         dut.motion_y);

                $display("min_x        = %0d",
                         dut.frame_controller.min_x);

                $display("max_x        = %0d",
                         dut.frame_controller.max_x);

                $display("min_y        = %0d",
                         dut.frame_controller.min_y);

                $display("max_y        = %0d",
                         dut.frame_controller.max_y);

                $display("motion_count = %0d",
                         dut.frame_controller.motion_count);

                $display("============================================================");

            end

            // ----------------------------------------------------
            // ROI START
            // ----------------------------------------------------

            if (dut.roi_start) begin

                roi_start_seen = 1'b1;

                $display("");
                $display("[ROI START]");
                $display("motion_x = %0d",
                         dut.motion_x);

                $display("motion_y = %0d",
                         dut.motion_y);

                $display("ROI left = %0d",
                         dut.roi_extractor.left);

                $display("ROI top  = %0d",
                         dut.roi_extractor.top);

            end

            // ----------------------------------------------------
            // ROI DONE
            // ----------------------------------------------------

            if (dut.roi_done) begin

                roi_done_seen = 1'b1;

                $display("");
                $display("[ROI DONE]");
                $display("ROI writes = %0d",
                         roi_write_count);

            end

            // ----------------------------------------------------
            // CNN START
            // ----------------------------------------------------

            if (dut.cnn_start) begin

                cnn_start_seen = 1'b1;

                $display("");
                $display("[CNN START]");

            end

            // ----------------------------------------------------
            // CNN RESET
            // ----------------------------------------------------

            if (dut.cnn_reset) begin

                cnn_reset_seen = 1'b1;

                $display("[CNN RESET]");

            end

            // ----------------------------------------------------
            // CNN DONE
            // ----------------------------------------------------

            if (dut.cnn_done) begin

                cnn_done_seen = 1'b1;

                $display("");
                $display("============================================================");
                $display("[CNN DONE]");
                $display("CNN locked = %0d",
                         dut.cnn_locked);

                $display("CNN score HEX = %08h",
                         dut.cnn_score);

                $display("CNN score DEC = %0d",
                         $signed(dut.cnn_score));

                $display("============================================================");

            end

            // ----------------------------------------------------
            // RESULT
            // ----------------------------------------------------

            if (dut.result_valid) begin

                $display("");
                $display("============================================================");
                $display("[RESULT VALID]");
                $display("Frame        = %0d",
                         current_frame);

                $display("LOCK         = %0d",
                         dut.target_locked);

                $display("X            = %0d",
                         dut.active_x);

                $display("Y            = %0d",
                         dut.active_y);

                $display("LED          = %0d",
                         system_state_led);

                $display("============================================================");

                if (current_frame == 1)
                    frame1_result_seen = 1'b1;

                if (current_frame == 2)
                    frame2_result_seen = 1'b1;

            end

        end

    end

    // ============================================================
    // FRAME MEMORY WRITE MONITOR
    //
    // This is particularly important.
    //
    // It checks:
    //
    //   1. number of writes
    //   2. sequential addresses
    //
    // The actual frame-buffer CONTENT is checked separately.
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            frame_write_index = 0;

            frame1_writes = 0;
            frame2_writes = 0;

            frame1_motion_hits = 0;
            frame2_motion_hits = 0;

        end
        else begin

            // ----------------------------------------------------
            // FRAME WRITE
            // ----------------------------------------------------

            if (dut.rx_mem_write_en) begin

                if (dut.rx_mem_addr !== frame_write_index) begin

                    $display(
                        "FRAME WRITE ADDRESS ERROR: expected=%0d actual=%0d",
                        frame_write_index,
                        dut.rx_mem_addr
                    );

                    errors = errors + 1;

                end

                frame_write_index = frame_write_index + 1;

                if (current_frame == 1)
                    frame1_writes = frame1_writes + 1;

                if (current_frame == 2)
                    frame2_writes = frame2_writes + 1;

            end

            // ----------------------------------------------------
            // MOTION HIT
            // ----------------------------------------------------

            if (dut.frame_controller.motion_hit) begin

                if (current_frame == 1)
                    frame1_motion_hits = frame1_motion_hits + 1;

                if (current_frame == 2)
                    frame2_motion_hits = frame2_motion_hits + 1;

            end

        end

    end

    // ============================================================
    // ROI WRITE MONITOR
    //
    // Expected:
    //
    // 1024 writes
    // addresses 0..1023
    //
    // Also records the actual pixel values presented to ROI BRAM.
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            roi_write_count = 0;

            roi_write_e0 = 0;
            roi_write_bg = 0;
            roi_write_other = 0;

        end
        else begin

            if (dut.roi_write_en) begin

                roi_write_count = roi_write_count + 1;

                if ((roi_write_count <= 5) ||
                    (roi_write_count > 1019)) begin

                    $display(
                        "[ROI WRITE] #%0d addr=%0d pixel=%02h",
                        roi_write_count,
                        dut.roi_write_addr,
                        dut.roi_pixel
                    );

                end

                if (dut.roi_write_addr !==
                    (roi_write_count - 1)) begin

                    $display(
                        "ROI ADDRESS ERROR: expected=%0d actual=%0d",
                        roi_write_count - 1,
                        dut.roi_write_addr
                    );

                    errors = errors + 1;

                end

                if (dut.roi_pixel === TARGET_VALUE)

                    roi_write_e0 = roi_write_e0 + 1;

                else if (dut.roi_pixel === BG_VALUE)

                    roi_write_bg = roi_write_bg + 1;

                else

                    roi_write_other = roi_write_other + 1;

            end

        end

    end

    // ============================================================
    // CNN ROI READ MONITOR
    //
    // Expected addresses:
    //
    // 0..1023
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            roi_read_count = 0;

        end
        else begin

            if (dut.cnn_read_en) begin

                roi_read_count = roi_read_count + 1;

                if ((roi_read_count <= 5) ||
                    (roi_read_count > 1019)) begin

                    $display(
                        "[CNN ROI READ] #%0d addr=%0d",
                        roi_read_count,
                        dut.cnn_read_addr
                    );

                end

                if (dut.cnn_read_addr !==
                    (roi_read_count - 1)) begin

                    $display(
                        "CNN ROI ADDRESS ERROR: expected=%0d actual=%0d",
                        roi_read_count - 1,
                        dut.cnn_read_addr
                    );

                    errors = errors + 1;

                end

            end

        end

    end

    // ============================================================
    // CNN INPUT MONITOR
    //
    // Expected for a perfect ROI:
    //
    // 1024 total
    // 961 target E0
    // 63 background 10
    // 0 other
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            cnn_valid_count = 0;
            cnn_e0_count = 0;
            cnn_bg_count = 0;
            cnn_other_count = 0;

        end
        else begin

            if (dut.cnn_valid) begin

                cnn_valid_count = cnn_valid_count + 1;

                if (dut.cnn_pixel === TARGET_VALUE)

                    cnn_e0_count = cnn_e0_count + 1;

                else if (dut.cnn_pixel === BG_VALUE)

                    cnn_bg_count = cnn_bg_count + 1;

                else

                    cnn_other_count = cnn_other_count + 1;

                if ((cnn_valid_count <= 8) ||
                    (cnn_valid_count > 1016)) begin

                    $display(
                        "[CNN INPUT] #%0d pixel=%02h",
                        cnn_valid_count,
                        dut.cnn_pixel
                    );

                end

            end

        end

    end

    // ============================================================
    // CONVOLUTION MONITOR
    //
    // Expected:
    //
    // 32x32 input
    // 3x3 kernel
    //
    // 30x30 = 900 outputs
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            conv_valid_count = 0;

        end
        else begin

            if (dut.cnn.core_conv.valid_out) begin

                conv_valid_count = conv_valid_count + 1;

                if ((conv_valid_count <= 5) ||
                    (conv_valid_count > 895)) begin

                    $display(
                        "[CONV] #%0d F0=%02h F1=%02h F2=%02h F3=%02h",
                        conv_valid_count,
                        dut.cnn.core_conv.feature_0,
                        dut.cnn.core_conv.feature_1,
                        dut.cnn.core_conv.feature_2,
                        dut.cnn.core_conv.feature_3
                    );

                end

            end

        end

    end

    // ============================================================
    // MAX POOL MONITOR
    //
    // Expected:
    //
    // 30x30 -> 15x15
    //
    // 225 outputs
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            pool_valid_count = 0;

        end
        else begin

            if (dut.cnn.pool_0.valid_out) begin

                pool_valid_count = pool_valid_count + 1;

                if ((pool_valid_count <= 5) ||
                    (pool_valid_count > 220)) begin

                    $display(
                        "[POOL] #%0d P0=%02h P1=%02h P2=%02h P3=%02h",
                        pool_valid_count,
                        dut.cnn.pool_p0,
                        dut.cnn.pool_p1,
                        dut.cnn.pool_p2,
                        dut.cnn.pool_p3
                    );

                end

            end

        end

    end

    // ============================================================
    // SERIALIZER MONITOR
    //
    // Expected:
    //
    // 225 batches x 4 channels
    // = 900 outputs
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            serial_valid_count = 0;

        end
        else begin

            if (dut.cnn.data_bridge.valid_out) begin

                serial_valid_count = serial_valid_count + 1;

                if ((serial_valid_count <= 10) ||
                    (serial_valid_count > 890)) begin

                    $display(
                        "[SERIALIZER] #%0d pixel=%02h",
                        serial_valid_count,
                        dut.cnn.data_bridge.pixel_out
                    );

                end

            end

        end

    end

    // ============================================================
    // DENSE INPUT MONITOR
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            dense_valid_count = 0;

        end
        else begin

            if (dut.cnn.decision_core.valid_in)

                dense_valid_count = dense_valid_count + 1;

        end

    end

    // ============================================================
    // SERIALIZER FIFO MONITOR
    // ============================================================

    always @(posedge clk) begin

        if (!reset) begin

            if (dut.cnn.data_bridge.fifo_count > 120) begin

                $display(
                    "[WARNING] Serializer FIFO high: count=%0d",
                    dut.cnn.data_bridge.fifo_count
                );

            end

        end

    end

    // ============================================================
    // UART PACKET MONITOR
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            tx_start_count = 0;

        end
        else begin

            if (dut.tx_start) begin

                if (tx_start_count < 32)

                    tx_bytes[tx_start_count] = dut.tx_data;

                $display(
                    "[UART PACKET] byte #%0d = %02h",
                    tx_start_count,
                    dut.tx_data
                );

                tx_start_count = tx_start_count + 1;

            end

        end

    end

    // ============================================================
    // GLOBAL WATCHDOG
    //
    // Two complete UART frames at 20 MHz:
    //
    // approximately 307 ms total.
    //
    // Give the simulation 450 ms.
    // ============================================================

    initial begin

        #450_000_000;

        if (!test_finished) begin

            $display("");
            $display("############################################################");
            $display("GLOBAL WATCHDOG TIMEOUT");
            $display("############################################################");
            $display("Simulation exceeded 450 ms.");
            $display("The DUT probably did not complete both frames.");
            $display("");

            errors = errors + 1;

            test_finished = 1'b1;

            $finish;

        end

    end

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // INITIALIZATION
        // --------------------------------------------------------

        reset = 1'b1;
        uart_rx_pin = 1'b1;

        current_frame = 0;

        errors = 0;

        test_finished = 1'b0;

        frame_write_index = 0;

        frame1_writes = 0;
        frame2_writes = 0;

        frame1_motion_hits = 0;
        frame2_motion_hits = 0;

        roi_write_count = 0;
        roi_read_count = 0;

        roi_write_e0 = 0;
        roi_write_bg = 0;
        roi_write_other = 0;

        cnn_valid_count = 0;
        cnn_e0_count = 0;
        cnn_bg_count = 0;
        cnn_other_count = 0;

        conv_valid_count = 0;
        pool_valid_count = 0;
        serial_valid_count = 0;
        dense_valid_count = 0;

        tx_start_count = 0;

        frame1_result_seen = 1'b0;
        frame2_result_seen = 1'b0;

        frame_done_seen = 1'b0;
        roi_start_seen = 1'b0;
        roi_done_seen = 1'b0;

        cnn_start_seen = 1'b0;
        cnn_reset_seen = 1'b0;
        cnn_done_seen = 1'b0;


        // --------------------------------------------------------
        // START MESSAGE
        // --------------------------------------------------------

        $display("");
        $display("");
        $display("################################################################");
        $display("#                                                              #");
        $display("#             VAJRA DRISHTI MASTER DEBUG                      #");
        $display("#                                                              #");
        $display("################################################################");
        $display("");
        $display("Clock       : 100 MHz");
        $display("UART        : 20 MHz");
        $display("Bit time    : 50 ns");
        $display("Resolution  : 640 x 480");
        $display("ROI         : 32 x 32");
        $display("");
        $display("Target:");
        $display("X = 304..335");
        $display("Y = 224..255");
        $display("");
        $display("Expected motion:");
        $display("1024 changed pixels");
        $display("");
        $display("Expected ROI:");
        $display("961 x E0");
        $display("63  x 10");
        $display("");
        $display("################################################################");


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        repeat (20)
            @(posedge clk);

        reset = 1'b0;

        repeat (10)
            @(posedge clk);


        // ========================================================
        // FRAME 1
        // ========================================================

        frame1_result_seen = 1'b0;

        send_background_frame();

        wait_for_result();

        $display("");
        $display("============================================================");
        $display("FRAME 1 RESULT RECEIVED");
        $display("============================================================");
        $display("Frame 1 writes = %0d", frame1_writes);
        $display("Frame 1 motion hits = %0d", frame1_motion_hits);
        $display("LOCK = %0d", dut.target_locked);
        $display("X = %0d", dut.active_x);
        $display("Y = %0d", dut.active_y);
        $display("============================================================");


        // --------------------------------------------------------
        // CHECK FRAME 1
        // --------------------------------------------------------

        if (frame1_writes != FRAME_PIXELS) begin

            $display("FAIL: Frame 1 write count.");

            errors = errors + 1;

        end
        else begin

            $display("PASS: Frame 1 has 307200 writes.");

        end

        if (frame1_motion_hits != 0) begin

            $display(
                "FAIL: Frame 1 unexpectedly detected %0d motion pixels.",
                frame1_motion_hits
            );

            errors = errors + 1;

        end
        else begin

            $display("PASS: Frame 1 has zero motion pixels.");

        end


        // --------------------------------------------------------
        // THIS IS IMPORTANT:
        //
        // If this fails with one or a few mismatches, we have
        // evidence of frame-buffer write timing corruption.
        // --------------------------------------------------------

        check_frame_buffer(1);


        // ========================================================
        // FRAME 2
        // ========================================================

        frame2_result_seen = 1'b0;

        send_target_frame();

        wait_for_result();

        $display("");
        $display("============================================================");
        $display("FRAME 2 RESULT RECEIVED");
        $display("============================================================");
        $display("Frame 2 writes = %0d", frame2_writes);
        $display("Frame 2 motion hits = %0d", frame2_motion_hits);
        $display("LOCK = %0d", dut.target_locked);
        $display("X = %0d", dut.active_x);
        $display("Y = %0d", dut.active_y);
        $display("============================================================");


        // ========================================================
        // FINAL CHECKS
        // ========================================================

        $display("");
        $display("");
        $display("################################################################");
        $display("#                     FINAL DEBUG REPORT                       #");
        $display("################################################################");


        // --------------------------------------------------------
        // FRAME WRITE
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("1. FRAME WRITE");
        $display("------------------------------------------------------------");

        $display("Frame 1 writes = %0d", frame1_writes);
        $display("Frame 2 writes = %0d", frame2_writes);

        if (frame1_writes == FRAME_PIXELS)

            $display("PASS: Frame 1 write count.");

        else begin

            $display("FAIL: Frame 1 write count.");
            errors = errors + 1;

        end

        if (frame2_writes == FRAME_PIXELS)

            $display("PASS: Frame 2 write count.");

        else begin

            $display("FAIL: Frame 2 write count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // FRAME 2 CONTENT
        // --------------------------------------------------------

        check_frame_buffer(2);


        // --------------------------------------------------------
        // MOTION
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("2. MOTION DETECTION");
        $display("------------------------------------------------------------");

        $display("motion_flag = %0d",
                 dut.motion_flag);

        $display("motion_x = %0d",
                 dut.motion_x);

        $display("motion_y = %0d",
                 dut.motion_y);

        $display("min_x = %0d",
                 dut.frame_controller.min_x);

        $display("max_x = %0d",
                 dut.frame_controller.max_x);

        $display("min_y = %0d",
                 dut.frame_controller.min_y);

        $display("max_y = %0d",
                 dut.frame_controller.max_y);

        $display("motion_count = %0d",
                 dut.frame_controller.motion_count);

        $display("Frame 2 motion hits = %0d",
                 frame2_motion_hits);


        if (frame2_motion_hits == 1024)

            $display("PASS: exactly 1024 motion pixels.");

        else begin

            $display("FAIL: expected 1024 motion pixels.");
            errors = errors + 1;

        end


        if ((dut.frame_controller.min_x == 304) &&
            (dut.frame_controller.max_x == 335) &&
            (dut.frame_controller.min_y == 224) &&
            (dut.frame_controller.max_y == 255)) begin

            $display("PASS: exact motion bounding box.");

        end
        else begin

            $display("FAIL: motion bounding box.");
            errors = errors + 1;

        end


        if ((dut.motion_x == 319) &&
            (dut.motion_y == 239)) begin

            $display("PASS: motion center = 319,239.");

        end
        else begin

            $display("FAIL: motion center.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // ROI
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("3. ROI EXTRACTION");
        $display("------------------------------------------------------------");

        $display("ROI writes = %0d",
                 roi_write_count);

        $display("ROI left = %0d",
                 dut.roi_extractor.left);

        $display("ROI top = %0d",
                 dut.roi_extractor.top);

        if (roi_write_count == 1024)

            $display("PASS: exactly 1024 ROI writes.");

        else begin

            $display("FAIL: ROI write count.");
            errors = errors + 1;

        end

        if ((dut.roi_extractor.left == 303) &&
            (dut.roi_extractor.top == 223)) begin

            $display("PASS: ROI origin = 303,223.");

        end
        else begin

            $display("FAIL: ROI origin.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // ROI WRITE DATA
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("4. ROI WRITE DATA");
        $display("------------------------------------------------------------");

        $display("ROI E0    = %0d", roi_write_e0);
        $display("ROI 10    = %0d", roi_write_bg);
        $display("ROI other = %0d", roi_write_other);

        if (roi_write_e0 == 961)

            $display("PASS: 961 target pixels at ROI write interface.");

        else begin

            $display("FAIL: ROI target pixel count.");
            errors = errors + 1;

        end

        if (roi_write_bg == 63)

            $display("PASS: 63 background pixels at ROI write interface.");

        else begin

            $display("FAIL: ROI background pixel count.");
            errors = errors + 1;

        end

        if (roi_write_other == 0)

            $display("PASS: no unexpected ROI values.");

        else begin

            $display("FAIL: unexpected ROI values.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // CNN READ
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("5. CNN ROI READ");
        $display("------------------------------------------------------------");

        $display("ROI reads = %0d",
                 roi_read_count);

        if (roi_read_count == 1024)

            $display("PASS: 1024 ROI reads.");

        else begin

            $display("FAIL: ROI read count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // CNN INPUT
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("6. CNN INPUT");
        $display("------------------------------------------------------------");

        $display("CNN valid = %0d",
                 cnn_valid_count);

        $display("CNN E0 = %0d",
                 cnn_e0_count);

        $display("CNN background = %0d",
                 cnn_bg_count);

        $display("CNN other = %0d",
                 cnn_other_count);

        if (cnn_valid_count == 1024)

            $display("PASS: exactly 1024 CNN inputs.");

        else begin

            $display("FAIL: CNN input count.");
            errors = errors + 1;

        end

        if (cnn_e0_count == 961)

            $display("PASS: 961 E0 pixels reached CNN.");

        else begin

            $display("FAIL: CNN E0 count.");
            errors = errors + 1;

        end

        if (cnn_bg_count == 63)

            $display("PASS: 63 background pixels reached CNN.");

        else begin

            $display("FAIL: CNN background count.");
            errors = errors + 1;

        end

        if (cnn_other_count == 0)

            $display("PASS: no unexpected CNN input values.");

        else begin

            $display("FAIL: unexpected CNN input values.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // CONV
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("7. CONVOLUTION");
        $display("------------------------------------------------------------");

        $display("Conv valid outputs = %0d",
                 conv_valid_count);

        if (conv_valid_count == 900)

            $display("PASS: 900 convolution outputs.");

        else begin

            $display("FAIL: convolution output count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // POOL
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("8. MAX POOL");
        $display("------------------------------------------------------------");

        $display("Pool valid outputs = %0d",
                 pool_valid_count);

        if (pool_valid_count == 225)

            $display("PASS: 225 pool outputs.");

        else begin

            $display("FAIL: pool output count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // SERIALIZER
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("9. SERIALIZER");
        $display("------------------------------------------------------------");

        $display("Serializer outputs = %0d",
                 serial_valid_count);

        $display("FIFO count = %0d",
                 dut.cnn.data_bridge.fifo_count);

        $display("FIFO WR ptr = %0d",
                 dut.cnn.data_bridge.wr_ptr);

        $display("FIFO RD ptr = %0d",
                 dut.cnn.data_bridge.rd_ptr);

        if (serial_valid_count == 900)

            $display("PASS: 900 serializer outputs.");

        else begin

            $display("FAIL: serializer output count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // DENSE
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("10. DENSE");
        $display("------------------------------------------------------------");

        $display("Dense valid inputs = %0d",
                 dense_valid_count);

        $display("Accumulator = %08h",
                 dut.cnn.decision_core.accumulator_out);

        $display("Accumulator signed = %0d",
                 $signed(dut.cnn.decision_core.accumulator_out));

        if (dense_valid_count == 900)

            $display("PASS: 900 dense inputs.");

        else begin

            $display("FAIL: dense input count.");
            errors = errors + 1;

        end


        // --------------------------------------------------------
        // CNN RESULT
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("11. CNN RESULT");
        $display("------------------------------------------------------------");

        $display("CNN done   = %0d",
                 dut.cnn_done);

        $display("CNN locked = %0d",
                 dut.cnn_locked);

        $display("CNN score HEX = %08h",
                 dut.cnn_score);

        $display("CNN score DEC = %0d",
                 $signed(dut.cnn_score));

        $display("Threshold = -150000");


        // --------------------------------------------------------
        // MASTER FSM
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("12. MASTER FSM");
        $display("------------------------------------------------------------");

        $display("FSM state = %0d",
                 dut.controller.state);

        $display("active_x = %0d",
                 dut.active_x);

        $display("active_y = %0d",
                 dut.active_y);

        $display("target_locked = %0d",
                 dut.target_locked);

        $display("tracking_active = %0d",
                 dut.tracking_active);


        // --------------------------------------------------------
        // UART
        // --------------------------------------------------------

        $display("");
        $display("------------------------------------------------------------");
        $display("13. UART RESULT");
        $display("------------------------------------------------------------");

        $display("TX start count = %0d",
                 tx_start_count);

        $display("Frame 1 result seen = %0d",
                 frame1_result_seen);

        $display("Frame 2 result seen = %0d",
                 frame2_result_seen);


        // --------------------------------------------------------
        // PRINT FIRST 14 UART BYTES
        // --------------------------------------------------------

        $display("");
        $display("UART BYTES:");

        if (tx_start_count >= 14) begin

            $display(
                "Frame 1: %02h %02h %02h %02h %02h %02h %02h",
                tx_bytes[0],
                tx_bytes[1],
                tx_bytes[2],
                tx_bytes[3],
                tx_bytes[4],
                tx_bytes[5],
                tx_bytes[6]
            );

            $display(
                "Frame 2: %02h %02h %02h %02h %02h %02h %02h",
                tx_bytes[7],
                tx_bytes[8],
                tx_bytes[9],
                tx_bytes[10],
                tx_bytes[11],
                tx_bytes[12],
                tx_bytes[13]
            );

        end
        else begin

            $display("WARNING: fewer than 14 UART packet bytes observed.");

        end


        // ========================================================
        // FINAL DIAGNOSIS
        // ========================================================

        $display("");
        $display("");
        $display("################################################################");
        $display("#                         DIAGNOSIS                            #");
        $display("################################################################");
        $display("");

        if (frame1_writes != FRAME_PIXELS ||
            frame2_writes != FRAME_PIXELS) begin

            $display(">>> FIRST SUSPECT: FRAME RECEIVER / FRAME BUFFER");

        end
        else if (frame2_motion_hits != 1024) begin

            $display(">>> FIRST SUSPECT: MOTION DETECTOR");

        end
        else if (roi_write_count != 1024) begin

            $display(">>> FIRST SUSPECT: ROI EXTRACTOR");

        end
        else if ((roi_write_e0 != 961) ||
                 (roi_write_bg != 63) ||
                 (roi_write_other != 0)) begin

            $display(">>> FIRST SUSPECT: ROI DATA / ROI BRAM WRITE TIMING");

        end
        else if (roi_read_count != 1024) begin

            $display(">>> FIRST SUSPECT: CNN ROI READ CONTROLLER");

        end
        else if ((cnn_valid_count != 1024) ||
                 (cnn_e0_count != 961) ||
                 (cnn_bg_count != 63) ||
                 (cnn_other_count != 0)) begin

            $display(">>> FIRST SUSPECT: CNN INPUT DATA PATH");

        end
        else if (conv_valid_count != 900) begin

            $display(">>> FIRST SUSPECT: CONVOLUTION / LINE BUFFER");

        end
        else if (pool_valid_count != 225) begin

            $display(">>> FIRST SUSPECT: MAX POOL");

        end
        else if (serial_valid_count != 900) begin

            $display(">>> FIRST SUSPECT: SERIALIZER");

        end
        else if (dense_valid_count != 900) begin

            $display(">>> FIRST SUSPECT: DENSE INPUT");

        end
        else begin

            $display(">>> ALL STRUCTURAL DATA-PATH COUNTS PASSED.");
            $display("");
            $display("If CNN_LOCK is still 0, the problem is now");
            $display("inside the CNN NUMERICAL / CLASSIFICATION PATH.");
            $display("");
            $display("Next suspects:");
            $display("  1. convolution arithmetic");
            $display("  2. signedness");
            $display("  3. convolution weights");
            $display("  4. feature-map values");
            $display("  5. max-pooling values");
            $display("  6. serializer ordering");
            $display("  7. dense weights");
            $display("  8. dense accumulator");
            $display("  9. threshold");
            $display("");

        end


        // ========================================================
        // FINAL STATUS
        // ========================================================

        $display("");
        $display("################################################################");
        $display("#                       FINAL STATUS                           #");
        $display("################################################################");
        $display("");

        $display("TOTAL ERRORS = %0d", errors);

        if (errors == 0) begin

            $display("");
            $display("============================================================");
            $display("MASTER TEST PASSED");
            $display("============================================================");

        end
        else begin

            $display("");
            $display("============================================================");
            $display("MASTER TEST FAILED");
            $display("============================================================");
            $display("We now have a concrete failure point.");
            $display("============================================================");

        end

        $display("");

        test_finished = 1'b1;

        $finish;

    end

endmodule