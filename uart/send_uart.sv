`timescale 1ns / 1ps
module sender_uart (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic [2:0] uart_mode_sel,
    input  logic [2:0] game_state_data,
    input  logic       start,
    output logic       tx,
    //output logic       tx_done
    output logic [7:0] rx_pop_data,
    output logic       song_select
);

    logic w_start, w_tx_full;
    logic [31:0] w_send_data;
    logic c_state, n_state;
    logic [7:0] send_data_reg, send_data_next;
    logic send_reg, send_next;
    logic [3:0] send_cnt_reg, send_cnt_next;
    logic ready_flag;

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
        .rx_pop      (),
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
            song_select <= 0;
        end else begin
            c_state       <= n_state;
            send_data_reg <= send_data_next;
            send_reg      <= send_next;
            send_cnt_reg  <= send_cnt_next;
            if((rx_pop_data == 8'h67) || (rx_pop_data == 8'h73) || (rx_pop_data == 8'h47) ||  (rx_pop_data == 8'h53) )  begin // 's' or 'g' or 'S' or 'G'
                song_select <= 1;
            end else begin
                song_select <= 0;
            end
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
                    end

                    //uart_mode_sel == 2'd3 -> pause
                    //uart_mode_sel == 2'd4 -> restart
                    //uart_mode_sel == 2'd5 -> reset

                    /*  
                    else if (game_fsm_data == 6) begin  //perfect
                        case (send_cnt_reg)
                            0: send_data_next = 8'h70;  
                            1: send_data_next = 8'h65;
                            2: send_data_next = 8'h72;
                            3: send_data_next = 8'h66;
                            4: send_data_next = 8'h65;
                            5: send_data_next = 8'h63;
                            6: send_data_next = 8'h74;
                            7: begin
                                n_state   = 0;
                                send_next = 0;
                            end
                        endcase
                        send_cnt_next = send_cnt_reg + 1;
                    end else begin
                        n_state = c_state;
                    end
                    */
                end else n_state = c_state;
            end
        endcase
    end
endmodule

