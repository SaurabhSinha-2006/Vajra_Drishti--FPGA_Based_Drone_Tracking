`timescale 1ns / 1ps

module uart_roi_extractor #(
    parameter integer WIDTH=640
)(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [9:0] center_x,
    input wire [9:0] center_y,

    output reg [18:0] frame_addr,
    output reg frame_read_req,
    input wire [7:0] frame_read_data,

    output reg roi_write_en,
    output reg [9:0] roi_write_addr,
    output reg [7:0] roi_pixel,
    output reg done
);
    localparam [2:0] IDLE=3'd0, READ=3'd1,
                     WAIT_READ=3'd2, WRITE=3'd3;

    reg [2:0] state;
    reg [9:0] left, top;
    reg [5:0] rx, ry;

    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE;
            frame_addr<=0;
            frame_read_req<=0;
            roi_write_en<=0;
            roi_write_addr<=0;
            roi_pixel<=0;
            done<=0;
            left<=0; top<=0;
            rx<=0; ry<=0;
        end else begin
            frame_read_req<=0;
            roi_write_en<=0;
            done<=0;

            case(state)
                IDLE: begin
                    if(start) begin
                        left <= (center_x < 16) ? 0 :
                                (center_x > 623) ? 608 : center_x-16;
                        top  <= (center_y < 16) ? 0 :
                                (center_y > 463) ? 448 : center_y-16;
                        rx<=0;
                        ry<=0;
                        state<=READ;
                    end
                end

                READ: begin
                    frame_addr<=((top+ry)*WIDTH)+(left+rx);
                    frame_read_req<=1'b1;
                    state<=WAIT_READ;
                end

                WAIT_READ: begin
                    // Top-level RAM performs the synchronous read on this
                    // edge. The returned byte is consumed in WRITE.
                    state<=WRITE;
                end

                WRITE: begin
                    roi_pixel<=frame_read_data;
                    roi_write_addr<=(ry*32)+rx;
                    roi_write_en<=1'b1;

                    if(rx==31) begin
                        rx<=0;
                        if(ry==31) begin
                            ry<=0;
                            done<=1'b1;
                            state<=IDLE;
                        end else begin
                            ry<=ry+1'b1;
                            state<=READ;
                        end
                    end else begin
                        rx<=rx+1'b1;
                        state<=READ;
                    end
                end

                default: state<=IDLE;
            endcase
        end
    end
endmodule
