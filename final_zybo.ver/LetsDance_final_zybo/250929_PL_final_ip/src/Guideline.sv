module GuideLine (
    input  logic [ 1:0] sel,
    input  logic [10:0] x,
    input  logic [10:0] y,
    input  logic [23:0] rgb_888,
    output logic [23:0] rgb
);

    always_comb begin
        rgb = rgb_888;
        case (sel)
            2'b00: begin
                rgb = rgb_888;
            end
            2'b01: begin
                if ( ( (x == 20 || x == 460) && (y > 380 && y < 700) ) || ( (y == 380 || y == 700) && (x >= 20 && x <= 460) ) ) begin
                    rgb = 24'hFF0000;
                end else begin
                    rgb = rgb_888;
                end
            end
            2'b10: begin
                if ( ( (x == 20 || x == 460) && (y > 20 && y < 380) ) || ( (y == 20 || y == 380) && (x >= 20 && x <= 460) ) || ( (x == 1460 || x == 1900) && (y > 20 && y < 380) ) || ( (y == 20 || y == 380) && (x >= 1460 && x <= 1900) ) ) begin
                    rgb = 24'hFF0000;
                end else begin
                    rgb = rgb_888;
                end
            end
        endcase
    end

endmodule
