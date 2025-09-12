`timescale 1ns / 1ps

module tmds_encoder (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] din,
    input  logic       de,
    input  logic [1:0] ctrl,
    output logic [9:0] dout
);
    localparam logic [9:0] CTRL_00 = 10'b1101010100;
    localparam logic [9:0] CTRL_01 = 10'b0010101011;
    localparam logic [9:0] CTRL_10 = 10'b0101010100;
    localparam logic [9:0] CTRL_11 = 10'b1010101011;

    logic [8:0] q_m;
    logic       use_xnor;
    logic       ones_din;
    logic       ones_qm_8;
    logic       disparity_qm;
    logic       rd;

    assign disparity_qm = (2 * ones_qm_8) - 8;

    always_comb begin
        q_m = 9'b0;
        ones_din = 0;

        for (int i = 0; i < 8; i = i + 1) ones_din = ones_din + din[i];

        q_m[0] = din[0];

        if (ones_din > 4) use_xnor = 1;
        else use_xnor = 0;

        for (int i = 1; i < 8; i = i + 1) begin
            if (!use_xnor) q_m[i] = q_m[i-1] ^ din[i];
            else q_m[i] = ~(q_m[i-1] ^ din[i]);
        end

        q_m[8] = use_xnor;
        ones_qm_8 = 0;
        for (int i = 0; i < 8; i = i + 1) ones_qm_8 = ones_qm_8 + q_m[i];
    end


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            dout <= 10'b0;
            rd   <= 0;
        end else begin
            if (!de) begin
                case (ctrl)
                    2'b00: begin
                        dout <= CTRL_00;
                        rd   <= 0;
                    end
                    2'b01: begin
                        dout <= CTRL_01;
                        rd   <= 0;
                    end
                    2'b10: begin
                        dout <= CTRL_10;
                        rd   <= 0;
                    end
                    2'b11: begin
                        dout <= CTRL_11;
                        rd   <= 0;
                    end
                    default: begin
                        dout <= CTRL_00;
                        rd   <= 0;
                    end
                endcase
            end else begin
                if (rd == 0 || disparity_qm == 0) begin
                    if (q_m[8] == 1) begin
                        dout[9] <= 1'b1;
                        dout[8] <= 1'b0;
                        dout[7:0] <= ~q_m[7:0];
                        rd <= rd - disparity_qm;
                    end else begin
                        dout[9] <= 1'b0;
                        dout[8] <= 1'b0;
                        dout[7:0] <= q_m[7:0];
                        rd <= rd + disparity_qm;
                    end
                end else begin
                    if ((rd > 0 && disparity_qm > 0) || (rd < 0 && disparity_qm < 0)) begin
                        dout[9] <= 1'b1;
                        dout[8] <= 1'b0;
                        dout[7:0] <= ~q_m[7:0];
                        rd <= rd - disparity_qm;
                    end else begin
                        dout[9] <= 1'b0;
                        dout[8] <= 1'b0;
                        dout[7:0] <= q_m[7:0];
                        rd <= rd + disparity_qm;
                    end
                end
            end
        end
    end
endmodule
