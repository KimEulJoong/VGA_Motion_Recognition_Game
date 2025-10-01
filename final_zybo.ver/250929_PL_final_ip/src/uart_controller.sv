`timescale 1ns / 1ps

module uart_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic       tx_push,       // 
    input  logic [7:0] tx_push_data,
    output logic       tx,
    output logic       rx_done,
    output logic       rx_empty,
    output logic       tx_full,
    output logic [7:0] rx_pop_data,
    output logic       tx_done,
    output logic       tx_busy,
    output logic       ready_flag
);

    logic [7:0] w_rx_data, w_pop_data, w_push_data;
    logic w_rx_done, w_tx_busy, w_empty, w_tx_start, w_full;

    logic w_bd_tick;
    logic w_btn_start;
    assign rx_done = w_rx_done;
    assign tx_busy = w_tx_busy;


    btn_debounce U_START_BD (
        .clk  (clk),
        .rst  (reset),
        .i_btn(btn_start),
        .o_btn(w_start)
    );

    uart_tx U_UART_TX (
        .clk    (clk),
        .reset  (reset),
        .br_tick(w_bd_tick),
        .start  (~w_tx_start),
        .tx_data(w_pop_data),
        .tx_busy(w_tx_busy),
        .tx_done(tx_done),
        .tx     (tx)

    );

    uart_rx U_UART_RX (
        .clk    (clk),
        .reset  (reset),
        .br_tick(w_bd_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );

    fifo U_TX_FIFO (
        .clk       (clk),
        .rst       (reset),           //controll block reset용
        .push      (tx_push),       //
        .pop       (~w_tx_busy),
        .push_data (tx_push_data),  //[7:0] push
        .full      (tx_full),       // tx fifo full
        .empty     (w_tx_start),
        .pop_data  (w_pop_data),    // [7:0]
        .ready_flag()
    );

    fifo U_RX_FIFO (
        .clk       (clk),
        .rst       (reset),          //controll block reset용
        .push      (w_rx_done),
        .pop       (~rx_empty),       //rx fifo pop
        .push_data (w_rx_data),    //[7:0] from tx fifo
        .full      (),             //don't use
        .empty     (rx_empty),     // rx fifo empty
        .pop_data  (rx_pop_data),  // pop data [7:0]
        .ready_flag(ready_flag)
    );

    baud_gen U_BR (
        .clk(clk),
        .reset(reset),
        .br_tick(w_bd_tick)
    );
endmodule

