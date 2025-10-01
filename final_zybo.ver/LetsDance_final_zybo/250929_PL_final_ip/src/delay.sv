`timescale 1ns / 1ps

module delay_data (
    input  logic        clk,
    input  logic        reset,
    input  logic        DE,
    input  logic        hdmi_h_sync,
    input  logic        hdmi_v_sync,
    input  logic [10:0] x_pixel,
    input  logic [10:0] y_pixel,
    output logic [10:0] x_pixel_d1,
    output logic [10:0] y_pixel_d1,
    output logic [10:0] x_pixel_d2,
    output logic [10:0] y_pixel_d2,
    output logic [10:0] x_pixel_d3,
    output logic [10:0] y_pixel_d3,
    output logic [10:0] x_pixel_d4,
    output logic [10:0] y_pixel_d4,
    output logic [10:0] x_pixel_d5,
    output logic [10:0] y_pixel_d5,
    output logic        DE_d4,
    output logic        DE_d5,
    output logic        hdmi_h_sync_d5,
    output logic        hdmi_v_sync_d5
);

    logic        DE_d1;
    logic        DE_d2;
    logic        DE_d3;

    logic        hdmi_h_sync_d1;
    logic        hdmi_v_sync_d1;

    logic        hdmi_h_sync_d2;
    logic        hdmi_v_sync_d2;

    logic        hdmi_h_sync_d3;
    logic        hdmi_v_sync_d3;
    
    logic        hdmi_h_sync_d4;
    logic        hdmi_v_sync_d4;

    always_ff @(posedge clk) begin
        if (reset) begin
            DE_d1          <= 0;
            DE_d2          <= 0;
            DE_d3          <= 0;
            DE_d4          <= 0;
            DE_d5          <= 0;

            hdmi_h_sync_d1 <= 0;
            hdmi_h_sync_d2 <= 0;
            hdmi_h_sync_d3 <= 0;
            hdmi_h_sync_d4 <= 0;
            hdmi_h_sync_d5 <= 0;

            hdmi_v_sync_d1 <= 0;
            hdmi_v_sync_d2 <= 0;
            hdmi_v_sync_d3 <= 0;
            hdmi_v_sync_d5 <= 0;

            x_pixel_d1     <= 0;
            x_pixel_d2     <= 0;
            x_pixel_d3     <= 0;
            x_pixel_d4     <= 0;
            x_pixel_d5     <= 0;
            
            y_pixel_d1     <= 0;
            y_pixel_d2     <= 0;
            y_pixel_d3     <= 0;
            y_pixel_d4     <= 0;
            y_pixel_d5     <= 0;
        end else begin
            DE_d1          <= DE;
            DE_d2          <= DE_d1;
            DE_d3          <= DE_d2;
            DE_d4          <= DE_d3;

            hdmi_h_sync_d1 <= hdmi_h_sync;
            hdmi_h_sync_d2 <= hdmi_h_sync_d1;
            hdmi_h_sync_d3 <= hdmi_h_sync_d2;
            hdmi_h_sync_d4 <= hdmi_h_sync_d3;
            hdmi_h_sync_d5 <= hdmi_h_sync_d4;

            hdmi_v_sync_d1 <= hdmi_v_sync;
            hdmi_v_sync_d2 <= hdmi_v_sync_d1;
            hdmi_v_sync_d3 <= hdmi_v_sync_d2;
            hdmi_v_sync_d4 <= hdmi_v_sync_d3;
            hdmi_v_sync_d5 <= hdmi_v_sync_d4;

            x_pixel_d1     <= x_pixel;
            x_pixel_d2     <= x_pixel_d1;
            x_pixel_d3     <= x_pixel_d2;
            x_pixel_d4     <= x_pixel_d3;
            x_pixel_d5     <= x_pixel_d4;

            y_pixel_d1     <= y_pixel;
            y_pixel_d2     <= y_pixel_d1;
            y_pixel_d3     <= y_pixel_d2;
            y_pixel_d4     <= y_pixel_d3;
            y_pixel_d5     <= y_pixel_d4;
        end
    end

endmodule
