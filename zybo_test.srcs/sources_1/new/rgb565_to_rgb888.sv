`timescale 1ns / 1ps

module rgb565_to_rgb888 (
    input  logic [4:0] r5,
    input  logic [5:0] g6,
    input  logic [4:0] b5,
    output logic [7:0] r8,
    output logic [7:0] g8,
    output logic [7:0] b8
);
    assign r8 = {r5, r5[4:2]};
    assign g8 = {g6, g6[5:4]};
    assign b8 = {b5, b5[4:2]};
endmodule
