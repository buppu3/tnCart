//
// debugger_input.sv
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
 * デバッガ用 UART 入力モジュール
 ***********************************************************************/
module DEBUGGER_INPUT #(
    parameter   COUNT = 64
)(
    input wire                      CLK,
    input wire                      RESET_n,
    UART_RX_IF.HOST                 RXD,
    input wire                      REQ_n,
    output reg [7:0]                DATA[0:COUNT-1],
    output reg [$clog2(COUNT+1):0]  LENGTH,
    output reg                      ACK_n
);
    enum logic[1:0] {
        STATE_IDLE,
        STATE_RUN,
        STATE_COMPLETE
    } state;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            LENGTH <= 0;
            ACK_n <= 1;
            state <= STATE_IDLE;
        end
        else case (state)
            STATE_IDLE:
            begin
                if(!REQ_n) begin
                    state <= STATE_RUN;
                    ACK_n <= 0;
                    LENGTH <= 0;
                end
            end

            STATE_RUN:
            begin
                if(RXD.READ) begin
                    RXD.READ <= 0;
                end
                else if(RXD.CLEAR) begin
                    RXD.CLEAR <= 0;
                end
                else if(RXD.READY) begin
                    if(RXD.DATA == CHAR_CR) begin
                        state <= STATE_COMPLETE;
                    end
                    else if(RXD.DATA == 8'h08) begin
                        if(LENGTH != 0) begin
                            LENGTH <= LENGTH - 1'd1;
                        end
                    end
                    else if(LENGTH != COUNT) begin
                        DATA[LENGTH] <= RXD.DATA;
                        LENGTH <= LENGTH + 1'd1;
                    end
                    RXD.READ <= 1;
                    RXD.CLEAR <= 1;
                end
            end

            STATE_COMPLETE:
            begin
                if(RXD.READ) begin
                    RXD.READ <= 0;
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
