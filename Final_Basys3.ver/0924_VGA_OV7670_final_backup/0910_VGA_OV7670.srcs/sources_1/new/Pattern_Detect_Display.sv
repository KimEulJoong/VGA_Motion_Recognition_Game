`timescale 1ns / 1ps

module Pattern_Detect_Display (
    input  logic        clk,
    input  logic        reset,
    input  logic        in_polygon,
    input  logic        chroma,         // bg_pixel from chromakey module
    input  logic        sobel,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic        DE,
    input  logic [ 4:0] in_r,
    input  logic [ 5:0] in_g,
    input  logic [ 4:0] in_b,
    //input  logic [2:0] state_data,
    input  logic [ 1:0] pattern_state,
    output logic        frame_stop,
    output logic [ 3:0] red,
    output logic [ 3:0] grn,
    output logic [ 3:0] blu,
    output logic [ 2:0] result,
    output logic [15:0] led,
    output logic        uart_start
);

    logic [$clog2(640*480)-1:0] grn_cnt_reg, grn_cnt_next;
    logic [$clog2(640*480)-1:0] red_cnt_reg, red_cnt_next;

    logic [21:0] temp_grn_cnt_reg, temp_grn_cnt_next;
    logic [21:0] temp_red_cnt_reg, temp_red_cnt_next;


    logic [3:0] red_reg, red_next, blu_next, blu_reg, grn_next, grn_reg;
    logic [7:0] score;

    logic uart_start_reg, uart_start_next, uart_start_reg_d1, uart_start_reg_d2;

    logic frame_stop_reg, frame_stop_next;
    logic cnt_sucess_reg, cnt_sucess_next;
    logic cnt_frame_flag, cnt_frame_flag_next;

    logic perfect, good, bad;

    assign uart_start = uart_start_reg_d1;

    assign frame_stop = frame_stop_reg;
    assign red = red_reg;
    assign grn = grn_reg;
    assign blu = blu_reg;

    logic in_polygon_reg;
    logic chroma_reg;
    logic sobel_reg;
    logic score_state, score_state_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            red_reg           <= 0;
            grn_reg           <= 0;
            blu_reg           <= 0;
            frame_stop_reg    <= 0;
            red_cnt_reg       <= 0;
            grn_cnt_reg       <= 0;
            cnt_frame_flag    <= 0;
            cnt_sucess_reg    <= 0;
            score_state       <= 0;
            temp_red_cnt_reg  <= 0;
            temp_grn_cnt_reg  <= 0;
            uart_start_reg    <= 0;
            uart_start_reg_d1 <= 0;
        end else begin
            red_reg           <= red_next;
            grn_reg           <= grn_next;
            blu_reg           <= blu_next;
            frame_stop_reg    <= frame_stop_next;
            red_cnt_reg       <= red_cnt_next;
            grn_cnt_reg       <= grn_cnt_next;
            score_state       <= score_state_next;
            cnt_sucess_reg    <= cnt_sucess_next;
            cnt_frame_flag    <= cnt_frame_flag_next;
            temp_red_cnt_reg  <= temp_red_cnt_next;
            temp_grn_cnt_reg  <= temp_grn_cnt_next;
            uart_start_reg    <= uart_start_next;
            uart_start_reg_d1 <= uart_start_reg;
        end
    end

    always_comb begin
        red_next = red_reg;
        grn_next = grn_reg;
        blu_next = blu_reg;
        frame_stop_next = frame_stop_reg;
        red_cnt_next = red_cnt_reg;
        grn_cnt_next = grn_cnt_reg;
        score_state_next = score_state;
        cnt_sucess_next = cnt_sucess_reg;
        cnt_frame_flag_next = cnt_frame_flag;
        temp_red_cnt_next = temp_red_cnt_reg;
        temp_grn_cnt_next = temp_grn_cnt_reg;
        uart_start_next = 1'b0;
        case (pattern_state)
            2'd0: begin
                frame_stop_next = 1'b0;
                red_next = in_r[4:1];
                grn_next = in_g[5:2];
                blu_next = in_b[4:1];
            end

            2'd2: begin
                grn_cnt_next = 0;
                red_cnt_next = 0;
                cnt_sucess_next = 1'b0;
                cnt_frame_flag_next = 1'b0;
                frame_stop_next = 1'b0;
                if (in_polygon) begin       //                   하늘색      카메라 
                    {red_next, grn_next, blu_next} = (chroma) ? 12'h0AF : {in_r[4:1], in_g[5:2], in_b[4:1]};
                end else begin  //                               연두색      빨간색
                    {red_next, grn_next, blu_next} = (chroma) ? 12'h9F0 : 12'hF00 ;
                end
            end

            2'd3: begin
                frame_stop_next = 1'b1;
                // led = 3'b100;
                if (in_polygon) begin
                    if (chroma) begin  //                 흰색
                        {red_next, grn_next, blu_next} = 12'hFFF;
                    end else begin
                        if (DE && cnt_frame_flag) begin
                            grn_cnt_next = grn_cnt_reg + 1;
                        end

                        if (sobel) begin  // 회색
                            {red_next, grn_next, blu_next} = 12'hCCC;
                        end else begin  // 연한 초록
                            {red_next, grn_next, blu_next} = 12'h0AF;
                        end
                    end
                end else begin
                    if (chroma) begin  //                 연두색
                        {red_next, grn_next, blu_next} = 12'hFF0;
                    end else begin
                        if (DE && cnt_frame_flag) begin
                            red_cnt_next = red_cnt_reg + 1;
                        end
                        if (sobel) begin  // 진한 빨강    
                            {red_next, grn_next, blu_next} = 12'hF00;
                        end else begin  // 핑크
                            {red_next, grn_next, blu_next} = 12'hF88;
                        end
                    end
                end
                if ((x_pixel == 0) && (y_pixel == 5) && (!cnt_sucess_reg)) begin
                    cnt_frame_flag_next = 1'b1;
                    red_cnt_next = 0;
                    grn_cnt_next = 0;
                end
                if ((x_pixel == 639) && (y_pixel == 474) && (cnt_frame_flag)) begin
                    cnt_frame_flag_next = 1'b0;
                    temp_red_cnt_next = red_cnt_reg;
                    temp_grn_cnt_next = grn_cnt_reg;
                    cnt_sucess_next = 1'b1;
                    uart_start_next = 1'b1;
                    red_cnt_next = 0;
                    grn_cnt_next = 0;

                end
            end
            default: begin
                red_next = in_r[4:1];
                grn_next = in_g[5:2];
                blu_next = in_b[4:1];
            end
        endcase  
    end

    //assign result = (temp_grn_cnt_reg > temp_red_cnt_reg)
    //          ? ((temp_grn_cnt_reg - temp_red_cnt_reg) > 32'd25000 ? 3'b100 : 3'b010) //37000이 원본
    //    : 3'b001;

    //assign score =  (temp_grn_cnt_reg*100) /(temp_grn_cnt_reg - temp_red_cnt_reg);

    //assign result = (score>80) ? 3'b100 : (((score>50)&&(score<=80))? 3'b010: 3'b001);
   
    //assign led = temp_grn_cnt_reg[18:3];   

    logic [22:0] sum = temp_grn_cnt_reg + temp_red_cnt_reg;  // 0925 수정

    assign result =  (temp_grn_cnt_reg * 5 >= (sum << 2)) ? 3'b100 : ((temp_grn_cnt_reg << 1) < sum) ? 3'b001 : 3'b010; 

endmodule
  