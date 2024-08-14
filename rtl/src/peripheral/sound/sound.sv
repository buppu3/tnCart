//
// sound.sv
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
 * サウンドインターフェース
 ***********************************************************************/
interface SOUND_IF #(parameter BIT_WIDTH=10);
    logic [BIT_WIDTH-1:0]   Signal;
    modport IN  ( input  Signal );
    modport OUT ( output Signal );

    // ダミー出力
    function automatic void connect_dummy();
        Signal = 0;
    endfunction
endinterface

/***********************************************************************
 * アッテネーターモジュール
 ***********************************************************************/
module SOUND_ATTENUATOR #(
    parameter   MUL = 4,
    parameter   DIV = 4
) (
    input wire      CLK,
    input wire      RESET_n,
    SOUND_IF.IN     IN,
    SOUND_IF.OUT    OUT
);
    ATT_CONST #(
        .BIT_WIDTH($bits(IN.Signal)),
        .MUL(MUL),
        .DIV(DIV)
    ) u_att (
        .CLK,
        .RESET_n,
        .IN(IN.Signal),
        .OUT(OUT.Signal)
    );

endmodule

/***********************************************************************
 * ミキサーモジュール
 ***********************************************************************/
module SOUND_MIXER #(
    parameter       COUNT = 1           // 入力数
) (
    input wire      CLK,
    input wire      RESET_n,

    SOUND_IF.IN     IN[0:COUNT-1],      // 入力信号
    SOUND_IF.OUT    OUT                 // 出力信号
);
    localparam SUM_BIT_WIDTH = ($bits(OUT.Signal) + $clog2(COUNT+1));

    wire [SUM_BIT_WIDTH-1:0]    value[0:COUNT-1];
    wire [SUM_BIT_WIDTH-1:0]    result[0:COUNT-1];

    /***************************************************************
     * ビット幅を拡張して加算
     ***************************************************************/
    generate
        genvar ch;
        for(ch = 0; ch < COUNT; ch = ch + 1) begin: ch_loop
            SIGN_EXTENSION #(
                .IN_WIDTH($bits(IN[ch].Signal)),
                .OUT_WIDTH($bits(value[ch]))
            ) u_sign_ext (
                .IN(IN[ch].Signal),
                .OUT(value[ch])
            );

            if(ch == COUNT - 1)
                assign result[ch] = value[ch];
            else
                assign result[ch] = value[ch] + result[ch + 1];
        end
    endgenerate


    /***************************************************************
     * リミッタ
     ***************************************************************/
    LIMITER_FF #(
        .IN_WIDTH($bits(result[0])),
        .OUT_WIDTH($bits(OUT.Signal))
    ) u_limiter (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .IN(result[0]),
        .OUT(OUT.Signal)
    );

endmodule

`default_nettype wire
