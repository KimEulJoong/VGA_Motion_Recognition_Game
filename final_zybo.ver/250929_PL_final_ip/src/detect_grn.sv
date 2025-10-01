`timescale 1ns / 1ps

module detect_grn (
    input  logic [23:0] rgb_in,
    output logic        g_detect
);

    logic [7:0] r8, g8, b8;
    logic [7:0] max_val, min_val, delta;
    
    assign r8 = rgb_in[23:16];
    assign g8 = rgb_in[15:8];
    assign b8 = rgb_in[7:0];

    logic [9:0] g9;
    assign g9 = g8 << 1;
    logic [9:0] sum_rb;
    assign sum_rb = r8 + b8;

    assign g_detect = (g8 > 8'h40) && (g8 < 8'he0) && (r8 + b8 < 256) && (g9 > sum_rb);

    // assign g_detect = (g > r+1) && (g >= b+1) && (g >= 3);

endmodule
