//
// debugger_output.sv
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

`include "debugger_char.inc"    // キャラクターコード定義

/***********************************************************************
 * デバッガ用 UART 出力モジュール
 ***********************************************************************/
module DEBUGGER_OUTPUT #(
    parameter   COUNT = 64
)(
    input wire                      CLK,
    input wire                      RESET_n,
    UART_TX_IF.HOST                 TXD,
    input wire                      REQ_n,
    input wire [1:0]                TYPE,
    input wire [7:0]                DATA[0:COUNT-1],
    input wire [$clog2(COUNT+1):0]  LENGTH,
    output reg                      ACK_n
);

    enum logic[2:0] {
        STATE_IDLE,
        STATE_SEND_STR,
        STATE_SEND_HEX,
        STATE_SEND_HEX_SEP,
        STATE_SEND_HEX_NIBBLE,
        STATE_COMPLETE
    } state;

    reg [3:0]                   hex_value;
    reg                         nibble_flag;
    reg [3:0]                   sep_count;
    reg [3:0]                   sep;
    reg [$clog2(COUNT+1)-1:0]   count;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ACK_n <= 1;
            state <= STATE_IDLE;
            hex_value <= 0;
            nibble_flag <= 0;
            sep_count <= 0;
            sep <= 0;
            count <= 0;
        end
        else case (state)
            STATE_IDLE:
            begin
                if(!REQ_n) begin
                    sep_count <= 0;
                    count <= 0;
                    nibble_flag <= 0;
                    case (TYPE)
                        default:state <= STATE_IDLE;
                        2'd0:
                        begin
                            state <= STATE_SEND_STR;
                            ACK_n <= 0;
                        end
                        2'd1:
                        begin
                            state <= STATE_SEND_HEX;
                            sep <= 2;
                            ACK_n <= 0;
                        end
                        2'd2:
                        begin
                            state <= STATE_SEND_HEX;
                            sep <= 4;
                            ACK_n <= 0;
                        end
                        2'd3:
                        begin
                            state <= STATE_SEND_HEX;
                            sep <= 8;
                            ACK_n <= 0;
                        end
                    endcase
                end
            end

            STATE_SEND_STR:
            begin
                // STOBE をクリア
                if(TXD.STROBE) begin
                    TXD.STROBE <= 0;
                end

                // 終了チェック
                else if(count == LENGTH) begin
                    state <= STATE_COMPLETE;
                end

                // バッファが空いているならデータを送信
                else if(!TXD.FULL) begin
                    TXD.DATA <= DATA[count];
                    TXD.STROBE <= 1;
                    count <= count + 1'd1;
                end
            end

            STATE_SEND_HEX:
            begin
                if(count == LENGTH) begin
                    state <= STATE_COMPLETE;
                end
                else if(TXD.STROBE) begin
                    TXD.STROBE <= 0;
                end
                else if(!TXD.FULL) begin
                    if(sep_count == sep) begin
                        state <= STATE_SEND_HEX_SEP;
                        sep_count <= 0;
                    end
                    else if(nibble_flag) begin
                        nibble_flag <= 0;
                        hex_value <= DATA[count][3:0];
                        sep_count <= sep_count + 1'd1;
                        count <= count + 1'd1;
                        state <= STATE_SEND_HEX_NIBBLE;
                    end
                    else begin
                        nibble_flag <= 1;
                        hex_value <= DATA[count][7:4];
                        sep_count <= sep_count + 1'd1;
                        state <= STATE_SEND_HEX_NIBBLE;
                    end
                end
            end

            STATE_SEND_HEX_SEP:
            begin
                TXD.DATA <= CHAR_SPC;
                TXD.STROBE <= 1;
                state <= STATE_SEND_HEX;
            end

            STATE_SEND_HEX_NIBBLE:
            begin
                case (hex_value)
                    default: TXD.DATA <= 8'h20;
                    4'h0: TXD.DATA <= CHAR_0;
                    4'h1: TXD.DATA <= CHAR_1;
                    4'h2: TXD.DATA <= CHAR_2;
                    4'h3: TXD.DATA <= CHAR_3;
                    4'h4: TXD.DATA <= CHAR_4;
                    4'h5: TXD.DATA <= CHAR_5;
                    4'h6: TXD.DATA <= CHAR_6;
                    4'h7: TXD.DATA <= CHAR_7;
                    4'h8: TXD.DATA <= CHAR_8;
                    4'h9: TXD.DATA <= CHAR_9;
                    4'hA: TXD.DATA <= CHAR_A;
                    4'hB: TXD.DATA <= CHAR_B;
                    4'hC: TXD.DATA <= CHAR_C;
                    4'hD: TXD.DATA <= CHAR_D;
                    4'hE: TXD.DATA <= CHAR_E;
                    4'hF: TXD.DATA <= CHAR_F;
                endcase
                TXD.STROBE <= 1;
                state <= STATE_SEND_HEX;
            end

            STATE_COMPLETE:
            begin
                if(TXD.STROBE) begin
                    TXD.STROBE <= 0;
                end
                if(REQ_n) begin
                    ACK_n <= 1;
                    state <= STATE_IDLE;
                end
            end
        endcase
    end

endmodule

`default_nettype wire
