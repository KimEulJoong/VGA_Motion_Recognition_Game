`timescale 1ns / 1ps

module Pattern_Detect_Display (
    input  logic        clk,
    input  logic        reset,
    input  logic        in_polygon,
    input  logic        g_detect,
    input  logic        sobel,
    input  logic [ 10:0] x_pixel,
    input  logic [ 10:0] y_pixel,
    input  logic        DE,
    input  logic [23:0] rgb_in,
    input  logic [ 1:0] pattern_state,
    output logic        frame_stop,
    output logic [23:0] rgb_out,
    output logic [ 2:0] result,
    output logic        uart_start
);

    logic [7:0] r8, g8, b8;
    assign r8 = rgb_in[23:16];
    assign g8 = rgb_in[15:8];
    assign b8 = rgb_in[7:0];
    

    logic [$clog2(1920*1080)-1:0] grn_cnt_reg, grn_cnt_next;
    logic [$clog2(1920*1080)-1:0] red_cnt_reg, red_cnt_next;

    logic [$clog2(1920*1080)+2:0] temp_grn_cnt_reg, temp_grn_cnt_next;
    logic [$clog2(1920*1080)+2:0] temp_red_cnt_reg, temp_red_cnt_next;
    logic [$clog2(1920*1080)+2:0] sum = temp_grn_cnt_reg + temp_red_cnt_reg;

    logic [7:0] red_reg, red_next, blu_next, blu_reg, grn_next, grn_reg;

    logic uart_start_reg, uart_start_next, uart_start_reg_d1, uart_start_reg_d2;

    logic frame_stop_reg, frame_stop_next;
    logic cnt_sucess_reg, cnt_sucess_next;
    logic cnt_frame_flag, cnt_frame_flag_next;

    logic perfect, good, bad;

    assign uart_start = uart_start_reg_d1;

    assign frame_stop = frame_stop_reg;
    assign rgb_out = {red_reg, grn_reg, blu_reg};

    logic in_polygon_reg;
    logic chroma_reg;
    logic sobel_reg;

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
        cnt_sucess_next = cnt_sucess_reg;
        cnt_frame_flag_next = cnt_frame_flag;
        temp_red_cnt_next = temp_red_cnt_reg;
        temp_grn_cnt_next = temp_grn_cnt_reg;
        uart_start_next = 1'b0;
        case (pattern_state)
            2'd0: begin
                frame_stop_next = 1'b0;
                red_next = r8;
                grn_next = g8;
                blu_next = b8;
            end

            2'd2: begin
                grn_cnt_next = 0;
                red_cnt_next = 0;
                cnt_sucess_next = 1'b0;
                cnt_frame_flag_next = 1'b0;
                frame_stop_next = 1'b0;
                if (in_polygon) begin       //                  하늘색        카메라 
                    {red_next, grn_next, blu_next} = (g_detect) ? 24'h00AAFF : {r8, g8, b8};
                end else begin  //                              연두색        빨간색
                    {red_next, grn_next, blu_next} = (g_detect) ? 24'h99FF00 : 24'hFF0000 ;
                end
            end

            2'd3: begin
                frame_stop_next = 1'b1;
                if (in_polygon) begin
                    if (g_detect) begin  //                흰색
                        {red_next, grn_next, blu_next} = 24'hFFFFFF;
                    end else begin
                        if (DE && cnt_frame_flag) begin
                            grn_cnt_next = grn_cnt_reg + 1;
                        end

                        if (sobel) begin  //                 회색
                            {red_next, grn_next, blu_next} = 24'hCCCCCC;
                        end else begin  //                   연한 초록
                            {red_next, grn_next, blu_next} = 24'h00AAFF;
                        end
                    end
                end else begin
                    if (g_detect) begin  //                연두색
                        {red_next, grn_next, blu_next} = 24'hFFFF00;
                    end else begin
                        if (DE && cnt_frame_flag) begin
                            red_cnt_next = red_cnt_reg + 1;
                        end
                        if (sobel) begin  //                 진한 빨강    
                            {red_next, grn_next, blu_next} = 24'hFF0000;
                        end else begin  //                   핑크
                            {red_next, grn_next, blu_next} = 24'hFF8888;
                        end
                    end
                end
                if ((x_pixel == 0) && (y_pixel == 5) && (!cnt_sucess_reg)) begin
                    cnt_frame_flag_next = 1'b1;
                    red_cnt_next = 0;
                    grn_cnt_next = 0;
                end
                if ((x_pixel == 1919) && (y_pixel == 1079) && (cnt_frame_flag)) begin
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
                red_next = r8;
                grn_next = g8;
                blu_next = b8;
            end
        endcase
    end

    assign result =  (temp_grn_cnt_reg * 5 >= (sum << 2)) ? 3'b100 : ((temp_grn_cnt_reg << 1) < sum) ? 3'b001 : 3'b010;

endmodule
