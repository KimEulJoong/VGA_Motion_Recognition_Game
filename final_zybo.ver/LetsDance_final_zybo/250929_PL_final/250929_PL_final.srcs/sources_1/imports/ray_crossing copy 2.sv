`timescale 1ns / 1ps
module ray_cross_unit_mul (
    input  logic        clk,
    input  logic [43:0] line,
    input  logic [10:0] x_pixel,
    input  logic [10:0] y_pixel,
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
    logic slope        = (x1 < x2) ? (y1 < y2) : (y1 > y2);
    logic [10:0] dx    = x_max - x_min;
    logic [10:0] dy    = y_max - y_min;

    // Reciprocal ROM (예시: 11비트 입력 → 16비트 출력)
    logic [15:0] recip_dy;
    recip_rom u_recip_rom (
        .clk (clk),
        .addr(dy),
        .dout(recip_dy)
    );

    // Stage0
    logic in_rng_s0;
    logic [22:0] prod_s0;
    logic [10:0] x_s0;
    logic slope_s0;
    logic [10:0] x_min_s0, x_max_s0;

    always_ff @(posedge clk) begin
        in_rng_s0 <= (dy != 0) && (y_pixel > y_min) && (y_pixel <= y_max);
        prod_s0   <= dx * (y_pixel - y_min);
        x_s0      <= x_pixel;
        slope_s0  <= slope;
        x_min_s0  <= x_min;
        x_max_s0  <= x_max;
    end

    // Stage1 : q ≈ prod * (1/dy)
    logic [31:0] q_mul;
    always_ff @(posedge clk) begin
        q_mul <= prod_s0 * recip_dy;  // DSP 사용
    end

    // Stage2 : 정규화 및 hit 판정
    logic [10:0] q_s1, xexp_s1;
    logic [12:0] xexp_tmp_s1;
    logic in_rng_s1;
    logic slope_s1;
    logic [10:0] x_s1, x_min_s1, x_max_s1;

    always_ff @(posedge clk) begin
        in_rng_s1 <= in_rng_s0;
        slope_s1  <= slope_s0;
        x_s1      <= x_s0;
        x_min_s1  <= x_min_s0;
        x_max_s1  <= x_max_s0;

        q_s1 <= q_mul[21:11]; // 스케일링 후 적절히 잘라서 사용

        if (slope_s1) xexp_tmp_s1 <= {1'b0, x_min_s1} + q_s1;
        else          xexp_tmp_s1 <= {1'b0, x_max_s1} - q_s1;

        xexp_s1 <= xexp_tmp_s1[10:0];
    end

    always_ff @(posedge clk) begin
        hit <= in_rng_s1 && (xexp_s1 < x_s1);
    end
endmodule
