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
interface MEGAROM_IF #(parameter ADDR_BIT_WIDTH=24);
    logic [ADDR_BIT_WIDTH-1:0]  MemoryTopAddr;                  // メモリ先頭アドレス
    logic                       WriteProtect;                   // 書き込み禁止
    logic                       is_16k_bank;                    // banksize 0:8KB / 1:16KB
    logic                       CS1_Mask;                       // 0:PAGE1 を使用する / 1:PAGE1 を使用しない
    logic                       CS2_Mask;                       // 0:PAGE2 を使用する / 1:PAGE2 を使用しない

    logic [15:0]                BankRegAddrMask;
    logic [15:0]                BankRegAddr[0:4-1];
    logic [7:0]                 BankRegMask;           // バンクレジスタマスク
    logic [7:0]                 BankRegInit[0:4-1];    // バンクレジスタ初期値
    logic [7:0]                 BankReg[0:4-1];        // バンクレジスタ(マスク値)
    logic [7:0]                 BankRegRaw[0:4-1];     // バンクレジスタ(ライト値)

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
    parameter               COUNT = 1
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
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: extbus_loop
            always @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    ExtBus[num].ADDR        <= 0;
                    ExtBus[num].DIN         <= 0;
                    ExtBus[num].RFSH_n      <= 1;
                    ExtBus[num].RD_n        <= 1;
                    ExtBus[num].WR_n        <= 1;
                    ExtBus[num].IORQ_n      <= 1;
                    ExtBus[num].SLTSL_n     <= 1;
                    ExtBus[num].RESET_n     <= 0;
                    ExtBus[num].CLK         <= 0;
                end
                else if(!Bus.RESET_n) begin
                    ExtBus[num].ADDR        <= 0;
                    ExtBus[num].DIN         <= 0;
                    ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                    ExtBus[num].RD_n        <= 1;
                    ExtBus[num].WR_n        <= 1;
                    ExtBus[num].IORQ_n      <= 1;
                    ExtBus[num].SLTSL_n     <= 1;
                    ExtBus[num].RESET_n     <= 0;
                    ExtBus[num].CLK         <= Bus.CLK;
                end
                else begin
                    ExtBus[num].ADDR        <= Bus.ADDR;
                    ExtBus[num].DIN         <= Bus.DIN;
                    ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                    ExtBus[num].RD_n        <= Bus.RD_n;
                    ExtBus[num].WR_n        <= Bus.WR_n;
                    ExtBus[num].IORQ_n      <= Bus.IORQ_n;
                    ExtBus[num].SLTSL_n     <= Bus.SLTSL_n;
                    ExtBus[num].RESET_n     <= Bus.RESET_n;
                    ExtBus[num].CLK         <= Bus.CLK;
                end
            end
        end
    endgenerate

    /***************************************************************
     * INT / WAIT
     ***************************************************************/
    wire [COUNT-1:0] w_int_n_n;
    wire [COUNT-1:0] w_wait_n_n;
    generate
        genvar i;
        for(i = 0; i < COUNT; i = i + 1) begin: lp
            assign w_int_n_n[i]  = ~ExtBus[i].INT_n;
            assign w_wait_n_n[i] = ~ExtBus[i].WAIT_n;
        end
    endgenerate

    NOR_Nbits #(
        .COUNT(COUNT)
    ) u_nor_int (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_int_n_n),
        .OUT(Bus.INT_n)
    );

    NOR_Nbits #(
        .COUNT(COUNT)
    ) u_nor_wait (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_wait_n_n),
        .OUT(Bus.WAIT_n)
    );

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
    wire wr_n = Bus.SLTSL_n || Bus.WR_n;
    wire rd_n = Bus.SLTSL_n || Bus.RD_n;
    wire wr_mem_n  = cs12_n || wr_n || Megarom.WriteProtect || bank_write_protect;
    wire rd_mem_n  = cs12_n || rd_n;

    /***************************************************************
     * bank register
     * 次の RD/WR サイクルまでに間に合えば良いので処理を分割する
     ***************************************************************/
    reg [9:0] ff_bank16_offset[0:4-1];
    reg [10:0] ff_bank8_offset[0:4-1];

    // wr_n 遅延
    reg ff_wr_n_delay;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          ff_wr_n_delay <= 1;
        else if(!Bus.RESET_n) ff_wr_n_delay <= 1;
        else                  ff_wr_n_delay <= wr_n;
    end

    // 書き込み先アドレスをマスク
    reg [7:0] ff_cmp_addr;
    always_ff @(posedge CLK) ff_cmp_addr <= Bus.ADDR[15:8] & Megarom.BankRegAddrMask[15:8];

    generate
        genvar bank_num;
        for(bank_num = 0; bank_num < 4; bank_num = bank_num + 1) begin: bank_reg
            // アドレス比較
            reg ff_wr_bank_n;
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)          ff_wr_bank_n <= 1;
                else if(!Bus.RESET_n) ff_wr_bank_n <= 1;
                else                  ff_wr_bank_n <= (ff_cmp_addr != Megarom.BankRegAddr[bank_num][15:8]) | ff_wr_n_delay;
            end

            // エッジ検出
            reg ff_wr_bank_n_delay;
            wire w_det_wr = ff_wr_bank_n_delay && ~ff_wr_bank_n;
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n)          ff_wr_bank_n_delay <= 1;
                else if(!Bus.RESET_n) ff_wr_bank_n_delay <= 1;
                else                  ff_wr_bank_n_delay <= ff_wr_bank_n;
            end

            // write
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    Megarom.BankReg[bank_num] <= 0;
                    Megarom.BankRegRaw[bank_num] <= 0;
                end
                else if(!Bus.RESET_n) begin
                    Megarom.BankReg[bank_num] <= Megarom.BankRegInit[bank_num];
                    Megarom.BankRegRaw[bank_num] <= Megarom.BankRegInit[bank_num];
                end
                else if(w_det_wr && BankEnable[bank_num]) begin
                    Megarom.BankReg[bank_num] <= Bus.DIN & Megarom.BankRegMask;
                    Megarom.BankRegRaw[bank_num] <= Bus.DIN;
                end
            end

            // 処理を軽くする為に、バンク切り替え時にアドレスを計算しておく
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    ff_bank16_offset[bank_num] <= Megarom.MemoryTopAddr[23:14];
                    ff_bank8_offset[bank_num] <= Megarom.MemoryTopAddr[23:13];
                end
                else begin
                    ff_bank16_offset[bank_num] <= Megarom.MemoryTopAddr[23:14] + { 2'h0, Megarom.BankReg[bank_num]};
                    ff_bank8_offset[bank_num] <= Megarom.MemoryTopAddr[23:13] + { 3'h0, Megarom.BankReg[bank_num]};
                end
            end
        end
    endgenerate

    /***************************************************************
     * address
     ***************************************************************/
    wire [ 7:0] bank_16;
    wire [ 7:0] bank_8;
    wire [23:0] addr_16 = { ff_bank16_offset[Bus.ADDR[15]], Bus.ADDR[13:0] };
    wire [23:0] addr_8  = { ff_bank8_offset[{Bus.ADDR[15],Bus.ADDR[13]}], Bus.ADDR[12:0] };
    wire [23:0] addr = Megarom.is_16k_bank ? addr_16 : addr_8;

    /***************************************************************
     * memory r/w
     ***************************************************************/
    wire [COUNT:0] w_busdir_n_n;
    assign w_busdir_n_n[COUNT] = ~rd_mem_n;
    generate
        genvar busdir_i;
        for(busdir_i = 0; busdir_i < COUNT; busdir_i = busdir_i + 1) begin: busdir_lp
            assign w_busdir_n_n[busdir_i] = ~ExtBus[busdir_i].BUSDIR_n;
        end
    endgenerate

    NOR_Nbits #(
        .COMB(1),
        .COUNT(COUNT+1)
    ) u_nor_busdir (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_busdir_n_n),
        .OUT(Bus.BUSDIR_n)
    );

    wire [7:0] w_dout[0:COUNT];
    assign w_dout[COUNT] = Ram.DOUT[7:0];
    generate
        genvar dout_i;
        for(dout_i = 0; dout_i < COUNT; dout_i = dout_i + 1) begin: dout_lp
            assign w_dout[dout_i] = ExtBus[dout_i].DOUT;
        end
    endgenerate

    ARRAY_SELECTOR #(
        .COMB(1),
        .WIDTH(8),
        .COUNT(COUNT+1)
    ) u_select_dout (
        .RESET_n(RESET_n & Bus.RESET_n),
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_dout),
        .OE(w_busdir_n_n),
        .OUT(Bus.DOUT)
    );

    assign Ram.DSIZE = RAM::DSIZE_8;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Ram.ADDR <= 0;
            Ram.WE_n <= 1;
            Ram.DIN <= 0;
            Ram.OE_n <= 1;
            Ram.RFSH_n <= 1;
        end
        else if(!Bus.RESET_n) begin
            Ram.ADDR <= 0;
            Ram.WE_n <= 1;
            Ram.DIN <= 0;
            Ram.OE_n <= 1;
            Ram.RFSH_n <= Bus.RFSH_n;
        end
        else begin
            // address
            Ram.ADDR <= addr[$bits(Ram.ADDR)-1:0];

            // memory write
            Ram.WE_n <= wr_mem_n;
            Ram.DIN <= Bus.DIN;

            // memory read
            Ram.OE_n <= rd_mem_n;

            // memory refresh
            Ram.RFSH_n <= Bus.RFSH_n;
        end
    end
endmodule


`default_nettype wire
