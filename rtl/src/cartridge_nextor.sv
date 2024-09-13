//
// cartridge_nextor.sv
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
 * NEXTOR カードリッジ
 ***************************************************************/
module CARTRIDGE_NEXTOR #(
    parameter               RAM_ADDR = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    SPI_IF.HOST             TF,
    LED_IF.HOST             Led
);

    /***************************************************************
     * NEXTOR KERNEL ROM
     ***************************************************************/
    MEGAROM_IF #(.BANK_COUNT(2)) Megarom();
    assign Megarom.MemoryTopAddr     = RAM_ADDR;             // 割り当て RAM アドレス
    assign Megarom.BankRegAddrMask   = 16'hF800;             // バンクレジスタアドレスマスク
    assign Megarom.BankRegAddr[0]    = 16'h6000;             // バンク#0 レジスタアドレス
    assign Megarom.BankRegAddr[1]    = 16'h6800;             // バンク#1 レジスタアドレス
//  assign Megarom.BankRegAddr[2]    = 16'h7000;             // バンク#2 レジスタアドレス
//  assign Megarom.BankRegAddr[3]    = 16'h7800;             // バンク#3 レジスタアドレス
    assign Megarom.BankRegMask       = 8'hFF;                // バンクレジスタマスク
    assign Megarom.BankRegInit[0]    = 8'h00;                // バンク#0 初期値
    assign Megarom.BankRegInit[1]    = 8'h00;                // バンク#1 初期値
//  assign Megarom.BankRegInit[2]    = 8'h00;                // バンク#2 初期値
//  assign Megarom.BankRegInit[3]    = 8'h00;                // バンク#3 初期値
    assign Megarom.WriteProtect      = 1;                    // 書き込み禁止
    assign Megarom.is_16k_bank       = 0;                    // バンクサイズ 8KB
    assign Megarom.CS1_Mask          = 0;                    // 4000h~7FFFh 有効
    assign Megarom.CS2_Mask          = 1;                    // 8000h=BFFFh 無効

    /***************************************************************
     * メガロムコントローラ
     ***************************************************************/
    BUS_IF  ExtBus[0:0]();
    MEGAROM_CONTROLLER #(
        .COUNT(1),
        .USE_FF(1)
    ) u_rom (
        .RESET_n,
        .CLK,
        .Megarom,
        .BankEnable(4'b1111),
        .WriteProtect(4'b1111),
        .Bus,
        .Ram,
        .ExtBus
    );

    /***************************************************************
     * TF コントローラ
     ***************************************************************/
    TF_CONTROLLER u_tf (
        .RESET_n,
        .CLK,
        .Bus(ExtBus[0]),
        .ENA_n(Megarom.BankReg[0] != 8'h40),
        .TF,
        .Led
    );

endmodule

`default_nettype wire
