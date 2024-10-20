//
// dac_i2s.sv
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
 * I2S DAC module
 ***********************************************************************/
module DAC_I2S #(
    parameter                   bit_width = 16  // 1ch 辺りのビット数(16 or 32bit)
) (
    input wire                  CLK,            // クロック
    input wire                  RESET_n,        // リセット信号

    SOUND_IF.IN                 IN_L,           // 再生信号
    SOUND_IF.IN                 IN_R,           // 再生信号

    input wire                  BCLK,           // BCLK
    output wire                 LRCLK,          // LRCLK
    output wire                 DIN             // DIN
);
    //
    wire CLK_EN = !ff_bclk & BCLK;
    logic ff_bclk;
    always_ff @(posedge CLK) ff_bclk <= BCLK;

    // 左データを 16bit に変換
    logic [bit_width-1:0] sig_l;
    if($bits(IN_L.Signal) >= bit_width) begin
        always_ff @(posedge CLK) sig_l <= IN_L.Signal[$bits(IN_L.Signal)-1:$bits(IN_L.Signal)-bit_width];
    end
    else begin
        localparam zero_bit_width = bit_width - $bits(IN_L.Signal);
        wire [zero_bit_width-1:0] zero = 0;
        always_ff @(posedge CLK) sig_l <= { IN_L.Signal, zero };
    end

    // 右データを 16bit に変換
    logic [bit_width-1:0] sig_r;
    if($bits(IN_R.Signal) >= bit_width) begin
        always_ff @(posedge CLK) sig_r <= IN_R.Signal[$bits(IN_R.Signal)-1:$bits(IN_R.Signal)-bit_width];
    end
    else begin
        localparam zero_bit_width = bit_width - $bits(IN_R.Signal);
        wire [zero_bit_width-1:0] zero = 0;
        always_ff @(posedge CLK) sig_r <= { IN_R.Signal, zero };
    end

    // カウンタ
    logic [$clog2(bit_width)-1:0] cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    cnt <= 0;
        else if(CLK_EN) cnt <= cnt + 1'd1;
    end

    // LRCLK 生成
    logic ff_lrclk;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                ff_lrclk <= 0;
        else if(CLK_EN && cnt == 0) ff_lrclk <= ~ff_lrclk;
    end

    // シフトレジスタ
    logic [bit_width-1:0] ff_reg;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                ff_reg <= 0;
        else if(CLK_EN && cnt == 0) ff_reg <= ff_lrclk ? sig_l : sig_r;
        else if(CLK_EN)             ff_reg <= {ff_reg[bit_width-2:0], ff_reg[bit_width-1]};
    end

    // 信号の出力
    assign LRCLK = ff_lrclk;
    assign DIN = ff_reg[bit_width-1];

endmodule


`default_nettype wire
