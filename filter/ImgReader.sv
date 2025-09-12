`timescale 1ns / 1ps

module ImgReader (
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input  logic [15:0] data,
    output logic [ 3:0] r_port,
    output logic [ 3:0] g_port,
    output logic [ 3:0] b_port
);

    //assign addr   = DE ? (320 * y_pixel + x_pixel) : 17'bz;

    logic img_QVGA;

    assign img_QVGA = (DE && ((x_pixel <640) && (y_pixel <480)));
    assign addr   = img_QVGA ? (320 * y_pixel[9:1] + x_pixel[9:1]) : 17'bz;

    assign r_port = img_QVGA ? data[15:12] : 4'b0;
    assign g_port = img_QVGA ? data[10:7] : 4'b0;
    assign b_port = img_QVGA ? data[4:1] : 4'b0;

endmodule
