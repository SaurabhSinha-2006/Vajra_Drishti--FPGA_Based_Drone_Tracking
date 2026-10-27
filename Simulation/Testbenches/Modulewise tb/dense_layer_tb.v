`timescale 1ns / 1ps

module dense_layer_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        done;
    wire        target_locked;

    // 2. Instantiate the Unit Under Test (UUT)
    // We leave the THRESHOLD at the default 150,000
    dense_layer uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .done(done),
        .target_locked(target_locked)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    integer i;

    // 4. The Stimulus Process
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        pixel_in = 0;

        // Wait for global reset
        #20;
        reset = 0;
        #10;

        $display("\n==================================================");
        $display("--- STARTING DENSE LAYER VERIFICATION ---");
        $display("==================================================");
        
        // ==========================================
        // TEST FRAME 1: A "Gray" Image
        // ==========================================
        $display("Injecting Frame 1: 900 pixels of value '100'...");
        valid_in = 1;
        
        for (i = 0; i < 900; i = i + 1) begin
            pixel_in = 8'd100; 
            #10; // Wait 1 clock cycle per pixel
        end
        
        valid_in = 0; // End of the frame stream
        pixel_in = 0;
        
        // Wait a few cycles to let the 1-cycle pipeline delay finish the final math
        #30; 

        // ==========================================
        // TEST FRAME 2: A "White" Image
        // ==========================================
        $display("\nInjecting Frame 2: 900 pixels of value '255'...");
        valid_in = 1;
        
        for (i = 0; i < 900; i = i + 1) begin
            pixel_in = 8'd255; 
            #10; 
        end
        
        valid_in = 0;
        
        #50;
        $display("\n==================================================");
        $display("--- VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        
        $finish;
    end

    // 5. The Hardware Monitor
    // This block triggers the exact nanosecond the hardware asserts the 'done' flag
    always @(posedge clk) begin
        if (done) begin
            $display("-> DONE FLAG ASSERTED!");
            // We use hierarchical referencing (uut.next_sum) to peek inside the module's wiring
            $display("-> Final Calculated Sum: %0d", uut.next_sum);
            $display("-> Target Locked: %0b", target_locked);
        end
    end

endmodule