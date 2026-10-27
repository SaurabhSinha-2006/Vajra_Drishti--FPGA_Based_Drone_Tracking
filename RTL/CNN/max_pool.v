`timescale 1ns / 1ps

module max_pool #(
    parameter integer WIDTH  = 30,
    parameter integer HEIGHT = 30
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       valid_in,
    input  wire [7:0] pixel_in,

    output reg        valid_out,
    output reg  [7:0] pixel_out
);

    // ============================================================
    // 2x2 MAX POOLING
    //
    // Input  : WIDTH x HEIGHT
    //          Default = 30 x 30
    //
    // Output : WIDTH/2 x HEIGHT/2
    //          Default = 15 x 15 = 225 values
    //
    // Stride = 2
    //
    // For a window:
    //
    //   A B
    //   C D
    //
    // output = max(A,B,C,D)
    // ============================================================

    reg [7:0] line_buf [0:WIDTH-1];

    // Previous pixel in current row
    reg [7:0] current_row_prev;

    // Previous pixel in previous row
    reg [7:0] previous_row_prev;

    reg [5:0] x_cnt;
    reg [5:0] y_cnt;

    integer i;

    // ============================================================
    // Values forming the current 2x2 window
    //
    // At the current pixel position (x,y):
    //
    // previous_row_prev = (x-1, y-1)
    // line_buf[WIDTH-1] = (x,   y-1)
    // current_row_prev  = (x-1, y)
    // pixel_in          = (x,   y)
    // ============================================================

    wire [7:0] a = previous_row_prev;
    wire [7:0] b = line_buf[WIDTH-1];
    wire [7:0] c = current_row_prev;
    wire [7:0] d = pixel_in;

    wire [7:0] max_ab =
        (a > b) ? a : b;

    wire [7:0] max_cd =
        (c > d) ? c : d;

    wire [7:0] max_window =
        (max_ab > max_cd) ? max_ab : max_cd;


    // ============================================================
    // Main logic
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            valid_out <= 1'b0;
            pixel_out <= 8'd0;

            x_cnt <= 6'd0;
            y_cnt <= 6'd0;

            current_row_prev  <= 8'd0;
            previous_row_prev <= 8'd0;

            for (i = 0; i < WIDTH; i = i + 1) begin
                line_buf[i] <= 8'd0;
            end

        end
        else begin

            valid_out <= 1'b0;

            if (valid_in) begin

                // =================================================
                // Generate output for every second pixel:
                //
                // x = 1,3,5,...,29
                // y = 1,3,5,...,29
                //
                // This gives:
                //
                // 15 x 15 = 225 outputs
                // =================================================

                if ((x_cnt[0] == 1'b1) &&
                    (y_cnt[0] == 1'b1)) begin

                    pixel_out <= max_window;
                    valid_out <= 1'b1;

                end


                // =================================================
                // Update horizontal history
                // =================================================

                previous_row_prev <= line_buf[WIDTH-1];

                current_row_prev <= pixel_in;


                // =================================================
                // Shift one-row line buffer
                //
                // After WIDTH clocks:
                // line_buf[WIDTH-1]
                // contains the pixel from the previous row
                // at the current column.
                // =================================================

                for (i = WIDTH-1; i > 0; i = i - 1) begin
                    line_buf[i] <= line_buf[i-1];
                end

                line_buf[0] <= pixel_in;


                // =================================================
                // Advance X/Y coordinates
                // =================================================

                if (x_cnt == WIDTH-1) begin

                    x_cnt <= 6'd0;

                    if (y_cnt == HEIGHT-1) begin
                        y_cnt <= 6'd0;
                    end
                    else begin
                        y_cnt <= y_cnt + 1'b1;
                    end

                end
                else begin

                    x_cnt <= x_cnt + 1'b1;

                end

            end
        end
    end

endmodule