`timescale 1ns / 1ps

// Two-step SAD datapath:
//   DIFF: register absolute pixel difference and associated metadata.
//   ACCUM: add the registered difference to the running SAD.
//
// Interface is unchanged from the original sad_tracker.
// Assumption: template_pixel and search_pixel are valid after the FETCH
// state has allowed the memory/address interface to settle. This matches
// the original FSM's FETCH -> ACCUM sequencing.

module sad_tracker (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [9:0]  start_x,
    input  wire [9:0]  start_y,
    output wire [9:0]  template_addr,
    input  wire [7:0]  template_pixel,
    output wire [18:0] search_addr,
    input  wire [7:0]  search_pixel,
    output reg  [9:0]  new_x,
    output reg  [9:0]  new_y,
    output reg         tracking_done,
    output reg         target_lost
);

    localparam integer SEARCH_STEP = 5;
    localparam [17:0] SAD_THRESHOLD = 18'd40000;

    localparam [2:0] IDLE      = 3'd0,
                     PREP_BASE = 3'd1,
                     PREP_ADDR = 3'd2,
                     FETCH     = 3'd3,
                     DIFF      = 3'd4,
                     ACCUM     = 3'd5,
                     NEXT_DIR  = 3'd6,
                     DECIDE    = 3'd7;

    localparam [2:0] CENTER = 3'd0,
                     UP     = 3'd1,
                     DOWN   = 3'd2,
                     LEFT   = 3'd3,
                     RIGHT  = 3'd4;

    reg [2:0] state;
    reg [2:0] current_dir;
    reg [9:0] pixel_idx;
    reg signed [10:0] offset_x, offset_y;

    reg [17:0] current_sum;
    reg [17:0] sad_center, sad_up, sad_down, sad_left, sad_right;

    wire [4:0] dx = pixel_idx[4:0];

    reg signed [11:0] raw_base_x;
    reg signed [11:0] raw_base_y;
    reg [9:0] base_x_comb;
    reg [9:0] base_y_comb;
    reg [9:0] base_x_reg;
    reg [9:0] base_y_reg;

    always @(*) begin
        raw_base_x = $signed({1'b0, start_x}) - 12'sd16 + offset_x;
        raw_base_y = $signed({1'b0, start_y}) - 12'sd16 + offset_y;

        if (raw_base_x < 0)
            base_x_comb = 10'd0;
        else if (raw_base_x > 12'sd608)
            base_x_comb = 10'd608;
        else
            base_x_comb = raw_base_x[9:0];

        if (raw_base_y < 0)
            base_y_comb = 10'd0;
        else if (raw_base_y > 12'sd448)
            base_y_comb = 10'd448;
        else
            base_y_comb = raw_base_y[9:0];
    end

    reg [18:0] search_addr_reg;
    assign search_addr = search_addr_reg;
    assign template_addr = pixel_idx;

    wire [7:0] abs_diff =
        (search_pixel >= template_pixel)
        ? (search_pixel - template_pixel)
        : (template_pixel - search_pixel);

    // Pipeline register for the difference.
    reg [7:0] diff_reg;

    function [9:0] clamp_center_x;
        input signed [11:0] v;
        begin
            if (v < 0) clamp_center_x = 10'd0;
            else if (v > 12'sd639) clamp_center_x = 10'd639;
            else clamp_center_x = v[9:0];
        end
    endfunction

    function [9:0] clamp_center_y;
        input signed [11:0] v;
        begin
            if (v < 0) clamp_center_y = 10'd0;
            else if (v > 12'sd479) clamp_center_y = 10'd479;
            else clamp_center_y = v[9:0];
        end
    endfunction

    reg signed [11:0] candidate_x;
    reg signed [11:0] candidate_y;

    always @(posedge clk) begin
        if (reset) begin
            state           <= IDLE;
            current_dir     <= CENTER;
            pixel_idx       <= 10'd0;
            offset_x        <= 11'sd0;
            offset_y        <= 11'sd0;
            base_x_reg      <= 10'd0;
            base_y_reg      <= 10'd0;
            search_addr_reg <= 19'd0;
            current_sum     <= 18'd0;
            sad_center      <= 18'd0;
            sad_up          <= 18'd0;
            sad_down        <= 18'd0;
            sad_left        <= 18'd0;
            sad_right       <= 18'd0;
            diff_reg        <= 8'd0;
            new_x           <= 10'd320;
            new_y           <= 10'd240;
            tracking_done   <= 1'b0;
            target_lost     <= 1'b0;
            candidate_x     <= 12'sd0;
            candidate_y     <= 12'sd0;
        end else begin
            tracking_done <= 1'b0;

            case (state)
                IDLE: begin
                    target_lost <= 1'b0;
                    if (enable) begin
                        current_dir <= CENTER;
                        pixel_idx   <= 10'd0;
                        current_sum <= 18'd0;
                        offset_x    <= 11'sd0;
                        offset_y    <= 11'sd0;
                        sad_center  <= 18'd0;
                        sad_up      <= 18'd0;
                        sad_down    <= 18'd0;
                        sad_left    <= 18'd0;
                        sad_right   <= 18'd0;
                        state       <= PREP_BASE;
                    end
                end

                PREP_BASE: begin
                    base_x_reg <= base_x_comb;
                    base_y_reg <= base_y_comb;
                    state      <= PREP_ADDR;
                end

                PREP_ADDR: begin
                    search_addr_reg <= (base_y_reg * 19'd640) + base_x_reg;
                    pixel_idx       <= 10'd0;
                    state           <= FETCH;
                end

                // Allow the pixel memory/address interface to settle.
                FETCH: state <= DIFF;

                // Pipeline stage 1: compute and register absolute difference.
                DIFF: begin
                    diff_reg <= abs_diff;
                    state    <= ACCUM;
                end

                // Pipeline stage 2: accumulate the previously registered diff.
                ACCUM: begin
                    current_sum <= current_sum + {10'd0, diff_reg};

                    if (pixel_idx == 10'd1023) begin
                        case (current_dir)
                            CENTER: sad_center <= current_sum + {10'd0, diff_reg};
                            UP:     sad_up     <= current_sum + {10'd0, diff_reg};
                            DOWN:   sad_down   <= current_sum + {10'd0, diff_reg};
                            LEFT:   sad_left   <= current_sum + {10'd0, diff_reg};
                            RIGHT:  sad_right  <= current_sum + {10'd0, diff_reg};
                            default: begin end
                        endcase
                        state <= NEXT_DIR;
                    end else begin
                        if (dx == 5'd31)
                            search_addr_reg <= search_addr_reg + 19'd609;
                        else
                            search_addr_reg <= search_addr_reg + 19'd1;

                        pixel_idx <= pixel_idx + 10'd1;
                        state     <= FETCH;
                    end
                end

                NEXT_DIR: begin
                    pixel_idx   <= 10'd0;
                    current_sum <= 18'd0;

                    if (current_dir == CENTER) begin
                        current_dir <= UP;
                        offset_x    <= 11'sd0;
                        offset_y    <= -11'sd5;
                        state       <= PREP_BASE;
                    end else if (current_dir == UP) begin
                        current_dir <= DOWN;
                        offset_x    <= 11'sd0;
                        offset_y    <= 11'sd5;
                        state       <= PREP_BASE;
                    end else if (current_dir == DOWN) begin
                        current_dir <= LEFT;
                        offset_x    <= -11'sd5;
                        offset_y    <= 11'sd0;
                        state       <= PREP_BASE;
                    end else if (current_dir == LEFT) begin
                        current_dir <= RIGHT;
                        offset_x    <= 11'sd5;
                        offset_y    <= 11'sd0;
                        state       <= PREP_BASE;
                    end else begin
                        state <= DECIDE;
                    end
                end

                DECIDE: begin
                    new_x <= start_x;
                    new_y <= start_y;

                    if (sad_center <= sad_up &&
                        sad_center <= sad_down &&
                        sad_center <= sad_left &&
                        sad_center <= sad_right) begin
                        if (sad_center > SAD_THRESHOLD)
                            target_lost <= 1'b1;
                    end else if (sad_up <= sad_down &&
                                 sad_up <= sad_left &&
                                 sad_up <= sad_right) begin
                        if (sad_up > SAD_THRESHOLD)
                            target_lost <= 1'b1;
                        candidate_x = $signed({1'b0, start_x});
                        candidate_y = $signed({1'b0, start_y}) - SEARCH_STEP;
                        new_x <= clamp_center_x(candidate_x);
                        new_y <= clamp_center_y(candidate_y);
                    end else if (sad_down <= sad_left && sad_down <= sad_right) begin
                        if (sad_down > SAD_THRESHOLD)
                            target_lost <= 1'b1;
                        candidate_x = $signed({1'b0, start_x});
                        candidate_y = $signed({1'b0, start_y}) + SEARCH_STEP;
                        new_x <= clamp_center_x(candidate_x);
                        new_y <= clamp_center_y(candidate_y);
                    end else if (sad_left <= sad_right) begin
                        if (sad_left > SAD_THRESHOLD)
                            target_lost <= 1'b1;
                        candidate_x = $signed({1'b0, start_x}) - SEARCH_STEP;
                        candidate_y = $signed({1'b0, start_y});
                        new_x <= clamp_center_x(candidate_x);
                        new_y <= clamp_center_y(candidate_y);
                    end else begin
                        if (sad_right > SAD_THRESHOLD)
                            target_lost <= 1'b1;
                        candidate_x = $signed({1'b0, start_x}) + SEARCH_STEP;
                        candidate_y = $signed({1'b0, start_y});
                        new_x <= clamp_center_x(candidate_x);
                        new_y <= clamp_center_y(candidate_y);
                    end

                    tracking_done <= 1'b1;
                    state         <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
