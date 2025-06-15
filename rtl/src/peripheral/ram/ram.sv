//
// ram.sv
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
 * メモリパッケージ
 ***********************************************************************/
package RAM;
    localparam [2:0]    DSIZE_8    = 3'b000;
    localparam [2:0]    DSIZE_16   = 3'b001;
    localparam [2:0]    DSIZE_32   = 3'b010;
    localparam [2:0]    DSIZE_32_E = 3'b011; // 64bit アクセスして偶数アドレスを 32bit 分
    localparam [2:0]    DSIZE_32_O = 3'b111; // 64bit アクセスして奇数アドレスを 32bit 分
endpackage

/***********************************************************************
 * メモリインターフェース
 ***********************************************************************/
interface RAM_IF #(parameter ADDR_BIT_WIDTH=24);
    logic [ADDR_BIT_WIDTH-1:0]  ADDR;           // アドレス
    logic                       OE_n;           // リード信号
    logic                       WE_n;           // ライト信号
    logic                       RFSH_n;         // リフレッシュ信号
    logic [31:0]                DIN;            // ライトデータ
    logic [31:0]                DOUT;           // リードデータ
    logic                       ACK_n;          // 応答
    logic                       WAIT_n;         // WAIT
    logic [2:0]                 DSIZE;          // R/Wデータサイズ
    logic                       TIMING;         // メモリアクセスタイミング信号(ToDo:削除)

    // ホスト側ポート
    modport HOST (
                    output ADDR, OE_n, WE_n, RFSH_n, DIN, DSIZE,
                    input  DOUT, ACK_n, WAIT_n, TIMING
                );

    // メモリ側ポート
    modport DEVICE (
                    input  ADDR, OE_n, WE_n, RFSH_n, DIN, DSIZE,
                    output DOUT, ACK_n, WAIT_n, TIMING
                );

    // ダミー接続
    function automatic void connect_dummy();
        ADDR = 0;
        DIN = 0;
        DSIZE = 0;
        OE_n = 1;
        WE_n = 1;
        RFSH_n = 1;
    endfunction
endinterface

/***************************************************************
 * Primary と Secondary をバイパス
 ***************************************************************/
module BYPASS_RAM (
    RAM_IF.HOST             Primary,
    RAM_IF.DEVICE           Secondary
);

    assign Primary.ADDR     = Secondary.ADDR;
    assign Primary.OE_n     = Secondary.OE_n;
    assign Primary.WE_n     = Secondary.WE_n;
    assign Primary.RFSH_n   = Secondary.RFSH_n;
    assign Primary.DIN      = Secondary.DIN;
    assign Primary.DSIZE    = Secondary.DSIZE;
    assign Secondary.DOUT   = Primary.DOUT;
    assign Secondary.ACK_n  = Primary.ACK_n;
    assign Secondary.WAIT_n = Primary.WAIT_n;
    assign Secondary.TIMING = Primary.TIMING;

endmodule

`default_nettype wire
