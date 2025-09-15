`timescale 1ns / 1ps


module color_detector (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 9:0] x,
    input  logic [ 9:0] y,
    input  logic [15:0] rgb_data,  //rgb565
    output logic [ 7:0] tx_data,
    output logic        tx_start   //detect
);

    logic [4:0] r;
    logic [4:0] g;
    logic [4:0] b;
    logic [2:0] digit;
    logic [7:0] xs; // logic [8:0] xs; & >>1로 수정
    logic [7:0] ys; // logic [8:0] ys; & >>1로 수정

    logic is_red;

    logic box1_on;
    logic box2_on;
    logic box3_on;

    localparam  X_BOX1 = 0,  X_BOX2 = 0,  X_BOX3 = 480,  Y_BOX1 = 0, Y_BOX2 = 320, Y_BOX3 = 0;


    logic [26:0] sig_timer;

    assign r = rgb_data[15:12];
    assign g = rgb_data[10:7];
    assign b = rgb_data[4:1];

    assign xs = x;
    assign ys = y;

    assign is_red = (r >= 12) && (g <= 6) && (b <= 6);


    // -----------------------------------box1-----------------------------------------
    assign box1_on = ((ys >> 2) >= (Y_BOX1 >> 2) && (ys >> 2) < ((Y_BOX1 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX1 >> 2) && (xs >> 2) < ((X_BOX1 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box2-----------------------------------------
    assign box2_on = ((ys >> 2) >= (Y_BOX2 >> 2) && (ys >> 2) < ((Y_BOX2 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX2 >> 2) && (xs >> 2) < ((X_BOX2 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box3-----------------------------------------
    assign box3_on = ((ys >> 2) >= (Y_BOX3 >> 2) && (ys >> 2) < ((Y_BOX3 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX3 >> 2) && (xs >> 2) < ((X_BOX3 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            tx_data <= 0;
            tx_start <=0;
        end else begin
            if (!tx_start) begin
                if (box1_on && is_red) begin
                    tx_data   <= 8'h1;
                    sig_timer  <= 0;
                    tx_start <= 1;
                end else if (box2_on && is_red) begin
                    tx_data   <= 8'h2;
                    sig_timer  <= 0;
                    tx_start <= 1;
                end else if (box3_on && is_red) begin
                    tx_data   <= 8'h3;
                    sig_timer  <= 0;
                    tx_start <= 1;
                end 
            end else begin
                if (digit == 5) begin // 5 sec
                    digit      <= 0;
                    tx_start <= 0;
                    sig_timer  <= 0;
                    tx_data   <= 0;
                end else if (sig_timer == 27'd25_000_000 - 1) begin //1 sec
                    sig_timer <= 0;
                    digit     <= digit + 1;
                end else begin
                    sig_timer <= sig_timer + 1;
                end
            end
        end
    end

endmodule
