`timescale 1ns / 1ps
module pwm_controller #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input wire clk,
    input wire reset,
    input wire track_enable,
    input wire [9:0] target_x,
    input wire [9:0] target_y,
    output reg pwm_pan,
    output reg pwm_tilt
);
    localparam integer PERIOD_CYCLES = CLK_FREQ_HZ / 50;
    localparam integer PULSE_MIN = CLK_FREQ_HZ / 1000;
    localparam integer PULSE_CENTER = CLK_FREQ_HZ * 3 / 2000;
    localparam integer PULSE_MAX = CLK_FREQ_HZ / 500;
    localparam integer STEP_SIZE = CLK_FREQ_HZ / 20000; // 0.05 ms

    localparam [9:0] X_CENTER=320, Y_CENTER=240, DEADZONE=40;

    reg [21:0] pwm_counter;
    reg [21:0] pan_width, tilt_width;

    always @(posedge clk) begin
        if(reset) begin
            pwm_counter<=0; pwm_pan<=0; pwm_tilt<=0;
        end else begin
            if(pwm_counter>=PERIOD_CYCLES-1) pwm_counter<=0;
            else pwm_counter<=pwm_counter+1;
            pwm_pan <= (pwm_counter<pan_width);
            pwm_tilt <= (pwm_counter<tilt_width);
        end
    end

    always @(posedge clk) begin
        if(reset || !track_enable) begin
            pan_width<=PULSE_CENTER;
            tilt_width<=PULSE_CENTER;
        end else if(pwm_counter==0) begin
            if(target_x > X_CENTER+DEADZONE) begin
                if(pan_width < PULSE_MAX) pan_width<=pan_width+STEP_SIZE;
            end else if(target_x < X_CENTER-DEADZONE) begin
                if(pan_width > PULSE_MIN) pan_width<=pan_width-STEP_SIZE;
            end

            if(target_y > Y_CENTER+DEADZONE) begin
                if(tilt_width < PULSE_MAX) tilt_width<=tilt_width+STEP_SIZE;
            end else if(target_y < Y_CENTER-DEADZONE) begin
                if(tilt_width > PULSE_MIN) tilt_width<=tilt_width-STEP_SIZE;
            end
        end
    end
endmodule
