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
    parameter COUNT         = 2,
    parameter DIV           = 30,       // 3.58MHz の分周値
    parameter DELAY         = 5,        // 3.58MHz クロックエッジからメモリアクセスまでのディレイ
    parameter SYNC_CLK_EN   = 1         // CLK_EN で同期をとる
) (
    input   wire            RESET_n,
    input   wire            CLK,
    input   wire            CLK_EN,
    RAM_IF.HOST             Primary,
    RAM_IF.DEVICE           Secondary[0:COUNT-1],
    UMA_IF.DEVICE           Uma
);
    localparam CLK_OFFSET = 7'd2;    // TIMING より 2clk 速く CLK_EN を出力
    localparam DIV14MHz = 15;
    localparam DIV21MHz = 5;
    localparam DIV25MHz = 13;

    localparam MRAM_EXEC_DELAY = 1;
    localparam VRAM_EXEC_DELAY = 2;

    /***************************************************************
     * 3.58MHz に同期して 10.74MHz 毎にメモリ切り替え
     ***************************************************************/
    localparam DIVCNT_TOP   = (DELAY);

    localparam DIVCNT_25M_0 = (DIVCNT_TOP + DIV * 0 / 7);
    localparam DIVCNT_25M_1 = (DIVCNT_TOP + DIV * 1 / 7);
    localparam DIVCNT_25M_2 = (DIVCNT_TOP + DIV * 2 / 7);
    localparam DIVCNT_25M_3 = (DIVCNT_TOP + DIV * 3 / 7);
    localparam DIVCNT_25M_4 = (DIVCNT_TOP + DIV * 4 / 7);
    localparam DIVCNT_25M_5 = (DIVCNT_TOP + DIV * 5 / 7);
    localparam DIVCNT_25M_6 = (DIVCNT_TOP + DIV * 6 / 7);

    localparam DIVCNT_21M_0 = (DIVCNT_TOP + DIV * 0 / 6);
    localparam DIVCNT_21M_1 = (DIVCNT_TOP + DIV * 1 / 6);
    localparam DIVCNT_21M_2 = (DIVCNT_TOP + DIV * 2 / 6);
    localparam DIVCNT_21M_3 = (DIVCNT_TOP + DIV * 3 / 6);
    localparam DIVCNT_21M_4 = (DIVCNT_TOP + DIV * 4 / 6);
    localparam DIVCNT_21M_5 = (DIVCNT_TOP + DIV * 5 / 6);

    localparam DIVCNT_14M_0 = (DIVCNT_TOP + DIV * 0 / 4);
    localparam DIVCNT_14M_1 = (DIVCNT_TOP + DIV * 1 / 4);
    localparam DIVCNT_14M_2 = (DIVCNT_TOP + DIV * 2 / 4);
    localparam DIVCNT_14M_3 = (DIVCNT_TOP + DIV * 3 / 4);

    localparam DIVCNT_10M_0 = (DIVCNT_TOP + DIV * 0 / 3);
    localparam DIVCNT_10M_1 = (DIVCNT_TOP + DIV * 1 / 3);
    localparam DIVCNT_10M_2 = (DIVCNT_TOP + DIV * 2 / 3);

    logic [$clog2(DIV)-1:0] mem_cnt;
if(SYNC_CLK_EN) begin
    // MSX の 3.58MHz に同期
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                  mem_cnt <= 0;
        else if(CLK_EN)               mem_cnt <= 0;
        else if(mem_cnt != (DIV - 1)) mem_cnt <= mem_cnt + 1'd1;
    end
end
else begin
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                  mem_cnt <= 0;
        else if(mem_cnt == (DIV - 1)) mem_cnt <= 0;
        else                          mem_cnt <= mem_cnt + 1'd1;
    end
end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                                    Uma.CLK25M_EN <= 0;
        else if(mem_cnt == (DIVCNT_25M_0 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_1 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_2 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_3 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_4 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_5 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else if(mem_cnt == (DIVCNT_25M_6 - CLK_OFFSET)) Uma.CLK25M_EN <= 1;
        else                                            Uma.CLK25M_EN <= 0;
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                                    Uma.CLK21M_EN <= 0;
        else if(mem_cnt == (DIVCNT_21M_0 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == (DIVCNT_21M_1 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == (DIVCNT_21M_2 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == (DIVCNT_21M_3 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == (DIVCNT_21M_4 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else if(mem_cnt == (DIVCNT_21M_5 - CLK_OFFSET)) Uma.CLK21M_EN <= 1;
        else                                            Uma.CLK21M_EN <= 0;
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                                    Uma.CLK14M_EN <= 0;
        else if(mem_cnt == (DIVCNT_14M_0 - CLK_OFFSET)) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == (DIVCNT_14M_1 - CLK_OFFSET)) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == (DIVCNT_14M_2 - CLK_OFFSET)) Uma.CLK14M_EN <= 1;
        else if(mem_cnt == (DIVCNT_14M_3 - CLK_OFFSET)) Uma.CLK14M_EN <= 1;
        else                                            Uma.CLK14M_EN <= 0;
    end

    logic timing_toggle;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Secondary[0].TIMING <= 0;
            Secondary[1].TIMING <= 0;
            timing_toggle <= 0;
        end
        else if(mem_cnt == DIVCNT_10M_0 ||
                mem_cnt == DIVCNT_10M_1 ||
                mem_cnt == DIVCNT_10M_2 ) begin
            Secondary[0].TIMING <= ~timing_toggle;
            Secondary[1].TIMING <= timing_toggle;
            timing_toggle <= ~timing_toggle;
        end
        else begin
            Secondary[0].TIMING <= 0;
            Secondary[1].TIMING <= 0;
        end
    end

    /***************************************************************
     * 処理完了タイミング
     ***************************************************************/
    wire done = Secondary[0].TIMING || Secondary[1].TIMING;

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
                else if(det_we[process_ch]) save_din_size[process_ch] <= Secondary[process_ch].DIN_SIZE;
            end

            // Primary へ渡すパラメータ
            assign req_addr[process_ch]     = (det_oe[process_ch] || det_we[process_ch]) ? Secondary[process_ch].ADDR     : save_addr[process_ch];
            assign req_din[process_ch]      =  det_we[process_ch]                        ? Secondary[process_ch].DIN      : save_din[process_ch];
            assign req_din_size[process_ch] =  det_we[process_ch]                        ? Secondary[process_ch].DIN_SIZE : save_din_size[process_ch];

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
