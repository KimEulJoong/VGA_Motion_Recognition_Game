`timescale 1ns / 1ps

module fifo (
    input  logic       clk,
    input  logic       rst,        //controll block reset용
    input  logic       push,
    input  logic       pop,
    input  logic [7:0] push_data,
    output logic       full,
    output logic       empty,
    output logic [7:0] pop_data,
    output logic       ready_flag
);

    logic [3:0] w_w_ptr, w_r_ptr;
    logic w_full;
    assign full = w_full;

    register_file U_REG (
        .clk  (clk),
        .wr_en(push & (~w_full)),
        .wdata(push_data),
        .w_ptr(w_w_ptr),
        .r_ptr(w_r_ptr),
        .rdata(pop_data)
    );

    fifo_controlunit U_FIFO (
        .clk       (clk),
        .rst       (rst),
        .push      (push),
        .pop       (pop),
        .w_ptr     (w_w_ptr),
        .r_ptr     (w_r_ptr),
        .full      (w_full),
        .empty     (empty),
        .ready_flag(ready_flag)
    );
endmodule


module register_file #(
    parameter DEPTH = 16,
    WIDTH = 4
) (
    input  logic             clk,
    input  logic             wr_en,  // write enable
    input  logic [      7:0] wdata,
    input  logic [WIDTH-1:0] w_ptr,  // write address
    input  logic [WIDTH-1:0] r_ptr,  // read address
    output logic [      7:0] rdata
);

    reg [7:0] mem[0:DEPTH-1];  //mem[0:2**WIDTH -1], **:제곱

    assign rdata = mem[r_ptr];    // clk마다 출력이 아닌 출력 상태 유지.

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[w_ptr] <= wdata;
        end
        //rdata <= mem[r_ptr];          // 매 clk마다 mem data를 내보낸다.
    end
endmodule
