`timescale 1ns / 1ps

module point_in_polygon (
    // global signals
    input  logic        clk,
    input  logic        reset,
    // pixel position
    input  logic [10:0] x_pixel,
    input  logic [10:0] y_pixel,
    // pattren data
    output logic        p_enable,
    output logic [ 9:0] p_addr,
    input  logic [43:0] p_data,
    // game state fsm data
    input  logic [ 4:0] pattern_num,
    input  logic        pattern_in_en,
    output logic        pattern_in,
    output logic        in_polygon_valid
);

    typedef enum {
        IDLE,
        GET_PATTERN
    } pattern_state_e;

    pattern_state_e pattern_state, pattern_state_next;

    logic [9:0] p_addr_reg, p_addr_next;
    logic p_en_reg, p_en_next;

    assign p_addr   = p_addr_reg;
    assign p_enable = p_en_reg;

    logic [43:0] line[0:30];
    logic [4:0] line_cnt_reg, line_cnt_next, line_cnt_reg_d;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            pattern_state  <= IDLE;
            p_en_reg       <= 0;
            p_addr_reg     <= 0;
            line_cnt_reg   <= 0;
            line_cnt_reg_d <= 0;
        end else begin
            pattern_state  <= pattern_state_next;
            p_addr_reg     <= p_addr_next;
            p_en_reg       <= p_en_next;
            line_cnt_reg   <= line_cnt_next;
            line_cnt_reg_d <= line_cnt_reg;
        end
    end

    always_ff @(posedge clk) begin
        if (p_en_reg) begin
            line[line_cnt_reg] <= p_data;
        end
    end

    always_comb begin : State_FSM
        line_cnt_next      = line_cnt_reg;
        p_addr_next        = p_addr_reg;
        p_en_next          = p_en_reg;
        pattern_state_next = pattern_state;

        case (pattern_state)
            IDLE: begin
                if (pattern_in_en) begin
                    pattern_state_next = GET_PATTERN;
                    p_en_next          = 1'b1;
                    line_cnt_next      = 0;
                    case (pattern_num)
                        5'd0:    p_addr_next = 30 * 0;
                        5'd1:    p_addr_next = 30 * 1;
                        5'd2:    p_addr_next = 30 * 2;
                        5'd3:    p_addr_next = 30 * 3;
                        5'd4:    p_addr_next = 30 * 4;
                        5'd5:    p_addr_next = 30 * 5;
                        5'd6:    p_addr_next = 30 * 6;
                        5'd7:    p_addr_next = 30 * 7;
                        5'd8:    p_addr_next = 30 * 8;
                        5'd9:    p_addr_next = 30 * 9;
                        5'd10:   p_addr_next = 30 * 10;
                        5'd11:   p_addr_next = 30 * 11;
                        5'd12:   p_addr_next = 30 * 12;
                        5'd13:   p_addr_next = 30 * 13;
                        5'd14:   p_addr_next = 30 * 14;
                        5'd15:   p_addr_next = 30 * 15;
                        5'd16:   p_addr_next = 30 * 16;
                        5'd17:   p_addr_next = 30 * 17;
                        5'd18:   p_addr_next = 30 * 18;
                        5'd19:   p_addr_next = 30 * 19;
                        default: p_addr_next = 0;
                    endcase
                end
            end

            GET_PATTERN: begin
                if (line_cnt_reg == 30) begin
                    pattern_state_next = IDLE;
                    line_cnt_next      = 0;
                    p_en_next          = 1'b0;
                end else begin
                    p_en_next     = 1'b1;
                    line_cnt_next = line_cnt_reg + 1;
                    p_addr_next   = p_addr_reg + 1;
                end
            end
        endcase
    end

    logic [29:0] hits;

    genvar i;
    generate
        for (i = 0; i < 30; i = i + 1) begin : ray_cross_units
            ray_cross_unit U_ray_cross_unit (
                .clk    (clk),
                .line   (line[i+1]),
                .x_pixel(x_pixel),
                .y_pixel(y_pixel),
                .hit    (hits[i])
            );
        end
    endgenerate

    logic pattern_in_reg, pattern_in_next;
    assign pattern_in = pattern_in_reg;

    always_ff @(posedge clk) begin : hit_delay
        pattern_in_reg <= pattern_in_next;
    end

    assign pattern_in_next = ^hits;
    assign in_polygon_valid = pattern_state == IDLE;

endmodule
