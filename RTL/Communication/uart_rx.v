`timescale 1ns / 1ps

module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input wire clk,
    input wire reset,
    input wire rx,
    output reg [7:0] data_out,
    output reg data_valid
);
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    localparam [2:0] IDLE=3'd0, START=3'd1,
                     DATA=3'd2, STOP=3'd3;

    reg rx_meta, rx_sync;
    reg [2:0] state;
    reg [31:0] count;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state<=IDLE;
            count<=0;
            bit_index<=0;
            shift<=0;
            data_out<=0;
            data_valid<=0;
        end else begin
            data_valid<=1'b0;

            case(state)
                IDLE: begin
                    count<=0;
                    bit_index<=0;
                    if (!rx_sync)
                        state<=START;
                end

                START: begin
                    if (count == HALF_BIT-1) begin
                        count<=0;
                        // Confirm that the line is still low at
                        // the middle of the start bit.
                        state <= (!rx_sync) ? DATA : IDLE;
                    end else begin
                        count<=count+1'b1;
                    end
                end

                DATA: begin
                    if (count == CLKS_PER_BIT-1) begin
                        count<=0;
                        shift[bit_index]<=rx_sync;

                        if (bit_index==3'd7)
                            state<=STOP;
                        else
                            bit_index<=bit_index+1'b1;
                    end else begin
                        count<=count+1'b1;
                    end
                end

                STOP: begin
                    if (count == CLKS_PER_BIT-1) begin
                        count<=0;
                        data_out<=shift;
                        data_valid<=1'b1;
                        state<=IDLE;
                    end else begin
                        count<=count+1'b1;
                    end
                end

                default: state<=IDLE;
            endcase
        end
    end
endmodule
