`timescale 1ns / 1ps

module ray_cross_unit (
    input  logic        clk,
    input  logic [43:0] line,
    input  logic [10:0]  x_pixel,
    input  logic [10:0]  y_pixel,
    output logic        hit
);
    // unpack
    logic [10:0] x1 = line[43:33], y1 = line[32:22];
    logic [10:0] x2 = line[21:11], y2 = line[10:0];

    // pre-calc (comb)
    logic [10:0] x_min = (x1 < x2) ? x1 : x2;
    logic [10:0] x_max = (x1 < x2) ? x2 : x1;
    logic [10:0] y_min = (y1 < y2) ? y1 : y2;
    logic [10:0] y_max = (y1 < y2) ? y2 : y1;
    logic        slope = (x1 < x2) ? (y1 < y2) : (y1 > y2);
    logic [10:0] dx    = x_max - x_min;
    logic [10:0] dy    = y_max - y_min;

    // Stage0 : in-range & product (register)
    logic        in_rng_s0;
    logic [22:0] prod_s0;       // (dx up to 2047) * (y - y_min up to 2047) ≈ 22bit, 여유로 23bit
    logic [10:0] x_s0;
    logic [10:0] dx_s0, dy_s0;
    logic        slope_s0;

    always_ff @(posedge clk) begin
        in_rng_s0 <= (dy != 0) && (y_pixel > y_min) && (y_pixel <= y_max);
        prod_s0   <= dx * (y_pixel - y_min);
        x_s0      <= x_pixel;
        dx_s0     <= dx;
        dy_s0     <= dy;
        slope_s0  <= slope;
    end

    // Stage1 : divide & x_exp (register)
    logic        in_rng_s1;
    logic [10:0] x_s1;
    logic [10:0] q_s1;          // quotient ≤ dx (11비트)
    logic [12:0] xexp_tmp_s1;   // 덧셈/뺄셈 결과 임시 (11+11 → 캐리 포함 12~13비트 필요)
    logic [10:0] xexp_s1;

    always_ff @(posedge clk) begin
        in_rng_s1 <= in_rng_s0;
        x_s1      <= x_s0;   

        // 나눗셈
        q_s1 <= (dy_s0 != 0) ? (prod_s0 / dy_s0) : 11'd0;

        // x_min/x_max 1비트 확장 후 덧셈/뺄셈
        if (slope_s0)
            xexp_tmp_s1 <= {1'b0, x_min} + q_s1;
        else
            xexp_tmp_s1 <= {1'b0, x_max} - q_s1;

        xexp_s1 <= xexp_tmp_s1[10:0];
    end

    // 최종 비교 (register)
    always_ff @(posedge clk) begin
        hit <= in_rng_s1 && (xexp_s1 < x_s1);
    end
endmodule
