//
// megarom_configure.sv
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
 * メガロムコントローラー設定モジュール
 ***********************************************************************/
//  0000h   キー0
//  0001h   キー1
//  0002h   キー2
//  0003h   キー3
//  000Ch   フラグ
//              b0  ライトプロテクト(1=書き込み禁止/0=書き込み許可)
//              b1  バンクサイズ(0=8KB/1=16KB)
//              b2  CS1マスク(1=4000h~7FFFh アクセス不可/0=アクセス可能)
//              b3  CS2マスク(1=8000h~BFFFh アクセス不可/0=アクセス可能)
//              b4  SCC 許可(1=有効/0=無効)
//  000Dh   バンクレジスタデータマスク
//  000Eh   バンクレジスタアドレスマスク下位
//  000Fh   バンクレジスタアドレスマスク上位
//  0010h   BANK#0 レジスタアドレス下位
//  0011h   BANK#0 レジスタアドレス上位
//  0012h   BANK#0 初期値
//  0013h   予約
//  0014h   BANK#1 レジスタアドレス下位
//  0015h   BANK#1 レジスタアドレス上位
//  0016h   BANK#1 初期値
//  0017h   予約
//  0018h   BANK#2 レジスタアドレス下位
//  0019h   BANK#2 レジスタアドレス上位
//  001Ah   BANK#2 初期値
//  001Bh   予約
//  001Ch   BANK#3 レジスタアドレス下位
//  001Dh   BANK#3 レジスタアドレス上位
//  001Eh   BANK#3 初期値
//  001Fh   予約

module MEGAROM_CONFIGURE #(
    parameter [31:0]    RAM_ADDR = 0,
    parameter [15:0]    BASE_ADDR = 0,
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
    input wire          CLK,
    input wire          RESET_n,
    BUS_IF.CARTRIDGE    Bus,
    MEGAROM_IF.HOST     Megarom,
    output reg          SCC_ENA,
    output reg          SCC_I_ENA
);
    localparam [7:0]    KEY_0 = 8'hAB;
    localparam [7:0]    KEY_1 = 8'hCD;
    localparam [7:0]    KEY_2 = 8'h98;
    localparam [7:0]    KEY_3 = 8'h76;
    localparam [4:0]    ADDR_KEY_0                  = 5'h00;
    localparam [4:0]    ADDR_KEY_1                  = 5'h01;
    localparam [4:0]    ADDR_KEY_2                  = 5'h02;
    localparam [4:0]    ADDR_KEY_3                  = 5'h03;
    localparam [4:0]    ADDR_FLAGS                  = 5'h0C;
    localparam [4:0]    ADDR_MASK_VAL               = 5'h0D;
    localparam [4:0]    ADDR_MASK_ADDR_L            = 5'h0E;
    localparam [4:0]    ADDR_MASK_ADDR_H            = 5'h0F;
    localparam [4:0]    ADDR_BANK0_ADDR_L           = 5'h10;
    localparam [4:0]    ADDR_BANK0_ADDR_H           = 5'h11;
    localparam [4:0]    ADDR_BANK0_INIT_VAL         = 5'h12;
    localparam [4:0]    ADDR_BANK0_RESERVED         = 5'h13;
    localparam [4:0]    ADDR_BANK1_ADDR_L           = 5'h14;
    localparam [4:0]    ADDR_BANK1_ADDR_H           = 5'h15;
    localparam [4:0]    ADDR_BANK1_INIT_VAL         = 5'h16;
    localparam [4:0]    ADDR_BANK1_RESERVED         = 5'h17;
    localparam [4:0]    ADDR_BANK2_ADDR_L           = 5'h18;
    localparam [4:0]    ADDR_BANK2_ADDR_H           = 5'h19;
    localparam [4:0]    ADDR_BANK2_INIT_VAL         = 5'h1A;
    localparam [4:0]    ADDR_BANK2_RESERVED         = 5'h1B;
    localparam [4:0]    ADDR_BANK3_ADDR_L           = 5'h1C;
    localparam [4:0]    ADDR_BANK3_ADDR_H           = 5'h1D;
    localparam [4:0]    ADDR_BANK3_INIT_VAL         = 5'h1E;
    localparam [4:0]    ADDR_BANK3_RESERVED         = 5'h1F;
    localparam [3:0]    BIT_FLAGS_WRITE_PROTECT     = 3'h0;
    localparam [3:0]    BIT_FLAGS_BANK_SIZE         = 3'h1;
    localparam [3:0]    BIT_FLAGS_CS1_MASK          = 3'h2;
    localparam [3:0]    BIT_FLAGS_CS2_MASK          = 3'h3;
    localparam [3:0]    BIT_FLAGS_SCC               = 3'h4; // 0 = SCC SOUND 無効 / 1= 有効
    localparam [3:0]    BIT_FLAGS_SCC_I             = 3'h5; // 0 = SCC+ 無効 / 1= 有効
    localparam [3:0]    BIT_FLAGS_ENABLE_CONTINUOUS = 3'h6; // BIT_FLAGS_ENABLE ビットはハードウェアリセットの影響を受けない
    localparam [3:0]    BIT_FLAGS_ENABLE            = 3'h7; // ROM を有効にする

    /***************************************************************
     * コントロールレジスタ
     ***************************************************************/
    reg [7:0]   ctrl_reg[0:31];

    /***************************************************************
     * 未使用信号の処理
     ***************************************************************/
    always_comb begin
        Bus.INT_n = 1;
        Bus.WAIT_n = 1;
    end

    /***************************************************************
     * リード/ライトタイミング
     ***************************************************************/
    wire rd_n = Bus.SLTSL_n || Bus.MERQ_n || Bus.RD_n;
    wire wr_n = Bus.SLTSL_n || Bus.MERQ_n || Bus.WR_n;
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_wr_n <= 1;
        else if(!Bus.RESET_n) prev_wr_n <= 1;
        else                  prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;

    /***************************************************************
     * レジスタプロテクト
     ***************************************************************/
    wire reg_protect =  (ctrl_reg[ADDR_KEY_0] != KEY_0) ||
                        (ctrl_reg[ADDR_KEY_1] != KEY_1) ||
                        (ctrl_reg[ADDR_KEY_2] != KEY_2) ||
                        (ctrl_reg[ADDR_KEY_3] != KEY_3);

    /***************************************************************
     * アドレスデコード
     ***************************************************************/
    wire cs_reg_rd_n = reg_protect || (Bus.ADDR[15:5] != BASE_ADDR[15:5]);
    wire cs_reg_wr_n = reg_protect ? (Bus.ADDR[15:2] != BASE_ADDR[15:2]) : (Bus.ADDR[15:5] != BASE_ADDR[15:5]);

    /***************************************************************
     * レジスタリード
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Bus.RESET_n || rd_n || cs_reg_rd_n) begin
            Bus.BUSDIR_n <= 1;
            Bus.DOUT <= 0;
        end
        else begin
            Bus.BUSDIR_n <= 0;
            Bus.DOUT <= ctrl_reg[Bus.ADDR[4:0]];
        end
    end

    /***************************************************************
     * レジスタライト
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ctrl_reg[ADDR_KEY_0         ] <= ~KEY_0;
            ctrl_reg[ADDR_KEY_1         ] <= ~KEY_1;
            ctrl_reg[ADDR_KEY_2         ] <= ~KEY_2;
            ctrl_reg[ADDR_KEY_3         ] <= ~KEY_3;
            ctrl_reg[ADDR_MASK_VAL      ] <= DEFAULT_BANK_REG_MASK;             // BankRegMask
            ctrl_reg[ADDR_MASK_ADDR_L   ] <= DEFAULT_BANK_REG_ADDR_MASK[7:0];   // BankRegAddrMask[7:0]
            ctrl_reg[ADDR_MASK_ADDR_H   ] <= DEFAULT_BANK_REG_ADDR_MASK[15:8];  // BankRegAddrMask[7:0]
            ctrl_reg[ADDR_BANK0_ADDR_L  ] <= DEFAULT_BANK_REG_ADDR_0[7:0];      // BankRegAddr[0][7:0]
            ctrl_reg[ADDR_BANK0_ADDR_H  ] <= DEFAULT_BANK_REG_ADDR_0[15:8];     // BankRegAddr[0][15:8]
            ctrl_reg[ADDR_BANK0_INIT_VAL] <= DEFAULT_BANK_REG_INIT_0;           // BankRegInit[0]
            ctrl_reg[ADDR_BANK0_RESERVED] <= 0;
            ctrl_reg[ADDR_BANK1_ADDR_L  ] <= DEFAULT_BANK_REG_ADDR_1[7:0];      // BankRegAddr[1][7:0]
            ctrl_reg[ADDR_BANK1_ADDR_H  ] <= DEFAULT_BANK_REG_ADDR_1[15:8];     // BankRegAddr[1][15:8]
            ctrl_reg[ADDR_BANK1_INIT_VAL] <= DEFAULT_BANK_REG_INIT_1;           // BankRegInit[1]
            ctrl_reg[ADDR_BANK1_RESERVED] <= 0;
            ctrl_reg[ADDR_BANK2_ADDR_L  ] <= DEFAULT_BANK_REG_ADDR_2[7:0];      // BankRegAddr[2][7:0]
            ctrl_reg[ADDR_BANK2_ADDR_H  ] <= DEFAULT_BANK_REG_ADDR_2[15:8];     // BankRegAddr[2][15:8]
            ctrl_reg[ADDR_BANK2_INIT_VAL] <= DEFAULT_BANK_REG_INIT_2;           // BankRegInit[2]
            ctrl_reg[ADDR_BANK2_RESERVED] <= 0;
            ctrl_reg[ADDR_BANK3_ADDR_L  ] <= DEFAULT_BANK_REG_ADDR_3[7:0];      // BankRegAddr[3][7:0]
            ctrl_reg[ADDR_BANK3_ADDR_H  ] <= DEFAULT_BANK_REG_ADDR_3[15:8];     // BankRegAddr[3][15:8]
            ctrl_reg[ADDR_BANK3_INIT_VAL] <= DEFAULT_BANK_REG_INIT_3;           // BankRegInit[3]
            ctrl_reg[ADDR_BANK3_RESERVED] <= 0;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_WRITE_PROTECT    ] <= DEFAULT_WRITE_PROTECT;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_BANK_SIZE        ] <= DEFAULT_IS_16K_BANK;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_CS1_MASK         ] <= DEFAULT_CS1_MASK;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_CS2_MASK         ] <= DEFAULT_CS2_MASK;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_SCC              ] <= DEFAULT_SCC_ENA;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_SCC_I            ] <= DEFAULT_SCC_I_ENA;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_ENABLE_CONTINUOUS] <= DEFAULT_ENABLE_CONTINUOUS;
            ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_ENABLE           ] <= DEFAULT_ENABLE;
        end
        else if(!Bus.RESET_n) begin
            // BIT_FLAGS_ENABLE_CONTINUOUS が無効なら BIT_FLAGS_ENABLE を無効にする
            // (リセットボタンでメガロムを無効にする)
            if(!ctrl_reg[ADDR_FLAGS][BIT_FLAGS_ENABLE_CONTINUOUS])
            begin
                ctrl_reg[ADDR_FLAGS][BIT_FLAGS_ENABLE] <= 0;
            end
        end
        else if(det_wr && !cs_reg_wr_n) begin
            ctrl_reg[Bus.ADDR[4:0]] <= Bus.DIN;
        end
    end

    /***************************************************************
     * 設定を転送
     ***************************************************************/
    always_comb begin
        Megarom.BankRegInit[0]  =   ctrl_reg[ADDR_BANK0_INIT_VAL];
        Megarom.BankRegInit[1]  =   ctrl_reg[ADDR_BANK1_INIT_VAL];
        Megarom.BankRegInit[2]  =   ctrl_reg[ADDR_BANK2_INIT_VAL];
        Megarom.BankRegInit[3]  =   ctrl_reg[ADDR_BANK3_INIT_VAL];
        Megarom.BankRegAddr[0]  = { ctrl_reg[ADDR_BANK0_ADDR_H  ], ctrl_reg[ADDR_BANK0_ADDR_L] };
        Megarom.BankRegAddr[1]  = { ctrl_reg[ADDR_BANK1_ADDR_H  ], ctrl_reg[ADDR_BANK1_ADDR_L] };
        Megarom.BankRegAddr[2]  = { ctrl_reg[ADDR_BANK2_ADDR_H  ], ctrl_reg[ADDR_BANK2_ADDR_L] };
        Megarom.BankRegAddr[3]  = { ctrl_reg[ADDR_BANK3_ADDR_H  ], ctrl_reg[ADDR_BANK3_ADDR_L] };
        Megarom.BankRegAddrMask = { ctrl_reg[ADDR_MASK_ADDR_H   ], ctrl_reg[ADDR_MASK_ADDR_L] };
        Megarom.BankRegMask     =   ctrl_reg[ADDR_MASK_VAL      ];
        Megarom.WriteProtect    =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_WRITE_PROTECT];
        Megarom.is_16k_bank     =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_BANK_SIZE    ];
        Megarom.CS1_Mask        =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_CS1_MASK     ] || !ctrl_reg[ADDR_FLAGS][BIT_FLAGS_ENABLE];
        Megarom.CS2_Mask        =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_CS2_MASK     ] || !ctrl_reg[ADDR_FLAGS][BIT_FLAGS_ENABLE];
        SCC_ENA                 =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_SCC          ];
        SCC_I_ENA               =   ctrl_reg[ADDR_FLAGS         ][BIT_FLAGS_SCC_I        ];
        Megarom.MemoryTopAddr   = RAM_ADDR[$bits(Megarom.MemoryTopAddr)-1:0];
    end

endmodule

`default_nettype wire
