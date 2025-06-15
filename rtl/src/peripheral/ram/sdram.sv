//
// sdram.sv
//
// BSD 3-Clause License
// 
// Copyright (c) 2024, Shinobu Hashimoto
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

`default_nettype none

/***********************************************************************
 * SDRAM 制御モジュール
 ***********************************************************************/
module SDRAM #(
    parameter   SDRAM_A_WIDTH       = 11,
    parameter   SDRAM_BA_WIDTH      = 2,
    parameter   SDRAM_COL_WIDTH     = 8,
    parameter   SDRAM_ROW_WIDTH     = 11,
    parameter   SDRAM_DQ_WIDTH      = 32,
    parameter   COUNT               = 2
)(
    input   wire                            CLK,                // 駆動クロック
    input   wire                            RESET_n,            // リセット信号

    output  reg                             READY,              // 初期化完了信号
    RAM_IF.DEVICE                           Ram[0:COUNT-1],     // RAM インターフェース

    //
    input wire [23:0]                       OFFSET[0:COUNT-1],  // アドレスオフセット

    // SDRAM port
    inout  wire                             SDRAM_CLK,
    output  wire                            SDRAM_CKE,
    output  wire                            SDRAM_CS_n,
    output  wire                            SDRAM_RAS_n,
    output  wire                            SDRAM_CAS_n,
    output  wire                            SDRAM_WE_n,
    output  wire    [SDRAM_A_WIDTH-1:0]     SDRAM_A,
    output  wire    [SDRAM_BA_WIDTH-1:0]    SDRAM_BA,
    output  wire    [SDRAM_DQ_WIDTH/8-1:0]  SDRAM_DQM,
    inout   wire    [SDRAM_DQ_WIDTH-1:0]    SDRAM_DQ
);
    localparam OUT_DELAY = 80;

    /***************************************************************
     * SDRAM のモードレジスタ設定定義
     ***************************************************************/
    localparam      MR_WRITE_BURST      = 1'b0;             // write burst(0:enable / 1:disable)
    localparam      MR_CAS_LATENCY      = 3'b010;           // cas latency(010:CL2 / 011:CL3)
    localparam      MR_BURST_TYPE       = 1'b0;             // burst type(0:sequential / 1:interleave)
    localparam      MR_BURST_LENGTH     = 3'b001;           // burst length(000:1word / 001:2word / 010:4word / 011:8word)

    /***************************************************************
     * 初期設定 state
     ***************************************************************/
    reg [5:0] ff_init_state;

    wire w_init_state_pre      = (ff_init_state == 6'd0);
    wire w_init_state_ref1     = (ff_init_state == 6'd8);
    wire w_init_state_ref2     = (ff_init_state == 6'd16);
    wire w_init_state_smr      = (ff_init_state == 6'd24);
    wire w_init_state_complete = (ff_init_state == 6'd32);
    wire w_init_state_halt     = (ff_init_state == 6'd33);

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                ff_init_state <= 0;
        else if(!w_init_state_halt) ff_init_state <= ff_init_state + 1'd1;
    end

    /***************************************************************
     * READY
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                   READY <= 0;
        else if(w_init_state_complete) READY <= 1;
    end

    /***************************************************************
     * main state
     ***************************************************************/
    reg [STATE_COMPLETE:0] ff_main_state;

    localparam  STATE_CHECK      = 0,
                STATE_REF        = 1,
                STATE_ACT        = 1,
                STATE_READ       = 3,
                STATE_WRITE      = 3,
                STATE_WRITE_DQ_0 = 3,
                STATE_WRITE_DQ_1 = 4,
                STATE_FETCH_DQ_0 = 6,
                STATE_FETCH_DQ_1 = 7,
                STATE_DOUT_S     = 8,
                STATE_DOUT_D     = 9,
                STATE_COMPLETE   = 9;

    // main state
    wire w_main_state_check_req    = ff_main_state[STATE_CHECK];
    wire w_main_state_ref          = ff_main_state[STATE_REF];
    wire w_main_state_act          = ff_main_state[STATE_ACT];
    wire w_main_state_read         = ff_main_state[STATE_READ];
    wire w_main_state_write        = ff_main_state[STATE_WRITE];
    wire w_main_state_write_data0  = ff_main_state[STATE_WRITE_DQ_0];
    wire w_main_state_write_data1  = ff_main_state[STATE_WRITE_DQ_1];
    wire w_main_state_fetch_data0  = ff_main_state[STATE_FETCH_DQ_0];
    wire w_main_state_fetch_data1  = ff_main_state[STATE_FETCH_DQ_1];
    wire w_main_state_dout_single  = ff_main_state[STATE_DOUT_S];
    wire w_main_state_dout_double  = ff_main_state[STATE_DOUT_D];
    wire w_main_state_complete     = ff_main_state[STATE_COMPLETE];

    // CMD タイミング
    wire w_cmd_state_act           = w_main_state_act & (ff_is_read | ff_is_write);     // ACT コマンド発行タイミング
    wire w_cmd_state_ref           = w_main_state_ref & ff_is_refresh;                  // REFRESH コマンド発行タイミング
    wire w_cmd_state_read          = w_main_state_read & ff_is_read;                    // READ コマンド発行タイミング
    wire w_cmd_state_write         = w_main_state_write & ff_is_write;                  // WRITE コマンド発行タイミング

    // DQ タイミング
    wire w_dq_state_prep           = w_main_state_act;                                  // DQM,DQ出力データを準備するタイミング
    wire w_dq_state_write_0        = w_main_state_write_data0 && ff_is_write;           // DQM,DQ出力タイミング(1ワード目)
    wire w_dq_state_write_1        = w_main_state_write_data1 && ff_is_write;           // DQM,DQ出力タイミング(2ワード目)
    wire w_dq_state_read_0         = w_main_state_fetch_data0/* synthesis syn_keep=1 */;// DQM,DQ入力タイミング(1ワード目)
    wire w_dq_state_read_1         = w_main_state_fetch_data1/* synthesis syn_keep=1 */;// DQM,DQ入力タイミング(2ワード目)

    // DOUT タイミング
    wire w_dout_state              = (ff_size_32_e | ff_size_32_o) ? w_main_state_dout_double : w_main_state_dout_single;

    //
    wire w_transaction_check    = w_main_state_check_req;
    wire w_transaction_complete = w_main_state_complete;

    /***************************************************************
     * 遷移
     ***************************************************************/
    wire w_loop_progress = !w_main_state_check_req;
    wire w_loop_start = w_start_transaction != 0;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                             ff_main_state <= 1'b1;
        else if(w_init_state_complete)           ff_main_state <= 1'b1;
        else if(w_loop_progress || w_loop_start) ff_main_state <= { ff_main_state[$bits(ff_main_state)-2:0], ff_main_state[$bits(ff_main_state)-1] };
    end

    /***************************************************************
     * パラメータの選択
     ***************************************************************/
    reg                             ff_size_32_e;
    reg                             ff_size_32_o;
    reg                             ff_size_shift_0;
    reg                             ff_size_shift_8;
    reg                             ff_size_shift_16;
    reg                             ff_size_shift_24;
    reg [COUNT-1:0]                 ff_dout_ena;
    reg                             ff_is_read;
    reg                             ff_is_write;
    reg                             ff_is_refresh;
    reg [SDRAM_BA_WIDTH-1:0]        ff_bank;
    reg [SDRAM_ROW_WIDTH-1:0]       ff_row;
    reg [1:0]                       ff_offset;
    reg [9:0]                       ff_col;
    reg [31:0]                      ff_din;
    reg [$bits(Ram[0].DSIZE)-1:0]   ff_dsize;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            ff_dout_ena      <= 0;
            ff_size_32_e     <= 0;
            ff_size_32_o     <= 0;
            ff_size_shift_0  <= 0;
            ff_size_shift_8  <= 0;
            ff_size_shift_16 <= 0;
            ff_size_shift_24 <= 0;
            ff_is_read       <= 0;
            ff_is_write      <= 0;
            ff_is_refresh    <= 0;
            ff_bank          <= 0;
            ff_row           <= 0;
            ff_offset        <= 0;
            ff_col           <= 0;
            ff_din           <= 0;
            ff_dsize         <= 0;
        end
`ifdef COMMENT
        else begin
            for(i = 0; i < COUNT; i = i + 1) begin: start_lp
                if(w_start_transaction[i]) begin
                    ff_dout_ena      <= w_req_read[i] ? (1'b1 << i) : 0;
                    ff_size_32_e     <= (Ram[i].DSIZE == RAM::DSIZE_32_E);
                    ff_size_32_o     <= (Ram[i].DSIZE == RAM::DSIZE_32_O);
                    ff_size_shift_0  <= (w_offset[i] == 2'b00);
                    ff_size_shift_8  <= (w_offset[i] == 2'b01);
                    ff_size_shift_16 <= (w_offset[i] == 2'b10);
                    ff_size_shift_24 <= (w_offset[i] == 2'b11);
                    ff_is_read       <= w_req_read[i];
                    ff_is_write      <= w_req_write[i];
                    ff_is_refresh    <= w_req_refresh[i];
                    ff_bank          <= w_bank[i];
                    ff_row           <= w_row[i];
                    ff_offset        <= w_offset[i];
                    ff_col           <= w_col[i];
                    ff_din           <= Ram[i].DIN;
                    ff_dsize         <= Ram[i].DSIZE;
                    disable start_lp;
                end
            end
        end
`else
        else if(w_start_transaction[0]) begin
            ff_dout_ena      <= w_req_read[0] ? (1'b1 << 0) : 0;
            ff_size_32_e     <= (Ram[0].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[0].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[0] == 2'b00);
            ff_size_shift_8  <= (w_offset[0] == 2'b01);
            ff_size_shift_16 <= (w_offset[0] == 2'b10);
            ff_size_shift_24 <= (w_offset[0] == 2'b11);
            ff_is_read       <= w_req_read[0];
            ff_is_write      <= w_req_write[0];
            ff_is_refresh    <= w_req_refresh[0];
            ff_bank          <= w_bank[0];
            ff_row           <= w_row[0];
            ff_offset        <= w_offset[0];
            ff_col           <= w_col[0];
            ff_din           <= Ram[0].DIN;
            ff_dsize         <= Ram[0].DSIZE;
        end
        else if(COUNT >= 2 && w_start_transaction[1]) begin
            ff_dout_ena      <= w_req_read[1] ? (1'b1 << 1) : 0;
            ff_size_32_e     <= (Ram[1].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[1].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[1] == 2'b00);
            ff_size_shift_8  <= (w_offset[1] == 2'b01);
            ff_size_shift_16 <= (w_offset[1] == 2'b10);
            ff_size_shift_24 <= (w_offset[1] == 2'b11);
            ff_is_read       <= w_req_read[1];
            ff_is_write      <= w_req_write[1];
            ff_is_refresh    <= w_req_refresh[1];
            ff_bank          <= w_bank[1];
            ff_row           <= w_row[1];
            ff_offset        <= w_offset[1];
            ff_col           <= w_col[1];
            ff_din           <= Ram[1].DIN;
            ff_dsize         <= Ram[1].DSIZE;
        end
        else if(COUNT >= 3 && w_start_transaction[2]) begin
            ff_dout_ena      <= w_req_read[2] ? (1'b1 << 2) : 0;
            ff_size_32_e     <= (Ram[2].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[2].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[2] == 2'b00);
            ff_size_shift_8  <= (w_offset[2] == 2'b01);
            ff_size_shift_16 <= (w_offset[2] == 2'b10);
            ff_size_shift_24 <= (w_offset[2] == 2'b11);
            ff_is_read       <= w_req_read[2];
            ff_is_write      <= w_req_write[2];
            ff_is_refresh    <= w_req_refresh[2];
            ff_bank          <= w_bank[2];
            ff_row           <= w_row[2];
            ff_offset        <= w_offset[2];
            ff_col           <= w_col[2];
            ff_din           <= Ram[2].DIN;
            ff_dsize         <= Ram[2].DSIZE;
        end
        else if(COUNT >= 4 && w_start_transaction[3]) begin
            ff_dout_ena      <= w_req_read[3] ? (1'b1 << 3) : 0;
            ff_size_32_e     <= (Ram[3].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[3].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[3] == 2'b00);
            ff_size_shift_8  <= (w_offset[3] == 2'b01);
            ff_size_shift_16 <= (w_offset[3] == 2'b10);
            ff_size_shift_24 <= (w_offset[3] == 2'b11);
            ff_is_read       <= w_req_read[3];
            ff_is_write      <= w_req_write[3];
            ff_is_refresh    <= w_req_refresh[3];
            ff_bank          <= w_bank[3];
            ff_row           <= w_row[3];
            ff_offset        <= w_offset[3];
            ff_col           <= w_col[3];
            ff_din           <= Ram[3].DIN;
            ff_dsize         <= Ram[3].DSIZE;
        end
        else if(COUNT >= 5 && w_start_transaction[4]) begin
            ff_dout_ena      <= w_req_read[4] ? (1'b1 << 4) : 0;
            ff_size_32_e     <= (Ram[4].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[4].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[4] == 2'b00);
            ff_size_shift_8  <= (w_offset[4] == 2'b01);
            ff_size_shift_16 <= (w_offset[4] == 2'b10);
            ff_size_shift_24 <= (w_offset[4] == 2'b11);
            ff_is_read       <= w_req_read[4];
            ff_is_write      <= w_req_write[4];
            ff_is_refresh    <= w_req_refresh[4];
            ff_bank          <= w_bank[4];
            ff_row           <= w_row[4];
            ff_offset        <= w_offset[4];
            ff_col           <= w_col[4];
            ff_din           <= Ram[4].DIN;
            ff_dsize         <= Ram[4].DSIZE;
        end
        else if(COUNT >= 6 && w_start_transaction[5]) begin
            ff_dout_ena      <= w_req_read[5] ? (1'b1 << 5) : 0;
            ff_size_32_e     <= (Ram[5].DSIZE == RAM::DSIZE_32_E);
            ff_size_32_o     <= (Ram[5].DSIZE == RAM::DSIZE_32_O);
            ff_size_shift_0  <= (w_offset[5] == 2'b00);
            ff_size_shift_8  <= (w_offset[5] == 2'b01);
            ff_size_shift_16 <= (w_offset[5] == 2'b10);
            ff_size_shift_24 <= (w_offset[5] == 2'b11);
            ff_is_read       <= w_req_read[5];
            ff_is_write      <= w_req_write[5];
            ff_is_refresh    <= w_req_refresh[5];
            ff_bank          <= w_bank[5];
            ff_row           <= w_row[5];
            ff_offset        <= w_offset[5];
            ff_col           <= w_col[5];
            ff_din           <= Ram[5].DIN;
            ff_dsize         <= Ram[5].DSIZE;
        end
`endif
    end

    /***************************************************************
     * ff_dqm_0 の準備
     ***************************************************************/
    reg [$bits(SDRAM_DQM)-1:0] ff_dqm_0;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            ff_dqm_0 <= 4'b0000;
        end
        else if(w_dq_state_prep) begin
            if(SDRAM_DQ_WIDTH == 32)
            begin
                if(ff_dsize == RAM::DSIZE_32_E)      ff_dqm_0 <= 4'b1010;
                else if(ff_dsize == RAM::DSIZE_32_O) ff_dqm_0 <= 4'b0101;
                else if(ff_dsize == RAM::DSIZE_32)   ff_dqm_0 <= 4'b0000;
                else if(ff_dsize == RAM::DSIZE_16) begin
                    case (ff_offset[1:1])
                        1'd0:       ff_dqm_0 <= 4'b1100;
                        1'd1:       ff_dqm_0 <= 4'b0011;
                    endcase
                end
                else begin
                    case (ff_offset[1:0])
                        2'd0:       ff_dqm_0 <= 4'b1110;
                        2'd1:       ff_dqm_0 <= 4'b1101;
                        2'd2:       ff_dqm_0 <= 4'b1011;
                        2'd3:       ff_dqm_0 <= 4'b0111;
                    endcase
                end
            end else begin
                if(ff_offset[0] == 1'b0) ff_dqm_0 <= 4'b10;
                else                     ff_dqm_0 <= 4'b01;
            end
        end
    end

    /***************************************************************
     * ff_dqm_1 の準備
     ***************************************************************/
    reg [$bits(SDRAM_DQM)-1:0] ff_dqm_1;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            ff_dqm_1 <= 4'b0000;
        end
        else if(w_dq_state_prep) begin
            if(SDRAM_DQ_WIDTH == 32)
            begin
                if(ff_dsize == RAM::DSIZE_32_E)      ff_dqm_1 <= 4'b1010;
                else if(ff_dsize == RAM::DSIZE_32_O) ff_dqm_1 <= 4'b0101;
                else                                 ff_dqm_1 <= 4'b1111;
            end
            else begin
                ff_dqm_1 <= 2'b11;
            end
        end
    end

    /***************************************************************
     * ff_dq_out_0 の準備
     ***************************************************************/
    reg [31:0] ff_dq_out_0;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            ff_dq_out_0 <= 0;
        end
        else if(w_dq_state_prep) begin
            if(SDRAM_DQ_WIDTH == 32)
            begin
                if(ff_dsize == RAM::DSIZE_32_E) begin
                    ff_dq_out_0 <= { ff_din[15:8], ff_din[15:8], ff_din[ 7:0], ff_din[ 7:0]};
                end
                else if(ff_dsize == RAM::DSIZE_32_O) begin
                    ff_dq_out_0 <= { ff_din[15:8], ff_din[15:8], ff_din[ 7:0], ff_din[ 7:0]};
                end
                else begin
                    case (ff_dsize)
                        default:       ff_dq_out_0 <= { ff_din[ 7:0], ff_din[ 7:0], ff_din[ 7:0], ff_din[ 7:0]};
                        RAM::DSIZE_16: ff_dq_out_0 <= { ff_din[15:0], ff_din[15:0]};
                        RAM::DSIZE_32: ff_dq_out_0 <=   ff_din[31:0];
                    endcase
                end
            end else begin
                ff_dq_out_0 <= { ff_din, ff_din};
            end
        end
    end

    /***************************************************************
     * ff_dq_out_1 の準備
     ***************************************************************/
    reg [31:0] ff_dq_out_1;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            ff_dq_out_1 <= 0;
        end
        else if(w_dq_state_prep) begin
            if(SDRAM_DQ_WIDTH == 32)
            begin
                if(ff_dsize == RAM::DSIZE_32_E) begin
                    ff_dq_out_1 <= { ff_din[31:24], ff_din[31:24], ff_din[23:16], ff_din[23:16]};
                end
                else if(ff_dsize == RAM::DSIZE_32_O) begin
                    ff_dq_out_1 <= { ff_din[31:24], ff_din[31:24], ff_din[23:16], ff_din[23:16]};
                end
            end
        end
    end

    /***************************************************************
     * SDRAM_CLK, SDRAM_CKE の出力
     ***************************************************************/
    wire w_sdclk_o/* synthesis syn_keep=1 */;
    IOBUF u_buf_clk_dq (
        .IO(SDRAM_CLK),
        .I(CLK),
        .O(w_sdclk_o),
        .OEN(1'b0)
    );
    wire w_clk_dq /* synthesis syn_keep=1 */;
    DQCE u_dqce_dq (
        .CLKIN(w_sdclk_o),
        .CE(1'b1),
        .CLKOUT(w_clk_dq)
    );

    assign SDRAM_CKE = 1;

    /***************************************************************
     * SDRAM_CS_n, SDRAM_RAS_n, SDRAM_CAS_n, SDRAM_WE_n の出力
     ***************************************************************/
    reg [3:0] ff_sdram_cmd;
    DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out_cs  (.IN(ff_sdram_cmd[3]), .OUT(SDRAM_CS_n));
    DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out_ras (.IN(ff_sdram_cmd[2]), .OUT(SDRAM_RAS_n));
    DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out_cas (.IN(ff_sdram_cmd[1]), .OUT(SDRAM_CAS_n));
    DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out_we  (.IN(ff_sdram_cmd[0]), .OUT(SDRAM_WE_n));

    localparam      CMD_DIS             = 4'b1111;      // disable
    localparam      CMD_SMR             = 4'b0000;      // set mode register
    localparam      CMD_REF             = 4'b0001;      // auto refresh
    localparam      CMD_PRE             = 4'b0010;      // precharge
    localparam      CMD_ACT             = 4'b0011;      // active
    localparam      CMD_WR              = 4'b0100;      // write
    localparam      CMD_RD              = 4'b0101;      // read
    localparam      CMD_BEND            = 4'b0110;      // burst end
    localparam      CMD_NOP             = 4'b0111;      // no operation

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)               ff_sdram_cmd <= CMD_NOP;
        else if(w_init_state_pre)  ff_sdram_cmd <= CMD_PRE;
        else if(w_init_state_ref1) ff_sdram_cmd <= CMD_REF;
        else if(w_init_state_ref2) ff_sdram_cmd <= CMD_REF;
        else if(w_init_state_smr)  ff_sdram_cmd <= CMD_SMR;
        else if(w_cmd_state_act)   ff_sdram_cmd <= CMD_ACT;
        else if(w_cmd_state_ref)   ff_sdram_cmd <= CMD_REF;
        else if(w_cmd_state_read)  ff_sdram_cmd <= CMD_RD;
        else if(w_cmd_state_write) ff_sdram_cmd <= CMD_WR;
        else                       ff_sdram_cmd <= CMD_NOP;
    end

    /***************************************************************
     * SDRAM_BA の出力
     ***************************************************************/
    reg [SDRAM_BA_WIDTH-1:0] ff_sdram_ba;

    generate
        genvar ba_bit;
        for(ba_bit = 0; ba_bit < $bits(SDRAM_BA); ba_bit = ba_bit + 1) begin: ba_bits
            DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out (.IN(ff_sdram_ba[ba_bit]), .OUT(SDRAM_BA[ba_bit]));
        end
    endgenerate

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                 ff_sdram_ba <= 0;
        //else if(w_init_state_pre)  ff_sdram_ba <= 0;
        //else if(w_init_state_ref1) ff_sdram_ba <= 0;
        //else if(w_init_state_ref2) ff_sdram_ba <= 0;
        //else if(w_init_state_smr)  ff_sdram_ba <= 0;
        else if(w_cmd_state_act)     ff_sdram_ba <= ff_bank;
        //else if(w_cmd_state_ref)   ff_sdram_ba <= 0;
        //else                       ff_sdram_ba <= 0;
    end

    /***************************************************************
     * SDRAM_A の出力
     ***************************************************************/
    reg [$bits(SDRAM_A)-1:0] ff_sdram_a/* synthesis syn_keep=1 */;

    generate
        genvar a_bit;
        for(a_bit = 0; a_bit < $bits(SDRAM_A); a_bit = a_bit + 1) begin: a_bits
            DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out (.IN(ff_sdram_a[a_bit]), .OUT(SDRAM_A[a_bit]));
        end
    endgenerate

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                 ff_sdram_a <= 0;
        //else if(w_init_state_pre)  ff_sdram_a <= { 1'b1, 10'b0000000000 };
        //else if(w_init_state_ref1) ff_sdram_a <= { 1'b1, 10'b0000000000 };
        //else if(w_init_state_ref2) ff_sdram_a <= { 1'b1, 10'b0000000000 };
        else if(w_init_state_smr)    ff_sdram_a <= { 1'b0, MR_WRITE_BURST, 2'b00, MR_CAS_LATENCY, MR_BURST_TYPE, MR_BURST_LENGTH};
        else if(w_cmd_state_act)     ff_sdram_a <= ff_row;
        //else if(w_cmd_state_ref)   ff_sdram_a <= { 1'b1, 10'b0000000000 };
        else if(w_cmd_state_read)    ff_sdram_a <= { 1'b1, ff_col };
        else if(w_cmd_state_write)   ff_sdram_a <= { 1'b1, ff_col };
        else                         ff_sdram_a <= { 1'b1, 10'b0000000000 };
    end

    /***************************************************************
     * SDRAM_DQM の出力
     ***************************************************************/
    reg [$bits(SDRAM_DQM)-1:0] ff_sdram_dqm;

    generate
        genvar dqm_bit;
        for(dqm_bit = 0; dqm_bit < $bits(SDRAM_DQM); dqm_bit = dqm_bit + 1) begin: dqm_bits
            DELAY_OUT #( .DELAY(OUT_DELAY) ) u_out (.IN(ff_sdram_dqm[dqm_bit]), .OUT(SDRAM_DQM[dqm_bit]));
        end
    endgenerate

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                ff_sdram_dqm <= 4'b0000;
        else if(w_dq_state_write_0) ff_sdram_dqm <= ff_dqm_0;
        else if(w_dq_state_write_1) ff_sdram_dqm <= ff_dqm_1;
        else                        ff_sdram_dqm <= 4'b0000;
    end

    /***************************************************************
     * SDRAM_DQ の入出力
     ***************************************************************/
    wire [31:0] w_dq_in;
    wire [31:0] w_dq_in0;
    wire [31:0] w_dq_in1;
    generate
        genvar dq_bit;
        for(dq_bit = 0; dq_bit < 32; dq_bit = dq_bit + 1) begin: dq_bits
            DELAY_IO #(.DELAY(OUT_DELAY)) u_io (.CLK, .IN(ff_sdram_dq_out[dq_bit]), .OE(w_dq_state_write_0 | w_dq_state_write_1), .OUT(w_dq_in[dq_bit]), .IO(SDRAM_DQ[dq_bit]));
            FETCH u_fetch_0 (.CLK, .CLK_PS(w_clk_dq), .CE(w_dq_state_read_0), .IN(w_dq_in[dq_bit]), .OUT(w_dq_in0[dq_bit]));
            FETCH u_fetch_1 (.CLK, .CLK_PS(w_clk_dq), .CE(w_dq_state_read_1), .IN(w_dq_in[dq_bit]), .OUT(w_dq_in1[dq_bit]));
        end
    endgenerate

    /*
     * DQ 出力データ
     */
    reg [31:0] ff_sdram_dq_out/* synthesis syn_keep=1 */;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                ff_sdram_dq_out <= 0;
        else if(w_dq_state_write_0) ff_sdram_dq_out <= ff_dq_out_0;
        else if(w_dq_state_write_1) ff_sdram_dq_out <= ff_dq_out_1;
    end

    /*
     * データ変換
     */
    wire [31:0] w_dout_e  = {w_dq_in1[23:16], w_dq_in1[ 7:0], w_dq_in0[23:16], w_dq_in0[ 7:0]};
    wire [31:0] w_dout_o  = {w_dq_in1[31:24], w_dq_in1[15:8], w_dq_in0[31:24], w_dq_in0[15:8]};
    wire [31:0] w_dout_0  = w_dq_in0[31: 0];
    wire [31:0] w_dout_8  = { 8'h00,      w_dq_in0[31: 8] };
    wire [31:0] w_dout_16 = { 16'h00,     w_dq_in0[31:16] };
    wire [31:0] w_dout_24 = { 24'h00,     w_dq_in0[31:24] };
//    reg [31:0] ff_dout_e;
//    reg [31:0] ff_dout_o;
//    reg [31:0] ff_dout_0;
//    reg [31:0] ff_dout_8;
//    reg [31:0] ff_dout_16;
//    reg [31:0] ff_dout_24;
//    always_ff @(posedge CLK) ff_dout_e  <= w_dout_e;
//    always_ff @(posedge CLK) ff_dout_o  <= w_dout_o;
//    always_ff @(posedge CLK) ff_dout_0  <= w_dout_0;
//    always_ff @(posedge CLK) ff_dout_8  <= w_dout_8;
//    always_ff @(posedge CLK) ff_dout_16 <= w_dout_16;
//    always_ff @(posedge CLK) ff_dout_24 <= w_dout_24;

    /***************************************************************
     * Ram[n] チェック
     ***************************************************************/
    localparam ADDR8_BIT_WIDTH = $bits(Ram[0].ADDR);
    localparam ADDR16_BIT_WIDTH = (ADDR8_BIT_WIDTH - 1);
    localparam ADDR32_BIT_WIDTH = (ADDR16_BIT_WIDTH - 1);
    wire [1:0]                  w_offset[0:COUNT-1];        // offset
    wire [9:0]                  w_col[0:COUNT-1];           // col
    wire [SDRAM_ROW_WIDTH-1:0]  w_row[0:COUNT-1];           // row 
    wire [SDRAM_BA_WIDTH-1:0]   w_bank[0:COUNT-1];          // bank
    wire                        w_req_read[0:COUNT-1];      // リード動作要求フラグ
    wire                        w_req_write[0:COUNT-1];     // ライト動作要求フラグ
    wire                        w_req_refresh[0:COUNT-1];   // リフレッシュ動作要求フラグ
    wire [COUNT-1:0]            w_start_transaction;        // 開始フラグ

    generate
        genvar prio;
        wire [COUNT-1:0] w_req_any;
        for(prio = 0; prio < COUNT; prio = prio + 1) begin: sec_update_lp
            /***************************************************************
             * アドレス計算
             ***************************************************************/
            // オフセットを加算
            wire [$bits(Ram[prio].ADDR)-1:0] w_addr = Ram[prio].ADDR + OFFSET[prio];

            // offset
            assign w_offset[prio] = w_addr[1:0];

            // ワードアドレスを計算
            wire [ADDR8_BIT_WIDTH-1:0]  sdram_addr_16 = w_addr[ADDR8_BIT_WIDTH-1:1];
            wire [ADDR8_BIT_WIDTH-1:0]  sdram_addr_32 = (SDRAM_DQ_WIDTH == 32) ? sdram_addr_16[ADDR16_BIT_WIDTH-1:1] : sdram_addr_16;

            // COL, ROW, BANK を計算
            assign w_col[prio]  = sdram_addr_32[                               SDRAM_COL_WIDTH-1 :                               0];
            assign w_row[prio]  = sdram_addr_32[               SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH-1 :                 SDRAM_COL_WIDTH];
            assign w_bank[prio] = sdram_addr_32[SDRAM_BA_WIDTH+SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH-1 : SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH];

            /***************************************************************
             * Ram[n].OE_n チェック
             ***************************************************************/
            // OE_n を 1クロック遅延
            reg ff_oe_n_delay;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n) ff_oe_n_delay <= 1;
                else         ff_oe_n_delay <= Ram[prio].OE_n;
            end

            // 立下りエッジを検出
            wire w_det_req_read = ff_oe_n_delay & ~Ram[prio].OE_n;

            // リード動作が保留されてるかどうか
            reg ff_pending_read;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n)                       ff_pending_read <= 0;
                else if(w_start_transaction[prio]) ff_pending_read <= 0;
                else if(w_det_req_read)            ff_pending_read <= 1;
            end

            assign w_req_read[prio] = ff_pending_read | w_det_req_read;

            /***************************************************************
             * Ram[n].WE_n チェック
             ***************************************************************/
            // WE_n を 1クロック遅延
            reg ff_we_n_delay;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n) ff_we_n_delay <= 1;
                else         ff_we_n_delay <= Ram[prio].WE_n;
            end

            // 立下りエッジを検出
            wire w_det_req_write = ff_we_n_delay & ~Ram[prio].WE_n;

            // ライト動作が保留されてるかどうか
            reg ff_pending_write;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n)                       ff_pending_write <= 0;
                else if(w_start_transaction[prio]) ff_pending_write <= 0;
                else if(w_det_req_write)           ff_pending_write <= 1;
            end

            assign w_req_write[prio] = ff_pending_write | w_det_req_write;

            /***************************************************************
             * Ram[n].RFSH_n チェック
             ***************************************************************/
            // RFSH_n を 1クロック遅延
            reg ff_rfsh_n_delay;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n) ff_rfsh_n_delay <= 1;
                else         ff_rfsh_n_delay <= Ram[prio].RFSH_n;
            end

            // 立下りエッジを検出
            wire w_det_req_refresh = ff_rfsh_n_delay & ~Ram[prio].RFSH_n;

            // リフレッシュ動作が保留されてるかどうか
            reg ff_pending_refresh;
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n)                       ff_pending_refresh <= 0;
                else if(w_start_transaction[prio]) ff_pending_refresh <= 0;
                else if(w_det_req_refresh)         ff_pending_refresh <= 1;
            end

            assign w_req_refresh[prio] = ff_pending_refresh | w_det_req_refresh;

            /***************************************************************
             * 開始フラグ設定
             ***************************************************************/
            assign w_req_any[prio] = w_req_read[prio] | w_req_write[prio] | w_req_refresh[prio];

            if(prio == 0) begin
                assign w_start_transaction[prio] = w_transaction_check & w_req_any[prio];
            end
            else begin
                assign w_start_transaction[prio] = w_transaction_check & w_req_any[prio] & (w_req_any[prio-1:0] == 0);
            end

            /***************************************************************
             * Ram[n].ACK_n 更新
             ***************************************************************/
            reg ff_ack_n;
            assign Ram[prio].ACK_n = ff_ack_n;

            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n)                       ff_ack_n <= 1;
                else if(w_start_transaction[prio]) ff_ack_n <= 0;
                else if(w_transaction_complete)    ff_ack_n <= 1;
            end

            /***************************************************************
             * Ram[n].DOUT 更新
             ***************************************************************/
`ifndef COMMENT
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n) Ram[prio].DOUT <= 0;
                else if(ff_dout_ena[prio] & w_dout_state) begin
                    if(ff_size_32_e)          Ram[prio].DOUT <= w_dout_e;
                    else if(ff_size_32_o)     Ram[prio].DOUT <= w_dout_o;
                    else if(ff_size_shift_0)  Ram[prio].DOUT <= w_dout_0;
                    else if(ff_size_shift_8)  Ram[prio].DOUT <= w_dout_8;
                    else if(ff_size_shift_16) Ram[prio].DOUT <= w_dout_16;
                    else if(ff_size_shift_24) Ram[prio].DOUT <= w_dout_24;
                end
            end
`else
            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n) Ram[prio].DOUT <= 0;
                else if(ff_dout_ena[prio] & w_dout_state) begin
                    if(ff_size_32_e)          Ram[prio].DOUT <= ff_dout_e;
                    else if(ff_size_32_o)     Ram[prio].DOUT <= ff_dout_o;
                    else if(ff_size_shift_0)  Ram[prio].DOUT <= ff_dout_0;
                    else if(ff_size_shift_8)  Ram[prio].DOUT <= ff_dout_8;
                    else if(ff_size_shift_16) Ram[prio].DOUT <= ff_dout_16;
                    else if(ff_size_shift_24) Ram[prio].DOUT <= ff_dout_24;
                end
            end
`endif

            /***************************************************************
             * Ram[n].VALID 更新
             ***************************************************************/
/*
            reg ff_valid;
            assign Ram[prio].VALID = ff_valid;

            always_ff @(posedge CLK or negedge RESET_n)
            begin
                if(!RESET_n)                               ff_valid <= 0;
                else if(w_start_transaction[prio])         ff_valid <= 0;
                else if(ff_dout_ena[prio] ＆ w_dout_state) ff_valid <= 1;
            end
*/

            assign Ram[prio].TIMING = 0;

            /***************************************************************
             * Ram[n].WAIT_n 更新
             ***************************************************************/
            assign Ram[prio].WAIT_n = 1;
        end
    endgenerate

    /***************************************************************
     * 遅延付き GPIO 出力
     ***************************************************************/
    module DELAY_OUT #(
        parameter DELAY=0
    ) (
        input wire IN,
        output wire OUT
    );
        if(DELAY != 0) begin
            wire w_dly;
            IODELAY u_dly (
                .DI(IN),
                .DO(w_dly),
                .DF(),
                .SDTAP(1'b0),
                .SETN(1'b0),
                .VALUE(1'b0)
            );
            defparam u_dly.C_STATIC_DLY=DELAY;
            OBUF u_buf (
                .O(OUT),
                .I(w_dly)
            );
        end
        else begin
            OBUF u_buf (
                .O(OUT),
                .I(IN)
            );
        end
    endmodule

    /***************************************************************
     * 遅延出力付き GPIO 入出力
     ***************************************************************/
    module DELAY_IO #(
        parameter DELAY=0
    ) (
        input wire CLK,
        input wire IN,
        input wire OE,
        output wire OUT,
        inout wire IO
    );
        wire w_oen;
        DFFE u_oen (
            .Q(w_oen),
            .D(~OE),
            .CLK(CLK),
            .CE(1'b1)
        );

        if(DELAY != 0) begin
            wire w_dly;
            IODELAY u_dly (
                .DI(IN),
                .DO(w_dly),
                .DF(),
                .SDTAP(1'b0),
                .SETN(1'b0),
                .VALUE(1'b0)
            );
            defparam u_dly.C_STATIC_DLY=DELAY;
            IOBUF u_buf (
                .IO(IO),
                .I(w_dly),
                .O(OUT),
                .OEN(w_oen)
            );
        end
        else begin
            IOBUF u_buf (
                .IO(IO),
                .I(IN),
                .O(OUT),
                .OEN(w_oen)
            );
        end
    endmodule

    /***************************************************************
     * DQ 取り込み
     ***************************************************************/
    module FETCH (
        input wire CLK,
        input wire CLK_PS,
        input wire CE,
        input wire IN,
        output wire OUT
    ) /* synthesis syn_preserve=1 */;

        wire w_ce_pre;
        DFF u_ce_pre (
            .Q(w_ce_pre),
            .D(CE),
            .CLK(CLK)
        );

        wire w_ce;
        DFF u_ce (
            .Q(w_ce),
            .D(w_ce_pre),
            .CLK(~CLK)
        );

        DFFE u_in (
            .Q(OUT),
            .D(IN),
            .CLK(CLK_PS),
            .CE(w_ce_pre)
        );
    endmodule

endmodule

`default_nettype wire
