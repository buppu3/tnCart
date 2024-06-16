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
    logic           MERQ_n;         // メモリ選択
    logic           IORQ_n;         // I/O 選択
    logic           CS1_n;          // 4000h~7FFFh 選択信号(リード時のみアサート)
    logic           CS2_n;          // 8000h~BFFFh 選択信号(リード時のみアサート)
    logic           CS12_n;         // 4000h~BFFFh 選択信号(リード時のみアサート)
    logic           M1_n;           // M1サイクル
    logic           SLTSL_n;        // スロット選択
    logic           RESET_n;        // MSX のリセット信号
    logic           CLK;            // MSX のクロック信号

    // カートリッジ->MSX
    logic [7:0]     DOUT;           // データバス
    logic           BUSDIR_n;       // データバス方向(0 = DOUT enable)
    logic           INT_n;          // 割り込み
    logic           WAIT_n;         // ウェイト

    // その他
    logic           CLK_EN;         // 3.58MHz クロックエッジ
    logic           CLK_21M;
    logic           CLK_EN_21M;     // 3.58MHz クロックエッジ

    // MSX 側ポート
    modport MSX(
                    output ADDR, DIN, RFSH_n, RD_n, WR_n, MERQ_n, IORQ_n, CS1_n, CS2_n, CS12_n, M1_n, SLTSL_n, RESET_n, CLK,
                    input  DOUT, BUSDIR_n, INT_n, WAIT_n,
                    output CLK_EN, CLK_21M, CLK_EN_21M
                );

    // カートリッジ側ポート
    modport CARTRIDGE(
                    input  ADDR, DIN, RFSH_n, RD_n, WR_n, MERQ_n, IORQ_n, CS1_n, CS2_n, CS12_n, M1_n, SLTSL_n, RESET_n, CLK,
                    output DOUT, BUSDIR_n, INT_n, WAIT_n,
                    input  CLK_EN, CLK_21M, CLK_EN_21M
                );

endinterface

/***************************************************************
 * バスを拡張する
 ***************************************************************/
module EXPANSION_BUS #(
    parameter               COUNT = 4,
    parameter               USE_FF = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,

    BUS_IF.CARTRIDGE        Primary,
    BUS_IF.MSX              Secondary[0:COUNT-1]
);
    /***************************************************************
     * Secondary へ接続
     ***************************************************************/
    wire [7:0] tmp_dout    [0:COUNT-1];
    wire       tmp_busdir_n[0:COUNT-1];
    wire       tmp_int_n   [0:COUNT-1];
    wire       tmp_wait_n  [0:COUNT-1];
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: sec
            if(USE_FF) begin
                always_ff @(posedge Primary.CLK_21M or negedge RESET_n) begin
                    if(!RESET_n) begin
                        Secondary[num].CLK_EN_21M <= 0;
                    end
                    else begin
                        Secondary[num].CLK_EN_21M <= Primary.CLK_EN_21M;
                    end
                end

                always_ff @(posedge CLK or negedge RESET_n) begin
                    if(!RESET_n) begin
                        Secondary[num].SLTSL_n    <= 1;
                        Secondary[num].ADDR       <= 0;
                        Secondary[num].DIN        <= 0;
                        Secondary[num].RFSH_n     <= 1;
                        Secondary[num].RD_n       <= 1;
                        Secondary[num].WR_n       <= 1;
                        Secondary[num].MERQ_n     <= 1;
                        Secondary[num].IORQ_n     <= 1;
                        Secondary[num].CS1_n      <= 1;
                        Secondary[num].CS2_n      <= 1;
                        Secondary[num].CS12_n     <= 1;
                        Secondary[num].M1_n       <= 1;
                        Secondary[num].RESET_n    <= 0;
                        Secondary[num].CLK        <= 0;
                        Secondary[num].CLK_EN     <= 0;
                    end
                    else if(!Primary.RESET_n) begin
                        Secondary[num].SLTSL_n    <= 1;
                        Secondary[num].ADDR       <= 0;
                        Secondary[num].DIN        <= 0;
                        Secondary[num].RFSH_n     <= Primary.RFSH_n;
                        Secondary[num].RD_n       <= 1;
                        Secondary[num].WR_n       <= 1;
                        Secondary[num].MERQ_n     <= 1;
                        Secondary[num].IORQ_n     <= 1;
                        Secondary[num].CS1_n      <= 1;
                        Secondary[num].CS2_n      <= 1;
                        Secondary[num].CS12_n     <= 1;
                        Secondary[num].M1_n       <= 1;
                        Secondary[num].RESET_n    <= 0;
                        Secondary[num].CLK        <= Primary.CLK;
                        Secondary[num].CLK_EN     <= Primary.CLK_EN;
                    end
                    else begin
                        Secondary[num].SLTSL_n    <= Primary.SLTSL_n;
                        Secondary[num].ADDR       <= Primary.ADDR;
                        Secondary[num].DIN        <= Primary.DIN;
                        Secondary[num].RFSH_n     <= Primary.RFSH_n;
                        Secondary[num].RD_n       <= Primary.RD_n;
                        Secondary[num].WR_n       <= Primary.WR_n;
                        Secondary[num].MERQ_n     <= Primary.MERQ_n;
                        Secondary[num].IORQ_n     <= Primary.IORQ_n;
                        Secondary[num].CS1_n      <= Primary.CS1_n;
                        Secondary[num].CS2_n      <= Primary.CS2_n;
                        Secondary[num].CS12_n     <= Primary.CS12_n;
                        Secondary[num].M1_n       <= Primary.M1_n;
                        Secondary[num].RESET_n    <= Primary.RESET_n;
                        Secondary[num].CLK        <= Primary.CLK;
                        Secondary[num].CLK_EN     <= Primary.CLK_EN;
                    end
                end
            end
            else begin
                assign Secondary[num].SLTSL_n    = Primary.SLTSL_n;
                assign Secondary[num].ADDR       = Primary.ADDR;
                assign Secondary[num].DIN        = Primary.DIN;
                assign Secondary[num].RFSH_n     = Primary.RFSH_n;
                assign Secondary[num].RD_n       = Primary.RD_n;
                assign Secondary[num].WR_n       = Primary.WR_n;
                assign Secondary[num].MERQ_n     = Primary.MERQ_n;
                assign Secondary[num].IORQ_n     = Primary.IORQ_n;
                assign Secondary[num].CS1_n      = Primary.CS1_n;
                assign Secondary[num].CS2_n      = Primary.CS2_n;
                assign Secondary[num].CS12_n     = Primary.CS12_n;
                assign Secondary[num].M1_n       = Primary.M1_n;
                assign Secondary[num].RESET_n    = Primary.RESET_n;
                assign Secondary[num].CLK        = Primary.CLK;
                assign Secondary[num].CLK_EN     = Primary.CLK_EN;
                assign Secondary[num].CLK_EN_21M = Primary.CLK_EN_21M;
            end

            assign Secondary[num].CLK_21M = Primary.CLK_21M;

            assign tmp_dout    [num] = Secondary[num].DOUT     | ((num < COUNT-1) ? tmp_dout    [num + 1] : 0);
            assign tmp_busdir_n[num] = Secondary[num].BUSDIR_n & ((num < COUNT-1) ? tmp_busdir_n[num + 1] : 1);
            assign tmp_int_n   [num] = Secondary[num].INT_n    & ((num < COUNT-1) ? tmp_int_n   [num + 1] : 1);
            assign tmp_wait_n  [num] = Secondary[num].WAIT_n   & ((num < COUNT-1) ? tmp_wait_n  [num + 1] : 1);
        end
    endgenerate

    if(USE_FF) begin
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n || !Primary.RESET_n) begin
                Primary.DOUT     <= 0;
                Primary.BUSDIR_n <= 1;
                Primary.INT_n    <= 1;
                Primary.WAIT_n   <= 1;
            end
            else begin
                Primary.DOUT     <= tmp_dout    [0];
                Primary.BUSDIR_n <= tmp_busdir_n[0];
                Primary.INT_n    <= tmp_int_n   [0];
                Primary.WAIT_n   <= tmp_wait_n  [0];
            end
        end
    end
    else begin
        assign Primary.DOUT     = tmp_dout    [0];
        assign Primary.BUSDIR_n = tmp_busdir_n[0];
        assign Primary.INT_n    = tmp_int_n   [0];
        assign Primary.WAIT_n   = tmp_wait_n  [0];
    end

endmodule

`default_nettype wire
