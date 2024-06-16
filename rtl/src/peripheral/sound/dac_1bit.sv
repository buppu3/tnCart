//
// dac_1bit.sv
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
 * 1bit DAC module
 *  1ビット DAC 出力を行う
 ***********************************************************************/
module DAC_1BIT #(
    parameter                   DIV = 5         // 駆動クロック分周比
) (
    input wire                  CLK,            // クロック
    input wire                  RESET_n,        // リセット信号

    SOUND_IF.IN                 IN,             // 再生信号

    output reg                  OUT             // 出力ポート
);
    /***************************************************************
     * 分周
     ***************************************************************/
    logic   [$clog2(DIV+1)-1:0] div_cnt;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            div_cnt <= 0;
        end
        else if(div_cnt == DIV - 1) begin
            div_cnt <= 0;
        end
        else begin
            div_cnt <= div_cnt + 1'd1;
        end
    end

    /***************************************************************
     * バッファ
     ***************************************************************/
    localparam BIT_WIDTH = $bits(IN.Signal);
    localparam [BIT_WIDTH - 1 : 0] OFFSET = (2 ** (BIT_WIDTH - 1));

    logic [BIT_WIDTH-1:0]   in0;
    logic [BIT_WIDTH-1:0]   in1;
    logic [BIT_WIDTH-1:0]   in_unsigned;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            in0 <= 0;
            in1 <= 0;
        end
        else if(div_cnt == 0) begin
            in0 <= IN.Signal;
            in1 <= in0;
            in_unsigned <= in1 + OFFSET;
        end
    end

    /***************************************************************
     * 加算
     ***************************************************************/
    reg     [BIT_WIDTH:0]   sum;
    wire    [BIT_WIDTH:0]   added = sum + in_unsigned;
    wire                    overflow = added[BIT_WIDTH];

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            sum <= 0;
            OUT <= 0;
        end
        else if(div_cnt == 0) begin
            sum <= added[BIT_WIDTH-1:0];
            OUT <= overflow;
        end
    end

endmodule


`default_nettype wire
