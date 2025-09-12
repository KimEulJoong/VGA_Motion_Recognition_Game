`timescale 1ns / 1ps

module top_sobel_Filter (
    // gray input
    input  logic [11:0] data00,
    input  logic [11:0] data01,
    input  logic [11:0] data02,
    input  logic [11:0] data10,
    input  logic [11:0] data11,
    input  logic [11:0] data12,
    input  logic [11:0] data20,
    input  logic [11:0] data21,
    input  logic [11:0] data22,
    output logic  result
);

    // gray output
    logic [11:0] data00_go;
    logic [11:0] data01_go;
    logic [11:0] data02_go;
    logic [11:0] data10_go;
    logic [11:0] data11_go;
    logic [11:0] data12_go;
    logic [11:0] data20_go;
    logic [11:0] data21_go;
    logic [11:0] data22_go;


    GrayScaleFilter U_GRAY (
        .data00_gi(data00),
        .data01_gi(data01),
        .data02_gi(data02),
        .data10_gi(data10),
        .data11_gi(data11),
        .data12_gi(data12),
        .data20_gi(data20),
        .data21_gi(data21),
        .data22_gi(data22),
        // gray output
        .data00_go(data00_go),
        .data01_go(data01_go),
        .data02_go(data02_go),
        .data10_go(data10_go),
        .data11_go(data11_go),
        .data12_go(data12_go),
        .data20_go(data20_go),
        .data21_go(data21_go),
        .data22_go(data22_go)
    );

    Sobel U_Sobel (
        // gray input
        .data00(data00_go),
        .data01(data01_go),
        .data02(data02_go),
        .data10(data10_go),
        .data11(data11_go),
        .data12(data12_go),
        .data20(data20_go),
        .data21(data21_go),
        .data22(data22_go),
        .sdata (result)
    );

endmodule

module Sobel (
    // gray input
    input  logic [11:0] data00,
    input  logic [11:0] data01,
    input  logic [11:0] data02,
    input  logic [11:0] data10,
    input  logic [11:0] data11,
    input  logic [11:0] data12,
    input  logic [11:0] data20,
    input  logic [11:0] data21,
    input  logic [11:0] data22,
    output logic        sdata
);


    localparam threshold = 6000;

    wire signed [15:0] xdata, ydata;
    logic [15:0] absx, absy;
    //logic [16:0] abadd;

    assign xdata = data02 + (data12 << 1) + data22 - data00 - (data10 << 1) - data20;
    assign ydata = data00 + (data01 << 1) + data02 - data20 - (data21 << 1) - data22;

    assign absx = xdata[15] ? (~xdata + 1) : xdata;
    assign absy = ydata[15] ? (~ydata + 1) : ydata;
    //assign abadd = absx + absy;

    assign sdata = (absx + absy > threshold) ? 1 : 0;
endmodule