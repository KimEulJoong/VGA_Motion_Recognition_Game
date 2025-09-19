`timescale 1ns / 1ps


module color_detector (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 9:0] x,
    input  logic [ 9:0] y,
    input  logic [15:0] rgb_data,  //rgb565
    output logic [ 7:0] tx_data,
    output logic        tx_start   //detect
);

    logic [4:0] r;
    logic [4:0] g;
    logic [4:0] b;
    logic [2:0] digit;
    logic [7:0] xs;  // logic [8:0] xs; & >>1로 수정
    logic [7:0] ys;  // logic [8:0] ys; & >>1로 수정

    logic [7:0] tx_reg, tx_next;
    logic start_reg, start_next;

    logic red;

    logic box1_in;
    logic box2_in;
    logic box3_in;
    logic box4_in;
    logic box5_in;

    localparam  X_BOX1 = 0,  X_BOX2 = 0,   X_BOX3 = 480, X_BOX4 = 480, X_BOX5 = 320;   // 4,5 수정 필
    localparam  Y_BOX1 = 0,  Y_BOX2 = 320, Y_BOX3 = 0,   Y_BOX4 = 160, Y_BOX5 = 320;     // 4,5 수정 필


    logic [$clog2(25_000_000*3):0] sig_timer, timer_reg, timer_next;
    logic [3:0] cnt_reg, cnt_next;

    assign r = rgb_data[15:12];
    assign g = rgb_data[10:7];
    assign b = rgb_data[4:1];

    assign xs = (x >> 2);
    assign ys = (y >> 2);

    assign red = (r >= 12) && (g <= 6) && (b <= 6);


    // -----------------------------------box1-----------------------------------------
    assign box1_in = ((ys >> 2) >= (Y_BOX1 >> 2) && (ys >> 2) < ((Y_BOX1 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX1 >> 2) && (xs >> 2) < ((X_BOX1 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box2-----------------------------------------
    assign box2_in = ((ys >> 2) >= (Y_BOX2 >> 2) && (ys >> 2) < ((Y_BOX2 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX2 >> 2) && (xs >> 2) < ((X_BOX2 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box3-----------------------------------------
    assign box3_in = ((ys >> 2) >= (Y_BOX3 >> 2) && (ys >> 2) < ((Y_BOX3 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX3 >> 2) && (xs >> 2) < ((X_BOX3 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box4----------------------------------------- 수정해야 함
    assign box4_in = ((ys >> 2) >= (Y_BOX4 >> 2) && (ys >> 2) < ((Y_BOX4 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX4 >> 2) && (xs >> 2) < ((X_BOX4 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------

    // -----------------------------------box5----------------------------------------- 수정해야 함
    assign box5_in = ((ys >> 2) >= (Y_BOX5 >> 2) && (ys >> 2) < ((Y_BOX5 + 159) >> 2) &&
                    (xs >> 2) >= (X_BOX5 >> 2) && (xs >> 2) < ((X_BOX5 + 159) >> 2)) ? 1 : 0;
    // --------------------------------------------------------------------------------


    typedef enum {
        IDLE,
        BOX1,
        PSEL,
        BOX2,
        BOX3,
        START,
        PAUSE,
        RESTART,
        BOX4,
        BOX5
    } detect_state_e;

    detect_state_e detect_state, detect_next_state;

    assign tx_data  = tx_reg;
    assign tx_start = start_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            detect_state <= IDLE;
            tx_reg <= 0;
            start_reg <= 0;
            timer_reg <= 0;
            cnt_reg <= 0;
        end else begin
            detect_state <= detect_next_state;
            tx_reg <= tx_next;
            start_reg <= start_next;
            timer_reg <= timer_next;
            cnt_reg <= cnt_next;
        end
    end

    always_comb begin
        tx_next    = tx_reg;
        start_next = start_reg;
        timer_next = timer_reg; 
        cnt_next   = cnt_reg;   
        case (detect_state)
            IDLE: begin
                detect_next_state = IDLE;
                tx_next    = 8'h0;
                timer_next = 0;
                start_next = 0;
                cnt_next   = 0;
                if (box1_in && red) begin
                    detect_next_state = BOX1;
                    tx_next           = 0;
                    timer_next        = 0;
                    start_next        = 0;
                    cnt_next          = 0;
                end
            end
            BOX1: begin
                detect_next_state = BOX1;
                tx_next    = 8'h0;
                start_next = 0;
                cnt_next   = 0;
                if (box1_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 12) begin  // 3 sec
                            detect_next_state = PSEL;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
            PSEL: begin
                detect_next_state = PSEL;
                tx_next    = 8'h0;
                timer_next = 0;
                start_next = 0;
                cnt_next   = 0;
                if (box2_in && red) begin
                    detect_next_state = BOX2;
                end else if (box3_in && red) begin
                    detect_next_state = BOX3;
                end
            end
            BOX2: begin
                detect_next_state = BOX2;
                tx_next    = 8'h0;
                start_next = 0;
                cnt_next   = 0;
                if (box2_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 12) begin  // 3 sec
                            detect_next_state = START;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
            BOX3: begin
                detect_next_state = BOX3;
                tx_next    = 8'h0;
                start_next = 0;
                cnt_next   = 0;
                if (box3_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 12) begin  // 3 sec
                            detect_next_state = START;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
            START: begin
                detect_next_state = START;
                tx_next    = 8'h0;
                timer_next = 0;
                start_next = 0;
                cnt_next   = 0;
                if (box1_in && red) begin
                    detect_next_state = PAUSE;
                    tx_next    = 8'h1;
                    timer_next = 0;
                    start_next = 1;
                    cnt_next   = 0;
                end
            end
            PAUSE: begin
                detect_next_state = PAUSE;
                tx_next    = 8'h0;
                timer_next = 0;
                start_next = 0;
                cnt_next   = 0;
                if (box1_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 4) begin  // 1 sec
                            detect_next_state = RESTART;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
            RESTART: begin
                detect_next_state = RESTART;
                tx_next    = 8'h0;
                timer_next = 0;
                start_next = 0;
                cnt_next   = 0;
                if (box4_in && red) begin
                    detect_next_state = BOX4;
                end else if (box5_in && red) begin
                    detect_next_state = BOX5;
                end
            end
            BOX4: begin
                detect_next_state = BOX4;
                tx_next    = 8'h0;
                start_next = 0;
                cnt_next   = 0;
                if (box4_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 12) begin  // 3 sec
                            detect_next_state = START;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
            BOX5: begin
                detect_next_state = BOX5;
                tx_next    = 8'h0;
                start_next = 0;
                cnt_next   = 0;
                if (box5_in && red) begin
                    if (timer_next == (27'd250_000) - 1) begin  //0.25sec
                        tx_next    = 8'h1;
                        timer_next = 0;
                        start_next = 1;
                        cnt_next   = cnt_reg + 1;
                        if (cnt_next == 12) begin  // 3 sec
                            detect_next_state = IDLE;
                            tx_next           = 8'h0;
                            timer_next        = 0;
                            start_next        = 0;
                            cnt_next          = 0;
                        end
                    end else begin
                        tx_next    = 8'h0;
                        timer_next = timer_reg + 1;
                        start_next = 0;
                        cnt_next   = cnt_reg;
                    end
                end else begin
                    detect_next_state = IDLE;
                end
            end
        endcase
    end

endmodule



//module color_detector (
//    input  logic        clk,
//    input  logic        rst,
//    input  logic [ 9:0] x,
//    input  logic [ 9:0] y,
//    input  logic [15:0] rgb_data,  //rgb565
//    output logic [ 7:0] tx_data,
//    output logic        tx_start   //detect
//);
//
//    logic [4:0] r;
//    logic [4:0] g;
//    logic [4:0] b;
//    logic [2:0] digit;
//    logic [7:0] xs; // logic [8:0] xs; & >>1로 수정
//    logic [7:0] ys; // logic [8:0] ys; & >>1로 수정
//
//    logic is_red;
//
//    logic box1_on;
//    logic box2_on;
//    logic box3_on;
//
//    localparam  X_BOX1 = 0,  X_BOX2 = 0,  X_BOX3 = 480,  Y_BOX1 = 0, Y_BOX2 = 320, Y_BOX3 = 0;
//
//
//    logic [26:0] sig_timer;
//
//    assign r = rgb_data[15:12];
//    assign g = rgb_data[10:7];
//    assign b = rgb_data[4:1];
//
//    assign xs = x;
//    assign ys = y;
//
//    assign is_red = (r >= 12) && (g <= 6) && (b <= 6);
//
//
//    // -----------------------------------box1-----------------------------------------
//    assign box1_on = ((ys >> 2) >= (Y_BOX1 >> 2) && (ys >> 2) < ((Y_BOX1 + 159) >> 2) &&
//                    (xs >> 2) >= (X_BOX1 >> 2) && (xs >> 2) < ((X_BOX1 + 159) >> 2)) ? 1 : 0;
//    // --------------------------------------------------------------------------------
//
//    // -----------------------------------box2-----------------------------------------
//    assign box2_on = ((ys >> 2) >= (Y_BOX2 >> 2) && (ys >> 2) < ((Y_BOX2 + 159) >> 2) &&
//                    (xs >> 2) >= (X_BOX2 >> 2) && (xs >> 2) < ((X_BOX2 + 159) >> 2)) ? 1 : 0;
//    // --------------------------------------------------------------------------------
//
//    // -----------------------------------box3-----------------------------------------
//    assign box3_on = ((ys >> 2) >= (Y_BOX3 >> 2) && (ys >> 2) < ((Y_BOX3 + 159) >> 2) &&
//                    (xs >> 2) >= (X_BOX3 >> 2) && (xs >> 2) < ((X_BOX3 + 159) >> 2)) ? 1 : 0;
//    // --------------------------------------------------------------------------------
//    always_ff @(posedge clk) begin
//        if (rst) begin
//            tx_data <= 0;
//            tx_start <=0;
//        end else begin
//            if (!tx_start) begin
//                if (box1_on && is_red) begin
//                    tx_data   <= 8'h1;
//                    sig_timer  <= 0;
//                    tx_start <= 1;
//                end else if (box2_on && is_red) begin
//                    tx_data   <= 8'h2;
//                    sig_timer  <= 0;
//                    tx_start <= 1;
//                end else if (box3_on && is_red) begin
//                    tx_data   <= 8'h3;
//                    sig_timer  <= 0;
//                    tx_start <= 1;
//                end 
//            end else begin
//                if (digit == 5) begin // 5 sec
//                    digit      <= 0;
//                    tx_start <= 0;
//                    sig_timer  <= 0;
//                    tx_data   <= 0;
//                end else if (sig_timer == 27'd25_000_000 - 1) begin //1 sec
//                    sig_timer <= 0;
//                    digit     <= digit + 1;
//                end else begin
//                    sig_timer <= sig_timer + 1;
//                end
//            end
//        end
//    end
//
//endmodule
//