`timescale 1ns / 1ps

module motion_roi_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         video_on;
    reg  [9:0]  x_pos;
    reg  [9:0]  y_pos;
    reg  [7:0]  pixel_in;
    reg  [7:0]  pixel_prev;
    
    wire [7:0]  pixel_out;
    wire [9:0]  suspect_x;
    wire [9:0]  suspect_y;
    wire        motion_flag;

    // 2. Instantiate the Radar (UUT)
    motion_roi uut (
        .clk(clk),
        .reset(reset),
        .video_on(video_on),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .pixel_in(pixel_in),
        .pixel_prev(pixel_prev),
        .pixel_out(pixel_out),
        .suspect_x(suspect_x),
        .suspect_y(suspect_y),
        .motion_flag(motion_flag)
    );

    // 3. Generate a 100MHz Clock (10ns period)
    always #5 clk = ~clk;

    integer x, y;

    initial begin
        // Initialize Inputs
        clk = 0; reset = 1; video_on = 0; 
        x_pos = 0; y_pos = 0;
        pixel_in = 0; pixel_prev = 0;

        #100; reset = 0; #20;

        $display("\n==================================================");
        $display("--- STARTING MOTION RADAR VERIFICATION ---");
        $display("==================================================");

        // ==========================================
        // TEST FRAME 1: NO MOTION (Static Background)
        // ==========================================
        $display("\nTime %0t: Injecting Frame 1 (Static Background)...", $time);
        
        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 640; x = x + 1) begin
                x_pos = x; 
                y_pos = y; 
                video_on = 1'b1;
                
                // Both pixels are identical. Difference is 0.
                pixel_in = 8'd100;   
                pixel_prev = 8'd100; 
                #10;
            end
        end
        video_on = 0; #50; // Brief blanking period
        
        $display("   [FRAME 1 COMPLETE] Motion Flag Status: %0b (Expected 0)", motion_flag);


        // ==========================================
        // TEST FRAME 2: DRONE DETECTED (Moving Box)
        // ==========================================
        $display("\nTime %0t: Injecting Frame 2 (Drone entering airspace)...", $time);
        $display("-> Simulating Drone bounding box between X: 100-150, Y: 200-250.");
        $display("-> Expected mathematical center: X = 125, Y = 225.");
        
        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 640; x = x + 1) begin
                x_pos = x; 
                y_pos = y; 
                video_on = 1'b1;
                
                // If we are inside the drone's coordinates, simulate a massive pixel change
                if (x >= 100 && x <= 150 && y >= 200 && y <= 250) begin
                    pixel_in = 8'd255;   // Bright white drone
                    pixel_prev = 8'd50;  // Was dark background
                end else begin
                    pixel_in = 8'd100;   // Rest of the sky hasn't changed
                    pixel_prev = 8'd100;
                end
                
                #10;
            end
        end
        video_on = 0; #100;
        
        $display("\n==================================================");
        $display("--- RADAR VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        $finish;
    end

    // ==========================================
    // THE HARDWARE TRIPWIRE
    // ==========================================
    // This triggers the exact nanosecond your motion_flag goes HIGH
    always @(posedge motion_flag) begin
        $display("\n-> [ALARM TRIPWIRE CAUGHT!]");
        $display("-> Hardware locked onto target center at: X = %0d, Y = %0d", suspect_x, suspect_y);
    end

endmodule