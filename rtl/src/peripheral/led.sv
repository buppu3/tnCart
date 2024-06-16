//
// led.sv
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
 * LED インターフェース
 ***********************************************************************/
interface LED_IF;
    // LED 状態の定義
    typedef enum logic [1:0] {
        LED_STATE_OFF,  // 消灯
        LED_STATE_ON    // 点灯
    } LED_STATE_t;

    LED_STATE_t State;                  // LED の状態

    // ホスト側ポート
    modport HOST        (output State);

    // デバイス側ポート
    modport DEVICE      (input  State);
endinterface

/***********************************************************************
 * LED 制御モジュール
 ***********************************************************************/
module LED #(
    parameter       DELAY = 21_480_000, // 消灯までの遅延[clk]
    parameter       BLINK = 21_480_00   // 点滅周期[clk]
) (
    input   wire    CLK,                // 駆動クロック
    input   wire    RESET_n,            // リセット信号

    LED_IF.DEVICE   LedNextor,          // TF アクセス状態
    LED_IF.DEVICE   LedBoot,            // Boot アクセス状態

    output  reg     LedPort             // LED ポート
);

    /***************************************************************
     * ディレイカウンタ
     ***************************************************************/
    reg [$clog2(DELAY+1)-1:0] delay_count;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            delay_count <= 0;
        end
        else begin
            if(LedNextor.State != LedNextor.LED_STATE_OFF) begin
                delay_count <= DELAY;
            end
            else if(delay_count != 0) begin
                delay_count <= delay_count - 1'd1;
            end
        end
    end

    /***************************************************************
     * 点滅カウンタ
     ***************************************************************/
    reg [$clog2(BLINK+1)-1:0] blink_count;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            blink_count <= 0;
        end
        else begin
            if(LedBoot.State == LedNextor.LED_STATE_OFF) begin
                blink_count <= 0;
            end
            else if(blink_count == BLINK - 1) begin
                blink_count <= 0;
            end
            else begin
                blink_count <= blink_count + 1'd1;
            end
        end
    end

    /***************************************************************
     * LED ON/OFF
     ***************************************************************/
    always_ff @(posedge CLK) begin
        if(LedBoot.State != LedNextor.LED_STATE_OFF) begin
            LedPort <= (blink_count < (BLINK / 2)) ? 1'b1 : 1'b0;
        end
        else begin
            LedPort <= (delay_count != 0) ? 1'b1 : 1'b0;
        end
    end

endmodule

`default_nettype wire
