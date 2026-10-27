`timescale 1ns / 1ps

module uart_system_fsm (
    input wire clk,
    input wire reset,

    input wire frame_done,
    input wire motion_flag,
    input wire [9:0] motion_x,
    input wire [9:0] motion_y,

    input wire roi_done,

    input wire cnn_done,
    input wire cnn_locked,

    input wire tracking_done,
    input wire target_lost,
    input wire [9:0] tracked_x,
    input wire [9:0] tracked_y,

    output reg roi_start,
    output reg cnn_start,
    output reg sad_start,
    output reg result_valid,

    output reg tracking_active,
    output reg system_state_led,

    output reg [9:0] active_x,
    output reg [9:0] active_y,
    output reg target_locked
);
    localparam [2:0] WAIT_FRAME=3'd0, ROI=3'd1, CNN=3'd2,
                     TRACK=3'd3, REPORT=3'd4;
    reg [2:0] state;

    always @(posedge clk) begin
        if (reset) begin
            state<=WAIT_FRAME;
            roi_start<=0;
            cnn_start<=0;
            sad_start<=0;
            result_valid<=0;
            tracking_active<=0;
            system_state_led<=0;
            active_x<=320;
            active_y<=240;
            target_locked<=0;
        end else begin
            roi_start<=0;
            cnn_start<=0;
            sad_start<=0;
            result_valid<=0;

            case(state)
                WAIT_FRAME: begin
                    tracking_active<=1'b0;

                    if(frame_done) begin
                        if(target_locked) begin
                            sad_start<=1'b1;
                            tracking_active<=1'b1;
                            state<=TRACK;
                        end else if(motion_flag) begin
                            active_x<=motion_x;
                            active_y<=motion_y;
                            roi_start<=1'b1;
                            state<=ROI;
                        end else begin
                            // Keep the PC/FPGA protocol synchronized even
                            // when this frame contains no motion.
                            state<=REPORT;
                        end
                    end
                end

                ROI: begin
                    if(roi_done) begin
                        cnn_start<=1'b1;
                        state<=CNN;
                    end
                end

                CNN: begin
                    if(cnn_done) begin
                        if(cnn_locked) begin
                            target_locked<=1'b1;
                            system_state_led<=1'b1;
                        end else begin
                            target_locked<=1'b0;
                            system_state_led<=1'b0;
                        end
                        // Wait one clock before reporting so the
                        // packetizer sees the newly updated decision.
                        state<=REPORT;
                    end
                end

                TRACK: begin
                    tracking_active<=1'b1;

                    if(tracking_done) begin
                        if(target_lost) begin
                            target_locked<=1'b0;
                            system_state_led<=1'b0;
                        end else begin
                            active_x<=tracked_x;
                            active_y<=tracked_y;
                            target_locked<=1'b1;
                            system_state_led<=1'b1;
                        end
                        state<=REPORT;
                    end
                end

                REPORT: begin
                    tracking_active<=1'b0;
                    result_valid<=1'b1;
                    state<=WAIT_FRAME;
                end

                default: state<=WAIT_FRAME;
            endcase
        end
    end
endmodule
