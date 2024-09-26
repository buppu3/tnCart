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
    RAM_IF                  VideoRam,           // VRAM I/F
    UMA_IF.CLK              UmaClock,           // UMA クロック
    SPI_IF                  TF,                 // TF カード I/F
    LED_IF                  LedNextor,          // Nextor 用 LED
    FLASH_IF.HOST           Flash,              // フラッシュメモリ
    LED_IF.HOST             LedBoot,            // Bootloader 用 LED
    VIDEO_IF                Video,              // ビデオ出力
    SOUND_IF.OUT            SoundExternal,      // 外部サウンド出力
    SOUND_IF.OUT            SoundInternal       // カートリッジサウンド出力
);
    /***************************************************************
     * サウンド信号格納用
     ***************************************************************/
    localparam SOUND_MEGAROM = 0;
    localparam SOUND_FM_INT  = 1;
    localparam SOUND_FM_EXT  = 2;
    localparam SOUND_PSG     = 3;
    localparam SOUND_COUNT   = 4;
    SOUND_IF #(.BIT_WIDTH(CONFIG::SOUND_BIT_WIDTH)) Sound[0:SOUND_COUNT-1]();

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
        .USE_FF         (CONFIG::RAM_IF_EXPANSION_USES_FF)
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
        .USE_FF         (CONFIG::SLOT_EXPANSION_USES_FF)
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
        always_comb ExpBus[BUS_MEGAROM].connect_dummy();
        always_comb ExpRam[RAM_MEGAROM].connect_dummy();
        always_comb Sound[SOUND_MEGAROM].connect_dummy();
    end

    /***************************************************************
     * FM 音源カートリッジ
     ***************************************************************/
    if(CONFIG::ENABLE_FM) begin
        wire FM_Sound_Enable;
        CARTRIDGE_FM #(
            .MIRROR         (1),
            .RAM_ADDR_BIOS  (CONFIG::RAM_ADDR_BIOS_FM),
            .RAM_ADDR_PAC   (CONFIG::RAM_ADDR_PAC)
        ) u_fm (
            .RESET_n        (SYS_RESET_n),
            .CLK,
            .Bus            (ExpBus[BUS_FM]),
            .Ram            (ExpRam[RAM_FM]),
            .Sound          (Sound[SOUND_FM_EXT]),
            .Output_En      (FM_Sound_Enable)
        );
        assign Sound[SOUND_FM_INT].Signal = FM_Sound_Enable ? Sound[SOUND_FM_EXT].Signal : 0;
    end
    else begin
        always_comb ExpBus[BUS_FM].connect_dummy();
        always_comb ExpRam[RAM_FM].connect_dummy();
        always_comb Sound[SOUND_FM_EXT].connect_dummy();
        always_comb Sound[SOUND_FM_INT].connect_dummy();
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
        always_comb ExpBus[BUS_NEXTOR].connect_dummy();
        always_comb ExpRam[RAM_NEXTOR].connect_dummy();
        always_comb LedNextor.connect_dummy();
        always_comb TF.connect_dummy();
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
        always_comb ExpBus[BUS_RAM].connect_dummy();
        always_comb ExpRam[RAM_RAM].connect_dummy();
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
        always_comb ExpBus[BUS_PSG].connect_dummy();
        always_comb Sound[SOUND_PSG].connect_dummy();
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
        always_comb ExpBus[BUS_V9990].connect_dummy();
        always_comb Video.connect_dummy();
        always_comb VideoRam.connect_dummy();
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
    SOUND_IF #(.BIT_WIDTH($bits(Sound[0].Signal))) AttOutExt[0:SOUND_EXT_COUNT-1]();

    if(CONFIG::ENABLE_MEGAROM) begin
        SOUND_ATTENUATOR #(
            .MUL(CONFIG::ATT_EXT_MEGAROM_MUL),
            .DIV(CONFIG::ATT_EXT_MEGAROM_DIV)
        ) u_att_ext_megarom (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_MEGAROM]),
            .OUT(AttOutExt[SOUND_EXT_MEGAROM])
        );
    end
    else begin
        always_comb AttOutExt[SOUND_EXT_MEGAROM].connect_dummy();
    end

    if(CONFIG::ENABLE_FM) begin
        SOUND_ATTENUATOR #(
            .MUL(CONFIG::ATT_EXT_FM_MUL),
            .DIV(CONFIG::ATT_EXT_FM_DIV)
        ) u_att_ext_fm (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_FM_EXT]),
            .OUT(AttOutExt[SOUND_EXT_FM])
        );
    end
    else begin
        always_comb AttOutExt[SOUND_EXT_FM].connect_dummy();
    end

    if(CONFIG::ENABLE_PSG) begin
        SOUND_ATTENUATOR #(
            .MUL(CONFIG::ATT_EXT_PSG_MUL),
            .DIV(CONFIG::ATT_EXT_PSG_DIV)
        ) u_att_ext_psg (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_PSG]),
            .OUT(AttOutExt[SOUND_EXT_PSG])
        );
    end
    else begin
        always_comb AttOutExt[SOUND_EXT_PSG].connect_dummy();
    end

    SOUND_IF #(.BIT_WIDTH($bits(AttOutExt[0].Signal))) mix_ext();

    SOUND_MIXER #(
        .COUNT          (SOUND_EXT_COUNT)
    ) u_mixer_ext (
        .RESET_n,
        .CLK,
        .IN             (AttOutExt),
        .OUT            (mix_ext)
    );

    if($bits(SoundExternal.Signal) == $bits(mix_ext.Signal)) begin
        assign SoundExternal.Signal = mix_ext.Signal;
    end
    else begin
        wire [$bits(mix_ext.Signal)+16-1:0] mix_ext_ex = { mix_ext.Signal, 16'd0 };
        assign SoundExternal.Signal = mix_ext_ex[$bits(mix_ext_ex)-1:$bits(mix_ext_ex)-$bits(SoundExternal.Signal)];
    end

    /***************************************************************
     * カートリッジサウンド出力ミキサー
     ***************************************************************/
    localparam SOUND_INT_MEGAROM = 0;
    localparam SOUND_INT_FM      = 1;
    localparam SOUND_INT_COUNT   = 2;
    SOUND_IF #(.BIT_WIDTH($bits(Sound[0].Signal))) AttOutInt[0:SOUND_INT_COUNT-1]();

    if(CONFIG::ENABLE_MEGAROM) begin
        SOUND_ATTENUATOR #(
            .MUL(CONFIG::ATT_INT_MEGAROM_MUL),
            .DIV(CONFIG::ATT_INT_MEGAROM_DIV)
        ) u_att_int_megarom (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_MEGAROM]),
            .OUT(AttOutInt[SOUND_INT_MEGAROM])
        );
    end
    else begin
        always_comb AttOutInt[SOUND_INT_MEGAROM].connect_dummy();
    end

    if(CONFIG::ENABLE_FM) begin
        SOUND_ATTENUATOR #(
            .MUL(CONFIG::ATT_INT_FM_MUL),
            .DIV(CONFIG::ATT_INT_FM_DIV)
        ) u_att_int_fm (
            .RESET_n,
            .CLK,
            .IN(Sound[SOUND_FM_INT]),
            .OUT(AttOutInt[SOUND_INT_FM])
        );
    end
    else begin
        always_comb AttOutInt[SOUND_INT_FM].connect_dummy();
    end

    SOUND_IF #(.BIT_WIDTH($bits(AttOutInt[0].Signal))) mix_int();

    SOUND_MIXER #(
        .COUNT          (SOUND_INT_COUNT)
    ) u_mixer_int (
        .RESET_n,
        .CLK,
        .IN             (AttOutInt),
        .OUT            (mix_int)
    );

    if($bits(SoundInternal.Signal) == $bits(mix_int.Signal)) begin
        assign SoundInternal.Signal = mix_int.Signal;
    end
    else begin
        wire [$bits(mix_int.Signal)+16-1:0] mix_int_ex = { mix_int.Signal, 16'd0 };
        assign SoundInternal.Signal = mix_int_ex[$bits(mix_int_ex)-1:$bits(mix_int_ex)-$bits(SoundInternal.Signal)];
    end

endmodule


`default_nettype wire
