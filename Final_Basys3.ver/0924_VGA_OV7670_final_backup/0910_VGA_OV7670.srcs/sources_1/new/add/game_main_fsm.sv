`timescale 1ns / 1ps

module game_main_fsm (
    input  logic        clk,
    input  logic        reset,
    //input  logic        btn,
    input  logic [ 9:0] x,
    input  logic [ 9:0] y,
    input  logic [15:0] rgb_data,       //rgb565
    //input  logic        choma_in,
    // output logic [ 7:0] tx_data,
    output logic [ 2:0] mode_sel,       //detect   수정!!!
    output logic [ 1:0] pattern_state,
    output logic        tx_start,       //detect
    //play_fsm input
    //input  logic [ 7:0] rx_data,
    input  logic [ 2:0] uart_sig,
    output logic        music_sel,
    output logic [ 4:0] pattern_num,
    //Loading
    output logic [ 9:0] chroma_start,
    output logic [ 9:0] chroma_end,
    //
    output logic        pattern_en,
    output logic [ 2:0] main_fsm_led,
    output logic [ 2:0] game_fsm_led,
    output logic [ 1:0] guide_sel
);



    logic choma_in;
    logic [5:0] r6, g6, b6;

    logic red;
    logic r_is_max, s_is_ok, value_is_ok;

    logic [3:0] qs_cnt_reg, qs_cnt_next;
    logic qs_tick;
    logic detected, detected_golden, detected_soda;
    logic start_state_reg, start_state_next;
    logic flag_reg, flag_next;
    logic flag_reg_golden, flag_next_golden;
    logic flag_reg_soda, flag_next_soda;
    logic [2:0] mode_sel_reg, mode_sel_next;
    logic [9:0] chroma_start_reg, chroma_start_next;
    logic [9:0] chroma_end_reg, chroma_end_next;
    logic signal, signal_next;
    logic music_sel_reg, music_sel_next;
    logic [1:0] pattern_state_reg, pattern_state_next;

    logic [4:0] pattern_num_reg, pattern_num_next;
    logic [1:0] guide_sel_reg, guide_sel_next;

    assign guide_sel = guide_sel_reg;

    assign pattern_state = pattern_state_reg;
    assign pattern_num = pattern_num_reg;
    assign music_sel = music_sel_reg;

    assign mode_sel = mode_sel_reg;
    assign chroma_start = chroma_start_reg;
    assign chroma_end = chroma_end_reg;

    // 5 / 6 / 5를 비교를 위해 6비트 통일
    assign r6 = {rgb_data[15:11], 1'b0};  // 32
    assign g6 = rgb_data[10:5];  // 64
    assign b6 = {rgb_data[4:0], 1'b0};  // 32

    // RGB565 -> HSV 기반 Red 검출
    logic [5:0] max_val, min_val, delta;

    assign max_val = (r6 > g6) ? ((r6 > b6) ? r6 : b6) : ((g6 > b6) ? g6 : b6);
    assign min_val = (r6 < g6) ? ((r6 < b6) ? r6 : b6) : ((g6 < b6) ? g6 : b6);
    assign delta = max_val - min_val;

    assign r_is_max = (r6 > g6) && (r6 > b6) && (r6 > 32);
    assign s_is_ok = (delta >= (max_val >> 2));

    assign red = r_is_max && s_is_ok;

    //add

    logic box1_in, box2_in, box3_in, box4_in, box5_in, box6_in;

    localparam  X_BOX1 = 10,  X_BOX2 = 10,   X_BOX3 = 10,   X_BOX4 = 480, X_BOX5 = 480, X_BOX6 = 480;   // 4,5 수정 필
    localparam  Y_BOX1 = 10,  Y_BOX2 = 160,  Y_BOX3 = 320,  Y_BOX4 = 10,  Y_BOX5 = 160, Y_BOX6 = 320;   // 4,5 수정 필

    // -----------------------------------box1-----------------------------------------
    assign box1_in = ( (y >= Y_BOX1) && (y < (Y_BOX1 + 149)) &&
                     (x >= X_BOX1 ) && (x < (X_BOX1 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box2-----------------------------------------
    assign box2_in = ( (y >= Y_BOX2) && (y < (Y_BOX2 + 149)) &&
                     (x >= X_BOX2 ) && (x < (X_BOX2 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box3-----------------------------------------
    assign box3_in = ( (y >= Y_BOX3) && (y < (Y_BOX3 + 149)) &&
                     (x >= X_BOX3 ) && (x < (X_BOX3 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box4-----------------------------------------
    assign box4_in = ( (y >= Y_BOX4) && (y < (Y_BOX4 + 149)) &&
                     (x >= X_BOX4 ) && (x < (X_BOX4 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box5-----------------------------------------
    assign box5_in = ( (y >= Y_BOX5) && (y < (Y_BOX5 + 149)) &&
                     (x >= X_BOX5 ) && (x < (X_BOX5 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box6-----------------------------------------
    assign box6_in = ( (y >= Y_BOX6) && (y < (Y_BOX6 + 149)) &&
                     (x >= X_BOX6 ) && (x < (X_BOX6 + 149)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------

    //logic [9:0]
    //    X_BOX1 = chroma_start_reg,
    //    X_BOX2 = chroma_start_reg,
    //    X_BOX3 = chroma_start_reg,
    //    X_BOX4 = chroma_end_reg,
    //    X_BOX5 = chroma_end_reg,
    //    X_BOX6 = chroma_end_reg;  // 4,5 수정 필
    //localparam  Y_BOX1 = 10,  Y_BOX2 = 160,  Y_BOX3 = 320,  Y_BOX4 = 10,  Y_BOX5 = 160, Y_BOX6 = 320;   // 4,5 수정 필
    //
    //// -----------------------------------box1-----------------------------------------
    //assign box1_in = ( (y >= Y_BOX1) && (y < (Y_BOX1 + 149)) &&
    //                 (x >= 10 ) && (x < (X_BOX1 )) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------
    //// -----------------------------------box2-----------------------------------------
    //assign box2_in = ( (y >= Y_BOX2) && (y < (Y_BOX2 + 149)) &&
    //                 (x >= 10 ) && (x < (X_BOX2 )) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------
    //// -----------------------------------box3-----------------------------------------
    //assign box3_in = ( (y >= Y_BOX3) && (y < (Y_BOX3 + 149)) &&
    //                 (x >= 10 ) && (x < X_BOX3 ) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------
    //// --------------------------------------------------------------------------------
    //// -----------------------------------box4-----------------------------------------
    //assign box4_in = ( (y >= Y_BOX4) && (y < (Y_BOX4 + 149)) &&
    //                 (x >= X_BOX4 ) && (x < 630 ) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------
    //// --------------------------------------------------------------------------------
    //// -----------------------------------box5-----------------------------------------
    //assign box5_in = ( (y >= Y_BOX5) && (y < (Y_BOX5 + 149)) &&
    //                 (x >= X_BOX5 ) && (x < 630 ) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------
    //// --------------------------------------------------------------------------------
    //// -----------------------------------box6-----------------------------------------
    //assign box6_in = ( (y >= Y_BOX6) && (y < (Y_BOX6 + 149)) &&
    //                 (x >= X_BOX6 ) && (x < 630 ) ) ? 1 : 0;
    //// --------------------------------------------------------------------------------

    logic
        box_intro, box_music_1, box_music_2, box_pause, box_restart, box_reset;

    assign box_intro   = box2_in;
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
        DETECT,
        PAUSE,
        WAIT,
        RESTART,
        RESET
    } detect_state_e;

    detect_state_e detect_state, detect_next_state;

    //assign state_data = detect_state;
    // assign tx_data  = tx_reg;
    assign tx_start = start_reg;
    logic pattern_en_reg, pattern_en_next;
    assign pattern_en = pattern_en_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            detect_state      <= IDLE;
            //detect_state      <= START;
            // tx_reg          <= 0;
            start_reg         <= 0;
            qs_cnt_reg        <= 0;
            // three_cnt_reg   <= 0;
            start_state_reg   <= 0;
            flag_reg          <= 0;
            mode_sel_reg      <= 0;
            chroma_start_reg  <= 0;
            chroma_end_reg    <= 0;
            signal            <= 0;
            pattern_num_reg   <= 0;
            music_sel_reg     <= 0;
            pattern_state_reg <= 0;
            pattern_en_reg    <= 0;
            guide_sel_reg     <= 0;
        end else begin
            detect_state      <= detect_next_state;
            // tx_reg          <= tx_next;
            start_reg         <= start_next;
            // three_cnt_reg   <= three_cnt_next;
            qs_cnt_reg        <= qs_cnt_next;
            start_state_reg   <= start_state_next;
            flag_reg          <= flag_next;
            flag_reg_golden   <= flag_next_golden;
            flag_reg_soda     <= flag_next_soda;
            mode_sel_reg      <= mode_sel_next;
            chroma_start_reg  <= chroma_start_next;
            chroma_end_reg    <= chroma_end_next;
            signal            <= signal_next;
            pattern_num_reg   <= pattern_num_next;
            music_sel_reg     <= music_sel_next;
            pattern_state_reg <= pattern_state_next;
            pattern_en_reg    <= pattern_en_next;
            guide_sel_reg     <= guide_sel_next;
        end
    end

    always_ff @(posedge clk or posedge reset) begin  // 249ms check tick
        if (reset) begin
            timer    <= 0;
            qs_tick  <= 0;
            detected <= 0;
            detected_golden <= 0;
            detected_soda <= 0;
        end else begin
            if (flag_reg | flag_reg_golden | flag_reg_soda) begin
                if (timer == (100_000_000 / 20) - 1) begin  // 1ms 빼줌.
                    timer   <= 0;
                    qs_tick <= 1;
                end else begin
                    timer   <= timer + 1;
                    qs_tick <= 0;
                end

                if ((detect_state == READY) && box_intro && red) begin
                    detected <= 1;
                end

                if ((detect_state == MSEL) && box_music_1 && red) begin
                    detected_golden <= 1;
                end

                if ((detect_state == MSEL) && box_music_2 && red) begin
                    detected_soda <= 1;
                end

                if ((detect_state == PAUSE) && box_pause && red) begin
                    detected <= 1;
                end

                if ((detect_state == RESTART) && box_restart && red) begin
                    detected <= 1;
                end

                if ((detect_state == RESET) && box_reset && red) begin
                    detected <= 1;
                end

                if (x == 0 && y == 0) begin
                    detected <= 0;
                    detected_golden <= 0;
                    detected_soda <= 0;
                end
            end else begin
                timer    <= 0;
                qs_tick  <= 0;
                detected <= 0;
                detected_golden <= 0;
                detected_soda <= 0;
            end
        end
    end

    always_comb begin
        detect_next_state  = detect_state;
        start_next         = 1'b0;
        qs_cnt_next        = qs_cnt_reg;
        start_state_next   = start_state_reg;
        flag_next          = flag_reg;
        flag_next_golden   = flag_reg_golden;
        flag_next_soda     = flag_reg_soda;
        mode_sel_next      = mode_sel_reg;
        chroma_start_next  = chroma_start_reg;
        chroma_end_next    = chroma_end_reg;
        signal_next        = signal;
        music_sel_next     = music_sel_reg;
        pattern_en_next    = pattern_en_reg;
        pattern_num_next   = pattern_num_reg;
        pattern_state_next = pattern_state_reg;
        guide_sel_next     = guide_sel_reg;
        case (detect_state)
            LOADING: begin  //크로마키 x좌표 탐지!!!!
                music_sel_next = 1'b0;
                if (y == 0) begin
                    if ((!signal) && choma_in) begin
                        chroma_start_next = x;
                        signal_next       = 1;
                    end
                    if (signal && (!choma_in)) begin
                        chroma_end_next   = x;
                        signal_next       = 0;
                        detect_next_state = IDLE;
                    end
                end
            end

            IDLE: begin
                guide_sel_next = 2'b01;
                pattern_state_next = 0;
                pattern_en_next = 1'b0;
                music_sel_next = 1'b0;
                if (red && box_intro) begin
                    flag_next = 1;
                    detect_next_state = READY;
                    mode_sel_next = 3'd0;
                end
            end

            READY: begin
                pattern_num_next = 1'b0;
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
                        if (qs_cnt_reg == 10) begin  // 안전제일!
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
                guide_sel_next = 2'b10;
                main_fsm_led = 3'b001;
                if (red && box_music_1) begin
                    flag_next_golden = 1;
                    mode_sel_next = 3'd1;
                end

                if (red && box_music_2) begin
                    flag_next_soda = 1;
                    mode_sel_next  = 3'd2;
                end

                if (flag_reg_golden) begin
                    flag_next_soda = 0;
                    if (x == 639 && y == 479) begin
                        if (!detected_golden) begin
                            start_next       = 1'b0;
                            flag_next_golden = 1'b0;
                        end
                    end
                    if (qs_tick) begin  // 200ms tick
                        start_next = 1'b1;
                    end
                end

                if (flag_reg_soda) begin
                    flag_next_golden = 0;
                    if (x == 639 && y == 479) begin
                        if (!detected_soda) begin
                            start_next     = 1'b0;
                            flag_next_soda = 1'b0;
                        end
                    end
                    if (qs_tick) begin  // 200ms tick
                        start_next = 1'b1;
                    end
                end

                if (uart_sig == 3'd1) begin  // rx_data from SW timer: 'g' / 'G'
                    flag_next_golden  = 0;
                    mode_sel_next     = 3'd6;
                    music_sel_next    = 1'b0;
                    detect_next_state = START;
                end

                if (uart_sig == 3'd5) begin  // rx_data from SW timer: 's' /'S'
                    flag_next_soda    = 0;
                    mode_sel_next     = 3'd6;
                    music_sel_next    = 1'b1;
                    detect_next_state = START;
                end
            end

            START: begin
                guide_sel_next = 2'b00;
                pattern_state_next = 2;
                main_fsm_led       = 3'b010;
                start_next         = 0;
                pattern_en_next    = 1;
                if (uart_sig == 3'd2) begin  // rx_data from SW timer: 'p'
                    detect_next_state = DETECT;
                end

                if (uart_sig == 3'd4) begin // 게임 끝내고 IDLE로 초기화 't'
                    detect_next_state = IDLE;
                end
            end

            DETECT: begin
                pattern_state_next = 3;
                main_fsm_led = 3'b100;
                if (uart_sig == 3'd3) begin  // rx_data from SW Score Calculation finish 'f'
                    detect_next_state = START;
                    pattern_num_next  = pattern_num_reg + 1;
                end

                if (uart_sig == 3'd4) begin // 게임 끝내고 IDLE로 초기화 't'
                    detect_next_state = IDLE;
                end
            end

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

                    if (qs_tick) begin  // 200ms tick
                        start_next = 1'b1;
                        if (qs_cnt_reg == 20) begin  // 안전제일!
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

            RESTART: begin
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
                        if (qs_cnt_reg == 10) begin  // 안전제일!
                            detect_next_state = START;
                            qs_cnt_next       = 0;
                            flag_next         = 1'b0;
                        end else begin
                            qs_cnt_next = qs_cnt_reg + 1;
                        end
                    end
                end
            end

            RESET: begin
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
                        if (qs_cnt_reg == 10) begin  // 안전제일!
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
    /*
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

    logic score_range;


    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            game_state <= PLAY_IDLE;
            stage_reg  <= STAGE_READY;
        end else begin
            game_state <= game_next_state;
            stage_reg  <= stage_next;
        end
    end

    always_comb begin
        game_next_state    = game_state;
        stage_next         = stage_reg;
        score_range        = 0;
        pattern_num_next   = pattern_num_reg;
        pattern_state_next = pattern_state_reg;
        case (game_state)
            PLAY_IDLE: begin
                pattern_num_next = 0;
                pattern_state_next = 0;
                game_fsm_led = 3'b001;
                if (detect_state == START) begin
                    game_next_state = PLAY_START;
                    pattern_state_next = 2;
                end
            end

            PLAY_START: begin
                game_fsm_led = 3'b010;
                //if (ready_flag) begin
                if (detect_state == DETECT) begin  // rx_data from SW timer: 'p'
                    game_next_state = PLAY_WAIT;
                    pattern_state_next = 3;
                end

                //end
                if (detect_state == PAUSE) begin
                    game_next_state = PLAY_PAUSE;
                    stage_next = STAGE_START;
                end
            end

            PLAY_WAIT: begin
                game_fsm_led = 3'b100;
                //if (ready_flag) begin
                if (detect_state == START) begin  // rx_data from SW Score Calculation finish 'f'
                    game_next_state = PLAY_START;
                    pattern_state_next = 2;
                    pattern_num_next = pattern_num_reg + 1;
                end

                if (detect_state == IDLE) begin // 게임 끝내고 IDLE로 초기화 't'
                    game_next_state = PLAY_IDLE;
                    pattern_num_next = 0;
                    pattern_state_next = 0;
                end
                //end

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
*/
endmodule
