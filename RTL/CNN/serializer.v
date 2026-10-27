`timescale 1ns / 1ps

module serializer #(
    parameter integer FIFO_DEPTH = 128
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid_in,

    input  wire [7:0]  p0,
    input  wire [7:0]  p1,
    input  wire [7:0]  p2,
    input  wire [7:0]  p3,

    output reg         valid_out,
    output reg  [7:0]  pixel_out
);

    // ============================================================
    // FIFO
    //
    // Each entry contains one spatial location from all
    // four convolution channels:
    //
    //     {p0,p1,p2,p3}
    //
    // Pooling produces one such batch every ~2 clocks.
    // Dense consumes one feature every clock.
    // ============================================================

    reg [31:0] fifo_mem [0:FIFO_DEPTH-1];

    reg [6:0] wr_ptr;
    reg [6:0] rd_ptr;

    reg [7:0] fifo_count;

    // ============================================================
    // Currently serialized batch
    // ============================================================

    reg [31:0] batch_reg;

    localparam STATE_IDLE = 2'd0;
    localparam STATE_P1   = 2'd1;
    localparam STATE_P2   = 2'd2;
    localparam STATE_P3   = 2'd3;

    reg [1:0] state;

    wire fifo_empty;
    wire fifo_full;

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full  = (fifo_count == FIFO_DEPTH);

    // Serializer can pop a new batch only while idle.
    wire pop_batch =
        (state == STATE_IDLE) &&
        !fifo_empty;

    // Allow simultaneous push/pop when FIFO is full.
    wire push_batch =
        valid_in &&
        (!fifo_full || pop_batch);

    // ============================================================
    // Main logic
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            wr_ptr     <= 7'd0;
            rd_ptr     <= 7'd0;
            fifo_count <= 8'd0;

            batch_reg  <= 32'd0;

            state      <= STATE_IDLE;

            valid_out  <= 1'b0;
            pixel_out  <= 8'd0;

        end
        else begin

            // Default
            valid_out <= 1'b0;

            // ====================================================
            // PUSH
            // ====================================================

            if (push_batch) begin

                fifo_mem[wr_ptr] <= {p0,p1,p2,p3};

                if (wr_ptr == FIFO_DEPTH-1)
                    wr_ptr <= 7'd0;
                else
                    wr_ptr <= wr_ptr + 1'b1;

            end

            // ====================================================
            // POP
            // ====================================================

            if (pop_batch) begin

                batch_reg <= fifo_mem[rd_ptr];

                pixel_out <= fifo_mem[rd_ptr][31:24];
                valid_out <= 1'b1;

                if (rd_ptr == FIFO_DEPTH-1)
                    rd_ptr <= 7'd0;
                else
                    rd_ptr <= rd_ptr + 1'b1;

                state <= STATE_P1;

            end

            // ====================================================
            // FIFO COUNT
            // ====================================================

            case ({push_batch,pop_batch})

                2'b10:
                    fifo_count <= fifo_count + 1'b1;

                2'b01:
                    fifo_count <= fifo_count - 1'b1;

                default:
                    fifo_count <= fifo_count;

            endcase

            // ====================================================
            // Serialize remaining three channels
            // ====================================================

            case (state)

                STATE_IDLE: begin
                    // Nothing to do.
                end

                STATE_P1: begin

                    pixel_out <= batch_reg[23:16];
                    valid_out <= 1'b1;

                    state <= STATE_P2;

                end

                STATE_P2: begin

                    pixel_out <= batch_reg[15:8];
                    valid_out <= 1'b1;

                    state <= STATE_P3;

                end

                STATE_P3: begin

                    pixel_out <= batch_reg[7:0];
                    valid_out <= 1'b1;

                    state <= STATE_IDLE;

                end

                default: begin
                    state <= STATE_IDLE;
                end

            endcase
        end
    end

endmodule