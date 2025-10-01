`timescale 1ns / 1ps

module uart_decoder (
    // gray input
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data,
    input  logic       ready_flag,
    output logic [2:0] uart_sig
);

    logic [2:0] uart_sig_next;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_sig <= 0;
        end else begin
            uart_sig <= uart_sig_next;
        end
    end

    always_comb begin
        uart_sig_next = uart_sig;
        if (ready_flag) begin
            if ((rx_data == 8'h47) || (rx_data == 8'h67)) begin // G, guart_sig == 3'd1;
                uart_sig_next = 3'd1;
            end else if ((rx_data == 8'h53) || (rx_data == 8'h73)) begin // G, g, S, s, uart_sig == 3'd1;
                uart_sig_next = 3'd5;
            end else if ((rx_data == 8'h70) || (rx_data == 8'h50)) begin // P, p, uart_sig == 3'd2; 
                uart_sig_next = 3'd2;
            end else if ((rx_data == 8'h66) || (rx_data == 8'h46)) begin // F, f, uart_sig == 3'd3;
                uart_sig_next = 3'd3;
            end else if ((rx_data == 8'h74) || (rx_data == 8'h54)) begin // T, t, uart_sig == 3'd4;
                uart_sig_next = 3'd4;
            end
        end
    end

endmodule