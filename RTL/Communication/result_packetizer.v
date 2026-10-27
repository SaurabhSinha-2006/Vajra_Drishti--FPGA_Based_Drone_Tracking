`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Vajra Drishti - Result Packetizer
// -----------------------------------------------------------------------------
// Sends one complete result packet over the UART TX interface:
//
//   AA 55 LOCK X_LOW X_HIGH Y_LOW Y_HIGH
//
// The UART transmitter uses tx_start as a one-clock pulse and uart_busy to
// indicate that it is transmitting a byte.  IMPORTANT: after asserting
// tx_start, this module waits for uart_busy to go HIGH and then back LOW before
// sending the next byte.  This prevents every second byte from being lost.
// -----------------------------------------------------------------------------
module result_packetizer (
    input  wire       clk,
    input  wire       reset,
    input  wire       result_valid,
    input  wire       target_locked,
    input  wire [9:0] target_x,
    input  wire [9:0] target_y,
    input  wire       uart_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start
);

    // Main states.
    localparam [2:0]
        IDLE      = 3'd0,
        SEND      = 3'd1,
        WAIT_HIGH = 3'd2,
        WAIT_LOW  = 3'd3;

    reg [2:0] state;

    // Byte index:
    //   0 = AA
    //   1 = 55
    //   2 = LOCK
    //   3 = X_LOW
    //   4 = X_HIGH
    //   5 = Y_LOW
    //   6 = Y_HIGH
    reg [2:0] byte_index;

    // Latch the result so it remains stable throughout the complete packet.
    reg       lock_r;
    reg [9:0] x_r;
    reg [9:0] y_r;

    always @(posedge clk) begin
        if (reset) begin
            state      <= IDLE;
            byte_index <= 3'd0;
            lock_r     <= 1'b0;
            x_r        <= 10'd0;
            y_r        <= 10'd0;
            tx_data    <= 8'h00;
            tx_start   <= 1'b0;
        end else begin
            // tx_start is a one-clock pulse.
            tx_start <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // Wait for a new result and latch it.
                // -------------------------------------------------------------
                IDLE: begin
                    if (result_valid) begin
                        lock_r     <= target_locked;
                        x_r        <= target_x;
                        y_r        <= target_y;
                        byte_index <= 3'd0;
                        state      <= SEND;
                    end
                end

                // -------------------------------------------------------------
                // Present one byte to UART TX and issue a one-clock start pulse.
                // -------------------------------------------------------------
                SEND: begin
                    if (!uart_busy) begin
                        case (byte_index)
                            3'd0: tx_data <= 8'hAA;
                            3'd1: tx_data <= 8'h55;
                            3'd2: tx_data <= {7'd0, lock_r};
                            3'd3: tx_data <= x_r[7:0];
                            3'd4: tx_data <= {6'd0, x_r[9:8]};
                            3'd5: tx_data <= y_r[7:0];
                            3'd6: tx_data <= {6'd0, y_r[9:8]};
                            default: tx_data <= 8'h00;
                        endcase

                        tx_start <= 1'b1;

                        // Do NOT advance to the next byte yet.  First make sure
                        // UART TX actually accepted this byte.
                        state <= WAIT_HIGH;
                    end
                end

                // -------------------------------------------------------------
                // Wait until UART TX acknowledges the start by becoming busy.
                // -------------------------------------------------------------
                WAIT_HIGH: begin
                    if (uart_busy) begin
                        state <= WAIT_LOW;
                    end
                end

                // -------------------------------------------------------------
                // Wait until UART TX has completely finished this byte.
                // -------------------------------------------------------------
                WAIT_LOW: begin
                    if (!uart_busy) begin
                        if (byte_index == 3'd6) begin
                            // Complete 7-byte packet sent.
                            state <= IDLE;
                        end else begin
                            byte_index <= byte_index + 3'd1;
                            state <= SEND;
                        end
                    end
                end

                default: begin
                    state      <= IDLE;
                    byte_index <= 3'd0;
                end

            endcase
        end
    end

endmodule
