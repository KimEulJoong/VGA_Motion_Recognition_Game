`timescale 1ns / 1ps

module VGA_MemController (
    // VGA side
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel, 
    // frame buffer side
    output logic        den,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    // export side
    output logic [ 4:0] r_port,
    output logic [ 5:0] g_port,
    output logic [ 4:0] b_port
);

    assign den = DE && (x_pixel < 640) && (y_pixel < 480);  // QVGA Area
    assign rAddr = den ? (y_pixel[8:1] * 320 + x_pixel[9:1]) : 17'bz;
    assign {r_port, g_port, b_port} = den ? {rData[15: 11], rData[10:5], rData[4:0]} : 16'b0;
  
endmodule
