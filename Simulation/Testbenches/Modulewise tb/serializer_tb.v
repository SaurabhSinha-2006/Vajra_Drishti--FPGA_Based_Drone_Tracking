`timescale 1ns / 1ps

module serializer_tb;

    // 1. Declare Signals
    reg        clk;
    reg        reset;
    reg        valid_in;
    reg  [7:0] p0, p1, p2, p3;
    
    wire       valid_out;
    wire [7:0] pixel_out;

    // 2. Instantiate the Unit Under Test (UUT)
    serializer uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .p0(p0),
        .p1(p1),
        .p2(p2),
        .p3(p3),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    // 4. The Stimulus Process
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        p0 = 0; p1 = 0; p2 = 0; p3 = 0;

        // Wait for global reset
        #20;
        reset = 0;
        #10;

        $display("\n==================================================");
        $display("--- STARTING SERIALIZER VERIFICATION ---");
        $display("==================================================");

        // ==========================================
        // TEST BATCH 1: Standard Ingestion
        // ==========================================
        $display("\nInjecting Batch 1: {10, 20, 30, 40} at Time %0t", $time);
        valid_in = 1;
        p0 = 8'd10; p1 = 8'd20; p2 = 8'd30; p3 = 8'd40;
        #10; // valid_in is strictly high for only 1 clock cycle!
        valid_in = 0; 
        
        // Wait 3 clock cycles for the hardware to shift out p1, p2, and p3
        #30; 

        // ==========================================
        // TEST BATCH 2: Continuous Flow (Max Pool Timing)
        // ==========================================
        // The exact moment the queue is empty, the next Max Pool batch arrives
        $display("\nInjecting Batch 2: {55, 66, 77, 88} at Time %0t", $time);
        valid_in = 1;
        p0 = 8'd55; p1 = 8'd66; p2 = 8'd77; p3 = 8'd88;
        #10; 
        valid_in = 0;
        
        // Wait for it to finish
        #40;

        $display("\n==================================================");
        $display("--- VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        $finish;
    end

    // 5. The Hardware Output Monitor
    always @(posedge clk) begin
        if (valid_out) begin
            $display("   -> Shifted Output: %0d", pixel_out);
        end
    end

endmodule