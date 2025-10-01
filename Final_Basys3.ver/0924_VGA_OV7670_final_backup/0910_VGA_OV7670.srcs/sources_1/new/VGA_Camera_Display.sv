`timescale 1ns / 1ps

module VGA_Camera_Display (  //TOP
    input  logic       clk,
    input  logic       reset,
    // ov7670 side
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_vsync,
    input  logic [7:0] ov7670_data,

    //  external port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,

    // SCCB port
    //input  logic start,
    inout  wire  sda,
    output logic scl,

    //input  logic [1:0] sw_pattern_in,
    //output logic [2:0] main_fsm_led,
    //output logic [2:0] game_fsm_led,
    //output logic [2:0] pattern_led,
    // UART port
    input  logic        rx,
    output logic        tx,
    output logic [15:0] led
);

    ////////////////////////////////////////  Camera
    logic [ 3:0] r_1;
    logic [ 3:0] g_1;
    logic [ 3:0] b_1;

    logic [ 9:0] vga_x_pixel;
    logic [ 9:0] vga_y_pixel;

    logic        vga_pclk;
    logic        vga_DE;

    logic        ov7670_we;
    logic [16:0] ov7670_wAddr;
    logic [15:0] ov7670_wData;

    logic        vga_den;
    logic [16:0] vga_rAddr;
    logic [15:0] vga_rData;
    logic        frame_stop;

    assign ov7670_xclk = vga_pclk;

    logic h_sync_nd;
    logic v_sync_nd;

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk),
        .reset  (reset),
        .pclk   (vga_pclk),
        .h_sync (h_sync_nd),
        .v_sync (v_sync_nd),
        .x_pixel(vga_x_pixel),
        .y_pixel(vga_y_pixel),
        .DE     (vga_DE)
    );

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
        .frame_stop (frame_stop),
        .wAddr(ov7670_wAddr),
        .wData(ov7670_wData),
        .rclk (vga_pclk),
        .oe   (vga_den),
        .rAddr(vga_rAddr),
        .rData(vga_rData)
    );

    logic [4:0] vga_red, vga_blu;
    logic [5:0] vga_grn;

    VGA_MemController U_VGA_MemController (
        .DE     (vga_DE),
        .x_pixel(vga_x_pixel),
        .y_pixel(vga_y_pixel),
        .den    (vga_den),
        .rAddr  (vga_rAddr),
        .rData  (vga_rData),
        .r_port (vga_red),
        .g_port (vga_grn),
        .b_port (vga_blu)
    );


    ////////////////////////////////////////  카메라 원본 출력

    logic [15:0] origin_vga;
    assign origin_vga = {vga_red, vga_grn, vga_blu};

    ////////////////////////////////////////  Delay

    logic [ 9:0] x_pixel_d1;
    logic [ 9:0] y_pixel_d1;

    logic [ 9:0] x_pixel_d2;
    logic [ 9:0] y_pixel_d2;

    logic [ 9:0] x_pixel_d3;
    logic [ 9:0] y_pixel_d3;

    logic        vga_den_d1;
    logic        vga_den_d2;
    logic        vga_den_d3;

    logic        vga_h_sync_d1;
    logic        vga_v_sync_d1;

    logic        vga_h_sync_d2;
    logic        vga_v_sync_d2;

    logic [15:0] rgbData_d1;
    logic [15:0] rgbData_d2;
    logic [15:0] rgbData_d3;

    delay_1pclk U_Delay_1 (
        .clk         (vga_pclk),
        .reset       (reset),
        .DE          (vga_den),
        .x_pixel     (vga_x_pixel),
        .y_pixel     (vga_y_pixel),
        .vga_h_sync  (h_sync_nd),
        .vga_v_sync  (v_sync_nd),
        .rgbData     (origin_vga),
        .DE_d        (vga_den_d1),
        .rgbData_d   (rgbData_d1),
        .vga_h_sync_d(vga_h_sync_d1),
        .vga_v_sync_d(vga_v_sync_d1),
        .x_pixel_d   (x_pixel_d1),
        .y_pixel_d   (y_pixel_d1)
    );

    delay_1pclk U_Delay_2 (
        .clk         (vga_pclk),
        .reset       (reset),
        .DE          (vga_den_d1),
        .x_pixel     (x_pixel_d1),
        .y_pixel     (y_pixel_d1),
        .vga_h_sync  (vga_h_sync_d1),
        .vga_v_sync  (vga_v_sync_d1),
        .rgbData     (rgbData_d1),
        .DE_d        (vga_den_d2),
        .rgbData_d   (rgbData_d2),
        .vga_h_sync_d(vga_h_sync_d2),
        .vga_v_sync_d(vga_v_sync_d2),
        .x_pixel_d   (x_pixel_d2),
        .y_pixel_d   (y_pixel_d2)
    );

    delay_1pclk U_Delay_3 (
        .clk         (vga_pclk),
        .reset       (reset),
        .DE          (vga_den_d2),
        .x_pixel     (x_pixel_d2),
        .y_pixel     (y_pixel_d2),
        .vga_h_sync  (vga_h_sync_d2),
        .vga_v_sync  (vga_v_sync_d2),
        .rgbData     (rgbData_d2),
        .DE_d        (vga_den_d3),
        .rgbData_d   (rgbData_d3),
        .vga_h_sync_d(h_sync),
        .vga_v_sync_d(v_sync),
        .x_pixel_d   (x_pixel_d3),
        .y_pixel_d   (y_pixel_d3)
    );

    ////////////////////////////////////////  Filter

    logic [15:0] GrayData_00;

    logic [15:0] PixelData_00;
    logic [15:0] PixelData_01;
    logic [15:0] PixelData_02;
    logic [15:0] PixelData_10;
    logic [15:0] PixelData_11;
    logic [15:0] PixelData_12;
    logic [15:0] PixelData_20;
    logic [15:0] PixelData_21;
    logic [15:0] PixelData_22;


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

    LineBuffer U_LineBuffer (
        .clk         (vga_pclk),
        .x_pixel     (x_pixel_d1),
        .y_pixel     (y_pixel_d1),
        .data        (origin_vga),
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

    //GrayScaleFilter U_GrayScaleFilter (
    //    // gray input
    //    .data00_gi(origin_vga),
    //    // gray output
    //    .data00_go(GrayData_00)
    //);

    LineBuffer U_LineBuffer1 (
        .clk         (vga_pclk),
        .x_pixel     (x_pixel_d2),
        .y_pixel     (y_pixel_d2),
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

    logic [5:0] g_data00;
    logic [5:0] g_data01;
    logic [5:0] g_data02;
    logic [5:0] g_data10;
    logic [5:0] g_data11;
    logic [5:0] g_data12;
    logic [5:0] g_data20;
    logic [5:0] g_data21;
    logic [5:0] g_data22;

    GrayScale_Filter_9 U_GrayScale_Filter_9 (
        // gray input
        .data00_gi(data00),
        .data01_gi(data01),
        .data02_gi(data02),
        .data10_gi(data10),
        .data11_gi(data11),
        .data12_gi(data12),
        .data20_gi(data20),
        .data21_gi(data21),
        .data22_gi(data22),
        // gray output
        .data00_go(g_data00),
        .data01_go(g_data01),
        .data02_go(g_data02),
        .data10_go(g_data10),
        .data11_go(g_data11),
        .data12_go(g_data12),
        .data20_go(g_data20),
        .data21_go(g_data21),
        .data22_go(g_data22)
    );

    logic sobel;

    SobelFilter U_Sobel (
        .data00(g_data00),
        .data01(g_data01),
        .data02(g_data02),
        .data10(g_data10),
        .data11(g_data11),
        .data12(g_data12),
        .data20(g_data20),
        .data21(g_data21),
        .data22(g_data22),
        .sdata (sobel)
    );

    //////////////////////////////////////// 

    SCCB U_SCCB (
        .clk  (clk),
        .reset(reset),
        .sda  (sda),
        .scl  (scl)
    );
    //
    //////////////////////////////////////// 

    logic chroma_en;

    chromakey U_chroma (
        // Line_buffer signals
        .DE      (vga_den_d3),
        .rgbData (data11),
        // export signals
        .bg_pixel(chroma_en)
    );

    //////////////////////////////////////// 

    logic pattern_in;

    logic [2:0] mode_sel;
    logic p_rom_en;
    logic [37:0] p_rom_data;
    logic [9:0] p_rom_addr;
    logic [1:0] pattern_state;
    logic u_start;
    logic [7:0] rx_data;
    logic ready_flag;
    logic music_sel;
    logic [4:0] pattern_num;
    logic pattern_en;
    logic [2:0] result;
    logic u_score_start;
    logic [1:0] guide_sel;

    pattern_rom U_pattern_ROM (
        .clk      (clk),
        .music_sel(music_sel),
        .p_oe     (p_rom_en),
        .p_Addr   (p_rom_addr),
        .p_Data   (p_rom_data)
    );

    logic [2:0] uart_sig;

    game_main_fsm U_Game_FSM (
        .clk          (vga_pclk),
        .reset        (reset),
        .x            (vga_x_pixel),
        .y            (vga_y_pixel),
        .rgb_data     (origin_vga),
        .mode_sel     (mode_sel),
        .pattern_state(pattern_state),
        .tx_start     (u_start),
        //.rx_data      (rx_data),
        .uart_sig     (uart_sig),
        .music_sel    (music_sel),
        .pattern_num  (pattern_num),
        .chroma_start (),
        .chroma_end   (),
        .pattern_en   (pattern_en),
        .main_fsm_led (),               // 디버깅용
        .game_fsm_led (),               // 디버깅용
        .guide_sel    (guide_sel)
    );


    point_in_polygon U_Point_In_Polygon (
        // global signals
        .clk             (clk),
        .pclk            (vga_pclk),
        .reset           (reset),
        // pixel position
        .x_pixel         (vga_x_pixel),
        .y_pixel         (vga_y_pixel),
        // pattren data
        .p_enable        (p_rom_en),
        .p_addr          (p_rom_addr),
        .p_data          (p_rom_data),
        // game state fsm data
        .pattern_num     (pattern_num),
        .pattern_in_en   (pattern_en),
        //.pattern_in_en   (1'b1),
        .pattern_in      (pattern_in),
        .in_polygon_valid(in_polygon_valid)
    );

    sender_uart U_UART (
        .clk          (clk),
        .reset        (reset),
        .rx           (rx),
        .uart_mode_sel(mode_sel),
        //input  logic [2:0] game_state_data,
        .start        (u_start | u_score_start),
        .tx           (tx),
        //output logic       tx_done
        .rx_pop_data  (rx_data),
        .ready_flag   (ready_flag),
        .result       (result)
    );

    uart_decoder U_uart_decoder (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .uart_sig(uart_sig),
        .ready_flag(ready_flag)
    );


    Pattern_Detect_Display U_Pattern_Detect_Display (
        .clk          (vga_pclk),
        .reset        (reset),
        .in_polygon   (pattern_in),
        .chroma       (chroma_en),      // bg_pixel from chromakey module
        .sobel        (sobel),
        .x_pixel      (x_pixel_d3),
        .y_pixel      (y_pixel_d3),
        .DE           (vga_den_d3),
        .in_r         (data11[15:11]),
        .in_g         (data11[10:5]),
        .in_b         (data11[4:0]),
        .pattern_state(pattern_state),
        //.pattern_state(sw_pattern_in),
        .frame_stop   (frame_stop),
        .red          (r_1),
        .grn          (g_1),
        .blu          (b_1),
        .result        (result),         // 추가
        .uart_start   (u_score_start),
        .led          (led)
    );

    GuideLine U_GuideLine (
        .sel    (guide_sel),
        .x      (x_pixel_d3),
        .y      (y_pixel_d3),
        .rgb_444({r_1, g_1, b_1}),
        .rgb    ({r_port, g_port, b_port})
    );

endmodule
