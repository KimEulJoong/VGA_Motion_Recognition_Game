`timescale 1ns / 1ps

module frame_buffer (
    // write side
    input  logic        wclk,
    input  logic        we,
    input  logic        frame_stop,
    input  logic [16:0] wAddr,
    input  logic [15:0] wData,
    // read side
    input  logic        rclk,
    input  logic        oe,
    input  logic [16:0] rAddr,
    output logic [15:0] rData
);

    logic [15:0] mem[0:(320 * 240 - 1)];

    // write side
    always_ff @(posedge wclk) begin
        if (we && !frame_stop) begin
            mem[wAddr] <= wData;
        end else begin
            mem[wAddr] <= mem[wAddr];
        end
    end

    // read side
    always_ff @(posedge rclk) begin
        if (oe) begin
            rData <= mem[rAddr];
        end
    end

endmodule
