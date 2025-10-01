`timescale 1ns / 1ps

module detect_red (
    input  logic [23:0] rgb_in,
    output logic        r_detect
);

    logic [7:0] r8, g8, b8;
    logic [7:0] max_val, min_val, delta;
    
    assign r8 = rgb_in[23:16];
    assign g8 = rgb_in[15:8];
    assign b8 = rgb_in[7:0];

    assign max_val = (r8 > g8) ? ((r8 > b8) ? r8 : b8) : ((g8 > b8) ? g8 : b8);
    assign min_val = (r8 < g8) ? ((r8 < b8) ? r8 : b8) : ((g8 < b8) ? g8 : b8);
    assign delta = max_val - min_val;
    assign r_is_max = (r8 > g8) && (r8 > b8) && (r8 > 32);
    assign s_is_ok = (delta >= (max_val >> 2));

    assign r_detect = r_is_max && s_is_ok;

endmodule
