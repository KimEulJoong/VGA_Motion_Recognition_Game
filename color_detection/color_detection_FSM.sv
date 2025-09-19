`timescale 1ns / 1ps

module color_detector (
    input  logic        clk,
    input  logic        reset,
    //input  logic        btn,
    input  logic [ 9:0] x,
    input  logic [ 9:0] y,
    input  logic [15:0] rgb_data,      //rgb565
    input  logic        bg_pixel,
    // output logic [ 7:0] tx_data,
    output logic [ 2:0] mode_sel,      //detect   수정!!!
    output logic        tx_start,      //detect
    //play_fsm input
    input  logic        song_select,
    input  logic [ 7:0] rx_data,
    output logic        pattern,
    output logic        order_cnt,
    //Loading
    output logic [ 9:0] chroma_start,
    output logic [ 9:0] chroma_end
);

    logic r4, g4, b4;
    logic [5:0] r6, g6, b6;

    logic red;
    logic r_is_max, s_is_ok, value_is_ok;

    logic [3:0] qs_cnt_reg, qs_cnt_next;
    logic qs_tick, detected;
    logic start_state_reg, start_state_next;
    logic flag_reg, flag_next;
    logic [2:0] mode_sel_reg, mode_sel_next;
    logic [9:0] chroma_start_reg, chroma_start_next;
    logic [9:0] chroma_end_reg, chroma_end_next;
    logic signal, signal_next;

    assign mode_sel = mode_sel_reg;
    assign chroma_start = chroma_start_reg;
    assign chroma_end = chroma_end_reg;

    assign r4 = rgb_data[15:12];
    assign g4 = rgb_data[10:7];
    assign b4 = rgb_data[4:1];

    // 5 / 6 / 5를 비교를 위해 6비트 통일
    assign r6 = {rgb_data[15:11], 1'b0};  // 32
    assign g6 = rgb_data[10:5];  // 64
    assign b6 = {rgb_data[4:0], 1'b0};  // 32

    // RGB565 -> HSV 기반 Red 검출
    logic [5:0] max_val, min_val, delta;

    assign max_val = (r6 > g6) ? ((r6 > b6) ? r6 : b6) : ((g6 > b6) ? g6 : b6);
    assign min_val = (r6 < g6) ? ((r6 < b6) ? r6 : b6) : ((g6 < b6) ? g6 : b6);
    assign delta = max_val - min_val;

    assign r_is_max = (r6 > g6) && (r6 > b6);
    assign s_is_ok = (delta >= (max_val >> 2));

    assign red = r_is_max && s_is_ok;

    //add

    logic box1_in, box2_in, box3_in, box4_in, box5_in, box6_in;

    logic [9:0]
        X_BOX1 = chroma_start_reg,
        X_BOX2 = chroma_start_reg,
        X_BOX3 = chroma_start_reg,
        X_BOX4 = chroma_end_reg,
        X_BOX5 = chroma_end_reg,
        X_BOX6 = chroma_end_reg;  // 4,5 수정 필
    localparam  Y_BOX1 = 10,  Y_BOX2 = 160,  Y_BOX3 = 320,  Y_BOX4 = 10,  Y_BOX5 = 160, Y_BOX6 = 320;   // 4,5 수정 필

    // -----------------------------------box1-----------------------------------------
    assign box1_in = ( (y >= Y_BOX1) && (y < (Y_BOX1 + 149)) &&
                     (x >= 10 ) && (x < (X_BOX1 )) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box2-----------------------------------------
    assign box2_in = ( (y >= Y_BOX2) && (y < (Y_BOX2 + 149)) &&
                     (x >= 10 ) && (x < (X_BOX2 )) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box3-----------------------------------------
    assign box3_in = ( (y >= Y_BOX3) && (y < (Y_BOX3 + 149)) &&
                     (x >= 10 ) && (x < X_BOX3 ) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box4-----------------------------------------
    assign box4_in = ( (y >= Y_BOX4) && (y < (Y_BOX4 + 149)) &&
                     (x >= X_BOX4 ) && (x < 630 ) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box5-----------------------------------------
    assign box5_in = ( (y >= Y_BOX5) && (y < (Y_BOX5 + 149)) &&
                     (x >= X_BOX5 ) && (x < 630 ) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box6-----------------------------------------
    assign box6_in = ( (y >= Y_BOX6) && (y < (Y_BOX6 + 149)) &&
                     (x >= X_BOX6 ) && (x < 630 ) ) ? 1 : 0;
    // --------------------------------------------------------------------------------

    logic
        box_intro, box_music_1, box_music_2, box_pause, box_restart, box_reset;

    assign box_intro   = box3_in;
    // assign box_mode_1p = box1_in || box2_in || box3_in;
    // assign box_mode_2p = box4_in || box5_in || box6_in;
    assign box_music_1 = box1_in;
    assign box_music_2 = box4_in;
    assign box_pause   = box1_in;
    assign box_restart = (box1_in || box2_in || box3_in);
    assign box_reset   = (box4_in || box5_in || box6_in);

    //assign tx_start = box_intro && red;

    // logic [7:0] tx_reg, tx_next;
    logic start_reg, start_next;
    logic [$clog2(100_000_000 / 16)-1:0] timer;
    // logic [3:0] three_cnt_reg, three_cnt_next;



    typedef enum {
        LOADING,
        IDLE,
        READY,
        MSEL,
        GOLDEN,
        SODA,
        START,
        PAUSE,
        WAIT,         
        RESTART,
        RESET
    } detect_state_e;

    detect_state_e detect_state, detect_next_state;

    assign state_data = detect_state;
    // assign tx_data  = tx_reg;
    assign tx_start   = start_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            detect_state     <= IDLE;
            // tx_reg          <= 0;
            start_reg        <= 0;
            qs_cnt_reg       <= 0;
            // three_cnt_reg   <= 0;
            start_state_reg  <= 0;
            flag_reg         <= 0;
            mode_sel_reg     <= 0;
            chroma_start_reg <= 0;
            chroma_end_reg   <= 0;
            signal           <= 0;
        end else begin
            detect_state     <= detect_next_state;
            // tx_reg          <= tx_next;
            start_reg        <= start_next;
            // three_cnt_reg   <= three_cnt_next;
            qs_cnt_reg       <= qs_cnt_next;
            start_state_reg  <= start_state_next;
            flag_reg         <= flag_next;
            mode_sel_reg     <= mode_sel_next;
            chroma_start_reg <= chroma_start_next;
            chroma_end_reg   <= chroma_end_next;
            signal           <= signal_next;
        end
    end

    always_ff @(posedge clk or posedge reset) begin  // 249ms check tick
        if (reset) begin
            timer    <= 0;
            qs_tick  <= 0;
            detected <= 0;
        end else begin
            if (flag_reg) begin
                if (timer == (100_000_000 / 16) - 1) begin  // 1ms 빼줌.
                    timer   <= 0;
                    qs_tick <= 1;
                end else begin
                    timer   <= timer + 1;
                    qs_tick <= 0;
                end

                if ((detect_state == READY) && box_intro && red) begin
                    detected <= 1;
                end

                if ((detect_state == GOLDEN) && box_music_1 && red) begin
                    detected <= 1;
                end

                if ((detect_state == SODA) && box_music_2 && red) begin
                    detected <= 1;
                end

                if (x == 0 && y == 0) begin
                    detected <= 0;
                end
            end else begin
                timer    <= 0;
                qs_tick  <= 0;
                detected <= 0;
            end
        end
    end

    always_comb begin
        detect_next_state = detect_state;
        // tx_next           = tx_reg;
        start_next        = 1'b0;
        // three_cnt_next    = three_cnt_reg;
        qs_cnt_next       = qs_cnt_reg;
        start_state_next  = start_state_reg;
        flag_next         = flag_reg;
        mode_sel_next     = mode_sel_reg;
        chroma_start_next = chroma_start_reg;
        chroma_end_next   = chroma_end_reg;
        signal_next       = signal;
        case (detect_state)
            LOADING: begin  //크로마키 x좌표 탐지!!!!
                if (y == 0) begin
                    if ((!signal) && bg_pixel) begin
                        chroma_start_next = x;
                        signal_next       = 1;
                    end

                    if (signal && (!bg_pixel)) begin
                        chroma_end_next   = x;
                        signal_next       = 0;
                        detect_next_state = IDLE;
                    end
                end
            end
            IDLE: begin
                if (red && box_intro) begin
                    flag_next = 1;
                    detect_next_state = READY;
                    mode_sel_next = 3'd0;
                end
            end

            READY: begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = IDLE;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = MSEL;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end

            MSEL: begin
                if (red && box_music_1) begin
                    flag_next = 1;
                    detect_next_state = GOLDEN;
                    mode_sel_next = 3'd1;
                end else if (red && box_music_2) begin
                    flag_next = 1;
                    detect_next_state = SODA;
                    mode_sel_next = 3'd2;
                end
            end

            GOLDEN: begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = MSEL;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = START;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end

            SODA: begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = MSEL;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = START;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end

            START: begin
                if (red && box_pause) begin
                    flag_next = 1;
                    detect_next_state = PAUSE;
                    mode_sel_next = 3'd3;
                end
            end


            //uart_mode_sel == 2'd3 -> pause
            //uart_mode_sel == 2'd4 -> restart
            //uart_mode_sel == 2'd5 -> reset


            PAUSE: begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = START;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = WAIT;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end
            WAIT: begin
                if (red && box_restart) begin
                    flag_next = 1;
                    detect_next_state = RESTART;
                    mode_sel_next = 3'd4;
                end else if (red && box_reset) begin
                    flag_next = 1;
                    detect_next_state = RESET;
                    mode_sel_next = 3'd5;
                end
            end
            RESTART:begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = WAIT;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = START;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end
            RESET:begin
                if (flag_reg) begin
                    if (x == 639 && y == 479) begin
                        if (!detected) begin
                            detect_next_state = WAIT;
                            qs_cnt_next       = 0;
                            start_next        = 1'b0;
                            flag_next         = 1'b0;
                        end
                    end

                    if (qs_tick) begin  // 250ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 8) begin  // 안전제일!
                            detect_next_state = IDLE;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end
        endcase
    end

    typedef enum {
        PLAY_IDLE,
        PLAY_READY,
        PLAY_START,
        PLAY_WAIT,
        PLAY_PAUSE
    } game_state_e;

    game_state_e game_state, game_next_state;


    typedef enum logic [2:0] {
        STAGE_READY = 3'd2,
        STAGE_START = 3'd3,
        STAGE_WAIT  = 3'd4
    } stage_e;

    stage_e stage_reg, stage_next;

    logic pattern_reg, pattern_next;
    logic score_range;
    logic order_cnt_reg, order_cnt_next;

    assign pattern   = pattern_reg;
    assign order_cnt = order_cnt_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            game_state <= PLAY_IDLE;
            stage_reg <= STAGE_READY;
            pattern_reg <= 0;
            order_cnt_reg <= 0;
        end else begin
            game_state    <= game_next_state;
            stage_reg     <= stage_next;
            pattern_reg   <= pattern_next;  //output
            order_cnt_reg <= order_cnt_next;  //output
        end
    end

    always_comb begin
        game_next_state = game_state;
        stage_next = stage_reg;
        pattern_next = pattern_reg;
        order_cnt_next = 0;
        score_range = 0;

        case (game_state)
            PLAY_IDLE: begin
                if (detect_state == START) begin
                    game_next_state = PLAY_READY;
                end
            end
            PLAY_READY: begin
                if (song_select) begin  // song_select from uart
                    game_next_state = PLAY_START;
                    pattern_next = (rx_data == 8'h73) ? 0 : 1; // 's' = sodapop = 0, 'g' = golden = 1 
                    //1bit라서 패턴 계산하는 쪽에서도 ready flag를 받으면 Pattern 신호를 감지하는 형태로 짜줘야 함
                end
                if (detect_state == PAUSE) begin
                    game_next_state = PLAY_PAUSE;
                    stage_next = STAGE_READY;
                end
            end
            PLAY_START: begin
                if (rx_data == 8'h70) begin  // rx_data from SW timer: 'p'
                    game_next_state = PLAY_WAIT;
                    order_cnt_next  = 1;
                end
                if (detect_state == PAUSE) begin
                    game_next_state = PLAY_PAUSE;
                    stage_next = STAGE_START;
                end
            end
            PLAY_WAIT: begin
                if (rx_data == 8'h66) begin  // rx_data from SW Score Calculation finish 'f'
                    game_next_state = PLAY_START;
                end
                if (detect_state == PAUSE) begin
                    game_next_state = PLAY_PAUSE;
                    stage_next = STAGE_WAIT;
                end
            end
            PLAY_PAUSE: begin
                case (stage_reg)
                    STAGE_READY: game_next_state = PLAY_READY;
                    STAGE_START: game_next_state = PLAY_START;
                    STAGE_WAIT:  game_next_state = PLAY_WAIT;
                endcase
            end
        endcase
    end

endmodule
