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
    parameter   SDRAM_DQ_WIDTH      = 32
)(
    input   wire                            CLK,        // 駆動クロック
    input   wire                            CLK_PS,     // CLK の位相を180°ずらしたクロック
    input   wire                            RESET_n,    // リセット信号

    output  reg                             READY,      // 初期化完了信号
    RAM_IF.DEVICE                           Ram,        // RAM インターフェース

    // SDRAM port
    output  wire                            SDRAM_CLK,
    output  wire                            SDRAM_CKE,
    output  wire                            SDRAM_CS_n,
    output  wire                            SDRAM_RAS_n,
    output  wire                            SDRAM_CAS_n,
    output  wire                            SDRAM_WE_n,
    output  reg     [SDRAM_A_WIDTH-1:0]     SDRAM_A,
    output  reg     [SDRAM_BA_WIDTH-1:0]    SDRAM_BA,
    output  reg     [SDRAM_DQ_WIDTH/8-1:0]  SDRAM_DQM,
    inout   wire    [SDRAM_DQ_WIDTH-1:0]    SDRAM_DQ
);
    localparam      LEVEL_TRIG          = 1;                // OE_n, WE_n, RFSH_n のトリガ条件(0=エッジ/1=レベル)

    /***************************************************************
     * SDRAM のモードレジスタ設定定義
     ***************************************************************/
    localparam      MR_WRITE_BURST      = 1'b0;             // write burst(0:enable / 1:disable)
    localparam      MR_CAS_LATENCY      = 3'b010;           // cas latency(010:CL2 / 011:CL3)
    localparam      MR_BURST_TYPE       = 1'b0;             // burst type(0:sequential / 1:interleave)
    localparam      MR_BURST_LENGTH     = 3'b000;           // burst length(000:1word / 001:2word / 010:4word / 011:8word)

    /***************************************************************
     * SDRAM のコマンド定義
     ***************************************************************/
    localparam      CMD_DIS             = 4'b1111;      // disable
    localparam      CMD_SMR             = 4'b0000;      // set mode register
    localparam      CMD_REF             = 4'b0001;      // auto refresh
    localparam      CMD_PRE             = 4'b0010;      // precharge
    localparam      CMD_ACT             = 4'b0011;      // active
    localparam      CMD_WR              = 4'b0100;      // write
    localparam      CMD_RD              = 4'b0101;      // read
    localparam      CMD_BEND            = 4'b0110;      // burst end
    localparam      CMD_NOP             = 4'b0111;      // no operation

    /***************************************************************
     * SDRAM 制御信号
     ***************************************************************/
    reg     [3:0]                   SDRAM_CMD;
    assign                          SDRAM_CS_n = SDRAM_CMD[3];
    assign                          SDRAM_RAS_n = SDRAM_CMD[2];
    assign                          SDRAM_CAS_n = SDRAM_CMD[1];
    assign                          SDRAM_WE_n = SDRAM_CMD[0];

    localparam      DQ_OUT_ENA_INACTIVE = 1'b1;
    localparam      DQ_OUT_ENA_ACTIVE   = 1'b0;
    reg     [SDRAM_DQ_WIDTH-1:0]    sdram_DQ_OUT;
    reg                             sdram_DQ_OUT_ENA_n;
    assign                          SDRAM_DQ = (sdram_DQ_OUT_ENA_n == DQ_OUT_ENA_ACTIVE) ? sdram_DQ_OUT : ((SDRAM_DQ_WIDTH == 32) ? 32'bZZZZZZZZ_ZZZZZZZZ_ZZZZZZZZ_ZZZZZZZZ : 16'bZZZZZZZZ_ZZZZZZZZ);

    assign                          SDRAM_CLK = CLK_PS;
    assign                          SDRAM_CKE = 1;

    /***************************************************************
     * アドレスを BANK, ROW, COL へ変換
     ***************************************************************/
    localparam ADDR8_BIT_WIDTH = $bits(Ram.ADDR);
    localparam ADDR16_BIT_WIDTH = (ADDR8_BIT_WIDTH - 1);
    localparam ADDR32_BIT_WIDTH = (ADDR16_BIT_WIDTH - 1);
    wire [ADDR8_BIT_WIDTH-1:0]  sdram_addr_16 = Ram.ADDR[ADDR8_BIT_WIDTH-1:1];
    wire [ADDR8_BIT_WIDTH-1:0]  sdram_addr_32 = (SDRAM_DQ_WIDTH == 32) ? sdram_addr_16[ADDR16_BIT_WIDTH-1:1] : sdram_addr_16;
    wire [9:0]                  sdram_col  = sdram_addr_32[                               SDRAM_COL_WIDTH-1 :                               0];
    wire [SDRAM_ROW_WIDTH-1:0]  sdram_row  = sdram_addr_32[               SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH-1 :                 SDRAM_COL_WIDTH];
    wire [SDRAM_BA_WIDTH-1:0]   sdram_bank = sdram_addr_32[SDRAM_BA_WIDTH+SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH-1 : SDRAM_ROW_WIDTH+SDRAM_COL_WIDTH];

    /***************************************************************
     * エッジ検出用
     ***************************************************************/
    logic prev_we_n;
    logic prev_oe_n;
    logic prev_rfsh_n;
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            prev_we_n <= 1;
            prev_oe_n <= 1;
            prev_rfsh_n <= 1;
        end
        else begin
            prev_we_n <= Ram.WE_n;
            prev_oe_n <= Ram.OE_n;
            prev_rfsh_n <= Ram.RFSH_n;
        end
    end

    /***************************************************************
     * 開始条件
     ***************************************************************/
    wire begin_rd;
    wire begin_wr;
    wire begin_rfsh;
    if(LEVEL_TRIG) begin
        assign begin_rd = !Ram.OE_n;
        assign begin_wr = !Ram.WE_n;
        assign begin_rfsh = !Ram.RFSH_n;
    end
    else begin
        assign begin_rd = (prev_oe_n && !Ram.OE_n);
        assign begin_wr = (prev_we_n && !Ram.WE_n);
        assign begin_rfsh = (prev_rfsh_n && !Ram.RFSH_n);
    end

    /***************************************************************
     * READY 更新
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                 READY <= 0;
        else if(state == STATE_IDLE) READY <= 1;
    end

    /***************************************************************
     * TIMING 更新
     ***************************************************************/
    assign Ram.TIMING = state == STATE_IDLE;

    /***************************************************************
     * ACK_n 更新
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            Ram.ACK_n <= 1;
        end
        else if(state == STATE_ACTIVE_ACK) begin
            if(begin_rd || begin_wr || begin_rfsh) begin
                Ram.ACK_n <= 0;
            end
        end
        else if(state == STATE_INACTIVE_ACK) begin
            //if(Ram.WE_n && Ram.OE_n && Ram.RFSH_n) begin
                Ram.ACK_n <= 1;
            //end
        end
    end

    /***************************************************************
     * state 更新
     ***************************************************************/
    localparam      STATE_INIT          = (7'd0);
    localparam      STATE_INIT_PRE      = (STATE_INIT + 7'd0);
    localparam      STATE_INIT_REF1     = (STATE_INIT + 7'd8);
    localparam      STATE_INIT_REF2     = (STATE_INIT + 7'd16);
    localparam      STATE_INIT_SMR      = (STATE_INIT + 7'd24);
    localparam      STATE_INIT_END      = (STATE_INIT + 7'd32);

    localparam      STATE_IDLE          = (STATE_INIT_END);
    localparam      STATE_ACTIVE_ACK    = (STATE_IDLE + 7'd0);
    localparam      STATE_INACTIVE_ACK  = (STATE_IDLE + 7'd6);
    localparam      STATE_END           = (STATE_IDLE + 7'd7);

    localparam      STATE_ACTIVE        = (STATE_IDLE + 7'd0);
    localparam      STATE_SETUP_DATA    = (STATE_IDLE + 7'd1);
    localparam      STATE_READ_WRITE    = (STATE_IDLE + 7'd3);
    localparam      STATE_FETCH_DATA    = (STATE_IDLE + 7'd6);
    reg [6:0]       state;
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)                            state <= STATE_INIT;
        else if(state == STATE_IDLE)            state <= (begin_rd || begin_wr || begin_rfsh) ? state + 1'd1 : state;
        else if(state == STATE_END)             state <= STATE_IDLE;
        //else if(state == STATE_INACTIVE_ACK)  state <= (Ram.WE_n && Ram.OE_n && Ram.RFSH_n) ? state + 1'd1 : state;
        else                                    state <= state + 1'd1;
    end

    /***************************************************************
     * SDRAM へコマンド送信
     ***************************************************************/
    reg                             cmd_is_write;
    reg                             cmd_is_read;
    reg                             cmd_is_refresh;
    reg [$bits(Ram.ADDR)-1:0]       save_addr;
    reg [$bits(Ram.DIN)-1:0]        save_din;
    reg [$bits(Ram.DIN_SIZE)-1:0]   save_din_size;
    reg [9:0]                       save_col;
    reg [SDRAM_ROW_WIDTH-1:0]       save_row;
    reg [SDRAM_BA_WIDTH-1:0]        save_bank;
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            cmd_is_read <= 0;
            cmd_is_write <= 0;
            cmd_is_refresh <= 0;
            Ram.DOUT <= 0;
            sdram_DQ_OUT_ENA_n <= DQ_OUT_ENA_INACTIVE;
        end else begin
            // コマンド設定
            case (state)
                //
                // 初期設定 : PRECHARGE コマンド
                //
                STATE_INIT_PRE:
                begin
                    // SDRAM へ PRECHARGE コマンドを送信
                    SDRAM_CMD <= CMD_PRE;
                    SDRAM_BA <= 0;
                    SDRAM_A <= 11'b10000000000;
                end

                //
                // 初期設定 : AUTO REFRESH コマンド
                //
                STATE_INIT_REF1, STATE_INIT_REF2:
                begin
                    // SDRAM へ AUTO REFRESH コマンドを送信
                    SDRAM_CMD <= CMD_PRE;
                    SDRAM_BA <= 0;
                    SDRAM_A <= 11'b10000000000;
                end

                //
                // 初期設定 : モードレジスタ設定
                //
                STATE_INIT_SMR:
                begin
                    // SDRAM へモードレジスタ設定コマンドを送信
                    SDRAM_CMD <= CMD_SMR;
                    SDRAM_BA <= 0;
                    SDRAM_A <= { 1'b0, MR_WRITE_BURST, 2'b00, MR_CAS_LATENCY, MR_BURST_TYPE, MR_BURST_LENGTH};
                end

                //
                // データ転送の開始
                //
                STATE_ACTIVE:
                begin
                    if(begin_rd || begin_wr)
                    begin
                        // SDRAM へ ACTIVE コマンドを送信
                        SDRAM_CMD <= CMD_ACT;
                        SDRAM_BA <= sdram_bank;
                        SDRAM_A <= sdram_row;

                        // DQ MASK を設定
                        if(Ram.WE_n) begin
                            SDRAM_DQM <= 0;
                        end
                        else begin
                            if(SDRAM_DQ_WIDTH == 32)
                            begin
                                case (Ram.DIN_SIZE)
                                    default:
                                        case (Ram.ADDR[1:0])
                                            2'd0:   SDRAM_DQM <= 4'b1110;
                                            2'd1:   SDRAM_DQM <= 4'b1101;
                                            2'd2:   SDRAM_DQM <= 4'b1011;
                                            2'd3:   SDRAM_DQM <= 4'b0111;
                                        endcase
                                    RAM::DIN_SIZE_16:
                                        case (Ram.ADDR[1:1])
                                            2'd0:   SDRAM_DQM <= 4'b1100;
                                            2'd1:   SDRAM_DQM <= 4'b0011;
                                        endcase
                                    RAM::DIN_SIZE_32:SDRAM_DQM <= 4'b0000;
                                endcase
                            end else begin
                                case (Ram.ADDR[0])
                                    2'd0:   SDRAM_DQM <= 4'b10;
                                    2'd1:   SDRAM_DQM <= 4'b01;
                                endcase
                            end
                        end

                        save_addr <= Ram.ADDR;
                        save_din <= Ram.DIN;
                        save_din_size <= Ram.DIN_SIZE;
                        save_bank <= sdram_bank;
                        save_row <= sdram_row;
                        save_col <= sdram_col;

                        // 状態を更新
                        cmd_is_refresh <= 0;
                        cmd_is_write <= (Ram.WE_n == 0);
                        cmd_is_read <= (Ram.OE_n == 0);

                    end else if(begin_rfsh)
                    begin
                        // SDRAM へ AUTO REFRESH コマンドを送信
                        SDRAM_CMD <= CMD_REF;
                        SDRAM_BA <= 0;
                        SDRAM_A <= 11'b10000000000;
                        SDRAM_DQM <= 0;

                        // 状態を更新
                        cmd_is_refresh <= 1;
                        cmd_is_write <= 0;
                        cmd_is_read <= 0;

                    end else begin
                        // SDRAM へ NOP コマンドを送信
                        SDRAM_CMD <= CMD_NOP;
                        SDRAM_BA <= 0;
                        SDRAM_A <= 11'b10000000000;
                        SDRAM_DQM <= 0;

                        // 状態を更新
                        cmd_is_refresh <= 0;
                        cmd_is_write <= 0;
                        cmd_is_read <= 0;
                    end
                end

                //
                // 書き込みデータの準備
                //
                STATE_SETUP_DATA:
                begin
                    // SDRAM へ NOP コマンドを送信
                    SDRAM_CMD <= CMD_NOP;

                    // DQ へデータ出力
                    if(cmd_is_write)
                    begin
                        // WRITE データを設定
                        if(SDRAM_DQ_WIDTH == 32)
                        begin
                            case (save_din_size)
                                default:          sdram_DQ_OUT <= { save_din[ 7:0], save_din[ 7:0], save_din[ 7:0], save_din[ 7:0]};
                                RAM::DIN_SIZE_16: sdram_DQ_OUT <= { save_din[15:0], save_din[15:0]};
                                RAM::DIN_SIZE_32: sdram_DQ_OUT <=   save_din[31:0];
                            endcase
                        end else begin
                            sdram_DQ_OUT <= { save_din, save_din};
                        end

                        // DQ の出力許可
                        sdram_DQ_OUT_ENA_n <= DQ_OUT_ENA_ACTIVE;
                    end
                end

                //
                // READ/WRITE コマンド発行
                //
                STATE_READ_WRITE:
                begin
                    if(!cmd_is_refresh)
                    begin
                        // SDRAM へ READ または WRITE コマンドを送信
                        SDRAM_CMD <= cmd_is_write ? CMD_WR : CMD_RD;
                        SDRAM_BA <= save_bank;
                        SDRAM_A[10] <= 1'b1;
                        SDRAM_A[9:0] <= save_col;
                    end else begin
                        // SDRAM へ NOP コマンドを送信
                        SDRAM_CMD <= CMD_NOP;
                    end
                end

                //
                // データの取り込み
                //
                STATE_FETCH_DATA:
                begin
                    // SDRAM へ NOP コマンドを送信
                    SDRAM_CMD <= CMD_NOP;

                    // DQ_IN を読み出す
                    if(cmd_is_read)
                    begin
                        cmd_is_read <= 0;
                        if(SDRAM_DQ_WIDTH == 32)
                        begin
                            case (save_addr[1:0])
                                2'd0:   Ram.DOUT <=               SDRAM_DQ[31: 0];
                                2'd1:   Ram.DOUT <= { 8'h00,      SDRAM_DQ[31: 8] };
                                2'd2:   Ram.DOUT <= { 16'h0000,   SDRAM_DQ[31:16] };
                                2'd3:   Ram.DOUT <= { 24'h000000, SDRAM_DQ[31:24] };
                            endcase
                        end else begin
                            case (save_addr[0])
                                2'd0:   Ram.DOUT <= SDRAM_DQ[15:0];
                                2'd1:   Ram.DOUT <= { SDRAM_DQ[7:0], SDRAM_DQ[15:8] };
                            endcase
                        end
                    end

                    // DQ 出力中なら Hi-Z にする
                    sdram_DQ_OUT_ENA_n <= DQ_OUT_ENA_INACTIVE;
                end

                default:
                begin
                    // SDRAM へ NOP コマンドを送信
                    SDRAM_CMD <= CMD_NOP;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
