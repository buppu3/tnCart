//
// video.sv
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

package VIDEO;
    typedef enum logic[2:0] {
        RESOLUTION_B1,
        RESOLUTION_B2,
        RESOLUTION_B3,
        RESOLUTION_B4,
        RESOLUTION_B5,
        RESOLUTION_B6,
        RESOLUTION_720_480
    } RESOLUTION_t;
endpackage

interface VIDEO_IF;
    VIDEO::RESOLUTION_t RESOLUTION;
    logic [7:0] R;
    logic [7:0] G;
    logic [7:0] B;
    logic       HS_n;
    logic       VS_n;
    logic       DCLK;
    logic       HSCAN;      // 0=normal / 1=400,480ラインモード
    logic       INTERLACE;  // 0=normal / 1=縦方向を2倍
    logic       FIELD;      // 0=1st field / 1=2nd field
    modport IN  ( input  RESOLUTION, R, G, B, HS_n, VS_n, DCLK, HSCAN, INTERLACE, FIELD );
    modport OUT ( output RESOLUTION, R, G, B, HS_n, VS_n, DCLK, HSCAN, INTERLACE, FIELD );

    // ダミー出力
    function automatic void connect_dummy();
        R = 0;
        G = 0;
        B = 0;
        HS_n = 1;
        VS_n = 1;
        RESOLUTION = VIDEO::RESOLUTION_720_480;
        DCLK = 0;
    endfunction
endinterface

`default_nettype wire
