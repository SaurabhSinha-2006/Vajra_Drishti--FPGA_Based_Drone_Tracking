`timescale 1ns / 1ps

module line_buffer #(
    parameter integer WIDTH = 32
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid_in,
    input  wire [7:0]  pixel_in,

    output reg         valid_out,
    output wire [71:0] window_out
);

    // ============================================================
    // 32x32 input image
    //
    // A valid 3x3 convolution window exists only when:
    //     row >= 2
    //     col >= 2
    //
    // Therefore:
    //     32x32 input  ->  30x30 valid windows = 900
    // ============================================================

    reg [7:0] line_buf_1 [0:WIDTH-1];
    reg [7:0] line_buf_2 [0:WIDTH-1];

    // 3x3 sliding window
    reg [7:0] p00, p01, p02;
    reg [7:0] p10, p11, p12;
    reg [7:0] p20, p21, p22;

    // Coordinates of the CURRENT incoming pixel.
    // 0..31 for both dimensions.
    reg [5:0] x_cnt;
    reg [5:0] y_cnt;

    integer i;

    // ============================================================
    // Flatten 3x3 window
    // ============================================================

    assign window_out = {
        p00, p01, p02,
        p10, p11, p12,
        p20, p21, p22
    };

    // ============================================================
    // Main logic
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            valid_out <= 1'b0;

            x_cnt <= 6'd0;
            y_cnt <= 6'd0;

            p00 <= 8'd0;
            p01 <= 8'd0;
            p02 <= 8'd0;

            p10 <= 8'd0;
            p11 <= 8'd0;
            p12 <= 8'd0;

            p20 <= 8'd0;
            p21 <= 8'd0;
            p22 <= 8'd0;

            for (i = 0; i < WIDTH; i = i + 1) begin
                line_buf_1[i] <= 8'd0;
                line_buf_2[i] <= 8'd0;
            end

        end
        else begin

            // Default: no valid convolution window.
            valid_out <= 1'b0;

            if (valid_in) begin

                // =================================================
                // Form the next 3x3 window.
                //
                // line_buf_2 = row-2
                // line_buf_1 = row-1
                // pixel_in    = current row
                // =================================================

                p00 <= p01;
                p01 <= p02;
                p02 <= line_buf_2[WIDTH-1];

                p10 <= p11;
                p11 <= p12;
                p12 <= line_buf_1[WIDTH-1];

                p20 <= p21;
                p21 <= p22;
                p22 <= pixel_in;

                // =================================================
                // Shift row delay buffers
                // =================================================

                for (i = WIDTH-1; i > 0; i = i - 1) begin
                    line_buf_1[i] <= line_buf_1[i-1];
                    line_buf_2[i] <= line_buf_2[i-1];
                end

                line_buf_1[0] <= pixel_in;
                line_buf_2[0] <= line_buf_1[WIDTH-1];

                // =================================================
                // IMPORTANT:
                //
                // The window becomes valid AFTER the current
                // registers have been updated.
                //
                // Therefore row >= 2 and col >= 2.
                // =================================================

                if ((x_cnt >= 2) && (y_cnt >= 2)) begin
                    valid_out <= 1'b1;
                end

                // =================================================
                // Advance input coordinates
                // =================================================

                if (x_cnt == WIDTH-1) begin
                    x_cnt <= 6'd0;

                    if (y_cnt == WIDTH-1)
                        y_cnt <= 6'd0;
                    else
                        y_cnt <= y_cnt + 1'b1;
                end
                else begin
                    x_cnt <= x_cnt + 1'b1;
                end

            end
        end
    end

endmodule