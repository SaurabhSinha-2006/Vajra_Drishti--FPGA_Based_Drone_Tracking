`timescale 1ns / 1ps

module sad_tracker_tb;

    // Inputs
    reg clk;
    reg reset;
    reg enable;
    reg [9:0] start_x;
    reg [9:0] start_y;
    reg [7:0] template_pixel;
    reg [7:0] search_pixel;

    // Outputs
    wire [9:0] template_addr;
    wire [18:0] search_addr;
    wire [9:0] new_x;
    wire [9:0] new_y;
    wire tracking_done;
    wire target_lost;

    // Instantiate the Unit Under Test (UUT)
    sad_tracker uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .start_x(start_x),
        .start_y(start_y),
        .template_addr(template_addr),
        .template_pixel(template_pixel),
        .search_addr(search_addr),
        .search_pixel(search_pixel),
        .new_x(new_x),
        .new_y(new_y),
        .tracking_done(tracking_done),
        .target_lost(target_lost)
    );

    // ==========================================
    // FAKE MEMORY ARRAYS (Simulating BRAM & Frame Buffer)
    // ==========================================
    reg [7:0] template_memory [0:1023];
    reg [7:0] search_memory [0:307199];

    // FAKE BRAM LATENCY: Memories take 1 clock cycle to output data!
    always @(posedge clk) begin
        template_pixel <= template_memory[template_addr];
        search_pixel   <= search_memory[search_addr];
    end

    // Clock Generation (25 MHz)
    always #20 clk = ~clk;

    // ==========================================
    // HELPER TASKS TO DRAW FAKE DRONES
    // ==========================================
    integer i, j;

    task clear_search_memory;
        begin
            // Fill whole screen with "Sky" (Value = 100)
            for(i=0; i<307200; i=i+1) begin
                search_memory[i] = 8'd100;
            end
        end
    endtask

    task draw_drone;
        input [9:0] d_x;
        input [9:0] d_y;
        begin
            // Draw a 32x32 "Drone" (Value = 50) at the given X,Y
            for(i=0; i<32; i=i+1) begin
                for(j=0; j<32; j=j+1) begin
                    search_memory[(d_y+i)*640 + (d_x+j)] = 8'd50;
                end
            end
        end
    endtask

    // ==========================================
    // THE TEST SEQUENCE
    // ==========================================
    initial begin
        // 1. Initialize System
        clk = 0;
        reset = 1;
        enable = 0;
        start_x = 320; // Center of screen
        start_y = 240;
        
        // Fill Template Memory with the "Drone" (Value = 50)
        for(i=0; i<1024; i=i+1) template_memory[i] = 8'd50;
        
        #100; reset = 0; #100;

        $display("\n==================================================");
        $display("--- RUNNING SAD TRACKER UNIT TESTS ---");
        $display("==================================================\n");

        // --------------------------------------------------
        // TEST 1: DRONE HAS NOT MOVED
        // --------------------------------------------------
        $display("[TEST 1] Drone is stationary at X=320, Y=240");
        clear_search_memory();
        draw_drone(320, 240); // Draw drone exactly where it was
        
        enable = 1; #40; enable = 0; // Pulse enable
        wait(tracking_done == 1'b1); // Wait for the tracker to finish
        #40;
        
        $display("   -> SAD Scores | Center: %0d | Up: %0d | Down: %0d | Left: %0d | Right: %0d", 
                 uut.sad_center, uut.sad_up, uut.sad_down, uut.sad_left, uut.sad_right);
        $display("   -> Result: New X=%0d, New Y=%0d, Target Lost=%b\n", new_x, new_y, target_lost);

        // --------------------------------------------------
        // TEST 2: DRONE MOVED RIGHT
        // --------------------------------------------------
        $display("[TEST 2] Drone moved RIGHT to X=325, Y=240");
        clear_search_memory();
        draw_drone(325, 240); // Draw drone 5 pixels to the right
        
        enable = 1; #40; enable = 0; 
        wait(tracking_done == 1'b1);
        #40;
        
        $display("   -> SAD Scores | Center: %0d | Up: %0d | Down: %0d | Left: %0d | Right: %0d", 
                 uut.sad_center, uut.sad_up, uut.sad_down, uut.sad_left, uut.sad_right);
        $display("   -> Result: New X=%0d, New Y=%0d, Target Lost=%b\n", new_x, new_y, target_lost);

        // --------------------------------------------------
        // TEST 3: DRONE DISAPPEARED (TARGET LOST)
        // --------------------------------------------------
        $display("[TEST 3] Drone flew away (Screen is just Sky)");
        clear_search_memory(); // Screen is empty!
        
        enable = 1; #40; enable = 0; 
        wait(tracking_done == 1'b1);
        #40;
        
        $display("   -> SAD Scores | Center: %0d | Up: %0d | Down: %0d | Left: %0d | Right: %0d", 
                 uut.sad_center, uut.sad_up, uut.sad_down, uut.sad_left, uut.sad_right);
        $display("   -> Result: New X=%0d, New Y=%0d, Target Lost=%b", new_x, new_y, target_lost);
        
        $display("\n==================================================");
        $display("--- SAD TRACKER UNIT TESTS COMPLETE ---");
        $display("==================================================\n");
        $finish;
    end

endmodule