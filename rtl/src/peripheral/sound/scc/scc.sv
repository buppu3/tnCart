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

/***********************************************************************
 * SCC
 ***********************************************************************/
module SCC (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire [7:0]    ADDR,
    input wire          CS_n,
    input wire          RD_n,
    input wire          WR_n,
    input wire [7:0]    DIN,
    output reg [7:0]    DOUT,
    output reg          BUSDIR_n,

    output reg [9:0]    Sound
);
    localparam CH_COUNT = 5;

    /***************************************************************
     * レジスタ
     ***************************************************************/
    localparam SCC_REG_DIV_L = 0;
    localparam SCC_REG_DIV_H = 1;
    localparam SCC_REG_VOL = 10;
    localparam SCC_REG_ENA = 15;
    localparam SCC_REG_MODE = 16;
    logic [7:0] scc_reg_file[0:SCC_REG_MODE];

    /***************************************************************
     * 波形メモリ
     ***************************************************************/
    localparam SCC_IN_WIDTH = 8;                   // -128~127
    localparam SCC_OUT_WIDTH = 11;                  // -600~595
    localparam [SCC_OUT_WIDTH-1:0] SCC_OFFSET = 128;
    logic [SCC_IN_WIDTH-1:0] wave_8bit[0:CH_COUNT-1];
    logic [4:0] wave_addr[0:CH_COUNT-1];
    logic wave_rotate[0:CH_COUNT-1];

    SCC_WAVE_TABLE u_wave_a (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .BUS_ADDR(ADDR[4:0]),
        .BUS_OE_n(RD_n || (ADDR[7:5] != 3'b000)),
        .BUS_WE_n(WR_n || (ADDR[7:5] != 3'b000)),
        .BUS_ENA_n(CS_n),
        .WDATA(DIN),
        .SOUND_ADDR(wave_addr[0]),
        .RDATA(wave_8bit[0]),
        .ROTATE((scc_reg_file[SCC_REG_MODE][6] != 0) && wave_rotate[0])
    );

    SCC_WAVE_TABLE u_wave_b (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .BUS_ADDR(ADDR[4:0]),
        .BUS_OE_n(RD_n || (ADDR[7:5] != 3'b001)),
        .BUS_WE_n(WR_n || (ADDR[7:5] != 3'b001)),
        .BUS_ENA_n(CS_n),
        .WDATA(DIN),
        .SOUND_ADDR(wave_addr[1]),
        .RDATA(wave_8bit[1]),
        .ROTATE((scc_reg_file[SCC_REG_MODE][6] != 0) && wave_rotate[1])
    );

    SCC_WAVE_TABLE u_wave_c (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .BUS_ADDR(ADDR[4:0]),
        .BUS_OE_n(RD_n || (ADDR[7:5] != 3'b010)),
        .BUS_WE_n(WR_n || (ADDR[7:5] != 3'b010)),
        .BUS_ENA_n(CS_n),
        .WDATA(DIN),
        .SOUND_ADDR(wave_addr[2]),
        .RDATA(wave_8bit[2]),
        .ROTATE((scc_reg_file[SCC_REG_MODE][6] != 0) && wave_rotate[2])
    );

    SCC_WAVE_TABLE u_wave_d (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .BUS_ADDR(ADDR[4:0]),
        .BUS_OE_n(RD_n || (ADDR[7:5] != 3'b011)),
        .BUS_WE_n(WR_n || (ADDR[7:5] != 3'b011)),
        .BUS_ENA_n(CS_n),
        .WDATA(DIN),
        .SOUND_ADDR(wave_addr[3]),
        .RDATA(wave_8bit[3]),
        .ROTATE((scc_reg_file[SCC_REG_MODE][7:6] != 0) && wave_rotate[3])
    );

    SCC_WAVE_TABLE u_wave_e (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .BUS_ADDR(ADDR[4:0]),
        .BUS_OE_n(RD_n || (ADDR[7:5] != 3'b101)),
        .BUS_WE_n(WR_n || (ADDR[7:5] != 3'b011)),
        .BUS_ENA_n(CS_n),
        .WDATA(DIN),
        .SOUND_ADDR(wave_addr[4]),
        .RDATA(wave_8bit[4]),
        .ROTATE((scc_reg_file[SCC_REG_MODE][7:6] != 0) && wave_rotate[3])
    );

    /***************************************************************
     * レジスタリード
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            DOUT <= 8'hFF;
            BUSDIR_n <= 1;
        end
        else if(RD_n || CS_n) begin
            DOUT <= 8'hFF;
            BUSDIR_n <= 1;
        end
        else begin
            BUSDIR_n <= 0;
            case (ADDR[7:5])
                3'b000: DOUT <= wave_8bit[0];                   // 波形メモリ chA
                3'b001: DOUT <= wave_8bit[1];                   // 波形メモリ chB
                3'b010: DOUT <= wave_8bit[2];                   // 波形メモリ chC
                3'b011: DOUT <= wave_8bit[3];                   // 波形メモリ chD
                3'b100: DOUT <= scc_reg_file[ADDR[3:0]];    // コントロールレジスタ
                3'b101: DOUT <= wave_8bit[4];                   // 波形メモリ chE
                3'b110: DOUT <= scc_reg_file[SCC_REG_MODE];     // モードレジスタ
                default:DOUT <= 8'hFF;
            endcase
        end
    end

    /***************************************************************
     * レジスタライト
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            //
            // レジスタ初期化
            //
            scc_reg_file[0] <= 0;
            scc_reg_file[1] <= 0;
            scc_reg_file[2] <= 0;
            scc_reg_file[3] <= 0;
            scc_reg_file[4] <= 0;
            scc_reg_file[5] <= 0;
            scc_reg_file[6] <= 0;
            scc_reg_file[7] <= 0;
            scc_reg_file[8] <= 0;
            scc_reg_file[9] <= 0;
            scc_reg_file[10] <= 0;
            scc_reg_file[11] <= 0;
            scc_reg_file[12] <= 0;
            scc_reg_file[13] <= 0;
            scc_reg_file[14] <= 0;
            scc_reg_file[15] <= 0;
            scc_reg_file[16] <= 0;
        end
        else if(!CS_n && !WR_n) begin
            //
            // レジスタライト
            //
            case (ADDR[7:5])
                3'b100: scc_reg_file[ADDR[3:0]] <= DIN; // コントロールレジスタ
                3'b110: scc_reg_file[SCC_REG_MODE] <= DIN;  // モードレジスタ
            endcase
        end
    end

    /***************************************************************
     * ENA が 0->1 になった CH を検出
     ***************************************************************/
    logic [7:0] prev_ena_reg;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)        prev_ena_reg <= 0;
        else if(!CLK_EN)    prev_ena_reg <= prev_ena_reg;
        else                prev_ena_reg <= scc_reg_file[SCC_REG_ENA];
    end

    logic det_ena[0:CH_COUNT-1];
    generate
        genvar ena_ch;
        for(ena_ch = 0; ena_ch < CH_COUNT; ena_ch = ena_ch + 1) begin: ena_loop
            always_comb begin
                if(!RESET_n)        det_ena[ena_ch] = 0;
                else if(!CLK_EN)    det_ena[ena_ch] = 0;
                else                det_ena[ena_ch] = !prev_ena_reg[ena_ch] && scc_reg_file[SCC_REG_ENA][ena_ch];
            end
        end
    endgenerate

    /***************************************************************
     * WR_n のエッジを検出
     ***************************************************************/
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)        prev_wr_n <= 0;
        else if(!CLK_EN)    prev_wr_n <= prev_wr_n;
        else                prev_wr_n <= WR_n;
    end

    logic det_wrt;
    always_comb begin
        if(!RESET_n)        det_wrt = 0;
        else if(!CLK_EN)    det_wrt = 0;
        else                det_wrt = prev_wr_n && !WR_n;
    end

    /***************************************************************
     * 分周レジスタ書き換えを検出
     ***************************************************************/
    logic det_wrt_div[0:CH_COUNT-1];
    generate
        genvar wrt_ch;
        for(wrt_ch = 0; wrt_ch < CH_COUNT; wrt_ch = wrt_ch + 1) begin: wrt_loop
            always_comb begin
                if(!RESET_n)        det_wrt_div[wrt_ch] = 0;
                else if(!CLK_EN)    det_wrt_div[wrt_ch] = 0;
                else                det_wrt_div[wrt_ch] = det_wrt && (ADDR[7:1] == (SCC_REG_DIV_L[7:1] + wrt_ch));
            end
        end
    endgenerate

    /***************************************************************
     * 波形メモリアドレス リスタート
     ***************************************************************/
    logic restart[0:CH_COUNT-1];
    generate
        genvar restart_ch;
        for(restart_ch = 0; restart_ch < CH_COUNT; restart_ch = restart_ch + 1) begin: restart_loop
            always_comb begin
                if(!RESET_n)                                                      restart[restart_ch] = 1;
                else if(!CLK_EN)                                                  restart[restart_ch] = 0;
                else if(det_ena[restart_ch])                                      restart[restart_ch] = 1;  // イネーブルが 0->1
                else if(scc_reg_file[SCC_REG_MODE][5] && det_wrt_div[restart_ch]) restart[restart_ch] = 1;  // 分周比レジスタライト
                else                                                              restart[restart_ch] = 0;
            end
        end
    endgenerate

    /***************************************************************
     * 波形メモリアドレス移動
     ***************************************************************/
    logic [4:0] pointer[0:CH_COUNT-1];
    generate
        genvar addr_ch;
        for(addr_ch = 0; addr_ch < CH_COUNT; addr_ch = addr_ch + 1) begin: addr_loop
            SCC_ADDR u_addr (
                .CLK(CLK),
                .RESET_n(RESET_n),
                .CLK_EN(CLK_EN),
                .MODE_4b(scc_reg_file[SCC_REG_MODE][0]),
                .MODE_8b(scc_reg_file[SCC_REG_MODE][1]),
                .MODE_ROATE(scc_reg_file[SCC_REG_MODE][6] || (addr_ch >= 4 && scc_reg_file[SCC_REG_MODE][7])),
                .RESTART(restart[addr_ch]),
                .DIV({scc_reg_file[SCC_REG_DIV_H + addr_ch * 2][3:0], scc_reg_file[SCC_REG_DIV_L + addr_ch * 2][7:0]}),
                .ROTATE(wave_rotate[addr_ch]),
                .ADDR(wave_addr[addr_ch])
            );
        end
    endgenerate

    /***************************************************************
     * 音量
     * (-128~127) * (0~15) = -1920~1905
     ***************************************************************/
    logic [11:0] amp_12bit[0:CH_COUNT-1];
    generate
        genvar amp_ch;
        for(amp_ch = 0; amp_ch < CH_COUNT; amp_ch = amp_ch + 1) begin: amp_loop
            SCC_AMP u_amp (
                .CLK(CLK),
                .RESET_n(RESET_n),
                .IN(wave_8bit[amp_ch]),
                .VOL(scc_reg_file[SCC_REG_VOL + amp_ch][3:0]),
                .OUT(amp_12bit[amp_ch])
            );
        end
    endgenerate

    /***************************************************************
     * MIXER
     ***************************************************************/
    logic [10:0] mix_11bit;
    SCC_MIXER #(
        .CH_COUNT(CH_COUNT),
        .SCC_OFFSET(SCC_OFFSET),
        .IN_BIT_WIDTH($bits(amp_12bit[0])),
        .OUT_BIT_WIDTH($bits(mix_11bit))
    ) u_mixer (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .ENABLE(scc_reg_file[SCC_REG_ENA][CH_COUNT-1:0]),
        .IN(amp_12bit),
        .OUT(mix_11bit)
    );

    /***************************************************************
     * 出力レベルを合わせる -600~595 -> -512~507
     * Sound.signal = mix * 512 / 600;
     ***************************************************************/
    logic [10:0] att_11bit;
    ATT_CONST #(
        .BIT_WIDTH($bits(mix_11bit)),
        .MUL(512),
        .DIV(600)
    ) u_att (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .IN(mix_11bit),
        .OUT(att_11bit)
    );

    assign Sound = att_11bit[$bits(Sound)-1:0];

endmodule

/***********************************************************************
 * MIXER
 ***********************************************************************/
module SCC_MIXER #(
    parameter CH_COUNT = 5,
    parameter SCC_OFFSET = 128,
    parameter IN_BIT_WIDTH  = 12,
    parameter OUT_BIT_WIDTH = 11
) (
    input wire CLK,
    input wire RESET_n,
    input wire [CH_COUNT-1:0] ENABLE,
    input wire [IN_BIT_WIDTH-1:0] IN[0:CH_COUNT-1],
    output reg [OUT_BIT_WIDTH-1:0] OUT
);
    /***************************************************************
     * signed -> unsigned
     * (-1920~1905) >> 4 + 128 = (8~247)
     ***************************************************************/
    logic [8-1:0] out_8bit[0:CH_COUNT-1];
    generate
        genvar out_ch;
        for(out_ch = 0; out_ch < CH_COUNT; out_ch = out_ch + 1) begin: out_loop
            always_comb begin
                out_8bit[out_ch] = ENABLE[out_ch] ? ((IN[out_ch][11:4] + SCC_OFFSET) & 8'hFF) : SCC_OFFSET;
            end
        end
    endgenerate

    /***************************************************************
     * ミキサー、unsigned -> signed
     * (8~247) * 5 - 128 * 5 = (-600~595)
     ***************************************************************/
    localparam [OUT_BIT_WIDTH-8-1:0] zero = 0; 
    localparam [OUT_BIT_WIDTH-1:0] SCC_OFFSET_ALL_CH = (SCC_OFFSET * CH_COUNT);
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    OUT <= 0;
        else            OUT <= ({ zero, out_8bit[0] } +
                                { zero, out_8bit[1] } +
                                { zero, out_8bit[2] } +
                                { zero, out_8bit[3] } +
                                { zero, out_8bit[4] } ) - SCC_OFFSET_ALL_CH;
    end
endmodule

/***********************************************************************
 * OUT = IN * VOL
 ***********************************************************************/
module SCC_AMP (
    input wire          CLK,
    input wire          RESET_n,
    input wire [7:0]    IN,
    input wire [3:0]    VOL,
    output reg [11:0]   OUT
);
    localparam MUL_BIT_WIDTH = $bits(VOL);
    localparam OUT_BIT_WIDTH = ($bits(IN) + $bits(VOL));


    /***************************************************************
     * 絶対値
     ***************************************************************/
    logic sign;
    logic [OUT_BIT_WIDTH-1:0] abs_val;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            sign <= 0;
            abs_val <= 0;
        end
        else begin
            sign <= IN[$bits(IN)-1];
            abs_val <= IN[$bits(IN)-1] ? (~IN + 1'd1) : IN;
        end
    end

    /***************************************************************
     * ビット毎に積を求める
     ***************************************************************/
    localparam [OUT_BIT_WIDTH-1:0] zero = 0;
    logic [OUT_BIT_WIDTH-1:0] val[0:MUL_BIT_WIDTH-1];
    generate
        genvar bit_count;
        for(bit_count = 0; bit_count < MUL_BIT_WIDTH; bit_count = bit_count + 1) begin: bit_loop
            always_comb begin
                val[bit_count] = VOL[bit_count] ? (abs_val << bit_count) : zero;
            end
        end
    endgenerate

    /***************************************************************
     * 積を加算
     ***************************************************************/
    logic [OUT_BIT_WIDTH-1:0] sum[0:MUL_BIT_WIDTH-1];
    generate
        genvar sum_count;
        for(sum_count = 0; sum_count < MUL_BIT_WIDTH; sum_count = sum_count + 1) begin: sum_loop
            if(sum_count == MUL_BIT_WIDTH - 1) begin
                always_comb begin
                    sum[sum_count] = val[sum_count];
                end
            end
            else begin
                always_comb begin
                    sum[sum_count] = sum[sum_count + 1] + val[sum_count];
                end
            end
        end
    endgenerate

    /***************************************************************
     * 符号を戻す
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) OUT <= 0;
        else OUT <= sign ? ~(sum[0] - 1'd1) : sum[0];
    end

endmodule

/***********************************************************************
 * アドレス移動
 ***********************************************************************/
module SCC_ADDR (
    input wire          CLK,
    input wire          RESET_n,
    input wire          CLK_EN,
    input wire          MODE_4b,
    input wire          MODE_8b,
    input wire          MODE_ROATE,
    input wire          RESTART,
    input wire [11:0]   DIV,
    output reg          ROTATE,
    output reg [4:0]    ADDR
);
    /***************************************************************
     * DIV 変換
     ***************************************************************/
    logic [11:0] div_conv;
    always_comb begin
        case ({MODE_8b, MODE_4b})
            2'b00:  div_conv = DIV;
            2'b01:  div_conv = { 8'b00000000, DIV[11:8] };
            2'b10:  div_conv = { 4'b0000, DIV[7:0] };
            default:div_conv = { 4'b0000, DIV[7:0] };
        endcase
    end

    /***************************************************************
     * カウンタの更新
     ***************************************************************/
    logic [11:0] curr_cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                    curr_cnt <= 0;
        else if(RESTART)                curr_cnt <= 0;
        else if(!CLK_EN)                curr_cnt <= curr_cnt;
        else if(curr_cnt >= div_conv)   curr_cnt <= 0;
        else                            curr_cnt <= curr_cnt + 1'd1;
    end

    /***************************************************************
     * ローテート
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                    ROTATE <= 0;
        else if(RESTART)                ROTATE <= 0;
        else if(!CLK_EN)                ROTATE <= 0;
        else if(!MODE_ROATE)            ROTATE <= 0;
        else if(curr_cnt >= div_conv)   ROTATE <= 1;
        else                            ROTATE <= 0;
    end

    /***************************************************************
     * アドレスの更新
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                    ADDR <= 0;
        else if(RESTART)                ADDR <= 0;
        else if(!CLK_EN)                ADDR <= ADDR;
        else if(MODE_ROATE)             ADDR <= ADDR;
        else if(curr_cnt >= div_conv)   ADDR <= ADDR + 1'd1;
        else                            ADDR <= ADDR;
    end
endmodule

/***********************************************************************
 * 波形メモリ
 ***********************************************************************/
module SCC_WAVE_TABLE (
    input wire          CLK,
    input wire          RESET_n,

    input wire [4:0]    SOUND_ADDR,
    input wire [4:0]    BUS_ADDR,
    input wire          BUS_OE_n,
    input wire          BUS_WE_n,
    input wire          BUS_ENA_n,

    output reg [7:0]    RDATA,
    input wire [7:0]    WDATA,

    input wire          ROTATE
);
    logic [4:0] offset;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                offset <= 0;
        else if(ROTATE)             offset <= offset + 1'd1;
        else                        offset <= offset;
    end

    wire [4:0] addr = (BUS_ENA_n || (BUS_OE_n && BUS_WE_n)) ? (SOUND_ADDR + offset) : (BUS_ADDR + offset);

`ifndef HOGE

    reg [7:0] buffer[0:31];

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)        RDATA <= 0;
        else                RDATA <= buffer[addr];
    end

    always_ff @(posedge CLK) begin
        if(!(BUS_WE_n || BUS_ENA_n)) begin
            buffer[addr] <= WDATA;
        end
    end

`else
    reg [3:0] rdata_ll;
    reg [3:0] rdata_lh;
    reg [3:0] rdata_hl;
    reg [3:0] rdata_hh;

    wire [4:0] addr = (BUS_ENA_n || (BUS_OE_n && BUS_WE_n)) ? (SOUND_ADDR + offset) : (BUS_ADDR + offset);
    wire [3:0] rdata_l = addr[4] ? rdata_hl : rdata_ll;
    wire [3:0] rdata_h = addr[4] ? rdata_hh : rdata_lh;
    assign RDATA = { rdata_h, rdata_l };

    RAM16S4 u_mem_ll (
        .WRE(!BUS_WE_n && !addr[4]),
        .CLK(CLK),
        .AD(addr[3:0]),
        .DI(WDATA[3:0]),
        .DO(rdata_ll)
    );

    RAM16S4 u_mem_lh (
        .WRE(!BUS_WE_n && !addr[4]),
        .CLK(CLK),
        .AD(addr[3:0]),
        .DI(WDATA[7:4]),
        .DO(rdata_lh)
    );

    RAM16S4 u_mem_hl (
        .WRE(!BUS_WE_n && addr[4]),
        .CLK(CLK),
        .AD(addr[3:0]),
        .DI(WDATA[3:0]),
        .DO(rdata_hl)
    );

    RAM16S4 u_mem_hh (
        .WRE(!BUS_WE_n && addr[4]),
        .CLK(CLK),
        .AD(addr[3:0]),
        .DI(WDATA[7:4]),
        .DO(rdata_hh)
    );
`endif
endmodule

`default_nettype wire
