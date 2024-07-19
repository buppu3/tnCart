//
// t9990_clock.sv
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

/***************************************************************
 * クロック生成
 ***************************************************************/
module T9990_CLOCK (
    // クロック入力
    input wire              RESET_n,            // リセット
    input wire              CLK,                // 動作クロック
    input wire              CLK_21M_EN,         // 21MHz
    input wire              CLK_14M_EN,         // 14MHz
    input wire              CLK_25M_EN,         // 25MHz
    input wire              RAM_REQ,            // メモリアクセスタイミング

    // レジスタ
    T9990_REGISTER_IF.VDP   REG,

    // 出力
    output wire             CLK_MASTER_EN,      // マスタークロック
    output wire             MEM_REQ,            // メモリアクセスタイミング
    output reg              DCLK_EN,            // ドットクロック
    output reg              TG_EN,              // タイミングジェネレータ動作許可
    output reg [2:0]        RESO
);
    // mode DCLK MCS DCKM HSCN C25M
    // B1    5.4  0   0    0    X
    // B2    7.2  1   0    0    X
    // B3   10.7  0   1    0    X
    // B4   14.3  1   1    0    X
    // B5   21.5  X   X    1    0       (unsupport)
    // B6   25.2  X   X    1    1       (unsupport)

    /***************************************************************
     * メモリアクセスタイミングの生成
     ***************************************************************/
    assign MEM_REQ = RAM_REQ;

    /***************************************************************
     * 設定の変更を監視
     ***************************************************************/
    wire [4:0] CONF = { REG.MCS, REG.DCKM, REG.HSCN, REG.C25M };
    logic [4:0] prev_conf;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_conf <= 0;
        else         prev_conf <= CONF;
    end
    wire change_conf = prev_conf != CONF;

    /***************************************************************
     * マスタークロック選択
     ***************************************************************/
    assign CLK_MASTER_EN = (REG.C25M == T9990_REG::C25M_25MHZ ? CLK_25M_EN : (REG.MCS == T9990_REG::MCS_14MHZ ? CLK_14M_EN : CLK_21M_EN));

    /***************************************************************
     * マスタークロックを分周
     ***************************************************************/
    enum logic [1:0] {
        STATE_SYNCING,
        STATE_COMPLETE
    } state;

    // CLM_*M_EN は MEM_REQ より 2clk 早いので、2clk遅延した信号を用意する
    logic [1:0] clk_master_delay;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            clk_master_delay <= 0;
        end
        else begin
            clk_master_delay <= {clk_master_delay[0:0],CLK_MASTER_EN};
        end
    end

    logic [2:0] cnt;
    wire [2:0] DIV = REG.DCKM == T9990_REG::DCKM_DIV4 ? 3'd3 :
                     REG.DCKM == T9990_REG::DCKM_DIV2 ? 3'd1 :
                     REG.DCKM == T9990_REG::DCKM_DIV1 ? 3'd0 : 3'd0;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            cnt <= 3;
            DCLK_EN <= 0;
            state <= STATE_SYNCING;
            TG_EN <= 0;
        end

        else if(state == STATE_SYNCING || change_conf) begin
            // MASTER_CLKの2clk遅延した信号と MEM_REQ が同時にきたタイミングから分周開始
            if(clk_master_delay[1] && MEM_REQ) begin
                cnt <= DIV;
                DCLK_EN <= 0;
                TG_EN <= 1;
                state <= STATE_COMPLETE;
            end
            else begin
                cnt <= DIV;
                DCLK_EN <= 0;
                TG_EN <= 0;
                state <= STATE_SYNCING;
            end
        end

        else if(CLK_MASTER_EN) begin
            if(cnt == 0) begin
                cnt <= DIV;
                DCLK_EN <= 1;   // MEM_REQ より 1clk 早く　DCLK を出力
            end
            else begin
                cnt <= cnt - 1'd1;
                DCLK_EN <= 0;
            end
        end
        else begin
            DCLK_EN <= 0;
        end
    end

    /***************************************************************
     * RESO
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
        end
        else if(REG.HSCN) begin
            RESO <= REG.C25M ? T9990::RESO_B6 : T9990::RESO_B5;
        end
        else if(REG.MCS) begin
            RESO <= REG.DCKM == T9990_REG::DCKM_DIV2 ? T9990::RESO_B4 : T9990::RESO_B2;
        end
        else begin
            RESO <= REG.DCKM == T9990_REG::DCKM_DIV2 ? T9990::RESO_B3 : T9990::RESO_B1;
        end
    end
endmodule

`default_nettype wire
