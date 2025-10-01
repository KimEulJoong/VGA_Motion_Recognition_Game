`timescale 1ns / 1ps

module pattern_rom (
    input  logic        clk,
    input  logic        music_sel,
    input  logic        p_oe,
    input  logic [ 9:0] p_Addr,
    output logic [37:0] p_Data
);
    logic [37:0] music_rom [0:(30*20) - 1];  // 10 pattern *2
    logic [ 9:0] base_addr;

    assign base_addr = music_sel ? 10'd300 : 10'd0;

    always_ff @(posedge clk) begin : pattern_read
        if (p_oe) begin
            p_Data <= music_rom[base_addr + p_Addr];
        end
    end

    initial begin
        $readmemh("PATTERN.mem", music_rom);
    end

endmodule
