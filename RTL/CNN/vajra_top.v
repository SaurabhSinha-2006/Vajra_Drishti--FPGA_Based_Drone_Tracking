`timescale 1ns / 1ps

module vajra_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        valid_in,
    input  wire [7:0]  pixel_in,
    output wire        done,
    output wire        target_locked,
    output wire [31:0] final_sum
);

    wire       conv_valid_out;
    wire [7:0] conv_f0, conv_f1, conv_f2, conv_f3;
    wire       pool_valid_sync;
    wire [7:0] pool_p0, pool_p1, pool_p2, pool_p3;
    wire       serial_valid_out;
    wire [7:0] serial_pixel_out;

    conv_layer core_conv (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(conv_valid_out),
        .feature_0(conv_f0),
        .feature_1(conv_f1),
        .feature_2(conv_f2),
        .feature_3(conv_f3)
    );

    // Convolution output is 30x30. Each 2x2 pool produces 15x15.
    max_pool #(.WIDTH(30)) pool_0 (
        .clk(clk), .reset(reset),
        .valid_in(conv_valid_out), .pixel_in(conv_f0),
        .valid_out(pool_valid_sync), .pixel_out(pool_p0)
    );

    max_pool #(.WIDTH(30)) pool_1 (
        .clk(clk), .reset(reset),
        .valid_in(conv_valid_out), .pixel_in(conv_f1),
        .valid_out(), .pixel_out(pool_p1)
    );

    max_pool #(.WIDTH(30)) pool_2 (
        .clk(clk), .reset(reset),
        .valid_in(conv_valid_out), .pixel_in(conv_f2),
        .valid_out(), .pixel_out(pool_p2)
    );

    max_pool #(.WIDTH(30)) pool_3 (
        .clk(clk), .reset(reset),
        .valid_in(conv_valid_out), .pixel_in(conv_f3),
        .valid_out(), .pixel_out(pool_p3)
    );

    serializer data_bridge (
        .clk(clk),
        .reset(reset),
        .valid_in(pool_valid_sync),
        .p0(pool_p0), .p1(pool_p1), .p2(pool_p2), .p3(pool_p3),
        .valid_out(serial_valid_out),
        .pixel_out(serial_pixel_out)
    );

    dense_layer #(
        .MAX_WEIGHTS(900),
        .THRESHOLD(-150000)
    ) decision_core (
        .clk(clk),
        .reset(reset),
        .valid_in(serial_valid_out),
        .pixel_in(serial_pixel_out),
        .done(done),
        .target_locked(target_locked),
        .accumulator_out(final_sum)
    );

endmodule
