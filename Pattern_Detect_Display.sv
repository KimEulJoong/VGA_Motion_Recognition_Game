`timescale 1ns / 1ps

module Pattern_Detect_Display (
    input  logic       game_in,
    input  logic       in_polygon,
    input  logic       chroma,      // bg_pixel from chromakey module
    input  logic       sobel,
    input  logic [4:0] in_r,
    input  logic [5:0] in_g,
    input  logic [4:0] in_b,
    output logic [7:0] red,
    output logic [7:0] grn,
    output logic [7:0] blu,
    output logic       perfect,    // 추가
    output logic       good,       // 추가
    output logic       bad         // 추가
);
 
    logic [$clog2(640*480)-1:0] grn_cnt;                                  
    logic [$clog2(640*480)-1:0] red_cnt;  

    logic [6:0] score;

    always_comb begin
        if (game_in) begin
            if (in_polygon) begin  // 패턴 안에서
                if (!chroma) begin
                    {red, grn, blu} = {
                        in_r[4:0],
                        in_r[4:2],
                        in_g[5:0],
                        in_g[5:4],
                        in_b[4:0],
                        in_b[4:2]
                    };
                end else begin
                    {red, grn, blu} = 24'h00FF00;  // 사람이 없는 공간은 초록색
                end
            end else begin  // 패턴 밖에서
                if (!chroma) begin  // 사람이 있으면 (삐져나오면)
                    if (sobel) begin
                        {red, grn, blu} = 24'hFF0000;  // 엣지는 진한 빨강
                    end else begin
                        {red, grn, blu} = 24'hFF8888;  // 엣지가 아닌 나머지 면은 연한 빨강
                    end
                end else begin
                    {red, grn, blu} = 24'h87CEFA;  // 크로마키 천에 해당하는 영역은 하늘색
                end
            end
        end else begin
            grn_cnt = 0;
            red_cnt = 0;
            if (in_polygon) begin
                if (!chroma) begin
                    grn_cnt = grn_cnt + 1;
                    if (sobel) begin
                        {red, grn, blu} = 24'h00FF00;  // 진한 초록
                    end else begin
                        {red, grn, blu} = 24'h88FF88;  // 연한 초록
                    end
                end else begin
                    {red, grn, blu} = 24'hFFFFFF;  // 흰색
                end
            end else begin
                if (!chroma) begin
                    red_cnt = red_cnt + 1;
                    if (sobel) begin
                        {red, grn, blu} = 24'hFF0000;  // 진한 빨강
                    end else begin
                        {red, grn, blu} = 24'hFF8888;  // 파랑 -> 연한 빨강으로 교체
                    end
                end else begin
                    {red, grn, blu} = 24'hFFFF00;  // 노랑색
                end
                //{red, grn, blu} = {in_r[4:0], in_r[4:2], in_g[5:0], in_g[5:4], in_b[4:0], in_b[4:2]};
            end
        end
    end

    assign score = ((grn_cnt - red_cnt) / (grn_cnt + red_cnt)) * 100; 

    assign perfect = (score >= 80) ? 1'b1 : 1'b0;                         
    assign good    = ((score >= 50) && (score < 80)) ? 1'b1 : 1'b0;          
    assign bad     = (score <  50) ? 1'b1 : 1'b0;  
endmodule
