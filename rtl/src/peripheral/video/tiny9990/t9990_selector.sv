//
// t9990_selector.sv
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

/***************************************************************
 * Bx 側と Px 側の画面を合成
 ***************************************************************/
module T9990_SELECTOR (
    input wire          RESET_n,
    input wire          CLK,
    input wire          DCLK_EN,

    input wire          DA,
    input wire          DE,
    input wire          IN_HS,
    input wire          IN_VS,
    input wire [15:0]   IN_PALETTE,
    input wire [15:0]   IN_BITMAP,

    output reg          OUT_HS,
    output reg          OUT_VS,
    output reg [15:0]   OUT
);
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)             OUT <= 16'b1_00000_00000_00000;
        else if(!DCLK_EN)        OUT <= OUT;
        else if(!DE)             OUT <= 16'b1_00000_00000_00000;    // イレーズ期間
        else if(!DA)             OUT <= {1'b1, IN_PALETTE[14:0]};   // ボーダー期間
        else if(!IN_PALETTE[15]) OUT <= IN_PALETTE;                 // パレット画面
        else if(!IN_BITMAP[15])  OUT <= IN_BITMAP;                  // ビットマップ画面
        else                     OUT <= IN_PALETTE;                 // ビットマップ画面(バックドロップ)
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) OUT_HS <= 0;
        else         OUT_HS <= IN_HS;
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) OUT_VS <= 0;
        else         OUT_VS <= IN_VS;
    end

endmodule

`default_nettype wire
