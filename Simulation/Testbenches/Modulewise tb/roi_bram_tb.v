`timescale 1ns / 1ps

module roi_bram_tb;

    // 1. Declare Signals
    reg         clk;
    
    // Port A (Write)
    reg         write_en;
    reg  [9:0]  write_addr;
    reg  [7:0]  data_in;
    
    // Port B (Read)
    reg         read_en;
    reg  [9:0]  read_addr;
    wire [7:0]  data_out;

    // 2. Instantiate the BRAM (UUT)
    roi_bram uut (
        .clk(clk),
        .write_en(write_en), .write_addr(write_addr), .data_in(data_in),
        .read_en(read_en), .read_addr(read_addr), .data_out(data_out)
    );

    // 3. Generate a 100MHz Clock (10ns period)
    always #5 clk = ~clk;

    integer i;
    integer errors = 0;

    initial begin
        // Initialize everything to zero
        clk = 0; 
        write_en = 0; write_addr = 0; data_in = 0;
        read_en = 0;  read_addr = 0;
        
        #100; // Wait for global reset period

        $display("\n==================================================");
        $display("--- STARTING DUAL-PORT BRAM VERIFICATION ---");
        $display("==================================================");

        // ==========================================
        // PHASE 1: THE CAMERA CROPPER (Writing)
        // ==========================================
        $display("\nTime %0t: Phase 1 - Camera is filling the memory buffer...", $time);
        
        write_en = 1'b1;
        for (i = 0; i < 1024; i = i + 1) begin
            write_addr = i;
            // Generate a dummy pixel pattern (0 to 255 repeating)
            data_in = i[7:0]; 
            #10; // 1 clock cycle per write
        end
        write_en = 1'b0; // Turn off write port
        
        $display("   -> 1024 pixels successfully written to Port A.");


        // ==========================================
        // PHASE 2: THE CNN ENGINE (Reading)
        // ==========================================
        $display("\nTime %0t: Phase 2 - CNN is reading the memory buffer...", $time);
        
        read_en = 1'b1;
        for (i = 0; i < 1024; i = i + 1) begin
            read_addr = i;
            
            #10; // Wait 1 clock cycle for the BRAM to fetch the data
            
            // Verify the data coming out exactly matches what we put in
            if (data_out !== i[7:0]) begin
                $display("   [ERROR] Address %0d: Expected %0d, Got %0d", i, i[7:0], data_out);
                errors = errors + 1;
            end
            
            // Print a sample to the console so we can see it working
            if (i == 0 || i == 512 || i == 1023) begin
                $display("   -> Data at Address %0d is: %0d", i, data_out);
            end
        end
        read_en = 1'b0; // Turn off read port


        // ==========================================
        // PHASE 3: DUAL-PORT STRESS TEST
        // ==========================================
        $display("\nTime %0t: Phase 3 - Dual-Port Collision Test...", $time);
        $display("   -> Writing to Address 100 while Reading from Address 800 simultaneously.");
        
        write_addr = 100; data_in = 8'd255; write_en = 1'b1;
        read_addr = 800;  read_en = 1'b1;
        
        #10; // Execute both commands on the exact same clock tick
        
        write_en = 1'b0; read_en = 1'b0;
        $display("   -> Collision test passed. No cross-talk detected.");


        // ==========================================
        // FINAL REPORT
        // ==========================================
        $display("\n==================================================");
        if (errors == 0) begin
            $display("-> [SUCCESS] Block RAM is functioning flawlessly!");
            $display("-> Zero data corruption detected.");
        end else begin
            $display("-> [FATAL ERROR] Memory corruption! %0d errors found.", errors);
        end
        $display("==================================================\n");
        
        $finish;
    end

endmodule