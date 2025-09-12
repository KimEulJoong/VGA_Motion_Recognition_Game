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

module line_buffer_640 (
    input logic pclk,
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    input logic [11:0] data,
    output logic [11:0] data_00,
    output logic [11:0] data_01,
    output logic [11:0] data_02,
    output logic [11:0] data_10,
    output logic [11:0] data_11,
    output logic [11:0] data_12,
    output logic [11:0] data_20,
    output logic [11:0] data_21,
    output logic [11:0] data_22
);
    // median filter parameters
    reg [11:0] fmem0[639:0];
    reg [11:0] fmem1[639:0];
    reg [11:0] fmem2[639:0];
    reg [11:0] temp;
    always_ff @(posedge pclk) begin
        if (x_pixel < 640 && y_pixel < 480) begin
            temp <= fmem2[x_pixel];
            fmem2[x_pixel] <= fmem1[x_pixel];
            fmem1[x_pixel] <= fmem0[x_pixel];
            fmem0[x_pixel] <= data;
        end
    end

    always_ff @(posedge pclk) begin
        data_00 <= (y_pixel == 0 || x_pixel == 0) ? 0 : temp;
        data_01 <= (y_pixel == 0) ? 0 : fmem2[x_pixel];
        data_02 <= (y_pixel == 0 || x_pixel == 639) ? 0 : fmem2[x_pixel+1];
        data_10 <= (x_pixel == 0) ? 0 : fmem2[x_pixel-1];
        data_11 <= fmem1[x_pixel];
        data_12 <= (x_pixel == 639) ? 0 : fmem1[x_pixel+1];
        data_20 <= (x_pixel == 0 || y_pixel == 479) ? 0 : fmem1[x_pixel-1];
        data_21 <= (y_pixel == 479) ? 0 : fmem0[x_pixel];
        data_22 <= (x_pixel == 639 || y_pixel == 479) ? 0 : fmem0[x_pixel+1];
    end

endmodule
