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

    logic [3:0] r_data[0:8];
    logic [3:0] g_data[0:8];
    logic [3:0] b_data[0:8];

    always_comb begin
        // Red
        r_data[0] = PixelData_00[11:8];   
        r_data[1] = PixelData_01[11:8];
        r_data[2] = PixelData_02[11:8];
        r_data[3] = PixelData_10[11:8];
        r_data[4] = PixelData_11[11:8];
        r_data[5] = PixelData_12[11:8];
        r_data[6] = PixelData_20[11:8];
        r_data[7] = PixelData_21[11:8];
        r_data[8] = PixelData_22[11:8];

        // Green
        g_data[0] = PixelData_00[7:4];
        g_data[1] = PixelData_01[7:4];
        g_data[2] = PixelData_02[7:4];
        g_data[3] = PixelData_10[7:4];
        g_data[4] = PixelData_11[7:4];
        g_data[5] = PixelData_12[7:4];
        g_data[6] = PixelData_20[7:4];
        g_data[7] = PixelData_21[7:4];
        g_data[8] = PixelData_22[7:4];

        // Blue
        b_data[0] = PixelData_00[3:0];
        b_data[1] = PixelData_01[3:0];
        b_data[2] = PixelData_02[3:0];
        b_data[3] = PixelData_10[3:0];
        b_data[4] = PixelData_11[3:0];  
        b_data[5] = PixelData_12[3:0];
        b_data[6] = PixelData_20[3:0];
        b_data[7] = PixelData_21[3:0];
        b_data[8] = PixelData_22[3:0];
    end

    logic [3:0] red;
    logic [3:0] green;
    logic [3:0] blue;

    // 0, 2, 6, 8 => 4 shift
    // 1, 3, 5, 7 => 3 shift
    // 4 => 1 shift
    assign red = (r_data[0] >> 4) + (r_data[1] >> 3) + (r_data[2] >> 4) + 
                 (r_data[3] >> 3) + (r_data[4] >> 1) + (r_data[5] >> 3) + 
                 (r_data[6] >> 4) + (r_data[7] >> 3) + (r_data[8] >> 4);

    assign green = (g_data[0] >> 4) + (g_data[1] >> 3) + (g_data[2] >> 4) + 
                 (g_data[3] >> 3) + (g_data[4] >> 1) + (g_data[5] >> 3) + 
                 (g_data[6] >> 4) + (g_data[7] >> 3) + (g_data[8] >> 4);

    assign blue = (b_data[0] >> 4) + (b_data[1] >> 3) + (b_data[2] >> 4) + 
                 (b_data[3] >> 3) + (b_data[4] >> 1) + (b_data[5] >> 3) + 
                 (b_data[6] >> 4) + (b_data[7] >> 3) + (b_data[8] >> 4);

    assign Gaussian_Result = {red, green, blue};
    
endmodule
