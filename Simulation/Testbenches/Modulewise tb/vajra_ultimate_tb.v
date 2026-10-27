// Om Shri Ganeshay Namah!!!
`timescale 1ns / 1ps

module vajra_ultimate_tb;

    reg clk;
    reg reset;
    reg [7:0] camera_pixel_in;
    
    wire vga_hsync;
    wire vga_vsync;
    wire system_state_led;

    vajra_system_top uut (
        .clk(clk),
        .reset(reset),
        .camera_pixel_in(camera_pixel_in),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .system_state_led(system_state_led)
    );

    reg [7:0] frame1_mem [0:307199];
    reg [7:0] frame2_mem [0:307199];
    reg [7:0] frame3_mem [0:307199];

    initial begin
        $display("\n==================================================");
        $display("--- LOADING REAL VIDEO FRAMES FROM PYTHON ---");
        $readmemh("drone.hex", frame1_mem);
        $readmemh("sky.hex", frame2_mem);
        $readmemh("sky.hex", frame3_mem);
        $display("--- VIDEO LOAD COMPLETE ---");
        $display("==================================================\n");
    end

    always #20 clk = ~clk;

    integer current_frame = 1;
    wire [18:0] pixel_index = (uut.eyes.y_pos * 640) + uut.eyes.x_pos;

    // --- THE SEQUENTIAL CAMERA LENS ---
    always @(posedge clk) begin
        if (uut.eyes.video_on) begin
            if (current_frame == 1)      camera_pixel_in <= frame1_mem[pixel_index]; // Boot up (Sky)
            else if (current_frame == 2) camera_pixel_in <= frame1_mem[pixel_index]; // Stabilize (Sky)
            else if (current_frame == 3) camera_pixel_in <= frame2_mem[pixel_index]; // Intruder (Drone)
            else                         camera_pixel_in <= frame3_mem[pixel_index]; // Processing (Drone)
        end else begin
            camera_pixel_in <= 8'd0;
        end
    end

    integer real_confidence_score = 0;
    integer watchdog_timer = 0;
    integer pixels_fed = 0;

    always @(posedge clk) begin
        if (uut.cnn_brain.decision_core.addr_cnt == 899) begin
            real_confidence_score = uut.cnn_brain.decision_core.next_sum;
        end

        if (uut.cnn_valid_in && pixels_fed < 5) begin
            $display("   [BRAM SPY] Feeding CNN Pixel %0d: Value = %0d", pixels_fed, uut.cnn_pixel_in);
            pixels_fed = pixels_fed + 1;
        end

        if (uut.conductor.current_state == 2'd1) begin
            watchdog_timer = watchdog_timer + 1;
            if (uut.cnn_done == 1'b1) begin
                $display("\n   >>> [AI BINGO!] MATH FINISHED <<<");
                $display("   >>> CAPTURED CONFIDENCE SCORE: %0d <<< \n", real_confidence_score);
            end
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
            $display("--- FINAL SYSTEM DIAGNOSTIC ---");
            $display("CNN Confidence Score: %0d", real_confidence_score);
            if (system_state_led) $display(">>> [LOCK] Target confirmed. <<<");
            else                  $display(">>> [REJECT] Not a drone. <<<");
            $display("==================================================\n");
            
        end else begin
            $display("   -> [RADAR SILENT] No movement detected. Airspace is clear.");
        end
        $finish;
    end
endmodule