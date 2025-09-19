`timescale 1ns / 1ps

module VGA_Display_ImgROM (
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic       capture,
    input  logic       sw,
    // OV7670
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_vsync,
    input  logic [7:0] ov7670_data,
    inout  logic       sda,
    output logic       scl,

    //input logic [3:0] sw,  // 0918 추가

    output logic       hdmi_out_clk_n,
    output logic       hdmi_out_clk_p,
    output logic [2:0] hdmi_out_data_n,
    output logic [2:0] hdmi_out_data_p
);
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;

    logic [ 9:0] x_pixel_d1;
    logic [ 9:0] y_pixel_d1;

    logic [16:0] addr;
    logic [15:0] data;

    logic        vga_pclk;
    logic        vga_DE;
    logic        vga_den;
    logic [16:0] vga_rAddr;
    logic [15:0] vga_rData;

    logic [ 4:0] vga_r;
    logic [ 5:0] vga_g;
    logic [ 4:0] vga_b;

    logic [15:0] origin_vga;
    assign origin_vga = {vga_r, vga_g, vga_b};

    logic        vga_h_sync;
    logic        vga_v_sync;

    logic [15:0] PixelData_00;
    logic [15:0] PixelData_01;
    logic [15:0] PixelData_02;
    logic [15:0] PixelData_10;
    logic [15:0] PixelData_11;
    logic [15:0] PixelData_12;
    logic [15:0] PixelData_20;
    logic [15:0] PixelData_21;
    logic [15:0] PixelData_22;

    logic [15:0] GrayData_00;
    //logic [23:0] GrayData_01;
    //logic [23:0] GrayData_02;
    //logic [23:0] GrayData_10;
    //logic [23:0] GrayData_11;
    //logic [23:0] GrayData_12;
    //logic [23:0] GrayData_20;
    //logic [23:0] GrayData_21;
    //logic [23:0] GrayData_22;

    logic [15:0] Median_Result;

    logic [15:0] data00;
    logic [15:0] data01;
    logic [15:0] data02;
    logic [15:0] data10;
    logic [15:0] data11;
    logic [15:0] data12;
    logic [15:0] data20;
    logic [15:0] data21;
    logic [15:0] data22;

    logic        sobel;
    logic        chroma;

    logic        p_oe;
    logic [ 7:0] p_Addr;
    logic [37:0] p_Data;

    logic        in_polygon;
    logic        in_polygon_valid;
    logic [ 4:0] pattern_num;
    logic        in_polygon_enable;

    logic [ 7:0] red;
    logic [ 7:0] grn;
    logic [ 7:0] blu;

    logic [23:0] vid_pData;
    assign vid_pData = {red, grn, blu};

    clk_wiz_0 U_sys_clk (
        // Clock out ports
        .clk_out1(sys_clk),
        // Status and control signals
        .reset   (reset),
        // Clock in ports
        .clk_in1 (clk)
    );

    always_ff @(posedge vga_pclk) begin : data_delay
        x_pixel_d1 <= x_pixel;
        y_pixel_d1 <= y_pixel;
    end

    logic serial_clk;

    clk_wiz_1 U_serial_clk (
        // Clock out ports
        .serial_clk(serial_clk),
        // Status and control signals
        .reset     (reset),
        // Clock in ports
        .i_pclk    (vga_pclk)
    );

    VGA_Decoder U_VGA_DEC (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (vga_h_sync),
        .v_sync (vga_v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .DE     (vga_DE),
        .pclk   (vga_pclk)
    );

    logic ov7670_we;
    logic [16:0] ov7670_wAddr;
    logic [15:0] ov7670_wData;
    logic pattern_en;

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

    frame_buffer U_frame_buffer (
        .wclk (ov7670_pclk),
        .we   (ov7670_we),
        .wAddr(ov7670_wAddr),
        .wData(ov7670_wData),
        .rclk (vga_pclk),
        .oe   (vga_den),
        .rAddr(vga_rAddr),
        .rData(vga_rData)
    );

    VGA_Memcontroller U_VGA_Memcontroller (
        .DE     (vga_DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .den    (vga_den),
        .rAddr  (vga_rAddr),
        .rData  (vga_rData),
        .r_port (vga_r),      //----------------------------
        .g_port (vga_g),
        .b_port (vga_b)
    );

    GrayScaleFilter U_GrayScaleFilter (
        // gray input
        .data00_gi(origin_vga),
        //.data01_gi(PixelData_01),
        //.data02_gi(PixelData_02),
        //.data10_gi(PixelData_10),
        //.data11_gi(PixelData_11),
        //.data12_gi(PixelData_12),
        //.data20_gi(PixelData_20),
        //.data21_gi(PixelData_21),
        //.data22_gi(PixelData_22),
        // gray output
        .data00_go(GrayData_00)
        //.data01_go(GrayData_01),
        //.data02_go(GrayData_02),
        //.data10_go(GrayData_10),
        //.data11_go(GrayData_11),
        //.data12_go(GrayData_12),
        //.data20_go(GrayData_20),
        //.data21_go(GrayData_21),
        //.data22_go(GrayData_22)
    );

    LineBuffer U_LineBuffer (
        .clk         (vga_pclk),
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .data        (GrayData_00),
        .PixelData_00(PixelData_00),
        .PixelData_01(PixelData_01),
        .PixelData_02(PixelData_02),
        .PixelData_10(PixelData_10),
        .PixelData_11(PixelData_11),
        .PixelData_12(PixelData_12),
        .PixelData_20(PixelData_20),
        .PixelData_21(PixelData_21),
        .PixelData_22(PixelData_22)
    );

    MedianFilter U_Median_Filter (
        .PixelData_00 (PixelData_00),
        .PixelData_01 (PixelData_01),
        .PixelData_02 (PixelData_02),
        .PixelData_10 (PixelData_10),
        .PixelData_11 (PixelData_11),
        .PixelData_12 (PixelData_12),
        .PixelData_20 (PixelData_20),
        .PixelData_21 (PixelData_21),
        .PixelData_22 (PixelData_22),
        .Median_result(Median_Result)
    );

    LineBuffer U_LineBuf_2 (
        .clk         (vga_pclk),
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .data        (Median_Result),
        .PixelData_00(data00),
        .PixelData_01(data01),
        .PixelData_02(data02),
        .PixelData_10(data10),
        .PixelData_11(data11),
        .PixelData_12(data12),
        .PixelData_20(data20),
        .PixelData_21(data21),
        .PixelData_22(data22)
    );

    SobelFilter U_Sobel (
        .data00(data00),
        .data01(data01),
        .data02(data02),
        .data10(data10),
        .data11(data11),
        .data12(data12),
        .data20(data20),
        .data21(data21),
        .data22(data22),
        .sdata (sobel)
    );

    // mux U_MUX(
    //     .sw(sw),
    //     .vga_rgb(origin_vga),
    //     .gry(GrayData_00), 
    //     .mid(Median_Result), 
    //     .sob(sobel),
    //     .o_vga(vid_pData) 
    // );

    /* pattern_rom U_ROM (
        .clk   (sys_clk),
        .p_oe  (p_oe),
        .p_Addr(p_Addr),
        .p_Data(p_Data)
    );
 */
    /* point_in_polygon U_PointinPolygon (
        // global signals
        .clk              (sys_clk),
        .pclk             (vga_pclk),
        .reset            (reset),
        // pixcel positions
        .x_pixel          (x_pixel),
        .y_pixel          (y_pixel),
        // pattern_rom
        .p_oe             (p_oe),
        .p_Addr           (p_Addr),
        .p_Data           (p_Data),
        // Operate outport
        .pattern_num      (3'b1),
        .in_polygon_enable(1'b1),
        .in_polygon       (in_polygon)
        // .in_polygon_valid(in_polygon_valid)
    ); */

    logic p_rom_en;
    logic [7:0] p_rom_addr;
    logic [37:0] p_rom_data;
    logic pattern_in, pattern_in_valid;
    logic choma_en;


    game_main_fsm U_Game_FSM (
        .clk        (vga_pclk),
        .reset      (reset),
        //input  logic        btn,
        .x          (x_pixel_d1),
        .y          (y_pixel_d1),
        .rgb_data   (origin_vga),   //rgb565
        .pattern_en (pattern_en),
        .pattern_num(pattern_num),
        // output logic [ 7:0] tx_data,
        // output logic [ 2:0] state_data,  //detect
        .tx_start   ()              //detect
    );

    point_in_polygon U_Point_In_Polygon (
        // global signals
        .clk             (sys_clk),
        .pclk            (vga_pclk),
        .reset           (reset),
        // pixel position
        .x_pixel         (x_pixel_d1),
        .y_pixel         (y_pixel_d1),
        // pattren data
        .p_enable        (p_rom_en),
        .p_addr          (p_rom_addr),
        .p_data          (p_rom_data),
        // game state fsm data
        .state_data      (),
        .pattern_num     (pattern_num),
        .pattern_in_en   (pattern_en),
        .pattern_in      (pattern_in),
        .pattern_in_valid()
    );

    pattern_rom U_pattern_ROM (
        .clk      (sys_clk),
        .music_sel(1'b0),
        .p_oe     (p_rom_en),
        .p_Addr   (p_rom_addr),
        .p_Data   (p_rom_data)
    );

    chromakey U_crhoma (
        // Line_buffer signals
        .rgbData (origin_vga),
        .DE      (vga_DE),
        // export signals
        .bg_pixel(choma_en)
    );

    Pattern_Detect_Display U_Pattern_Detect_Display (
        //.game_in   (pattern_en),
        .game_in   (sw),
        .in_polygon(pattern_in),
        .chroma    (choma_en),           // bg_pixel from chromakey module
        .sobel     (sobel),
        .in_r      (origin_vga[15:11]),
        .in_g      (origin_vga[10:5]),
        .in_b      (origin_vga[4:0]),
        .red       (red),
        .grn       (grn),
        .blu       (blu)
    );

    /* Pattern_Detect_Display U_Display (
        .in_polygon(in_polygon),
        .chroma    (chroma),              // bg_pixel from chromakey module
        .sobel     (sobel),               // sdata from Sobel module  
        .in_r      (origin_vga[15:11]),
        .in_g      (origin_vga[10:5]),
        .in_b      (origin_vga[4:0]),
        .red       (red),
        .grn       (grn),
        .blu       (blu)
    ); */


    rgb2dvi_0 u_rgb2dvi (
        .TMDS_Clk_p (hdmi_out_clk_p),
        .TMDS_Clk_n (hdmi_out_clk_n),
        .TMDS_Data_p(hdmi_out_data_p),
        .TMDS_Data_n(hdmi_out_data_n),
        .aRst       (reset),            // Active high reset
        .vid_pData  (vid_pData),        // 24-bit RGB
        .vid_pVDE   (vga_DE),           // Video Data Enable
        .vid_pHSync (vga_h_sync),
        .vid_pVSync (vga_v_sync),
        .PixelClk   (vga_pclk),         // clk_wiz에서 나온 pixel clock
        .SerialClk  (serial_clk)        // clk_wiz에서 나온 serial clock
    );

    SCCB U_SCCB (
        .clk  (sys_clk),
        .reset(reset),
        .start(start),
        .sda  (sda),
        .scl  (scl)
    );


endmodule


// module mux (
//     input  logic [ 3:0] sw,
//     input  logic [15:0] vga_rgb,
//     input  logic [15:0] gry,
//     input  logic [15:0] mid,
//     input  logic        sob,
//     output logic [23:0] o_vga
// );

//     always_comb begin
//         case (sw)
//             4'b0001:
//             o_vga = {
//                 vga_rgb[15:11],
//                 vga_rgb[15:13],
//                 vga_rgb[10:5],
//                 vga_rgb[10:9],
//                 vga_rgb[4:0],
//                 vga_rgb[4:2]
//             };  //원본
//             4'b0010:
//             o_vga = {
//                 gry[15:11], gry[15:13], gry[10:5], gry[10:9], gry[4:0], gry[4:2]
//             };  // 그레이
//             4'b0100:
//             o_vga = {
//                 mid[15:11], mid[15:13], mid[10:5], mid[10:9], mid[4:0], mid[4:2]
//             };  // 그레이 + 미디안
//             4'b1000:
//             o_vga = sob ? 24'hFFFFFF : 24'h000000;// 그레이 + 미디안 + 소벨 
//         endcase
//     end

// endmodule
