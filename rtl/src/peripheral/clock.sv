//
// main.sv
//
// BSD 3-Clause License
// 
// Copyright (c) 2025, Shinobu Hashimoto
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

interface CLOCK_IF;
    // メモリクロック(128.86MHz/129.6MHz)
    logic   MEM_READY;
    logic   MEM_CLK;

    // 動作クロック(128.86MHz/129.6MHz)
    logic   OP_READY;
    logic   OP_CLK;             // メイン動作用クロック
    logic   OP_PSG_EN;
    logic   OP_SCC_EN;
    logic   OP_OPLL_EN;

    //
    logic   VDP_CLK;            // VDP モジュール動作クロック

    //
    logic   OPLL_CLK;           // OPLL モジュール動作クロック
    logic   OPLL_4M_EN;         // OPLL モジュール基準クロック

    //
    logic   PSG_CLK;            // PSG モジュール動作クロック
    logic   PSG_4M_EN;          // PSG モジュール基準クロック

    //
    logic   SCC_CLK;            // SCC モジュール動作クロック
    logic   SCC_4M_EN;          // SCC モジュール基準クロック

    //
    logic   LED_CLK;            // LED モジュール動作クロック
    logic   LED_ENA;            // LED カウンタ CE

    //
    logic   DAC_CLK;            // DAC モジュール動作クロック
    logic   DAC_ENA;            // DAC CE

    //
    logic   TMDS_READY;
    logic   TMDS_S_CLK;
    logic   TMDS_P_CLK;

    modport SRC (
                    input MEM_READY, MEM_CLK,
                    input OP_READY, OP_CLK, OP_PSG_EN, OP_SCC_EN, OP_OPLL_EN,
                    input VDP_CLK,
                    input PSG_CLK, PSG_4M_EN,
                    input OPLL_CLK, OPLL_4M_EN,
                    input SCC_CLK, SCC_4M_EN,
                    input LED_CLK, LED_ENA,
                    input DAC_CLK, DAC_ENA,
                    input TMDS_READY, TMDS_S_CLK, TMDS_P_CLK
                );

    modport DST (
                    output MEM_READY, MEM_CLK,
                    output OP_READY, OP_CLK, OP_PSG_EN, OP_SCC_EN, OP_OPLL_EN,
                    output VDP_CLK,
                    output PSG_CLK, PSG_4M_EN,
                    output OPLL_CLK, OPLL_4M_EN,
                    output SCC_CLK, SCC_4M_EN,
                    output LED_CLK, LED_ENA,
                    output DAC_CLK, DAC_ENA,
                    output TMDS_READY, TMDS_S_CLK, TMDS_P_CLK
                );
endinterface

`default_nettype wire
