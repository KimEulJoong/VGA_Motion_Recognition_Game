`timescale 1ns / 1ps

module LineBuffer (
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [15:0] data,
    output logic [15:0] PixelData_00,
    output logic [15:0] PixelData_01,
    output logic [15:0] PixelData_02,
    output logic [15:0] PixelData_10,
    output logic [15:0] PixelData_11,
    output logic [15:0] PixelData_12,
    output logic [15:0] PixelData_20,
    output logic [15:0] PixelData_21,
    output logic [15:0] PixelData_22
);

    logic [15:0] fmem0[0:639];
    logic [15:0] fmem1[0:639];
    logic [15:0] fmem2[0:639];

    always_ff @(posedge clk) begin
        if ((x_pixel < 639) && (y_pixel < 479)) begin
            fmem2[x_pixel] <= fmem1[x_pixel];
            fmem1[x_pixel] <= fmem0[x_pixel];
            fmem0[x_pixel] <= data;
        end
    end

    always_ff @(posedge clk) begin
        PixelData_00 <= (y_pixel == 0 || x_pixel == 0) ? 0 : fmem2[x_pixel+1];
        PixelData_01 <= (y_pixel == 0) ? 0 : fmem2[x_pixel];
        PixelData_02 <= (y_pixel == 0 || x_pixel == 639) ? 0 : fmem2[x_pixel-1];
        PixelData_10 <= (x_pixel == 0) ? 0 : fmem1[x_pixel+1];
        PixelData_11 <= fmem1[x_pixel];
        PixelData_12 <= (x_pixel == 639) ? 0 : fmem1[x_pixel-1];
        PixelData_20 <= (x_pixel == 0 || y_pixel == 479) ? 0 : fmem0[x_pixel+1];
        PixelData_21 <= (y_pixel == 479) ? 0 : fmem0[x_pixel];
        PixelData_22 <= (x_pixel == 639 || y_pixel == 479) ? 0 : fmem0[x_pixel-1];
    end
endmodule