//
// uart.sv
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
 * UART 受信インターフェース
 ***********************************************************************/
interface UART_RX_IF;
    logic [7:0] DATA;       // 受信データ
    logic       READY;      // 受信データレディフラグ
    logic       FERR;       // フレーミングエラーフラグ
    logic       OERR;       // オーバーランエラーフラグ

    logic       READ;       // データ読み出し
    logic       CLEAR;      // フラグクリア

    // ホスト側ポート
    modport HOST  (input  DATA, READY, FERR, OERR, output READ, CLEAR);

    // デバイス側ポート
    modport DEVICE(output DATA, READY, FERR, OERR, input  READ, CLEAR);
endinterface

/***********************************************************************
 * UART 送信インターフェース
 ***********************************************************************/
interface UART_TX_IF;
    logic [7:0] DATA;       // 送信データ
    logic       STROBE;     // 送信ストローブ
    logic       FULL;       // 送信バッファフル

    // ホスト側ポート
    modport HOST  (output DATA, STROBE, input  FULL);

    // デバイス側ポート
    modport DEVICE(input  DATA, STROBE, output FULL);
endinterface

/***********************************************************************
 * UART 受信モジュール
 ***********************************************************************/
module UART_RX #(
    parameter   CLKFREQ         = 27_000_000,   // 駆動クロック周波数
    parameter   BAUDRATE        = 115_200       // 伝送速度
)(
    input   wire            CLK,                // 駆動クロック
    input   wire            RESET_n,            // リセット信号

    UART_RX_IF.DEVICE       Uart_rx_interface,  // インターフェース

    input   wire            RXD                 // 受信ポート
);

    localparam      CLKDIV = CLKFREQ / BAUDRATE;
    localparam      COUNTER_WIDTH = $clog2((CLKDIV)+1);

    localparam      STATE_IDLE  = 4'd0, // START bit 受信待機
                    STATE_D0    = 4'd1, // D0 ビット受信
                    STATE_D1    = 4'd2,
                    STATE_D2    = 4'd3,
                    STATE_D3    = 4'd4,
                    STATE_D4    = 4'd5,
                    STATE_D5    = 4'd6,
                    STATE_D6    = 4'd7,
                    STATE_D7    = 4'd8,
                    STATE_STOP  = 4'd9; // STOP bit 受信

    reg     [3:0]               state;
    reg     [7:0]               buffer;             // 受信データバッファ
    reg     [7:0]               shift;              // シフトレジスタ
    reg     [COUNTER_WIDTH-1:0] baudrate_counter;   // ボーレートカウンタ
    reg                         e_frame;            // フレーミングエラーフラグ
    reg                         e_over;             // オーバーランエラーフラグ
    reg                         complete;           // 受信完了フラグ
    reg     [COUNTER_WIDTH-1:0] startbit_counter;
    wire    [COUNTER_WIDTH-1:0] DELAY = (CLKFREQ / BAUDRATE);
    wire    [COUNTER_WIDTH-1:0] DELAY_HALF = (CLKFREQ / (2 * BAUDRATE));

    assign          Uart_rx_interface.DATA = buffer;
    assign          Uart_rx_interface.FERR = e_frame;
    assign          Uart_rx_interface.OERR = e_over;
    assign          Uart_rx_interface.READY = complete;

    always @(posedge CLK)
    begin
        if(!RESET_n)
        begin
            buffer <= 0;
            shift <= 0;
            e_frame <= 0;
            e_over <= 0;
            complete <= 0;
            baudrate_counter <= 0;
            startbit_counter <= 8'd0;
            state <= STATE_IDLE;
        end else begin

            // complete フラグ SET/RESET
            if(Uart_rx_interface.READ)
            begin
                complete <= 0;
            end else if(baudrate_counter == 8'd0 && state == STATE_STOP)
            begin
                complete <= 1;
            end

            // e_frame フラグ SET/RESET
            if(Uart_rx_interface.CLEAR)
            begin
                e_frame <= 0;
            end else if(baudrate_counter == 8'd0 && state == STATE_STOP && !RXD)
            begin
                e_frame <= 1;
            end

            // e_over フラグ SET/RESET
            if(Uart_rx_interface.CLEAR)
            begin
                e_over <= 0;
            end else if(baudrate_counter == 8'd0 && state == STATE_STOP && complete)
            begin
                e_over <= 1;
            end

            if(state == STATE_IDLE)
            begin
                // 0.5bit の間 LOW が続いたらデータの開始とする
                if(!RXD)
                begin
                    if(startbit_counter != DELAY_HALF)
                    begin
                        startbit_counter <= startbit_counter + 8'd1;
                    end else begin
                        startbit_counter <= 8'd0;
                        baudrate_counter <= DELAY - 8'd1;
                        state <= state + 4'd1;
                    end
                end else begin
                    startbit_counter <= 8'd0;
                end

            end else if(baudrate_counter != 8'd0)
            begin
                baudrate_counter <= baudrate_counter - 8'd1;

            end else begin
                baudrate_counter <= DELAY - 8'd1;

                if(state == STATE_STOP)
                begin
                    buffer <= shift;
                    state <= STATE_IDLE;
                end else begin
                    shift <= { RXD, shift[7:1] };
                    state <= state + 4'd1;
                end
            end
        end
    end

endmodule

/***********************************************************************
 * UART 送信モジュール
 ***********************************************************************/
module UART_TX #(
    parameter   CLKFREQ         = 27_000_000,   // 駆動クロック周波数
    parameter   BAUDRATE        = 115_200       // 伝送速度
)(
    input   wire            CLK,                // 駆動クロック
    input   wire            RESET_n,            // リセット信号

    UART_TX_IF.DEVICE       Uart_tx_interface,  // インターフェース

    output  wire            TXD                 // 送信ポート
);

    localparam      CLKDIV = CLKFREQ / BAUDRATE;
    localparam      COUNTER_WIDTH = $clog2((CLKDIV)+1);

    localparam      STATE_IDLE      = 4'd0,
                    STATE_START     = 4'd1,
                    STATE_D0        = 4'd2,
                    STATE_D1        = 4'd3,
                    STATE_D2        = 4'd4,
                    STATE_D3        = 4'd5,
                    STATE_D4        = 4'd6,
                    STATE_D5        = 4'd7,
                    STATE_D6        = 4'd8,
                    STATE_D7        = 4'd9,
                    STATE_STOP      = 4'd10,
                    STATE_COMPLETE  = 4'd11;

    reg     [3:0]               state;
    reg     [9:0]               shift_reg;
    reg     [COUNTER_WIDTH-1:0] baudrate_counter;
    wire    [COUNTER_WIDTH-1:0] DELAY = (CLKDIV);
    assign                      Uart_tx_interface.FULL = (state == STATE_IDLE) ? Uart_tx_interface.STROBE : (state != STATE_COMPLETE);
    assign                      TXD = shift_reg[0];

    always @(posedge CLK)
    begin
        if(!RESET_n)
        begin
            shift_reg <= 10'b1_11111111_1;
            baudrate_counter <= 0;
            state <= STATE_IDLE;
        end else begin
            if(state == STATE_IDLE)
            begin
                if(Uart_tx_interface.STROBE)
                begin
                    shift_reg <= { 
                            1'b1,           // stop
                            Uart_tx_interface.DATA[7:0],      // data
                            1'b0            // start
                        };
                    baudrate_counter <= DELAY - 1'd1;
                    state <= state + 4'd1;
                end
            end else if(state == STATE_COMPLETE)
            begin
                if(!Uart_tx_interface.STROBE)
                begin
                    state <= STATE_IDLE;
                end
            end else if(baudrate_counter != 8'd0)
            begin
                baudrate_counter <= baudrate_counter - 1'd1;
            end else begin
                baudrate_counter <= DELAY - 1'd1;
                shift_reg <= {1'b1, shift_reg[9:1]};
                state <= state + 4'd1;
            end
        end
    end
endmodule

`default_nettype wire
