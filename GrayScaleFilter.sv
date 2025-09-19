`timescale 1ns / 1ps

module GrayScaleFilter (
    // gray input
    input  logic [15:0] data00_gi,
    // gray output
    output logic [15:0] data00_go
);
    logic [4:0] r5, b5;
    logic [5:0] g5;

    assign r5 = data00_gi[15:11];
    assign g6 = data00_gi[10:5];
    assign b5 = data00_gi[4:0];

    logic [12:0] gray16; // 최대값 4068 : 여유있게 13bit
    assign gray16 = (39*r5) + (38*g6) + (15*b5); // 정수 계수 적용 (x16 스케일)

    logic [7:0] gray8;
    assign gray8 = gray16[12:5]; // ÷16 보정 → 8비트 그레이

    assign data00_go = {gray8[7:3], gray8[7:2], gray8[7:3]};   // Gray → RGB565 복제

    // code 설명
    //RGB -> GRAY 변환식 : GRAY = 0.299*R + 0.587*G + 0.114*B (RGB 각각 0~255 범위일 때 사용)
    //RGB 5(31) 6(63) 5(31)에 단순히 가중치 곱하면 X. 0~255 스케일로 보정
    
    //R5 -> 8비트 : scale_R = 255 / 31  = 8.2258
    //G6 -> 8비트 : scale_G = 255 / 63 = 4.0476
    //B5 -> 8비트 : scale_B = 255 / 31  = 8.2258

    // Gray 계수유도 : Gray = 0.299·(R5×8.2258) + 0.587·(G6×4.0476) + 0.114·(B5×8.2258) ≈ 2.46·R5 + 2.38·G6 + 0.94·B5
    // 소수 계산 어려워서 *16해서 정수화 : R: 2.46 × 16 ≈ 39 / G: 2.38 × 16 ≈ 38 / B: 0.94 × 16 ≈ 15
    // Gray8 = Gray16 >> 4; : 다시 원래 크기로 보정
endmodule