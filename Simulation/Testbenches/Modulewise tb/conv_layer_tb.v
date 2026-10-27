`timescale 1ns / 1ps

module conv_layer_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        valid_out;
    wire [7:0]  feature_0;
    wire [7:0]  feature_1;
    wire [7:0]  feature_2;
    wire [7:0]  feature_3;

    // 2. Instantiate the Unit Under Test (UUT)
    conv_layer uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .feature_0(feature_0),
        .feature_1(feature_1),
        .feature_2(feature_2),
        .feature_3(feature_3)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    integer i;
    integer valid_count;

    // 4. The Stimulus Process
    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        pixel_in = 0;
        valid_count = 0;

        // Wait for global reset
        #20;
        reset = 0;
        #10;

        $display("\n==================================================");
        $display("--- STARTING V8 ENGINE (CONV LAYER) TEST ---");
        $display("==================================================");
        $display("Feeding a full 32x32 image (1024 pixels) into the pipeline...\n");
        
        // Turn on the data stream
        valid_in = 1;
        
        // Feed exactly 1024 pixels (one full 32x32 image frame)
        for (i = 1; i <= 1024; i = i + 1) begin
            
            // Create a fake image pattern (loops 0 to 255 to prevent 8-bit overflow)
            pixel_in = i % 256; 
            
            #10; // Wait 1 clock cycle for hardware to process
            
            // The moment the hardware asserts valid_out, we capture the data
            if (valid_out) begin
                valid_count = valid_count + 1;
                
                // Print only the first 10 valid calculations to keep the console clean
                if (valid_count <= 10) begin
                    $display("Pixel %0d Ingested | MACs Fired! -> F0: %0d | F1: %0d | F2: %0d | F3: %0d", 
                             i, feature_0, feature_1, feature_2, feature_3);
                end
                
                if (valid_count == 11) begin
                    $display("... [Suppressing remaining 1000+ logs. Check Waveform for full data] ...");
                end
            end
        end

        // Turn off stream
        valid_in = 0;
        #50;
        
        $display("\n==================================================");
        $display("Total Valid MAC Computations: %0d (Expected 1024)", valid_count);
        $display("--- VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        
        $finish;
    end

endmodule