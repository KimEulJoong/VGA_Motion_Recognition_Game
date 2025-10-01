`timescale 1ns / 1ps

module GrayScale_Filter_9 (
    // gray input
    input  logic [15:0] data00_gi,
    input  logic [15:0] data01_gi,
    input  logic [15:0] data02_gi,
    input  logic [15:0] data10_gi,
    input  logic [15:0] data11_gi,
    input  logic [15:0] data12_gi,
    input  logic [15:0] data20_gi,
    input  logic [15:0] data21_gi,
    input  logic [15:0] data22_gi,
    // gray output
    output logic [5:0] data00_go,
    output logic [5:0] data01_go,
    output logic [5:0] data02_go,
    output logic [5:0] data10_go,
    output logic [5:0] data11_go,
    output logic [5:0] data12_go,
    output logic [5:0] data20_go,
    output logic [5:0] data21_go,
    output logic [5:0] data22_go
);

    logic [13:0] gray[0:8];  // 최대 값 14비트면 충분, 더 크게 설정하면 아래서 상위비트를 잘라올때 없는 값을 잘라옴

    assign gray[0] = 77 * data00_gi[15:11] + 154 * data00_gi[10:5] + 25 * data00_gi[4:0];
    assign gray[1] = 77 * data01_gi[15:11] + 154 * data01_gi[10:5] + 25 * data01_gi[4:0];
    assign gray[2] = 77 * data02_gi[15:11] + 154 * data02_gi[10:5] + 25 * data02_gi[4:0];
    assign gray[3] = 77 * data10_gi[15:11] + 154 * data10_gi[10:5] + 25 * data10_gi[4:0];
    assign gray[4] = 77 * data11_gi[15:11] + 154 * data11_gi[10:5] + 25 * data11_gi[4:0];
    assign gray[5] = 77 * data12_gi[15:11] + 154 * data12_gi[10:5] + 25 * data12_gi[4:0];
    assign gray[6] = 77 * data20_gi[15:11] + 154 * data20_gi[10:5] + 25 * data20_gi[4:0];
    assign gray[7] = 77 * data21_gi[15:11] + 154 * data21_gi[10:5] + 25 * data21_gi[4:0];
    assign gray[8] = 77 * data22_gi[15:11] + 154 * data22_gi[10:5] + 25 * data22_gi[4:0];

    assign data00_go = gray[0][13:8];  // 565포맷
    assign data01_go = gray[1][13:8];
    assign data02_go = gray[2][13:8];
    assign data10_go = gray[3][13:8];
    assign data11_go = gray[4][13:8];
    assign data12_go = gray[5][13:8];
    assign data20_go = gray[6][13:8];
    assign data21_go = gray[7][13:8];
    assign data22_go = gray[8][13:8];

endmodule