`timescale 1ns / 1ps

module vajra_top_tb;

    reg clk, reset, valid_in;
    reg [7:0] pixel_in;
    wire done, target_locked;

    // Instantiate UUT
    vajra_top uut (
        .clk(clk), .reset(reset), .valid_in(valid_in), 
        .pixel_in(pixel_in), .done(done), .target_locked(target_locked)
    );

    // 100MHz Clock
    always #5 clk = ~clk;

    integer i;

    // ==========================================
    // STIMULUS
    // ==========================================
    initial begin
        clk = 0; reset = 1; valid_in = 0; pixel_in = 0;
        #100; reset = 0; #20;

        $display("\n==================================================");
        $display("--- STARTING FINAL SYSTEM VERIFICATION ---");
        $display("==================================================");

        $display("\nTime %0t: Injecting 32x32 Image...", $time);
        
        // Inject 1024 pixels with the required Throttle
        for (i = 0; i < 1024; i = i + 1) begin
            pixel_in = 8'd128; // Gray image
            valid_in = 1'b1; #10;
            valid_in = 1'b0; #10; // Throttle to prevent Serializer collision
        end
        
        // Flush pipeline
        for (i = 0; i < 20; i = i + 1) begin
            pixel_in = 8'd0;
            valid_in = 1'b1; #10;
            valid_in = 1'b0; #10;
        end
        
        valid_in = 0;
        
        // Timeout Catch (Only triggers if the tripwire below fails)
        #100000; 
        $display("\n-> [FATAL ERROR] Timeout! The 'done' tripwire never caught a pulse.");
        $finish;
    end

    // ==========================================
    // THE TRIPWIRE (Catches the 10ns pulse instantly)
    // ==========================================
    always @(posedge clk) begin
        if (done) begin
            $display("\n-> [SUCCESS] DONE FLAG CAUGHT AT TIME %0t!", $time);
            $display("-> [DECISION] TARGET LOCKED: %0b", target_locked);
            $display("==================================================\n");
            $finish; // Immediately end the simulation successfully!
        end
    end

endmodule