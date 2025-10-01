`timescale 1ns / 1ps

module delay_1pclk (
    input  logic        clk,
    input  logic        reset,
    input  logic        DE,
    input  logic        vga_h_sync,
    input  logic        vga_v_sync,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [15:0] rgbData,
    output logic [ 9:0] x_pixel_d,
    output logic [ 9:0] y_pixel_d,
    output logic        DE_d,
    output logic        vga_h_sync_d,
    output logic        vga_v_sync_d,
    output logic [15:0] rgbData_d
);

    always_ff @(posedge clk) begin
        if (reset) begin
            rgbData_d    <= 0;
            DE_d         <= 0;
            vga_h_sync_d <= 0;
            vga_v_sync_d <= 0;
            x_pixel_d    <= 0;
            y_pixel_d    <= 0;
        end else begin
            rgbData_d    <= rgbData;
            DE_d         <= DE;
            vga_h_sync_d <= vga_h_sync;
            vga_v_sync_d <= vga_v_sync;
            x_pixel_d    <= x_pixel;
            y_pixel_d    <= y_pixel;
        end
    end

endmodule
