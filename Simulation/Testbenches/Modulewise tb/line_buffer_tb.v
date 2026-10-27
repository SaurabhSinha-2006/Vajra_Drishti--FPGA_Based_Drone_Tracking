`timescale 1ns / 1ps

module line_buffer_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        valid_out;
    wire [71:0] window_out;

    // 2. Instantiate the Unit Under Test (UUT)
    line_buffer #(
        .WIDTH(32) // Set to our exact image crop width
    ) uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .window_out(window_out)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    integer i;

    // 4. The Stimulus Process
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        pixel_in = 0;

        // Wait for global reset
        #20;
        reset = 0;
        #10;

        $display("\n--- STARTING LINE BUFFER VERIFICATION ---");
        
        // Turn on the data stream
        valid_in = 1;
        
        // Feed 70 pixels into the hardware, one per clock cycle
        for (i = 1; i <= 70; i = i + 1) begin
            pixel_in = i;
            #10; // Wait 1 clock cycle for the shift registers to move
            
            // Check the exact moment Pixel 67 has been processed
            if (i == 67) begin
                $display("\nAt Clock Cycle 67, Pixel 67 enters the bottom right corner.");
                $display("If the hardware delay tubes are working, the 3x3 Window will align perfectly:");
                
                // Unpack the 72-bit wire back into a 3x3 grid for the console
                $display("[%0d] [%0d] [%0d]", window_out[71:64], window_out[63:56], window_out[55:48]);
                $display("[%0d] [%0d] [%0d]", window_out[47:40], window_out[39:32], window_out[31:24]);
                $display("[%0d] [%0d] [%0d]", window_out[23:16], window_out[15:8],  window_out[7:0]);
            end
        end

        valid_in = 0;
        #20;
        $display("\n--- VERIFICATION COMPLETE ---\n");
        $finish;
    end

endmodule