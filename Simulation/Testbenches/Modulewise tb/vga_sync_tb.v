`timescale 1ns / 1ps

module vga_sync_tb;

    // 1. Declare Signals
    reg clk;
    reg reset;

    wire hsync;
    wire vsync;
    wire video_on;
    wire [9:0] x_pos;
    wire [9:0] y_pos;

    // 2. Instantiate the VGA Generator (UUT)
    vga_sync uut (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .x_pos(x_pos),
        .y_pos(y_pos)
    );

    // 3. Generate a 25MHz Pixel Clock (40ns period)
    // 25 million cycles per second = 1 cycle every 40 nanoseconds
    always #20 clk = ~clk; 

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;

        $display("\n==================================================");
        $display("--- STARTING VGA TIMING VERIFICATION ---");
        $display("==================================================");

        // Wait for reset to clear
        #100;
        reset = 0;

        $display("Time %0t: System active. Generating 25MHz Pixel Clock...", $time);

        // The simulation will now run freely. The independent tripwires below 
        // will catch the sync pulses. We just need to tell the main thread to 
        // wait until the Y counter hits 524 (the absolute bottom of the frame).
        
        wait(y_pos == 524 && x_pos == 799); 
        
        $display("\nTime %0t: -> [SUCCESS] Reached the final pixel of Frame 1!", $time);
        
        // Wait for it to roll over to Frame 2
        wait(y_pos == 0 && x_pos == 0);
        $display("Time %0t: -> [SUCCESS] Counters cleanly rolled over to Frame 2.", $time);

        $display("\n==================================================");
        $display("--- VGA VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        $finish;
    end

    // ==========================================
    // OSCILLOSCOPE TRIPWIRES
    // ==========================================
    
    // Catch the FIRST Horizontal Sync pulse to prove rows are working
    always @(negedge hsync) begin
        if (y_pos == 0) // Only print for the very first row to keep the console clean
            $display("   [OSCILLOSCOPE] Time %0t: HSYNC Pulse dropped LOW! (Row %0d complete)", $time, y_pos);
    end

    // Catch the Vertical Sync pulse to prove frames are working
    always @(negedge vsync) begin
        $display("   [OSCILLOSCOPE] Time %0t: VSYNC Pulse dropped LOW! (Entering Vertical Blanking)", $time);
    end

endmodule