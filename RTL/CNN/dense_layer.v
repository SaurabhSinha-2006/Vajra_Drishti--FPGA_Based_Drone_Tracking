`timescale 1ns / 1ps

module dense_layer #(
    parameter integer MAX_WEIGHTS = 900,
    parameter integer THRESHOLD   = -150000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid_in,
    input  wire [7:0]  pixel_in,

    output reg         done,
    output reg         target_locked,
    output reg [31:0]  accumulator_out
);

    reg [9:0]  addr_cnt;
    reg [7:0]  pixel_delayed;
    reg        valid_delayed;
    reg signed [31:0] master_sum;

    wire signed [7:0] current_weight;
    wire signed [15:0] pixel_ext =
        $signed({8'd0, pixel_delayed});
    wire signed [15:0] weight_ext =
        $signed(current_weight);

    // Explicitly widen the multiply operands so the product does
    // not overflow at the native 8/9-bit expression width.
    wire signed [31:0] product =
        pixel_ext * weight_ext;

    wire signed [31:0] next_sum =
        master_sum + product;

    dense_weight_rom #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(8)
    ) weight_memory (
        .clk(clk),
        .ena(1'b1),
        .addr(addr_cnt),
        .dout(current_weight)
    );

    always @(posedge clk) begin
        if (reset) begin
            addr_cnt        <= 0;
            pixel_delayed   <= 0;
            valid_delayed   <= 0;
            master_sum      <= 0;
            done            <= 0;
            target_locked   <= 0;
            accumulator_out <= 0;
        end else begin
            done <= 1'b0;

            if (valid_in) begin
                addr_cnt      <= addr_cnt + 1'b1;
                pixel_delayed <= pixel_in;
                valid_delayed <= 1'b1;
            end else begin
                valid_delayed <= 1'b0;
            end

            if (valid_delayed) begin
                master_sum <= next_sum;

                // The 900th input is associated with weight 899.
                // addr_cnt has already advanced to 900 at this point.
                if (addr_cnt == MAX_WEIGHTS) begin
                    done <= 1'b1;

                    if (next_sum < $signed(THRESHOLD))
                        target_locked <= 1'b1;
                    else
                        target_locked <= 1'b0;

                    accumulator_out <= next_sum;

                    // Re-arm for a future ROI. The surrounding
                    // controller also supplies a clean CNN reset.
                    master_sum <= 0;
                    addr_cnt   <= 0;
                end
            end
        end
    end
endmodule
