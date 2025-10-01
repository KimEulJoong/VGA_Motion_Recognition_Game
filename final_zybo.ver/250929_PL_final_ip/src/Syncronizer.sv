`timescale 1ns / 1ps

module Synchronizer (
    input  logic       clk,
    input  logic       reset,
    input  logic [2:0] d_in,
    output logic [2:0] d_out
);

    logic [2:0] d_ff_1, d_ff_2, d_ff_3;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            d_ff_1 <= 0;
            d_ff_2 <= 0;
            d_ff_3 <= 0;
        end else begin
            d_ff_1 <= d_in;
            d_ff_2 <= d_ff_1;
            d_ff_3 <= d_ff_2;
        end
    end

    assign d_out = d_ff_3;

endmodule
