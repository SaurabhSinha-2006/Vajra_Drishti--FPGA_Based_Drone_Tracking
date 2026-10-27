`timescale 1ns / 1ps

module max_pool_tb;

    // 1. Declare Signals
    reg         clk;
    reg         reset;
    reg         valid_in;
    reg  [7:0]  pixel_in;
    
    wire        valid_out;
    wire [7:0]  pixel_out;

    // 2. Instantiate the Unit Under Test (UUT)
    // We override the WIDTH parameter to 4 to make the math easy to verify
    max_pool #(
        .WIDTH(4) 
    ) uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .pixel_out(pixel_out)
    );

    // 3. Generate a 100MHz Clock
    always #5 clk = ~clk;

    // Array to hold our fake 4x4 image
    reg [7:0] fake_image [0:15];
    integer i;
    integer out_count;

    // 4. The Stimulus Process
    initial begin
        // Load the fake image data
        // Row 0
        fake_image[0] = 10; fake_image[1] = 20; fake_image[2] = 30; fake_image[3] = 40;
        // Row 1
        fake_image[4] = 50; fake_image[5] = 60; fake_image[6] = 70; fake_image[7] = 80;
        // Row 2
        fake_image[8] = 15; fake_image[9] = 25; fake_image[10]= 35; fake_image[11]= 45;
        // Row 3
        fake_image[12]= 55; fake_image[13]= 65; fake_image[14]= 75; fake_image[15]= 85;

        // Initialize Inputs
        clk = 0;
        reset = 1;
        valid_in = 0;
        pixel_in = 0;
        out_count = 0;

        // Wait for global reset
        #20;
        reset = 0;
        #10;

        $display("\n==================================================");
        $display("--- STARTING MAX POOL VERIFICATION ---");
        $display("==================================================");
        $display("Feeding a 4x4 image. Expecting exactly 4 outputs: 60, 80, 65, 85.\n");
        
        valid_in = 1;
        
        // Feed the 16 pixels into the hardware one by one
        for (i = 0; i < 16; i = i + 1) begin
            pixel_in = fake_image[i];
            #10; // Wait 1 clock cycle for ingestion
        end

        valid_in = 0;
        
        // Wait a few extra clock cycles to ensure the final pipeline stage clears
        #50; 
        
        $display("\n==================================================");
        $display("Total Valid Max Pool Outputs: %0d (Expected 4)", out_count);
        $display("--- VERIFICATION COMPLETE ---");
        $display("==================================================\n");
        
        $finish;
    end

    // 5. Output Monitor
    // This block runs independently and prints whenever the hardware asserts valid_out
    always @(posedge clk) begin
        if (valid_out) begin
            out_count = out_count + 1;
            $display("Hardware Output %0d: %0d", out_count, pixel_out);
        end
    end

endmodule