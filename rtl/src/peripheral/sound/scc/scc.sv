//
// scc.sv
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
 * SCC sound
 ***************************************************************/
module SCC (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire          CS_n,
    input wire [7:0]    ADDR,
    input wire          WR_n,
    input wire          RD_n,
    output wire         BUSDIR_n,
    input wire [7:0]    DIN,
    output wire [7:0]   DOUT,

    output reg [10:0]   OUT
);
    /***************************************************************
     * 読み書きタイミング
     ***************************************************************/
    wire rd_n = CS_n || RD_n;
    wire wr_n = CS_n || WR_n;
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                 prev_wr_n <= 1;
        else if(!wr_n && !cs_test_n) prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;
    wire det_rd = !rd_n;

    /***************************************************************
     * アドレスデコーダ
     ***************************************************************/
    wire cs_reg_n = ADDR[7:5] != 3'b100;
    wire cs_test_n = ADDR[7:5] != 3'b111;
    wire cs_enable_n = cs_reg_n || (ADDR[3:0] != 4'b1111);

    /***************************************************************
     * TEST レジスタ
     ***************************************************************/
    logic [7:0] test_reg;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                  test_reg <= 0;
        else if(det_wr && !cs_test_n) test_reg <= DIN;
    end

    /***************************************************************
     * ENABLE レジスタ
     ***************************************************************/
    logic [7:0] enable_reg;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                    enable_reg <= 0;
        else if(det_wr && !cs_enable_n) enable_reg <= DIN;
    end

    /***************************************************************
     * 出力更新カウンタ
     ***************************************************************/
    logic [3:0] out_cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    out_cnt <= 0;
        else if(CLK_EN) out_cnt <= out_cnt + 1'd1;
    end
    wire OUT_EN = out_cnt == 0;

    /***************************************************************
     * 各チャンネルの処理
     ***************************************************************/
    logic busdir_n[0:4];
    logic [7:0] dout[0:4];
    logic [7:0] ch_out[0:4];

    generate
        genvar chnum;
        for(chnum = 0; chnum < 5; chnum = chnum + 1) begin: ch
            SCC_SIGNAL_GENERATOR u_gen (
                .RESET_n,
                .CLK,
                .CLK_EN,
                .TEST_CNTM  (test_reg[0]),
                .TEST_CNTH  (test_reg[1]),
                .TEST_ADDR  (test_reg[5]),
                .TEST_MEM   (chnum == 4 ? test_reg[7] : test_reg[6]),
                .ADDR       (ADDR[4:0]),
                .WR_FREQ_L_n(!det_wr || cs_reg_n || (ADDR[3:0] != (chnum * 2 +  0))),
                .WR_FREQ_H_n(!det_wr || cs_reg_n || (ADDR[3:0] != (chnum * 2 +  1))),
                .WR_VOL_n   (!det_wr || cs_reg_n || (ADDR[3:0] != (chnum     + 10))),
                .WR_WAVE_n  (chnum < 4 ? (!det_wr || (ADDR[7:5] != chnum)) : (!det_wr || (ADDR[7:5] != 3))),
                .RD_WAVE_n  (chnum < 4 ? (!det_rd || (ADDR[7:5] != chnum)) : (!det_rd || (ADDR[7:5] != 5))),
                .BUSDIR_n   (busdir_n[chnum]),
                .DIN,
                .DOUT       (dout[chnum]),
                .MUTE_n     (enable_reg[chnum]),
                .OUT_EN,
                .OUT        (ch_out[chnum])
            );
        end
    endgenerate

    /***************************************************************
     * 波形メモリのデータを CPU 側へ出力
     ***************************************************************/
    assign BUSDIR_n = busdir_n[0] && busdir_n[1] && busdir_n[2] && busdir_n[3] && busdir_n[4];
    assign DOUT = dout[0] | dout[1] | dout[2] | dout[3] | dout[4];

    /***************************************************************
     * ミキサー
     ***************************************************************/
    SCC_MIXER u_mixer (
        .RESET_n,
        .CLK,
        .CLK_EN(CLK_EN && OUT_EN),
        .IN(ch_out),
        .OUT(OUT)
    );
endmodule

/***********************************************************************
 * ミキサー
 ***********************************************************************/
module SCC_MIXER (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,
    input wire [7:0]    IN[0:4],
    output reg [10:0]   OUT
);

    logic [10:0] in_0;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    in_0 <= 0;
        else if(CLK_EN) in_0 <= IN[0][7] ? {3'b111,IN[0]} : {3'b000,IN[0]};
    end

    logic [10:0] in_1;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    in_1 <= 0;
        else if(CLK_EN) in_1 <= IN[1][7] ? {3'b111,IN[1]} : {3'b000,IN[1]};
    end

    logic [10:0] in_2;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    in_2 <= 0;
        else if(CLK_EN) in_2 <= IN[2][7] ? {3'b111,IN[2]} : {3'b000,IN[2]};
    end

    logic [10:0] in_3;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    in_3 <= 0;
        else if(CLK_EN) in_3 <= IN[3][7] ? {3'b111,IN[3]} : {3'b000,IN[3]};
    end

    logic [10:0] in_4;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    in_4 <= 0;
        else if(CLK_EN) in_4 <= IN[4][7] ? {3'b111,IN[4]} : {3'b000,IN[4]};
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    OUT <= 0;
        else if(CLK_EN) OUT <= in_0 + in_1 + in_2 + in_3 + in_4;
    end

endmodule

/***********************************************************************
 * SCC 1CH シグナルジェネレータ
 ***********************************************************************/
module SCC_SIGNAL_GENERATOR (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire          TEST_CNTM,      // TEST.b0
    input wire          TEST_CNTH,      // TEST.b1
    input wire          TEST_ADDR,      // TEST.b5
    input wire          TEST_MEM,       // TEST.b6(ch0~3), TEST.b7(ch4)

    input wire [4:0]    ADDR,
    input wire          WR_FREQ_L_n,
    input wire          WR_FREQ_H_n,
    input wire          WR_VOL_n,
    input wire          WR_WAVE_n,
    input wire          RD_WAVE_n,
    output wire         BUSDIR_n,
    input wire  [7:0]   DIN,
    output wire  [7:0]  DOUT,

    input wire          MUTE_n,
    input wire          OUT_EN,
    output reg [7:0]    OUT
);

    logic [4:0] WAVE_ADDR;
    SCC_COUNTER u_cnt (
        .RESET_n,
        .CLK,
        .CLK_EN,
        .TEST_CNTM,
        .TEST_CNTH,
        .TEST_ADDR,
        .WR_FREQ_L_n,
        .WR_FREQ_H_n,
        .DIN,
        .WAVE_ADDR
    );

    wire [7:0] WAVE_DATA;
    SCC_WAVE_MEMORY u_mem (
        .RESET_n,
        .CLK,
        .TEST_MEM,
        .ADDR(ADDR[4:0]),
        .RD_WAVE_n,
        .WR_WAVE_n,
        .DIN,
        .BUSDIR_n,
        .DOUT,
        .WAVE_ADDR,
        .WAVE_DATA
    );

    SCC_AMP u_amp (
        .RESET_n,
        .CLK,
        .CLK_EN,
        .WR_VOL_n,
        .DIN(DIN[3:0]),
        .WAVE_DATA,
        .MUTE_n,
        .OUT_EN,
        .OUT
    );
endmodule

/***********************************************************************
 * SCC CH カウンター
 ***********************************************************************/
module SCC_COUNTER (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire          TEST_CNTM,      // TEST.b0
    input wire          TEST_CNTH,      // TEST.b1
    input wire          TEST_ADDR,      // TEST.b5

    input wire          WR_FREQ_L_n,
    input wire          WR_FREQ_H_n,
    input wire [7:0]    DIN,

    output reg [4:0]    WAVE_ADDR
);

    /***************************************************************
     * 分周レジスタライト
     ***************************************************************/
    logic [3:0] freq_l;
    logic [3:0] freq_m;
    logic [3:0] freq_h;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            freq_l <= 0;
            freq_m <= 0;
            freq_h <= 0;
        end
        else if(!WR_FREQ_L_n) begin
            freq_l <= DIN[3:0];
            freq_m <= DIN[7:4];
        end
        else if(!WR_FREQ_H_n) begin
            freq_h <= DIN[3:0];
        end
    end

    /***************************************************************
     * カウンタの動作条件
     ***************************************************************/
    wire dec_cnt_l = CLK_EN;
    wire dec_cnt_m = (dec_cnt_l && (cnt_l == 0)) || TEST_CNTM;
    wire dec_cnt_h = (dec_cnt_m && (cnt_m == 0)) || TEST_CNTH;
    wire inc_adr   = (dec_cnt_h && (cnt_h == 0));
    wire rst_cnt   = inc_adr;
    wire rst_adr   = (TEST_ADDR && (!WR_FREQ_L_n || !WR_FREQ_H_n));

    /***************************************************************
     * 分周カウント
     ***************************************************************/
    logic [3:0] cnt_l;
    logic [3:0] cnt_m;
    logic [3:0] cnt_h;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)       cnt_l <= 0;
        else if(rst_cnt)   cnt_l <= freq_l;
        else if(dec_cnt_l) cnt_l <= cnt_l - 1'd1;
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)       cnt_m <= 0;
        else if(rst_cnt)   cnt_m <= freq_m;
        else if(dec_cnt_m) cnt_m <= cnt_m - 1'd1;
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)       cnt_h <= 0;
        else if(rst_cnt)   cnt_h <= freq_h;
        else if(dec_cnt_h) cnt_h <= cnt_h - 1'd1;
    end

    /***************************************************************
     * アドレスカウント
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)       WAVE_ADDR <= 0;
        else if(rst_adr)   WAVE_ADDR <= 0;
        else if(inc_adr)   WAVE_ADDR <= WAVE_ADDR + 1'd1;
    end

endmodule

/***********************************************************************
 * SCC CH 波形メモリー
 ***********************************************************************/
module SCC_WAVE_MEMORY (
    input wire          RESET_n,
    input wire          CLK,

    input wire          TEST_MEM,   // TEST.b6(ch0~3), TEST.b7(ch4)

    input wire [4:0]    ADDR,
    input wire          RD_WAVE_n,
    input wire          WR_WAVE_n,
    input wire  [7:0]   DIN,
    output reg          BUSDIR_n,
    output reg [7:0]    DOUT,

    input wire [4:0]    WAVE_ADDR,
    output reg  [7:0]   WAVE_DATA
);
    reg [7:0] buffer[0:31];

    /***************************************************************
     * メモリ R/W
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            BUSDIR_n <= 1;
            DOUT <= 0;
            WAVE_DATA <= 0;
        end
        else if(TEST_MEM) begin
            BUSDIR_n <= 1;
            DOUT <= 0;
            WAVE_DATA <= buffer[WAVE_ADDR];
        end
        else if(!WR_WAVE_n) begin
            BUSDIR_n <= 1;
            DOUT <= 0;
            WAVE_DATA <= DIN;
            buffer[ADDR] <= DIN;
        end
        else if(!RD_WAVE_n) begin
            BUSDIR_n <= 0;
            DOUT <= buffer[ADDR];
            WAVE_DATA <= buffer[ADDR];
        end
        else begin
            BUSDIR_n <= 1;
            DOUT <= 0;
            WAVE_DATA <= buffer[WAVE_ADDR];
        end
    end
endmodule

/***********************************************************************
 * SCC CH アンプ
 ***********************************************************************/
module SCC_AMP (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire          WR_VOL_n,
    input wire [3:0]    DIN,

    input wire [7:0]    WAVE_DATA,

    input wire          MUTE_n,
    input wire          OUT_EN,
    output reg [7:0]    OUT
);
    logic [3:0] vol;
    logic [3:0] cnt;
    logic [11:0] sum;

    /***************************************************************
     * 音量レジスタライト
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            vol <= 0;
        end
        else if(!WR_VOL_n) begin
            vol <= DIN;
        end
    end

    /***************************************************************
     * 波形データを12bitへ拡張
     ***************************************************************/
    wire [11:0] data_12bit = WAVE_DATA[7] ? {4'b1111,WAVE_DATA} : {4'b0000,WAVE_DATA};

    /***************************************************************
     * 音量の分だけ加算する
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT <= 0;
            cnt <= 0;
            sum <= 0;
        end
        else if(CLK_EN) begin
            if(OUT_EN) begin
                OUT <= MUTE_n ? sum[11:4] : 0;

                if(vol != 0) begin
                    cnt <= vol - 1'd1;
                    sum <= data_12bit;
                end
                else begin
                    cnt <= 0;
                    sum <= 0;
                end
            end
            else begin
                if(cnt != 0) begin
                    cnt <= cnt - 1'd1;
                    sum <= sum + data_12bit;
                end
            end
        end
    end
endmodule

`default_nettype wire
