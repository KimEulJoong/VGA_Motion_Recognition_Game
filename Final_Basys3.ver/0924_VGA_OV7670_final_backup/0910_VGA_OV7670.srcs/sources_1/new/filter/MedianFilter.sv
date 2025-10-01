`timescale 1ns / 1ps

module MedianFilter (
    input  logic [15:0] PixelData_00,
    input  logic [15:0] PixelData_01,
    input  logic [15:0] PixelData_02,
    input  logic [15:0] PixelData_10,
    input  logic [15:0] PixelData_11,
    input  logic [15:0] PixelData_12,
    input  logic [15:0] PixelData_20,
    input  logic [15:0] PixelData_21,
    input  logic [15:0] PixelData_22,
    output logic [15:0] Median_result
);


    logic [4:0] r_data[0:8];
    logic [5:0] g_data[0:8];
    logic [4:0] b_data[0:8];

    always_comb begin
        // Red
        r_data[0] = PixelData_00[15:11];
        r_data[1] = PixelData_01[15:11];
        r_data[2] = PixelData_02[15:11];
        r_data[3] = PixelData_10[15:11];
        r_data[4] = PixelData_11[15:11];
        r_data[5] = PixelData_12[15:11];
        r_data[6] = PixelData_20[15:11];
        r_data[7] = PixelData_21[15:11];
        r_data[8] = PixelData_22[15:11];

        // Green
        g_data[0] = PixelData_00[10:5];
        g_data[1] = PixelData_01[10:5];
        g_data[2] = PixelData_02[10:5];
        g_data[3] = PixelData_10[10:5];
        g_data[4] = PixelData_11[10:5];
        g_data[5] = PixelData_12[10:5];
        g_data[6] = PixelData_20[10:5];
        g_data[7] = PixelData_21[10:5];
        g_data[8] = PixelData_22[10:5];

        // Blue
        b_data[0] = PixelData_00[4:0];
        b_data[1] = PixelData_01[4:0];
        b_data[2] = PixelData_02[4:0];
        b_data[3] = PixelData_10[4:0];
        b_data[4] = PixelData_11[4:0];
        b_data[5] = PixelData_12[4:0];
        b_data[6] = PixelData_20[4:0];
        b_data[7] = PixelData_21[4:0];
        b_data[8] = PixelData_22[4:0];
    end

    logic [4:0] sort_r_data[0:8];
    logic [5:0] sort_g_data[0:8];
    logic [4:0] sort_b_data[0:8];

    Sort #(.WIDTH(5)) U_Sort_R (  // Red
        .din (r_data),  // 5비트
        .dout(sort_r_data)
    );

    Sort #(.WIDTH(6)) U_Sort_G (  // Green
        .din (g_data),  // 6비트
        .dout(sort_g_data)
    );

    Sort #(.WIDTH(5)) U_Sort_B (  // Blue
        .din (b_data),  // 5비트
        .dout(sort_b_data)
    );

    assign Median_result = {sort_r_data[4], sort_g_data[4], sort_b_data[4]};

endmodule


module Sort #(
    parameter int WIDTH = 6
)(
    input  logic [WIDTH-1:0] din [0:8],
    output logic [WIDTH-1:0] dout[0:8]
);

    integer i, j;
    logic [WIDTH-1:0] tmp;
    logic [WIDTH-1:0] arr [0:8];

    always_comb begin
        for (i = 0; i < 9; i++) begin
            arr[i] = din[i];
        end

        for (i = 0; i < 9; i++) begin
            for (j = 0; j < 8 - i; j++) begin
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
