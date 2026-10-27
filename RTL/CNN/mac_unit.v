`timescale 1ns / 1ps

module mac_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        valid_in,
    input  wire [71:0] pixels_in,
    input  wire [71:0] weights_in,
    output reg         valid_out,
    output reg  [7:0]  pixel_out
);

    // Stage 1: nine signed 16-bit products.
    wire signed [15:0] product_comb [0:8];
    reg  signed [15:0] product_s1   [0:8];

    genvar g;
    generate
        for (g = 0; g < 9; g = g + 1) begin : GEN_MULT
            wire signed [15:0] pixel_ext;
            wire signed [15:0] weight_ext;

            assign pixel_ext =
                $signed({8'b0, pixels_in[g*8 +: 8]});

            assign weight_ext =
                $signed({{8{weights_in[g*8+7]}},
                          weights_in[g*8 +: 8]});

            assign product_comb[g] = pixel_ext * weight_ext;
        end
    endgenerate

    // Stage 2: pairwise sums.
    reg signed [16:0] pair01_s2, pair23_s2;
    reg signed [16:0] pair45_s2, pair67_s2;
    reg signed [15:0] product8_s2;

    // Stage 3: sums of four products.
    reg signed [17:0] sum0123_s3, sum4567_s3;
    reg signed [15:0] product8_s3;

    // Stage 4: final sum.
    reg signed [19:0] total_s4;

    // Valid markers travel with the corresponding data.
    reg valid_s1, valid_s2, valid_s3, valid_s4;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 9; i = i + 1)
                product_s1[i] <= 16'sd0;

            pair01_s2  <= 17'sd0;
            pair23_s2  <= 17'sd0;
            pair45_s2  <= 17'sd0;
            pair67_s2  <= 17'sd0;
            product8_s2 <= 16'sd0;

            sum0123_s3 <= 18'sd0;
            sum4567_s3 <= 18'sd0;
            product8_s3 <= 16'sd0;

            total_s4 <= 20'sd0;

            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            valid_s3 <= 1'b0;
            valid_s4 <= 1'b0;

            valid_out <= 1'b0;
            pixel_out <= 8'd0;
        end else begin
            // Stage 1: multiply current input window.
            for (i = 0; i < 9; i = i + 1)
                product_s1[i] <= product_comb[i];

            valid_s1 <= valid_in;

            // Stage 2: add pairs of previous products.
            pair01_s2 <=
                $signed({product_s1[0][15], product_s1[0]}) +
                $signed({product_s1[1][15], product_s1[1]});

            pair23_s2 <=
                $signed({product_s1[2][15], product_s1[2]}) +
                $signed({product_s1[3][15], product_s1[3]});

            pair45_s2 <=
                $signed({product_s1[4][15], product_s1[4]}) +
                $signed({product_s1[5][15], product_s1[5]});

            pair67_s2 <=
                $signed({product_s1[6][15], product_s1[6]}) +
                $signed({product_s1[7][15], product_s1[7]});

            product8_s2 <= product_s1[8];
            valid_s2 <= valid_s1;

            // Stage 3: combine pairs.
            sum0123_s3 <=
                $signed({pair01_s2[16], pair01_s2}) +
                $signed({pair23_s2[16], pair23_s2});

            sum4567_s3 <=
                $signed({pair45_s2[16], pair45_s2}) +
                $signed({pair67_s2[16], pair67_s2});

            product8_s3 <= product8_s2;
            valid_s3 <= valid_s2;

            // Stage 4: sum all nine products.
            total_s4 <=
                $signed({{2{sum0123_s3[17]}}, sum0123_s3}) +
                $signed({{2{sum4567_s3[17]}}, sum4567_s3}) +
                $signed({{4{product8_s3[15]}}, product8_s3});

            valid_s4 <= valid_s3;

            // Stage 5: ReLU, Q7 scaling, saturation.
            valid_out <= valid_s4;

            if (valid_s4) begin
                if (total_s4 < 0)
                    pixel_out <= 8'd0;
                else if (total_s4 >= 20'sd32768)
                    pixel_out <= 8'd255;
                else
                    pixel_out <= total_s4[14:7];
            end
        end
    end

endmodule