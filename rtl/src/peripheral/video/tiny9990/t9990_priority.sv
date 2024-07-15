//
// t9990_priority.sv
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
 * パレット画面の合成
 ***************************************************************/
module T9990_PRIORITY (
    input wire          RESET_n,
    input wire          CLK,
    input wire          DCLK_EN,

    input wire          MUX_VDE,
    input wire          MUX_HDE,

    input wire          SP_DISABLE,
    input wire [1:0]    SP_PRI,
    input wire [5:0]    SP_PA,

    input wire          PA_DISABLE,
    input wire [1:0]    PA_PRI,
    input wire [5:0]    PA_PA,

    input wire          PB_DISABLE,
    input wire [1:0]    PB_PRI,
    input wire [5:0]    PB_PA,

    input wire          BP_DISABLE,
    input wire [0:0]    BP_PRI,
    input wire [5:0]    BP_PA,
    input wire [5:0]    BDC,

    output reg [5:0]    PA,
    output reg [0:0]    PRI
);
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                            PA <= 0;
        else if(DCLK_EN) begin
            if(!MUX_VDE)                            PA <= BDC;
            else if(!MUX_HDE)                       PA <= BDC;
            else if(!SP_DISABLE && SP_PRI == 2'b00) PA <= SP_PA;   // スプライト全面
            else if(!PA_DISABLE && PA_PRI == 2'b00) PA <= PA_PA;   // P1A/P2
            else if(!PB_DISABLE && PB_PRI == 2'b00) PA <= PB_PA;   // P1B
            else if(!SP_DISABLE && SP_PRI == 2'b10) PA <= SP_PA;   // スプライト背面
            else if(!PA_DISABLE && PA_PRI == 2'b10) PA <= PA_PA;   // P1A/P2
            else if(!PB_DISABLE && PB_PRI == 2'b10) PA <= PB_PA;   // P1B
            else if(!BP_DISABLE && !BP_PRI)         PA <= BP_PA;   // ビットマップ(YAE / BP6 / BP4 / BP2)
            else                                    PA <= BDC;     // バックドロップ
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                            PRI <= 1;
        else if(DCLK_EN) begin
            if(!MUX_VDE)                            PRI <= 0;
            else if(!MUX_HDE)                       PRI <= 0;
            else if(!SP_DISABLE && SP_PRI == 2'b00) PRI <= 0;   // スプライト全面
            else if(!PA_DISABLE && PA_PRI == 2'b00) PRI <= 0;   // P1A/P2
            else if(!PB_DISABLE && PB_PRI == 2'b00) PRI <= 0;   // P1B
            else if(!SP_DISABLE && SP_PRI == 2'b10) PRI <= 0;   // スプライト背面
            else if(!PA_DISABLE && PA_PRI == 2'b10) PRI <= 0;   // P1A/P2
            else if(!PB_DISABLE && PB_PRI == 2'b10) PRI <= 0;   // P1B
            else if(!BP_DISABLE && !BP_PRI)         PRI <= 0;   // ビットマップ(YAE / BP6 / BP4 / BP2)
            else                                    PRI <= 1;   // バックドロップ
        end
    end
endmodule

`default_nettype wire
