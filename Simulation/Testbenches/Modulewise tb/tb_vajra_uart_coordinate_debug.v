`timescale 1ns/1ps

/*
 * Vajra Drishti - FULL UART TOP INTEGRATION TESTBENCH
 *
 * DUT SOURCE RTL IS NOT MODIFIED.
 *
 * Test sequence:
 *
 *   Frame 1:
 *       Static background
 *       Expected LOCK = 0
 *
 *   Frame 2:
 *       Same background + 32x32 bright target
 *       Motion -> ROI -> CNN -> result
 *
 * Simulation UART:
 *
 *       CLK  = 100 MHz
 *       BAUD = 20 MHz
 *       BIT_CLKS = 5
 *
 * Production UART remains 921600 baud.
 */

module tb_vajra_uart_top_fixed;

    // =========================================================
    // PARAMETERS
    // =========================================================

    localparam integer CLK_FREQ = 100_000_000;
    localparam integer BAUD     = 20_000_000;

    localparam integer BIT_CLKS = CLK_FREQ / BAUD;

    localparam integer WIDTH  = 640;
    localparam integer HEIGHT = 480;
    localparam integer NPIX   = WIDTH * HEIGHT;

    localparam integer TARGET_X = 320;
    localparam integer TARGET_Y = 240;


    // =========================================================
    // SIGNALS
    // =========================================================

    reg clk;
    reg reset;
    reg uart_rx_pin;

    wire uart_tx_pin;
    wire pwm_pan;
    wire pwm_tilt;
    wire system_state_led;


    // =========================================================
    // TEST VARIABLES
    // =========================================================

    integer errors;

    integer x;
    integer y;
    integer pixel;

    integer bit_index;
    integer byte_index;

    reg [7:0] tx_frame_byte;
    reg [7:0] rx_byte;

    reg [7:0] packet [0:6];


    // =========================================================
    // DUT
    // =========================================================

    vajra_uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ),
        .BAUD_RATE(BAUD)
    ) dut (
        .clk(clk),
        .reset(reset),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .pwm_pan(pwm_pan),
        .pwm_tilt(pwm_tilt),
        .system_state_led(system_state_led)
    );


    // =========================================================
    // 100 MHz CLOCK
    // =========================================================

    always #5 clk = ~clk;


    // =========================================================
    // UART SEND BYTE
    //
    // 8N1:
    //
    // START
    // D0
    // D1
    // D2
    // D3
    // D4
    // D5
    // D6
    // D7
    // STOP
    //
    // Each bit = 5 FPGA clocks.
    // =========================================================

    task uart_send_byte;

        input [7:0] b;

        integer k;

        begin

            // START BIT
            uart_rx_pin = 1'b0;

            repeat (BIT_CLKS)
                @(posedge clk);


            // DATA BITS
            for (k = 0; k < 8; k = k + 1) begin

                uart_rx_pin = b[k];

                repeat (BIT_CLKS)
                    @(posedge clk);

            end


            // STOP BIT
            uart_rx_pin = 1'b1;

            repeat (BIT_CLKS)
                @(posedge clk);

        end

    endtask


    // =========================================================
    // CREATE FRAME PIXEL
    // =========================================================

    task make_frame_byte;

        input integer frame_id;
        input integer px;
        input integer py;

        output [7:0] b;

        begin

            // -------------------------------------------------
            // FRAME 1
            // -------------------------------------------------

            if (frame_id == 1) begin

                b = 8'h10;

            end

            // -------------------------------------------------
            // FRAME 2
            // -------------------------------------------------

            else begin

                if ((px >= TARGET_X - 16) &&
                    (px <  TARGET_X + 16) &&
                    (py >= TARGET_Y - 16) &&
                    (py <  TARGET_Y + 16)) begin

                    b = 8'hE0;

                end
                else begin

                    b = 8'h10;

                end

            end

        end

    endtask


    // =========================================================
    // SEND COMPLETE FRAME
    // =========================================================

    task send_frame;

        input integer frame_id;

        begin

            $display("");
            $display("[%0t] Sending frame %0d ...",
                     $time,
                     frame_id);


            // -------------------------------------------------
            // HEADER
            // -------------------------------------------------

            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);


            // -------------------------------------------------
            // 640x480 PIXELS
            // -------------------------------------------------

            for (pixel = 0;
                 pixel < NPIX;
                 pixel = pixel + 1) begin

                x = pixel % WIDTH;
                y = pixel / WIDTH;

                make_frame_byte(
                    frame_id,
                    x,
                    y,
                    tx_frame_byte
                );

                uart_send_byte(tx_frame_byte);


                // Progress every 50k pixels
                if ((pixel % 50000) == 0) begin

                    $display(
                        "    frame %0d progress: %0d / %0d pixels",
                        frame_id,
                        pixel,
                        NPIX
                    );

                end

            end


            $display(
                "[%0t] Frame %0d transmitted.",
                $time,
                frame_id
            );

        end

    endtask


    // =========================================================
    // UART RECEIVE BYTE
    //
    // IMPORTANT:
    //
    // We do NOT search indefinitely for a negedge.
    //
    // The DUT TX is already known to be idle-high.
    //
    // We wait synchronously for the start bit to become LOW.
    //
    // Then:
    //
    //   1.5 bit periods -> center of D0
    //
    // Since:
    //
    //   100 MHz clock = 10 ns
    //   20 MHz UART    = 50 ns/bit
    //
    // we use:
    //
    //   75 ns -> D0 center
    //
    // and then:
    //
    //   50 ns -> next data bit
    //
    // No extra full-bit delay after D7.
    // =========================================================

    task uart_receive_byte;

        output [7:0] b;

        integer k;
        integer wait_count;

        begin

            b = 8'h00;

            wait_count = 0;


            // -------------------------------------------------
            // WAIT FOR START BIT
            //
            // Sample on FPGA clock edges.
            // Maximum wait = 5,000,000 clocks.
            // -------------------------------------------------

            while (uart_tx_pin !== 1'b0) begin

                @(posedge clk);

                wait_count = wait_count + 1;

                if (wait_count >= 5_000_000) begin

                    $display(
                        "FAIL: timeout waiting for UART TX start bit"
                    );

                    errors = errors + 1;

                    b = 8'h00;

                    disable uart_receive_byte;

                end

            end


            // -------------------------------------------------
            // MOVE TO CENTER OF DATA BIT 0
            //
            // Start bit is currently LOW.
            //
            // Wait 1.5 UART bit times:
            //
            // 1.5 x 50 ns = 75 ns
            // -------------------------------------------------

            #75;


            // -------------------------------------------------
            // SAMPLE DATA
            // -------------------------------------------------

            for (k = 0; k < 8; k = k + 1) begin

                b[k] = uart_tx_pin;

                #50;

            end


            // -------------------------------------------------
            // DO NOT WAIT A FULL EXTRA BIT.
            //
            // We are now in the stop bit.
            // Wait only half a bit before returning.
            // -------------------------------------------------

            #25;

        end

    endtask


    // =========================================================
    // RECEIVE 7-BYTE RESULT PACKET
    //
    // AA 55 LOCK XLOW XHIGH YLOW YHIGH
    // =========================================================

    task receive_result_packet;

        begin

            $display("");
            $display(
                "[%0t] Waiting for 7-byte result packet...",
                $time
            );


            for (byte_index = 0;
                 byte_index < 7;
                 byte_index = byte_index + 1) begin

                uart_receive_byte(rx_byte);

                packet[byte_index] = rx_byte;

                $display(
                    "    TX[%0d] = %02h",
                    byte_index,
                    rx_byte
                );

            end


            // -------------------------------------------------
            // HEADER CHECK
            // -------------------------------------------------

            if ((packet[0] !== 8'hAA) ||
                (packet[1] !== 8'h55)) begin

                $display(
                    "FAIL: invalid result header: %02h %02h",
                    packet[0],
                    packet[1]
                );

                errors = errors + 1;

            end
            else begin

                $display(
                    "PASS: result packet header valid"
                );

            end

        end

    endtask


    // =========================================================
    // TEMPORARY COORDINATE DEBUG
    // =========================================================
    // This block ONLY observes internal DUT signals.
    // It does not drive or modify any DUT signal.
    // Remove this block after coordinate debugging is complete.

    always @(posedge dut.frame_controller.frame_done) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: FRAME DONE ********");
        $display("Frame Controller:");
        $display("  motion_flag = %0d", dut.frame_controller.motion_flag);
        $display("  suspect_x   = %0d", dut.frame_controller.suspect_x);
        $display("  suspect_y   = %0d", dut.frame_controller.suspect_y);
        $display("  min_x/max_x = %0d / %0d",
                 dut.frame_controller.min_x,
                 dut.frame_controller.max_x);
        $display("  min_y/max_y = %0d / %0d",
                 dut.frame_controller.min_y,
                 dut.frame_controller.max_y);
        $display("  motion_count= %0d", dut.frame_controller.motion_count);
        $display("***********************************************");
    end

    always @(posedge dut.controller.roi_start) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: ROI START *********");
        $display("  motion_x = %0d", dut.controller.motion_x);
        $display("  motion_y = %0d", dut.controller.motion_y);
        $display("  active_x = %0d", dut.controller.active_x);
        $display("  active_y = %0d", dut.controller.active_y);
        $display("***********************************************");
    end

    always @(posedge dut.roi_extractor.done) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: ROI DONE **********");
        $display("  ROI source center = (%0d,%0d)",
                 dut.roi_extractor.center_x,
                 dut.roi_extractor.center_y);
        $display("  ROI left/top      = (%0d,%0d)",
                 dut.roi_extractor.left,
                 dut.roi_extractor.top);
        $display("***********************************************");
    end

    always @(posedge dut.controller.cnn_start) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: CNN START *********");
        $display("  active_x = %0d", dut.controller.active_x);
        $display("  active_y = %0d", dut.controller.active_y);
        $display("***********************************************");
    end

    always @(posedge dut.controller.cnn_done) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: CNN DONE **********");
        $display("  cnn_locked = %0d", dut.controller.cnn_locked);
        $display("  active_x   = %0d", dut.controller.active_x);
        $display("  active_y   = %0d", dut.controller.active_y);
        $display("***********************************************");
    end

    always @(posedge dut.controller.sad_start) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: SAD START *********");
        $display("  SAD start_x = %0d", dut.tracker.start_x);
        $display("  SAD start_y = %0d", dut.tracker.start_y);
        $display("***********************************************");
    end

    always @(posedge dut.tracker.tracking_done) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: SAD DONE **********");
        $display("  SAD new_x       = %0d", dut.tracker.new_x);
        $display("  SAD new_y       = %0d", dut.tracker.new_y);
        $display("  target_lost     = %0d", dut.tracker.target_lost);
        $display("  sad_center      = %0d", dut.tracker.sad_center);
        $display("  sad_up          = %0d", dut.tracker.sad_up);
        $display("  sad_down        = %0d", dut.tracker.sad_down);
        $display("  sad_left        = %0d", dut.tracker.sad_left);
        $display("  sad_right       = %0d", dut.tracker.sad_right);
        $display("***********************************************");
    end

    always @(posedge dut.controller.result_valid) begin
        #1;
        $display("");
        $display("******** COORDINATE DEBUG: FINAL REPORT ******");
        $display("  target_locked = %0d", dut.controller.target_locked);
        $display("  active_x      = %0d", dut.controller.active_x);
        $display("  active_y      = %0d", dut.controller.active_y);
        $display("***********************************************");
    end

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin

        // -----------------------------------------------------
        // INITIAL VALUES
        // -----------------------------------------------------

        clk         = 1'b0;
        reset       = 1'b1;
        uart_rx_pin = 1'b1;

        errors = 0;


        // -----------------------------------------------------
        // TEST INFORMATION
        // -----------------------------------------------------

        $display("");
        $display("============================================================");
        $display(" VAJRA DRISHTI - FULL UART TOP INTEGRATION TEST");
        $display(" Clock       : %0d Hz", CLK_FREQ);
        $display(" Test baud   : %0d baud", BAUD);
        $display(" Bit clocks  : %0d", BIT_CLKS);
        $display(" Bit time    : 50 ns");
        $display(" Frame       : %0dx%0d = %0d pixels",
                 WIDTH,
                 HEIGHT,
                 NPIX);
        $display("============================================================");
        $display("");


        // -----------------------------------------------------
        // RESET
        // -----------------------------------------------------

        repeat (20)
            @(posedge clk);

        reset = 1'b0;


        // =====================================================
        // FRAME 1
        // =====================================================

        send_frame(1);

        receive_result_packet();


        // -----------------------------------------------------
        // FRAME 1 MUST HAVE LOCK = 0
        // -----------------------------------------------------

        if (packet[2] !== 8'h00) begin

            $display(
                "FAIL: frame 1 should not be locked. LOCK=%02h",
                packet[2]
            );

            errors = errors + 1;

        end
        else begin

            $display(
                "PASS: frame 1 reports LOCK=0"
            );

        end


        // =====================================================
        // FRAME 2
        // =====================================================

        send_frame(2);

        receive_result_packet();


        // -----------------------------------------------------
        // DECODE RESULT
        // -----------------------------------------------------

        $display("");
        $display("Decoded result:");

        $display(
            "  LOCK = %0d",
            packet[2]
        );

        $display(
            "  X    = %0d",
            {packet[4], packet[3]}
        );

        $display(
            "  Y    = %0d",
            {packet[6], packet[5]}
        );

        $display(
            "  PWM  = pan=%b tilt=%b",
            pwm_pan,
            pwm_tilt
        );


        // -----------------------------------------------------
        // LOCK MUST BE 0 OR 1
        // -----------------------------------------------------

        if ((packet[2] === 8'h00) ||
            (packet[2] === 8'h01)) begin

            $display(
                "PASS: frame 2 returned a legal LOCK value"
            );

        end
        else begin

            $display(
                "FAIL: illegal LOCK byte %02h",
                packet[2]
            );

            errors = errors + 1;

        end


        // =====================================================
        // FINAL RESULT
        // =====================================================

        $display("");
        $display("============================================================");

        if (errors == 0) begin

            $display(
                " FULL UART TOP INTEGRATION PASS"
            );

        end
        else begin

            $display(
                " FULL UART TOP INTEGRATION FAIL: %0d error(s)",
                errors
            );

        end

        $display("============================================================");
        $display("");


        $finish;

    end

endmodule