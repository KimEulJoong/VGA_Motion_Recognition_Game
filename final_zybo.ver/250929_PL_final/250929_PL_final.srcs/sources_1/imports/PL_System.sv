`timescale 1ns / 1ps

module PL_system (
    input  logic        SysClk,
    input  logic        reset,
    // PCAM DATA
    input  logic        PixelClk,
    input  logic        vid_active_video,
    input  logic [23:0] vid_data,
    input  logic        hsync,
    input  logic        vsync,
    // RGB OUTPUT
    output logic [23:0] vid_pData,
    output logic        vid_den_d5,
    output logic        vid_h_sync,
    output logic        vid_v_sync,
    // UART port
    input  logic        rx,
    output logic        tx
);

    logic clk_bufg;
    logic PixelClk_bufg;

    BUFG u_bufg_clk (
        .I(SysClk),
        .O(SysClk_bufg)
    );

    BUFG u_bufg_pixelclk (
        .I(PixelClk),
        .O(PixelClk_bufg)
    );

    logic [10:0] x_pixel;
    logic [10:0] y_pixel;

    pcam_decoder U_pcam_decoder (
        .clk             (PixelClk_bufg),
        .reset           (reset),
        .vid_active_video(vid_active_video),
        .vid_vsync       (vsync),
        .x               (x_pixel),
        .y               (y_pixel)
    );

    ////////////////////////////////////////  Delay

    logic [10:0] x_pixel_d2;
    logic [10:0] x_pixel_d4;
    logic [10:0] x_pixel_d5;

    logic [10:0] y_pixel_d2;
    logic [10:0] y_pixel_d4;
    logic [10:0] y_pixel_d5;

    logic [23:0] rgbData_d3;
    logic        vid_den_d4;

    delay_data U_Delay (
        .clk           (PixelClk_bufg),
        .reset         (reset),
        .DE            (vid_active_video),
        .x_pixel       (x_pixel),
        .y_pixel       (y_pixel),
        .hdmi_h_sync   (hsync),
        .hdmi_v_sync   (vsync),
        .x_pixel_d1    (),
        .y_pixel_d1    (),
        .x_pixel_d2    (x_pixel_d2),
        .y_pixel_d2    (y_pixel_d2),
        .x_pixel_d3    (),
        .y_pixel_d3    (),
        .x_pixel_d4    (x_pixel_d4),
        .y_pixel_d4    (y_pixel_d4),
        .x_pixel_d5    (x_pixel_d5),
        .y_pixel_d5    (y_pixel_d5),
        .DE_d4         (vid_den_d4),
        .DE_d5         (vid_den_d5),
        .hdmi_h_sync_d5(vid_h_sync),
        .hdmi_v_sync_d5(vid_v_sync)
    );

    ////////////////////////////////////////  Filter

    logic [23:0] GrayData_00;

    logic [23:0] PixelData_00;
    logic [23:0] PixelData_01;
    logic [23:0] PixelData_02;
    logic [23:0] PixelData_10;
    logic [23:0] PixelData_11;
    logic [23:0] PixelData_12;
    logic [23:0] PixelData_20;
    logic [23:0] PixelData_21;
    logic [23:0] PixelData_22;

    logic [23:0] Median_Result;

    logic [23:0] data00;
    logic [23:0] data01;
    logic [23:0] data02;
    logic [23:0] data10;
    logic [23:0] data11;
    logic [23:0] data12;
    logic [23:0] data20;
    logic [23:0] data21;
    logic [23:0] data22;

    LineBuffer #(
        .WIDTH(24)
    ) U_LineBuffer_1 (
        .clk         (PixelClk_bufg),
        .x_pixel     (x_pixel),
        .y_pixel     (y_pixel),
        .data        (vid_data),
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

    LineBuffer #(
        .WIDTH(24)
    ) U_LineBuffer_2 (
        .clk         (PixelClk_bufg),
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

    logic [7:0] g_data00;
    logic [7:0] g_data01;
    logic [7:0] g_data02;
    logic [7:0] g_data10;
    logic [7:0] g_data11;
    logic [7:0] g_data12;
    logic [7:0] g_data20;
    logic [7:0] g_data21;
    logic [7:0] g_data22;

    GrayScale_Filter U_GrayScale_Filter_9 (
        .data00_gi(data00),
        .data01_gi(data01),
        .data02_gi(data02),
        .data10_gi(data10),
        .data11_gi(data11),
        .data12_gi(data12),
        .data20_gi(data20),
        .data21_gi(data21),
        .data22_gi(data22),
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

    logic g_detect;
    logic r_detect;

    detect_grn U_detect_grn (
        .rgb_in  (data11),
        .g_detect(g_detect)
    );


    detect_red U_detect_red (
        .rgb_in  (vid_data),
        .r_detect(r_detect)
    );
    //////////////////////////////////////// 

    logic        p_rom_en;
    logic [ 9:0] p_rom_addr;
    logic [43:0] p_rom_data;

    logic        u_start;
    logic [ 2:0] uart_sig_sync;
    logic        music_sel;
    logic [ 2:0] mode_sel;
    logic [ 1:0] pattern_state;
    logic [ 4:0] pattern_num;
    logic        pattern_en;
    logic [ 1:0] guide_sel;
    logic        pattern_in;

    logic [ 7:0] rx_data;
    logic        ready_flag;
    logic [ 2:0] result;
    logic        u_score_start;
    logic [ 2:0] uart_sig;

    pattern_rom U_pattern_ROM (
        .clk      (PixelClk_bufg),
        .music_sel(music_sel),
        .p_oe     (p_rom_en),
        .p_Addr   (p_rom_addr),
        .p_Data   (p_rom_data)
    );

    game_main_fsm U_Game_FSM (
        .clk          (PixelClk_bufg),
        .reset        (reset),
        .x            (x_pixel),
        .y            (y_pixel),
        .r_detect     (r_detect),
        .tx_start     (u_start),
        .uart_sig     (uart_sig_sync),
        .music_sel    (music_sel),
        .mode_sel     (mode_sel),
        .pattern_state(pattern_state),
        .pattern_num  (pattern_num),
        .pattern_en   (pattern_en),
        .guide_sel    (guide_sel)
    );

    point_in_polygon U_Point_In_Polygon (
        .clk             (PixelClk_bufg),
        .reset           (reset),
        .x_pixel         (x_pixel),
        .y_pixel         (y_pixel),
        .p_enable        (p_rom_en),
        .p_addr          (p_rom_addr),
        .p_data          (p_rom_data),
        .pattern_num     (pattern_num),
        .pattern_in_en   (pattern_en),
        .pattern_in      (pattern_in),
        .in_polygon_valid()
    );

    sender_uart U_UART (
        .clk          (SysClk_bufg),
        .reset        (reset),
        .rx           (rx),
        .uart_mode_sel(mode_sel),
        .start        (u_start | u_score_start),
        .tx           (tx),
        .rx_pop_data  (rx_data),
        .ready_flag   (ready_flag),
        .result       (result)
    );

    uart_decoder U_uart_decoder (
        .clk       (SysClk_bufg),
        .reset     (reset),
        .rx_data   (rx_data),
        .uart_sig  (uart_sig),
        .ready_flag(ready_flag)
    );

    Synchronizer U_Synchronizer (
        .clk  (PixelClk_bufg),
        .reset(reset),
        .d_in (uart_sig),
        .d_out(uart_sig_sync)
    );

    logic [23:0] rgb_888;

    Pattern_Detect_Display U_Pattern_Detect_Display (
        .clk          (PixelClk_bufg),
        .reset        (reset),
        .in_polygon   (pattern_in),
        .g_detect     (g_detect),
        .sobel        (sobel),          // 4clk delay signal
        .x_pixel      (x_pixel_d4),
        .y_pixel      (y_pixel_d4),
        .DE           (vid_den_d4),
        .rgb_in       (data11),
        .pattern_state(pattern_state),
        .frame_stop   (frame_stop),
        .rgb_out      (rgb_888),
        .result       (result),
        .uart_start   (u_score_start)
    );

    logic [1:0] guide_sel_d4;

    delay_sig U_delay_sig (
        .clk    (PixelClk_bufg),
        .reset  (reset),
        .sel_in (guide_sel),
        .sel_out(guide_sel_d4)
    );

    GuideLine U_GuideLine (
        .sel    (guide_sel_d4),
        .x      (x_pixel_d5),
        .y      (y_pixel_d5),
        .rgb_888(rgb_888),
        .rgb    (vid_pData)
    );

endmodule
