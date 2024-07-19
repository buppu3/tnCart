//
// main.sv
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

module MAIN (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,                // BUS I/F
    RAM_IF.HOST             Ram,                // RAM I/F
    RAM_IF.HOST             VideoRam,           // VRAM I/F
    UMA_IF.CLK              UmaClock,           // UMA クロック
    SPI_IF.HOST             TF,                 // TF カード I/F
    LED_IF.HOST             LedNextor,          // Nextor 用 LED
    FLASH_IF.HOST           Flash,              // フラッシュメモリ
    LED_IF.HOST             LedBoot,            // Bootloader 用 LED
    VIDEO_IF.OUT            Video,              // ビデオ出力
    SOUND_IF.OUT            SoundExternal,      // 外部サウンド出力
    SOUND_IF.OUT            SoundInternal       // カートリッジサウンド出力
);
    /***************************************************************
     * サウンド信号格納用
     ***************************************************************/
    localparam SOUND_MEGAROM = 0;
    localparam SOUND_FM      = 1;
    localparam SOUND_PSG     = 2;
    localparam SOUND_COUNT   = 3;
    SOUND_IF Sound[0:SOUND_COUNT-1]();

    /***************************************************************
     * RAM I/F を複数に拡張
     ***************************************************************/
    localparam RAM_MEGAROM    = 0;
    localparam RAM_FM         = 1;
    localparam RAM_NEXTOR     = 2;
    localparam RAM_RAM        = 3;
    localparam RAM_BOOTLOADER = 4;
    localparam RAM_COUNT      = 5;
    RAM_IF ExpRam[0:RAM_COUNT-1]();
    EXPANSION_RAM #(
        .COUNT          (RAM_COUNT),
        .USE_FF         (0)
    ) u_expram (
        .RESET_n,
        .CLK,
        .Primary        (Ram),
        .Secondary      (ExpRam)
    );

    /***************************************************************
     * スロットの拡張
     ***************************************************************/
    localparam BUS_MEGAROM = 0;
    localparam BUS_FM      = 1;
    localparam BUS_NEXTOR  = 2;
    localparam BUS_RAM     = 3;
    localparam BUS_PSG     = 4;     // SLTSL_n 信号なし(I/Oのみ)
    localparam BUS_V9990   = 5;     // SLTSL_n 信号なし(I/Oのみ)
    localparam BUS_COUNT   = 6;
    BUS_IF  ExpBus[0:BUS_COUNT-1]();
    EXPANSION_SLOT #(
        .COUNT          (BUS_COUNT),
        .USE_FF         (1)
    ) u_sltexp (
        .RESET_n        (SYS_RESET_n),
        .CLK,
        .Primary        (Bus),
        .Secondary      (ExpBus),
        .WAIT_n         (BOOT_n)
    );

    /***************************************************************
     * MEGAROM カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_MEGAROM) begin
        CARTRIDGE_MEGAROM #(
            .RAM_ADDR       (CONFIG::RAM_ADDR_MEGAROM)
        ) u_megarom (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_MEGAROM]),
            .Ram            (ExpRam[RAM_MEGAROM]),
            .Sound          (Sound[SOUND_MEGAROM])
        );
        end
    else begin
        assign ExpBus[BUS_MEGAROM].DOUT = 0;
        assign ExpBus[BUS_MEGAROM].BUSDIR_n = 1;
        assign ExpBus[BUS_MEGAROM].INT_n = 1;
        assign ExpBus[BUS_MEGAROM].WAIT_n = 1;
        assign ExpRam[RAM_MEGAROM].ADDR = 0;
        assign ExpRam[RAM_MEGAROM].DIN = 0;
        assign ExpRam[RAM_MEGAROM].DIN_SIZE = 0;
        assign ExpRam[RAM_MEGAROM].OE_n = 1;
        assign ExpRam[RAM_MEGAROM].WE_n = 1;
        assign ExpRam[RAM_MEGAROM].RFSH_n = 1;
        assign Sound[SOUND_MEGAROM].Signal = 0;
    end

    /***************************************************************
     * FM 音源カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_FM) begin
        CARTRIDGE_FM #(
            .RAM_ADDR       (CONFIG::RAM_ADDR_BIOS_FM)
        ) u_fm (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_FM]),
            .Ram            (ExpRam[RAM_FM]),
            .Sound          (Sound[SOUND_FM])
        );
    end
    else begin
        assign ExpBus[BUS_FM].DOUT = 0;
        assign ExpBus[BUS_FM].BUSDIR_n = 1;
        assign ExpBus[BUS_FM].INT_n = 1;
        assign ExpBus[BUS_FM].WAIT_n = 1;
        assign ExpRam[RAM_FM].ADDR = 0;
        assign ExpRam[RAM_FM].DIN = 0;
        assign ExpRam[RAM_FM].DIN_SIZE = 0;
        assign ExpRam[RAM_FM].OE_n = 1;
        assign ExpRam[RAM_FM].WE_n = 1;
        assign ExpRam[RAM_FM].RFSH_n = 1;
        assign Sound[SOUND_FM].Signal = 0;
    end

    /***************************************************************
     * NEXTOR カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_NEXTOR) begin
        CARTRIDGE_NEXTOR #(
            .RAM_ADDR       (CONFIG::RAM_ADDR_BIOS_NEXTOR)
        ) u_nextor (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_NEXTOR]),
            .Ram            (ExpRam[RAM_NEXTOR]),
            .TF,
            .Led            (LedNextor)
        );
    end
    else begin
        assign ExpBus[BUS_NEXTOR].DOUT = 0;
        assign ExpBus[BUS_NEXTOR].BUSDIR_n = 1;
        assign ExpBus[BUS_NEXTOR].INT_n = 1;
        assign ExpBus[BUS_NEXTOR].WAIT_n = 1;
        assign ExpRam[RAM_NEXTOR].ADDR = 0;
        assign ExpRam[RAM_NEXTOR].DIN = 0;
        assign ExpRam[RAM_NEXTOR].DIN_SIZE = 0;
        assign ExpRam[RAM_NEXTOR].OE_n = 1;
        assign ExpRam[RAM_NEXTOR].WE_n = 1;
        assign ExpRam[RAM_NEXTOR].RFSH_n = 1;
        assign LedNextor.State = LedNextor.LED_STATE_OFF;
        assign TF.MOSI = 0;
        assign TF.LEN = 0;
        assign TF.REQ = 0;
        assign TF.CS_n = 1;        
    end

    /***************************************************************
     * RAM カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_RAM) begin
        CARTRIDGE_RAM #(
            .RAM_ADDR       (CONFIG::RAM_ADDR_RAM)
        ) u_ram (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_RAM]),
            .Ram            (ExpRam[RAM_RAM])
        );
    end
    else begin
        assign ExpBus[BUS_RAM].DOUT = 0;
        assign ExpBus[BUS_RAM].BUSDIR_n = 1;
        assign ExpBus[BUS_RAM].INT_n = 1;
        assign ExpBus[BUS_RAM].WAIT_n = 1;
        assign ExpRam[RAM_RAM].ADDR = 0;
        assign ExpRam[RAM_RAM].DIN = 0;
        assign ExpRam[RAM_RAM].DIN_SIZE = 0;
        assign ExpRam[RAM_RAM].OE_n = 1;
        assign ExpRam[RAM_RAM].WE_n = 1;
        assign ExpRam[RAM_RAM].RFSH_n = 1;
    end

    /***************************************************************
     * PSG カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_PSG) begin
        CARTRIDGE_PSG u_psg (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_PSG]),
            .Sound          (Sound[SOUND_PSG])
        );
    end
    else begin
        assign ExpBus[BUS_PSG].DOUT = 0;
        assign ExpBus[BUS_PSG].BUSDIR_n = 1;
        assign ExpBus[BUS_PSG].INT_n = 1;
        assign ExpBus[BUS_PSG].WAIT_n = 1;
        assign Sound[SOUND_PSG].Signal = 0;
    end

    /***************************************************************
     * V9990 カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_V9990) begin
        CARTRIDGE_V9990 u_v9990 (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_V9990]),
            .Ram            (VideoRam),
            .UmaClock,
            .Video          (Video)
        );
    end
    else begin
        assign ExpBus[BUS_V9990].DOUT = 0;
        assign ExpBus[BUS_V9990].BUSDIR_n = 1;
        assign ExpBus[BUS_V9990].INT_n = 1;
        assign ExpBus[BUS_V9990].WAIT_n = 1;
        assign Video.R = 0;
        assign Video.G = 0;
        assign Video.B = 0;
        assign Video.HS_n = 1;
        assign Video.VS_n = 1;
        assign Video.RESOLUTION = VIDEO::RESOLUTION_720_480;
        assign Video.DCLK = ExpBus[BUS_V9990].CLK_14M;
        assign VideoRam.ADDR = 0;
        assign VideoRam.OE_n = 1;
        assign VideoRam.WE_n = 1;
        assign VideoRam.RFSH_n = 1;
        assign VideoRam.DIN = 0;
        assign VideoRam.DIN_SIZE = 0;
    end

    /***************************************************************
     * ブートローダー
     ***************************************************************/
    logic SYS_RESET_n;
    logic BOOT_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)     SYS_RESET_n <= 0;
        else if(!BOOT_n) SYS_RESET_n <= 0;
        else             SYS_RESET_n <= 1;
    end
    //assign SYS_RESET_n = RESET_n && BOOT_n;
    BOOTLOADER #(
        .XFER_SRC_ADDR  (CONFIG::FLASH_ADDR_BIOS),
        .XFER_DST_ADDR  (CONFIG::RAM_ADDR_BIOS),
        .XFER_SIZE      (CONFIG::FLASH_SIZE_BIOS),
        .MEGAROM_CLEAR_ADDR(CONFIG::RAM_ADDR_MEGAROM),
        .MEGAROM_CLEAR_SIZE(32768),
        .RAM_CLEAR_ADDR (CONFIG::RAM_ADDR_RAM),
        .RAM_CLEAR_SIZE (65536)
    ) u_boot (
        .RESET_n,
        .CLK,
        .Flash,
        .Ram            (ExpRam[RAM_BOOTLOADER]),
        .Led            (LedBoot),
        .ClearMegarom   (1'b1),
        .READY          (BOOT_n)
    );

    /***************************************************************
     * 外部サウンド出力ミキサー
     ***************************************************************/
    localparam SOUND_EXT_MEGAROM = 0;
    localparam SOUND_EXT_FM      = 1;
    localparam SOUND_EXT_PSG     = 2;
    localparam SOUND_EXT_COUNT   = 3;
    SOUND_IF AttOutExt[0:SOUND_EXT_COUNT-1]();

    if(CONFIG::ENABLE_MEGAROM) begin
        SOUND_ATTENUATOR #(
            .MUL(1),
            .DIV(2)
        ) u_att_ext_megarom (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_MEGAROM]),
            .OUT(AttOutExt[SOUND_EXT_MEGAROM])
        );
    end
    else begin
        assign AttOutExt[SOUND_EXT_MEGAROM].Signal = 0;
    end

    if(CONFIG::ENABLE_FM) begin
        SOUND_ATTENUATOR #(
            .MUL(1),
            .DIV(2)
        ) u_att_ext_fm (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_FM]),
            .OUT(AttOutExt[SOUND_EXT_FM])
        );
    end
    else begin
        assign AttOutExt[SOUND_EXT_FM].Signal = 0;
    end

    if(CONFIG::ENABLE_PSG) begin
        SOUND_ATTENUATOR #(
            .MUL(1),
            .DIV(2)
        ) u_att_ext_psg (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_PSG]),
            .OUT(AttOutExt[SOUND_EXT_PSG])
        );
    end
    else begin
        assign AttOutExt[SOUND_EXT_PSG].Signal = 0;
    end

    SOUND_MIXER #(
        .COUNT          (SOUND_EXT_COUNT)
    ) u_mixer_ext (
        .RESET_n,
        .CLK,
        .IN             (AttOutExt),
        .OUT            (SoundExternal)
    );

    /***************************************************************
     * カートリッジサウンド出力ミキサー
     ***************************************************************/
    localparam SOUND_INT_MEGAROM = 0;
    localparam SOUND_INT_FM      = 1;
    localparam SOUND_INT_COUNT   = 2;
    SOUND_IF AttOutInt[0:SOUND_INT_COUNT-1]();

    if(CONFIG::ENABLE_MEGAROM) begin
        SOUND_ATTENUATOR #(
            .MUL(1),
            .DIV(2)
        ) u_att_int_megarom (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_MEGAROM]),
            .OUT(AttOutInt[SOUND_INT_MEGAROM])
        );
    end
    else begin
        assign AttOutInt[SOUND_INT_MEGAROM].Signal = 0;
    end

    if(CONFIG::ENABLE_FM) begin
        SOUND_ATTENUATOR #(
            .MUL(1),
            .DIV(2)
        ) u_att_int_fm (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_FM]),
            .OUT(AttOutInt[SOUND_INT_FM])
        );
    end
    else begin
        assign AttOutInt[SOUND_INT_FM].Signal = 0;
    end

    SOUND_MIXER #(
        .COUNT          (SOUND_INT_COUNT)
    ) u_mixer_int (
        .RESET_n,
        .CLK,
        .IN             (AttOutInt),
        .OUT            (SoundInternal)
    );

endmodule


`default_nettype wire
