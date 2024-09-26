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
    localparam [1:0]    DIN_SIZE_8  = 2'b00;
    localparam [1:0]    DIN_SIZE_16 = 2'b01;
    localparam [1:0]    DIN_SIZE_32 = 2'b10;
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
    logic [1:0]                 DIN_SIZE;       // ライトデータサイズ
    logic                       TIMING;         // メモリアクセスタイミング信号

    // ホスト側ポート
    modport HOST (
                    output ADDR, OE_n, WE_n, RFSH_n, DIN, DIN_SIZE,
                    input  DOUT, ACK_n, TIMING
                );

    // メモリ側ポート
    modport DEVICE (
                    input  ADDR, OE_n, WE_n, RFSH_n, DIN, DIN_SIZE,
                    output DOUT, ACK_n, TIMING
                );

    // ダミー接続
    function automatic void connect_dummy();
        ADDR = 0;
        DIN = 0;
        DIN_SIZE = 0;
        OE_n = 1;
        WE_n = 1;
        RFSH_n = 1;
    endfunction
endinterface

/***************************************************************
 * RAM を拡張
 ***************************************************************/
module EXPANSION_RAM #(
    parameter               COUNT = 4,
    parameter               USE_FF = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,

    RAM_IF.HOST             Primary,
    RAM_IF.DEVICE           Secondary[0:COUNT-1]
);

    /***************************************************************
     * Secondary へ接続
     ***************************************************************/
    wire [$bits(Primary.ADDR)-1:0]      tmp_addr    [0:COUNT-1];
    wire [$bits(Primary.DIN)-1:0]       tmp_din     [0:COUNT-1];
    wire [$bits(Primary.DIN_SIZE)-1:0]  tmp_din_size[0:COUNT-1];
    wire       tmp_oe_n     [0:COUNT-1];
    wire       tmp_we_n     [0:COUNT-1];
    wire       tmp_rfsh_n   [0:COUNT-1];
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: sec
            if(USE_FF) begin
                always_ff @(posedge CLK or negedge RESET_n) begin
                    if(!RESET_n) begin
                        Secondary[num].DOUT    <= 0;
                        Secondary[num].ACK_n   <= 1;
                        Secondary[num].TIMING  <= 0;
                    end
                    else begin
                        Secondary[num].DOUT    <= Primary.DOUT;
                        Secondary[num].ACK_n   <= Primary.ACK_n;
                        Secondary[num].TIMING  <= Primary.TIMING;
                    end
                end
            end
            else begin
                assign Secondary[num].DOUT    = Primary.DOUT;
                assign Secondary[num].ACK_n   = Primary.ACK_n;
                assign Secondary[num].TIMING  = Primary.TIMING;
            end

            assign tmp_addr    [num] = Secondary[num].ADDR     | ((num < COUNT-1) ? tmp_addr    [num + 1] : 0);
            assign tmp_din     [num] = Secondary[num].DIN      | ((num < COUNT-1) ? tmp_din     [num + 1] : 0);
            assign tmp_din_size[num] = Secondary[num].DIN_SIZE | ((num < COUNT-1) ? tmp_din_size[num + 1] : 0);
            assign tmp_oe_n    [num] = Secondary[num].OE_n     & ((num < COUNT-1) ? tmp_oe_n    [num + 1] : 1);
            assign tmp_we_n    [num] = Secondary[num].WE_n     & ((num < COUNT-1) ? tmp_we_n    [num + 1] : 1);
            assign tmp_rfsh_n  [num] = Secondary[num].RFSH_n   & ((num < COUNT-1) ? tmp_rfsh_n  [num + 1] : 1);
        end
    endgenerate

    if(USE_FF) begin
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                Primary.ADDR   <= 0;
                Primary.DIN    <= 0;
                Primary.DIN_SIZE<= RAM::DIN_SIZE_8;
                Primary.OE_n   <= 1;
                Primary.WE_n   <= 1;
                Primary.RFSH_n <= 1;
            end
            else begin
                Primary.ADDR     <= tmp_addr[0];
                Primary.DIN      <= tmp_din[0];
                Primary.DIN_SIZE <= tmp_din_size[0];
                Primary.OE_n     <= tmp_oe_n[0];
                Primary.WE_n     <= tmp_we_n[0];
                Primary.RFSH_n   <= tmp_rfsh_n[0];
            end
        end
    end
    else begin
        assign Primary.ADDR     = tmp_addr[0];
        assign Primary.DIN      = tmp_din[0];
        assign Primary.DIN_SIZE = tmp_din_size[0];
        assign Primary.OE_n     = tmp_oe_n[0];
        assign Primary.WE_n     = tmp_we_n[0];
        assign Primary.RFSH_n   = tmp_rfsh_n[0];
    end

endmodule

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
    assign Primary.DIN_SIZE = Secondary.DIN_SIZE;
    assign Secondary.DOUT   = Primary.DOUT;
    assign Secondary.ACK_n  = Primary.ACK_n;
    assign Secondary.TIMING = Primary.TIMING;

endmodule

`default_nettype wire
