`timescale 1ns / 1ps
module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input wire clk,
    input wire reset,
    input wire [7:0] data_in,
    input wire start,
    output reg tx,
    output reg busy
);
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    reg [31:0] count;
    reg [3:0] bit_index;
    reg [9:0] shift;

    always @(posedge clk) begin
        if (reset) begin
            count<=0; bit_index<=0; shift<=10'h3ff;
            tx<=1'b1; busy<=1'b0;
        end else if (!busy) begin
            tx<=1'b1;
            if (start) begin
                shift <= {1'b1,data_in,1'b0};
                count<=0; bit_index<=0; busy<=1'b1;
                tx<=1'b0;
            end
        end else begin
            if (count == CLKS_PER_BIT-1) begin
                count<=0;
                if (bit_index==4'd9) begin
                    busy<=1'b0; tx<=1'b1;
                end else begin
                    bit_index<=bit_index+1;
                    shift<={1'b1,shift[9:1]};
                    tx<=shift[1];
                end
            end else count<=count+1;
        end
    end
endmodule
