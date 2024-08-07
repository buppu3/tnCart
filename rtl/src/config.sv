//
// config.sv
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

package CONFIG;
    /***************************************************************
     * 機能に指定する定数
     ***************************************************************/
    localparam DISABLE          = 0;            // 機能の無効
    localparam ENABLE           = 1;            // 機能の有効
    localparam ENABLE_VM2413    = 1;            // 機能の有効(VM2413)
    localparam ENABLE_IKAOPLL   = 2;            // 機能の有効(IKAOPLL)

    /***************************************************************
     * フラッシュ
     ***************************************************************/
    localparam [23:0]   FLASH_ADDR_MEGAROM      = 24'h20_0000;
    localparam [23:0]   FLASH_SIZE_MEGAROM      = 24'h20_0000;
    localparam [23:0]   FLASH_ADDR_BIOS         = 24'h10_0000;
    localparam [23:0]   FLASH_SIZE_BIOS         = (FLASH_SIZE_BIOS_NEXTOR + FLASH_SIZE_BIOS_FM);
    localparam [23:0]   FLASH_SIZE_BIOS_NEXTOR  = 24'h02_0000;
    localparam [23:0]   FLASH_SIZE_BIOS_FM      = 24'h00_4000;

    /***************************************************************
     * RAM
     ***************************************************************/
    localparam [23:0]   RAM_ADDR_RAM            = 24'h00_0000;
    localparam [23:0]   RAM_ADDR_MEGAROM        = 24'h40_0000;
    localparam [23:0]   RAM_ADDR_BIOS           = 24'h70_0000;
    localparam [23:0]   RAM_ADDR_BIOS_NEXTOR    = RAM_ADDR_BIOS;
    localparam [23:0]   RAM_ADDR_BIOS_FM        = (RAM_ADDR_BIOS_NEXTOR + FLASH_SIZE_BIOS_NEXTOR);
    localparam [23:0]   RAM_ADDR_VRAM           = 24'h78_0000;

    /***************************************************************
     * アッテネータ
     ***************************************************************/
    localparam          ATT_EXT_PSG_MUL         = 4;
    localparam          ATT_EXT_PSG_DIV         = 5;
    localparam          ATT_EXT_FM_MUL          = 1;
    localparam          ATT_EXT_FM_DIV          = 1;
    localparam          ATT_EXT_MEGAROM_MUL     = 4;
    localparam          ATT_EXT_MEGAROM_DIV     = 5;

    localparam          ATT_INT_FM_MUL          = 1;
    localparam          ATT_INT_FM_DIV          = 1;
    localparam          ATT_INT_MEGAROM_MUL     = 4;
    localparam          ATT_INT_MEGAROM_DIV     = 5;

    /***************************************************************
     * 機能
     ***************************************************************/
    localparam          ENABLE_MEGAROM          = ENABLE;           // メガロムカートリッジを有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_FM               = ENABLE_IKAOPLL;   // FM 音源カートリッジを有効にするか(DISABLE/ENABLE_VM2413/ENABLE_IKAOPLL)
    localparam          ENABLE_NEXTOR           = ENABLE;           // NEXTOR カートリッジを有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_RAM              = ENABLE;           // 拡張 RAM カートリッジを有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_PSG              = ENABLE;           // PSG を有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_SCC              = ENABLE;           // SCC を有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_V9990            = ENABLE;           // V9990 を有効にするか(DISABLE/ENABLE)
    localparam          ENABLE_V9990_CMD        = ENABLE;           // V9990 の VDP コマンドを有効(V9990のVDPコマンドを有効にすると回路の規模が大きくなるので、他の大きな機能と同時使用はできない)

endpackage

`default_nettype wire
