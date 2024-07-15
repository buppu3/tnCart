//
// t9990_color_decode.sv
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
 * 色空間を変換
 ***************************************************************/
module T9990_COLOR_DECODE (
    input wire              RESET_n,
    input wire              CLK,
    input wire              DCLK_EN,

    T9990_REGISTER_IF.VDP   REG,

    input wire [9:0]        HCNT,

    input wire [15:0]       IN,
    output reg [15:0]       OUT
);
    wire [1:0] INDEX = HCNT[1:0];

    /***************************************************************
     * データを保存
     ***************************************************************/
    logic [15:0] buff[0:3] /* synthesis syn_ramstyle="block_ram" */;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            buff[0] <= 0;
            buff[1] <= 0;
            buff[2] <= 0;
            buff[3] <= 0;
        end
        else if(DCLK_EN) begin
            buff[INDEX] <= IN;
        end
    end

    /***************************************************************
     * Y 値を保存
     ***************************************************************/
    wire [7:0] in_y = REG.YAE ? { 3'b000, IN[7:4], IN[7] } : { 3'b000, IN[7:3] };
    logic [7:0] buff_y[0:3] /* synthesis syn_ramstyle="block_ram" */;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            buff_y[0] <= 0;
            buff_y[1] <= 0;
            buff_y[2] <= 0;
            buff_y[3] <= 0;
        end
        else if(DCLK_EN) begin
            buff_y[INDEX] <= in_y;
        end
    end

    /***************************************************************
     * Y*5 の計算値を保存
     ***************************************************************/
    logic [8:0] buff_y5[0:3] /* synthesis syn_ramstyle="block_ram" */;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            buff_y5[0] <= 0;
            buff_y5[1] <= 0;
            buff_y5[2] <= 0;
            buff_y5[3] <= 0;
        end
        else if(DCLK_EN) begin
            buff_y5[INDEX] <= { in_y[6:0], 2'b00 } + in_y;
        end
    end

    /***************************************************************
     * UV/JK 値を保存
     ***************************************************************/
    logic [2:0] buff_ul;
    logic [2:0] buff_uh;
    logic [2:0] buff_vl;
    logic [7:0] U;  // -32~31
    logic [8:0] U2; // -64~62
    logic [7:0] V;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            buff_ul <= 0;
            buff_uh <= 0;
            buff_vl <= 0;
        end
        else if(DCLK_EN) begin
            case (INDEX)
                2'd0:   buff_ul <= IN[2:0];
                2'd1:   buff_uh <= IN[2:0];
                2'd2:   buff_vl <= IN[2:0];
                2'd3:   begin
                            U  <= { buff_uh[2], buff_uh[2], buff_uh, buff_ul       };
                            U2 <= { buff_uh[2], buff_uh[2], buff_uh, buff_ul, 1'b0 };
                            V  <= { IN[2],      IN[2],      IN[2:0], buff_vl       };
                        end
            endcase
        end
    end

    /***************************************************************
     * YJK/YUV -> RGB 変換
     ***************************************************************/
    wire [7:0] Y  = buff_y[INDEX];      // 0~31
    wire [8:0] Y5 = buff_y5[INDEX];     // 0~155

    logic [7:0] YUV_R;  // -32~62
    logic [7:0] YUV_B;  // -32~62
    logic [8:0] YUV_G4; // -93~251

    wire [4:0] YUV_R_LIMIT = YUV_R [7] ? 5'd0 : (YUV_R[6:5] ? 5'd31 : YUV_R [4:0]);   // 0~31
    wire [4:0] YUV_B_LIMIT = YUV_B [7] ? 5'd0 : (YUV_B[6:5] ? 5'd31 : YUV_B [4:0]);   // 0~31
    wire [4:0] YUV_G_LIMIT = YUV_G4[8] ? 5'd0 : (YUV_G4 [7] ? 5'd31 : YUV_G4[6:2]);   // 0~31

    logic [7:0] YJK_R;  // -32~62
    logic [7:0] YJK_G;  // -32~62
    logic [8:0] YJK_B4; // -93~251

    wire [4:0] YJK_R_LIMIT = YJK_R [7] ? 5'd0 : (YJK_R[6:5] ? 5'd31 : YJK_R [4:0]);   // 0~31
    wire [4:0] YJK_G_LIMIT = YJK_G [7] ? 5'd0 : (YJK_G[6:5] ? 5'd31 : YJK_G [4:0]);   // 0~31
    wire [4:0] YJK_B_LIMIT = YJK_B4[8] ? 5'd0 : (YJK_B4 [7] ? 5'd31 : YJK_B4[6:2]);   // 0~31

    /***************************************************************
     * 出力
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT <= 16'b1_00000_00000_00000;
        end

        //
        // YUV
        //
        else if(REG.PLTM == T9990_REG::PLTM_YUV) begin
            if(!DCLK_EN) begin
                YUV_R  <= Y + U;          // R = Y + U;
                YUV_B  <= Y + V;          // B = Y + V;
                YUV_G4 <= (Y5 - U2 - V);  // G = (5Y - 2U - V) / 4;
            end
            else begin
                OUT <= {1'b0, YUV_G_LIMIT, YUV_R_LIMIT, YUV_B_LIMIT};
            end
        end

        //
        // YJK
        //
        else if(REG.PLTM == T9990_REG::PLTM_YJK) begin
            if(!DCLK_EN) begin
                YJK_R  <= Y + U;          // R = Y + J;
                YJK_G  <= Y + V;          // G = Y + K;
                YJK_B4 <= (Y5 - U2 - V);  // B = (5Y - 2J - K) / 4;
            end
            else begin
                OUT <= {1'b0, YJK_G_LIMIT, YJK_R_LIMIT, YJK_B_LIMIT};
            end
        end

        //
        // BD16
        //
        else if(REG.CLRM == T9990_REG::CLRM_16BPP) begin
            if(DCLK_EN) OUT <= buff[INDEX];
        end

        //
        // BD8
        //
        else if(REG.CLRM == T9990_REG::CLRM_8BPP) begin
            if(DCLK_EN) OUT <= {
                                buff[INDEX][7:0] == 0 ? 1'b1 : 1'b0,
                                buff[INDEX][7:5], buff[INDEX][7:6],
                                buff[INDEX][4:2], buff[INDEX][4:3],
                                buff[INDEX][1:0], buff[INDEX][1:0], buff[INDEX][1] | buff[INDEX][0]
                            };
        end

        //
        // その他の画面モード
        //
        else begin
            OUT <= OUT;
        end
    end
endmodule

`default_nettype wire
