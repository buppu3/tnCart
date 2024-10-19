//
// bootloader.sv
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
 * PACインターフェース
 ***********************************************************************/
interface PAC_IF #(parameter FlashBankCount = 8);
    logic                   SramEnable;
    logic [2:0]             FlashBankNumber;    // Flash bank number
    logic                   Busy;

    modport HOST  (input  FlashBankNumber, Busy, output SramEnable);
    modport DEVICE(output FlashBankNumber, Busy, input  SramEnable);

    // ダミー接続
    function automatic void connect_dummy();
        SramEnable = 0;
    endfunction
endinterface

/***********************************************************************
 * 転送モード
 ***********************************************************************/
package XFER;
    typedef enum logic[2:0]{
        XFER_MODE_FILL,
        XFER_MODE_READ_RAM,
        XFER_MODE_FLASH_TO_RAM,
        XFER_MODE_RAM_TO_FLASH,
        XFER_MODE_ERASE,
        XFER_MODE_VERIFY,
        XFER_MODE_FF,
        XFER_MODE_CRC
    } XFER_MODE_t;
endpackage

/***********************************************************************
 * 転送インターフェース
 ***********************************************************************/
interface XFER_IF #(parameter RAM_ADDR_WIDTH = 24, FLASH_ADDR_WIDTH = 24);
    logic   [RAM_ADDR_WIDTH-1:0]    RamAddress;
    logic   [FLASH_ADDR_WIDTH-1:0]  FlashAddress;
    logic   [RAM_ADDR_WIDTH-1:0]    Size;
    logic   [7:0]                   RData;
    logic   [7:0]                   WData;
    XFER::XFER_MODE_t               Mode;
    logic                           Start;
    logic                           Busy;

    modport HOST  (output RamAddress, FlashAddress, Size, Mode, Start, WData, input  Busy, RData);
    modport DEVICE(input  RamAddress, FlashAddress, Size, Mode, Start, WData, output Busy, RData);

    // ダミー接続
    function automatic void connect_dummy();
        RamAddress = 0;
        FlashAddress = 0;
        Size = 0;
        WData = 0;
        Mode = XFER::XFER_MODE_FILL;
        Start = 0;
    endfunction
endinterface

/***************************************************************
 * ブートローダー
 ***************************************************************/
module BOOTLOADER #(
    // FLASH から転送する領域
    parameter               XFER_DST_ADDR = 0,
    parameter               XFER_SIZE = 32768,
    parameter               XFER_SRC_ADDR = 24'h10_0000,

    // ClearMegarom が 1 の時にクリアする領域
    parameter               MEGAROM_CLEAR_ADDR = 0,
    parameter               MEGAROM_CLEAR_SIZE = 32768,

    // クリアする領域
    parameter               RAM_CLEAR_ADDR = 0,
    parameter               RAM_CLEAR_SIZE = 65536,

    //
    parameter [23:0]        PAC_RAM_ADDR = 0,
    parameter [23:0]        PAC_FLASH_ADDR = 0
) (
    input wire              RESET_n,
    input wire              CLK,
    RAM_IF.HOST             Ram,
    FLASH_IF.HOST           Flash,
    LED_IF.HOST             Led,
    XFER_IF.DEVICE          Xfer,
    PAC_IF.DEVICE           PAC,
    input wire              ClearMegarom,
    input wire              BusReset_n,
    input wire              RD_n,
    input wire              WR_n,
    input wire              RFSH_n,
    output wire             WAIT_n,
    output reg              READY
);
    localparam PAC_BANK_SIZE = 8192;
    logic [7:0] pac_crc;

    /***************************************************************
     * メモリ転送
     ***************************************************************/
    XFER_IF XferPrim();
    logic Cooperate;
    logic xfer_wait_n;
    XFER_MEMORY u_xfer (
        .RESET_n,
        .CLK,
        .Cooperate,
        .RD_n,
        .WR_n,
        .RFSH_n,
        .WAIT_n(xfer_wait_n),
        .Flash,
        .Ram,
        .Xfer               (XferPrim)
    );

    /***************************************************************
     * WAIT_n
     ***************************************************************/
    assign WAIT_n = xfer_wait_n && READY;

    /***************************************************************
     * pac detect flag
     ***************************************************************/
    logic pac_detect;
    logic pac_enable_prev;
    logic pac_busy_prev;
    always @(posedge CLK) pac_enable_prev <= PAC.SramEnable;
    always @(posedge CLK) pac_busy_prev <= PAC.Busy;
    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            pac_detect <= 0;
        end
        else if(pac_enable_prev && !PAC.SramEnable) begin
            // PAC.SramEnable が 1->0 で pac_detect を 1 にする
            pac_detect <= 1;
        end
        else if(!pac_busy_prev && PAC.Busy) begin
            // PAC.Busy が 0->1 で pac_detect を 0 にする
            pac_detect <= 0;
        end
    end

    /***************************************************************
     * PAC データがあるフラッシュのアドレス
     ***************************************************************/
    wire [$bits(XferPrim.FlashAddress)-1:0] pac_addr = {PAC_FLASH_ADDR[$bits(XferPrim.FlashAddress)-1:13+$clog2(PAC.FlashBankCount)], PAC.FlashBankNumber[$clog2(PAC.FlashBankCount)-1:0], 13'd0 };

    /***************************************************************
     * 
     ***************************************************************/
    enum logic [4:0] {
        STATE_WAIT_POR = 0,
        STATE_WAIT_BOOT,

        STATE_LOAD_BIOS,

        STATE_CLEAR_MEGAROM,

        STATE_CLEAR_MMAPPER,

        STATE_READ_PAC,
        STATE_READ_PAC_READ,
        STATE_READ_PAC_CRC,
        STATE_READ_PAC_CRC1,
        STATE_READ_PAC_CRC2,
        STATE_READ_PAC_CHECK,

        STATE_CLEAR_PAC,

        STATE_WRITE_PAC,
        STATE_WRITE_PAC_CHECK_VERIFY,
        STATE_WRITE_PAC_SEARCH_FREE,
        STATE_WRITE_PAC_SEARCH_FREE_READ,
        STATE_WRITE_PAC_SEARCH_FREE_CHECK,
        STATE_WRITE_PAC_CALC_CRC,
        STATE_WRITE_PAC_SET_CRC1,
        STATE_WRITE_PAC_SET_CRC2,
        STATE_WRITE_PAC_WRITE,

        STATE_SECONDARY,

        STATE_COMPLETE
    } state;

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            READY <= 0;
            Cooperate <= 0;

            PAC.Busy <= 1;

            Xfer.Busy  <= 0;
            Xfer.RData <= 0;

            XferPrim.Start <= 0;
            state <= STATE_WAIT_POR;

            Led.State <= Led.LED_STATE_ON;

        end
        else if(XferPrim.Start) begin
            // 開始待ち
            if(XferPrim.Busy) begin
                XferPrim.Start <= 0;
            end
        end
        else if(XferPrim.Busy) begin
            // 完了待ち
        end
        else begin
            case (state)
                //------------------------------
                // wait RESET inactive
                //------------------------------
                STATE_WAIT_POR:
                begin
                    if(BusReset_n && RFSH_n && RD_n && WR_n) begin
                        state <= STATE_LOAD_BIOS;
                    end
                end

                STATE_WAIT_BOOT:
                begin
                    if(BusReset_n && RFSH_n && RD_n && WR_n) begin
                        state <= STATE_COMPLETE;
                    end
                    else begin
                        // リセット中に SDRAM の内容が消えないようにリフレッシュ
                        XferPrim.RamAddress <= 0;
                        XferPrim.Mode <= XFER::XFER_MODE_READ_RAM;
                        XferPrim.Start <= 1;
                    end
                end

                //------------------------------
                // LOAD BIOS IMAGE 
                //------------------------------
                STATE_LOAD_BIOS:
                begin
                    XferPrim.RamAddress <= XFER_DST_ADDR;
                    XferPrim.FlashAddress <= XFER_SRC_ADDR;
                    XferPrim.Size <= XFER_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_FLASH_TO_RAM;
                    XferPrim.Start <= 1;
                    state <= STATE_CLEAR_MEGAROM;
                end

                //------------------------------
                // CLEAR MEGAROM 
                //------------------------------
                STATE_CLEAR_MEGAROM:
                begin
                    if(ClearMegarom) begin
                        XferPrim.RamAddress <= MEGAROM_CLEAR_ADDR;
                        XferPrim.Size <= MEGAROM_CLEAR_SIZE;
                        XferPrim.Mode <= XFER::XFER_MODE_FILL;
                        XferPrim.WData <= 8'hFF;
                        XferPrim.Start <= 1;
                        state <= STATE_CLEAR_MMAPPER;
                    end
                    else begin
                        state <= STATE_CLEAR_MMAPPER;
                    end
                end

                //------------------------------
                // CLEAR MMAPPER 
                //------------------------------
                STATE_CLEAR_MMAPPER:
                begin
                    XferPrim.RamAddress <= RAM_CLEAR_ADDR;
                    XferPrim.Size <= RAM_CLEAR_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_FILL;
                    XferPrim.WData <= 8'h00;
                    XferPrim.Start <= 1;
                    state <= STATE_READ_PAC;
                end

                //------------------------------
                // read PAC
                //------------------------------
                STATE_READ_PAC:
                begin
                    PAC.Busy <= 1;
                    PAC.FlashBankNumber <= PAC.FlashBankCount - 1'd1;
                    state <= STATE_READ_PAC_READ;
                end
                STATE_READ_PAC_READ:
                begin
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.FlashAddress <= pac_addr;
                    XferPrim.Size <= PAC_BANK_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_FLASH_TO_RAM;
                    XferPrim.Start <= 1;
                    state <= STATE_READ_PAC_CRC;
                end
                STATE_READ_PAC_CRC:
                begin
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.Size <= PAC_BANK_SIZE - 2;
                    XferPrim.Mode <= XFER::XFER_MODE_CRC;
                    XferPrim.Start <= 1;
                    state <= STATE_READ_PAC_CRC1;
                end
                STATE_READ_PAC_CRC1:
                begin
                    // CRC を保存
                    pac_crc <= XferPrim.RData;

                    // CRC1 を読む
                    XferPrim.RamAddress <= PAC_RAM_ADDR + PAC_BANK_SIZE - 2;
                    XferPrim.Mode <= XFER::XFER_MODE_READ_RAM;
                    XferPrim.Start <= 1;

                    state <= STATE_READ_PAC_CRC2;
                end
                STATE_READ_PAC_CRC2:
                begin
                    if(XferPrim.RData == pac_crc) begin
                        // CRC2 を読む
                        XferPrim.RamAddress <= PAC_RAM_ADDR + PAC_BANK_SIZE - 1;
                        XferPrim.Mode <= XFER::XFER_MODE_READ_RAM;
                        XferPrim.Start <= 1;
                        state <= STATE_READ_PAC_CHECK;
                    end
                    else begin
                        // 保存した CRC を壊す
                        pac_crc <= XferPrim.RData;
                        state <= STATE_READ_PAC_CHECK;
                    end
                end
                STATE_READ_PAC_CHECK:
                begin
                    if(XferPrim.RData == ~pac_crc) begin
                        // 正常なバンクが見つかった
                        state <= STATE_COMPLETE;
                    end
                    else if(PAC.FlashBankNumber == 0) begin
                        // 全てのバンクをチェックしたけど、正常なデータが見つからない
                        PAC.FlashBankNumber <= PAC.FlashBankCount - 1'd1;
                        state <= STATE_CLEAR_PAC;
                    end
                    else begin
                        // 前のバンクをチェックする
                        PAC.FlashBankNumber <= PAC.FlashBankNumber - 1'd1;
                        state <= STATE_READ_PAC_READ;
                    end
                end

                //------------------------------
                // CLEAR PAC
                //------------------------------
                STATE_CLEAR_PAC:
                begin
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.Size <= PAC_BANK_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_FILL;
                    XferPrim.WData <= 8'h00;
                    XferPrim.Start <= 1;
                    state <= STATE_COMPLETE;
                end

                //------------------------------
                // WRITE PAC
                //------------------------------
                STATE_WRITE_PAC: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // RAM と FLASH の内容を比較
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.FlashAddress <= pac_addr;
                    XferPrim.Size <= PAC_BANK_SIZE - 2;
                    XferPrim.Mode <= XFER::XFER_MODE_VERIFY;
                    XferPrim.Start <= 1;

                    state <= STATE_WRITE_PAC_CHECK_VERIFY;
                end
                STATE_WRITE_PAC_CHECK_VERIFY: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    if(XferPrim.RData == 0) begin
                        // RAM と FLASH の内容が全く同じ場合は何もしない
                        PAC.Busy <= 0;
                        state <= STATE_COMPLETE;
                    end
                    else begin
                        // LED 点灯
                        Led.State <= Led.LED_STATE_ON;

                        // SEARCH_FREE へ遷移
                        state <= STATE_WRITE_PAC_SEARCH_FREE;
                    end
                end
                STATE_WRITE_PAC_SEARCH_FREE: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    if(PAC.FlashBankNumber == PAC.FlashBankCount - 1'd1) begin
                        // 最終バンクまで使用済の場合は erase
                        XferPrim.FlashAddress <= PAC_FLASH_ADDR;
                        XferPrim.Mode <= XFER::XFER_MODE_ERASE;
                        XferPrim.Start <= 1;

                        // 先頭バンクに書き込む
                        PAC.FlashBankNumber <= 0;

                        // ERASE 完了したら CALC_CRC へ遷移する
                        state <= STATE_WRITE_PAC_CALC_CRC;
                    end
                    else begin
                        // 次のバンクを FFh チェック
                        PAC.FlashBankNumber <= PAC.FlashBankNumber + 1'd1;

                        // SEARCH_FREE_READ へ遷移
                        state <= STATE_WRITE_PAC_SEARCH_FREE_READ;
                    end
                end
                STATE_WRITE_PAC_SEARCH_FREE_READ: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // FFh チェック
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.FlashAddress <= pac_addr;
                    XferPrim.Size <= PAC_BANK_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_FF;
                    XferPrim.Start <= 1;

                    // FFh チェックが終わったら SEARCH_FREE_CHECK へ遷移
                    state <= STATE_WRITE_PAC_SEARCH_FREE_CHECK;
                end
                STATE_WRITE_PAC_SEARCH_FREE_CHECK: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    if(XferPrim.RData == 8'hFF)
                    begin
                        // 未使用バンクが見つかったら CRC 計算へ遷移
                        state <= STATE_WRITE_PAC_CALC_CRC;
                    end
                    else begin
                        // 使用済なので次バンクの FFh をチェック
                        state <= STATE_WRITE_PAC_SEARCH_FREE;
                    end
                end
                STATE_WRITE_PAC_CALC_CRC: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // CRC 計算
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.Size <= PAC_BANK_SIZE - 2;
                    XferPrim.Mode <= XFER::XFER_MODE_CRC;
                    XferPrim.Start <= 1;

                    // CRC 計算が終わったら SET_CRC1 へ遷移
                    state <= STATE_WRITE_PAC_SET_CRC1;
                end
                STATE_WRITE_PAC_SET_CRC1: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // CRC を保存
                    pac_crc <= XferPrim.RData;

                    // CRC1 を RAM へ書く
                    XferPrim.RamAddress <= PAC_RAM_ADDR + PAC_BANK_SIZE - 2;
                    XferPrim.WData <= XferPrim.RData;
                    XferPrim.Size <= 1;
                    XferPrim.Mode <= XFER::XFER_MODE_FILL;
                    XferPrim.Start <= 1;

                    // CRC1 を書いたら SET_CRC2 へ遷移
                    state <= STATE_WRITE_PAC_SET_CRC2;
                end
                STATE_WRITE_PAC_SET_CRC2: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // CRC2 を RAM へ書く
                    XferPrim.RamAddress <= PAC_RAM_ADDR + PAC_BANK_SIZE - 1;
                    XferPrim.WData <= ~pac_crc;
                    XferPrim.Size <= 1;
                    XferPrim.Mode <= XFER::XFER_MODE_FILL;
                    XferPrim.Start <= 1;

                    // CRC2 を書いたら WRITE へ遷移
                    state <= STATE_WRITE_PAC_WRITE;
                end
                STATE_WRITE_PAC_WRITE: if(CONFIG::ENABLE_PAC_WRITE)
                begin
                    // フラッシュへ書く
                    XferPrim.RamAddress <= PAC_RAM_ADDR;
                    XferPrim.FlashAddress <= pac_addr;
                    XferPrim.Size <= PAC_BANK_SIZE;
                    XferPrim.Mode <= XFER::XFER_MODE_RAM_TO_FLASH;
                    XferPrim.Start <= 1;

                    // 書いたら PAC 処理終了
                    PAC.Busy <= 0;
                    state <= STATE_COMPLETE;
                end

                //------------------------------
                // MSX からのフラッシュ制御
                //------------------------------
                STATE_SECONDARY:
                begin
                    Xfer.RData <= XferPrim.RData;

                    // 転送開始された?
                    if(XferPrim.Busy && XferPrim.Start) begin
                        XferPrim.Start <= 0;
                    end

                    // 転送完了した?
                    if(!XferPrim.Busy && !Xfer.Start) begin
                        XferPrim.Start <= 0;
                        Xfer.Busy <= 0;
                        state <= STATE_COMPLETE;
                    end
                end

                //------------------------------
                // COMPLETE 
                //------------------------------
                STATE_COMPLETE:
                begin
                    if(!BusReset_n) begin
                        // リセットされた時
                        state <= STATE_WAIT_BOOT;
                        Cooperate <= 0;
                        READY <= 0;
                        Led.State <= Led.LED_STATE_OFF;
                    end
                    else begin
                        Cooperate <= 1;
                        READY <= 1;

                        if(pac_detect && CONFIG::ENABLE_PAC_WRITE) begin
                            // PAC 書き込み処理開始
                            PAC.Busy <= 1;
                            state <= STATE_WRITE_PAC;
                            Led.State <= Led.LED_STATE_OFF;
                        end
                        else begin
                            if(Xfer.Start) begin
                                // MSX からのフラッシュ制御
                                XferPrim.RamAddress   <= Xfer.RamAddress;
                                XferPrim.FlashAddress <= Xfer.FlashAddress;
                                XferPrim.Size         <= Xfer.Size;
                                XferPrim.WData        <= Xfer.WData;
                                XferPrim.Mode         <= Xfer.Mode;
                                XferPrim.Start        <= 1;
                                Xfer.Busy <= 1;

                                state <= STATE_SECONDARY;
                                Led.State <= Led.LED_STATE_ON;
                            end
                            else begin
                                // 何もしない
                                Led.State <= Led.LED_STATE_OFF;
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule

/***********************************************************************
 * メモリ転送モジュール
 ***********************************************************************/
module XFER_MEMORY (
    input   wire                                RESET_n,
    input   wire                                CLK,
    input   wire                                Cooperate,
    input   wire                                RD_n,
    input   wire                                WR_n,
    input   wire                                RFSH_n,
    output  reg                                 WAIT_n,
    RAM_IF.HOST                                 Ram,
    FLASH_IF.HOST                               Flash,
    XFER_IF.DEVICE                              Xfer
);

    /***************************************************************
     * RAM
     ***************************************************************/
    reg     [1:0]       refresh_counter;                // 0~3

    /***************************************************************
     * 
     ***************************************************************/
    logic crc_clear;
    logic crc_ena;
    logic [7:0] crc_out;
    CRC7 u_crc (
        .CLK        (CLK),
        .RESET_n    (RESET_n),
        .CLEAR      (crc_clear),
        .ENABLE     (crc_ena),
        .IN         (rw_data),
        .OUT        (crc_out)
    );

    /***************************************************************
     * state
     ***************************************************************/
    enum logic [4:0] {
        STATE_IDLE = 0,

        STATE_VERIFY,
        STATE_VERIFY_READ_FLASH,
        STATE_VERIFY_REFRESH_RAM,
        STATE_VERIFY_READ_RAM,
        STATE_VERIFY_COMPARE,

        STATE_F2R_ENABLE_FLASH,
        STATE_F2R_READ_FLASH,
        STATE_F2R_REFRESH_RAM,
        STATE_F2R_WRITE_RAM,

        STATE_R2F_ENABLE_FLASH,
        STATE_R2F_READ_RAM,
        STATE_R2F_REFRESH_RAM,
        STATE_R2F_WRITE_FLASH,

        STATE_ERASE,
        STATE_ERASE_COMPLETE,

        STATE_FILL,
        STATE_FILL_REFRESH_RAM,
        STATE_FILL_WRITE_RAM,

        STATE_CRC,
        STATE_CRC_REFRESH_RAM,
        STATE_CRC_READ_RAM,
        STATE_CRC_CALC,

        STATE_READ_RAM,
        STATE_READ_RAM_REFRESH,
        STATE_READ_RAM_READ,
        STATE_READ_RAM_COMPLETE,

        STATE_FF,
        STATE_FF_READ_FLASH,
        STATE_FF_REFRESH_RAM,
        STATE_FF_READ_RAM
    } state;

    reg     [$bits(Flash.Address)-1:0]  remain;

    enum logic [5:0] {
        SUB_STATE_IDLE = 0,

        SUB_STATE_REFRESH_RAM,
        SUB_STATE_REFRESH_RAM_WAIT_Z80,
        SUB_STATE_REFRESH_RAM_REQ,
        SUB_STATE_REFRESH_WAIT_ACK,
        SUB_STATE_REFRESH_WAIT_BUSY,

        SUB_STATE_READ_RAM,
        SUB_STATE_READ_RAM_WAIT_Z80,
        SUB_STATE_READ_RAM_RFSH_REQ,
        SUB_STATE_READ_RAM_WAIT_RFSH_ACK,
        SUB_STATE_READ_RAM_WAIT_RFSH_BUSY,
        SUB_STATE_READ_RAM_REQ,
        SUB_STATE_READ_RAM_WAIT_ACK,
        SUB_STATE_READ_RAM_WAIT_BUSY,

        SUB_STATE_WRITE_RAM,
        SUB_STATE_WRITE_RAM_WAIT_Z80,
        SUB_STATE_WRITE_RAM_RFSH_REQ,
        SUB_STATE_WRITE_RAM_WAIT_RFSH_ACK,
        SUB_STATE_WRITE_RAM_WAIT_RFSH_BUSY,
        SUB_STATE_WRITE_RAM_REQ,
        SUB_STATE_WRITE_RAM_WAIT_ACK,
        SUB_STATE_WRITE_RAM_WAIT_BUSY,

        SUB_STATE_READ_FLASH,
        SUB_STATE_READ_FLASH_WAIT_ACK,
        SUB_STATE_READ_FLASH_WAIT_BUSY,

        SUB_STATE_WRITE_FLASH,
        SUB_STATE_WRITE_FLASH_WAIT_ACK,
        SUB_STATE_WRITE_FLASH_WAIT_BUSY,

        SUB_STATE_ENABLE_READ_FLASH,
        SUB_STATE_ENABLE_READ_FLASH_WAIT_ACK,
        SUB_STATE_ENABLE_READ_FLASH_WAIT_BUSY,

        SUB_STATE_ENABLE_WRITE_FLASH,
        SUB_STATE_ENABLE_WRITE_FLASH_WAIT_ACK,
        SUB_STATE_ENABLE_WRITE_FLASH_WAIT_BUSY,

        SUB_STATE_ERASE,
        SUB_STATE_ERASE_WAIT_ACK,
        SUB_STATE_ERASE_WAIT_BUSY
    } sub_state;

    logic   [7:0]                   rw_data;
    logic   [$bits(Ram.ADDR)-1:0]   rw_addr;

    /***************************************************************
     * 
     ***************************************************************/
    assign          Xfer.Busy = state != STATE_IDLE;
    
    /***************************************************************
     * xfer 
     ***************************************************************/
    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            state <= STATE_IDLE;
            sub_state <= SUB_STATE_IDLE;

            Ram.RFSH_n <= 1;
            Ram.WE_n <= 1;
            Ram.OE_n <= 1;
            Ram.ADDR <= 0;
            Ram.DIN <= 0;
            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;

            Flash.Enable_n <= 1;
            Flash.REQ_n <= 1;
            Flash.Mode <= FLASH::FLASH_MODE_READ;
            Flash.WData <= 0;

            Xfer.RData <= 0;

            crc_clear <= 0;
            crc_ena <= 0;
        end
        else begin
            if(sub_state != SUB_STATE_IDLE)
            begin
                case (sub_state)
                    //
                    // RAM をリフレッシュ
                    //
                    SUB_STATE_REFRESH_RAM:
                    begin
                        if(!Cooperate) begin
                            sub_state <= SUB_STATE_REFRESH_RAM_REQ;
                        end
                        else begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    SUB_STATE_REFRESH_RAM_REQ:
                    begin
                        refresh_counter <= refresh_counter + 1'd1;
                        if(refresh_counter == 0)
                        begin
                            Ram.RFSH_n <= 0;
                            sub_state <= SUB_STATE_REFRESH_WAIT_ACK;
                        end else begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    SUB_STATE_REFRESH_WAIT_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_REFRESH_WAIT_BUSY;
                            Ram.RFSH_n <= 1;
                        end
                    end

                    SUB_STATE_REFRESH_WAIT_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // RAM へ1バイト書き込み
                    //
                    SUB_STATE_WRITE_RAM:
                    begin
                        if(!Cooperate) begin
                            sub_state <= SUB_STATE_WRITE_RAM_REQ;
                        end
                        else if(RFSH_n) begin
                            sub_state <= SUB_STATE_WRITE_RAM_WAIT_Z80;
                        end
                    end

                    SUB_STATE_WRITE_RAM_WAIT_Z80:
                    begin
                        if(RD_n && WR_n && !RFSH_n) begin
                            WAIT_n <= 0;
                            sub_state <= SUB_STATE_WRITE_RAM_RFSH_REQ;
                        end
                    end

                    SUB_STATE_WRITE_RAM_RFSH_REQ:
                    begin
                        Ram.RFSH_n <= 0;
                        Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                        Ram.ADDR <= 0;
                        sub_state <= SUB_STATE_WRITE_RAM_WAIT_RFSH_ACK;
                    end

                    SUB_STATE_WRITE_RAM_WAIT_RFSH_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WRITE_RAM_WAIT_RFSH_BUSY;
                            Ram.RFSH_n <= 1;
                        end
                    end

                    SUB_STATE_WRITE_RAM_WAIT_RFSH_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_WRITE_RAM_REQ;
                        end
                    end

                    SUB_STATE_WRITE_RAM_REQ:
                    begin
                        Ram.WE_n <= 0;
                        Ram.DIN <= rw_data;
                        Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                        Ram.ADDR <= rw_addr;
                        sub_state <= SUB_STATE_WRITE_RAM_WAIT_ACK;
                    end

                    SUB_STATE_WRITE_RAM_WAIT_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WRITE_RAM_WAIT_BUSY;
                            Ram.WE_n <= 1;
                            Ram.DIN <= 0;
                            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                            Ram.ADDR <= 0;
                        end
                    end

                    SUB_STATE_WRITE_RAM_WAIT_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            WAIT_n <= 1;
                            sub_state <= SUB_STATE_IDLE;
                            remain = remain - 1'd1;
                            rw_addr <= rw_addr + 1'd1;
                        end
                    end

                    //
                    // RAM から1バイト読み込み
                    //
                    SUB_STATE_READ_RAM:
                    begin
                        if(!Cooperate) begin
                            sub_state <= SUB_STATE_READ_RAM_REQ;
                        end
                        else if(RFSH_n) begin
                            sub_state <= SUB_STATE_READ_RAM_WAIT_Z80;
                        end
                    end

                    SUB_STATE_READ_RAM_WAIT_Z80:
                    begin
                        if(RD_n && WR_n && !RFSH_n) begin
                            WAIT_n <= 0;
                            sub_state <= SUB_STATE_READ_RAM_RFSH_REQ;
                        end
                    end

                    SUB_STATE_READ_RAM_RFSH_REQ:
                    begin
                        Ram.RFSH_n <= 0;
                        Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                        Ram.ADDR <= 0;
                        sub_state <= SUB_STATE_READ_RAM_WAIT_RFSH_ACK;
                    end

                    SUB_STATE_READ_RAM_WAIT_RFSH_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_READ_RAM_WAIT_RFSH_BUSY;
                            Ram.RFSH_n <= 1;
                        end
                    end

                    SUB_STATE_READ_RAM_WAIT_RFSH_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_READ_RAM_REQ;
                        end
                    end

                    SUB_STATE_READ_RAM_REQ:
                    begin
                        Ram.OE_n <= 0;
                        Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                        Ram.ADDR <= rw_addr;
                        sub_state <= SUB_STATE_READ_RAM_WAIT_ACK;
                    end

                    SUB_STATE_READ_RAM_WAIT_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_READ_RAM_WAIT_BUSY;
                            Ram.OE_n <= 1;
                            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                            Ram.ADDR <= 0;
                        end
                    end

                    SUB_STATE_READ_RAM_WAIT_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            WAIT_n <= 1;
                            sub_state <= SUB_STATE_IDLE;
                            remain = remain - 1'd1;
                            rw_addr <= rw_addr + 1'd1;
                            rw_data <= Ram.DOUT[7:0];
                        end
                    end

                    //
                    // FLASH から 1バイト取得
                    //
                    SUB_STATE_READ_FLASH:
                    begin
                        Flash.REQ_n <= 0;
                        sub_state <= SUB_STATE_READ_FLASH_WAIT_ACK;
                    end

                    SUB_STATE_READ_FLASH_WAIT_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_READ_FLASH_WAIT_BUSY;
                            Flash.REQ_n <= 1;
                        end
                    end

                    SUB_STATE_READ_FLASH_WAIT_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // FLASH へ 1バイト書き込み
                    //
                    SUB_STATE_WRITE_FLASH:
                    begin
                        Flash.WData <= rw_data;
                        Flash.REQ_n <= 0;
                        sub_state <= SUB_STATE_WRITE_FLASH_WAIT_ACK;
                    end

                    SUB_STATE_WRITE_FLASH_WAIT_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WRITE_FLASH_WAIT_BUSY;
                            Flash.REQ_n <= 1;
                        end
                    end

                    SUB_STATE_WRITE_FLASH_WAIT_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // FLASH 読み出し開始
                    //
                    SUB_STATE_ENABLE_READ_FLASH:
                    begin
                        Flash.Address <= Xfer.FlashAddress;
                        Flash.Enable_n <= 0;
                        Flash.Mode <= FLASH::FLASH_MODE_READ;
                        sub_state <= SUB_STATE_ENABLE_READ_FLASH_WAIT_ACK;
                    end

                    SUB_STATE_ENABLE_READ_FLASH_WAIT_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_ENABLE_READ_FLASH_WAIT_BUSY;
                        end
                    end

                    SUB_STATE_ENABLE_READ_FLASH_WAIT_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // FLASH 書き込み開始
                    //
                    SUB_STATE_ENABLE_WRITE_FLASH:
                    begin
                        Flash.Address <= Xfer.FlashAddress;
                        Flash.Enable_n <= 0;
                        Flash.Mode <= FLASH::FLASH_MODE_WRITE;
                        sub_state <= SUB_STATE_ENABLE_WRITE_FLASH_WAIT_ACK;
                    end

                    SUB_STATE_ENABLE_WRITE_FLASH_WAIT_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_ENABLE_WRITE_FLASH_WAIT_BUSY;
                        end
                    end

                    SUB_STATE_ENABLE_WRITE_FLASH_WAIT_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // FLASH ERASE
                    //
                    SUB_STATE_ERASE:
                    begin
                        Flash.Address <= Xfer.FlashAddress;
                        Flash.Enable_n <= 0;
                        Flash.Mode <= FLASH::FLASH_MODE_ERASE;
                        Flash.WData <= 8'hD8;
                        sub_state <= SUB_STATE_ERASE_WAIT_ACK;
                    end

                    SUB_STATE_ERASE_WAIT_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            Flash.Enable_n <= 1;
                            sub_state <= SUB_STATE_ERASE_WAIT_BUSY;
                        end
                    end

                    SUB_STATE_ERASE_WAIT_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            Flash.WData <= 0;
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end
                endcase
            end else 

            case (state)
                STATE_IDLE:
                begin
                    Flash.Enable_n <= 1;
                    Flash.REQ_n <= 1;

                    Ram.RFSH_n <= 1;
                    Ram.OE_n <= 1;
                    Ram.WE_n <= 1;
                    Ram.DIN <= 0;
                    Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                    Ram.ADDR <= 0;

                    refresh_counter <= 0;
                    remain <= Xfer.Size;
                    rw_addr <= Xfer.RamAddress;

                    if(Xfer.Start)
                    begin
                        case (Xfer.Mode)
                            XFER::XFER_MODE_FILL:           state <= STATE_FILL;
                            XFER::XFER_MODE_READ_RAM:       state <= STATE_READ_RAM;
                            XFER::XFER_MODE_FLASH_TO_RAM:   state <= STATE_F2R_ENABLE_FLASH;
                            XFER::XFER_MODE_RAM_TO_FLASH:   state <= STATE_R2F_ENABLE_FLASH;
                            XFER::XFER_MODE_ERASE:          state <= STATE_ERASE;
                            XFER::XFER_MODE_VERIFY:         state <= STATE_VERIFY;
                            XFER::XFER_MODE_FF:             state <= STATE_FF;
                            XFER::XFER_MODE_CRC:            state <= STATE_CRC;
                        endcase
                    end
                end

                //---------------------------------------
                // verify
                //---------------------------------------
                // FLASH 読み出し開始
                STATE_VERIFY:
                begin
                    sub_state <= SUB_STATE_ENABLE_READ_FLASH;
                    state <= STATE_VERIFY_READ_FLASH;
                end

                // FLASH から 1バイト取得
                STATE_VERIFY_READ_FLASH:
                begin
                    if(remain == 0)
                    begin
                        Flash.Enable_n <= 1;
                        Xfer.RData <= 8'h00;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_READ_FLASH;
                        state <= STATE_VERIFY_REFRESH_RAM;
                    end
                end

                // RAM をリフレッシュ
                STATE_VERIFY_REFRESH_RAM:
                begin
                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_VERIFY_READ_RAM;
                end

                // RAM から1バイト読む
                STATE_VERIFY_READ_RAM:
                begin
                    sub_state <= SUB_STATE_READ_RAM;
                    state <= STATE_VERIFY_COMPARE;
                end

                // RAM から1バイト読む
                STATE_VERIFY_COMPARE:
                begin
                    if(rw_data == Flash.RData) begin
                        state <= STATE_VERIFY_READ_FLASH;
                    end
                    else begin
                        Flash.Enable_n <= 1;
                        Xfer.RData <= 8'hFF;
                        state <= STATE_IDLE;
                    end
                end

                //---------------------------------------
                // FLASH to RAM
                //---------------------------------------
                // FLASH 読み出し開始
                STATE_F2R_ENABLE_FLASH:
                begin
                    sub_state <= SUB_STATE_ENABLE_READ_FLASH;
                    state <= STATE_F2R_READ_FLASH;
                end

                // FLASH から 1バイト取得
                STATE_F2R_READ_FLASH:
                begin
                    if(remain == 0)
                    begin
                        Flash.Enable_n <= 1;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_READ_FLASH;
                        state <= STATE_F2R_REFRESH_RAM;
                    end
                end

                // RAM をリフレッシュ
                STATE_F2R_REFRESH_RAM:
                begin
                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_F2R_WRITE_RAM;
                end

                // RAM に1バイト書く
                STATE_F2R_WRITE_RAM:
                begin
                    rw_data <= Flash.RData;
                    sub_state <= SUB_STATE_WRITE_RAM;
                    state <= STATE_F2R_READ_FLASH;
                end

                //---------------------------------------
                // RAM to FLASH
                //---------------------------------------
                // FLASH 書き出し開始
                STATE_R2F_ENABLE_FLASH:
                begin
                    sub_state <= SUB_STATE_ENABLE_WRITE_FLASH;
                    state <= STATE_R2F_READ_RAM;
                end

                // RAM から 1バイト取得
                STATE_R2F_READ_RAM:
                begin
                    if(remain == 0)
                    begin
                        Flash.Enable_n <= 1;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_READ_RAM;
                        state <= STATE_R2F_REFRESH_RAM;
                    end
                end

                // RAM をリフレッシュ
                STATE_R2F_REFRESH_RAM:
                begin
                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_R2F_WRITE_FLASH;
                end

                // FLASH に1バイト書く
                STATE_R2F_WRITE_FLASH:
                begin
                    Flash.WData <= rw_data;
                    sub_state <= SUB_STATE_WRITE_FLASH;
                    state <= STATE_R2F_READ_RAM;
                end

                //---------------------------------------
                // ERASE
                //---------------------------------------
                STATE_ERASE:
                begin
                    sub_state <= SUB_STATE_ERASE;
                    state <= STATE_ERASE_COMPLETE;
                end

                STATE_ERASE_COMPLETE:
                begin
                    state <= STATE_IDLE;
                end

                //---------------------------------------
                // メモリフィル
                //---------------------------------------
                STATE_FILL:
                begin
                    rw_data <= Xfer.WData;
                    state <= STATE_FILL_REFRESH_RAM;
                end

                // RAM をリフレッシュ
                STATE_FILL_REFRESH_RAM:
                begin
                    if(remain == 0)
                    begin
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_REFRESH_RAM;
                        state <= STATE_FILL_WRITE_RAM;
                    end
                end

                // RAM に1バイト書く
                STATE_FILL_WRITE_RAM:
                begin
                    sub_state <= SUB_STATE_WRITE_RAM;
                    state <= STATE_FILL_REFRESH_RAM;
                end

                //---------------------------------------
                // CRC
                //---------------------------------------
                STATE_CRC:
                begin
                    crc_clear <= 1;
                    state <= STATE_CRC_REFRESH_RAM;
                end

                // RAM をリフレッシュ
                STATE_CRC_REFRESH_RAM:
                begin
                    crc_ena <= 0;
                    crc_clear <= 0;
                    if(remain == 0)
                    begin
                        Xfer.RData <= crc_out;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_REFRESH_RAM;
                        state <= STATE_CRC_READ_RAM;
                    end
                end

                // RAM から 1バイト読む
                STATE_CRC_READ_RAM:
                begin
                    sub_state <= SUB_STATE_READ_RAM;
                    state <= STATE_CRC_CALC;
                end

                // 計算
                STATE_CRC_CALC:
                begin
                    crc_ena <= 1;
                    state <= STATE_CRC_REFRESH_RAM;
                end

                //---------------------------------------
                // READ RAM
                //---------------------------------------
                STATE_READ_RAM:
                begin
                    state <= STATE_READ_RAM_REFRESH;
                end

                // RAM をリフレッシュ
                STATE_READ_RAM_REFRESH:
                begin
                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_READ_RAM_READ;
                end

                // RAM から 1バイト読む
                STATE_READ_RAM_READ:
                begin
                    sub_state <= SUB_STATE_READ_RAM;
                    state <= STATE_READ_RAM_COMPLETE;
                end

                // 終わり
                STATE_READ_RAM_COMPLETE:
                begin
                    Xfer.RData <= rw_data;
                    state <= STATE_IDLE;
                end

                //---------------------------------------
                // check FF
                //---------------------------------------
                // FLASH 読み出し開始
                STATE_FF:
                begin
                    sub_state <= SUB_STATE_ENABLE_READ_FLASH;
                    state <= STATE_FF_READ_FLASH;
                    Xfer.RData <= 8'hFF;
                end

                // FLASH から 1バイト取得
                STATE_FF_READ_FLASH:
                begin
                    if(remain == 0)
                    begin
                        Flash.Enable_n <= 1;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_READ_FLASH;
                        state <= STATE_FF_REFRESH_RAM;
                    end
                end

                // RAM をリフレッシュ
                STATE_FF_REFRESH_RAM:
                begin
                    Xfer.RData <= Xfer.RData & Flash.RData;

                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_FF_READ_RAM;
                end

                // RAM に1バイト読む
                STATE_FF_READ_RAM:
                begin
                    sub_state <= SUB_STATE_READ_RAM;
                    state <= STATE_FF_READ_FLASH;
                end
            endcase
        end
    end

endmodule

module CRC7 #(
    parameter [7:0] INIT = 0
) (
    input wire          CLK,
    input wire          RESET_n,
    input wire          CLEAR,
    input wire          ENABLE,
    input wire  [7:0]   IN,
    output wire [7:0]   OUT
);
    logic [7:0] ff;

    assign OUT = ff;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ff <= INIT;
        end
        else if(CLEAR) begin
            ff <= INIT;
        end
        else if(ENABLE) begin
            ff[0] <= IN[0] ^ IN[4] ^ IN[7] ^ ff[6] ^ ff[3]; 
            ff[1] <= IN[1] ^ IN[5] ^ ff[0] ^ ff[4]; 
            ff[2] <= IN[2] ^ IN[6] ^ ff[1] ^ ff[5]; 
            ff[3] <= IN[0] ^ IN[3] ^ ff[2] ^ IN[4] ^ ff[3]; 
            ff[4] <= IN[1] ^ IN[4] ^ ff[3] ^ IN[5] ^ ff[0] ^ ff[4]; 
            ff[5] <= IN[2] ^ IN[5] ^ ff[4] ^ IN[6] ^ ff[1] ^ ff[5]; 
            ff[6] <= IN[3] ^ IN[6] ^ ff[5] ^ IN[7] ^ ff[2] ^ ff[6]; 
        end
    end
endmodule

`default_nettype wire
