//
// cartridge_megarom.sv
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
 * MEGA ROM カードリッジ
 ***************************************************************/
module CARTRIDGE_MEGAROM #(
    parameter [23:0]    FLASH_FS_ADDR               = 0,
    parameter [23:0]    FLASH_FS_SIZE               = 0,
    parameter [23:0]    FLASH_MEGAROM_ADDR          = 0,
    parameter [23:0]    FLASH_MEGAROM_SIZE          = 0,
    parameter [23:0]    FLASH_NEXTOR_ADDR           = 0,
    parameter [23:0]    FLASH_NEXTOR_SIZE           = 0,
    parameter [23:0]    FLASH_FM_ADDR               = 0,
    parameter [23:0]    FLASH_FM_SIZE               = 0,
    parameter [23:0]    FLASH_PAC_ADDR              = 0,
    parameter [23:0]    FLASH_PAC_SIZE              = 0,
    parameter [23:0]    RAM_ADDR                    = 0,
    parameter [23:0]    RAM_SIZE                    = 0,
    parameter [7:0]     DEFAULT_BANK_REG_INIT_0     = 0,
    parameter [7:0]     DEFAULT_BANK_REG_INIT_1     = 0,
    parameter [7:0]     DEFAULT_BANK_REG_INIT_2     = 0,
    parameter [7:0]     DEFAULT_BANK_REG_INIT_3     = 0,
    parameter [15:0]    DEFAULT_BANK_REG_ADDR_0     = 16'hFFFF,
    parameter [15:0]    DEFAULT_BANK_REG_ADDR_1     = 16'hFFFF,
    parameter [15:0]    DEFAULT_BANK_REG_ADDR_2     = 16'hFFFF,
    parameter [15:0]    DEFAULT_BANK_REG_ADDR_3     = 16'hFFFF,
    parameter [15:0]    DEFAULT_BANK_REG_ADDR_MASK  = 16'h0000,
    parameter [7:0]     DEFAULT_BANK_REG_MASK       = 8'h00,
    parameter [0:0]     DEFAULT_WRITE_PROTECT       = 1'b1,
    parameter [0:0]     DEFAULT_IS_16K_BANK         = 1'b1,
    parameter [0:0]     DEFAULT_CS1_MASK            = 1'b1,
    parameter [0:0]     DEFAULT_CS2_MASK            = 1'b1,
    parameter [0:0]     DEFAULT_SCC_ENA             = 1'b0,
    parameter [0:0]     DEFAULT_SCC_I_ENA           = 1'b0,
    parameter [0:0]     DEFAULT_ENABLE_CONTINUOUS   = 1'b0,
    parameter [0:0]     DEFAULT_ENABLE              = 1'b0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    XFER_IF.HOST            Xfer,
    SOUND_IF.OUT            Sound
);

    /***************************************************************
     * メガロム設定
     ***************************************************************/
    MEGAROM_IF Megarom();
    logic SCC_ENA;
    logic SCC_I_ENA;
    MEGAROM_CONFIGURE #(
        .FLASH_FS_ADDR          (FLASH_FS_ADDR),
        .FLASH_FS_SIZE          (FLASH_FS_SIZE),
        .FLASH_MEGAROM_ADDR     (FLASH_MEGAROM_ADDR),
        .FLASH_MEGAROM_SIZE     (FLASH_MEGAROM_SIZE),
        .FLASH_NEXTOR_ADDR      (FLASH_NEXTOR_ADDR),
        .FLASH_NEXTOR_SIZE      (FLASH_NEXTOR_SIZE),
        .FLASH_FM_ADDR          (FLASH_FM_ADDR),
        .FLASH_FM_SIZE          (FLASH_FM_SIZE),
        .FLASH_PAC_ADDR         (FLASH_PAC_ADDR),
        .FLASH_PAC_SIZE         (FLASH_PAC_SIZE),
        .RAM_ADDR               (RAM_ADDR),
        .RAM_SIZE               (RAM_SIZE),
        .DEFAULT_BANK_REG_INIT_0(DEFAULT_BANK_REG_INIT_0),
        .DEFAULT_BANK_REG_INIT_1(DEFAULT_BANK_REG_INIT_1),
        .DEFAULT_BANK_REG_INIT_2(DEFAULT_BANK_REG_INIT_2),
        .DEFAULT_BANK_REG_INIT_3(DEFAULT_BANK_REG_INIT_3),
        .DEFAULT_BANK_REG_ADDR_0(DEFAULT_BANK_REG_ADDR_0),
        .DEFAULT_BANK_REG_ADDR_1(DEFAULT_BANK_REG_ADDR_1),
        .DEFAULT_BANK_REG_ADDR_2(DEFAULT_BANK_REG_ADDR_2),
        .DEFAULT_BANK_REG_ADDR_3(DEFAULT_BANK_REG_ADDR_3),
        .DEFAULT_BANK_REG_ADDR_MASK(DEFAULT_BANK_REG_ADDR_MASK),
        .DEFAULT_BANK_REG_MASK(DEFAULT_BANK_REG_MASK),
        .DEFAULT_WRITE_PROTECT(DEFAULT_WRITE_PROTECT),
        .DEFAULT_IS_16K_BANK(DEFAULT_IS_16K_BANK),
        .DEFAULT_CS1_MASK(DEFAULT_CS1_MASK),
        .DEFAULT_CS2_MASK(DEFAULT_CS2_MASK),
        .DEFAULT_SCC_ENA(DEFAULT_SCC_ENA),
        .DEFAULT_SCC_I_ENA(DEFAULT_SCC_I_ENA),
        .DEFAULT_ENABLE_CONTINUOUS(DEFAULT_ENABLE_CONTINUOUS),
        .DEFAULT_ENABLE(DEFAULT_ENABLE)
    ) u_conf (
        .RESET_n,
        .CLK,
        .Bus(ExtBus[BUS_CONFIG]),
        .Xfer(Xfer),
        .Megarom,
        .SCC_ENA,
        .SCC_I_ENA
    );

    /***************************************************************
     * メガロムコントローラ
     ***************************************************************/
    localparam BUS_CONFIG     = 0;
    localparam BUS_SCC        = 1;
    localparam BUS_COUNT      = 2;
    BUS_IF  ExtBus[0:BUS_COUNT-1]();

    // データ書き換え禁止
    wire [3:0] WriteProtect;
    assign WriteProtect[0] = WriteProtect_SCC[0];
    assign WriteProtect[1] = WriteProtect_SCC[1];
    assign WriteProtect[2] = WriteProtect_SCC[2];
    assign WriteProtect[3] = WriteProtect_SCC[3];

    // バンクレジスタ書き換え許可
    wire [3:0] BankEnable;
    assign BankEnable[0] = BankEnable_SCC[0];
    assign BankEnable[1] = BankEnable_SCC[1];
    assign BankEnable[2] = BankEnable_SCC[2];
    assign BankEnable[3] = BankEnable_SCC[3];

    MEGAROM_CONTROLLER #(
        .COUNT(BUS_COUNT),
        .USE_FF(1)
    ) u_rom (
        .RESET_n,
        .CLK,
        .Megarom,
        .BankEnable,
        .WriteProtect,
        .Bus,
        .Ram,
        .ExtBus
    );

    /***************************************************************
     * SCC
     ***************************************************************/
    assign ExtBus[BUS_SCC].INT_n = 1;
    assign ExtBus[BUS_SCC].WAIT_n = 1;

    logic [3:0] BankEnable_SCC;
    logic [3:0] WriteProtect_SCC;

    if(CONFIG::ENABLE_SCC) begin
        /***************************************************************
         * SCC-I mode register
         ***************************************************************/
        reg scc_mode_scci;
        if(CONFIG::ENABLE_SCC) begin
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n || !ExtBus[BUS_SCC].RESET_n || !SCC_I_ENA) begin
                    // SCC-I 音源無効
                    scc_mode_scci <= 0;
                    // バンクレジスタ更新は常に有効
                    BankEnable_SCC[0] <= 1;
                    BankEnable_SCC[1] <= 1;
                    BankEnable_SCC[2] <= 1;
                    BankEnable_SCC[3] <= 1;
                    // ライトプロテクトは Megarom.WriteProtect に従う
                    WriteProtect_SCC[0] <= 0;
                    WriteProtect_SCC[1] <= 0;
                    WriteProtect_SCC[2] <= 0;
                    WriteProtect_SCC[3] <= 0;
                end
                else if(ExtBus[BUS_SCC].ADDR[15:1] == 15'b1011_1111_1111_111 && !ExtBus[BUS_SCC].SLTSL_n && !ExtBus[BUS_SCC].WR_n) begin
                    // SCC/SCC-I の切り替え
                    scc_mode_scci <= ExtBus[BUS_SCC].DIN[5];
                    // バンクレジスタ更新許可フラグ
                    BankEnable_SCC[0] <= !(ExtBus[BUS_SCC].DIN[4]);
                    BankEnable_SCC[1] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[0]);
                    BankEnable_SCC[2] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[1]);
                    BankEnable_SCC[3] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[2]);
                    // Megarom.WriteProtect == 0 にしておき、WriteProtect_SCC でバンク毎のライトプロテクトを設定する
                    WriteProtect_SCC[0] <= !(ExtBus[BUS_SCC].DIN[4]);
                    WriteProtect_SCC[1] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[0]);
                    WriteProtect_SCC[2] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[1]);
                    WriteProtect_SCC[3] <= !(ExtBus[BUS_SCC].DIN[4] || ExtBus[BUS_SCC].DIN[2]);
                end;
            end
        end

        /***************************************************************
         * SOUND
         ***************************************************************/
        // sound register bank
        logic scc_bank_n;
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      scc_bank_n <= 1;
            else if(!ExtBus[BUS_SCC].RESET_n) scc_bank_n <= 1;
            else if(scc_mode_scci)            scc_bank_n <= Megarom.BankRegRaw[{ExtBus[BUS_SCC].ADDR[15], ExtBus[BUS_SCC].ADDR[13]}][7] != 1'b1;   
            else                              scc_bank_n <= Megarom.BankRegRaw[{ExtBus[BUS_SCC].ADDR[15], ExtBus[BUS_SCC].ADDR[13]}][5:0] != 6'b111111;
        end

        // address decoder
        logic scc_cs_n;
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      scc_cs_n <= 1;
            else if(!ExtBus[BUS_SCC].RESET_n) scc_cs_n <= 1;
            else if(scc_mode_scci)            scc_cs_n <= ExtBus[BUS_SCC].ADDR[15:8] != 8'hB8;
            else                              scc_cs_n <= ExtBus[BUS_SCC].ADDR[15:8] != 8'h98;
        end

        // sound module
        logic busdir_n;
        logic [7:0] dout;
        wire  [10:0] sound;
        if(CONFIG::ENABLE_SCC == CONFIG::ENABLE_IKASCC) begin
            /***************************************************************
             * IKASCC
             ***************************************************************/
            reg rst_n;
            reg clk_en;
            reg cs_n;
            reg rd_n;
            reg wr_n;
            reg [7:0] addr_l;
            reg [4:0] addr_h;
            reg [7:0] din;

            wire wr_edge = !ExtBus[BUS_SCC].WR_n && wr_n;
            wire rd_edge = !ExtBus[BUS_SCC].RD_n && rd_n;

            always_ff @(posedge ExtBus[BUS_SCC].CLK_21M) begin
                rst_n <= RESET_n && ExtBus[BUS_SCC].RESET_n;
                clk_en <= !ExtBus[BUS_SCC].CLK_EN_21M;              // CLK_EN も1クロック遅らせる
                cs_n <= ExtBus[BUS_SCC].SLTSL_n || !SCC_ENA;
                rd_n <= ExtBus[BUS_SCC].RD_n;
                wr_n <= ExtBus[BUS_SCC].WR_n;
                // WR_n, RD_n の立ち下がりでアドレス更新
                if(wr_edge || rd_edge) begin
                    addr_l <= ExtBus[BUS_SCC].ADDR[7:0];
                    addr_h <= ExtBus[BUS_SCC].ADDR[15:11];
                end
                // WR_n の立ち下がりでデータ更新
                if(wr_edge) din <= ExtBus[BUS_SCC].DIN;
            end

            wire [7:0] db_o;
            wire db_oe;

            always_ff @(posedge CLK) begin
                busdir_n <= !db_oe;
                dout <= db_oe ? db_o : 8'd0;
            end

            IKASCC #(
                .IMPL_TYPE      (0),
                .RAM_BLOCK      (1)
            ) u_scc (
                .i_EMUCLK       (ExtBus[BUS_SCC].CLK_21M),
                .i_MCLK_PCEN_n  (clk_en),
                .i_RST_n        (rst_n),

                .i_CS_n         (cs_n),
                .i_RD_n         (rd_n),
                .i_WR_n         (wr_n),
                .i_ABLO         (addr_l),
                .i_ABHI         (addr_h),

                .i_DB           (din),
                .o_DB           (db_o),
                .o_DB_OE        (db_oe),

                .o_ROMCS_n      (),
                .o_ROMADDR      (),

                .o_SOUND        (sound),

                .o_TEST         ()
            );
        end
        else begin
            /***************************************************************
             * default SCC
             ***************************************************************/
            SCC u_scc (
                .RESET_n    (RESET_n && ExtBus[BUS_SCC].RESET_n),
                .CLK        (CLK),
                .CLK_EN     (ExtBus[BUS_SCC].CLK_EN),
                .MODE_SCC_I (scc_mode_scci),
                .ADDR       (ExtBus[BUS_SCC].ADDR[7:0]),
                .CS_n       (scc_cs_n || ExtBus[BUS_SCC].SLTSL_n || ExtBus[BUS_SCC].MERQ_n || !SCC_ENA || scc_bank_n),
                .RD_n       (ExtBus[BUS_SCC].RD_n),
                .WR_n       (ExtBus[BUS_SCC].WR_n),
                .DIN        (ExtBus[BUS_SCC].DIN),
                .DOUT       (dout),
                .BUSDIR_n   (busdir_n),
                .OUT        (sound)
            );
        end

        wire [15:0] sound_ext = { sound, 5'd0 };
        assign Sound.Signal = sound_ext[15:16-$bits(Sound.Signal)];

        assign ExtBus[BUS_SCC].BUSDIR_n = busdir_n;
        assign ExtBus[BUS_SCC].DOUT = dout;
    end
    else begin
        assign ExtBus[BUS_SCC].BUSDIR_n = 1;
        assign ExtBus[BUS_SCC].DOUT = 0;
        assign Sound.Signal = 0;
        assign BankEnable_SCC[0] = 1'b1;
        assign BankEnable_SCC[1] = 1'b1;
        assign BankEnable_SCC[2] = 1'b1;
        assign BankEnable_SCC[3] = 1'b1;
        assign WriteProtect_SCC[0] = 1'b0;
        assign WriteProtect_SCC[1] = 1'b0;
        assign WriteProtect_SCC[2] = 1'b0;
        assign WriteProtect_SCC[3] = 1'b0;
    end

endmodule

`default_nettype wire
