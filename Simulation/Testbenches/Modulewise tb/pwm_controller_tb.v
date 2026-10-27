`timescale 1ns / 1ps

module pwm_controller_tb;

    // Inputs
    reg clk;
    reg reset;
    reg track_enable;
    reg [9:0] target_x;
    reg [9:0] target_y;
    
    // Outputs
    wire pwm_pan;
    wire pwm_tilt;

    // Instantiate the Unit Under Test (UUT)
    pwm_controller uut (
        .clk(clk),
        .reset(reset),
        .track_enable(track_enable),
        .target_x(target_x),
        .target_y(target_y),
        .pwm_pan(pwm_pan),
        .pwm_tilt(pwm_tilt)
    );

    // Clock Generation (25 MHz)
    always #20 clk = ~clk;

    // ==========================================
    // HELPER TASK: WAIT FOR ONE 20ms FRAME
    // ==========================================
    task wait_pwm_period;
        begin
            // Wait for the master counter to roll over to 0 (Start of a new 20ms frame)
            wait(uut.pwm_counter == 19'd0);
            @(posedge clk); // Step 1 cycle so the logic has time to update
            
            // Print the internal calculated pulse widths
            $display("   [Time %0t ns] Pan Width: %0d | Tilt Width: %0d", 
                     $time, uut.pan_width, uut.tilt_width);
                     
            // Wait for the counter to leave 0 so we don't trigger this infinitely
            wait(uut.pwm_counter == 19'd10);
        end
    endtask

    // ==========================================
    // THE TEST SEQUENCE
    // ==========================================
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        track_enable = 0;
        target_x = 320; // Center
        target_y = 240; // Center
        
        #100; reset = 0; #100;

        $display("\n==================================================");
        $display("--- PWM CONTROLLER UNIT TESTS ---");
        $display("Expected Center: 37500 | Min: 25000 | Max: 50000");
        $display("==================================================\n");

        // --------------------------------------------------
        // TEST 1: SYSTEM BOOT (NO TRACKING)
        // --------------------------------------------------
        $display("[TEST 1] Tracking Disabled. Motors should snap to DEAD CENTER.");
        wait_pwm_period();

        // --------------------------------------------------
        // TEST 2: THE DEADZONE
        // --------------------------------------------------
        $display("\n[TEST 2] Target inside Deadzone (X=330, Y=230). Widths should NOT change.");
        track_enable = 1;
        target_x = 330; // Just 10 pixels right (Inside 40px deadzone)
        target_y = 230; // Just 10 pixels up (Inside 40px deadzone)
        wait_pwm_period(); // Frame 1
        wait_pwm_period(); // Frame 2

        // --------------------------------------------------
        // TEST 3: TARGET MOVES FAR RIGHT AND DOWN
        // --------------------------------------------------
        $display("\n[TEST 3] Target far Right/Down (X=500, Y=400). Widths should INCREASE (+50 per frame).");
        target_x = 500;
        target_y = 400;
        wait_pwm_period(); // Frame 1
        wait_pwm_period(); // Frame 2
        wait_pwm_period(); // Frame 3

        // --------------------------------------------------
        // TEST 4: TARGET MOVES FAR LEFT AND UP
        // --------------------------------------------------
        $display("\n[TEST 4] Target far Left/Up (X=100, Y=100). Widths should DECREASE (-50 per frame).");
        target_x = 100;
        target_y = 100;
        wait_pwm_period(); // Frame 1
        wait_pwm_period(); // Frame 2
        wait_pwm_period(); // Frame 3

        // --------------------------------------------------
        // TEST 5: TARGET LOST (FAIL-SAFE)
        // --------------------------------------------------
        $display("\n[TEST 5] Target Lost! Tracking disabled. Motors should snap back to CENTER.");
        track_enable = 0;
        wait_pwm_period();

        $display("\n==================================================");
        $display("--- PWM TESTS COMPLETE ---");
        $display("==================================================\n");
        $finish;
    end

endmodule