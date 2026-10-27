`timescale 1ns / 1ps

module uart_frame_controller #(
    parameter integer WIDTH  = 640,
    parameter integer HEIGHT = 480
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg  [18:0] mem_addr,
    output reg         mem_read_req,
    output reg         mem_write_en,
    output reg  [7:0]  mem_write_data,
    input  wire [7:0]  mem_read_data,

    output reg         frame_done,
    output reg  [9:0]  suspect_x,
    output reg  [9:0]  suspect_y,
    output reg         motion_flag
);

    localparam integer TOTAL = WIDTH * HEIGHT;

    localparam [2:0]
        WAIT_AA  = 3'd0,
        WAIT_55  = 3'd1,
        RECEIVE  = 3'd2,
        WAIT_MEM = 3'd3,
        DIFF     = 3'd4,
        PROCESS  = 3'd5,
        FINALIZE = 3'd6,
        DONE     = 3'd7;

    localparam [7:0] DIFF_THRESHOLD = 8'd25;
    localparam integer MIN_PIXELS = 50;

    reg [2:0] state;

    reg [18:0] pixel_count;
    reg [9:0] cur_x, cur_y;

    reg [9:0] min_x, max_x;
    reg [9:0] min_y, max_y;

    reg [18:0] motion_count;
    reg history_valid;

    reg [7:0] pending_pixel;
    reg [9:0] pending_x, pending_y;

    // Pipeline register for the absolute pixel difference.
    reg [7:0] diff_reg;

    // Absolute difference is calculated before being registered.
    wire [7:0] diff_comb;

    assign diff_comb =
        (pending_pixel >= mem_read_data)
        ? (pending_pixel - mem_read_data)
        : (mem_read_data - pending_pixel);

    // Motion detection uses the registered difference.
    wire motion_hit =
        history_valid && (diff_reg > DIFF_THRESHOLD);

    // ------------------------------------------------------------
    // Frame controller
    // ------------------------------------------------------------

    always @(posedge clk) begin
        if (reset) begin
            state           <= WAIT_AA;

            pixel_count     <= 19'd0;
            cur_x           <= 10'd0;
            cur_y           <= 10'd0;

            min_x           <= 10'd1023;
            max_x           <= 10'd0;
            min_y           <= 10'd1023;
            max_y           <= 10'd0;

            motion_count    <= 19'd0;
            history_valid   <= 1'b0;

            pending_pixel   <= 8'd0;
            pending_x       <= 10'd0;
            pending_y       <= 10'd0;

            diff_reg        <= 8'd0;

            mem_addr        <= 19'd0;
            mem_read_req    <= 1'b0;
            mem_write_en    <= 1'b0;
            mem_write_data  <= 8'd0;

            frame_done      <= 1'b0;

            suspect_x       <= 10'd320;
            suspect_y       <= 10'd240;
            motion_flag     <= 1'b0;

        end else begin
            // These outputs are pulses.
            mem_read_req <= 1'b0;
            mem_write_en <= 1'b0;
            frame_done   <= 1'b0;

            case (state)

                // ------------------------------------------------
                // Wait for frame-start byte AA.
                // ------------------------------------------------
                WAIT_AA: begin
                    if (rx_valid && rx_data == 8'hAA) begin
                        state <= WAIT_55;
                    end
                end

                // ------------------------------------------------
                // Wait for second frame-start byte 55.
                // ------------------------------------------------
                WAIT_55: begin
                    if (rx_valid) begin
                        if (rx_data == 8'h55) begin
                            state        <= RECEIVE;

                            pixel_count  <= 19'd0;
                            cur_x        <= 10'd0;
                            cur_y        <= 10'd0;

                            min_x        <= 10'd1023;
                            max_x        <= 10'd0;
                            min_y        <= 10'd1023;
                            max_y        <= 10'd0;

                            motion_count <= 19'd0;
                            motion_flag  <= 1'b0;

                            mem_addr     <= 19'd0;
                        end else begin
                            state <= WAIT_AA;
                        end
                    end
                end

                // ------------------------------------------------
                // Accept a new pixel and request the previous
                // pixel at the corresponding frame-buffer address.
                // ------------------------------------------------
                RECEIVE: begin
                    if (rx_valid) begin
                        pending_pixel <= rx_data;
                        pending_x     <= cur_x;
                        pending_y     <= cur_y;

                        mem_addr      <= pixel_count;
                        mem_read_req  <= 1'b1;

                        state         <= WAIT_MEM;
                    end
                end

                // ------------------------------------------------
                // Preserve the original memory-read wait state.
                // ------------------------------------------------
                WAIT_MEM: begin
                    state <= DIFF;
                end

                // ------------------------------------------------
                // Pipeline stage:
                // Register the absolute difference.
                // ------------------------------------------------
                DIFF: begin
                    diff_reg <= diff_comb;
                    state    <= PROCESS;
                end

                // ------------------------------------------------
                // Process the registered difference.
                // ------------------------------------------------
                PROCESS: begin
                    if (motion_hit) begin
                        motion_count <= motion_count + 19'd1;

                        if (pending_x < min_x)
                            min_x <= pending_x;

                        if (pending_x > max_x)
                            max_x <= pending_x;

                        if (pending_y < min_y)
                            min_y <= pending_y;

                        if (pending_y > max_y)
                            max_y <= pending_y;
                    end

                    // Write the received pixel into frame memory.
                    mem_write_en   <= 1'b1;
                    mem_write_data <= pending_pixel;
                    mem_addr       <= pixel_count;

                    if (pixel_count == TOTAL - 1) begin
                        state <= FINALIZE;
                    end else begin
                        pixel_count <= pixel_count + 19'd1;

                        if (cur_x == WIDTH - 1) begin
                            cur_x <= 10'd0;
                            cur_y <= cur_y + 10'd1;
                        end else begin
                            cur_x <= cur_x + 10'd1;
                        end

                        state <= RECEIVE;
                    end
                end

                // ------------------------------------------------
                // Evaluate the final frame results after all
                // PROCESS-cycle nonblocking assignments commit.
                // ------------------------------------------------
                FINALIZE: begin
                    frame_done <= 1'b1;

                    if (!history_valid) begin
                        suspect_x   <= 10'd320;
                        suspect_y   <= 10'd240;
                        motion_flag <= 1'b0;
                    end else if (motion_count >= MIN_PIXELS) begin
                        suspect_x <=
                            ({1'b0, min_x} + {1'b0, max_x}) >> 1;

                        suspect_y <=
                            ({1'b0, min_y} + {1'b0, max_y}) >> 1;

                        motion_flag <= 1'b1;
                    end else begin
                        suspect_x   <= 10'd320;
                        suspect_y   <= 10'd240;
                        motion_flag <= 1'b0;
                    end

                    history_valid <= 1'b1;
                    state         <= DONE;
                end

                // ------------------------------------------------
                // Frame processing complete.
                // ------------------------------------------------
                DONE: begin
                    state <= WAIT_AA;
                end

                default: begin
                    state <= WAIT_AA;
                end

            endcase
        end
    end

endmodule