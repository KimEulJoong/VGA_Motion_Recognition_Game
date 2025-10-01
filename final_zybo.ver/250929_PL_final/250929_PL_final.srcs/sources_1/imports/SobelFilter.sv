`timescale 1ns / 1ps

module SobelFilter (
    // gray input
    input  logic [7:0] data00,
    input  logic [7:0] data01,
    input  logic [7:0] data02,
    input  logic [7:0] data10,
    input  logic [7:0] data11,
    input  logic [7:0] data12,
    input  logic [7:0] data20,
    input  logic [7:0] data21,
    input  logic [7:0] data22,
    output logic        sdata
);

    localparam threshold = 1500;
    logic signed [10:0] xdata, ydata;
    logic [10:0] absx, absy;
    //logic [16:0] abadd;

    assign xdata = data02 + (data12 << 1) + data22 - data00 - (data10 << 1) - data20;
    assign ydata = data00 + (data01 << 1) + data02 - data20 - (data21 << 1) - data22;

    assign absx = xdata[10] ? (~xdata + 1) : xdata;
    assign absy = ydata[10] ? (~ydata + 1) : ydata;
    //assign abadd = absx + absy;

    assign sdata = (absx + absy > threshold) ? 1 : 0;
    
endmodule