`timescale 1ns / 1ps

module MedianFilter (
    input  logic [23:0] PixelData_00,
    input  logic [23:0] PixelData_01,
    input  logic [23:0] PixelData_02,
    input  logic [23:0] PixelData_10,
    input  logic [23:0] PixelData_11,
    input  logic [23:0] PixelData_12,
    input  logic [23:0] PixelData_20,
    input  logic [23:0] PixelData_21,
    input  logic [23:0] PixelData_22,
    output logic [23:0] Median_result
);


    logic [7:0] r_data[0:8];
    logic [7:0] g_data[0:8];
    logic [7:0] b_data[0:8];

    always_comb begin
        r_data[0] = PixelData_00[23:16];
        r_data[1] = PixelData_01[23:16];
        r_data[2] = PixelData_02[23:16];
        r_data[3] = PixelData_10[23:16];
        r_data[4] = PixelData_11[23:16];
        r_data[5] = PixelData_12[23:16];
        r_data[6] = PixelData_20[23:16];
        r_data[7] = PixelData_21[23:16];
        r_data[8] = PixelData_22[23:16];
        
        g_data[0] = PixelData_00[15:8];
        g_data[1] = PixelData_01[15:8];
        g_data[2] = PixelData_02[15:8];
        g_data[3] = PixelData_10[15:8];
        g_data[4] = PixelData_11[15:8];
        g_data[5] = PixelData_12[15:8];
        g_data[6] = PixelData_20[15:8];
        g_data[7] = PixelData_21[15:8];
        g_data[8] = PixelData_22[15:8];
    
        b_data[0] = PixelData_00[7:0];
        b_data[1] = PixelData_01[7:0];
        b_data[2] = PixelData_02[7:0];
        b_data[3] = PixelData_10[7:0];
        b_data[4] = PixelData_11[7:0];
        b_data[5] = PixelData_12[7:0];
        b_data[6] = PixelData_20[7:0];
        b_data[7] = PixelData_21[7:0];
        b_data[8] = PixelData_22[7:0];
    end

    logic [7:0] sort_r_data[0:8];
    logic [7:0] sort_g_data[0:8];
    logic [7:0] sort_b_data[0:8];

    Sort #(.WIDTH(8)) U_Sort_R (
        .din (r_data),  // 5비트
        .dout(sort_r_data)
    );
    Sort #(.WIDTH(8)) U_Sort_G (
        .din (g_data),  // 5비트
        .dout(sort_g_data)
    );
    Sort #(.WIDTH(8)) U_Sort_B (
        .din (b_data),  // 5비트
        .dout(sort_b_data)
    );

    assign Median_result = {sort_r_data[4], sort_g_data[4], sort_b_data[4]};

endmodule


module Sort #(
    parameter int WIDTH = 8
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
