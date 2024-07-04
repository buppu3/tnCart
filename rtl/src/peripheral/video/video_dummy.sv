//
// video_dummy.sv
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

module VIDEO_DUMMY (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_27M,
    input wire          CLK_21M,
    input wire          CLK_14M,

    input wire VIDEO::RESOLUTION_t RESOLUTION,

    VIDEO_IF.OUT        OUT
);
    localparam [23:0] BORDER_COLOR = 24'h65DBEF;
    localparam [23:0] BACK_COLOR = 24'h5955E0;
    localparam [23:0] GRID_COLOR = 24'hFFFFFF;

    /***************************************************************
     * CLK_27M_EN
     ***************************************************************/
    wire CLK_27M_EN = !prev_clk_27m && CLK_27M;

    logic prev_clk_27m;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_clk_27m <= 0;
        else         prev_clk_27m <= CLK_27M;
    end

    /***************************************************************
     * CLK_21M_EN
     ***************************************************************/
    wire CLK_21M_EN = !prev_clk_21m && CLK_21M;

    logic prev_clk_21m;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_clk_21m <= 0;
        else         prev_clk_21m <= CLK_21M;
    end

    /***************************************************************
     * CLK_14M_EN
     ***************************************************************/
    wire CLK_14M_EN = !prev_clk_14m && CLK_14M;

    logic prev_clk_14m;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_clk_14m <= 0;
        else         prev_clk_14m <= CLK_14M;
    end

    /***************************************************************
     * MODE
     ***************************************************************/
    localparam [9:0] B1_H_SYNC          = 10'd25;
    localparam [9:0] B1_H_ERASE_LEFT    = 10'd50;
    localparam [9:0] B1_H_BORDER_LEFT   = 10'd14;
    localparam [9:0] B1_H_DISPLAY       = 10'd256;
    localparam [9:0] B1_H_BORDER_RIGHT  = 10'd14;
    localparam [9:0] B1_H_ERASE_RIGHT   = 10'd8;
    localparam [9:0] B1_V_SYNC          = 10'd3;
    localparam [9:0] B1_V_ERASE_TOP     = 10'd18;
    localparam [9:0] B1_V_BORDER_TOP    = 10'd14;
    localparam [9:0] B1_V_DISPLAY       = 10'd212;
    localparam [9:0] B1_V_BORDER_BOTTOM = 10'd14;
    localparam [9:0] B1_V_ERASE_BOTTOM  = 10'd4;

    localparam [9:0] B2_H_SYNC          = 10'd34;
    localparam [9:0] B2_H_ERASE_LEFT    = 10'd62;
    localparam [9:0] B2_H_BORDER_LEFT   = 10'd0;
    localparam [9:0] B2_H_DISPLAY       = 10'd384;
    localparam [9:0] B2_H_BORDER_RIGHT  = 10'd0;
    localparam [9:0] B2_H_ERASE_RIGHT   = 10'd10;
    localparam [9:0] B2_V_SYNC          = 10'd3;
    localparam [9:0] B2_V_ERASE_TOP     = 10'd18;
    localparam [9:0] B2_V_BORDER_TOP    = 10'd0;
    localparam [9:0] B2_V_DISPLAY       = 10'd240;
    localparam [9:0] B2_V_BORDER_BOTTOM = 10'd0;
    localparam [9:0] B2_V_ERASE_BOTTOM  = 10'd4;

    localparam [9:0] B3_H_SYNC          = 10'd50;
    localparam [9:0] B3_H_ERASE_LEFT    = 10'd100;
    localparam [9:0] B3_H_BORDER_LEFT   = 10'd28;
    localparam [9:0] B3_H_DISPLAY       = 10'd512;
    localparam [9:0] B3_H_BORDER_RIGHT  = 10'd28;
    localparam [9:0] B3_H_ERASE_RIGHT   = 10'd16;
    localparam [9:0] B3_V_SYNC          = 10'd3;
    localparam [9:0] B3_V_ERASE_TOP     = 10'd18;
    localparam [9:0] B3_V_BORDER_TOP    = 10'd14;
    localparam [9:0] B3_V_DISPLAY       = 10'd212;
    localparam [9:0] B3_V_BORDER_BOTTOM = 10'd14;
    localparam [9:0] B3_V_ERASE_BOTTOM  = 10'd4;

    localparam [9:0] B4_H_SYNC          = 10'd68;
    localparam [9:0] B4_H_ERASE_LEFT    = 10'd124;
    localparam [9:0] B4_H_BORDER_LEFT   = 10'd0;
    localparam [9:0] B4_H_DISPLAY       = 10'd768;
    localparam [9:0] B4_H_BORDER_RIGHT  = 10'd0;
    localparam [9:0] B4_H_ERASE_RIGHT   = 10'd20;
    localparam [9:0] B4_V_SYNC          = 10'd3;
    localparam [9:0] B4_V_ERASE_TOP     = 10'd18;
    localparam [9:0] B4_V_BORDER_TOP    = 10'd0;
    localparam [9:0] B4_V_DISPLAY       = 10'd240;
    localparam [9:0] B4_V_BORDER_BOTTOM = 10'd0;
    localparam [9:0] B4_V_ERASE_BOTTOM  = 10'd4;

    localparam [9:0] B5_H_SYNC          = 10'd64;
    localparam [9:0] B5_H_ERASE_LEFT    = 10'd128;
    localparam [9:0] B5_H_BORDER_LEFT   = 10'd0;
    localparam [9:0] B5_H_DISPLAY       = 10'd640;
    localparam [9:0] B5_H_BORDER_RIGHT  = 10'd0;
    localparam [9:0] B5_H_ERASE_RIGHT   = 10'd80;
    localparam [9:0] B5_V_SYNC          = 10'd8;
    localparam [9:0] B5_V_ERASE_TOP     = 10'd33;
    localparam [9:0] B5_V_BORDER_TOP    = 10'd0;
    localparam [9:0] B5_V_DISPLAY       = 10'd400;
    localparam [9:0] B5_V_BORDER_BOTTOM = 10'd0;
    localparam [9:0] B5_V_ERASE_BOTTOM  = 10'd7;

    localparam [9:0] B6_H_SYNC          = 10'd96;
    localparam [9:0] B6_H_ERASE_LEFT    = 10'd112;
    localparam [9:0] B6_H_BORDER_LEFT   = 10'd0;
    localparam [9:0] B6_H_DISPLAY       = 10'd640;
    localparam [9:0] B6_H_BORDER_RIGHT  = 10'd0;
    localparam [9:0] B6_H_ERASE_RIGHT   = 10'd48;
    localparam [9:0] B6_V_SYNC          = 10'd2;
    localparam [9:0] B6_V_ERASE_TOP     = 10'd35;
    localparam [9:0] B6_V_BORDER_TOP    = 10'd0;
    localparam [9:0] B6_V_DISPLAY       = 10'd480;
    localparam [9:0] B6_V_BORDER_BOTTOM = 10'd0;
    localparam [9:0] B6_V_ERASE_BOTTOM  = 10'd10;

    localparam [9:0] D_720_480_H_SYNC          = 10'd62;
    localparam [9:0] D_720_480_H_ERASE_LEFT    = 10'd69;
    localparam [9:0] D_720_480_H_BORDER_LEFT   = 10'd0;
    localparam [9:0] D_720_480_H_DISPLAY       = 10'd720;
    localparam [9:0] D_720_480_H_BORDER_RIGHT  = 10'd0;
    localparam [9:0] D_720_480_H_ERASE_RIGHT   = 10'd66;
    localparam [9:0] D_720_480_V_SYNC          = 10'd2;
    localparam [9:0] D_720_480_V_ERASE_TOP     = 10'd35;
    localparam [9:0] D_720_480_V_BORDER_TOP    = 10'd0;
    localparam [9:0] D_720_480_V_DISPLAY       = 10'd480;
    localparam [9:0] D_720_480_V_BORDER_BOTTOM = 10'd0;
    localparam [9:0] D_720_480_V_ERASE_BOTTOM  = 10'd10;

    reg [9:0] H_TOTAL;
    reg [9:0] H_SYNC;
    reg [9:0] H_ERASE_LEFT_POS;
    reg [9:0] H_ERASE_RIGHT_POS;
    reg [9:0] H_BORDER_LEFT_POS;
    reg [9:0] H_BORDER_RIGHT_POS;
    reg [9:0] H_DISPLAY_LEFT_POS;

    reg [9:0] V_TOTAL;
    reg [9:0] V_SYNC;
    reg [9:0] V_ERASE_TOP_POS;
    reg [9:0] V_ERASE_BOTTOM_POS;
    reg [9:0] V_BORDER_TOP_POS;
    reg [9:0] V_BORDER_BOTTOM_POS;
    reg [9:0] V_DISPLAY_TOP_POS;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || RESOLUTION == VIDEO::RESOLUTION_B1) begin
            H_SYNC              <= B1_H_SYNC;
            H_ERASE_LEFT_POS    <= B1_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B1_H_ERASE_LEFT + B1_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B1_H_ERASE_LEFT + B1_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B1_H_ERASE_LEFT + B1_H_BORDER_LEFT + B1_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B1_H_ERASE_LEFT + B1_H_BORDER_LEFT + B1_H_DISPLAY + B1_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B1_H_ERASE_LEFT + B1_H_BORDER_LEFT + B1_H_DISPLAY + B1_H_BORDER_RIGHT + B1_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B1_V_SYNC;
            V_ERASE_TOP_POS     <= B1_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B1_V_ERASE_TOP + B1_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B1_V_ERASE_TOP + B1_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B1_V_ERASE_TOP + B1_V_BORDER_TOP + B1_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B1_V_ERASE_TOP + B1_V_BORDER_TOP + B1_V_DISPLAY + B1_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B1_V_ERASE_TOP + B1_V_BORDER_TOP + B1_V_DISPLAY + B1_V_BORDER_BOTTOM + B1_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B2) begin
            H_SYNC              <= B2_H_SYNC;
            H_ERASE_LEFT_POS    <= B2_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B2_H_ERASE_LEFT + B2_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B2_H_ERASE_LEFT + B2_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B2_H_ERASE_LEFT + B2_H_BORDER_LEFT + B2_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B2_H_ERASE_LEFT + B2_H_BORDER_LEFT + B2_H_DISPLAY + B2_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B2_H_ERASE_LEFT + B2_H_BORDER_LEFT + B2_H_DISPLAY + B2_H_BORDER_RIGHT + B2_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B2_V_SYNC;
            V_ERASE_TOP_POS     <= B2_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B2_V_ERASE_TOP + B2_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B2_V_ERASE_TOP + B2_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B2_V_ERASE_TOP + B2_V_BORDER_TOP + B2_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B2_V_ERASE_TOP + B2_V_BORDER_TOP + B2_V_DISPLAY + B2_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B2_V_ERASE_TOP + B2_V_BORDER_TOP + B2_V_DISPLAY + B2_V_BORDER_BOTTOM + B2_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B3) begin
            H_SYNC              <= B3_H_SYNC;
            H_ERASE_LEFT_POS    <= B3_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B3_H_ERASE_LEFT + B3_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B3_H_ERASE_LEFT + B3_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B3_H_ERASE_LEFT + B3_H_BORDER_LEFT + B3_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B3_H_ERASE_LEFT + B3_H_BORDER_LEFT + B3_H_DISPLAY + B3_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B3_H_ERASE_LEFT + B3_H_BORDER_LEFT + B3_H_DISPLAY + B3_H_BORDER_RIGHT + B3_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B3_V_SYNC;
            V_ERASE_TOP_POS     <= B3_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B3_V_ERASE_TOP + B3_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B3_V_ERASE_TOP + B3_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B3_V_ERASE_TOP + B3_V_BORDER_TOP + B3_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B3_V_ERASE_TOP + B3_V_BORDER_TOP + B3_V_DISPLAY + B3_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B3_V_ERASE_TOP + B3_V_BORDER_TOP + B3_V_DISPLAY + B3_V_BORDER_BOTTOM + B3_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B4) begin
            H_SYNC              <= B4_H_SYNC;
            H_ERASE_LEFT_POS    <= B4_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B4_H_ERASE_LEFT + B4_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B4_H_ERASE_LEFT + B4_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B4_H_ERASE_LEFT + B4_H_BORDER_LEFT + B4_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B4_H_ERASE_LEFT + B4_H_BORDER_LEFT + B4_H_DISPLAY + B4_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B4_H_ERASE_LEFT + B4_H_BORDER_LEFT + B4_H_DISPLAY + B4_H_BORDER_RIGHT + B4_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B4_V_SYNC;
            V_ERASE_TOP_POS     <= B4_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B4_V_ERASE_TOP + B4_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B4_V_ERASE_TOP + B4_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B4_V_ERASE_TOP + B4_V_BORDER_TOP + B4_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B4_V_ERASE_TOP + B4_V_BORDER_TOP + B4_V_DISPLAY + B4_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B4_V_ERASE_TOP + B4_V_BORDER_TOP + B4_V_DISPLAY + B4_V_BORDER_BOTTOM + B4_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B5) begin
            H_SYNC              <= B5_H_SYNC;
            H_ERASE_LEFT_POS    <= B5_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B5_H_ERASE_LEFT + B5_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B5_H_ERASE_LEFT + B5_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B5_H_ERASE_LEFT + B5_H_BORDER_LEFT + B5_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B5_H_ERASE_LEFT + B5_H_BORDER_LEFT + B5_H_DISPLAY + B5_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B5_H_ERASE_LEFT + B5_H_BORDER_LEFT + B5_H_DISPLAY + B5_H_BORDER_RIGHT + B5_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B5_V_SYNC;
            V_ERASE_TOP_POS     <= B5_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B5_V_ERASE_TOP + B5_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B5_V_ERASE_TOP + B5_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B5_V_ERASE_TOP + B5_V_BORDER_TOP + B5_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B5_V_ERASE_TOP + B5_V_BORDER_TOP + B5_V_DISPLAY + B5_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B5_V_ERASE_TOP + B5_V_BORDER_TOP + B5_V_DISPLAY + B5_V_BORDER_BOTTOM + B5_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B6) begin
            H_SYNC              <= B6_H_SYNC;
            H_ERASE_LEFT_POS    <= B6_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= B6_H_ERASE_LEFT + B6_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= B6_H_ERASE_LEFT + B6_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= B6_H_ERASE_LEFT + B6_H_BORDER_LEFT + B6_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= B6_H_ERASE_LEFT + B6_H_BORDER_LEFT + B6_H_DISPLAY + B6_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= B6_H_ERASE_LEFT + B6_H_BORDER_LEFT + B6_H_DISPLAY + B6_H_BORDER_RIGHT + B6_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= B6_V_SYNC;
            V_ERASE_TOP_POS     <= B6_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= B6_V_ERASE_TOP + B6_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= B6_V_ERASE_TOP + B6_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= B6_V_ERASE_TOP + B6_V_BORDER_TOP + B6_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= B6_V_ERASE_TOP + B6_V_BORDER_TOP + B6_V_DISPLAY + B6_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= B6_V_ERASE_TOP + B6_V_BORDER_TOP + B6_V_DISPLAY + B6_V_BORDER_BOTTOM + B6_V_ERASE_BOTTOM - 1'd1;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_720_480) begin
            H_SYNC              <= D_720_480_H_SYNC;
            H_ERASE_LEFT_POS    <= D_720_480_H_ERASE_LEFT - 1'd1;
            H_BORDER_LEFT_POS   <= D_720_480_H_ERASE_LEFT + D_720_480_H_BORDER_LEFT - 1'd1;
            H_DISPLAY_LEFT_POS  <= D_720_480_H_ERASE_LEFT + D_720_480_H_BORDER_LEFT;
            H_BORDER_RIGHT_POS  <= D_720_480_H_ERASE_LEFT + D_720_480_H_BORDER_LEFT + D_720_480_H_DISPLAY - 1'd1;
            H_ERASE_RIGHT_POS   <= D_720_480_H_ERASE_LEFT + D_720_480_H_BORDER_LEFT + D_720_480_H_DISPLAY + D_720_480_H_BORDER_RIGHT - 1'd1;
            H_TOTAL             <= D_720_480_H_ERASE_LEFT + D_720_480_H_BORDER_LEFT + D_720_480_H_DISPLAY + D_720_480_H_BORDER_RIGHT + D_720_480_H_ERASE_RIGHT - 1'd1;
            V_SYNC              <= D_720_480_V_SYNC;
            V_ERASE_TOP_POS     <= D_720_480_V_ERASE_TOP - 1'd1;
            V_BORDER_TOP_POS    <= D_720_480_V_ERASE_TOP + D_720_480_V_BORDER_TOP - 1'd1;
            V_DISPLAY_TOP_POS   <= D_720_480_V_ERASE_TOP + D_720_480_V_BORDER_TOP;
            V_BORDER_BOTTOM_POS <= D_720_480_V_ERASE_TOP + D_720_480_V_BORDER_TOP + D_720_480_V_DISPLAY - 1'd1;
            V_ERASE_BOTTOM_POS  <= D_720_480_V_ERASE_TOP + D_720_480_V_BORDER_TOP + D_720_480_V_DISPLAY + D_720_480_V_BORDER_BOTTOM - 1'd1;
            V_TOTAL             <= D_720_480_V_ERASE_TOP + D_720_480_V_BORDER_TOP + D_720_480_V_DISPLAY + D_720_480_V_BORDER_BOTTOM + D_720_480_V_ERASE_BOTTOM - 1'd1;
        end
    end

    /***************************************************************
     * ドットクロック
     ***************************************************************/
    reg [1:0] clk_div;
    reg DCLK_EN;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            DCLK_EN <= 0;
            clk_div <= 0;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B1) begin
            // 21MHz/2
            if(CLK_21M_EN) begin
                DCLK_EN <= clk_div[1:0] == 0;
                clk_div <= clk_div + 1'd1;
            end
            else begin
                DCLK_EN <= 0;
            end
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B2) begin
            // 14MHz/2
            if(CLK_14M_EN) begin
                DCLK_EN <= clk_div[0] == 0;
                clk_div <= clk_div + 1'd1;
            end
            else begin
                DCLK_EN <= 0;
            end
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B3) begin
            // 21MHz/2
            if(CLK_21M_EN) begin
                DCLK_EN <= clk_div[0] == 0;
                clk_div <= clk_div + 1'd1;
            end
            else begin
                DCLK_EN <= 0;
            end
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_B4) begin
            // 14MHz/1
            DCLK_EN <= CLK_14M_EN;
        end
        else if(RESOLUTION == VIDEO::RESOLUTION_720_480) begin
            // 27MHz/1
            DCLK_EN <= CLK_27M_EN;
        end
        else begin
            DCLK_EN <= 0;
        end
    end

    /***************************************************************
     * H_CNT
     ***************************************************************/
    reg  [9:0] H_CNT;
    wire [9:0] X = H_CNT - H_DISPLAY_LEFT_POS;
    wire h_inc = DCLK_EN;
    wire h_rst = (H_CNT >= H_TOTAL) && h_inc;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)   H_CNT <= 0;
        else if(h_rst) H_CNT <= 0;
        else if(h_inc) H_CNT <= H_CNT + 1'd1;
    end

    /***************************************************************
     * V_CNT
     ***************************************************************/
    reg  [9:0] V_CNT;
    wire [9:0] Y = V_CNT - V_DISPLAY_TOP_POS;
    wire v_inc = h_rst;
    wire v_rst = (V_CNT >= V_TOTAL) && v_inc;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)   V_CNT <= 0;
        else if(v_rst) V_CNT <= 0;
        else if(v_inc) V_CNT <= V_CNT + 1'd1;
    end

    /***************************************************************
     * RGB
     ***************************************************************/
    wire h_erase = (H_CNT <= H_ERASE_LEFT_POS) || (H_CNT > H_ERASE_RIGHT_POS);
    wire h_border = (H_CNT <= H_BORDER_LEFT_POS) || (H_CNT > H_BORDER_RIGHT_POS);
    wire v_erase = (V_CNT <= V_ERASE_TOP_POS) || (V_CNT > V_ERASE_BOTTOM_POS);
    wire v_border = (V_CNT <= V_BORDER_TOP_POS) || (V_CNT > V_BORDER_BOTTOM_POS);
    wire grid = (X[3:0] == 0) || (X[3:0] == 15) || (Y[3:0] == 0) || (Y[3:0] == 15);

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT.R <= 0;
            OUT.G <= 0;
            OUT.B <= 0;
        end
        else if(DCLK_EN) begin
            if(h_erase || v_erase) begin
                OUT.R <= 0;
                OUT.G <= 0;
                OUT.B <= 0;
            end
            else if(h_border || v_border) begin
                OUT.R <= BORDER_COLOR[23:16];
                OUT.G <= BORDER_COLOR[15: 8];
                OUT.B <= BORDER_COLOR[ 7: 0];
            end
            else if(grid) begin
                OUT.R <= GRID_COLOR[23:16];
                OUT.G <= GRID_COLOR[15: 8];
                OUT.B <= GRID_COLOR[ 7: 0];
            end
            else begin
                OUT.R <= BACK_COLOR[23:16];
                OUT.G <= BACK_COLOR[15: 8];
                OUT.B <= BACK_COLOR[ 7: 0];
            end
        end
    end

    /***************************************************************
     * SYNC, CLK
     ***************************************************************/
    wire h_sync = (H_CNT < H_SYNC);
    wire v_sync = (V_CNT < V_SYNC);

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT.DCLK <= 0;
        end
        else if(DCLK_EN) begin
            OUT.DCLK <= 1;
        end
        else begin
            OUT.DCLK <= 0;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT.RESOLUTION <= VIDEO::RESOLUTION_B1;
        end
        else begin
            OUT.RESOLUTION <= RESOLUTION;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT.HS_n <= 1;
        end
        else begin
            OUT.HS_n <= !h_sync;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT.VS_n <= 1;
        end
        else begin
            OUT.VS_n <= !v_sync;
        end
    end
endmodule

`default_nettype wire
