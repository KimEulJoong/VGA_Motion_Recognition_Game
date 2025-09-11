`timescale 1ns / 1ps

module LineBuffer (
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [11:0] data,
    output logic [11:0] PixelData_00,
    output logic [11:0] PixelData_01,
    output logic [11:0] PixelData_02,
    output logic [11:0] PixelData_10,
    output logic [11:0] PixelData_11,
    output logic [11:0] PixelData_12,
    output logic [11:0] PixelData_20,
    output logic [11:0] PixelData_21,
    output logic [11:0] PixelData_22
);

    logic [11:0] PixelMem0[0:639];
    logic [11:0] PixelMem1[0:639];
    logic [11:0] PixelMem2[0:639];

    always_ff @(posedge clk) begin
        if ((x_pixel < 640) && (y_pixel < 480)) begin
            PixelMem2[x_pixel] <= PixelMem1[x_pixel];
            PixelMem1[x_pixel] <= PixelMem0[x_pixel];
            PixelMem0[x_pixel] <= data;
        end
    end

    always_ff @(posedge clk) begin
        PixelData_00 <= ((!x_pixel) || (!y_pixel)) ? 0 : PixelMem2[x_pixel-1];
        PixelData_01 <= (!y_pixel) ? 0 : PixelMem2[x_pixel];
        PixelData_02 <= ((!y_pixel) || (x_pixel == 639)) ? 0 : PixelMem2[x_pixel+1];
        PixelData_10 <= (!x_pixel) ? 0 : PixelMem1[x_pixel-1];
        PixelData_11 <= PixelMem1[x_pixel];
        PixelData_12 <= (x_pixel == 639) ? 0 : PixelMem1[x_pixel+1];
        PixelData_20 <= (!x_pixel || (y_pixel == 479)) ? 0 : PixelMem0[x_pixel-1];
        PixelData_21 <= (y_pixel == 479) ? 0 : PixelMem0[x_pixel];
        PixelData_22 <= ((x_pixel == 639) || (y_pixel == 479)) ? 0 : PixelMem0[x_pixel+1];
    end

endmodule
