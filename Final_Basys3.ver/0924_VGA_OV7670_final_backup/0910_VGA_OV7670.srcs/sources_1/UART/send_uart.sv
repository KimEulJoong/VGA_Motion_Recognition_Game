`timescale 1ns / 1ps
module sender_uart (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic [2:0] uart_mode_sel,
    //input  logic [2:0] game_state_data,
    input  logic       start,
    output logic       tx,
    //output logic       tx_done
    output logic [7:0] rx_pop_data,
    output logic       ready_flag,
    //Pattern_detect
    input  logic [2:0] result
);

    logic w_start, w_tx_full;
    logic [31:0] w_send_data;
    logic c_state, n_state;
    logic [7:0] send_data_reg, send_data_next;
    logic send_reg, send_next;
    logic [3:0] send_cnt_reg, send_cnt_next;
    //logic ready_flag;

    /*
    btn_debounce U_START_BD (
        .clk  (clk),
        .rst  (reset),
        .i_btn(start),
        .o_btn(w_start)
    );
    */

    // wire [2:0] state_data = 1;


    uart_controller U_UART_CNTL (
        .clk         (clk),
        .reset       (reset),
        .rx          (rx),
        .tx_push_data(send_data_reg),
        .tx_push     (send_reg),
        .rx_pop_data (rx_pop_data),
        .rx_empty    (),
        .rx_done     (),
        .tx_full     (w_tx_full),
        .tx_done     (tx_done),
        .tx_busy     (),
        .tx          (tx),
        .ready_flag  (ready_flag)
    );


    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state       <= 0;
            send_data_reg <= 0;
            send_reg      <= 0;
            send_cnt_reg  <= 0;
            //song_select <= 0;
        end else begin
            c_state       <= n_state;
            send_data_reg <= send_data_next;
            send_reg      <= send_next;
            send_cnt_reg  <= send_cnt_next;
            //if (ready_flag) begin
            //    if((rx_pop_data == 8'h67) || (rx_pop_data == 8'h73) || (rx_pop_data == 8'h47) ||  (rx_pop_data == 8'h53) )  begin // 's' or 'g' or 'S' or 'G'
            //        song_select <= 1;
            //    end else begin
            //        song_select <= 0;
            //    end
            //end
        end
    end

    always @(*) begin
        n_state        = c_state;
        send_data_next = send_data_reg;
        send_next      = send_reg;
        send_cnt_next  = send_cnt_reg;
        case (c_state)
            00: begin
                send_cnt_next = 0;
                if (start) begin
                    n_state = 1;
                end
            end
            01: begin  // send
                if (~w_tx_full) begin
                    send_next = 1;  // send tick 생성.
                    if (uart_mode_sel == 3'd0) begin  // qstick
                        case (send_cnt_reg)
                            0: send_data_next = 8'h71;  // q
                            1: send_data_next = 8'h73;  // s
                            2: send_data_next = 8'h74;  // t
                            3: send_data_next = 8'h69;  // i
                            4: send_data_next = 8'h63;  // c
                            5: send_data_next = 8'h6B;  // k
                            6: send_data_next = 8'h0a;  // \n
                            7: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (uart_mode_sel == 3'd1) begin  // golden
                        case (send_cnt_reg)
                            0: send_data_next = 8'h67;  // g
                            1: send_data_next = 8'h6f;  // o
                            2: send_data_next = 8'h6c;  // l
                            3: send_data_next = 8'h64;  // d
                            4: send_data_next = 8'h65;  // e
                            5: send_data_next = 8'h6e;  // n
                            6: send_data_next = 8'h0a;  // \n
                            7: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (uart_mode_sel == 3'd2) begin  // sodapop
                        case (send_cnt_reg)
                            0: send_data_next = 8'h73;  // s
                            1: send_data_next = 8'h6f;  // o
                            2: send_data_next = 8'h64;  // d
                            3: send_data_next = 8'h61;  // a
                            4: send_data_next = 8'h70;  // p
                            5: send_data_next = 8'h6f;  // o
                            6: send_data_next = 8'h70;  // p
                            7: send_data_next = 8'h0a;  // \n
                            8: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (uart_mode_sel == 3'd3) begin  // pause
                        case (send_cnt_reg)
                            0: send_data_next = 8'h70;  // p
                            1: send_data_next = 8'h61;  // a
                            2: send_data_next = 8'h75;  // u
                            3: send_data_next = 8'h73;  // s
                            4: send_data_next = 8'h65;  // e
                            5: send_data_next = 8'h0a;  // \n
                            6: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (uart_mode_sel == 3'd4) begin  // restart
                        case (send_cnt_reg)
                            0: send_data_next = 8'h72;  // r
                            1: send_data_next = 8'h65;  // e
                            2: send_data_next = 8'h73;  // s
                            3: send_data_next = 8'h74;  // t
                            4: send_data_next = 8'h61;  // a
                            5: send_data_next = 8'h72;  // r
                            6: send_data_next = 8'h74;  // t
                            7: send_data_next = 8'h0a;  // \n
                            8: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (uart_mode_sel == 3'd5) begin  // reset
                        case (send_cnt_reg)
                            0: send_data_next = 8'h72;  // r
                            1: send_data_next = 8'h65;  // e
                            2: send_data_next = 8'h73;  // s
                            3: send_data_next = 8'h65;  // e
                            4: send_data_next = 8'h74;  // t
                            5: send_data_next = 8'h0a;  // \n
                            6: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (result[0] == 1) begin  //bad
                        case (send_cnt_reg)
                            0: send_data_next = 8'h42;  // B
                            1: send_data_next = 8'h41;  // A
                            2: send_data_next = 8'h44;  // D
                            3: send_data_next = 8'h0a;  // \n
                            4: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (result[1] == 1) begin  //good
                        case (send_cnt_reg)
                            0: send_data_next = 8'h47;  // G
                            1: send_data_next = 8'h4F;  // O
                            2: send_data_next = 8'h4F;  // O
                            3: send_data_next = 8'h44;  // D
                            4: send_data_next = 8'h0a;  // \n
                            5: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else if (result[2] == 1) begin  //perfect
                        case (send_cnt_reg)
                            0: send_data_next = 8'h50;  // P
                            1: send_data_next = 8'h45;  // E
                            2: send_data_next = 8'h52;  // R
                            3: send_data_next = 8'h46;  // F
                            4: send_data_next = 8'h45;  // E
                            5: send_data_next = 8'h43;  // C
                            6: send_data_next = 8'h54;  // T
                            7: send_data_next = 8'h0a;  // \n
                            8: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end
                end else n_state = c_state;
            end
        endcase
    end
endmodule

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
