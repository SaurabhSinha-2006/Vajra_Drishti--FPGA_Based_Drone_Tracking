`timescale 1ns / 1ps

module roi_bram (
    input  wire        clk,
    
    // ==========================================
    // PORT A: WRITE PORT (Driven by roi_cropper.v)
    // ==========================================
    input  wire        write_en,
    input  wire [9:0]  write_addr, // Address: 0 to 1023
    input  wire [7:0]  data_in,    // 8-bit pixel from the camera
    
    // ==========================================
    // PORT B: READ PORT (Driven by the CNN Engine)
    // ==========================================
    input  wire        read_en,
    input  wire [9:0]  read_addr,  // Address: 0 to 1023
    output reg  [7:0]  data_out    // 8-bit pixel going to the CNN
);

    // ==========================================
    // THE PHYSICAL MEMORY ARRAY
    // 1024 locations, each 8 bits wide (Exactly 1 Kilobyte)
    // ==========================================
    reg [7:0] memory_array [0:1023];

    // ==========================================
    // SYNCHRONOUS WRITE LOGIC
    // ==========================================
    always @(posedge clk) begin
        if (write_en) begin
            memory_array[write_addr] <= data_in;
        end
    end

    // ==========================================
    // SYNCHRONOUS READ LOGIC
    // ==========================================
    always @(posedge clk) begin
        if (read_en) begin
            data_out <= memory_array[read_addr];
        end
    end

endmodule