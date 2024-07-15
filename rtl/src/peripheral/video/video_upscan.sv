//
// video_upscan.sv
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
 * アップスキャンモジュール
 ***********************************************************************/
module VIDEO_UPSCAN #(
    parameter [9:0] H_TOTAL = 10'd855,
    parameter [9:0] H_SYNC  = 10'd62,
    parameter [9:0] H_ERASE = 10'd69,
    parameter [9:0] H_DISP  = 10'd720,
    parameter [9:0] V_TOTAL = 10'd525,
    parameter [9:0] V_SYNC  = 10'd2,
    parameter RESOLUTION    = VIDEO::RESOLUTION_720_480
) (
    input wire      RESET_n,
    input wire      DCLK,

    VIDEO_IF.IN     IN,
    VIDEO_IF.OUT    OUT
);
    /***************************************************************
     * 入力バッファ
     ***************************************************************/
    logic [7:0] in_r;
    logic [7:0] in_g;
    logic [7:0] in_b;
    logic       in_hs_n;
    logic       in_vs_n;
    VIDEO::RESOLUTION_t in_reso;

    always_ff @(posedge IN.DCLK) begin
        in_r <= IN.R;
        in_g <= IN.G;
        in_b <= IN.B;
        in_hs_n <= IN.HS_n;
        in_vs_n <= IN.VS_n;
        in_reso <= IN.RESOLUTION;
    end

    /***************************************************************
     * ラインバッファ
     ***************************************************************/
    logic   IN_EN;
    logic   IN_START;
    logic   IN_LINE;
    logic   OUT_EN;
    logic   OUT_START;
    logic   OUT_LINE;

    VIDEO_UPSCAN_STRETCH_BUFFER u_buff_r (
        .RESET_n,
        .CLEAR(1'b0),

        .IN_RESOLUTION(in_reso),
        .IN_CLK(IN.DCLK),
        .IN_EN,
        .IN_START,
        .IN_LINE,
        .IN(in_r),

        .OUT_CLK(DCLK),
        .OUT_EN,
        .OUT_START,
        .OUT_LINE,
        .OUT(OUT.R)
    );

    VIDEO_UPSCAN_STRETCH_BUFFER u_buff_g (
        .RESET_n,
        .CLEAR(1'b0),

        .IN_RESOLUTION(in_reso),
        .IN_CLK(IN.DCLK),
        .IN_EN,
        .IN_START,
        .IN_LINE,
        .IN(in_g),

        .OUT_CLK(DCLK),
        .OUT_EN,
        .OUT_START,
        .OUT_LINE,
        .OUT(OUT.G)
    );

    VIDEO_UPSCAN_STRETCH_BUFFER u_buff_b (
        .RESET_n,
        .CLEAR(1'b0),

        .IN_RESOLUTION(in_reso),
        .IN_CLK(IN.DCLK),
        .IN_EN,
        .IN_START,
        .IN_LINE,
        .IN(in_b),

        .OUT_CLK(DCLK),
        .OUT_EN,
        .OUT_START,
        .OUT_LINE,
        .OUT(OUT.B)
    );

    /***************************************************************
     * 入力
     ***************************************************************/
    logic in_prev_in_hs_n;
    logic in_prev_in_vs_n;

    always_ff @(posedge IN.DCLK or negedge RESET_n) begin
        if(!RESET_n) in_prev_in_hs_n <= 1;
        else         in_prev_in_hs_n <= in_hs_n;
    end

    always_ff @(posedge IN.DCLK or negedge RESET_n) begin
        if(!RESET_n) in_prev_in_vs_n <= 1;
        else         in_prev_in_vs_n <= in_vs_n;
    end

    logic [9:0] in_h_cnt;

    wire in_h_inc = 1;
    wire in_h_rst = in_prev_in_hs_n && !in_hs_n;

    always_ff @(posedge IN.DCLK or negedge RESET_n) begin
        if(!RESET_n)      in_h_cnt <= 0;
        else if(in_h_rst) in_h_cnt <= 1'd1;
        else if(in_h_inc) in_h_cnt <= in_h_cnt + 1'd1;
    end

    always_ff @(posedge IN.DCLK or negedge RESET_n) begin
        if(!RESET_n)                         IN_LINE <= 1;               // RESET
        else if(in_prev_in_vs_n && !in_vs_n) IN_LINE <= 1;               // VSYNC
        else if(in_prev_in_hs_n && !in_hs_n) IN_LINE <= !IN_LINE;        // HSYNC
    end

    always_ff @(posedge IN.DCLK or negedge RESET_n) begin
        if(!RESET_n)                         IN_START <= 0;              // RESET
        else if(in_prev_in_hs_n && !in_hs_n) IN_START <= 1;              // HSYNC
        else                                 IN_START <= 0;              // VSYNC
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)   IN_EN <= 0;
        else case (in_reso)
            VIDEO::RESOLUTION_B1:   IN_EN <= (in_h_cnt >= 10'd 48) && (in_h_cnt < 10'd 48 + 10'd288);  //  48 + 16 + 256 + 16 +  6
            VIDEO::RESOLUTION_B2:   IN_EN <= (in_h_cnt >= 10'd 62) && (in_h_cnt < 10'd 62 + 10'd384);  //  62 +  0 + 384 +  0 + 10
            VIDEO::RESOLUTION_B3:   IN_EN <= (in_h_cnt >= 10'd 96) && (in_h_cnt < 10'd 96 + 10'd576);  //  96 + 32 + 512 + 32 + 12
            VIDEO::RESOLUTION_B4:   IN_EN <= (in_h_cnt >= 10'd124) && (in_h_cnt < 10'd124 + 10'd768);  // 124 +  0 + 768 +  0 + 20
            VIDEO::RESOLUTION_B5:   IN_EN <= (in_h_cnt >= 10'd128) && (in_h_cnt < 10'd128 + 10'd640);  // 128 +  0 + 640 +  0 + 80
            VIDEO::RESOLUTION_B6:   IN_EN <= (in_h_cnt >= 10'd112) && (in_h_cnt < 10'd112 + 10'd640);  // 112 +  0 + 640 +  0 + 48
            default:                IN_EN <= (in_h_cnt >= 10'd 69) && (in_h_cnt < 10'd 69 + 10'd720);  //  69 +  0 + 720 +  0 + 66
        endcase
    end

    /***************************************************************
     * 入力側の HSYNC, VSYNC を出力側クロックで受ける
     ***************************************************************/
    logic out_in_vs_n;
    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n) out_in_vs_n <= 1;
        else         out_in_vs_n <= in_vs_n;
    end

    logic out_prev_in_vs_n;
    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n) out_prev_in_vs_n <= 1;
        else         out_prev_in_vs_n <= out_in_vs_n;
    end

    /***************************************************************
     * 出力タイミング生成
     ***************************************************************/
    logic [9:0] out_h_cnt;
    logic [9:0] out_v_cnt;
    logic [1:0] out_line_cnt;

    wire out_h_inc = 1;
    wire out_h_rst = (out_h_cnt == H_TOTAL - 1'd1) && out_h_inc;
    wire out_v_inc = out_h_rst;
    wire out_v_rst = (out_v_cnt == V_TOTAL - 1'd1) && out_v_inc;

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)                              out_h_cnt <= 0;
        else if(out_h_rst)                        out_h_cnt <= 0;                   // OUT.HSYNC
        else if(out_prev_in_vs_n && !out_in_vs_n) out_h_cnt <= 0;                   // IN.VSYNC
        else if(out_h_inc)                        out_h_cnt <= out_h_cnt + 1'd1;    // OUT.DCLK
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)                              out_v_cnt <= 0;
        else if(out_v_rst)                        out_v_cnt <= 0;                   // OUT.VSYNC
        else if(out_prev_in_vs_n && !out_in_vs_n) out_v_cnt <= 0;                   // IN.VSYNC
        else if(out_v_inc)                        out_v_cnt <= out_v_cnt + 1'd1;    // OUT.VSYNC
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)                              out_line_cnt <= 0;
        else if(out_prev_in_vs_n && !out_in_vs_n) out_line_cnt <= 0;                    // IN.VSYNC
        else if(out_h_rst)                        out_line_cnt <= out_line_cnt + 1'd1;  // OUT.HSYNC
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)                OUT_START <= 0;
        else if(out_h_cnt == 10'd1) OUT_START <= 1; // OUT.HSYNC + 1clk
        else                        OUT_START <= 0; // default
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)                OUT_LINE <= 0;                  // RESET
        else if(out_h_cnt == 10'd1) OUT_LINE <= out_line_cnt[1];    // OUT.HSYNC + 1clk
    end

    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)   OUT_EN <= 0;
        else           OUT_EN <= (out_h_cnt >= (H_ERASE - 10'd2)) && (out_h_cnt < (H_ERASE + H_DISP - 10'd2));
    end

    /***************************************************************
     * HSYNC 出力
     ***************************************************************/
    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)   OUT.HS_n <= 1;
        else           OUT.HS_n <= out_h_cnt >= H_SYNC;
    end

    /***************************************************************
     * VSYNC 出力
     ***************************************************************/
    always_ff @(posedge DCLK or negedge RESET_n) begin
        if(!RESET_n)   OUT.VS_n <= 1;
        else           OUT.VS_n <= out_v_cnt >= V_SYNC;
    end

    assign  OUT.RESOLUTION = RESOLUTION;
    assign  OUT.DCLK = DCLK;
endmodule

/***********************************************************************
 * 拡大縮小付きバッファ
 ***********************************************************************/
module VIDEO_UPSCAN_STRETCH_BUFFER (
    input wire          RESET_n,
    input wire          CLEAR,

    input wire VIDEO::RESOLUTION_t IN_RESOLUTION,
    input wire          IN_CLK,
    input wire          IN_EN,
    input wire          IN_START,
    input wire          IN_LINE,
    input wire [7:0]    IN,

    input wire          OUT_CLK,
    input wire          OUT_EN,
    input wire          OUT_START,
    input wire          OUT_LINE,
    output reg [7:0]    OUT
);
    localparam [10:0]   MAX_BUFFER_WIDTH = 11'd768;

    /***************************************************************
     * メモリ
     ***************************************************************/
    logic [10:0] W_ADDR;
    logic [7:0]  W_DATA;
    logic        W_EN;
    logic [10:0] R_ADDR;
    logic [7:0]  R_DATA;

    VIDEO_UPSCAN_BUFFER #(
        .COUNT(MAX_BUFFER_WIDTH * 2)
    ) u_buf (
        .W_CLK(IN_CLK),
        .W_ADDR,
        .W_DATA,
        .W_EN,

        .R_CLK(OUT_CLK),
        .R_ADDR,
        .R_DATA
    );

    /***************************************************************
     * 入力
     ***************************************************************/
    logic [9:0]  in_count;

    always_ff @(posedge IN_CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            in_count <= 0;
        end
        else if(IN_START) begin
            in_count <= 0;
        end
        else if(IN_EN) begin
            case (IN_RESOLUTION)
                VIDEO::RESOLUTION_B1: in_count <= (in_count != 10'd256) ? (in_count + 1'd1) : in_count;
                VIDEO::RESOLUTION_B3: in_count <= (in_count != 10'd512) ? (in_count + 1'd1) : in_count;
                VIDEO::RESOLUTION_B2: in_count <= (in_count != 10'd384) ? (in_count + 1'd1) : in_count;
                VIDEO::RESOLUTION_B4: in_count <= (in_count != 10'd768) ? (in_count + 1'd1) : in_count;
                VIDEO::RESOLUTION_B5: in_count <= (in_count != 10'd640) ? (in_count + 1'd1) : in_count;
                VIDEO::RESOLUTION_B6: in_count <= (in_count != 10'd640) ? (in_count + 1'd1) : in_count;
                default:              in_count <= (in_count != 10'd720) ? (in_count + 1'd1) : in_count;
            endcase
        end
    end

    always_ff @(posedge IN_CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            W_ADDR <= 0;
            W_EN <= 0;
        end
        else if(IN_START) begin
            W_ADDR <= IN_LINE ? 11'b11111111111 : (MAX_BUFFER_WIDTH-1);
            W_EN <= 0;
        end
        else if(IN_EN) begin
            case (IN_RESOLUTION)
                VIDEO::RESOLUTION_B1: begin
                    W_ADDR <= (in_count != 10'd288) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd288);
                end
                VIDEO::RESOLUTION_B3: begin
                    W_ADDR <= (in_count != 10'd576) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd576);
                end
                VIDEO::RESOLUTION_B2: begin
                    W_ADDR <= (in_count != 10'd384) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd384);
                end
                VIDEO::RESOLUTION_B4: begin
                    W_ADDR <= (in_count != 10'd768) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd768);
                end
                VIDEO::RESOLUTION_B5,
                VIDEO::RESOLUTION_B6: begin
                    W_ADDR <= (in_count != 10'd640) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd640);
                end
                default: begin
                    W_ADDR <= (in_count != 10'd720) ? (W_ADDR + 1'd1) : W_ADDR;
                    W_DATA <= IN;
                    W_EN <= (in_count != 10'd720);
                end
            endcase
        end
        else begin
            W_EN <= 0;
        end
    end

    /***************************************************************
     * 出力
     ***************************************************************/
    logic [9:0] out_count;
    logic [3:0] out_state;
    logic [3:0] out_state_delay;
    logic [7:0] R_DATA_P;
    wire  [7:0] R_DATA_C = R_DATA;


    wire [11:0] p0 = 0;
    wire [11:0] p1 = {4 'h0, R_DATA_P };
    wire [11:0] p2 = {4 'h0, R_DATA_P, 1'h0 };
    wire [11:0] p4 = {4 'h0, R_DATA_P, 2'h0 };
    wire [11:0] p8 = {4 'h0, R_DATA_P, 3'h0 };
    wire [11:0] p3 =           p2 + p1;
    wire [11:0] p5 =      p4      + p1;
    wire [11:0] p6 =      p4 + p2     ;
    wire [11:0] p7 =      p4 + p2 + p1;
    wire [11:0] p9 = p8           + p1;
    wire [11:0] pA = p8      + p2     ;
    wire [11:0] pB = p8      + p2 + p1;
    wire [11:0] pC = p8 + p4          ;
    wire [11:0] pD = p8 + p4      + p1;
    wire [11:0] pE = p8 + p4 + p2     ;
    wire [11:0] pF = p8 + p4 + p2 + p1;

    wire [11:0] c0 = 0;
    wire [11:0] c1 = {4 'h0, R_DATA_C };
    wire [11:0] c2 = {4 'h0, R_DATA_C, 1'h0 };
    wire [11:0] c4 = {4 'h0, R_DATA_C, 2'h0 };
    wire [11:0] c8 = {4 'h0, R_DATA_C, 3'h0 };
    wire [11:0] c3 =           c2 + c1;
    wire [11:0] c5 =      c4      + c1;
    wire [11:0] c6 =      c4 + c2     ;
    wire [11:0] c7 =      c4 + c2 + c1;
    wire [11:0] c9 = c8           + c1;
    wire [11:0] cA = c8      + c2     ;
    wire [11:0] cB = c8      + c2 + c1;
    wire [11:0] cC = c8 + c4          ;
    wire [11:0] cD = c8 + c4      + c1;
    wire [11:0] cE = c8 + c4 + c2     ;
    wire [11:0] cF = c8 + c4 + c2 + c1;

    wire [11:0] p0_c2 = p0 + c2;
    wire [11:0] p1_c1 = p1 + c1;

    wire [11:0] p0_c4 = p0 + c4;
    wire [11:0] p1_c3 = p1 + c3;
    wire [11:0] p2_c2 = p2 + c2;
    wire [11:0] p3_c1 = p3 + c1;

    wire [11:0] p0_c8 = p0 + c8;
    wire [11:0] p1_c7 = p1 + c7;
    wire [11:0] p2_c6 = p2 + c6;
    wire [11:0] p3_c5 = p3 + c5;
    wire [11:0] p4_c4 = p4 + c4;
    wire [11:0] p5_c3 = p5 + c3;
    wire [11:0] p6_c2 = p6 + c2;
    wire [11:0] p7_c1 = p7 + c1;

    wire [11:0] p1_cF = p1 + cF;
    wire [11:0] p2_cE = p2 + cE;
    wire [11:0] p3_cD = p3 + cD;
    wire [11:0] p4_cC = p4 + cC;
    wire [11:0] p5_cB = p5 + cB;
    wire [11:0] p6_cA = p6 + cA;
    wire [11:0] p7_c9 = p7 + c9;
    wire [11:0] p8_c8 = p8 + c8;
    wire [11:0] p9_c7 = p9 + c7;
    wire [11:0] pA_c6 = pA + c6;
    wire [11:0] pB_c5 = pB + c5;
    wire [11:0] pC_c4 = pC + c4;
    wire [11:0] pD_c3 = pD + c3;
    wire [11:0] pE_c2 = pE + c2;
    wire [11:0] pF_c1 = pF + c1;

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            out_count <= 0;
        end
        else if(OUT_START) begin
            out_count <= 0;
        end
        else if(OUT_EN) begin
            if(out_count != 10'd720) out_count <= out_count + 1'd1;
        end
    end

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            out_state <= 0;
        end
        else if(OUT_START) begin
            out_state <= 0;
        end
        else if(OUT_EN && out_count != 10'd720) begin
            case (IN_RESOLUTION)
                VIDEO::RESOLUTION_B1:   out_state <= (out_state == 4'h4) ? 4'h0 : (out_state + 1'd1);
                VIDEO::RESOLUTION_B2:   out_state <= (out_state == 4'he) ? 4'h0 : (out_state + 1'd1);
                VIDEO::RESOLUTION_B3:   out_state <= (out_state == 4'h4) ? 4'h0 : (out_state + 1'd1);
                VIDEO::RESOLUTION_B4:   out_state <= (out_state == 4'he) ? 4'h0 : (out_state + 1'd1);
                VIDEO::RESOLUTION_B5:   out_state <= (out_state == 4'h8) ? 4'h0 : (out_state + 1'd1);
                VIDEO::RESOLUTION_B6:   out_state <= (out_state == 4'h8) ? 4'h0 : (out_state + 1'd1);
                default:                out_state <= out_state;
            endcase
        end
    end

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            out_state_delay <= 0;
        end
        else if(OUT_START) begin
            out_state_delay <= -1;
        end
        else if(OUT_EN && out_count != 10'd720) begin
            out_state_delay <= out_state;
        end
    end

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            R_DATA_P <= 0;
        end
        else if(OUT_START) begin
            R_DATA_P <= 0;
        end
        else if(OUT_EN && out_count != 10'd720) begin
            R_DATA_P <= R_DATA_C;
        end
    end

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            R_ADDR <= 0;
        end
        else if(OUT_START) begin
            R_ADDR <= OUT_LINE ? 0 : MAX_BUFFER_WIDTH;
        end
        else if(OUT_EN && out_count != 10'd720) begin
            case (IN_RESOLUTION)
                default:         R_ADDR <= R_ADDR + 1'd1;

                VIDEO::RESOLUTION_B1:                       // 5.4MHz       (16+256+16)*5/2=720
                    case (out_state)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    R_ADDR <= R_ADDR;          // 00           x0
                        4'h1:    R_ADDR <= R_ADDR + 1'd1;   // 00           x0 +
                        4'h2:    R_ADDR <= R_ADDR;          // 01           01
                        4'h3:    R_ADDR <= R_ADDR;          // 11           01
                        4'h4:    R_ADDR <= R_ADDR + 1'd1;   // 11           01 +
                                                            // 22           12
                    endcase

                VIDEO::RESOLUTION_B2:                       // 7.2MHz       (0+384+0)*15/8=720
                    case (out_state)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    R_ADDR <= R_ADDR + 1'd1;   // 00000000     x0 +
                        4'h1:    R_ADDR <= R_ADDR;          // 00000001     01
                        4'h2:    R_ADDR <= R_ADDR + 1'd1;   // 11111111     01 +
                        4'h3:    R_ADDR <= R_ADDR;          // 11111122     12
                        4'h4:    R_ADDR <= R_ADDR + 1'd1;   // 22222222     12 +
                        4'h5:    R_ADDR <= R_ADDR;          // 22222333     23
                        4'h6:    R_ADDR <= R_ADDR + 1'd1;   // 33333333     23 +
                        4'h7:    R_ADDR <= R_ADDR;          // 33334444     34
                        4'h8:    R_ADDR <= R_ADDR + 1'd1;   // 44444444     34 +
                        4'h9:    R_ADDR <= R_ADDR;          // 44455555     45
                        4'ha:    R_ADDR <= R_ADDR + 1'd1;   // 55555555     45 +
                        4'hb:    R_ADDR <= R_ADDR;          // 55666666     56
                        4'hc:    R_ADDR <= R_ADDR + 1'd1;   // 66666666     56 +
                        4'hd:    R_ADDR <= R_ADDR;          // 67777777     67
                        4'he:    R_ADDR <= R_ADDR + 1'd1;   // 77777777     67 +
                                                            // 88888888     78
                    endcase

                VIDEO::RESOLUTION_B3:                       // 10.7MHz      (32+512+32)*5/4=720
                    case (out_state)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    R_ADDR <= R_ADDR + 1'd1;   // 0000         x0 +
                        4'h1:    R_ADDR <= R_ADDR + 1'd1;   // 0111         x1 +
                        4'h2:    R_ADDR <= R_ADDR + 1'd1;   // 1122         12 +
                        4'h3:    R_ADDR <= R_ADDR;          // 2223         23
                        4'h4:    R_ADDR <= R_ADDR + 1'd1;   // 3333         23 +
                                                            // 4444         34
                    endcase

                VIDEO::RESOLUTION_B4:                       // 14.3MHz      (0+768+0)*15/16=720
                    case (out_state)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    R_ADDR <= R_ADDR + 2'd2;   // 0000000000000001     x0
                        4'h1:    R_ADDR <= R_ADDR + 1'd1;   // 1111111111111122     12
                        4'h2:    R_ADDR <= R_ADDR + 1'd1;   // 2222222222222333     23
                        4'h3:    R_ADDR <= R_ADDR + 1'd1;   // 3333333333334444     34
                        4'h4:    R_ADDR <= R_ADDR + 1'd1;   // 4444444444455555     45
                        4'h5:    R_ADDR <= R_ADDR + 1'd1;   // 5555555555666666     56
                        4'h6:    R_ADDR <= R_ADDR + 1'd1;   // 6666666667777777     67
                        4'h7:    R_ADDR <= R_ADDR + 1'd1;   // 7777777788888888     78
                        4'h8:    R_ADDR <= R_ADDR + 1'd1;   // 8888888999999999     89
                        4'h9:    R_ADDR <= R_ADDR + 1'd1;   // 999999AAAAAAAAAA     9A
                        4'ha:    R_ADDR <= R_ADDR + 1'd1;   // AAAAABBBBBBBBBBB     AB
                        4'hb:    R_ADDR <= R_ADDR + 1'd1;   // BBBBCCCCCCCCCCCC     BC
                        4'hc:    R_ADDR <= R_ADDR + 1'd1;   // CCCDDDDDDDDDDDDD     CD
                        4'hd:    R_ADDR <= R_ADDR + 1'd1;   // DDEEEEEEEEEEEEEE     DE
                        4'he:    R_ADDR <= R_ADDR + 1'd1;   // EFFFFFFFFFFFFFFF     EF
                    endcase

                VIDEO::RESOLUTION_B5,                       // 25           (0+640+0)*9/8=720
                VIDEO::RESOLUTION_B6:                       // 25MHz        (0+640+0)*9/8=720
                    case (out_state)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    R_ADDR <= R_ADDR + 1'd1;   // 00000000     x0 +
                        4'h1:    R_ADDR <= R_ADDR + 1'd1;   // 01111111     01 +
                        4'h2:    R_ADDR <= R_ADDR + 1'd1;   // 11222222     12 +
                        4'h3:    R_ADDR <= R_ADDR + 1'd1;   // 22233333     23 +
                        4'h4:    R_ADDR <= R_ADDR + 1'd1;   // 33334444     34 +
                        4'h5:    R_ADDR <= R_ADDR + 1'd1;   // 44444555     45 +
                        4'h6:    R_ADDR <= R_ADDR + 1'd1;   // 55555566     56 +
                        4'h7:    R_ADDR <= R_ADDR;          // 66666667     67
                        4'h8:    R_ADDR <= R_ADDR + 1'd1;   // 77777777     67 +
                                                            // 88888888     78
                    endcase
            endcase
        end
    end

    always_ff @(posedge OUT_CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT <= 0;
        end
        else if(OUT_START) begin
            OUT <= 0;
        end
        else if(OUT_EN && out_count != 10'd720) begin
            case (IN_RESOLUTION)
                default:         OUT <= c1[7:0];

                VIDEO::RESOLUTION_B1:                       // 5.4MHz       (16+256+16)*5/2=720
                    case (out_state_delay)
                        default: OUT <= 0;                  //              PC
                        4'h0:    OUT <= p0_c2[8:1];         // 00           x0
                        4'h1:    OUT <= p0_c2[8:1];         // 00           x0
                        4'h2:    OUT <= p1_c1[8:1];         // 01           01
                        4'h3:    OUT <= p0_c2[8:1];         // 11           01
                        4'h4:    OUT <= p0_c2[8:1];         // 11           01
                                                            // 22           12
                    endcase

                VIDEO::RESOLUTION_B2:                       // 7.2MHz       (0+384+0)*15/8=720
                    case (out_state_delay)
                        default: OUT <= 0;                  //              PC
                        4'h0:    OUT <= p0_c8[10:3];        // 00000000     x0
                        4'h1:    OUT <= p7_c1[10:3];        // 00000001     01
                        4'h2:    OUT <= p0_c8[10:3];        // 11111111     01
                        4'h3:    OUT <= p6_c2[10:3];        // 11111122     12
                        4'h4:    OUT <= p0_c8[10:3];        // 22222222     12
                        4'h5:    OUT <= p5_c3[10:3];        // 22222333     23
                        4'h6:    OUT <= p0_c8[10:3];        // 33333333     23
                        4'h7:    OUT <= p4_c4[10:3];        // 33334444     34
                        4'h8:    OUT <= p0_c8[10:3];        // 44444444     34
                        4'h9:    OUT <= p3_c5[10:3];        // 44455555     45
                        4'ha:    OUT <= p0_c8[10:3];        // 55555555     45
                        4'hb:    OUT <= p2_c6[10:3];        // 55666666     56
                        4'hc:    OUT <= p0_c8[10:3];        // 66666666     56
                        4'hd:    OUT <= p1_c7[10:3];        // 67777777     67
                        4'he:    OUT <= p0_c8[10:3];        // 77777777     67
                                                            // 88888888     78
                    endcase

                VIDEO::RESOLUTION_B3:                       // 10.7MHz      (32+512+32)*5/4=720
                    case (out_state_delay)
                        default: OUT <= 0;                  //              PC
                        4'h0:    OUT <= p0_c4[9:2];         // 0000         x0
                        4'h1:    OUT <= p1_c3[9:2];         // 0111         01
                        4'h2:    OUT <= p2_c2[9:2];         // 1122         12
                        4'h3:    OUT <= p3_c1[9:2];         // 2223         23
                        4'h4:    OUT <= p0_c4[9:2];         // 3333         23
                                                            // 4444         34
                    endcase

                VIDEO::RESOLUTION_B4:                       // 14.3MHz      (0+768+0)*15/16=720
                    case (out_state_delay)
                        default: R_ADDR <= R_ADDR;          //      R_DATA_P  R_DATA_C
                        4'h0:    OUT <= c1[7:0];            // 0000000000000001     x0 ToDo:最初に2バイト読む
                        4'h1:    OUT <= pE_c2[11:4];        // 1111111111111122     12
                        4'h2:    OUT <= pD_c3[11:4];        // 2222222222222333     23
                        4'h3:    OUT <= pC_c4[11:4];        // 3333333333334444     34
                        4'h4:    OUT <= pB_c5[11:4];        // 4444444444455555     45
                        4'h5:    OUT <= pA_c6[11:4];        // 5555555555666666     56
                        4'h6:    OUT <= p9_c7[11:4];        // 6666666667777777     67
                        4'h7:    OUT <= p8_c8[11:4];        // 7777777788888888     78
                        4'h8:    OUT <= p7_c9[11:4];        // 8888888999999999     89
                        4'h9:    OUT <= p6_cA[11:4];        // 999999AAAAAAAAAA     9A
                        4'ha:    OUT <= p5_cB[11:4];        // AAAAABBBBBBBBBBB     AB
                        4'hb:    OUT <= p4_cC[11:4];        // BBBBCCCCCCCCCCCC     BC
                        4'hc:    OUT <= p3_cD[11:4];        // CCCDDDDDDDDDDDDD     CD
                        4'hd:    OUT <= p2_cE[11:4];        // DDEEEEEEEEEEEEEE     DE
                        4'he:    OUT <= p1_cF[11:4];        // EFFFFFFFFFFFFFFF     EF
                    endcase
                VIDEO::RESOLUTION_B5,                       // 25           (0+640+0)*9/8=720
                VIDEO::RESOLUTION_B6:                       // 25MHz        (0+640+0)*9/8=720
                    case (out_state_delay)
                        default: OUT <= 0;                  //              PC
                        4'h0:    OUT <= p0_c8[10:3];        // 00000000     x0
                        4'h1:    OUT <= p1_c7[10:3];        // 01111111     01
                        4'h2:    OUT <= p2_c6[10:3];        // 11222222     12
                        4'h3:    OUT <= p3_c5[10:3];        // 22233333     23
                        4'h4:    OUT <= p4_c4[10:3];        // 33334444     34
                        4'h5:    OUT <= p5_c3[10:3];        // 44444555     45
                        4'h6:    OUT <= p6_c2[10:3];        // 55555566     56
                        4'h7:    OUT <= p7_c1[10:3];        // 66666667     67
                        4'h8:    OUT <= p0_c8[10:3];        // 77777777     67
                                                            // 88888888     78
                    endcase
            endcase
        end
    end

endmodule

/***********************************************************************
 * ラインバッファ
 ***********************************************************************/
module VIDEO_UPSCAN_BUFFER #(
    parameter COUNT = 768 * 2
) (
    input wire          W_CLK,
    input wire [10:0]   W_ADDR,
    input wire [7:0]    W_DATA,
    input wire          W_EN,

    input wire          R_CLK,
    input wire [10:0]   R_ADDR,
    output reg [7:0]    R_DATA
);

`define USE_DPB
`ifdef USE_DPB
    wire [7:0] dummy_a;
    wire [15:0] dummy_b;

    DPB u_dpb (
        .DOA({dummy_a[7:0],R_DATA[7:0]}),
        .CLKA(R_CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(1'b0),
        .WREA(1'b0),
        .BLKSELA(3'b000),
        .ADA({R_ADDR[10:0],3'b000}),
        .DIA({8'b00000000,8'b00000000}),

        .DOB(dummy_b),
        .CLKB(W_CLK),
        .OCEB(1'b0),
        .CEB(1'b1),
        .RESETB(1'b0),
        .WREB(W_EN),
        .BLKSELB(3'b000),
        .ADB({W_ADDR[10:0],3'b000}),
        .DIB({8'b00000000,W_DATA[7:0]})
    );

    defparam u_dpb.READ_MODE0 = 1'b0;
    defparam u_dpb.READ_MODE1 = 1'b0;
    defparam u_dpb.WRITE_MODE0 = 2'b00;
    defparam u_dpb.WRITE_MODE1 = 2'b00;
    defparam u_dpb.BIT_WIDTH_0 = 8;
    defparam u_dpb.BIT_WIDTH_1 = 8;
    defparam u_dpb.BLK_SEL_0 = 3'b000;
    defparam u_dpb.BLK_SEL_1 = 3'b000;
    defparam u_dpb.RESET_MODE = "SYNC";
`else
    logic [6-1:0] buff[0:(COUNT)-1] /* synthesis syn_ramstyle="block_ram" */;

    always_ff @(posedge W_CLK) begin
        if(W_EN) begin
            buff[W_ADDR] <= W_DATA[7:2];
        end
    end

    always_ff @(posedge R_CLK) begin
        R_DATA <= {buff[R_ADDR], buff[R_ADDR][5:4]};
    end
`endif

endmodule

`default_nettype wire
