//
// uma.sv
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

interface UMA_IF #(parameter COUNT = 2);
    logic [23:0]    ADDR[0:COUNT-1];    // アドレスオフセット
    logic CLK14M_EN;
    logic CLK21M_EN;
    logic CLK25M_EN;

    // ホスト側ポート
    modport HOST (
                    output ADDR
                );

    // ホスト側ポート
    modport CLK (
                    input CLK14M_EN, CLK21M_EN, CLK25M_EN
                );

    // メモリ側ポート
    modport DEVICE (
                    input  ADDR,
                    output CLK14M_EN, CLK21M_EN, CLK25M_EN
                );
endinterface

module UMA #(
    parameter COUNT         = 2
) (
    input   wire            RESET_n,
    input   wire            CLK,
    input   wire            CLK_3_58M,
    input   wire            WAIT_EN,
    RAM_IF.HOST             Primary,
    RAM_IF.DEVICE           Secondary[0:COUNT-1],
    UMA_IF.DEVICE           Uma
);
    localparam CLK_OFFSET = 7'd2;    // TIMING より 2clk 速く CLK_EN を出力

    localparam MRAM_EXEC_DELAY = 2;
    localparam VRAM_EXEC_DELAY = 2;

    /***************************************************************
     * 3.58MHz に同期して 10.74MHz 毎にメモリ切り替え
     *
     * 108MHz         ~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_~_
     * CLK_3_58M      ~~______________________________~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~______________________________~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~____________________________
     * mem_cnt            0 1 2 3 4 5 6 7 8 9101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585900
     * CLK21M_EN      _____~~________~~________~~________~~________~~________~~________~~________~~________~~________~~________~~________~~________~~________~~________~~___
     * CLK14M_EN      _____~~______________~~____________~~______________~~____________~~______________~~____________~~______________~~____________~~______________~~_______
     * S[0].TIMING    _____________________________~~______________________________________~~______________________________________________________________________________~
     * S[1].TIMING    _________~~______________________________________~~______________________________________~~______________________________________~~___________________
     * done_timing    _____________________________~~__________________~~__________________~~__________________~~__________________~~_______________________________________
     * exec_timing[0] _________________________________~~______________________________________~~___________________________________________________________________________
     * exec_timing[1] _____________~~______________________________________~~______________________________________~~______________________________________~~_______________
     * done           _________________________________~~__________________~~__________________~~__________________~~__________________~~___________________________________
     * SDRAM access   --------------[VRAM              ][CPU               ][VRAM              ][CPU               ][VRAM              ]--------------------[VRAM              ]     
     *
     ***************************************************************/
    // カウンタリセット条件
    wire mem_cnt_rst = mem_cnt > 6'd56 && !CLK_3_58M;

    // counter
    logic [5:0] mem_cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)              mem_cnt <= 0;
        else if(mem_cnt_rst)      mem_cnt <= 0;
        else if(mem_cnt != 6'd63) mem_cnt <= mem_cnt + 1'd1;
    end

    // 25MHz 生成
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)               Uma.CLK25M_EN <= 0;
    end

    // 21.6MHz 生成
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                     Uma.CLK21M_EN <= 0;
        else if(mem_cnt == 6'd 0 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd 5 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd10 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd15 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd20 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd25 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd30 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd35 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd40 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd45 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd50 - 6'd0) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == 6'd55 - 6'd0) Uma.CLK21M_EN <= 1;
        else                             Uma.CLK21M_EN <= 0;
    end

    // 14.4MHz 生成
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                     Uma.CLK14M_EN <= 0;
        else if(mem_cnt == 6'd 0 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd 8 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd15 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd23 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd30 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd38 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd45 - 6'd0) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == 6'd53 - 6'd0) Uma.CLK14M_EN <= 1;
        else                             Uma.CLK14M_EN <= 0;
    end

    // CPU メモリタイミング生成
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) Secondary[0].TIMING <= 0;
        else         Secondary[0].TIMING <= (mem_cnt == (6'd10 + CLK_OFFSET) || mem_cnt == (6'd30 + CLK_OFFSET));
    end

    // VRAM メモリタイミング生成
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) Secondary[1].TIMING <= 0;
        else         Secondary[1].TIMING <= (mem_cnt == (6'd0 + CLK_OFFSET) || mem_cnt == (6'd20 + CLK_OFFSET) || mem_cnt == (6'd40 + CLK_OFFSET));
    end

    /***************************************************************
     * 処理完了タイミング
     ***************************************************************/
    logic done_timing;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) done_timing <= 0;
        else         done_timing <= (mem_cnt == (6'd10 + CLK_OFFSET) || mem_cnt == (6'd20 + CLK_OFFSET) || mem_cnt == (6'd30 + CLK_OFFSET) || mem_cnt == (6'd40 + CLK_OFFSET) || mem_cnt == (6'd50 + CLK_OFFSET));
    end

    logic [1:0] done_timing_buff;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) done_timing_buff <= 0;
        else         done_timing_buff <= {done_timing_buff[$bits(done_timing_buff)-2:0], done_timing};
    end

    //wire done = exec_timing[0] || exec_timing[1];
    wire done = done_timing_buff[VRAM_EXEC_DELAY-1];

    /***************************************************************
     * 切り替えの 1クロック後に RAM へデータ送信
     ***************************************************************/
    wire                               exec_timing[0:COUNT-1];   // TIMING 1~2クロック遅延
    reg                                done_delay;               // done 1クロック遅延
    reg                                processing[0:COUNT-1];    // 処理中フラグ
    reg                                done_ch[0:COUNT-1];       // 処理完了フラグ
    reg                                prev_oe_n[0:COUNT-1];     // 1クロック前の OE_n
    reg                                prev_we_n[0:COUNT-1];     // 1クロック前の WE_n
    reg                                prev_rfsh_n[0:COUNT-1];   // 1クロック前の RFSH_n
    reg                                save_oe[0:COUNT-1];       // OE 要求の保持
    reg                                save_we[0:COUNT-1];       // WE 要求の保持
    reg                                save_rfsh[0:COUNT-1];     // RFSH 要求の保持
    reg [$bits(Primary.ADDR)-1:0]      save_addr[0:COUNT-1];     // OE_n, WE_n エッジ検出時の ADDR を保持
    reg [$bits(Primary.DIN)-1:0]       save_din[0:COUNT-1];      // WE_n エッジ検出時の DIN を保持
    reg [$bits(Primary.DIN_SIZE)-1:0]  save_din_size[0:COUNT-1]; // WE_n エッジ検出時の DIN_SIZE を保持
    wire                               det_oe[0:COUNT-1];        // OE_n の H->L 検出
    wire                               det_we[0:COUNT-1];        // WE_n の H->L 検出
    wire                               det_rfsh[0:COUNT-1];      // RFSH_n の H->L 検出
    wire                               det_any[0:COUNT-1];       // OE_n, WE_n, RFSH_n の H->L 検出
    wire                               req_oe[0:COUNT-1];
    wire                               req_we[0:COUNT-1];
    wire                               req_rfsh[0:COUNT-1];
    wire                               req_any[0:COUNT-1];
    wire [$bits(Primary.ADDR)-1:0]     req_addr[0:COUNT-1];      // Primary へ渡す ADDR 値
    wire [$bits(Primary.DIN)-1:0]      req_din[0:COUNT-1];       // Primary へ渡す DIN 値
    wire [$bits(Primary.DIN_SIZE)-1:0] req_din_size[0:COUNT-1];  // Primary へ渡す DIN_SIZE 値

    reg [1:0]                          exec_timing_buff[0:COUNT-1];
    assign exec_timing[0] = exec_timing_buff[0][MRAM_EXEC_DELAY-1]; // MainRam は 1CLK 遅延
    assign exec_timing[1] = exec_timing_buff[1][VRAM_EXEC_DELAY-1]; // VideoRam は 2CLK 遅延

    generate
        genvar process_ch;
        for(process_ch = 0; process_ch < COUNT; process_ch = process_ch + 1) begin: process
            // RAM 転送タイミング
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) exec_timing_buff[process_ch] <= 0;
                else         exec_timing_buff[process_ch] <= {exec_timing_buff[process_ch][$bits(exec_timing_buff[process_ch])-2:0], Secondary[process_ch].TIMING};
            end

            // OE_n 遅延
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) prev_oe_n[process_ch] <= 1;
                else         prev_oe_n[process_ch] <= Secondary[process_ch].OE_n;
            end

            // WE_n 遅延
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) prev_we_n[process_ch] <= 1;
                else         prev_we_n[process_ch] <= Secondary[process_ch].WE_n;
            end

            // RFSH_n 遅延
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) prev_rfsh_n[process_ch] <= 1;
                else         prev_rfsh_n[process_ch] <= Secondary[process_ch].RFSH_n;
            end

            // OE_n の H->L 検出
            assign det_oe[process_ch] = prev_oe_n[process_ch] && !Secondary[process_ch].OE_n;

            // WE_n の H->L 検出
            assign det_we[process_ch] = prev_we_n[process_ch] && !Secondary[process_ch].WE_n;

            // RFSH_n の H->L 検出
            assign det_rfsh[process_ch] = prev_rfsh_n[process_ch] && !Secondary[process_ch].RFSH_n;

            // OE_n, WE_n, RFSH_n のいずれかのエッジを検出
            assign det_any[process_ch] = det_we[process_ch] || det_oe[process_ch] || det_rfsh[process_ch];

            // OE 要求フラグ
            assign req_oe[process_ch] = det_oe[process_ch] || save_oe[process_ch];

            // WE 要求フラグ
            assign req_we[process_ch] = det_we[process_ch] || save_we[process_ch];

            // RFSH 要求フラグ
            assign req_rfsh[process_ch] = det_rfsh[process_ch] || save_rfsh[process_ch];

            // OE, WE, RFSH いずれかの要求フラグ
            assign req_any[process_ch] = req_we[process_ch] || req_oe[process_ch] || req_rfsh[process_ch];

            // 各 ch の処理完了フラグ
            assign done_ch[process_ch] = done && processing[process_ch];

            // 処理中フラグ更新
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                            processing[process_ch] <= 0;
                else if(exec_timing[process_ch] && req_any[process_ch]) processing[process_ch] <= 1;
                else if(done_ch[process_ch])                            processing[process_ch] <= 0;
            end

            // DOUT 格納
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                 Secondary[process_ch].DOUT <= 0;
                else if(done_ch[process_ch]) Secondary[process_ch].DOUT <= Primary.DOUT;
            end

            // ACK_n 更新
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                         Secondary[process_ch].ACK_n <= 1;
                else if(det_any[process_ch])                         Secondary[process_ch].ACK_n <= 0;  // OE_n, WE_n, RFSH_n エッジ検出で ACK_n = 0
                else if(done_ch[process_ch] && !req_any[process_ch]) Secondary[process_ch].ACK_n <= 1;  // 処理完了で残りの処理がないなら ACK_n = 1
            end

            // WAIT_n 更新
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                      Secondary[process_ch].WAIT_n <= 1;
                else if(!WAIT_EN)                                 Secondary[process_ch].WAIT_n <= 1;
                else if(req_oe[process_ch] || req_we[process_ch]) Secondary[process_ch].WAIT_n <= 0;  // OE_n, WE_n 要求がある場合は WAIT_n = 0
                else if(exec_timing[(process_ch + 1) % COUNT])    Secondary[process_ch].WAIT_n <= 1;  // 次の ch の処理開始時に OE_n, WE_n 要求がないなら WAIT_n = 1
            end

            // OE_n の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                           save_oe[process_ch] <= 0;
                else if(exec_timing[process_ch] && req_oe[process_ch]) save_oe[process_ch] <= 0;        // Primary.OE_n 更新のタイミングでクリア
                else if(det_oe[process_ch])                            save_oe[process_ch] <= 1;        // Secondary.OE_n の立下り検出でセット
            end

            // WE_n の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                           save_we[process_ch] <= 0;
                else if(exec_timing[process_ch] && req_we[process_ch]) save_we[process_ch] <= 0;        // Primary.WE_n 更新のタイミングでクリア
                else if(det_we[process_ch]                           ) save_we[process_ch] <= 1;        // Secondary.WE_n の立下り検出でセット
            end

            // RFSH_n の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                             save_rfsh[process_ch] <= 0;
                else if(exec_timing[process_ch] && req_rfsh[process_ch]) save_rfsh[process_ch] <= 0;    // Primary.RFSH_n 更新のタイミングでクリア
                else if(det_rfsh[process_ch])                            save_rfsh[process_ch] <= 1;    // Secondary.RFSH_n の立下り検出でセット
            end

            // ADDR の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                                      save_addr[process_ch] <= 0;
                else if(det_oe[process_ch] || det_we[process_ch]) save_addr[process_ch] <= Secondary[process_ch].ADDR;
            end

            // DIN の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                save_din[process_ch] <= 0;
                else if(det_we[process_ch]) save_din[process_ch] <= Secondary[process_ch].DIN;
            end

            // DIN_SIZE の保持
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)                save_din_size[process_ch] <= 0;
                else if(det_oe[process_ch] || det_we[process_ch]) save_din_size[process_ch] <= Secondary[process_ch].DIN_SIZE;
            end

            // Primary へ渡すパラメータ
            assign req_addr[process_ch]     = (det_oe[process_ch] || det_we[process_ch]) ? Secondary[process_ch].ADDR     : save_addr[process_ch];
            assign req_din[process_ch]      =  det_we[process_ch]                        ? Secondary[process_ch].DIN      : save_din[process_ch];
            assign req_din_size[process_ch] = (det_oe[process_ch] || det_we[process_ch]) ? Secondary[process_ch].DIN_SIZE : save_din_size[process_ch];

        end
    endgenerate

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Primary.ADDR <= 0;
            Primary.DIN <= 0;
            Primary.DIN_SIZE <= 0;
            Primary.OE_n <= 1;
            Primary.WE_n <= 1;
            Primary.RFSH_n <= 1;
        end
        else if(!Primary.ACK_n) begin
            Primary.OE_n     <= 1;
            Primary.WE_n     <= 1;
            Primary.RFSH_n   <= 1;
        end
        else if(exec_timing[0] && req_any[0]) begin
            Primary.ADDR     <= (req_oe[0] || req_we[0]) ? ((req_addr[0] + Uma.ADDR[0]) & 24'hFFFFFF) : 0;
            Primary.DIN      <= (req_oe[0] || req_we[0]) ? req_din[0] : 0;
            Primary.DIN_SIZE <= (req_oe[0] || req_we[0]) ? req_din_size[0] : 0;
            Primary.OE_n     <= !req_oe[0];
            Primary.WE_n     <= !req_we[0];
            Primary.RFSH_n   <= !req_rfsh[0];
        end
        else if(exec_timing[1] && req_any[1]) begin
            Primary.ADDR     <= (req_oe[1] || req_we[1]) ? ((req_addr[1] + Uma.ADDR[1]) & 24'hFFFFFF) : 0;
            Primary.DIN      <= (req_oe[1] || req_we[1]) ? req_din[1] : 0;
            Primary.DIN_SIZE <= (req_oe[1] || req_we[1]) ? req_din_size[1] : 0;
            Primary.OE_n     <= !req_oe[1];
            Primary.WE_n     <= !req_we[1];
            Primary.RFSH_n   <= !req_rfsh[1];
        end
    end

endmodule

`default_nettype wire
