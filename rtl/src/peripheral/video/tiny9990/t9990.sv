//
// t9990.sv
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

package T9990;
    // RESO
    localparam [2:0] RESO_B1 = 3'd0;    // 256x212
    localparam [2:0] RESO_B2 = 3'd1;    // 384x240
    localparam [2:0] RESO_B3 = 3'd2;    // 512x212
    localparam [2:0] RESO_B4 = 3'd3;    // 768x240
    localparam [2:0] RESO_B5 = 3'd4;    // 640x400
    localparam [2:0] RESO_B6 = 3'd5;    // 640x480
endpackage

/***********************************************************************
 * tiny9990
 ***********************************************************************/
module T9990 (
    input wire          RESET_n,            // リセット
    input wire          CLK,                // 動作クロック
    input wire          CLK_21M_EN,         // 21MHz タイミング入力
    input wire          CLK_14M_EN,         // 14MHz タイミング入力
    input wire          CLK_25M_EN,         // 25MHz タイミング入力(未対応)

    // CPU I/F
    input wire          CSR_n,
    input wire          CSW_n,
    input wire [3:0]    MODE,
    input wire [7:0]    CD_IN,
    output wire [7:0]   CD_OUT,
    output wire         WAIT_n,
    output wire         INT0_n,
    output wire         INT1_n,
    output wire         DREQ_n,
    output wire         VMREQ_n,

    // RAM I/F
    input wire          RAM_REQ,            // RAM アクセスタイミング時に 1 を入力
    input wire          RAM_ACK_n,          // RAM アクセス完了時に 1 を入力
    output wire         RAM_OE_n,           // 読み出し要求
    output wire         RAM_WE_n,           // 書き込み要求
    output wire         RAM_RFSH_n,         // リフレッシュ要求
    output wire [18:0]  RAM_ADDR,           // RAM のアドレス
    output wire [31:0]  RAM_DIN,            // RAM へ書くデータが出力される
    output wire [1:0]   RAM_DIN_SIZE,       // アクセスのビット幅 0=8bit, 2=32bit
    input wire [31:0]   RAM_DOUT,           // RAM から読んだデータ

    // ビデオ出力
    output wire         HS,                 // HSYNC(正論理)
    output wire         VS,                 // VSYNC(正論理)
    output wire [4:0]   R,                  // R
    output wire [4:0]   G,                  // G
    output wire [4:0]   B,                  // B
    output wire         Ys,                 // Ys
    output wire         DCLK_EN,            // ドットクロックエッジ
    output wire [2:0]   RESO,               // 解像度
    output wire         IL,                 // インターレースモード
    output wire         EO                  // 奇数/偶数
);

//`define DISABLE_SP
//`define DISABLE_P1A
//`define DISABLE_P1B
//`define DISABLE_BD

    /***************************************************************
     * ソフトウェアリセット
     ***************************************************************/
    reg rst_ff;
    wire rst_flag = rst_ff;
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            rst_ff <= 0;
        end
        else if(REG.SRS) begin
            rst_ff <= 0;
        end
        else if(CSW_n) begin
            rst_ff <= 1;
        end
    end

    /***************************************************************
     * ドットクロック生成
     ***************************************************************/
    logic CLK_MASTER_EN;
    logic MEM_REQ;
    logic TG_EN;
    T9990_CLOCK u_clk (
        .RESET_n(rst_flag),
        .CLK,
        .CLK_21M_EN,
        .CLK_14M_EN,
        .CLK_25M_EN,
        .RAM_REQ,

        // レジスタ
        .REG,

        // 出力
        .CLK_MASTER_EN,
        .MEM_REQ,
        .DCLK_EN,
        .TG_EN,
        .RESO
    );

    /***************************************************************
     * I/Oポート
     ***************************************************************/
    T9990_REGISTER_IF       REG();
    T9990_STATUS_IF         STATUS();
    T9990_P2_CPU_TO_VDP_IF  P2_CPU_TO_VDP();
    T9990_P2_VDP_TO_CPU_IF  P2_VDP_TO_CPU();
    T9990_PALETTE_IF        PAL();

    T9990_PORT u_port (
        .RESET_n(rst_flag),
        .CLK,

        // CPU I/F
        .CSR_n,
        .CSW_n,
        .MODE,
        .CD_IN,
        .CD_OUT,
        .INT0_n,
        .INT1_n,
        .WAIT_n,

        // P#0 I/F
        .CPU_MEM,

        // P#2 I/F
        .P2_CPU_TO_VDP,
        .P2_VDP_TO_CPU,

        // P#1 I/F パレット
        .PAL,

        // レジスタ
        .STATUS,
        .REG,

        //
        .CMD_START
    );

    /***************************************************************
     * モード設定に従ってモジュールの動作を禁止する
     ***************************************************************/
    logic SP_DISABLE;
    logic PA_DISABLE;
    logic PB_DISABLE;
    logic BP_DISABLE;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            SP_DISABLE <= 1;
            PA_DISABLE <= 1;
            PB_DISABLE <= 1;
            BP_DISABLE <= 1;
        end

        // no display
        else if(!REG.DISP) begin
            SP_DISABLE <= 1;
            PA_DISABLE <= 1;
            PB_DISABLE <= 1;
            BP_DISABLE <= 1;
        end

        // P1
        else if(REG.DSPM == T9990_REG::DSPM_P1) begin
            SP_DISABLE <= REG.SPD;
            PA_DISABLE <= 0;
            PB_DISABLE <= 0;
            BP_DISABLE <= 1;
        end

        // P2
        else if(REG.DSPM == T9990_REG::DSPM_P2) begin
            SP_DISABLE <= REG.SPD;
            PA_DISABLE <= 0;
            PB_DISABLE <= 1;
            BP_DISABLE <= 1;
        end

        // Bx
        else begin
            SP_DISABLE <= REG.SPD;
            PA_DISABLE <= 1;
            PB_DISABLE <= 1;
            BP_DISABLE <= 0;
        end
    end

    /***************************************************************
     * タイミング生成
     ***************************************************************/
    T9990_MEM_TIMING MEM_TIMING();
    logic hs;
    logic vs;
    logic HD;
    logic VD;

    logic SPR_START;
    logic [8:0] SPR_Y;

    logic BG_START;
    logic [9:0] BG_X;
    logic [8:0] BG_Y;

    T9990_TIMING u_tg (
        .RESET_n(rst_flag),
        .CLK,
        .CLK_MASTER_EN,
        .DCLK_EN,
        .TG_EN,

        .MEM_REQ,

        // レジスタ
        .REG,
        .STATUS,

        // ビデオ出力タイミング
        .HD,
        .VD,
        .HS(hs),
        .VS(vs),

        // 現在の座標
        .SPR_START,
        .SPR_Y,
        .BG_START,
        .BG_X,
        .BG_Y,
        .MUX_VDE,
        .MUX_HDE,

        // メモリタイミング
        .MEM(MEM_TIMING)
    );

    /***************************************************************
     * RAM 調停(RAM <= VC/SP/CR/BP/PA/PB)
     ***************************************************************/
    T9990_VC_MEM_IF     VC_MEM();
    T9990_VDP_MEM_IF    SP_MEM();
    T9990_VDP_MEM_IF    BP_MEM();
    T9990_VDP_MEM_IF    PA_MEM();
    T9990_VDP_MEM_IF    PB_MEM();
    T9990_RAM u_ram (
        .RESET_n(rst_flag),
        .CLK,
        .CLK_21M_EN,

        // CPU へ VRAM アクセスを通知
        .VMREQ_n,

        // RAM I/F
        .RAM_OE_n,
        .RAM_WE_n,
        .RAM_RFSH_n,
        .RAM_ADDR,
        .RAM_DIN,
        .RAM_DIN_SIZE,
        .RAM_DOUT,
        .RAM_ACK_n,

        // TIMING
        .TIMING(MEM_TIMING),

        // 各モジュールへのメモリアクセス I/F
        .VC_MEM,    // VDP/CPU
        .SP_MEM,    // SPRITE
        .BP_MEM,    // BITMAP
        .PA_MEM,    // PATTERN A
        .PB_MEM     // PATTERN B
    );

    /***************************************************************
     * RAM 調停(VC <= CMD/CPU)
     ***************************************************************/
    T9990_CPU_MEM_IF CPU_MEM();
    T9990_CMD_MEM_IF CMD_MEM();
    T9990_URB_RAM_VC u_ram_vc (
        .RESET_n(rst_flag),
        .CLK,

        // VC MEM I/F
        .VC_MEM,

        // P#0 I/F
        .CPU_MEM,

        // VDP CMD MEM I/F
        .CMD_MEM
    );

    /***************************************************************
     * VDP COMMAND
     ***************************************************************/
    assign DREQ_n = REG.DMAE ? !STATUS.TR : 1;
    logic        CMD_START;
    T9990_BLIT u_blit (
        .RESET_n(rst_flag),
        .CLK,
        .CLK_EN(CLK_21M_EN),

        // MEM I/F
        .CMD_MEM,

        // P#2 I/F
        .P2_CPU_TO_VDP,
        .P2_VDP_TO_CPU,

        // レジスタ
        .REG,
        .STATUS,

        .START(CMD_START)
    );

    /***************************************************************
     * スプライト
     ***************************************************************/
    logic [1:0] SP_PRI;
    logic [5:0] SP_PA;
`ifndef DISABLE_SP
    T9990_SPRITE u_sp (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,
        .DISABLE(SP_DISABLE),

        // レジスタ
        .REG,

        // 座標
        .FETCH_START(BG_START),
        .OUT_START(SPR_START),
        .VCNT(SPR_Y),

        // MEM I/F
        .MEM(SP_MEM),

        // 出力
        .PRI(SP_PRI),
        .EOR(),
        .PA(SP_PA)
    );
`else
    assign SP_MEM.ADDR = 0;
    assign SP_PRI = 2'b01;
    assign SP_PA  = 0;
`endif

    /***************************************************************
     * P1A/P2
     ***************************************************************/
    logic [1:0] PA_PRI;
    logic [5:0] PA_PA;
`ifndef DISABLE_P1A
    T9990_PATTERN #(
        .IS_B(0),
        .PAT_ADDR(19'h00000),
        .NAME_ADDR(19'h7C000)
    ) u_pa (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,
        .DISABLE(PA_DISABLE),

        // レジスタ
        .REG,
        .SCX(REG.SCAX),
        .SCY(REG.SCAY),

        // 座標
        .START(BG_START),
        .HCNT(BG_X),
        .VCNT(BG_Y),

        // MEM I/F
        .MEM(PA_MEM),

        // 出力
        .PRI(PA_PRI),
        .PA(PA_PA)
    );
`else
    assign PA_MEM.ADDR = 0;
    assign PA_PRI = 2'b01;
    assign PA_PA = 0;
`endif

    /***************************************************************
     * P1B
     ***************************************************************/
    logic [1:0] PB_PRI;
    logic [5:0] PB_PA;
`ifndef DISABLE_P1B
    T9990_PATTERN #(
        .IS_B(1),
        .PAT_ADDR(19'h40000),
        .NAME_ADDR(19'h7E000)
    ) u_pb (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,
        .DISABLE(PB_DISABLE),

        // レジスタ
        .REG,
        .SCX({2'b00, REG.SCBX}),
        .SCY({4'b0000, REG.SCBY}),

        // 座標
        .START(BG_START),
        .HCNT(BG_X),
        .VCNT(BG_Y),

        // MEM I/F
        .MEM(PB_MEM),

        // 出力
        .PRI(PB_PRI),
        .PA(PB_PA)
    );
`else
    assign PB_MEM.ADDR = 0;
    assign PB_PRI = 2'b01;
    assign PB_PA = 0;
`endif

    /***************************************************************
     * BP/BD
     ***************************************************************/
    logic [0:0] BP_PRI;
    logic [5:0] BP_PA;
    logic [15:0] BD_CLR;
`ifndef DISABLE_BD
    T9990_BITMAP u_bp (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,
        .DISABLE(BP_DISABLE),

        // レジスタ
        .REG,
        .SCX(REG.SCAX),
        .SCY(REG.SCAY),

        // 座標
        .START(BG_START),
        .HCNT(BG_X),
        .VCNT(BG_Y),

        // MEM I/F
        .MEM(BP_MEM),

        // 出力
        .PRI(BP_PRI),
        .PA(BP_PA),
        .CLR(BD_CLR)
    );
`else
    assign BP_MEM.ADDR = 0;
    assign BP_PRI = 1;
    assign BP_PA = 0;
    assign BD_CLR = 16'b1_00000_00000_00000;
`endif

    /***************************************************************
     * MUX
     ***************************************************************/
    logic [0:0] MUX_PRI;
    logic [5:0] MUX_PA;
    logic MUX_VDE;
    logic MUX_HDE;
    T9990_PRIORITY u_pri (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,

        // アクティブ期間信号(イレーズ、ボーダー期間以外)
        .MUX_VDE,
        .MUX_HDE,

        // 各モジュールから出力されたデータ
        .SP_DISABLE,    .SP_PRI,    .SP_PA,
        .PA_DISABLE,    .PA_PRI,    .PA_PA,
        .PB_DISABLE,    .PB_PRI,    .PB_PA,
        .BP_DISABLE,    .BP_PRI,    .BP_PA,
        .BDC(REG.BDC),

        // 出力
        .PRI(MUX_PRI),
        .PA(MUX_PA)
    );

    /***************************************************************
     * パレット変換
     ***************************************************************/
    logic [15:0] PAL_CLR;
    T9990_PALETTE u_pal (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,

        // P#1 I/F
        .PAL,

        // 入力
        .START(BG_START),
        .PA(MUX_PA),
        .PRI(MUX_PRI),

        // 出力
        .OUT(PAL_CLR)
    );

    /***************************************************************
     * 色変換
     ***************************************************************/
    logic [15:0] DEC_CLR;
    T9990_COLOR_DECODE u_decode (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,

        // レジスタ
        .REG,

        // 座標
        .HCNT(BG_X),

        // 入力
        .IN(BD_CLR),

        // 出力
        .OUT(DEC_CLR)
    );

    /***************************************************************
     * セレクタ
     ***************************************************************/
    logic [15:0] OUT;
    T9990_SELECTOR u_sel (
        .RESET_n(rst_flag),
        .CLK,
        .DCLK_EN,

        // 入力
        .DA(!STATUS.VR && !STATUS.HR),      // 表示期間(ボーダー含まない)
        .DE(HD && VD),                      // 表示期間(ボーダー含む)
        .IN_HS(hs),                         // HSYNC
        .IN_VS(vs),                         // VSYNC
        .IN_PALETTE(PAL_CLR),               // PALETTE 側画面
        .IN_BITMAP(DEC_CLR),                // BITMAP 側画面

        // 出力
        .OUT_HS(HS),
        .OUT_VS(VS),
        .OUT
    );

    // Ys:R:G:B を分解
    assign Ys = REG.YSE ? OUT[15] : 1;
    assign R = OUT[ 9: 5];
    assign G = OUT[14:10];
    assign B = OUT[ 4: 0];
    assign EO = STATUS.EO;
    assign IL = REG.ILM && REG.EO && !REG.HSCN;

endmodule


`default_nettype wire
