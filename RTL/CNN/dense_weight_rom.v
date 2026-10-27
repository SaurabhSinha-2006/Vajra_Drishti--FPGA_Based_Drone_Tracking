`timescale 1ns / 1ps

module dense_weight_rom #(
    parameter ADDR_WIDTH = 10, // 10 bits to address ~900 weights
    parameter DATA_WIDTH = 8   // 8-bit quantized weights
)(
    input  wire                   clk,
    input  wire                   ena,
    input  wire  [ADDR_WIDTH-1:0] addr,
    output reg signed [DATA_WIDTH-1:0] dout
);

    // 1024 elements deep, 8 bits wide
    reg signed [DATA_WIDTH-1:0] rom_array [0:(1<<ADDR_WIDTH)-1];

    initial begin
        // IMPORTANT: Ensure "vajra_dense_weights.hex" is added to your Vivado project sources
        $readmemh("vajra_dense_weights_final.hex", rom_array);
    end

    always @(posedge clk) begin
        if (ena) begin
            dout <= rom_array[addr];
        end
    end

endmodule