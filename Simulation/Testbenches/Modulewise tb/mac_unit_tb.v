`timescale 1ns / 1ps

module mac_unit_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [71:0] pixels_in;
    reg  [71:0] weights_in;
    
    wire        valid_out;
    wire [7:0]  pixel_out;

    // 2. Instantiate the Unit Under Test (UUT)
    mac_unit uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixels_in(pixels_in),
        .weights_in(weights_in),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    // 4. The Stimulus Process
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        pixels_in = 0;
        weights_in = 0;

        // Wait 20ns for global reset
        #20;
        reset = 0;
        #10;

        $display("\n--- STARTING MAC UNIT VERIFICATION ---");

        // ==========================================
        // TEST CASE 1: Standard Positive Feature
        // ==========================================
        // Pixels: All 100 (Medium gray)
        // Weights: All 2 (Small positive weights)
        // Expected Math: (100*2) * 9 = 1800.
        // Scaled Math: 1800 / 128 = 14.
        valid_in = 1;
        pixels_in  = {8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100};
        weights_in = {8'sd2,  8'sd2,  8'sd2,  8'sd2,  8'sd2,  8'sd2,  8'sd2,  8'sd2,  8'sd2};
        #10;
        valid_in = 0;
        #10; // Wait for processing
        $display("Test 1 (Standard): Expected ~14, Got %0d", pixel_out);


        // ==========================================
        // TEST CASE 2: The ReLU Check (Negative Result)
        // ==========================================
        // Pixels: All 100
        // Weights: All -5 (Negative weights)
        // Expected Math: (100 * -5) * 9 = -4500.
        // Expected Output: 0 (Because ReLU blocks negative numbers)
        valid_in = 1;
        pixels_in  = {8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100, 8'd100};
        // Note: -5 in 8-bit two's complement is 8'hFB, but Verilog handles -5 with the signed cast
        weights_in = {8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5, 8'sd_5}; 
        #10;
        valid_in = 0;
        #10;
        $display("Test 2 (ReLU): Expected 0, Got %0d", pixel_out);


        // ==========================================
        // TEST CASE 3: The Saturation Ceiling
        // ==========================================
        // Pixels: All 255 (Pure white, max value)
        // Weights: All 127 (Max positive weight)
        // Expected Math: (255 * 127) * 9 = 291,465.
        // Scaled Math: 291465 / 128 = 2277.
        // Expected Output: 255 (Because 2277 > 255, it must hit the hardware ceiling)
        valid_in = 1;
        pixels_in  = {8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255};
        weights_in = {-8'sd5, -8'sd5, -8'sd5, -8'sd5, -8'sd5, -8'sd5, -8'sd5, -8'sd5, -8'sd5};
        #10;
        valid_in = 0;
        #10;
        $display("Test 3 (Saturation): Expected 255, Got %0d", pixel_out);

        #20;
        $display("--- VERIFICATION COMPLETE ---\n");
        $finish;
    end

endmodule