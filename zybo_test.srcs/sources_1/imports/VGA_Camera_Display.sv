`timescale 1ns / 1ps

module VGA_Camera_Display (
    input  logic       clk,
    input  logic       reset,
    // ov7670 side
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_vsync,
    input  logic [7:0] ov7670_data,
    // external port
    // input              sw_gray,
    output logic       hdmi_clk_p,
    output logic       hdmi_clk_n,
    output logic       r_port_p,
    output logic       r_port_n,
    output logic       g_port_p,
    output logic       g_port_n,
    output logic       b_port_p,
    output logic       b_port_n
);
    logic        ov7670_we;
    logic [16:0] ov7670_wAddr;
    logic [15:0] ov7670_wData;

    logic        vga_pclk;
    logic [ 9:0] vga_x_pixel;
    logic [ 9:0] vga_y_pixel;
    logic        vga_DE;

    logic        vga_den;
    logic [16:0] vga_rAddr;
    logic [15:0] vga_rData;

    logic        h_sync;
    logic        v_sync;
    logic [4:0] vga_r, gray_r, r5;
    logic [5:0] vga_g, gray_g, g6;
    logic [4:0] vga_b, gray_b, b5;
    logic [7:0] r8;
    logic [7:0] g8;
    logic [7:0] b8;
    logic       clk_250Mhz;

    assign ov7670_xclk = vga_pclk;


    OV7670_MemController U_OV7670_MemController (
        .clk        (ov7670_pclk),
        .reset      (reset),
        .href       (ov7670_href),
        .vsync      (ov7670_vsync),
        .ov7670_data(ov7670_data),
        .we         (ov7670_we),
        .wAddr      (ov7670_wAddr),
        .wData      (ov7670_wData)
    );

    frame_buffer U_FrameBuffer (
        .wclk (ov7670_pclk),
        .we   (ov7670_we),
        .wAddr(ov7670_wAddr),
        .wData(ov7670_wData),
        .rclk (vga_pclk),
        .oe   (vga_den),
        .rAddr(vga_rAddr),
        .rData(vga_rData)
    );

    VGA_MemController U_VGAMemController (
        .DE     (vga_DE),
        .x_pixel(vga_x_pixel),
        .y_pixel(vga_y_pixel),
        .den    (vga_den),
        .rAddr  (vga_rAddr),
        .rData  (vga_rData),
        .r5     (r5),
        .g6     (g6),
        .b5     (b5)
    );

    rgb565_to_rgb888 U_rgb565_to_rgb888 (.*);

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk),
        .reset  (reset),
        .pclk   (vga_pclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(vga_x_pixel),
        .y_pixel(vga_y_pixel),
        .DE     (vga_DE)
    );

    clk_wiz_0 U_clk_250Mhz (
        .clk_in1 (vga_pclk),
        .reset   (reset),
        .clk_out1(clk_250Mhz)
    );

    vga2hdmi U_vga2hdmi (
        .*,
        .pclk      (vga_pclk),
        .clk_250Mhz(clk_250Mhz),
        .reset     (reset),
        .de        (vga_DE)
    );

endmodule
