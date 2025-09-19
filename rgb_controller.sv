`timescale 1ns / 1ps

module rgb_controller (
    input  logic       sw_r,
    input  logic       sw_g,
    input  logic       sw_b,
    input  logic [3:0] r_internal,
    input  logic [3:0] g_internal,
    input  logic [3:0] b_internal,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port
);

    assign r_port = sw_r ? r_internal : 4'b0;
    assign g_port = sw_g ? g_internal : 4'b0;
    assign b_port = sw_b ? b_internal : 4'b0;

endmodule
