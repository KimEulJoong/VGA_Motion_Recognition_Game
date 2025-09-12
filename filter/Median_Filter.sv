`timescale 1ns / 1ps

module Median_Filter (
    input  logic [11:0] PixelData_00,
    input  logic [11:0] PixelData_01,
    input  logic [11:0] PixelData_02,
    input  logic [11:0] PixelData_10,
    input  logic [11:0] PixelData_11,
    input  logic [11:0] PixelData_12,
    input  logic [11:0] PixelData_20,
    input  logic [11:0] PixelData_21,
    input  logic [11:0] PixelData_22,
    output logic [11:0] Median_result
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

    logic [3:0] sort_r_data[0:8];
    logic [3:0] sort_g_data[0:8];
    logic [3:0] sort_b_data[0:8];

    Sort U_Sort_R (  // Red
        .din (r_data),
        .dout(sort_r_data)
    );

    Sort U_Sort_G (  // Green
        .din (g_data),
        .dout(sort_g_data)
    );

    Sort U_Sort_B (  // Blue
        .din (b_data),
        .dout(sort_b_data)
    );

    assign Median_result = {sort_r_data[4], sort_g_data[4], sort_b_data[4]};

endmodule


module Sort (
    input  logic [3:0] din [0:8],
    output logic [3:0] dout[0:8]
);

    integer i, j;
    logic [3:0] tmp;
    logic [3:0] arr [0:8];

    always_comb begin
        for (i = 0; i < 9; i++) begin
            arr[i] = din[i];
        end

        for (i = 0; i < 9; i++) begin
            for (j = 0; j < 9 - i; j++) begin
                if (arr[j] > arr[j+1]) begin
                    tmp = arr[j];
                    arr[j] = arr[j+1];
                    arr[j+1] = tmp;
                end
            end
        end

        for (i = 0; i < 9; i++) begin
            dout[i] = arr[i];
        end
    end

endmodule
