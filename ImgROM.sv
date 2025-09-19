`timescale 1ns / 1ps

module ImgROM (
    input  logic        pclk,
    input  logic [16:0] addr,
    output logic [15:0] data
);
    logic [15:0] mem[0:320*240-1];

    initial begin
        $readmemh("Lenna.mem", mem);
    end

    always_ff @(posedge pclk) begin
        data <= mem[addr];
    end
    
endmodule
