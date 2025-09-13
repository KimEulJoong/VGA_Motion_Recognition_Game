`timescale 1ns / 1ps

module tb_BMP ();
    byte bmp_total[640*480*3+54];  // Header + Image
    byte bmp_header[54];
    byte bmp_data[640*480*3];

    int bmp_size, bmp_data_offset, bmp_width, bmp_height, biBitCount;
    string sourceFileName = "Lenna_640x480.bmp";
    string targetFileName = "target_640x480.bmp";

    logic clk;
    logic [9:0] x_pixel;
    logic [9:0] y_pixel;
    logic [9:0] target_x;
    logic [9:0] target_y;

    logic [11:0]
        data00,
        data01,
        data02,
        data10,
        data11,
        data12,
        data20,
        data21,
        data22,
        filter_result;
    logic result;
    logic [23:0] pixel_rgb888;
    logic [11:0] pixel_rgb444;

    // BMP 파일 읽기
    task ReadBMP();
        int fileID, readSize;
        fileID = $fopen(sourceFileName, "rb");
        if (!fileID) begin
            $display("Open %s Error!", sourceFileName);
            $finish;
        end
        readSize = $fread(bmp_total, fileID);
        $fclose(fileID);

        bmp_size = {bmp_total[5], bmp_total[4], bmp_total[3], bmp_total[2]};
        bmp_data_offset = {
            bmp_total[13], bmp_total[12], bmp_total[11], bmp_total[10]
        };
        bmp_width = {
            bmp_total[21], bmp_total[20], bmp_total[19], bmp_total[18]
        };
        bmp_height = {
            bmp_total[25], bmp_total[24], bmp_total[23], bmp_total[22]
        };
        biBitCount = {bmp_total[29], bmp_total[28]};

        if (biBitCount != 24 || bmp_width % 4 != 0) begin
            $display("BMP format not supported");
            $finish;
        end

        // header 복사
        for (int i = 0; i < bmp_data_offset; i++) bmp_header[i] = bmp_total[i];
        // 이미지 데이터 복사
        for (
            int i = bmp_data_offset;
            i < bmp_data_offset + bmp_width * bmp_height * 3;
            i++
        )
            bmp_data[i-bmp_data_offset] = bmp_total[i];
    endtask

    // BMP 파일 쓰기
    task WriteBMP();  // 입력 파라미터 제거하고 직접 bmp_data 사용
        int fileID;
        fileID = $fopen(targetFileName, "wb");

        // 파일 열기 실패 체크
        if (!fileID) begin
            $display("Error: Cannot create %s", targetFileName);
            $finish;
        end

        $display("Writing BMP file: %s", targetFileName);

        // 헤더 쓰기
        for (int i = 0; i < bmp_data_offset; i++) begin
            $fwrite(fileID, "%c", bmp_header[i]);
        end

        // 데이터 쓰기
        for (int i = 0; i < bmp_width * bmp_height * 3; i++) begin
            $fwrite(fileID, "%c", bmp_data[i]);
        end

        $fclose(fileID);
        $display("✅ Write BMP File Done!");
    endtask

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // RGB 변환 모듈
    RGB888_to_RGB444 u_rgb_conv (
        .rgb888_in (pixel_rgb888),
        .rgb444_out(pixel_rgb444)
    );

    // LineBuffer 모듈
    LineBuffer U_LineBuf (
        .clk(clk),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .data(pixel_rgb444),
        .PixelData_00(data00),
        .PixelData_01(data01),
        .PixelData_02(data02),
        .PixelData_10(data10),
        .PixelData_11(data11),
        .PixelData_12(data12),
        .PixelData_20(data20),
        .PixelData_21(data21),
        .PixelData_22(data22)
    );

    Gaussian_Filter U_Gaussian(
        .PixelData_00(data00),
        .PixelData_01(data01),
        .PixelData_02(data02),
        .PixelData_10(data10),
        .PixelData_11(data11),
        .PixelData_12(data12),
        .PixelData_20(data20),
        .PixelData_21(data21),
        .PixelData_22(data22),
        .Gaussian_Result(filter_result)
    );

    //Median_Filter U_Median (
    //    .PixelData_00 (data00),
    //    .PixelData_01 (data01),
    //    .PixelData_02 (data02),
    //    .PixelData_10 (data10),
    //    .PixelData_11 (data11),
    //    .PixelData_12 (data12),
    //    .PixelData_20 (data20),
    //    .PixelData_21 (data21),
    //    .PixelData_22 (data22),
    //    .Median_result(filter_result)
    //);

    //// Sobel 모듈
    //top_sobel_Filter U_Sobel (
    //    .data00(data00),
    //    .data01(data01),
    //    .data02(data02),
    //    .data10(data10),
    //    .data11(data11),
    //    .data12(data12),
    //    .data20(data20),
    //    .data21(data21),
    //    .data22(data22),
    //    .result(result)
    //);

    // 메인 initial 블록만 수정 (타이밍 문제 해결)
    initial begin
        ReadBMP();

        // 초기 2라인 LineBuffer 채우기
        for (int y = 0; y < 2; y++) begin
            for (int x = 0; x < bmp_width; x++) begin
                x_pixel = x;
                y_pixel = y;
                pixel_rgb888 = {
                    bmp_data[(y*bmp_width+x)*3+2],
                    bmp_data[(y*bmp_width+x)*3+1],
                    bmp_data[(y*bmp_width+x)*3+0]
                };
                @(posedge clk);
            end
        end

        // Sobel 적용 (3번째 줄부터)
        for (int y = 2; y < bmp_height; y++) begin
            for (int x = 0; x < bmp_width; x++) begin
                x_pixel = x;
                y_pixel = y;
                pixel_rgb888 = {
                    bmp_data[(y*bmp_width+x)*3+2],
                    bmp_data[(y*bmp_width+x)*3+1],
                    bmp_data[(y*bmp_width+x)*3+0]
                };
                @(posedge clk);  // LineBuffer에 입력

                // *** 핵심 수정: 지연된 위치에 결과 적용 ***
                // 현재 처리되는 결과는 2라인 이전의 픽셀에 해당
                target_y = y - 2;
                target_x = x;

                if (target_y >= 0) begin  // 유효한 위치만 처리
                    // 결과 반영
                    bmp_data[(target_y*bmp_width+target_x)*3+0] = {2{filter_result[3:0]}};
                    bmp_data[(target_y*bmp_width+target_x)*3+1] = {2{filter_result[7:4]}};
                    bmp_data[(target_y*bmp_width+target_x)*3+2] = {2{filter_result[11:8]}};
                end
            end
        end

        // *** 추가: 마지막 2라인 처리***
        for (int y = bmp_height - 2; y < bmp_height; y++) begin
            for (int x = 0; x < bmp_width; x++) begin
                @(posedge clk);  // 추가 클럭으로 남은 데이터 처리

                // 결과 반영
                bmp_data[(y*bmp_width+x)*3+0] = {2{filter_result[3:0]}};
                bmp_data[(y*bmp_width+x)*3+1] = {2{filter_result[7:4]}};
                bmp_data[(y*bmp_width+x)*3+2] = {2{filter_result[11:8]}};

            end
        end

        #1000000;
        WriteBMP();
        $finish;
    end
endmodule


module RGB888_to_RGB444 (
    input  logic [23:0] rgb888_in,  // {R[7:0], G[7:0], B[7:0]}
    output logic [11:0] rgb444_out  // {R[3:0], G[3:0], B[3:0]}
);
    assign rgb444_out = {
        rgb888_in[23:20],  // R[7:4]
        rgb888_in[15:12],  // G[7:4]
        rgb888_in[7:4]
    };  // B[7:4]
endmodule

//module RGB444_to_RGB888 (
//    input  logic [11:0] rgb444_in,
//    output logic [23:0] rgb888_out
//);
//
//    assign rgb888_out = {
//        {2{rgb444_in[11:8]}},  // Red  4bit -> 8bit
//        {2{rgb444_in[7:4]}},  // Green
//        {2{rgb444_in[3:0]}}  // Blue
//    };
//
//endmodule
