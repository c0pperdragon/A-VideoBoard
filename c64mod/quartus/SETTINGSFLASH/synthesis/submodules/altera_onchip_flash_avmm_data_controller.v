// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


////////////////////////////////////////////////////////////////////
//
//  ALTERA_ONCHIP_FLASH_AVMM_DATA_CONTROLLER (PARALLEL-to-SERIAL MODE)
//
//  Copyright (C) 1991-2013 Altera Corporation
//  Your use of Altera Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Altera Program License 
//  Subscription Agreement, Altera MegaCore Function License 
//  Agreement, or other applicable license agreement, including, 
//  without limitation, that your use is for the sole purpose of 
//  programming logic devices manufactured by Altera and sold by 
//  Altera or its authorized distributors.  Please refer to the 
//  applicable agreement for further details.
//
////////////////////////////////////////////////////////////////////

// synthesis VERILOG_INPUT_VERSION VERILOG_2001

`timescale 1 ps / 1 ps

module altera_onchip_flash_avmm_data_controller (
    // To/From System
    clock,
    reset_n,
    
    // To/From Flash IP interface
    flash_busy,
    flash_se_pass,
    flash_sp_pass,
    flash_osc,
    flash_drdout,
    flash_xe_ye,
    flash_se,
    flash_arclk,
    flash_arshft,
    flash_drclk,
    flash_drshft,
    flash_drdin,
    flash_nprogram,
    flash_nerase,
    flash_ardin,
        
    // To/From Avalon_MM data slave interface
    avmm_read,
    avmm_write,
    avmm_addr,
    avmm_writedata,
    avmm_burstcount,
    avmm_waitrequest,
    avmm_readdatavalid,
    avmm_readdata,
        
    // To/From Avalon_MM csr slave interface
    csr_control,
    csr_status
);

    parameter READ_AND_WRITE_MODE = 0;
    parameter WRAPPING_BURST_MODE = 0;
    parameter DATA_WIDTH = 32;
    parameter AVMM_DATA_ADDR_WIDTH = 20;
    parameter AVMM_DATA_BURSTCOUNT_WIDTH = 4;
    parameter FLASH_ADDR_WIDTH = 23;
    parameter FLASH_SEQ_READ_DATA_COUNT = 2;    //number of 32-bit data per sequential read
    parameter FLASH_READ_CYCLE_MAX_INDEX = 3;    //period to for each sequential read
    parameter FLASH_ADDR_ALIGNMENT_BITS = 1;     //number of last addr bits for alignment
    parameter FLASH_RESET_CYCLE_MAX_INDEX = 28;    //period that required by flash before back to idle for erase and program operation
    parameter FLASH_BUSY_TIMEOUT_CYCLE_MAX_INDEX = 112; //flash busy timeout period (960ns)
    parameter FLASH_ERASE_TIMEOUT_CYCLE_MAX_INDEX = 40603248; //erase timeout period (350ms)
    parameter FLASH_WRITE_TIMEOUT_CYCLE_MAX_INDEX = 35382; //write timeout period (305us)
    parameter MIN_VALID_ADDR = 1;
    parameter MAX_VALID_ADDR = 1;
    parameter SECTOR1_START_ADDR = 1;
    parameter SECTOR1_END_ADDR = 1;
    parameter SECTOR2_START_ADDR = 1;
    parameter SECTOR2_END_ADDR = 1;
    parameter SECTOR3_START_ADDR = 1;
    parameter SECTOR3_END_ADDR = 1;
    parameter SECTOR4_START_ADDR = 1;
    parameter SECTOR4_END_ADDR = 1;
    parameter SECTOR5_START_ADDR = 1;
    parameter SECTOR5_END_ADDR = 1;
    parameter SECTOR_READ_PROTECTION_MODE = 5'b11111;
    parameter SECTOR1_MAP = 1;
    parameter SECTOR2_MAP = 1;
    parameter SECTOR3_MAP = 1;
    parameter SECTOR4_MAP = 1;
    parameter SECTOR5_MAP = 1;
    parameter ADDR_RANGE1_END_ADDR = 1;
    parameter ADDR_RANGE2_END_ADDR = 1;
    parameter ADDR_RANGE1_OFFSET = 1;
    parameter ADDR_RANGE2_OFFSET = 1;
    parameter ADDR_RANGE3_OFFSET = 1;
    
    localparam [1:0]    ERASE_ST_IDLE = 0,
                        ERASE_ST_PENDING = 1,
                        ERASE_ST_BUSY = 2;

    localparam [1:0]    STATUS_IDLE = 0,
                        STATUS_BUSY_ERASE = 1,
                        STATUS_BUSY_WRITE = 2,
                        STATUS_BUSY_READ = 3;
    
    // State 0~4 is common for both RW and read only mode. State 5~8 is only needed in RW mode.
    localparam [3:0]    OP_STATE_IDLE = 0,
                        OP_STATE_ADDR = 1,
                        OP_STATE_READ_SHIFT = 2,
                        OP_STATE_READ_DATA = 3,
                        OP_STATE_CLEAR = 4,
                        OP_STATE_WRITE = 5,
                        OP_STATE_WAIT_BUSY = 6,
                        OP_STATE_WAIT_DONE = 7,
                        OP_STATE_RESET = 8;

    // To/From System
    input clock;
    input reset_n;
    
    // To/From Flash IP interface
    input flash_busy;
    input flash_se_pass;
    input flash_sp_pass;
    input flash_osc;
    input [DATA_WIDTH-1:0] flash_drdout;
    output flash_xe_ye;
    output flash_se;
    output flash_arclk;
    output flash_arshft;
    output flash_drclk;
    output flash_drshft;
    output flash_drdin;
    output flash_nprogram;
    output flash_nerase;
    output [FLASH_ADDR_WIDTH-1:0] flash_ardin;
        
    // To/From Avalon_MM data slave interface
    input avmm_read;
    input avmm_write;
    input [AVMM_DATA_ADDR_WIDTH-1:0] avmm_addr;
    input [DATA_WIDTH-1:0] avmm_writedata;
    input [AVMM_DATA_BURSTCOUNT_WIDTH-1:0] avmm_burstcount;
    output avmm_waitrequest;
    output avmm_readdatavalid;
    output [DATA_WIDTH-1:0] avmm_readdata;
        
    // To/From Avalon_MM csr slave interface
    input [31:0] csr_control;
    output [9:0] csr_status;

    reg reset_n_reg1;
    reg reset_n_reg2;
    reg flash_busy_reg;
    reg flash_busy_clear_reg;
    reg flash_addr_neg_reg;
    reg flash_drdin_neg_reg;
    reg [DATA_WIDTH-1:0] flash_drdout_neg_reg;
    reg [AVMM_DATA_BURSTCOUNT_WIDTH-1:0] cur_burstcount;
    reg [1:0] csr_status_busy;
    reg csr_status_e_pass;
    reg csr_status_w_pass;
    reg csr_status_r_pass;

    reg [3:0] op_state;
    reg op_wait;
    reg op_r_wait;
    reg op_wait_neg_reg;
    reg op_count_start;
    reg op_w_count_start;
    reg [FLASH_ADDR_WIDTH-1:0] op_addr;
    reg op_wrap_back_addr;
    reg op_range2_addr;
    reg op_range3_addr;
    reg op_illegal_write_addr;
    reg op_scan_busy;
    
    reg arclk_en;
    reg enable_arclk_neg_reg;
    reg enable_arclk_neg_pos_reg;
    reg enable_drclk_neg_reg;
    reg enable_drclk_neg_pos_reg;

    reg flash_arshft_reg;
    reg flash_arshft_neg_reg;
    reg flash_drshft_reg;
    reg flash_drshft_neg_reg;
    reg avmm_readdatavalid_reg;
    reg avmm_readdatavalid_neg_reg;

    wire reset_n_w;
    wire op_wait_wire;
    wire flash_ardin_w;
    wire flash_drdin_w;
    wire [DATA_WIDTH-1:0] flash_drdout_w;
    
    wire [FLASH_ADDR_WIDTH-1:0] csr_page_erase_addr;
    wire [2:0] csr_sector_erase_addr;
    wire valid_csr_sector_erase_addr;
    wire [1:0] csr_erase_state;
    wire [4:0] csr_write_protection_mode;
    wire valid_csr_erase;
    
    wire [1:0] addr_mux;
    wire [FLASH_ADDR_WIDTH-1:0] cur_addr;
    wire [FLASH_ADDR_WIDTH-1:0] flash_addr_wire;
    wire [FLASH_ADDR_WIDTH-1:0] flash_page_addr_wire;
    wire [2:0] flash_sector_wire;
    wire is_valid_write_burst_count;
    wire is_addr_within_valid_range;
    wire is_addr_writable;
    wire is_busy;
    wire is_busy_erase;
    wire is_busy_write;
    wire is_busy_read;
    wire [4:0] counter_count_wire;
    wire flash_busy_sync;
    wire flash_busy_clear_sync;

    generate
        if (READ_AND_WRITE_MODE == 1) begin
            assign is_busy = (op_state != OP_STATE_IDLE);
            assign is_busy_erase = (csr_status_busy == STATUS_BUSY_ERASE);
            assign is_busy_write = (csr_status_busy == STATUS_BUSY_WRITE);
            assign is_busy_read = (csr_status_busy == STATUS_BUSY_READ);
            assign csr_status = { SECTOR_READ_PROTECTION_MODE[4:0], csr_status_e_pass, csr_status_w_pass, csr_status_r_pass, csr_status_busy};
            assign csr_page_erase_addr = { {(3){1'b0}}, csr_control[19:0] };
            assign csr_sector_erase_addr = csr_control[22:20];
            assign csr_erase_state = csr_control[31:30];
            assign csr_write_protection_mode = csr_control[27:23];
            assign valid_csr_sector_erase_addr = (csr_sector_erase_addr != {(3){1'b1}});
            assign valid_csr_erase = (csr_erase_state == ERASE_ST_PENDING);

            assign addr_mux = { valid_csr_erase, valid_csr_sector_erase_addr };

            assign cur_addr = 
                (addr_mux == 2'b11) ? csr_sector_erase_addr :
                (addr_mux == 2'b10) ? csr_page_erase_addr   :
                avmm_addr ;

            assign flash_addr_wire = 
                (op_wrap_back_addr == 1'b1) ? ADDR_RANGE1_OFFSET[FLASH_ADDR_WIDTH-1:0] :
                (op_range2_addr == 1'b1) ? ADDR_RANGE1_END_ADDR[FLASH_ADDR_WIDTH-1:0] + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1} + ADDR_RANGE2_OFFSET[FLASH_ADDR_WIDTH-1:0]:
                (op_range3_addr == 1'b1) ? ADDR_RANGE2_END_ADDR[FLASH_ADDR_WIDTH-1:0] + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1} + ADDR_RANGE3_OFFSET[FLASH_ADDR_WIDTH-1:0]:
                (addr_mux == 2'b11) ? { flash_sector_wire, 1'b0, {(19){1'b1}} } : 
                flash_page_addr_wire;

            assign flash_drdin = flash_drdin_neg_reg;
            assign flash_nerase = ~(is_busy_erase && (op_state == OP_STATE_WAIT_BUSY || op_state == OP_STATE_WAIT_DONE));
            assign flash_nprogram = ~(is_busy_write && (op_state == OP_STATE_WAIT_BUSY || op_state == OP_STATE_WAIT_DONE));
            assign is_valid_write_burst_count = (avmm_burstcount == 1);
        end
        else begin
            
            assign is_busy = (op_state != OP_STATE_IDLE);
            assign is_busy_read = is_busy;
            assign csr_status = 10'b0000000000;
            assign cur_addr = avmm_addr;
            assign flash_addr_wire = 
                (op_wrap_back_addr == 1'b1) ? ADDR_RANGE1_OFFSET[FLASH_ADDR_WIDTH-1:0] :
                (op_range2_addr == 1'b1) ? ADDR_RANGE1_END_ADDR[FLASH_ADDR_WIDTH-1:0] + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1} + ADDR_RANGE2_OFFSET[FLASH_ADDR_WIDTH-1:0]:
                (op_range3_addr == 1'b1) ? ADDR_RANGE2_END_ADDR[FLASH_ADDR_WIDTH-1:0] + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1} + ADDR_RANGE3_OFFSET[FLASH_ADDR_WIDTH-1:0]:
                flash_page_addr_wire;
            assign flash_drdin = 1'b1;
            assign flash_nerase = 1'b1;
            assign flash_nprogram = 1'b1;
        end
    endgenerate
    
    assign op_wait_wire = (op_wait || op_wait_neg_reg);

    assign avmm_waitrequest = (~reset_n || (((op_state == OP_STATE_IDLE || op_state == OP_STATE_RESET || op_wait_wire) || op_r_wait) && (avmm_write || avmm_read)));
    assign avmm_readdatavalid = avmm_readdatavalid_neg_reg;
    assign avmm_readdata = (csr_status_r_pass) ? flash_drdout_neg_reg : 32'hffffffff;

    assign flash_arshft = flash_arshft_neg_reg;
    assign flash_drshft = flash_drshft_neg_reg;
    assign flash_arclk = (~enable_arclk_neg_reg || clock || enable_arclk_neg_pos_reg);
    assign flash_drclk = (~enable_drclk_neg_reg || clock || enable_drclk_neg_pos_reg);
    assign flash_ardin = { {(FLASH_ADDR_WIDTH-1){1'b1}}, flash_addr_neg_reg};
    assign flash_xe_ye = 1'b0;
    assign flash_se = 1'b0;
        
    // avoid async reset removal issue 
    assign reset_n_w = reset_n_reg2;

    // initial register
    initial begin
        reset_n_reg1 = 0;
        reset_n_reg2 = 0;
        csr_status_busy = STATUS_IDLE;
        csr_status_e_pass = 0;
        csr_status_w_pass = 0;
        csr_status_r_pass = 0;
        flash_busy_reg = 0;
        flash_busy_clear_reg = 0;
        flash_addr_neg_reg = 0;
        flash_drdin_neg_reg = 0;
        flash_drdout_neg_reg = 0;
        flash_arshft_reg = 1;
        flash_arshft_neg_reg = 1;
        flash_drshft_reg = 1;
        flash_drshft_neg_reg = 1;
        avmm_readdatavalid_reg = 0;
        avmm_readdatavalid_neg_reg = 0;
        cur_burstcount = 0;
        op_state = OP_STATE_IDLE;
        op_wait = 0;
        op_r_wait = 0;
        op_wait_neg_reg = 0;
        op_count_start = 0;
        op_w_count_start = 0;
        op_addr = 0;
        op_wrap_back_addr = 0;
        op_range2_addr = 0;
        op_range3_addr = 0;
        op_illegal_write_addr = 0;
        op_scan_busy = 0;
        arclk_en = 0;
        enable_arclk_neg_reg = 0;
        enable_arclk_neg_pos_reg = 0;
        enable_drclk_neg_reg = 0;
        enable_drclk_neg_pos_reg = 0;
    end
    
    // -------------------------------------------------------------------
    // Avoid async reset removal issue 
    // -------------------------------------------------------------------
    always @ (negedge reset_n or posedge clock) begin
        if (~reset_n) begin
            {reset_n_reg2, reset_n_reg1} <= 2'b0;
        end
        else begin
            {reset_n_reg2, reset_n_reg1} <= {reset_n_reg1, 1'b1};
        end
    end

    // -------------------------------------------------------------------
    // Get rid of the race condition between different dynamic clock. Trigger clock enable in early half cycle.
    // -------------------------------------------------------------------
    always @ (negedge clock) begin
        if (~reset_n_w) begin
            enable_arclk_neg_reg <= 0;
            enable_drclk_neg_reg <= 0;
            flash_addr_neg_reg <= 0;
            flash_drdin_neg_reg <= 0;
            flash_arshft_neg_reg <= 1;
            flash_drshft_neg_reg <= 1;
            flash_drdout_neg_reg <= 0;
            avmm_readdatavalid_neg_reg <= 0;
            op_wait_neg_reg <= 0;
        end
        else begin
            enable_arclk_neg_reg <= arclk_en;
            enable_drclk_neg_reg <= ((op_state == OP_STATE_WRITE) || (op_state == OP_STATE_READ_SHIFT) || (op_state == OP_STATE_READ_DATA));
            flash_addr_neg_reg <= flash_ardin_w;
            flash_drdin_neg_reg <= flash_drdin_w;
            flash_arshft_neg_reg <= flash_arshft_reg;
            flash_drshft_neg_reg <= flash_drshft_reg;
            flash_drdout_neg_reg <= flash_drdout_w;
            avmm_readdatavalid_neg_reg <= avmm_readdatavalid_reg;
            op_wait_neg_reg <= op_wait;
        end
    end

    // -------------------------------------------------------------------
    // Avalon_MM data interface fsm - communicate between Avalon_MM and Flash IP
    // -------------------------------------------------------------------        
    generate // generate always block based on read and write mode. Write and erase operation is unnecessary in read only mode.

        if (READ_AND_WRITE_MODE == 1) begin

            // -------------------------------------------------------------------
            // Monitor and store flash busy signal, it may faster then the clock
            // -------------------------------------------------------------------
            always @ (negedge reset_n or negedge op_scan_busy  or posedge flash_osc) begin
                if (~reset_n || ~op_scan_busy) begin
                    flash_busy_reg <= 0;
                    flash_busy_clear_reg <= 0;
                end
                else if (flash_busy_reg) begin                    
                    flash_busy_reg <= flash_busy_reg;
                    flash_busy_clear_reg <= ~flash_busy;
                end
                else begin
                    flash_busy_reg <= flash_busy;
                    flash_busy_clear_reg <= 0;
                end
            end

            altera_std_synchronizer #(
                .depth (2)
            ) stdsync_1 ( 
                .clk(clock), // clock
                .din(flash_busy_reg), // busy signal
                .dout(flash_busy_sync), // busy signal which reg to clock
                .reset_n(reset_n) // active low reset
            );

            altera_std_synchronizer #(
                .depth (2)
            ) stdsync_2 ( 
                .clk(clock), // clock
                .din(flash_busy_clear_reg), // busy signal
                .dout(flash_busy_clear_sync), // busy signal which reg to clock
                .reset_n(reset_n) // active low reset
            );
        
            // -------------------------------------------------------------------
            // FSM for write, erase and read operation
            // -------------------------------------------------------------------        
        
            always @ (posedge clock) begin
                if (~reset_n_w) begin
                    op_state <= OP_STATE_IDLE;
                    csr_status_w_pass <= 0;
                    csr_status_e_pass <= 0;
                    csr_status_r_pass <= 0;
                    op_r_wait <= 0;
                end
                else begin
                    case (op_state)
                        OP_STATE_IDLE: begin
                            // reset all register
                            flash_drshft_reg <= 1;
                            op_count_start <= 1;
                            op_w_count_start <= 0;
                            arclk_en <= 0;
                            enable_arclk_neg_pos_reg <= 0;
                            enable_drclk_neg_pos_reg <= 0;
                            op_wait <= 0;
                            op_addr <= 0;
                            op_wrap_back_addr <= 0;
                            op_range2_addr <= 0;
                            op_scan_busy <= 0;
                            
                            // wait command
                            if (valid_csr_erase) begin
                                csr_status_busy <= STATUS_BUSY_ERASE;
                                op_wait <= 1;
                                if (is_addr_writable) begin
                                    op_state <= OP_STATE_ADDR;
                                end
                                else begin
                                    op_state <= OP_STATE_RESET;
                                    csr_status_e_pass <= 0;
                                end
                            end
                            else if (avmm_write) begin
                                csr_status_busy <= STATUS_BUSY_WRITE;
                                op_r_wait <= 0;
                                op_wait <= 1;
                                if (is_addr_writable && is_valid_write_burst_count) begin
                                    op_state <= OP_STATE_ADDR;
                                end
                                else begin
                                    op_state <= OP_STATE_RESET;
                                    csr_status_w_pass <= 0;
                                end
                            end
                            else if (avmm_read) begin
                                csr_status_busy <= STATUS_BUSY_READ;
                                op_state <= OP_STATE_ADDR;
                                op_r_wait <= 0;
                                op_wait <= 1;
                                op_addr <= avmm_addr;
                                cur_burstcount <= avmm_burstcount;
                                if (is_addr_within_valid_range) begin
                                    csr_status_r_pass <= 1;
                                end
                                else begin
                                    csr_status_r_pass <= 0;
                                end
                            end
                            else begin
                                csr_status_busy <= STATUS_IDLE;
                                op_count_start <= 0;
                            end
                        end

                        OP_STATE_ADDR: begin
                            op_count_start <= 0;
                            avmm_readdatavalid_reg <= 0;
                            if (counter_count_wire == (FLASH_ADDR_WIDTH-1)) begin
                                enable_arclk_neg_pos_reg <= 1;
                                arclk_en <= 0;
                                op_count_start <= 1;
                                case (csr_status_busy)
                                    STATUS_BUSY_ERASE: begin
                                        op_count_start <= 1;
                                        op_scan_busy <= 1;
                                        op_state <= OP_STATE_WAIT_BUSY;
                                    end
                                    STATUS_BUSY_WRITE: begin
                                        op_w_count_start <= 1;
                                        op_state <= OP_STATE_WRITE;
                                    end
                                    default: begin
                                        op_wait <= 0;
                                        flash_drshft_reg <= 0;
                                        op_state <= OP_STATE_READ_SHIFT;
                                    end
                                endcase
                            end
                            else begin
                                arclk_en <= 1;
                            end
                        end

                        OP_STATE_WRITE: begin
                            op_count_start <= 0;
                            op_w_count_start <= 0;
                            enable_arclk_neg_pos_reg <= 0;
                            if (counter_count_wire == (DATA_WIDTH-1)) begin
                                enable_drclk_neg_pos_reg <= 1;
                                op_count_start <= 1;
                                op_wait <= 0;
                                op_scan_busy <= 1;
                                op_state <= OP_STATE_WAIT_BUSY;
                            end
                        end    

                        OP_STATE_READ_SHIFT: begin
                            avmm_readdatavalid_reg <= 0;
                            flash_drshft_reg <= 1;
                            enable_arclk_neg_pos_reg <= 0;
                            op_count_start <= 1;
                            op_r_wait <= 1;
                            op_state <= OP_STATE_READ_DATA;
                            
                            if (cur_burstcount > 1) begin
                                if (op_addr == MAX_VALID_ADDR) begin
                                    op_addr <= MIN_VALID_ADDR[FLASH_ADDR_WIDTH-1:0];
                                    op_wrap_back_addr <= 1;
                                end
                                else if (op_addr == ADDR_RANGE1_END_ADDR[FLASH_ADDR_WIDTH-1:0] && ADDR_RANGE2_OFFSET != 0) begin
                                    op_addr <= op_addr + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1};
                                    op_range2_addr <= 1;
                                end
                                else if (op_addr == ADDR_RANGE2_END_ADDR[FLASH_ADDR_WIDTH-1:0] && ADDR_RANGE3_OFFSET != 0) begin
                                    op_addr <= op_addr + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1};
                                    op_range3_addr <= 1;
                                end
                                else begin
                                    flash_arshft_reg <= 0;
                                    arclk_en <= 1;
                                    op_addr <= op_addr + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1};
                                    op_wrap_back_addr <= 0;
                                    op_range2_addr <= 0;
                                    op_range3_addr <= 0;
                                end
                            end
                        end

                        OP_STATE_READ_DATA: begin
                            op_count_start <= 0;
                            enable_arclk_neg_pos_reg <= 1;
                            flash_arshft_reg <= 1;
                            arclk_en <= 0;

                            if (counter_count_wire == 30) begin
                                avmm_readdatavalid_reg <= 1;
                                enable_arclk_neg_pos_reg <= 0;
                                
                                if (cur_burstcount == 1) begin
                                    enable_drclk_neg_pos_reg <= 1;
                                    op_state <= OP_STATE_CLEAR;
                                end
                                else if (op_wrap_back_addr || op_range2_addr) begin
                                    op_count_start <= 1;
                                    op_state <= OP_STATE_ADDR;
                                end
                                else begin
                                    flash_drshft_reg <= 0;
                                    op_state <= OP_STATE_READ_SHIFT;
                                end
                                
                                cur_burstcount <= cur_burstcount - {{(AVMM_DATA_BURSTCOUNT_WIDTH-1){1'b0}}, 1'b1};
                            end
                        end
                        
                        OP_STATE_WAIT_BUSY: begin
                            op_r_wait <= 1;
                            op_count_start <= 0;
                            if (flash_busy_sync) begin
                                op_count_start <= 1;
                                op_state <= OP_STATE_WAIT_DONE;
                            end
                            else begin
                                if (counter_count_wire == FLASH_BUSY_TIMEOUT_CYCLE_MAX_INDEX) begin
                                    op_count_start <= 1;
                                    op_state <= OP_STATE_RESET;
                                    if (is_busy_write)
                                        csr_status_w_pass <= 0;
                                    else
                                        csr_status_e_pass <= 0;
                                end
                            end
                        end
                        
                        OP_STATE_WAIT_DONE: begin
                            op_count_start <= 0;
                            if (flash_busy_clear_sync) begin
                                op_wait <= 1;
                                op_count_start <= 1;
                                op_state <= OP_STATE_RESET;
                                if (is_busy_write)
                                    csr_status_w_pass <= flash_sp_pass;
                                else
                                    csr_status_e_pass <= flash_se_pass;
                            end
                            else begin
                                if ((is_busy_erase && counter_count_wire == FLASH_ERASE_TIMEOUT_CYCLE_MAX_INDEX) ||
                                    (is_busy_write && counter_count_wire == FLASH_WRITE_TIMEOUT_CYCLE_MAX_INDEX)) begin
                                    op_wait <= 1;
                                    op_count_start <= 1;
                                    op_state <= OP_STATE_RESET;
                                    if (is_busy_write)
                                        csr_status_w_pass <= 0;
                                    else
                                        csr_status_e_pass <= 0;
                                end
                            end
                        end

                        OP_STATE_RESET: begin
                            op_scan_busy <= 0;
                            op_count_start <= 0;
                            if (counter_count_wire == FLASH_RESET_CYCLE_MAX_INDEX) begin
                                op_wait <= 0;
                                op_state <= OP_STATE_CLEAR;
                            end
                        end

                        OP_STATE_CLEAR: begin
                            avmm_readdatavalid_reg <= 0;
                            if (~avmm_write && ~avmm_read) begin
                                op_r_wait <= 0;
                            end
                            op_state <= OP_STATE_IDLE;
                        end
                        
                        default: begin
                            op_state <= OP_STATE_IDLE;
                        end
                        
                    endcase
                end
            end
        end
        else begin
        
            // -------------------------------------------------------------------
            // FSM for read only operation. It is the simplify version of erase/write/read FSM
            // -------------------------------------------------------------------                
        
            always @ (posedge clock) begin
                if (~reset_n_w) begin
                    op_state <= OP_STATE_IDLE;
                    csr_status_r_pass <= 0;
                    op_r_wait <= 0;
                end
                else begin
                    case (op_state)
                        OP_STATE_IDLE: begin
                            // reset all register
                            op_count_start <= 1;
                            arclk_en <= 0;
                            enable_arclk_neg_pos_reg <= 0;
                            enable_drclk_neg_pos_reg <= 0;
                            op_wait <= 0;
                            op_addr <= 0;
                            op_wrap_back_addr <= 0;
                            op_range2_addr <= 0;
                            cur_burstcount <= 0;
                            
                            // wait command
                            if (avmm_read) begin
                                op_state <= OP_STATE_ADDR;
                                op_r_wait <= 0;
                                op_wait <= 1;
                                op_addr <= avmm_addr;
                                cur_burstcount <= avmm_burstcount;
                                if (is_addr_within_valid_range) begin
                                    csr_status_r_pass <= 1;
                                end
                                else begin
                                    csr_status_r_pass <= 0;
                                end
                            end
                            else begin
                                op_count_start <= 0;
                            end
                        end

                        OP_STATE_ADDR: begin
                            op_count_start <= 0;
                            avmm_readdatavalid_reg <= 0;
                            if (counter_count_wire == (FLASH_ADDR_WIDTH-1)) begin
                                flash_drshft_reg <= 0;
                                enable_arclk_neg_pos_reg <= 1;
                                arclk_en <= 0;
                                op_count_start <= 1;
                                op_wait <= 0;
                                op_state <= OP_STATE_READ_SHIFT;
                            end
                            else begin
                                arclk_en <= 1;
                            end
                        end

                        OP_STATE_READ_SHIFT: begin
                            avmm_readdatavalid_reg <= 0;
                            flash_drshft_reg <= 1;
                            enable_arclk_neg_pos_reg <= 0;
                            op_count_start <= 1;
                            op_r_wait <= 1;
                            op_state <= OP_STATE_READ_DATA;
                            
                            if (cur_burstcount > 1) begin
                                if (op_addr == MAX_VALID_ADDR) begin
                                    op_addr <= MIN_VALID_ADDR[FLASH_ADDR_WIDTH-1:0];
                                    op_wrap_back_addr <= 1;
                                end
                                else if (op_addr == ADDR_RANGE1_END_ADDR[FLASH_ADDR_WIDTH-1:0] && ADDR_RANGE2_OFFSET != 0) begin
                                    op_addr <= op_addr + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1};
                                    op_range2_addr <= 1;
                                end
                                else begin
                                    flash_arshft_reg <= 0;
                                    arclk_en <= 1;
                                    op_addr <= op_addr + {{(FLASH_ADDR_WIDTH-1){1'b0}}, 1'b1};
                                    op_wrap_back_addr <= 0;
                                    op_range2_addr <= 0;
                                end
                            end
                        end

                        OP_STATE_READ_DATA: begin
                            op_count_start <= 0;
                            enable_arclk_neg_pos_reg <= 1;
                            flash_arshft_reg <= 1;
                            arclk_en <= 0;

                            if (counter_count_wire == 30) begin
                                avmm_readdatavalid_reg <= 1;
                                enable_arclk_neg_pos_reg <= 0;
                                
                                if (cur_burstcount == 1) begin
                                    enable_drclk_neg_pos_reg <= 1;
                                    op_state <= OP_STATE_CLEAR;
                                end
                                else if (op_wrap_back_addr || op_range2_addr) begin
                                    op_count_start <= 1;
                                    op_state <= OP_STATE_ADDR;
                                end
                                else begin
                                    flash_drshft_reg <= 0;
                                    op_state <= OP_STATE_READ_SHIFT;
                                end
                                
                                cur_burstcount <= cur_burstcount - {{(AVMM_DATA_BURSTCOUNT_WIDTH-1){1'b0}}, 1'b1};
                            end
                        end

                        OP_STATE_CLEAR: begin
                            avmm_readdatavalid_reg <= 0;
                            if (~avmm_read) begin
                                op_r_wait <= 0;
                            end
                            op_state <= OP_STATE_IDLE;
                        end
                        
                        default: begin
                            op_state <= OP_STATE_IDLE;
                        end
                        
                    endcase
                end
            end
        end
        
    endgenerate

    altera_onchip_flash_address_range_check    # (
        .MIN_VALID_ADDR(MIN_VALID_ADDR),
        .MAX_VALID_ADDR(MAX_VALID_ADDR)
    ) address_range_checker (
        .address(cur_addr),
        .is_addr_within_valid_range(is_addr_within_valid_range)
    );

    altera_onchip_flash_convert_address # (
        .ADDR_RANGE1_END_ADDR(ADDR_RANGE1_END_ADDR),
        .ADDR_RANGE2_END_ADDR(ADDR_RANGE2_END_ADDR),
        .ADDR_RANGE1_OFFSET(ADDR_RANGE1_OFFSET),
        .ADDR_RANGE2_OFFSET(ADDR_RANGE2_OFFSET),
        .ADDR_RANGE3_OFFSET(ADDR_RANGE3_OFFSET)
    ) address_convertor (
        .address(cur_addr),
        .flash_addr(flash_page_addr_wire)
    );

    generate // sector address convertsion is unnecessary in read only mode
        if (READ_AND_WRITE_MODE == 1) begin    
            altera_onchip_flash_address_write_protection_check # (
                .SECTOR1_START_ADDR(SECTOR1_START_ADDR),
                .SECTOR1_END_ADDR(SECTOR1_END_ADDR),
                .SECTOR2_START_ADDR(SECTOR2_START_ADDR),
                .SECTOR2_END_ADDR(SECTOR2_END_ADDR),
                .SECTOR3_START_ADDR(SECTOR3_START_ADDR),
                .SECTOR3_END_ADDR(SECTOR3_END_ADDR),
                .SECTOR4_START_ADDR(SECTOR4_START_ADDR),
                .SECTOR4_END_ADDR(SECTOR4_END_ADDR),
                .SECTOR5_START_ADDR(SECTOR5_START_ADDR),
                .SECTOR5_END_ADDR(SECTOR5_END_ADDR),
                .SECTOR_READ_PROTECTION_MODE(SECTOR_READ_PROTECTION_MODE)
            ) address_write_protection_checker (
                .use_sector_addr(valid_csr_erase && valid_csr_sector_erase_addr),
                .address(cur_addr),
                .write_protection_mode(csr_write_protection_mode),
                .is_addr_writable(is_addr_writable)
            );
        
            altera_onchip_flash_convert_sector # (
                .SECTOR1_MAP(SECTOR1_MAP),
                .SECTOR2_MAP(SECTOR2_MAP),
                .SECTOR3_MAP(SECTOR3_MAP),
                .SECTOR4_MAP(SECTOR4_MAP),
                .SECTOR5_MAP(SECTOR5_MAP)
            ) sector_convertor (
                .sector(cur_addr[2:0]),
                .flash_sector(flash_sector_wire)
            );
        end
    endgenerate
    
    altera_onchip_flash_counter share_counter (
        .clock(clock),
        .reset(op_count_start),
        .count(counter_count_wire)
    );
    
    // -------------------------------------------------------------------
    // Instantiate a shift register to send the address to UFM serially (parallel -> serial)
    // -------------------------------------------------------------------
    lpm_shiftreg # (
        .lpm_type ("LPM_SHIFTREG"),
        .lpm_width (FLASH_ADDR_WIDTH),
        .lpm_direction ("LEFT")
    ) ufm_addr_shiftreg (
        .data(flash_addr_wire),
        .clock(clock),
        .enable(op_state == OP_STATE_ADDR),
        .load(op_count_start),
        .shiftout(flash_ardin_w),
        .aclr(~reset_n)
    );

    // -------------------------------------------------------------------
    // Instantiate a shift register to send the data to/from UFM (write: parallel -> serial, read: serial -> parallel)
    // -------------------------------------------------------------------
    lpm_shiftreg # (
        .lpm_type ("LPM_SHIFTREG"),
        .lpm_width (DATA_WIDTH),
        .lpm_direction ("LEFT")
    ) ufm_data_shiftreg (
        .data(avmm_writedata), // write data parallel in
        .shiftin(flash_drdout[0]), // read data serial in
        .clock(clock),
        .enable(op_state == OP_STATE_WRITE || (op_state == OP_STATE_READ_DATA && cur_burstcount > 0)), // during write and read shift
        .load(op_w_count_start), // 1=load (p2s), 0=shift(s2p)
        .shiftout(flash_drdin_w), // write data serial out
        .q(flash_drdout_w), // read data parallel out
        .aclr(~reset_n)
    );
    
endmodule
