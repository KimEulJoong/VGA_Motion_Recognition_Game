`timescale 1ns / 1ps


module btn_debounce (
    input  logic clk,
    input  logic rst,
    input  logic i_btn,
    output logic o_btn
);
    parameter F_COUNT = 1000;
    // 100KHz 
    logic [$clog2(F_COUNT)-1 : 0] r_counter;
    logic r_clk;
    logic [7:0] q_reg, q_next;
    logic w_debounce;

    // 100KHz clk divider 생성
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            r_clk     <= 0;
        end else begin
            if (r_counter == F_COUNT - 1) begin
                r_counter <= 0;
                r_clk     <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;  // adder 사용하여 1 더하기
                r_clk     <= 1'b0;
            end
        end
    end

    // Shift register
    // 피드백 구조
    always @(posedge r_clk, posedge rst) begin
        if (rst) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    // 새로 들어온 비트를 shift
    always @(i_btn, r_clk, q_reg) begin
        q_next = {i_btn, q_reg[7:1]};
    end

    // 8 input and gate
    assign w_debounce = &q_reg;

    logic r_edge_q;  //Q5

    //edge detector 
    // Edge가 들어왔을 때 100Mhz 짜리 폭으로 tick 발생
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_edge_q <= 0;
        end else begin
            r_edge_q <= w_debounce;
        end
    end

    // rising edge
    assign o_btn = (~r_edge_q) & w_debounce;


endmodule
