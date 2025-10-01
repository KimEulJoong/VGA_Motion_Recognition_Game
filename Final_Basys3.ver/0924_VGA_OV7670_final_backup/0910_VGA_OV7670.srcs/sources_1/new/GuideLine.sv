`timescale 1ns / 1ps

module GuideLine (
    input        [ 1:0] sel,
    input        [ 9:0] x,
    input        [ 9:0] y,
    input  logic [11:0] rgb_444,
    output logic [11:0] rgb
);

    always_comb begin
        rgb = rgb_444;
        case (sel)
            2'b00: begin
                rgb = rgb_444;
            end
            2'b01: begin
                if ( ( (x == 20 || x == 140) && (y > 180 && y < 300) ) || ( (y == 180 || y == 300) && (x >= 20 && x <= 140) ) ) begin
                    rgb = 12'hF00;
                end else begin
                    rgb = rgb_444;
                end
            end
            2'b10: begin
                if ( ( (x == 20 || x == 140) && (y > 20 && y < 140) ) || ( (y == 20 || y == 140) && (x >= 20 && x <= 140) ) || ( (x == 500 || x == 620) && (y > 20 && y < 140) ) || ( (y == 20 || y == 140) && (x >= 500 && x <= 620) ) ) begin
                    rgb = 12'hF00;
                end else begin
                    rgb = rgb_444;
                end
            end
        endcase
    end

endmodule    
