`timescale 1ns / 1ps

module chromakey(
    // Line_buffer signals
    input logic [15:0] rgbData,
    input logic DE,
    // export signals
    output logic bg_pixel
    );
    // RGB 추출 
    logic [3:0] r, b,g;

    assign {r, g, b} = DE ? {rgbData[15:12], rgbData[10:7], rgbData[4:1]} : 12'b0;
    
    // 배경 조건 (크로마키용 초록 배경 인식) 초록색이면 1 아니면 0
    // assign bg_pixel =  (g > b) && (b > r) && (g >= 8) ? 0 : 1;
    // 조건이 완화된 버전
    assign bg_pixel = (g > r+1) && (g >= b+1) && (g >= 3);


endmodule

