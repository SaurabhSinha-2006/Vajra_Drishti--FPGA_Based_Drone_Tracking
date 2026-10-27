`timescale 1ns / 1ps

module vajra_system_top_tb;

    // 1. Declare Physical Pins
    reg        clk;
    reg        reset;
    reg  [7:0] camera_pixel_in;
    
    wire       vga_hsync;
    wire       vga_vsync;
    wire       system_state_led;

    // 2. Instantiate the Master Motherboard
    vajra_system_top uut (
        .clk(clk),
        .reset(reset),
        .camera_pixel_in(camera_pixel_in),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .system_state_led(system_state_led)
    );

    // 3. 25MHz Pixel Clock (40ns period to match VGA timing)
    always #20 clk = ~clk;

    // Internal testbench variables
    integer frame_count = 0;
    reg drone_present = 0;

    // ==========================================
    // THE CAMERA LENS (Feeds pixels based on VGA coordinates)
    // ==========================================
    always @(posedge clk) begin
        if (uut.eyes.video_on) begin
            if (drone_present) begin
                // Draw a bright 30x30 drone in the exact center of the sky (X:320, Y:240)
                if (uut.eyes.x_pos >= 305 && uut.eyes.x_pos <= 335 && 
                    uut.eyes.y_pos >= 225 && uut.eyes.y_pos <= 255) begin
                    camera_pixel_in <= 8'd255; // White Drone
                end else begin
                    camera_pixel_in <= 8'd100; // Gray Sky
                end
            end else begin
                camera_pixel_in <= 8'd100; // Just Gray Sky
            end
        end else begin
            camera_pixel_in <= 8'd0; // Blanking zones
        end
    end

    // Track the ends of frames by watching the VSYNC pulse
    always @(negedge vga_vsync) begin
        frame_count = frame_count + 1;
    end

    // ==========================================
    // THE MASTER SCENARIO
    // ==========================================
    initial begin
        // Power On Reset
        clk = 0; reset = 1; camera_pixel_in = 0;
        #200; reset = 0;
        
        $display("\n==================================================");
        $display("--- INITIATING SYSTEM-LEVEL COMBAT SIMULATION ---");
        $display("==================================================");

        // PHASE 1: SEARCH MODE
        $display("\nTime %0t: Frame 1 - Scanning static airspace...", $time);
        drone_present = 0;
        
        // Wait for Frame 1 to finish
        wait(frame_count == 1);
        $display("   -> Frame 1 Complete. Radar ignored background. FSM State: %0d (Expected 0)", uut.conductor.current_state);

        // PHASE 2: DRONE INTRUSION
        $display("\nTime %0t: Frame 2 - Drone entering airspace at Center Coordinates!", $time);
        drone_present = 1;
        
        // Wait for Frame 2 to finish (This is when the Radar triggers motion_flag)
        wait(frame_count == 2);
        $display("   -> Frame 2 Complete. Radar tripped!");

        // At this exact moment, the FSM should jump to CNN_VERIFY and start the Feeder
        #100;
        $display("\nTime %0t: Master FSM State changed to: %0d (Expected 1: CNN Waking Up)", $time, uut.conductor.current_state);
        $display("   -> CNN Feeder logic engaged. Throttling data from BRAM to AI Core...");

        // Wait for the CNN to finish its math
        wait(uut.cnn_done == 1'b1);
        $display("\nTime %0t: Neural Network Math Complete!", $time);
        
        // Check the final hardware decision
        #100;
        if (system_state_led) begin
            $display("\n==================================================");
            $display("-> [CRITICAL SUCCESS] TARGET LOCKED LED IS ON!");
            $display("-> The full system successfully found, cropped, processed, and identified the target.");
            $display("==================================================\n");
        end else begin
            $display("\n-> [FAILURE] Target was not locked.");
        end

        $finish;
    end

    // ==========================================
    // FSM STATE MONITOR WIRETAP
    // ==========================================
    always @(uut.conductor.current_state) begin
        if (uut.conductor.current_state == 2'd2) begin
            $display("   [WIRETAP] Time %0t: FSM just jumped to TRACK MODE! Motors are engaging.", $time);
        end
    end

endmodule