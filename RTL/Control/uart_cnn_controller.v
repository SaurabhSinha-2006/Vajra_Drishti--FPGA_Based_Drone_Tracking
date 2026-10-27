`timescale 1ns / 1ps

module uart_cnn_controller (
    input wire clk,
    input wire reset,
    input wire start,

    output reg cnn_reset,
    output reg roi_read_en,
    output reg [9:0] roi_read_addr,
    input wire [7:0] roi_read_data,

    output reg cnn_valid,
    output reg [7:0] cnn_pixel,

    input wire cnn_done,
    output reg result_seen
);
    localparam [2:0] IDLE=3'd0, RESET_CNN=3'd1,
                     WAIT_READ=3'd2, FEED=3'd3, WAIT=3'd4;

    reg [2:0] state;
    reg [10:0] count;

    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE;
            count<=0;
            cnn_reset<=0;
            roi_read_en<=0;
            roi_read_addr<=0;
            cnn_valid<=0;
            cnn_pixel<=0;
            result_seen<=0;
        end else begin
            cnn_reset<=0;
            roi_read_en<=0;
            cnn_valid<=0;
            result_seen<=0;

            case(state)
                IDLE: begin
                    if(start) begin
                        // Re-arm the whole CNN pipeline before every ROI.
                        cnn_reset<=1'b1;
                        count<=0;
                        roi_read_addr<=0;
                        state<=RESET_CNN;
                    end
                end

                RESET_CNN: begin
                    // CNN reset was asserted during the previous clock.
                    // Issue the first synchronous ROI read.
                    roi_read_en<=1'b1;
                    state<=WAIT_READ;
                end

                WAIT_READ: begin
                    // The ROI BRAM performs the requested synchronous read
                    // on this clock edge. Consume the byte next cycle.
                    state<=FEED;
                end

                FEED: begin
                    // roi_read_data is the result of the read requested
                    // on the previous clock.
                    cnn_pixel<=roi_read_data;
                    cnn_valid<=1'b1;

                    if(count==1023) begin
                        state<=WAIT;
                    end else begin
                        count<=count+1'b1;
                        roi_read_addr<=count+1'b1;
                        roi_read_en<=1'b1;
                    end
                end

                WAIT: begin
                    if(cnn_done) begin
                        result_seen<=1'b1;
                        state<=IDLE;
                    end
                end

                default: state<=IDLE;
            endcase
        end
    end
endmodule
