`timescale 1ns / 1ps

module weight_rom_tb;

    // Testbench Signals
    reg clk;
    reg ena;
    reg [5:0] conv_addr;   // 6 bits fits 0-63 (We need 0-35)
    reg [9:0] dense_addr;  // 10 bits fits 0-1023 (We need 0-899)
    
    wire signed [7:0] conv_data;
    wire signed [7:0] dense_data;

    // Instantiate the Convolutional ROM
    conv_weight_rom #(
        .ADDR_WIDTH(6),
        .DATA_WIDTH(8)
    ) uut_conv (
        .clk(clk),
        .ena(ena),
        .addr(conv_addr),
        .dout(conv_data)
    );

    // Instantiate the Dense ROM
    dense_weight_rom #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(8)
    ) uut_dense (
        .clk(clk),
        .ena(ena),
        .addr(dense_addr),
        .dout(dense_data)
    );

    // Generate a 100MHz clock
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Initialize inputs
        clk = 0;
        ena = 1;
        conv_addr = 0;
        dense_addr = 0;

        // Wait for global reset
        #20;
        
        $display("\n==================================================");
        $display("--- VERIFYING CONV WEIGHTS (Expected: 36) ---");
        $display("==================================================");
        for (i = 0; i < 36; i = i + 1) begin
            conv_addr = i;
            #10; // Wait 1 clock cycle for ROM to output data
            // Print both Hexadecimal and signed Decimal formats
            $display("Conv Addr %0d: Hex %h | Signed Dec: %d", i, conv_data, conv_data);
        end

        $display("\n==================================================");
        $display("--- VERIFYING DENSE WEIGHTS (Expected: 900) ---");
        $display("==================================================");
        $display("Showing first 5 and last 5 to avoid spamming the console...");

        // Verify first 5 Dense weights
        for (i = 0; i < 5; i = i + 1) begin
            dense_addr = i;
            #10;
            $display("Dense Addr %0d: Hex %h | Signed Dec: %d", i, dense_data, dense_data);
        end

        $display("... [Skipping middle weights] ...");

        // Verify last 5 Dense weights (895 to 899)
        for (i = 895; i < 900; i = i + 1) begin
            dense_addr = i;
            #10;
            $display("Dense Addr %0d: Hex %h | Signed Dec: %d", i, dense_data, dense_data);
        end

        #20;
        $display("\n--- MEMORY VERIFICATION COMPLETE ---");
        $finish; // Stop the simulation
    end

endmodule