`timescale 1ns / 1ps


module fifo_controlunit(
    input  logic       clk,
    input  logic       rst,
    input  logic       push,
    input  logic       pop,
    output logic [3:0] w_ptr,
    output logic [3:0] r_ptr,
    output logic       full,
    output logic       empty,
    output logic       ready_flag
);

    // State 만들지 않고 진행

    logic [3:0] w_ptr_reg, w_ptr_next, r_ptr_reg, r_ptr_next;
    logic full_reg, full_next, empty_reg, empty_next;
    logic ready_reg, ready_next;

    assign full       = full_reg;
    assign empty      = empty_reg;
    assign w_ptr      = w_ptr_reg;
    assign r_ptr      = r_ptr_reg;
    assign ready_flag = ready_reg;


    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            w_ptr_reg <= 0;
            r_ptr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
            ready_reg <= 0;
        end else begin
            w_ptr_reg <= w_ptr_next;
            r_ptr_reg <= r_ptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
            if (push && !full) begin
                ready_reg <= 1;
            end else begin
                ready_reg <= 0;
            end


        end
    end

    always_comb begin
        w_ptr_next = w_ptr_reg;
        r_ptr_next = r_ptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        ready_next = 0;
        case ({
            pop, push
        })  // 2b로 결합
            2'b01: begin  //push
                if (full_reg == 0) begin
                    w_ptr_next = w_ptr_reg + 1;
                    empty_next = 0;
                    ready_next = 1;
                    if (w_ptr_next == r_ptr_reg) begin
                        full_next = 1;
                    end
                end
            end
            2'b10: begin  //pop
                if (empty_reg == 0) begin
                    r_ptr_next = r_ptr_reg + 1;
                    full_next  = 0;
                    if (r_ptr_next == w_ptr_reg) begin
                        empty_next = 1;
                    end
                end
            end
            2'b11: begin  //push,pop 같이 들어올 때, 우선 순위 필요 
                if (empty_reg == 1) begin
                    w_ptr_next = w_ptr_reg + 1;
                    empty_next = 0;
                end else if (full_reg == 1) begin
                    r_ptr_next = r_ptr_reg + 1;
                    full_next  = 0;
                end else begin
                    w_ptr_next = w_ptr_reg + 1;
                    r_ptr_next = r_ptr_reg + 1;

                end
            end
        endcase
    end

endmodule
