`timescale 1ns / 1ps

module GrayScaleFilter (
    // gray input
    input  logic [11:0] data_gi,
    // gray output
    output logic [11:0] data_go
);

    logic [11:0] gray;

    assign gray = 77 * data_gi[11:8] + 154 * data_gi[7:4] + 25 * data_gi[3:0];
    // assign gray[1] = 77 * data01_gi[11:8] + 154 * data01_gi[7:4] + 25 * data01_gi[3:0];
    // assign gray[2] = 77 * data02_gi[11:8] + 154 * data02_gi[7:4] + 25 * data02_gi[3:0];
    // assign gray[3] = 77 * data10_gi[11:8] + 154 * data10_gi[7:4] + 25 * data10_gi[3:0];
    // assign gray[4] = 77 * data11_gi[11:8] + 154 * data11_gi[7:4] + 25 * data11_gi[3:0];
    // assign gray[5] = 77 * data12_gi[11:8] + 154 * data12_gi[7:4] + 25 * data12_gi[3:0];
    // assign gray[6] = 77 * data20_gi[11:8] + 154 * data20_gi[7:4] + 25 * data20_gi[3:0];
    // assign gray[7] = 77 * data21_gi[11:8] + 154 * data21_gi[7:4] + 25 * data21_gi[3:0];
    // assign gray[8] = 77 * data22_gi[11:8] + 154 * data22_gi[7:4] + 25 * data22_gi[3:0];

    assign data_go = {gray[11:8], gray[11:8], gray[11:8]};
    // assign data01_go = {gray[1][11:8], gray[1][11:8], gray[1][11:8]};
    // assign data02_go = {gray[2][11:8], gray[2][11:8], gray[2][11:8]};
    // assign data10_go = {gray[3][11:8], gray[3][11:8], gray[3][11:8]};
    // assign data11_go = {gray[4][11:8], gray[4][11:8], gray[4][11:8]};
    // assign data12_go = {gray[5][11:8], gray[5][11:8], gray[5][11:8]};
    // assign data20_go = {gray[6][11:8], gray[6][11:8], gray[6][11:8]};
    // assign data21_go = {gray[7][11:8], gray[7][11:8], gray[7][11:8]};
    // assign data22_go = {gray[8][11:8], gray[8][11:8], gray[8][11:8]};

endmodule
