`timescale 1ns / 1ps

interface filter_intf;
    //logic        clk;
    logic [11:0] data_00;
    logic [11:0] data_01;
    logic [11:0] data_02;
    logic [11:0] data_10;
    logic [11:0] data_11;
    logic [11:0] data_12;
    logic [11:0] data_20;
    logic [11:0] data_21;
    logic [11:0] data_22;
    logic result;
endinterface

class transaction;
    rand bit [11:0] data_00;
    rand bit [11:0] data_01;
    rand bit [11:0] data_02;
    rand bit [11:0] data_10;
    rand bit [11:0] data_11;
    rand bit [11:0] data_12;
    rand bit [11:0] data_20;
    rand bit [11:0] data_21;
    rand bit [11:0] data_22;
    bit             result;

    // Constraint for reasonable pixel values (0-4095 for 12-bit)
    constraint pixel_range {
        data_00 inside {[0 : 4095]};
        data_01 inside {[0 : 4095]};
        data_02 inside {[0 : 4095]};
        data_10 inside {[0 : 4095]};
        data_11 inside {[0 : 4095]};
        data_12 inside {[0 : 4095]};
        data_20 inside {[0 : 4095]};
        data_21 inside {[0 : 4095]};
        data_22 inside {[0 : 4095]};
    }

    // method
    task print();
        $display("Random data generate!");
        $display("data_00 = %d ", data_00);
        $display("data_01 = %d ", data_01);
        $display("data_02 = %d\n", data_02);
        $display("data_10 = %d ", data_10);
        $display("data_11 = %d ", data_11);
        $display("data_12 = %d\n", data_12);
        $display("data_20 = %d ", data_20);
        $display("data_21 = %d ", data_21);
        $display("data_22 = %d\n", data_22);
    endtask
endclass  //transaction

class generator; // 변수와 함수의 묶음을 클래스로 만듦. C언어의 구조체는 변수만 묶을 수 있음.
    transaction tr;  // 클래스 이름, 클래스 변수
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction

    task run(int run_count);
        repeat (run_count) begin // garbage collection으로 사용하지 않는 메모리를 자동으로 찾아서 제거.
            tr = new(); // instance 실체화 시킴. heap memory영역에 class 자료형을 만듦.
            tr.randomize();  // a, b값의 랜덤 값을 만들어줌.
            tr.print();
            gen2drv_mbox.put(tr);
            #10;
        end
    endtask

endclass  //generator

class driver;
    transaction tr;
    virtual filter_intf filter_if;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual filter_intf filter_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.filter_if = filter_if;
    endfunction  //new()

    task run();
        forever begin
            gen2drv_mbox.get(
                tr); // blocking 모드, mailbox에 값이 없으면 다음 라인으로 넘어가지 않음.
            filter_if.data_00 = tr.data_00;    // transaction 받아온 것을 인터페이스로 보내줌.
            filter_if.data_01 = tr.data_01;
            filter_if.data_02 = tr.data_02;
            filter_if.data_10 = tr.data_10;
            filter_if.data_11 = tr.data_11;
            filter_if.data_12 = tr.data_12;
            filter_if.data_20 = tr.data_20;
            filter_if.data_21 = tr.data_21;
            filter_if.data_22 = tr.data_22;
            //@(posedge filter_if.clk);
        end
    endtask  //run 
endclass

class monitor;
    transaction tr;
    virtual filter_intf filter_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual filter_intf filter_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.filter_if = filter_if;
    endfunction

    task run();
        forever begin
            tr = new();
            //@(posedge filter_if.clk);
            #1;
            tr.data_00 = filter_if.data_00;
            tr.data_01 = filter_if.data_01;
            tr.data_02 = filter_if.data_02;
            tr.data_10 = filter_if.data_10;
            tr.data_11 = filter_if.data_11;
            tr.data_12 = filter_if.data_12;
            tr.data_20 = filter_if.data_20;
            tr.data_21 = filter_if.data_21;
            tr.data_22 = filter_if.data_22;
            #1;  // glitch 때문에 기다림.
            tr.result = filter_if.result;
            mon2scb_mbox.put(tr);
        end
    endtask

endclass

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    bit [11:0]
        data_00_g,
        data_01_g,
        data_02_g,
        data_10_g,
        data_11_g,
        data_12_g,
        data_20_g,
        data_21_g,
        data_22_g;
    bit [15:0]
        data_00,
        data_01,
        data_02,
        data_10,
        data_11,
        data_12,
        data_20,
        data_21,
        data_22,
        data_total_1,
        data_total_1_1,
        data_total_2,
        data_total_2_2;
    bit [16:0] data_total;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction  //new()

    task run();
        //tr = new();
        forever begin
            // gray
            mon2scb_mbox.get(tr);
            data_02_g = 77 *  tr.data_02[11:8] + 154 *  tr.data_02[7:4] + 25 *  tr.data_02[3:0];
            data_12_g = 77 *  tr.data_12[11:8] + 154 *  tr.data_12[7:4] + 25 *  tr.data_12[3:0];
            data_22_g = 77 *  tr.data_22[11:8] + 154 *  tr.data_22[7:4] + 25 *  tr.data_22[3:0];

            data_00_g = 77 *  tr.data_00[11:8] + 154 *  tr.data_00[7:4] + 25 *  tr.data_00[3:0];
            data_10_g = 77 *  tr.data_10[11:8] + 154 *  tr.data_10[7:4] + 25 *  tr.data_10[3:0];
            data_20_g = 77 *  tr.data_20[11:8] + 154 *  tr.data_20[7:4] + 25 *  tr.data_20[3:0];
            // sobel x
            data_02 = {data_02_g[11:8], data_02_g[11:8], data_02_g[11:8]};
            data_12 = {data_12_g[11:8], data_12_g[11:8], data_12_g[11:8]} << 1;
            data_22 = {data_22_g[11:8], data_22_g[11:8], data_22_g[11:8]};

            data_00 = {data_00_g[11:8], data_00_g[11:8], data_00_g[11:8]};
            data_10 = {data_10_g[11:8], data_10_g[11:8], data_10_g[11:8]} << 1;
            data_20 = {data_20_g[11:8], data_20_g[11:8], data_20_g[11:8]};
            data_total_1 = data_02 + data_12 + data_22 - data_00 - data_10 - data_20;
            data_total_1_1 = data_total_1[15] ? (~data_total_1 + 1) : data_total_1;
            //gray 
            data_00_g = 77 *  tr.data_00[11:8] + 154 *  tr.data_00[7:4] + 25 *  tr.data_00[3:0];
            data_01_g = 77 *  tr.data_01[11:8] + 154 *  tr.data_01[7:4] + 25 *  tr.data_01[3:0];
            data_02_g = 77 *  tr.data_02[11:8] + 154 *  tr.data_02[7:4] + 25 *  tr.data_02[3:0];

            data_20_g = 77 *  tr.data_20[11:8] + 154 *  tr.data_20[7:4] + 25 *  tr.data_20[3:0];
            data_21_g = 77 *  tr.data_21[11:8] + 154 *  tr.data_21[7:4] + 25 *  tr.data_21[3:0];
            data_22_g = 77 *  tr.data_22[11:8] + 154 *  tr.data_22[7:4] + 25 *  tr.data_22[3:0];
            // sobel y
            data_00 = {data_00_g[11:8], data_00_g[11:8], data_00_g[11:8]};
            data_01 = {data_01_g[11:8], data_01_g[11:8], data_01_g[11:8]} << 1;
            data_02 = {data_02_g[11:8], data_02_g[11:8], data_02_g[11:8]};

            data_20 = {data_20_g[11:8], data_20_g[11:8], data_20_g[11:8]};
            data_21 = {data_21_g[11:8], data_21_g[11:8], data_21_g[11:8]} << 1;
            data_22 = {data_22_g[11:8], data_22_g[11:8], data_22_g[11:8]};
            data_total_2 = data_00 + data_01 + data_02 - data_20 - data_21 - data_22;
            data_total_2_2 = data_total_2[15] ? (~data_total_2 + 1) : data_total_2;
            data_total = ((data_total_1_1 + data_total_2_2) > 6000) ? 1 : 0;
            if (tr.result == data_total) begin
                $display("PASS! : tr.result = %d , ref.result = %d, absx = %d, absy =  %d", tr.result,
                         data_total, data_total_1_1, data_total_2_2);
            end else begin
                $display("FAIL! : tr.result = %d , ref.result = %d,absx = %d, absy =  %d", tr.result,
                         data_total, data_total_1_1, data_total_2_2);
            end
        end
    endtask  //run
endclass  //scoreboard

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    function new(
        virtual filter_intf filter_if
    );  // virtual은 가상 인터페이스 하드웨어를 소프트웨어처럼 넣음.
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, filter_if);
        mon = new(mon2scb_mbox, filter_if);
        scb = new(mon2scb_mbox);
    endfunction  //new()

    task run(int loop);
        // fork-join : 멀티 프로세서 생성.
        // gen.run과 drv.run이 독립적으로 동작. (always문 두 개처럼)
        fork
            gen.run(loop);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #100 $finish;
    endtask  //run 
endclass

module tb_filter ();
    environment env;  // class
    filter_intf filter_if (); // 인터페이스는 H/W 임. 메모리 공간이 생기는 것이 아니라 하드웨어가 생긴다.

    top_sobel_Filter dut (
        .data00(filter_if.data_00),
        .data01(filter_if.data_01),
        .data02(filter_if.data_02),
        .data10(filter_if.data_10),
        .data11(filter_if.data_11),
        .data12(filter_if.data_12),
        .data20(filter_if.data_20),
        .data21(filter_if.data_21),
        .data22(filter_if.data_22),
        .result(filter_if.result)
    );
    /*
    always #5 filter_if.clk = ~filter_if.clk;

    initial begin
        filter_if.clk = 1;
    end
*/

    initial begin
        env = new(filter_if);
        env.run(100);
    end

endmodule


