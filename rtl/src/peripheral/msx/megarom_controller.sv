//
// megarom_controller.sv
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
 * メガロムコントローラーインターフェース
 ***********************************************************************/
interface MEGAROM_IF #(parameter ADDR_BIT_WIDTH=24, BANK_COUNT = 4);
    logic [ADDR_BIT_WIDTH-1:0]  MemoryTopAddr;                  // メモリ先頭アドレス
    logic                       WriteProtect;                   // 書き込み禁止
    logic                       is_16k_bank;                    // banksize 0:8KB / 1:16KB
    logic                       CS1_Mask;                       // 0:PAGE1 を使用する / 1:PAGE1 を使用しない
    logic                       CS2_Mask;                       // 0:PAGE2 を使用する / 1:PAGE2 を使用しない

    logic [15:0]                BankRegAddrMask;
    logic [15:0]                BankRegAddr[0:BANK_COUNT-1];
    logic [7:0]                 BankRegMask;                    // バンクレジスタマスク
    logic [7:0]                 BankRegInit[0:BANK_COUNT-1];    // バンクレジスタ初期値
    logic [7:0]                 BankReg[0:BANK_COUNT-1];        // バンクレジスタ(マスク値)
    logic [7:0]                 BankRegRaw[0:BANK_COUNT-1];     // バンクレジスタ(ライト値)

    // ホスト側ポート
    modport HOST(
                    output MemoryTopAddr, WriteProtect, is_16k_bank, CS1_Mask, CS2_Mask,

                    output BankRegAddrMask, BankRegAddr, BankRegMask, BankRegInit,
                    input  BankReg, BankRegRaw
                );

    // メガロムコントローラ側ポート
    modport DEVICE (
                    input  MemoryTopAddr, WriteProtect, is_16k_bank, CS1_Mask, CS2_Mask,

                    input  BankRegAddrMask, BankRegAddr, BankRegMask, BankRegInit,
                    inout  BankReg, BankRegRaw
                );
endinterface

/***************************************************************
 * メガロムコントローラ
 ***************************************************************/
module MEGAROM_CONTROLLER #(
    parameter               COUNT = 1,
    parameter               USE_FF = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    MEGAROM_IF.DEVICE       Megarom,
    input wire [3:0]        BankEnable,
    input wire [3:0]        WriteProtect,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    BUS_IF.MSX              ExtBus[0:COUNT-1]
);

    /***************************************************************
     * external signal
     ***************************************************************/
    logic [7:0] tmp_dout[0:COUNT-1];
    logic tmp_busdir_n[0:COUNT-1];
    logic tmp_int_n[0:COUNT-1];
    logic tmp_wait_n[0:COUNT-1];
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: extbus_loop
            if(USE_FF) begin
                always_ff @(posedge Bus.CLK_21M or negedge RESET_n) begin
                    if(!RESET_n) begin
                        ExtBus[num].CLK_EN_21M <= 0;
                    end
                    else begin
                        ExtBus[num].CLK_EN_21M <= Bus.CLK_EN_21M;
                    end
                end

                always @(posedge CLK or negedge RESET_n) begin
                    if(!RESET_n) begin
                        ExtBus[num].ADDR        <= 0;
                        ExtBus[num].DIN         <= 0;
                        ExtBus[num].RFSH_n      <= 1;
                        ExtBus[num].RD_n        <= 1;
                        ExtBus[num].WR_n        <= 1;
                        ExtBus[num].MERQ_n      <= 1;
                        ExtBus[num].IORQ_n      <= 1;
                        ExtBus[num].CS1_n       <= 1;
                        ExtBus[num].CS2_n       <= 1;
                        ExtBus[num].CS12_n      <= 1;
                        ExtBus[num].M1_n        <= 1;
                        ExtBus[num].SLTSL_n     <= 1;
                        ExtBus[num].RESET_n     <= 0;
                        ExtBus[num].CLK         <= 0;
                        ExtBus[num].CLK_EN      <= 0;
                    end
                    else if(!Bus.RESET_n) begin
                        ExtBus[num].ADDR        <= 0;
                        ExtBus[num].DIN         <= 0;
                        ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                        ExtBus[num].RD_n        <= 1;
                        ExtBus[num].WR_n        <= 1;
                        ExtBus[num].MERQ_n      <= 1;
                        ExtBus[num].IORQ_n      <= 1;
                        ExtBus[num].CS1_n       <= 1;
                        ExtBus[num].CS2_n       <= 1;
                        ExtBus[num].CS12_n      <= 1;
                        ExtBus[num].M1_n        <= 1;
                        ExtBus[num].SLTSL_n     <= 1;
                        ExtBus[num].RESET_n     <= 0;
                        ExtBus[num].CLK         <= Bus.CLK;
                        ExtBus[num].CLK_EN      <= Bus.CLK_EN;
                    end
                    else begin
                        ExtBus[num].ADDR        <= Bus.ADDR;
                        ExtBus[num].DIN         <= Bus.DIN;
                        ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                        ExtBus[num].RD_n        <= Bus.RD_n;
                        ExtBus[num].WR_n        <= Bus.WR_n;
                        ExtBus[num].MERQ_n      <= Bus.MERQ_n;
                        ExtBus[num].IORQ_n      <= Bus.IORQ_n;
                        ExtBus[num].CS1_n       <= Bus.CS1_n;
                        ExtBus[num].CS2_n       <= Bus.CS2_n;
                        ExtBus[num].CS12_n      <= Bus.CS12_n;
                        ExtBus[num].M1_n        <= Bus.M1_n;
                        ExtBus[num].SLTSL_n     <= Bus.SLTSL_n;
                        ExtBus[num].RESET_n     <= Bus.RESET_n;
                        ExtBus[num].CLK         <= Bus.CLK;
                        ExtBus[num].CLK_EN      <= Bus.CLK_EN;
                    end
                end
            end
            else begin
                assign ExtBus[num].ADDR        = Bus.ADDR;
                assign ExtBus[num].DIN         = Bus.DIN;
                assign ExtBus[num].RFSH_n      = Bus.RFSH_n;
                assign ExtBus[num].RD_n        = Bus.RD_n;
                assign ExtBus[num].WR_n        = Bus.WR_n;
                assign ExtBus[num].MERQ_n      = Bus.MERQ_n;
                assign ExtBus[num].IORQ_n      = Bus.IORQ_n;
                assign ExtBus[num].CS1_n       = Bus.CS1_n;
                assign ExtBus[num].CS2_n       = Bus.CS2_n;
                assign ExtBus[num].CS12_n      = Bus.CS12_n;
                assign ExtBus[num].M1_n        = Bus.M1_n;
                assign ExtBus[num].SLTSL_n     = Bus.SLTSL_n;
                assign ExtBus[num].RESET_n     = Bus.RESET_n;
                assign ExtBus[num].CLK         = Bus.CLK;
                assign ExtBus[num].CLK_EN      = Bus.CLK_EN;
                assign ExtBus[num].CLK_EN_21M  = Bus.CLK_EN_21M;
            end

            assign ExtBus[num].CLK_21M = Bus.CLK_21M;

            assign tmp_dout    [num] = ExtBus[num].DOUT     | ((num < COUNT-1) ? tmp_dout    [num + 1] : 0);
            assign tmp_busdir_n[num] = ExtBus[num].BUSDIR_n & ((num < COUNT-1) ? tmp_busdir_n[num + 1] : 1);
            assign tmp_int_n   [num] = ExtBus[num].INT_n    & ((num < COUNT-1) ? tmp_int_n   [num + 1] : 1);
            assign tmp_wait_n  [num] = ExtBus[num].WAIT_n   & ((num < COUNT-1) ? tmp_wait_n  [num + 1] : 1);
        end
    endgenerate

    if(USE_FF) begin
        always @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                Bus.INT_n          <= 1;
                Bus.WAIT_n         <= 1;
            end
            else if(!Bus.RESET_n) begin
                Bus.INT_n          <= 1;
                Bus.WAIT_n         <= 1;
            end
            else begin
                Bus.INT_n          <= tmp_int_n[0];
                Bus.WAIT_n         <= tmp_wait_n[0];
            end
        end
    end
    else begin
        assign Bus.INT_n          = tmp_int_n[0];
        assign Bus.WAIT_n         = tmp_wait_n[0];
    end

    /***************************************************************
     * アドレスデコード
     ***************************************************************/
    wire cs1_n  =  Bus.ADDR[15] || ~Bus.ADDR[14] || Megarom.CS1_Mask;
    wire cs2_n  = ~Bus.ADDR[15] ||  Bus.ADDR[14] || Megarom.CS2_Mask;
    wire cs12_n = (cs1_n && cs2_n);

    /***************************************************************
     * バンク毎のライトプロテクト
     ***************************************************************/
    wire bank_write_protect = WriteProtect[{Bus.ADDR[15],Bus.ADDR[13]}];

    /***************************************************************
     * memory read / write strobe
     ***************************************************************/
    wire wr_n = Bus.SLTSL_n || Bus.MERQ_n || Bus.WR_n;
    wire rd_n = Bus.SLTSL_n || Bus.MERQ_n || Bus.RD_n;
    wire wr_mem_n  = cs12_n || wr_n || Megarom.WriteProtect || bank_write_protect;
    wire rd_mem_n  = cs12_n || rd_n;

    /***************************************************************
     * ライト検出
     ***************************************************************/
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_wr_n <= 1;
        else if(!Bus.RESET_n) prev_wr_n <= 1;
        else                  prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;

    /***************************************************************
     * bank register
     ***************************************************************/
    generate
        genvar bank_num;
        for(bank_num = 0; bank_num < Megarom.BANK_COUNT; bank_num = bank_num + 1) begin: bank_reg
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    Megarom.BankReg[bank_num] <= 0;
                    Megarom.BankRegRaw[bank_num] <= 0;
                end
                else if(!Bus.RESET_n) begin
                    Megarom.BankReg[bank_num] <= Megarom.BankRegInit[bank_num];
                    Megarom.BankRegRaw[bank_num] <= Megarom.BankRegInit[bank_num];
                end
                else if(det_wr && ((Bus.ADDR & Megarom.BankRegAddrMask) == Megarom.BankRegAddr[bank_num]) && BankEnable[bank_num]) begin
                    Megarom.BankReg[bank_num] <= Bus.DIN & Megarom.BankRegMask;
                    Megarom.BankRegRaw[bank_num] <= Bus.DIN;
                end
            end
        end
    endgenerate

    /***************************************************************
     * address
     ***************************************************************/
    wire [ 7:0] bank_16;
    wire [ 7:0] bank_8;
    wire [23:0] addr_16 = Megarom.MemoryTopAddr + { 2'h0, bank_16, Bus.ADDR[13:0] };
    wire [23:0] addr_8  = Megarom.MemoryTopAddr + { 3'h0, bank_8 , Bus.ADDR[12:0] };
    wire [23:0] addr = Megarom.is_16k_bank ? addr_16 : addr_8;

    if(Megarom.BANK_COUNT >= 4) begin
        assign bank_16 = Megarom.BankReg[Bus.ADDR[15]];
        assign bank_8  = Megarom.BankReg[{Bus.ADDR[15],Bus.ADDR[13]}];
    end
    else if(Megarom.BANK_COUNT >= 3) begin
        assign bank_16 = Megarom.BankReg[Bus.ADDR[15]];
        assign bank_8  = {Bus.ADDR[15],Bus.ADDR[13]} == 2'b11 ? 8'h00 : Megarom.BankReg[{Bus.ADDR[15],Bus.ADDR[13]}];
    end
    else if(Megarom.BANK_COUNT >= 2) begin
        assign bank_16 = Megarom.BankReg[Bus.ADDR[15]];
        assign bank_8  = Megarom.BankReg[Bus.ADDR[13]];
    end
    else if(Megarom.BANK_COUNT >= 1) begin
        assign bank_16 = Bus.ADDR[15] ? 8'h00 : Megarom.BankReg[0];
        assign bank_8  = Bus.ADDR[13] ? 8'h00 : Megarom.BankReg[0];
    end
    else begin
        assign bank_16 = 8'h00;
        assign bank_8  = 8'h00;
    end


    /***************************************************************
     * memory r/w
     ***************************************************************/
    if(USE_FF) begin
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                Ram.ADDR <= 0;
                Ram.WE_n <= 1;
                Ram.DIN <= 0;
                Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                Ram.OE_n <= 1;
                Bus.BUSDIR_n <= 1;
                Bus.DOUT <= 0;
                Ram.RFSH_n <= 1;
            end
            else if(!Bus.RESET_n) begin
                Ram.ADDR <= 0;
                Ram.WE_n <= 1;
                Ram.DIN <= 0;
                Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
                Ram.OE_n <= 1;
                Bus.BUSDIR_n <= 1;
                Bus.DOUT <= 0;
                Ram.RFSH_n <= Bus.RFSH_n;
            end
            else begin
                // address
                Ram.ADDR <= (rd_mem_n && wr_mem_n) ? 0 : addr[$bits(Ram.ADDR)-1:0];

                // memory write
                Ram.WE_n <= wr_mem_n;
                Ram.DIN <= wr_mem_n ? 0 : Bus.DIN;
                Ram.DIN_SIZE <= RAM::DIN_SIZE_8;

                // memory read
                Ram.OE_n <= rd_mem_n;
                Bus.BUSDIR_n <= rd_mem_n && tmp_busdir_n[0];
                Bus.DOUT <= tmp_busdir_n[0] ? (rd_mem_n ? 0 : Ram.DOUT[7:0]) : tmp_dout[0];

                // memory refresh
                Ram.RFSH_n <= Bus.RFSH_n;
            end
        end
    end
    else begin
        // address
        assign Ram.ADDR = (rd_mem_n && wr_mem_n) ? 0 : addr[$bits(Ram.ADDR)-1:0];

        // memory write
        assign Ram.DIN_SIZE = RAM::DIN_SIZE_8;
        assign Ram.DIN  = wr_mem_n ? 0 : Bus.DIN;
        assign Ram.WE_n = wr_mem_n;

        // memory read
        assign Ram.OE_n = rd_mem_n;
        assign Bus.BUSDIR_n = rd_mem_n && tmp_busdir_n[0];
        assign Bus.DOUT = tmp_busdir_n[0] ? (rd_mem_n ? 0 : Ram.DOUT[7:0]) : tmp_dout[0];

        // memory refresh
        assign Ram.RFSH_n = Bus.RFSH_n;
    end

endmodule


`default_nettype wire
