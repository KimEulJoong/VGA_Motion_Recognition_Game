`timescale 1ns / 1ps


module vga2hdmi (
    input  logic       pclk,        // pixel clock (e.g. 25.175 MHz)
    input  logic       clk_250Mhz,  // serdes clock = pix * 5 (for DDR 5x)
    input  logic       reset,
    input  logic [7:0] r8,
    input  logic [7:0] g8,
    input  logic [7:0] b8,
    input  logic       h_sync,
    input  logic       v_sync,
    input  logic       de,
    // physical outputs (connect these to board constraints .xdc pins)
    output logic       r_port_p,
    output logic       r_port_n,
    output logic       g_port_p,
    output logic       g_port_n,
    output logic       b_port_p,
    output logic       b_port_n,
    output logic       hdmi_clk_p,
    output logic       hdmi_clk_n
);

    logic [1:0] ctrl;
    assign ctrl = {h_sync, v_sync};

    // TMDS encoder
    logic [9:0] tmds_r_word, tmds_g_word, tmds_b_word;

    tmds_encoder tmds_r (
        .clk    (pclk),
        .reset  (reset),
        .din    (r8),
        .de     (de),
        .ctrl   (ctrl),
        .dout   (tmds_r_word)
    );

    tmds_encoder tmds_g (
        .clk    (pclk),
        .reset  (reset),
        .din    (g8),
        .de     (de),
        .ctrl   (ctrl),
        .dout   (tmds_g_word)
    );

    tmds_encoder tmds_b (
        .clk    (pclk),
        .reset  (reset),
        .din    (b8),
        .de     (de),
        .ctrl   (ctrl),
        .dout   (tmds_b_word)
    );

    // === RED CHANNEL OSERDESE2 ===
    logic ser_r;
    logic slave_shiftin1_r, slave_shiftin2_r;

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("MASTER")
    ) osr_r_master (
        .D1(tmds_r_word[0]),
        .D2(tmds_r_word[1]),
        .D3(tmds_r_word[2]),
        .D4(tmds_r_word[3]),
        .D5(tmds_r_word[4]),
        .D6(tmds_r_word[5]),
        .D7(tmds_r_word[6]),
        .D8(tmds_r_word[7]),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .SHIFTIN1(slave_shiftin1_r),
        .SHIFTIN2(slave_shiftin2_r),
        .OQ(ser_r),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("SLAVE")
    ) osr_r_slave (
        .D1(tmds_r_word[8]),
        .D2(tmds_r_word[9]),
        .D3(1'b0),
        .D4(1'b0),
        .D5(1'b0),
        .D6(1'b0),
        .D7(1'b0),
        .D8(1'b0),
        .SHIFTOUT1(slave_shiftin1_r),
        .SHIFTOUT2(slave_shiftin2_r),
        .SHIFTIN1(1'b0),  // 연결 없음, slave chain 시작점
        .SHIFTIN2(1'b0),
        .OQ(),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    // === GREEN CHANNEL OSERDESE2 ===
    logic ser_g;
    logic slave_shiftin1_g, slave_shiftin2_g;

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("MASTER")
    ) osr_g_master (
        .D1(tmds_g_word[0]),
        .D2(tmds_g_word[1]),
        .D3(tmds_g_word[2]),
        .D4(tmds_g_word[3]),
        .D5(tmds_g_word[4]),
        .D6(tmds_g_word[5]),
        .D7(tmds_g_word[6]),
        .D8(tmds_g_word[7]),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .SHIFTIN1(slave_shiftin1_g),
        .SHIFTIN2(slave_shiftin2_g),
        .OQ(ser_g),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("SLAVE")
    ) osr_g_slave (
        .D1(tmds_g_word[8]),
        .D2(tmds_g_word[9]),
        .D3(1'b0),
        .D4(1'b0),
        .D5(1'b0),
        .D6(1'b0),
        .D7(1'b0),
        .D8(1'b0),
        .SHIFTOUT1(slave_shiftin1_g),
        .SHIFTOUT2(slave_shiftin2_g),
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .OQ(),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    // === BLUE CHANNEL OSERDESE2 ===
    logic ser_b;
    logic slave_shiftin1_b, slave_shiftin2_b;

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("MASTER")
    ) osr_b_master (
        .D1(tmds_b_word[0]),
        .D2(tmds_b_word[1]),
        .D3(tmds_b_word[2]),
        .D4(tmds_b_word[3]),
        .D5(tmds_b_word[4]),
        .D6(tmds_b_word[5]),
        .D7(tmds_b_word[6]),
        .D8(tmds_b_word[7]),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .SHIFTIN1(slave_shiftin1_b),
        .SHIFTIN2(slave_shiftin2_b),
        .OQ(ser_b),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ("SDR"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1),
        .SERDES_MODE("SLAVE")
    ) osr_b_slave (
        .D1(tmds_b_word[8]),
        .D2(tmds_b_word[9]),
        .D3(1'b0),
        .D4(1'b0),
        .D5(1'b0),
        .D6(1'b0),
        .D7(1'b0),
        .D8(1'b0),
        .SHIFTOUT1(slave_shiftin1_b),
        .SHIFTOUT2(slave_shiftin2_b),
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .OQ(),
        .OCE(1'b1),
        .CLK(clk_250Mhz),
        .CLKDIV(pclk),
        .RST(reset)
    );

    // === OBUFDS outputs ===
    OBUFDS obuf_r (
        .I (ser_r),
        .O (r_port_p),
        .OB(r_port_n)
    );
    OBUFDS obuf_g (
        .I (ser_g),
        .O (g_port_p),
        .OB(g_port_n)
    );
    OBUFDS obuf_b (
        .I (ser_b),
        .O (b_port_p),
        .OB(b_port_n)
    );
    OBUFDS obuf_clk (
        .I (clk_250Mhz),
        .O (hdmi_clk_p),
        .OB(hdmi_clk_n)
    );

endmodule
