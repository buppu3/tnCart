//
// board_rev1_tmds.sv
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
 * rev1 基板用 TMDS 出力モジュール
 ***********************************************************************/
module BOARD_REV1_TMDS_OUT #(
    parameter           V_ACTIVE = 480,
    parameter           V_SYNC = 2,
    parameter           V_BACKPORCH = 33,
    parameter           H_ACTIVE = 720,
    parameter           H_SYNC = 62,
    parameter           H_BACKPORCH = 7
)(
    input  wire         RESET_n,
    VIDEO_IF.IN         IN,

    input  wire         TMDS_READY,
    input  wire         CLK_S,
    input  wire         CLK_P,
    output wire         TMDS_CLKP,
    output wire         TMDS_CLKN,
    output wire [2:0]   TMDS_DATAP,
    output wire [2:0]   TMDS_DATAN
);
    /***************************************************************
     * 
     ***************************************************************/
    logic [$bits(IN.R)-1:0]  in_r;
    logic [$bits(IN.G)-1:0]  in_g;
    logic [$bits(IN.B)-1:0]  in_b;
    logic                    in_hs_n;
    logic                    in_vs_n;

    always_ff @(posedge IN.DCLK) begin
        in_r <= IN.R;
        in_g <= IN.G;
        in_b <= IN.B;
        in_hs_n <= IN.HS_n;
        in_vs_n <= IN.VS_n;
    end

    /***************************************************************
     * HSYNC の検出
     ***************************************************************/
    logic prev_hs;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) prev_hs <= 1;
        else            prev_hs <= in_hs_n;
    end

    /***************************************************************
     * VSYNC の検出
     ***************************************************************/
    logic prev_vs;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) prev_vs <= 1;
        else            prev_vs <= in_vs_n;
    end

    /***************************************************************
     * クロックのカウント
     ***************************************************************/
    logic [9:0] h_cnt;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) begin
            h_cnt <= 0;
        end
        else if(prev_hs && !in_hs_n) begin
            h_cnt <= 0;
        end
        else begin
            h_cnt <= h_cnt + 1'd1;
        end
    end

    logic [9:0] v_cnt;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) begin
            v_cnt <= 0;
        end
        else if(prev_vs && !in_vs_n) begin
            v_cnt <= 0;
        end
        else if(prev_hs && !in_hs_n) begin
            v_cnt <= v_cnt + 1'd1;
        end
    end

    /***************************************************************
     * 輝度信号の遅延
     ***************************************************************/
    localparam DLY_COUNT = 1;
    reg [$bits(in_r)-1:0] delay_r[0:DLY_COUNT-1];
    reg [$bits(in_g)-1:0] delay_g[0:DLY_COUNT-1];
    reg [$bits(in_b)-1:0] delay_b[0:DLY_COUNT-1];
    BOARD_REV1_TMDS_OUT_DELAY u_dly0_r (.CLK(CLK_P), .IN(in_r), .OUT(delay_r[0]));
    BOARD_REV1_TMDS_OUT_DELAY u_dly0_g (.CLK(CLK_P), .IN(in_g), .OUT(delay_g[0]));
    BOARD_REV1_TMDS_OUT_DELAY u_dly0_b (.CLK(CLK_P), .IN(in_b), .OUT(delay_b[0]));

    /***************************************************************
     * DE 信号の生成
     ***************************************************************/
    logic de;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) de <= 00;
        else            de <= (v_cnt >= V_SYNC+V_BACKPORCH) && (v_cnt < V_SYNC+V_BACKPORCH+V_ACTIVE) &&
                              (h_cnt >= H_SYNC+H_BACKPORCH-1'd1) && (h_cnt < H_SYNC+H_BACKPORCH+H_ACTIVE-1'd1);
    end

    /***************************************************************
     * HSYNC 信号の生成
     ***************************************************************/
    logic hs;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) hs <= 0;
        else            hs <= h_cnt >= 0 && h_cnt < H_SYNC;
    end

    /***************************************************************
     * VSYNC 信号の生成
     ***************************************************************/
    logic vs;
    always_ff @(posedge CLK_P or negedge TMDS_READY) begin
        if(!TMDS_READY) vs <= 0;
        else            vs <= v_cnt >= 0 && v_cnt < V_SYNC;
    end

    /***************************************************************
     * TMDS へ出力
     ***************************************************************/
    DVI_TX_Top DVI_TX_Top_inst
    (
        .I_rst_n        (TMDS_READY          ),
        .I_serial_clk   (CLK_S               ),
        .I_rgb_clk      (CLK_P               ),
        .I_rgb_vs       (vs                  ),
        .I_rgb_hs       (hs                  ),
        .I_rgb_de       (de                  ), 
        .I_rgb_r        (delay_r[DLY_COUNT-1]),
        .I_rgb_g        (delay_g[DLY_COUNT-1]),  
        .I_rgb_b        (delay_b[DLY_COUNT-1]),  
        .O_tmds_clk_p   (TMDS_CLKP           ),
        .O_tmds_clk_n   (TMDS_CLKN           ),
        .O_tmds_data_p  (TMDS_DATAP          ),
        .O_tmds_data_n  (TMDS_DATAN          )
    );

endmodule

// 信号の1clk遅延
module BOARD_REV1_TMDS_OUT_DELAY (
    input wire CLK,
    input wire [7:0] IN,
    output reg [7:0] OUT
);
    always_ff @(posedge CLK) begin
        OUT <= IN;
    end
endmodule

`default_nettype wire
