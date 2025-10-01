`timescale 1ns / 1ps

module baud_gen(
    input  logic clk,
    input  logic reset,
    output logic br_tick
);
    logic [$clog2(100_000_000 / 115200 / 16)-1:0] br_counter;
    //logic [3:0] br_counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            br_counter <= 0;
            br_tick <= 1'b0;
        end else begin
            if (br_counter == 100_000_000 / 115200 / 16 - 1) begin
                //if (br_counter == 10 - 1) begin
                br_counter <= 0;
                br_tick <= 1'b1;
            end else begin
                br_counter <= br_counter + 1;
                br_tick <= 1'b0;
            end
        end
    end

endmodule

// 나누기 말고 counter로 58개 세/기