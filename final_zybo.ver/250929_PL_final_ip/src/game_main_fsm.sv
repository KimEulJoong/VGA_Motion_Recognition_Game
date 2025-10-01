`timescale 1ns / 1ps

module game_main_fsm (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 10:0] x,
    input  logic [ 10:0] y,
    input  logic        r_detect,
    output logic        tx_start,
    input  logic [ 2:0] uart_sig,
    output logic        music_sel,
    output logic [ 2:0] mode_sel,
    output logic [ 1:0] pattern_state,
    output logic [ 4:0] pattern_num,
    output logic        pattern_en,
    output logic [ 1:0] guide_sel
);

    logic [3:0] qs_cnt_reg, qs_cnt_next;
    logic qs_tick;
    logic detected, detected_golden, detected_soda;
    logic flag_reg, flag_next;
    logic flag_reg_golden, flag_next_golden;
    logic flag_reg_soda, flag_next_soda;
    logic [2:0] mode_sel_reg, mode_sel_next;
    logic music_sel_reg, music_sel_next;
    logic [1:0] pattern_state_reg, pattern_state_next;

    logic [4:0] pattern_num_reg, pattern_num_next;
    logic [1:0] guide_sel_reg, guide_sel_next;

    assign mode_sel = mode_sel_reg;
    assign pattern_state = pattern_state_reg;
    assign music_sel = music_sel_reg;
    assign pattern_num = pattern_num_reg;
    assign guide_sel = guide_sel_reg;

    logic box1_in, box2_in, box3_in, box4_in, box5_in, box6_in;

    localparam  X_BOX1 = 10,  X_BOX2 = 10,   X_BOX3 = 10,   X_BOX4 = 1440, X_BOX5 = 1440, X_BOX6 = 1440;   // 4,5 수정 필
    localparam  Y_BOX1 = 10,  Y_BOX2 = 360,  Y_BOX3 = 720,  Y_BOX4 = 10,  Y_BOX5 = 360, Y_BOX6 = 720;   // 4,5 수정 필

    // -----------------------------------box1-----------------------------------------
    assign box1_in = ( (y >= Y_BOX1) && (y < (Y_BOX1 + 349)) &&
                     (x >= X_BOX1 ) && (x < (X_BOX1 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box2-----------------------------------------
    assign box2_in = ( (y >= Y_BOX2) && (y < (Y_BOX2 + 349)) &&
                     (x >= X_BOX2 ) && (x < (X_BOX2 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // -----------------------------------box3-----------------------------------------
    assign box3_in = ( (y >= Y_BOX3) && (y < (Y_BOX3 + 349)) &&
                     (x >= X_BOX3 ) && (x < (X_BOX3 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box4-----------------------------------------
    assign box4_in = ( (y >= Y_BOX4) && (y < (Y_BOX4 + 349)) &&
                     (x >= X_BOX4 ) && (x < (X_BOX4 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box5-----------------------------------------
    assign box5_in = ( (y >= Y_BOX5) && (y < (Y_BOX5 + 349)) &&
                     (x >= X_BOX5 ) && (x < (X_BOX5 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // -----------------------------------box6-----------------------------------------
    assign box6_in = ( (y >= Y_BOX6) && (y < (Y_BOX6 + 349)) &&
                     (x >= X_BOX6 ) && (x < (X_BOX6 + 469)) ) ? 1 : 0;
    // --------------------------------------------------------------------------------


    logic
        box_intro, box_music_1, box_music_2, box_pause, box_restart, box_reset;

    assign box_intro   = box2_in;
    assign box_music_1 = box1_in;
    assign box_music_2 = box4_in;
    assign box_pause   = box1_in;
    assign box_restart = (box1_in || box2_in || box3_in);
    assign box_reset   = (box4_in || box5_in || box6_in);

    logic start_reg, start_next;
    logic [$clog2(30_000_000)-1:0] timer;

    typedef enum {
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

    assign tx_start = start_reg;
    logic pattern_en_reg, pattern_en_next;
    assign pattern_en = pattern_en_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            detect_state      <= IDLE;
            start_reg         <= 0;
            qs_cnt_reg        <= 0;
            flag_reg          <= 0;
            mode_sel_reg      <= 0;
            pattern_num_reg   <= 0;
            music_sel_reg     <= 0;
            pattern_state_reg <= 0;
            pattern_en_reg    <= 0;
            guide_sel_reg     <= 0;
        end else begin
            detect_state      <= detect_next_state;
            start_reg         <= start_next;
            qs_cnt_reg        <= qs_cnt_next;
            flag_reg          <= flag_next;
            flag_reg_golden   <= flag_next_golden;
            flag_reg_soda     <= flag_next_soda;
            mode_sel_reg      <= mode_sel_next;
            pattern_num_reg   <= pattern_num_next;
            music_sel_reg     <= music_sel_next;
            pattern_state_reg <= pattern_state_next;
            pattern_en_reg    <= pattern_en_next;
            guide_sel_reg     <= guide_sel_next;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            timer    <= 0;
            qs_tick  <= 0;
            detected <= 0;
            detected_golden <= 0;
            detected_soda <= 0;
        end else begin
            if (flag_reg | flag_reg_golden | flag_reg_soda) begin
                if (timer == (30_000_000) - 1) begin  // 1ms 빼줌.
                    timer   <= 0;
                    qs_tick <= 1;
                end else begin
                    timer   <= timer + 1;
                    qs_tick <= 0;
                end

                if ((detect_state == READY) && box_intro && r_detect) begin
                    detected <= 1;
                end

                if ((detect_state == MSEL) && box_music_1 && r_detect) begin
                    detected_golden <= 1;
                end

                if ((detect_state == MSEL) && box_music_2 && r_detect) begin
                    detected_soda <= 1;
                end

                if ((detect_state == PAUSE) && box_pause && r_detect) begin
                    detected <= 1;
                end

                if ((detect_state == RESTART) && box_restart && r_detect) begin
                    detected <= 1;
                end

                if ((detect_state == RESET) && box_reset && r_detect) begin
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
        flag_next          = flag_reg;
        flag_next_golden   = flag_reg_golden;
        flag_next_soda     = flag_reg_soda;
        mode_sel_next      = mode_sel_reg;
        music_sel_next     = music_sel_reg;
        pattern_en_next    = pattern_en_reg;
        pattern_num_next   = pattern_num_reg;
        pattern_state_next = pattern_state_reg;
        guide_sel_next     = guide_sel_reg;
        case (detect_state)

            IDLE: begin
                guide_sel_next = 2'b01;
                pattern_state_next = 0;
                pattern_en_next = 1'b0;
                music_sel_next = 1'b0;
                if (r_detect && box_intro) begin
                    flag_next = 1;
                    detect_next_state = READY;
                    mode_sel_next = 3'd0;
                end
            end

            READY: begin
                pattern_num_next = 1'b0;
                if (flag_reg) begin
                    if (x == 1919 && y == 1079) begin
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
                if (r_detect && box_music_1) begin
                    flag_next_golden = 1;
                    mode_sel_next = 3'd1;
                end

                if (r_detect && box_music_2) begin
                    flag_next_soda = 1;
                    mode_sel_next  = 3'd2;
                end

                if (flag_reg_golden) begin
                    flag_next_soda = 0;
                    if (x == 1919 && y == 1079) begin
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
                    if (x == 1919 && y == 1079) begin
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
                    if (x == 1919 && y == 1079) begin
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
                if (r_detect && box_restart) begin
                    flag_next = 1;
                    detect_next_state = RESTART;
                    mode_sel_next = 3'd4;
                end else if (r_detect && box_reset) begin
                    flag_next = 1;
                    detect_next_state = RESET;
                    mode_sel_next = 3'd5;
                end
            end

            RESTART: begin
                if (flag_reg) begin
                    if (x == 1919 && y == 1079) begin
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
                    if (x == 1919 && y == 1079) begin
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

endmodule
