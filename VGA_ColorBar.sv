`timescale 1ns / 1ps

module VGA_ColorBar (
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port
);

    localparam WHITE = 12'b1111_1111_1111;
    localparam BLACK = 12'b0000_0000_0000;
    localparam RED = 12'b1111_0000_0000;
    localparam GREEN = 12'b0000_1111_0000;
    localparam BLUE = 12'b0000_0000_1111;
    localparam YELLOW = 12'b1111_1111_0000;
    localparam MAGENTA = 12'b1111_0000_1111;
    localparam CYAN = 12'b0000_1111_1111;

    logic [11:0] rgb;
    assign r_port = DE ? rgb[11:8] : 4'b0;
    assign g_port = DE ? rgb[7:4] : 4'b0;
    assign b_port = DE ? rgb[3:0] : 4'b0;

    always_comb begin
        if (y_pixel < 300) begin
            if (x_pixel < 90) begin
                rgb = WHITE;
            end else if (x_pixel < 180) begin
                rgb = YELLOW;
            end else if (x_pixel < 270) begin
                rgb = CYAN;
            end else if (x_pixel < 360) begin
                rgb = GREEN;
            end else if (x_pixel < 450) begin
                rgb = MAGENTA;
            end else if (x_pixel < 540) begin
                rgb = RED;
            end else begin
                rgb = BLUE;
            end
        end else if ((y_pixel >= 300) && (y_pixel < 350)) begin
            if (x_pixel < 90) begin
                rgb = BLUE;
            end else if (x_pixel < 180) begin
                rgb = BLACK;
            end else if (x_pixel < 270) begin
                rgb = MAGENTA;
            end else if (x_pixel < 360) begin
                rgb = BLACK;
            end else if (x_pixel < 450) begin
                rgb = CYAN;
            end else if (x_pixel < 540) begin
                rgb = BLACK;
            end else begin
                rgb = WHITE;
            end
        end else begin
            if (x_pixel < 105) begin
                rgb = 12'b0000_0000_0011;
            end else if (x_pixel < 210) begin
                rgb = WHITE;
            end else if (x_pixel < 315) begin
                rgb = 12'b0011_0000_0011;
            end else if (x_pixel < 420) begin
                rgb = 12'b0001_0001_0001;
            end else if (x_pixel < 437) begin
                rgb = 12'b0010_0010_0010;
            end else if (x_pixel < 454) begin
                rgb = 12'b0011_0011_0011;
            end else if (x_pixel < 471) begin
                rgb = 12'b0100_0100_0100;
            end else if (x_pixel < 488) begin
                rgb = 12'b0101_0101_0101;
            end else if (x_pixel < 505) begin
                rgb = 12'b0110_0110_0110;
            end else if (x_pixel < 525) begin
                rgb = 12'b0111_0111_0111;
            end else begin
                rgb = BLACK;
            end
        end
    end

endmodule
