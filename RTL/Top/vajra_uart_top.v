`timescale 1ns / 1ps

module vajra_uart_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 921600
)(
    input wire clk,
    input wire reset,

    input wire uart_rx_pin,
    output wire uart_tx_pin,

    output wire pwm_pan,
    output wire pwm_tilt,
    output wire system_state_led
);

    // =========================================================
    // 1. UART
    // =========================================================
    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_pin),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    wire [7:0] tx_data;
    wire tx_start;
    wire tx_busy;

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .reset(reset),
        .data_in(tx_data),
        .start(tx_start),
        .tx(uart_tx_pin),
        .busy(tx_busy)
    );

    // =========================================================
    // 2. ONE 640x480 FRAME BUFFER
    // =========================================================
    reg [7:0] frame_buffer [0:307199];

    wire [18:0] rx_mem_addr;
    wire rx_mem_read_req;
    wire rx_mem_write_en;
    wire [7:0] rx_mem_write_data;
    wire [7:0] rx_mem_read_data;

    wire [18:0] roi_mem_addr;
    wire roi_mem_read_req;
    wire [7:0] roi_mem_read_data;

    wire [18:0] sad_mem_addr;
    wire [7:0] sad_mem_read_data;

    wire tracking_active;
    wire [9:0] active_x;
    wire [9:0] active_y;
    wire result_valid;
    wire target_locked;

    // Explicitly multiplex all consumers onto ONE physical read port.
    wire frame_mem_read_req =
        rx_mem_read_req | roi_mem_read_req | tracking_active;

    wire [18:0] frame_mem_read_addr =
        rx_mem_read_req  ? rx_mem_addr :
        roi_mem_read_req ? roi_mem_addr :
        tracking_active  ? sad_mem_addr :
        19'd0;

    reg [7:0] frame_mem_read_data;

    assign rx_mem_read_data  = frame_mem_read_data;
    assign roi_mem_read_data = frame_mem_read_data;
    assign sad_mem_read_data = frame_mem_read_data;

    always @(posedge clk) begin
        if (frame_mem_read_req)
            frame_mem_read_data <= frame_buffer[frame_mem_read_addr];

        if (rx_mem_write_en)
            frame_buffer[rx_mem_addr] <= rx_mem_write_data;
    end

    // =========================================================
    // 3. UART FRAME RECEIVER + MOTION
    // =========================================================
    wire frame_done;
    wire [9:0] motion_x, motion_y;
    wire motion_flag;

    uart_frame_controller frame_controller (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),

        .mem_addr(rx_mem_addr),
        .mem_read_req(rx_mem_read_req),
        .mem_write_en(rx_mem_write_en),
        .mem_write_data(rx_mem_write_data),
        .mem_read_data(rx_mem_read_data),

        .frame_done(frame_done),
        .suspect_x(motion_x),
        .suspect_y(motion_y),
        .motion_flag(motion_flag)
    );

    // =========================================================
    // 4. ROI EXTRACTION
    // =========================================================
    wire roi_start;
    wire roi_done;
    wire [9:0] roi_write_addr;
    wire [7:0] roi_pixel;
    wire roi_write_en;

    uart_roi_extractor roi_extractor (
        .clk(clk),
        .reset(reset),
        .start(roi_start),
        .center_x(motion_x),
        .center_y(motion_y),

        .frame_addr(roi_mem_addr),
        .frame_read_req(roi_mem_read_req),
        .frame_read_data(roi_mem_read_data),

        .roi_write_en(roi_write_en),
        .roi_write_addr(roi_write_addr),
        .roi_pixel(roi_pixel),
        .done(roi_done)
    );

    // =========================================================
    // 5. 32x32 ROI BRAM
    // =========================================================
    wire cnn_read_en;
    wire [9:0] cnn_read_addr;
    wire [7:0] cnn_read_data;

    wire [9:0] sad_template_addr;
    wire [7:0] sad_template_data;

    // CNN and SAD never run simultaneously, so one read port is enough.
    wire active_roi_read_en =
        tracking_active ? 1'b1 : cnn_read_en;

    wire [9:0] active_roi_read_addr =
        tracking_active ? sad_template_addr : cnn_read_addr;

    roi_bram roi_memory (
        .clk(clk),
        .write_en(roi_write_en),
        .write_addr(roi_write_addr),
        .data_in(roi_pixel),
        .read_en(active_roi_read_en),
        .read_addr(active_roi_read_addr),
        .data_out(cnn_read_data)
    );

    assign sad_template_data = cnn_read_data;

    // =========================================================
    // 6. CNN CONTROLLER + CNN CORE
    // =========================================================
    wire cnn_start;
    wire cnn_reset;
    wire cnn_valid;
    wire [7:0] cnn_pixel;
    wire cnn_done;
    wire cnn_locked;
    wire [31:0] cnn_score;

    uart_cnn_controller cnn_controller (
        .clk(clk),
        .reset(reset),
        .start(cnn_start),
        .cnn_reset(cnn_reset),

        .roi_read_en(cnn_read_en),
        .roi_read_addr(cnn_read_addr),
        .roi_read_data(cnn_read_data),

        .cnn_valid(cnn_valid),
        .cnn_pixel(cnn_pixel),

        .cnn_done(cnn_done),
        .result_seen()
    );

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
    // 7. SAD TRACKER
    // =========================================================
    wire sad_start;
    wire [9:0] tracked_x, tracked_y;
    wire tracking_done;
    wire target_lost;

    sad_tracker tracker (
        .clk(clk),
        .reset(reset),
        .enable(sad_start),

        .start_x(active_x),
        .start_y(active_y),

        .template_addr(sad_template_addr),
        .template_pixel(sad_template_data),

        .search_addr(sad_mem_addr),
        .search_pixel(sad_mem_read_data),

        .new_x(tracked_x),
        .new_y(tracked_y),

        .tracking_done(tracking_done),
        .target_lost(target_lost)
    );

    // =========================================================
    // 8. MASTER FSM
    // =========================================================
    uart_system_fsm controller (
        .clk(clk),
        .reset(reset),

        .frame_done(frame_done),
        .motion_flag(motion_flag),
        .motion_x(motion_x),
        .motion_y(motion_y),

        .roi_done(roi_done),

        .cnn_done(cnn_done),
        .cnn_locked(cnn_locked),

        .tracking_done(tracking_done),
        .target_lost(target_lost),
        .tracked_x(tracked_x),
        .tracked_y(tracked_y),

        .roi_start(roi_start),
        .cnn_start(cnn_start),
        .sad_start(sad_start),
        .result_valid(result_valid),

        .tracking_active(tracking_active),

        // Temporarily disconnected.
        // The LED is driven by the hardware heartbeat below.
        // .system_state_led(system_state_led),

        .active_x(active_x),
        .active_y(active_y),
        .target_locked(target_locked)
    );

    // =========================================================
    // 9. UART RESULT
    // =========================================================
    result_packetizer packetizer (
        .clk(clk),
        .reset(reset),
        .result_valid(result_valid),
        .target_locked(target_locked),
        .target_x(active_x),
        .target_y(active_y),
        .uart_busy(tx_busy),
        .tx_data(tx_data),
        .tx_start(tx_start)
    );

    // =========================================================
    // 10. SERVO PWM
    // =========================================================
    pwm_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) motors (
        .clk(clk),
        .reset(reset),
        .track_enable(target_locked),
        .target_x(active_x),
        .target_y(active_y),
        .pwm_pan(pwm_pan),
        .pwm_tilt(pwm_tilt)
    );

    // =========================================================
    // 11. TEMPORARY HARDWARE HEARTBEAT TEST
    // =========================================================
    //
    // This is ONLY for the first hardware bring-up.
    //
    // It proves that:
    //   - the FPGA is configured
    //   - the 100 MHz clock is reaching the RTL
    //   - the logic is actually running
    //   - the system_state_led pin is correctly constrained
    //
    // We intentionally do NOT use reset here.
    //
    // At 100 MHz, bit 25 changes state slowly enough to be
    // visibly observed as an LED blink.
    //

    reg [25:0] heartbeat_counter;

    always @(posedge clk) begin
        heartbeat_counter <= heartbeat_counter + 1'b1;
    end

    assign system_state_led = heartbeat_counter[25];

endmodule