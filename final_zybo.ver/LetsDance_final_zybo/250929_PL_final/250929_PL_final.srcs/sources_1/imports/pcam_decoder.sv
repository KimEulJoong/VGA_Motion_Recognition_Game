`timescale 1ns / 1ps

module pcam_decoder (
    input logic clk,
    input logic reset,           // active-low reset
    // video input from AXI4-Stream to Video Out
    input logic vid_active_video,  // VDE
    input logic vid_vsync,
    // outputs
    output logic [10:0] x,  // 0 ~ 1919 (12비트면 충분)
    output logic [10:0] y   // 0 ~ 1079 (11비트면 충분)
);

    localparam X_MAX = 1920;
    localparam Y_MAX = 1080;

    logic prev_vsync;
    logic prev_active;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 0;
            y <= 0;
            prev_vsync <= 1'b0;
            prev_active <= 1'b0;
        end else begin
            prev_vsync  <= vid_vsync;
            prev_active <= vid_active_video;

            if (vid_vsync && !prev_vsync) begin
                // 프레임 시작: y 리셋
                y <= 0;
            end

            if (vid_active_video) begin
                if (!prev_active) begin
                    // 한 라인 시작: x 리셋
                    x <= 0;
                    if (y < Y_MAX - 1) y <= y + 1;
                    else y <= 0;
                end else begin
                    if (x < X_MAX - 1) x <= x + 1;
                    else x <= 0;
                end
            end
        end
    end

endmodule
