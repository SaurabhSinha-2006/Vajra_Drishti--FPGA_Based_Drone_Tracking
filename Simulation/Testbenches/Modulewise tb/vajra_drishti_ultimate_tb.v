// Om Shri Ganeshay Namah!!!
`timescale 1ns / 1ps

module vajra_drishti_ultimate_tb;

    // Master Signals
    reg clk;
    reg reset;
    reg [7:0] camera_pixel_in;
    
    // Outputs from the new integrated motherboard
    wire vga_hsync;
    wire vga_vsync;
    wire system_state_led;
    wire pwm_pan;
    wire pwm_tilt;

    // Instantiate the fully integrated system
    vajra_drishti_top uut (
        .clk(clk),
        .reset(reset),
        .camera_pixel_in(camera_pixel_in),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .pwm_pan(pwm_pan),
        .pwm_tilt(pwm_tilt),
        .system_state_led(system_state_led)
    );

    // Memory arrays for our visual world
    reg [7:0] sky_mem   [0:307199];
    reg [7:0] drone_mem [0:307199];

    initial begin
        $display("\n==================================================");
        $display("--- LOADING REAL VIDEO FRAMES FROM PYTHON ---");
        $readmemh("sky.hex", sky_mem);
        $readmemh("drone.hex", drone_mem);
        $display("--- VIDEO LOAD COMPLETE ---");
        $display("==================================================\n");
    end

    // 25 MHz System Clock
    always #20 clk = ~clk;

    integer current_frame = 1;
    wire [18:0] pixel_index = (uut.eyes.y_pos * 640) + uut.eyes.x_pos;

    // --- THE SEQUENTIAL CAMERA LENS ---
    always @(posedge clk) begin
        if (uut.eyes.video_on) begin
            // Frame 1 & 2: Empty Sky (Boot & Stabilize)
            if (current_frame <= 2) camera_pixel_in <= sky_mem[pixel_index]; 
            // Frame 3+: Drone appears and is tracked
            else                    camera_pixel_in <= drone_mem[pixel_index]; 
        end else begin
            camera_pixel_in <= 8'd0;
        end
    end

    // ==========================================
    // THE ULTIMATE DEBUG WIRETAPS
    // ==========================================
    integer real_confidence_score = 0;
    integer watchdog_timer = 0;
    integer pixels_fed = 0;

    always @(posedge clk) begin
        // Spy on CNN Math
        if (uut.cnn_brain.decision_core.addr_cnt == 899) begin
            real_confidence_score = uut.cnn_brain.decision_core.next_sum;
        end

        // BRAM SPY
        if (uut.cnn_valid_in && pixels_fed < 5) begin
            $display("   [BRAM SPY] Feeding CNN Pixel %0d: Value = %0d", pixels_fed, uut.bram_data_out);
            pixels_fed = pixels_fed + 1;
        end

        // Watchdog
        if (uut.conductor.current_state == 2'd1) begin // STATE_CNN_VERIFY
            watchdog_timer = watchdog_timer + 1;
            if (watchdog_timer > 1000000) begin
                $display("!!! FATAL ERROR: WATCHDOG TIMER TRIPPED !!!");
                $finish;
            end
        end else begin
            watchdog_timer = 0;
        end
    end

    // ==========================================
    // THE MASTER COMBAT SCENARIO
    // ==========================================
    initial begin
        clk = 0; reset = 1; #200; reset = 0;
        
        $display("\n[TIME %0t] FRAME 1: Booting system and filling memory with Sky...", $time);
        current_frame = 1;
        @(negedge vga_vsync); 
        
        $display("\n[TIME %0t] FRAME 2: Stabilizing Radar (Sky vs Sky)...", $time);
        current_frame = 2;
        @(negedge vga_vsync); 
        
        $display("\n[TIME %0t] FRAME 3: Intruder enters airspace! (Drone vs Sky)", $time);
        current_frame = 3;
        @(negedge vga_vsync); 
        
        #40; 
        if (uut.conductor.current_state == 2'd1) begin
            $display("   -> [TARGET DETECTED] Radar triggered!");
            $display("   -> Locked Coordinates: X = %0d, Y = %0d", uut.radar.suspect_x, uut.radar.suspect_y);
            
            $display("\n[TIME %0t] FRAME 4: AI is processing...", $time);
            current_frame = 4;
            
            wait(uut.cnn_done == 1'b1); 
            #100;
            
            $display("\n==================================================");
            $display("--- AI VERIFICATION DIAGNOSTIC ---");
            $display("CNN Confidence Score: %0d", real_confidence_score);
            
            if (system_state_led) begin
                $display(">>> [LOCK] Target confirmed. Engaging Tracking Systems! <<<");
                
                // --- NEW TRACKING & MOTOR VERIFICATION PHASE ---
                $display("\n[TIME %0t] FRAME 5: Handing template to SAD Tracker...", $time);
                current_frame = 5;
                @(negedge vga_vsync); // Let the camera draw the frame
                
                $display("   -> Waiting for SAD Tracker to finish Diamond Search...");
                wait(uut.bloodhound.tracking_done == 1'b1);
                #100;
                $display("   -> [SAD OUTPUT] New Target Coordinates: X = %0d, Y = %0d", uut.target_x, uut.target_y);
                
                $display("\n[TIME %0t] FRAME 6: Powering Servo Motors...", $time);
                current_frame = 6;
                
                $display("   -> Waiting for 20ms PWM Cycle to reset...");
                wait(uut.muscles.pwm_counter == 19'd0); // Wait for the motor logic to trigger
                #100;
                
                $display("\n==================================================");
                $display("--- FINAL SYSTEM STATE ---");
                $display("Pan Pulse Width:  %0d (Center is 37500)", uut.muscles.pan_width);
                $display("Tilt Pulse Width: %0d (Center is 37500)", uut.muscles.tilt_width);
                $display("==================================================\n");

            end else begin
                $display(">>> [REJECT] Not a drone. Returning to Search. <<<");
                $display("==================================================\n");
            end
            
        end else begin
            $display("   -> [RADAR SILENT] No movement detected. Airspace is clear.");
        end
        
        $finish;
    end
endmodule