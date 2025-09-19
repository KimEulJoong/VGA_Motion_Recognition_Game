`timescale 1ns / 1ps

module ImgReader (
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input  logic [15:0] data,
    output logic [ 7:0] r_internal,
    output logic [ 7:0] g_internal,
    output logic [ 7:0] b_internal
);

    logic img_show;
    assign img_show   = (DE && (x_pixel < 320) && (y_pixel < 240));

    assign addr       = img_show ? (320 * y_pixel + x_pixel) : 17'bz;
    assign r_internal = img_show ? {data[15:11], data[15:13]} : 8'b0;
    assign g_internal = img_show ? {data[10:5], data[10:9]} : 8'b0;
    assign b_internal = img_show ? {data[4:0], data[4:2]} : 8'b0;

endmodule
