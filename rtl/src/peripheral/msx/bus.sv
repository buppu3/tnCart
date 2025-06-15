//
// bus.sv
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

interface BUS_IF;
    // MSX->カートリッジ
    logic [15:0]    ADDR;           // ADDRESS
    logic [7:0]     DIN;            // データバス(MSX->DEVICE)
    logic           RFSH_n;         // リフレッシュ信号
    logic           RD_n;           // リード信号
    logic           WR_n;           // ライト信号
    logic           IORQ_n;         // I/O 選択
    logic           SLTSL_n;        // スロット選択
    logic           RESET_n;        // MSX のリセット信号
    logic           CLK;            // MSX のクロック信号

    // カートリッジ->MSX
    logic [7:0]     DOUT;           // データバス
    logic           BUSDIR_n;       // データバス方向(0 = DOUT enable)
    logic           INT_n;          // 割り込み
    logic           WAIT_n;         // ウェイト

    // MSX 側ポート
    modport MSX(
                    output ADDR, DIN, RFSH_n, RD_n, WR_n, IORQ_n, SLTSL_n, RESET_n, CLK,
                    input  DOUT, BUSDIR_n, INT_n, WAIT_n
                );

    // カートリッジ側ポート
    modport CARTRIDGE(
                    input  ADDR, DIN, RFSH_n, RD_n, WR_n, IORQ_n, SLTSL_n, RESET_n, CLK,
                    output DOUT, BUSDIR_n, INT_n, WAIT_n
                );

    // ダミー接続
    function automatic void connect_dummy();
        DOUT = 0;
        BUSDIR_n = 1;
        INT_n = 1;
        WAIT_n = 1;
    endfunction
endinterface

`default_nettype wire
