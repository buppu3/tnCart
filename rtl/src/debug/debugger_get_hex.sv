//
// debugger_get_hex.sv
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

`default_nettype none

`include "debugger_char.inc"    // キャラクターコード定義

/***********************************************************************
 * デバッガ用 16進数変換モジュール
 ***********************************************************************/
module DEBUGGER_GET_HEX #(
    parameter COUNT = 64
) (
    input wire                      CLK,
    input wire                      RESET_n,
    input wire                      REQ_n,
    input wire [7:0]                DATA[0:COUNT-1],
    input wire [$clog2(COUNT+1):0]  LENGTH,
    input wire [$clog2(COUNT+1):0]  START,
    output reg                      ACK_n,
    output reg [31:0]               VALUE,
    output reg [$clog2(COUNT+1):0]  INDEX
);
    enum logic [2:0] {
        STATE_IDLE,
        STATE_CONV,
        STATE_CONV_2,
        STATE_SKIP_POST_SPC,
        STATE_SKIP_PRE_SPC,
        STATE_COMPLETE
    } state;

    logic [3:0] nibble;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ACK_n <= 1;
            VALUE <= 0;
            INDEX <= 0;
            state <= STATE_IDLE;
        end
        else case (state)
            STATE_IDLE:
            begin
                if(!REQ_n) begin
                    ACK_n <= 0;
                    VALUE <= 0;
                    INDEX <= START;
                    state <= STATE_CONV;
                end
            end

            STATE_CONV:
            begin
                if(INDEX == COUNT || INDEX == LENGTH) begin
                    state <= STATE_COMPLETE;
                end
                else if(DATA[INDEX] == CHAR_COMMA) begin
                    INDEX <= INDEX + 1'd1;
                    state <= STATE_SKIP_PRE_SPC;
                end
                else if(DATA[INDEX] == CHAR_SPC) begin
                    state <= STATE_SKIP_POST_SPC;
                end
                else begin
                    INDEX <= INDEX + 1'd1;
                    state <= STATE_CONV_2;
                    case (DATA[INDEX])
                        default:  nibble <= 0;
                        CHAR_0:   nibble <= 4'h0;
                        CHAR_1:   nibble <= 4'h1;
                        CHAR_2:   nibble <= 4'h2;
                        CHAR_3:   nibble <= 4'h3;
                        CHAR_4:   nibble <= 4'h4;
                        CHAR_5:   nibble <= 4'h5;
                        CHAR_6:   nibble <= 4'h6;
                        CHAR_7:   nibble <= 4'h7;
                        CHAR_8:   nibble <= 4'h8;
                        CHAR_9:   nibble <= 4'h9;
                        CHAR_A:   nibble <= 4'hA;
                        CHAR_B:   nibble <= 4'hB;
                        CHAR_C:   nibble <= 4'hC;
                        CHAR_D:   nibble <= 4'hD;
                        CHAR_E:   nibble <= 4'hE;
                        CHAR_F:   nibble <= 4'hF;
                        CHAR_a:   nibble <= 4'hA;
                        CHAR_b:   nibble <= 4'hB;
                        CHAR_c:   nibble <= 4'hC;
                        CHAR_d:   nibble <= 4'hD;
                        CHAR_e:   nibble <= 4'hE;
                        CHAR_f:   nibble <= 4'hF;
                    endcase
                end
            end
            STATE_CONV_2:
            begin
                state <= STATE_CONV;
                VALUE <= { VALUE[27:0], nibble };
            end

            //
            // 値の後ろにあるスペースをスキップ
            //
            STATE_SKIP_POST_SPC:
            begin
                if(INDEX == COUNT || INDEX == LENGTH) begin
                    state <= STATE_COMPLETE;
                end
                else if(DATA[INDEX] == CHAR_COMMA) begin
                    state <= STATE_SKIP_PRE_SPC;
                    INDEX <= INDEX + 1'd1;
                end
                else if(DATA[INDEX] == CHAR_SPC) begin
                    state <= STATE_SKIP_POST_SPC;
                    INDEX <= INDEX + 1'd1;
                end
                else begin
                    state <= STATE_COMPLETE;
                end
            end

            //
            // 値の前にあるスペースをスキップ
            //
            STATE_SKIP_PRE_SPC:
            begin
                if(INDEX == COUNT || INDEX == LENGTH) begin
                    state <= STATE_COMPLETE;
                end
                else if(DATA[INDEX] == CHAR_SPC) begin
                    state <= STATE_SKIP_PRE_SPC;
                    INDEX <= INDEX + 1'd1;
                end
                else begin
                    state <= STATE_COMPLETE;
                end
            end

            STATE_COMPLETE:
            begin
                if(REQ_n) begin
                    ACK_n <= 1;
                    state <= STATE_IDLE;
                end
            end
        endcase
    end

endmodule

`default_nettype wire
