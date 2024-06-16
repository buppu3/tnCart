//
// spi.sv
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
 * SPI interface
 ***********************************************************************/
interface SPI_IF #(parameter MOSI_BIT_WIDTH = 8, MISO_BIT_WIDTH = 8, LEN_BIT_WIDTH = 8);
    logic [MOSI_BIT_WIDTH-1:0]  MOSI;   // MOSI データ
    logic [MISO_BIT_WIDTH-1:0]  MISO;   // MISO データ
    logic [LEN_BIT_WIDTH-1:0]   LEN;    // 転送ビット数
    logic                       REQ;    // 転送要求
    logic                       BUSY;   // ビジー信号
    logic                       CS_n;   // CS 信号

    // ホスト側ポート
    modport HOST(
                    output MOSI, LEN, REQ, CS_n,
                    input  MISO, BUSY
                );

    // SPI デバイス側ポート
    modport DEVICE(
                    input  MOSI, LEN, REQ, CS_n,
                    output MISO, BUSY
                );
endinterface

/***********************************************************************
 * SPI モジュール
 ***********************************************************************/
module SPI #(
    parameter   CLK_DIV = 2'd1          // 分周比
)(
    input   wire        CLK,            // 駆動クロック
    input   wire        RESET_n,        // リセット信号

    SPI_IF.DEVICE       SPI_Interface,  // SPI インターフェース

    // SPI ポート
    output  wire        SCLK,           // SCLK ポート
    output  wire        MOSI,           // MOSI ポート
    input   wire        MISO,           // MISO ポート
    output  wire        CS_n            // CS ポート
);
    localparam          CLK_DIV_BIT_WIDTH = $clog2((CLK_DIV) + 1);

    /***************************************************************
     * 
     ***************************************************************/
    assign              SPI_Interface.BUSY = state != STATE_IDLE;

    /***************************************************************
     * buffer
     ***************************************************************/
    reg                 ff_req[0:1];

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            ff_req[0] <= 0;
            ff_req[1] <= 0;
        end else begin
            ff_req[0] <= SPI_Interface.REQ;
            ff_req[1] <= ff_req[0];
        end
    end

    /***************************************************************
     * transfer
     ***************************************************************/
    enum logic [1:0] {
        STATE_IDLE,
        STATE_XFER,
        STATE_WAIT
    } state;
    reg [$bits(SPI_Interface.LEN)-1:0]      remain;     // 残りビット数
    reg [CLK_DIV_BIT_WIDTH-1:0]             div_cnt;    // 分周カウンタ
    reg [$bits(SPI_Interface.MOSI)-1:0]     o_shift;    // シフトレジスタ
    reg [$bits(SPI_Interface.MISO)-1:0]     i_shift;    // シフトレジスタ

    reg                     sclk_ff;
    reg                     mosi_ff;
    assign                  SCLK = sclk_ff;
    assign                  MOSI = mosi_ff;
    assign                  CS_n = SPI_Interface.CS_n;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            state <= STATE_IDLE;
            sclk_ff <= 1'b0;
            remain <= 0;
            div_cnt <= 0;
            SPI_Interface.MISO <= 0;

        end else begin
            if(state == STATE_IDLE)
            begin
                if(ff_req[1])
                begin
                    state <= STATE_XFER;

                    sclk_ff <= 1'b0;
                    mosi_ff <= SPI_Interface.MOSI[$bits(SPI_Interface.MOSI)-1];

                    o_shift <= SPI_Interface.MOSI;
                    remain <= SPI_Interface.LEN;

                    div_cnt <= 0;
                end
            end else if(state == STATE_XFER)
            begin
                if(div_cnt != CLK_DIV)
                begin
                    div_cnt <= div_cnt + 1'd1;

                end else begin
                    div_cnt <= 0;

                    if(SCLK)
                    begin
                        // fall clock
                        sclk_ff <= 1'b0;

                        if(remain == 0)
                        begin
                            SPI_Interface.MISO <= i_shift;
                            state <= STATE_WAIT;
                        end else begin
                            mosi_ff <= o_shift[$bits(o_shift)-1];
                        end
                    end else begin
                        // rise clock
                        sclk_ff <= 1'b1;

                        // bit shift output buffer
                        o_shift <= { o_shift[$bits(o_shift)-2:0], 1'b0 };

                        // bit shift input buffer
                        i_shift <= { i_shift[$bits(i_shift)-2:0], MISO };

                        // decriment remain counter
                        remain <= remain - 1'd1;
                    end
                end
            end else begin
                if(!ff_req[1])
                begin
                    state <= STATE_IDLE;
                end
            end
        end
    end
endmodule

`default_nettype wire
