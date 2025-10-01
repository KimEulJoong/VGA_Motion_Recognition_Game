`timescale 1ns / 1ps

module GrayScale_Filter (
    // gray input
    input  logic [23:0] data00_gi,
    input  logic [23:0] data01_gi,
    input  logic [23:0] data02_gi,
    input  logic [23:0] data10_gi,
    input  logic [23:0] data11_gi,
    input  logic [23:0] data12_gi,
    input  logic [23:0] data20_gi,
    input  logic [23:0] data21_gi,
    input  logic [23:0] data22_gi,
    // gray output
    output logic [7:0] data00_go,
    output logic [7:0] data01_go,
    output logic [7:0] data02_go,
    output logic [7:0] data10_go,
    output logic [7:0] data11_go,
    output logic [7:0] data12_go,
    output logic [7:0] data20_go,
    output logic [7:0] data21_go,
    output logic [7:0] data22_go
);

    logic [15:0] gray[0:8];  

    assign gray[0] = 77 * data00_gi[23:16] + 150 * data00_gi[15:8] + 29 * data00_gi[7:0];
    assign gray[1] = 77 * data01_gi[23:16] + 150 * data01_gi[15:8] + 29 * data01_gi[7:0];
    assign gray[2] = 77 * data02_gi[23:16] + 150 * data02_gi[15:8] + 29 * data02_gi[7:0];
    assign gray[3] = 77 * data10_gi[23:16] + 150 * data10_gi[15:8] + 29 * data10_gi[7:0];
    assign gray[4] = 77 * data11_gi[23:16] + 150 * data11_gi[15:8] + 29 * data11_gi[7:0];
    assign gray[5] = 77 * data12_gi[23:16] + 150 * data12_gi[15:8] + 29 * data12_gi[7:0];
    assign gray[6] = 77 * data20_gi[23:16] + 150 * data20_gi[15:8] + 29 * data20_gi[7:0];
    assign gray[7] = 77 * data21_gi[23:16] + 150 * data21_gi[15:8] + 29 * data21_gi[7:0];
    assign gray[8] = 77 * data22_gi[23:16] + 150 * data22_gi[15:8] + 29 * data22_gi[7:0];

    assign data00_go = gray[0][15:8];  
    assign data01_go = gray[1][15:8];
    assign data02_go = gray[2][15:8];
    assign data10_go = gray[3][15:8];
    assign data11_go = gray[4][15:8];
    assign data12_go = gray[5][15:8];
    assign data20_go = gray[6][15:8];
    assign data21_go = gray[7][15:8];
    assign data22_go = gray[8][15:8];

endmodule