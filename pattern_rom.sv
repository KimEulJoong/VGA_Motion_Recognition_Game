`timescale 1ns / 1ps

module pattern_rom (
    input  logic        clk,
    input  logic        p_oe,
    input  logic [ 7:0] p_Addr,
    output logic [37:0] p_Data
);
    logic [(10+9+10+9)-1:0] rom[0:(30*8) - 1];  //8 pattern

    always_ff @(posedge clk) begin : pattern_read
        if (p_oe) begin
            p_Data <= rom[p_Addr];
        end
    end
    initial begin
        $readmemh("PATTERN.mem", rom);
    end
endmodule
