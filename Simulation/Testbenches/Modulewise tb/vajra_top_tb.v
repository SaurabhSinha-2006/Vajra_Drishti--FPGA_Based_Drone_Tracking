`timescale 1ns / 1ps

module vajra_top_tb;

    // 1. Declare Physical Pins
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    wire        done;
    wire        target_locked;

    // 2. Instantiate the Top-Level Motherboard
    vajra_top uut (
        .clk(clk), .reset(reset), .valid_in(valid_in), 
        .pixel_in(pixel_in), .done(done), .target_locked(target_locked)
    );

    // 3. 100MHz Clock Generation
    always #5 clk = ~clk;

    // =========================================================
    // THE WIRETAPS (Looking inside the hardware pipeline)
    // =========================================================
    integer serial_out_cnt = 0;

    // Watch the Serializer output and report to the console
    always @(posedge clk) begin
        if (uut.serial_valid_out) begin
            serial_out_cnt = serial_out_cnt + 1;
            
            // Print progress milestones to see the hardware "thinking"
            if (serial_out_cnt == 1)   
                $display("   [LATENCY TRACKER] Time %0t: The FIRST compressed pixel just reached the Dense Layer!", $time);
            if (serial_out_cnt == 225) 
                $display("   [PIPELINE PROGRESS] Time %0t: Dense Layer is 25%% done accumulating...", $time);
            if (serial_out_cnt == 450) 
                $display("   [PIPELINE PROGRESS] Time %0t: Dense Layer is 50%% done accumulating...", $time);
            if (serial_out_cnt == 675) 
                $display("   [PIPELINE PROGRESS] Time %0t: Dense Layer is 75%% done accumulating...", $time);
            if (serial_out_cnt == 900) 
                $display("   [PIPELINE PROGRESS] Time %0t: Dense Layer received all 900 pixels! Math complete.", $time);
        end
    end

    // =========================================================
    // STIMULUS (The Camera Simulator)
    // =========================================================
    integer i;

    initial begin
        // Reset the hardware
        clk = 0; reset = 1; valid_in = 0; pixel_in = 0;
        #100; reset = 0; #20;

        $display("\n==================================================");
        $display("--- STARTING HARDWARE DATAPATH VISUALIZATION ---");
        $display("==================================================");
        
        $display("\nTime %0t: Camera turning on. Injecting 32x32 image (1024 pixels)...", $time);
        $display("-> Note: The camera is actively throttled to prevent Serializer collisions.");

        // INJECTION LOOP
        for (i = 0; i < 1024; i = i + 1) begin
            pixel_in = 8'd128; // Injecting a solid gray background image
            valid_in = 1'b1; #10;
            valid_in = 1'b0; #10; // The Throttle!
            
            if (i == 511) 
                $display("   [CAMERA PROGRESS] Time %0t: 50%% of image injected into Conv Layer...", $time);
        end
        
        $display("   [CAMERA PROGRESS] Time %0t: 100%% of image injected. Camera turning off.", $time);
        $display("\nTime %0t: Waiting for the final pixels to physically travel through the silicon...", $time);
        
        // FLUSH PIPELINE (Push empty air to force the final math through the registers)
        for (i = 0; i < 20; i = i + 1) begin
            pixel_in = 8'd0;
            valid_in = 1'b1; #10;
            valid_in = 1'b0; #10;
        end
        
        valid_in = 0;

        // =========================================================
        // THE TRIPWIRE (Waits for the hardware to make a decision)
        // =========================================================
        begin : wait_block
            fork
                begin
                    wait(done == 1'b1);
                    $display("\n==================================================");
                    $display("--- HARDWARE INTERRUPT CAUGHT ---");
                    $display("-> Time: %0t", $time);
                    $display("-> Decision: TARGET LOCKED = %0b", target_locked);
                    if (target_locked == 1'b1)
                        $display("-> Analysis: Drone Detected in airspace.");
                    else
                        $display("-> Analysis: Background only. Airspace clear.");
                    $display("==================================================\n");
                    disable wait_block;
                end
                begin
                    #1000000; // 1 Millisecond absolute timeout
                    $display("\n-> [FATAL ERROR] Timeout! The hardware pipeline stalled.");
                    disable wait_block;
                end
            join
        end

        $finish;
    end

endmodule