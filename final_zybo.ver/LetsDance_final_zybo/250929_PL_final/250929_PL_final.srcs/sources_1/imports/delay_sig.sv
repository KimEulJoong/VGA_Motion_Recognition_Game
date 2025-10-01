`timescale 1ns / 1ps

module delay_sig (
    input  logic       clk,
    input  logic       reset,
    input  logic [1:0] sel_in,
    output logic [1:0] sel_out
);

    logic [1:0] sel_d1;
    logic [1:0] sel_d2;
    logic [1:0] sel_d3;

    always_ff @(posedge clk) begin
        if (reset) begin
            sel_d1  <= 0;
            sel_d2  <= 0;
            sel_d3  <= 0;
            sel_out <= 0;
        end else begin
            sel_d1  <= sel_in;
            sel_d2  <= sel_d1;
            sel_d3  <= sel_d2;
            sel_out <= sel_d3;
        end
    end

endmodule
