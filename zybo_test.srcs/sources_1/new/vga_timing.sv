`timescale 1ns / 1ps

module vga_timing (
    input  logic        pclk,
    input  logic        reset,
    output logic        hsync,
    output logic        vsync,
    output logic        de,
    output logic [11:0] hcount,
    output logic [11:0] vcount
);
    // 640x480@60 typical parameters (VGA)
    localparam H_VISIBLE = 640;
    localparam H_FRONT = 16;
    localparam H_PULSE = 96;
    localparam H_BACK = 48;
    localparam H_TOTAL = H_VISIBLE + H_FRONT + H_PULSE + H_BACK;  // 800

    localparam V_VISIBLE = 480;
    localparam V_FRONT = 10;
    localparam V_PULSE = 2;
    localparam V_BACK = 33;
    localparam V_TOTAL = V_VISIBLE + V_FRONT + V_PULSE + V_BACK;  // 525

    logic [11:0] hcnt, vcnt;

    always_ff @(posedge pclk, posedge reset) begin
        if (!reset) begin
            hcnt <= 0;
            vcnt <= 0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL - 1) vcnt <= 0;
                else vcnt <= vcnt + 1;
            end else begin
                hcnt <= hcnt + 1;
            end
        end
    end

    assign hcount = hcnt;
    assign vcount = vcnt;

    // HSYNC/VSYNC are asserted during pulse intervals (active low for VGA)
    assign hsync = ~((hcnt >= (H_VISIBLE + H_FRONT)) && (hcnt < (H_VISIBLE + H_FRONT + H_PULSE)));
    assign vsync = ~((vcnt >= (V_VISIBLE + V_FRONT)) && (vcnt < (V_VISIBLE + V_FRONT + V_PULSE)));

    // DE (data enable) is high during visible region
    assign de = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
endmodule
