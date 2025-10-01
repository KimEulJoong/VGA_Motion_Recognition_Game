`timescale 1ns / 1ps


module uart_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic       br_tick,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    typedef enum {
        IDLE,
        START,
        DATA,
        STOP
    } rx_state_e;

    rx_state_e rx_state, rx_next_state;

    logic rx_done_reg, rx_done_next;
    logic [4:0] tick_cnt_reg, tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [7:0] rx_data_reg, rx_data_next;

    assign rx_done = rx_done_reg;
    assign rx_data = rx_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            rx_state     <= IDLE;
            rx_done_reg  <= 0;
            bit_cnt_reg  <= 0;
            tick_cnt_reg <= 0;
            rx_data_reg  <= 0;
        end else begin
            rx_state     <= rx_next_state;
            rx_done_reg  <= rx_done_next;
            tick_cnt_reg <= tick_cnt_next;
            bit_cnt_reg  <= bit_cnt_next;
            rx_data_reg  <= rx_data_next;
        end
    end

    always_comb begin
        rx_next_state = rx_state;
        rx_done_next  = rx_done;
        bit_cnt_next  = bit_cnt_reg;
        rx_data_next  = rx_data_reg;
        tick_cnt_next = tick_cnt_reg;
        case (rx_state)
            IDLE: begin
                rx_done_next = 0;
                if ((rx == 1'b0)) begin
                    rx_next_state = START;
                    tick_cnt_next = 0;
                    bit_cnt_next  = 0;
                    rx_data_next  = 0;
                end
            end

            START: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 7) begin
                        tick_cnt_next = 0;
                        rx_next_state = DATA;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 15) begin
                        tick_cnt_next = 0;
                        rx_data_next  = {rx, rx_data_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next  = 0;
                            rx_next_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (br_tick) begin
                    if (tick_cnt_reg == 23) begin
                        tick_cnt_next = 0;
                        rx_done_next  = 1;
                        rx_next_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
        endcase

    end


endmodule
