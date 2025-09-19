`timescale 1ns / 1ps
 
module chromakey(
    input  logic [15:0] rgbData,  // RGB565: {R5,G6,B5}
    input  logic        DE,
    output logic        bg_pixel
);
    // 565 채널 분리
    logic [4:0] r5, b5;
    logic [5:0] g6;
    assign {r5, g6, b5} = DE ? {rgbData[15:11], rgbData[10:5], rgbData[4:0]} : 16'b0;

    // 5비트를 6비트로 확장해 공정하게 비교 (MSB replicate: 31→63)
    logic [5:0] r6 = {r5, r5[4]};
    logic [5:0] b6 = {b5, b5[4]};

    // 간단 HSV-ish: 채도 느낌(sat) = max-min (흰색/회색 억제용)
    logic [5:0] maxc = (r6 > g6 ? (r6 > b6 ? r6 : b6) : (g6 > b6 ? g6 : b6));
    logic [5:0] minc = (r6 < g6 ? (r6 < b6 ? r6 : b6) : (g6 < b6 ? g6 : b6));
    logic [5:0] sat  = maxc - minc;

    // ====== 튜닝 가능한 보편 파라미터(현장 기본값) ======
    localparam logic [5:0] G_MIN  = 6'd12; // 최소 녹색 밝기(너무 어두운 픽셀 배제)
    localparam logic [5:0] DR     = 6'd3;  // G - R 최소 차이
    localparam logic [5:0] DB     = 6'd2;  // G - B 최소 차이
    localparam logic [5:0] SATMIN = 6'd6;  // 채도 하한(흰/회색 배제)

    // 초록 배경(크로마키) 판정
    assign bg_pixel =
           (g6 >= r6 + DR)   // G가 R보다 충분히 큼
        && (g6 >= b6 + DB)   // G가 B보다 충분히 큼
        && (g6 >= G_MIN)     // 너무 어둡지 않음
        && (sat >= SATMIN);  // 채도 확보(흰색/회색/과노출면 배제)
endmodule