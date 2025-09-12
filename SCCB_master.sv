`timescale 1ns / 1ps

module SCCB_master (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,        // 400kHz tick
    input  logic [7:0] reg_addr,
    input  logic [7:0] reg_data,
    output logic [7:0] rom_addr,
    output logic       clk_div_en,
    output logic       scl,
    inout  logic       sda
);


    logic sda_reg, sda_next;

    logic [8:0] temp_ip_addr_reg, temp_ip_addr_next;
    logic [8:0] temp_reg_addr_reg, temp_reg_addr_next;
    logic [8:0] temp_reg_data_reg, temp_reg_data_next;
    logic [7:0] rom_addr_reg, rom_addr_next;


    logic [2:0] addcnt_reg, addcnt_next;

    // SCL State
    typedef enum {
        SCL_IDLE,
        SCL_START,
        SCL_HtL,
        SCL_LtL,
        SCL_LtH,
        SCL_HtH,
        SCL_STOP
    } scl_state_e;

    // SDA State
    typedef enum {
        SDA_IDLE,
        SDA_START,
        SDA_IP_ADDR,
        SDA_REG_ADDR,
        SDA_REG_DATA,
        SDA_STOP
    } sda_state_e;

    sda_state_e sda_state, sda_state_next;

    scl_state_e scl_state, scl_state_next;

    logic scl_reg, scl_next;

    logic process_en_reg, process_en_next;
    logic clk_div_en_reg, clk_div_en_next;

    logic sda_drive, sda_drive_next;

    assign sda        = sda_drive ? sda_reg : 1'bz;
    assign rom_addr   = rom_addr_reg;

    assign clk_div_en = clk_div_en_reg;
    assign scl        = scl_reg;


    // SCL State FSM
    always_ff @(posedge clk, posedge reset) begin : SCL_FSM_seq
        if (reset) begin
            scl_state      <= SCL_IDLE;
            scl_reg        <= 1'b1;
            clk_div_en_reg <= 1'b0;
        end else begin
            scl_state      <= scl_state_next;
            scl_reg        <= scl_next;
            clk_div_en_reg <= clk_div_en_next;
        end
    end

    always_comb begin : SCL_FSM_comb
        scl_state_next  = scl_state;
        scl_next        = scl_reg;
        clk_div_en_next = clk_div_en_reg;
        case (scl_state)
            SCL_IDLE: begin
                scl_next        = 1'b1;
                clk_div_en_next = 1'b1;
                if (!sda_reg) begin
                    scl_state_next = SCL_START;
                end
            end

            SCL_START: begin
                if (tick) begin
                    scl_next       = 1'b0;
                    scl_state_next = SCL_HtL;
                end
            end

            SCL_HtL: begin
                if (tick) begin
                    scl_next       = 1'b0;
                    scl_state_next = SCL_LtL;
                end
            end

            SCL_LtL: begin
                if (tick) begin
                    scl_next       = 1'b1;
                    scl_state_next = SCL_LtH;
                end
            end

            SCL_LtH: begin
                if (tick) begin
                    if (sda_state == SDA_STOP) begin
                        scl_next       = 1'b1;
                        scl_state_next = SCL_STOP;
                    end else begin
                        scl_next       = 1'b1;
                        scl_state_next = SCL_HtH;
                    end
                end
            end

            SCL_HtH: begin
                if (tick) begin
                    scl_next       = 1'b0;
                    scl_state_next = SCL_HtL;
                end
            end

            SCL_STOP: begin
                if (tick) begin
                    if (process_en_reg) begin
                        clk_div_en_next = 1'b1;
                    end else begin
                        clk_div_en_next = 1'b0;
                    end
                    scl_next       = 1'b1;
                    scl_state_next = SCL_IDLE;
                end
            end
        endcase
    end




    // SDA State FSM
    always_ff @(posedge clk, posedge reset) begin : SDA_FSM_seq
        if (reset) begin
            sda_state         <= SDA_IDLE;
            sda_reg           <= 1;
            temp_ip_addr_reg  <= 0;
            addcnt_reg        <= 8;
            temp_reg_addr_reg <= 0;
            temp_reg_data_reg <= 0;
            rom_addr_reg      <= 0;
            process_en_reg    <= 0;
            sda_drive         <= 0;
        end else begin
            sda_state         <= sda_state_next;
            sda_reg           <= sda_next;
            temp_ip_addr_reg  <= temp_ip_addr_next;
            addcnt_reg        <= addcnt_next;
            temp_reg_addr_reg <= temp_reg_addr_next;
            temp_reg_data_reg <= temp_reg_data_next;
            rom_addr_reg      <= rom_addr_next;
            process_en_reg    <= process_en_next;
            sda_drive         <= sda_drive_next;
        end
    end

    always_comb begin : SDA_FSM_comb
        sda_next           = sda_reg;
        sda_state_next     = sda_state;
        temp_ip_addr_next  = temp_ip_addr_reg;
        addcnt_next        = addcnt_reg;
        temp_reg_data_next = temp_reg_data_reg;
        temp_reg_addr_next = temp_reg_addr_reg;
        rom_addr_next      = rom_addr_reg;
        process_en_next    = process_en_reg;
        sda_drive_next     = sda_drive;

        case (sda_state)
            SDA_IDLE: begin
                sda_drive_next = 1'b1;
                if (!sda) begin
                    sda_state_next  = SDA_START;
                    process_en_next = 1'b1;
                    sda_next        = 1'b0;
                end
            end

            SDA_START: begin
                sda_next           = 1'b0;
                temp_ip_addr_next  = {8'h42, 1'b0};
                temp_reg_addr_next = {reg_addr, 1'b0};
                temp_reg_data_next = {reg_data, 1'b0};
                if (tick) begin
                    if (!scl_reg) begin
                        sda_state_next = SDA_IP_ADDR;
                    end
                end
            end

            SDA_IP_ADDR: begin
                if (tick && scl_reg) begin
                    sda_next          = temp_ip_addr_reg[addcnt_reg];
                    temp_ip_addr_next = {temp_ip_addr_reg[7:0], 1'b0};
                    if (addcnt_reg > 0) begin
                        addcnt_next = addcnt_reg - 1;
                    end
                end else if (tick && (~scl_reg) && (addcnt_reg == 0)) begin
                    sda_state_next = SDA_REG_ADDR;
                    addcnt_next    = 8;
                end
            end

            SDA_REG_ADDR: begin
                if (tick && scl_reg) begin
                    if (addcnt_reg > 0) begin
                        sda_next           = temp_reg_addr_reg[addcnt_reg];
                        temp_reg_addr_next = {temp_reg_addr_reg[7:0], 1'b0};
                        addcnt_next        = addcnt_reg - 1;
                    end
                end else if (tick && (~scl_reg) && (addcnt_reg == 0)) begin
                    sda_state_next = SDA_REG_DATA;
                    addcnt_next    = 8;
                end
            end

            SDA_REG_DATA: begin
                if (tick && scl_reg) begin
                    if (addcnt_reg > 0) begin
                        sda_next           = temp_reg_data_reg[addcnt_reg];
                        temp_reg_data_next = {temp_reg_data_reg[7:0], 1'b0};
                        addcnt_next        = addcnt_reg - 1;
                    end
                end else if (tick && (~scl_reg) && (addcnt_reg == 0)) begin
                    sda_state_next = SDA_STOP;
                    addcnt_next    = 8;
                end
            end

            SDA_STOP: begin
                if (tick && scl_reg) begin
                    if (rom_addr_reg >= 75) begin
                        process_en_next = 0;
                    end else begin
                        rom_addr_next   = rom_addr_reg + 1;
                        process_en_next = 1;
                    end
                    sda_next = 1'b1;
                    sda_state_next = SDA_IDLE;
                end
            end
        endcase
    end
endmodule
