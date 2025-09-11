`timescale 1ns / 1ps

module Gaussian_Filter (
    input  logic [11:0] PixelData_00,
    input  logic [11:0] PixelData_01,
    input  logic [11:0] PixelData_02,
    input  logic [11:0] PixelData_10,
    input  logic [11:0] PixelData_11,
    input  logic [11:0] PixelData_12,
    input  logic [11:0] PixelData_20,
    input  logic [11:0] PixelData_21,
    input  logic [11:0] PixelData_22,
    output logic [11:0] Gaussian_Result
);

    logic [11:0] PixelData[0:8];

    assign PixelData[0] = {4'b0, PixelData_00[11:4]};
    assign PixelData[1] = {3'b0, PixelData_01[11:3]};
    assign PixelData[2] = {4'b0, PixelData_02[11:4]};
    assign PixelData[3] = {3'b0, PixelData_10[11:3]};
    assign PixelData[4] = {2'b0, PixelData_11[11:2]};
    assign PixelData[5] = {3'b0, PixelData_12[11:3]};
    assign PixelData[6] = {4'b0, PixelData_20[11:4]};
    assign PixelData[7] = {3'b0, PixelData_21[11:3]};
    assign PixelData[8] = {4'b0, PixelData_22[11:4]};

    assign Gaussian_Result = PixelData[0] + PixelData[1] + PixelData[2] + 
                                PixelData[3] + PixelData[4] + PixelData[5] + 
                                    PixelData[6] + PixelData[7] + PixelData[8] ;

endmodule
