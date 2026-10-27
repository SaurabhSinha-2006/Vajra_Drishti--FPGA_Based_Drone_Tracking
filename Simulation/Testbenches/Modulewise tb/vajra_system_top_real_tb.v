`timescale 1ns / 1ps

module vajra_system_top_real_tb;

    reg clk;
    reg reset;
    reg [7:0] camera_pixel_in;
    wire vga_hsync, vga_vsync, system_state_led;

    // Memory to hold 2 Full Frames (307,200 * 2 = 614,400 pixels)
    reg [7:0] video_stream [0:614399];
    integer pixel_ptr = 0;

    initial begin
        $display("--- LOADING REAL DUAL-FRAME VIDEO DATA ---");
        $readmemh("dual_frame_video.hex", video_stream);
    end

    // Instantiate the Full System
    vajra_system_top uut (
        .clk(clk), .reset(reset), 
        .camera_pixel_in(camera_pixel_in),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
        .system_state_led(system_state_led)
    );

    // 25MHz VGA Clock
    always #20 clk = ~clk;

    // Feed the pixels sequentially from the 2-frame memory
    always @(posedge clk) begin
        if (reset) begin
            pixel_ptr <= 0;
        end else if (uut.eyes.video_on) begin
            camera_pixel_in <= video_stream[pixel_ptr];
            if (pixel_ptr < 614399) pixel_ptr <= pixel_ptr + 1;
        end else begin
            camera_pixel_in <= 8'd0;
        end
    end

    initial begin
        clk = 0; reset = 1; #200; reset = 0;
        
        $display("\n[TIME %0t] FRAME 1: LEARNING BACKGROUND...", $time);
        wait(uut.eyes.y_pos == 479 && uut.eyes.x_pos == 639);
        
        $display("\n[TIME %0t] FRAME 2: DRONE INTRUSION! RADAR ACTIVE...", $time);
        // During this frame, the motion_roi should calculate the suspect_x/y
        
        wait(uut.conductor.current_state == 2'd1); // State: STATE_CNN_VERIFY
        $display("\n[TIME %0t] SUCCESS: RADAR TRIPPED. CNN WAKING UP...", $time);
        $display("   -> Radar ROI Center: X=%d, Y=%d", uut.radar.suspect_x, uut.radar.suspect_y);

        wait(uut.cnn_done == 1'b1);
        #100;
        
        if (system_state_led) 
            $display("\n>>> [FINAL RESULT] SYSTEM ACCURATELY IDENTIFIED THE REAL DRONE! <<<");
        else 
            $display("\n>>> [FINAL RESULT] AI REJECTED THE TARGET. (Current Acc: %d)", uut.cnn_brain.decision_core.accumulator);
            
        $finish;
    end

endmodule