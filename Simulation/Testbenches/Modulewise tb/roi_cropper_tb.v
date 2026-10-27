`timescale 1ns / 1ps

module roi_cropper_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         video_on;
    reg  [9:0]  x_pos;
    reg  [9:0]  y_pos;
    reg  [7:0]  pixel_in;
    reg  [9:0]  suspect_x;
    reg  [9:0]  suspect_y;
    reg         motion_flag;
    
    wire        roi_write_en;
    wire [9:0]  roi_write_addr;
    wire [7:0]  roi_pixel_out;

    // 2. Instantiate the Cropper (UUT)
    roi_cropper uut (
        .clk(clk), .reset(reset), .video_on(video_on),
        .x_pos(x_pos), .y_pos(y_pos), .pixel_in(pixel_in),
        .suspect_x(suspect_x), .suspect_y(suspect_y), .motion_flag(motion_flag),
        .roi_write_en(roi_write_en), .roi_write_addr(roi_write_addr), .roi_pixel_out(roi_pixel_out)
    );

    // 3. Clock Generation
    always #5 clk = ~clk;

    integer x, y;
    integer captured_pixels = 0;

    initial begin
        // Initialize
        clk = 0; reset = 1; video_on = 0; 
        x_pos = 0; y_pos = 0; pixel_in = 0;
        suspect_x = 0; suspect_y = 0; motion_flag = 0;
        #100; reset = 0; #20;

        $display("\n==================================================");
        $display("--- STARTING ROI CROPPER VERIFICATION ---");
        $display("==================================================");

        // STEP 1: Simulate the Motion Radar finishing a frame and locking a target
        $display("Time %0t: Radar detected drone! Center locked at X: 100, Y: 100", $time);
        suspect_x = 100;
        suspect_y = 100;
        motion_flag = 1; #10; // Pulse the flag to latch the coordinates
        motion_flag = 0; #10;

        // The expected bounding box should be:
        // Left: 100 - 16 = 84
        // Right: 84 + 31 = 115
        // Top: 100 - 16 = 84
        // Bottom: 84 + 31 = 115

        // STEP 2: Sweep the entire next frame
        $display("Time %0t: Sweeping full 640x480 frame to find the bounding box...", $time);
        
        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 640; x = x + 1) begin
                x_pos = x; 
                y_pos = y; 
                video_on = 1'b1;
                pixel_in = 8'd255; // Dummy pixel data
                #10;
            end
        end
        video_on = 0; #50;

        // STEP 3: Report Results
        $display("\n==================================================");
        $display("--- CROPPER DIAGNOSTIC REPORT ---");
        $display("==================================================");
        $display("Total Pixels Captured: %0d", captured_pixels);
        
        if (captured_pixels == 1024) begin
            $display("-> [SUCCESS] Flawless 32x32 extraction achieved!");
        end else begin
            $display("-> [FATAL ERROR] Captured the wrong number of pixels.");
        end
        $display("==================================================\n");
        $finish;
    end

    // ==========================================
    // THE WIRETAP (Monitors the RAM Write Enable)
    // ==========================================
    always @(posedge clk) begin
        if (roi_write_en) begin
            captured_pixels = captured_pixels + 1;
            
            // Print the very first pixel captured
            if (captured_pixels == 1) begin
                $display("   -> First pixel captured at physical coordinates: X=%0d, Y=%0d", x_pos, y_pos);
            end
            
            // Print the very last pixel captured
            if (captured_pixels == 1024) begin
                $display("   -> Final pixel captured at physical coordinates: X=%0d, Y=%0d", x_pos, y_pos);
            end
        end
    end

endmodule