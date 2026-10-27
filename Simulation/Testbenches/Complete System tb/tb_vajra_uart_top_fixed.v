`timescale 1ns / 1ps

/*
 * Vajra Drishti - FULL UART TOP INTEGRATION TESTBENCH
 *
 * Purpose:
 *   1. Send a complete 640x480 frame through UART RX.
 *   2. Verify frame 1 produces LOCK=0.
 *   3. Send frame 2 containing a 32x32 bright target.
 *   4. Verify the ROI BRAM contains the expected 32x32 crop.
 *   5. Verify the final UART result packet.
 *
 * IMPORTANT:
 *   The DUT RTL is NOT modified.
 *
 * The internal ROI memory is checked using the ACTUAL hierarchy
 * from vajra_uart_top.v:
 *
 *   dut
 *    └── roi_memory
 *         └── memory_array
 *
 * ROI expected for target center (320,240):
 *   target pixels: x=304..335, y=224..255
 *   ROI left/top : x=303, y=223
 *   ROI range    : x=303..334, y=223..254
 *
 * Therefore:
 *   961 pixels = 0xE0  (31x31 overlap)
 *    63 pixels = 0x10  (remaining border)
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

    // Expected ROI
    localparam integer ROI_LEFT = TARGET_X - 17;   // 303
    localparam integer ROI_TOP  = TARGET_Y - 17;   // 223

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

    integer errors;
    integer x;
    integer y;
    integer pixel;
    integer bit_index;
    integer byte_index;

    integer roi_index;
    integer roi_x;
    integer roi_y;
    integer roi_e0_count;
    integer roi_10_count;
    integer roi_other_count;
    integer roi_expected_e0;
    integer roi_expected_10;

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
    // CLOCK
    // =========================================================

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================
    // UART SEND BYTE
    // 8N1, 5 clocks/bit
    // =========================================================

    task uart_send_byte;
        input [7:0] b;
        integer k;
        begin
            // START
            uart_rx_pin = 1'b0;
            repeat (BIT_CLKS) @(posedge clk);

            // DATA, LSB first
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx_pin = b[k];
                repeat (BIT_CLKS) @(posedge clk);
            end

            // STOP
            uart_rx_pin = 1'b1;
            repeat (BIT_CLKS) @(posedge clk);
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
            if (frame_id == 1) begin
                b = 8'h10;
            end
            else begin
                if ((px >= TARGET_X - 16) &&
                    (px <  TARGET_X + 16) &&
                    (py >= TARGET_Y - 16) &&
                    (py <  TARGET_Y + 16))
                    b = 8'hE0;
                else
                    b = 8'h10;
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
            $display("[%0t] Sending frame %0d ...", $time, frame_id);

            // Header
            uart_send_byte(8'hAA);
            uart_send_byte(8'h55);

            // 640x480 pixels
            for (pixel = 0; pixel < NPIX; pixel = pixel + 1) begin
                x = pixel % WIDTH;
                y = pixel / WIDTH;

                make_frame_byte(frame_id, x, y, tx_frame_byte);
                uart_send_byte(tx_frame_byte);

                if ((pixel % 50000) == 0)
                    $display("    frame %0d progress: %0d / %0d pixels",
                             frame_id, pixel, NPIX);
            end

            $display("[%0t] Frame %0d transmitted.", $time, frame_id);
        end
    endtask

    // =========================================================
    // UART RECEIVE BYTE
    //
    // TX is idle-high. Wait for TX start bit, then sample:
    //   1.5 bit times -> D0 center
    //   1 bit time    -> each next data bit
    // =========================================================

    task uart_receive_byte;
        output [7:0] b;
        integer k;
        integer wait_count;
        begin
            b = 8'h00;
            wait_count = 0;

            while (uart_tx_pin !== 1'b0) begin
                @(posedge clk);
                wait_count = wait_count + 1;

                if (wait_count >= 5_000_000) begin
                    $display("FAIL: timeout waiting for UART TX start bit");
                    errors = errors + 1;
                    b = 8'h00;
                    disable uart_receive_byte;
                end
            end

            // 1.5 bit periods = 75 ns
            #75;

            // Sample 8 data bits
            for (k = 0; k < 8; k = k + 1) begin
                b[k] = uart_tx_pin;
                #50;
            end

            // Half of stop bit
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
            $display("[%0t] Waiting for 7-byte result packet...", $time);

            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1) begin
                uart_receive_byte(rx_byte);
                packet[byte_index] = rx_byte;

                $display("    TX[%0d] = %02h", byte_index, rx_byte);
            end

            if ((packet[0] !== 8'hAA) ||
                (packet[1] !== 8'h55)) begin
                $display("FAIL: invalid result header: %02h %02h",
                         packet[0], packet[1]);
                errors = errors + 1;
            end
            else begin
                $display("PASS: result packet header valid");
            end
        end
    endtask

    // =========================================================
    // CHECK ROI BRAM
    //
    // ACTUAL hierarchy from supplied vajra_uart_top.v:
    //
    //     dut.roi_memory.memory_array[index]
    //
    // No guessed roi_bram_inst name is used.
    // =========================================================

    task check_roi_bram;
        begin
            $display("");
            $display("============================================================");
            $display(" ROI BRAM CHECK");
            $display(" Expected ROI left/top = (%0d,%0d)",
                     ROI_LEFT, ROI_TOP);
            $display(" Expected contents     = 961 x E0 + 63 x 10");
            $display("============================================================");

            roi_e0_count    = 0;
            roi_10_count    = 0;
            roi_other_count = 0;

            for (roi_index = 0; roi_index < 1024; roi_index = roi_index + 1) begin
                if (dut.roi_memory.memory_array[roi_index] === 8'hE0)
                    roi_e0_count = roi_e0_count + 1;
                else if (dut.roi_memory.memory_array[roi_index] === 8'h10)
                    roi_10_count = roi_10_count + 1;
                else
                    roi_other_count = roi_other_count + 1;
            end

            $display("ROI BRAM counts:");
            $display("  E0    = %0d", roi_e0_count);
            $display("  10    = %0d", roi_10_count);
            $display("  OTHER = %0d", roi_other_count);

            if (roi_e0_count == 961)
                $display("PASS: ROI E0 count is exactly 961");
            else begin
                $display("FAIL: ROI E0 count expected 961, got %0d",
                         roi_e0_count);
                errors = errors + 1;
            end

            if (roi_10_count == 63)
                $display("PASS: ROI 10 count is exactly 63");
            else begin
                $display("FAIL: ROI 10 count expected 63, got %0d",
                         roi_10_count);
                errors = errors + 1;
            end

            if (roi_other_count == 0)
                $display("PASS: ROI contains no unexpected pixel values");
            else begin
                $display("FAIL: ROI contains %0d unexpected values",
                         roi_other_count);
                errors = errors + 1;
            end

            // -------------------------------------------------
            // Check a few exact addresses.
            //
            // ROI is row-major:
            // address = row*32 + column
            // -------------------------------------------------

            // Top-left ROI pixel = source (303,223), background
            if (dut.roi_memory.memory_array[0] !== 8'h10) begin
                $display("FAIL: ROI[0] expected 10, got %02h",
                         dut.roi_memory.memory_array[0]);
                errors = errors + 1;
            end
            else
                $display("PASS: ROI[0] = 10");

            // ROI address 1,1 corresponds to source (304,224),
            // which is inside the 32x32 target.
            if (dut.roi_memory.memory_array[33] !== 8'hE0) begin
                $display("FAIL: ROI[33] expected E0, got %02h",
                         dut.roi_memory.memory_array[33]);
                errors = errors + 1;
            end
            else
                $display("PASS: ROI[33] = E0");

            // ROI[1023] = source (334,254), inside target.
            if (dut.roi_memory.memory_array[1023] !== 8'hE0) begin
                $display("FAIL: ROI[1023] expected E0, got %02h",
                         dut.roi_memory.memory_array[1023]);
                errors = errors + 1;
            end
            else
                $display("PASS: ROI[1023] = E0");

            $display("============================================================");
        end
    endtask

    // =========================================================
    // MAIN TEST
    // =========================================================

    initial begin
        clk         = 1'b0;
        reset       = 1'b1;
        uart_rx_pin = 1'b1;
        errors      = 0;

        $display("");
        $display("============================================================");
        $display(" VAJRA DRISHTI - FULL UART TOP INTEGRATION TEST");
        $display(" Clock       : %0d Hz", CLK_FREQ);
        $display(" Test baud   : %0d baud", BAUD);
        $display(" Bit clocks  : %0d", BIT_CLKS);
        $display(" Bit time    : 50 ns");
        $display(" Frame       : %0dx%0d = %0d pixels",
                 WIDTH, HEIGHT, NPIX);
        $display(" Target      : center=(%0d,%0d), size=32x32",
                 TARGET_X, TARGET_Y);
        $display("============================================================");
        $display("");

        // Reset
        repeat (20) @(posedge clk);
        reset = 1'b0;

        // =====================================================
        // FRAME 1 - STATIC BACKGROUND
        // =====================================================

        send_frame(1);
        receive_result_packet();

        if (packet[2] !== 8'h00) begin
            $display("FAIL: frame 1 should not be locked. LOCK=%02h",
                     packet[2]);
            errors = errors + 1;
        end
        else
            $display("PASS: frame 1 reports LOCK=0");

        // =====================================================
        // FRAME 2 - MOVING 32x32 TARGET
        // =====================================================

        send_frame(2);
        receive_result_packet();

        // The ROI must have been extracted before the result packet
        // is generated, so the BRAM is stable here.
        check_roi_bram();

        // Decode packet
        $display("");
        $display("Decoded frame 2 result:");
        $display("  LOCK = %0d", packet[2]);
        $display("  X    = %0d", {packet[4], packet[3]});
        $display("  Y    = %0d", {packet[6], packet[5]});
        $display("  PWM  = pan=%b tilt=%b", pwm_pan, pwm_tilt);

        // LOCK must be a real binary value.
        if ((packet[2] === 8'h00) || (packet[2] === 8'h01))
            $display("PASS: frame 2 returned a legal LOCK value");
        else begin
            $display("FAIL: illegal LOCK byte %02h", packet[2]);
            errors = errors + 1;
        end

        // Since motion center is expected to be approximately 319,239
        // after bounding-box integer averaging, check the coordinates
        // are at least inside the target/ROI neighborhood.
        if (({packet[4], packet[3]} >= 300) &&
            ({packet[4], packet[3]} <= 340) &&
            ({packet[6], packet[5]} >= 220) &&
            ({packet[6], packet[5]} <= 260))
            $display("PASS: frame 2 reported coordinates are in target neighborhood");
        else begin
            $display("FAIL: frame 2 coordinates are outside expected neighborhood");
            errors = errors + 1;
        end

        // =====================================================
        // FINAL RESULT
        // =====================================================

        $display("");
        $display("============================================================");

        if (errors == 0)
            $display(" FULL UART TOP + ROI INTEGRATION PASS");
        else
            $display(" FULL UART TOP + ROI INTEGRATION FAIL: %0d error(s)",
                     errors);

        $display("============================================================");
        $display("");

        $finish;
    end

endmodule
