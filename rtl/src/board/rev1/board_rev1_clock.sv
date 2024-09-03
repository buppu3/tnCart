//
// board_rev1_clock.sv
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
 * 
 ***********************************************************************/
module BOARD_REV1_CLOCK (
    input wire      RESET_n,
    input wire      CLK_IN,

    output wire     CLK_BASE,
    output wire     CLK_21M,
    output wire     CLK_BASE_READY,

    output wire     CLK_MEM,
    output wire     CLK_MEM_P,
    output wire     CLK_MEM_READY,

    output wire     CLK_TMDS_S,
    output wire     CLK_TMDS_P,
    output wire     CLK_TMDS_READY
);
    /***************************************************************
     * 基本クロック
     ***************************************************************/
    assign CLK_BASE = CLK_MEM;
    assign CLK_BASE_READY = CLK_MEM_READY;

    /***************************************************************
     * 107.4MHz * 44 / 35 = 134.25MHz
     ***************************************************************/
    assign CLK_TMDS_READY = RESET_n && lock_135m;
    wire lock_135m;
    rPLL u_pll_tmds (
        .CLKOUT(CLK_TMDS_S),
        .LOCK(lock_135m),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(!CLK_MEM_READY),
        .RESET_P(1'b0),
        .CLKIN(CLK_MEM),
        .CLKFB(1'b0),
        .FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PSDA({1'b0,1'b0,1'b0,1'b0}),
        .DUTYDA({1'b0,1'b0,1'b0,1'b0}),
        .FDLY({1'b0,1'b0,1'b0,1'b0})
    );

    defparam u_pll_tmds.FCLKIN = "107.4";
    defparam u_pll_tmds.DYN_IDIV_SEL = "false";
    defparam u_pll_tmds.IDIV_SEL = 3;
    defparam u_pll_tmds.DYN_FBDIV_SEL = "false";
    defparam u_pll_tmds.FBDIV_SEL = 4;
    defparam u_pll_tmds.DYN_ODIV_SEL = "false";
    defparam u_pll_tmds.ODIV_SEL = 4;
    defparam u_pll_tmds.PSDA_SEL = "0000";
    defparam u_pll_tmds.DYN_DA_EN = "true";
    defparam u_pll_tmds.DUTYDA_SEL = "1000";
    defparam u_pll_tmds.CLKOUT_FT_DIR = 1'b1;
    defparam u_pll_tmds.CLKOUTP_FT_DIR = 1'b1;
    defparam u_pll_tmds.CLKOUT_DLY_STEP = 0;
    defparam u_pll_tmds.CLKOUTP_DLY_STEP = 0;
    defparam u_pll_tmds.CLKFB_SEL = "internal";
    defparam u_pll_tmds.CLKOUT_BYPASS = "false";
    defparam u_pll_tmds.CLKOUTP_BYPASS = "false";
    defparam u_pll_tmds.CLKOUTD_BYPASS = "false";
    defparam u_pll_tmds.DYN_SDIV_SEL = 2;
    defparam u_pll_tmds.CLKOUTD_SRC = "CLKOUT";
    defparam u_pll_tmds.CLKOUTD3_SRC = "CLKOUT";
    defparam u_pll_tmds.DEVICE = "GW2AR-18C";

    /***************************************************************
     * 134.25MHz /5 = 26.85MHz
     ***************************************************************/
    CLKDIV u_div_tmds (
        .CLKOUT(CLK_TMDS_P),
        .HCLKIN(CLK_TMDS_S),
        .RESETN(CLK_TMDS_READY),
        .CALIB(1'b0)
    );
    defparam u_div_tmds.DIV_MODE = "5";
    defparam u_div_tmds.GSREN = "false";
    
    /***************************************************************
     * 3.58MHz * 30 = 107.4MHz
     ***************************************************************/
    wire CLK_MEM_LOCK;
    assign CLK_MEM_READY = RESET_n && CLK_MEM_LOCK;
    rPLL u_pll_base (
        .CLKOUT(CLK_MEM),
        .LOCK(CLK_MEM_LOCK),
        .CLKOUTP(CLK_MEM_P),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(!RESET_n),
        .RESET_P(1'b0),
        .CLKIN(CLK_IN),
        .CLKFB(1'b0),
        .FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PSDA({1'b0,1'b0,1'b0,1'b0}),
        .DUTYDA({1'b0,1'b0,1'b0,1'b0}),
        .FDLY({1'b1,1'b1,1'b1,1'b1})
    );

    defparam u_pll_base.FCLKIN = "3.58";
    defparam u_pll_base.DYN_IDIV_SEL = "false";
    defparam u_pll_base.IDIV_SEL = 0;
    defparam u_pll_base.DYN_FBDIV_SEL = "false";
    defparam u_pll_base.FBDIV_SEL = 29;
    defparam u_pll_base.DYN_ODIV_SEL = "false";
    defparam u_pll_base.ODIV_SEL = 8;
    defparam u_pll_base.PSDA_SEL = "1000";
    defparam u_pll_base.DYN_DA_EN = "false";
    defparam u_pll_base.DUTYDA_SEL = "1000";
    defparam u_pll_base.CLKOUT_FT_DIR = 1'b1;
    defparam u_pll_base.CLKOUTP_FT_DIR = 1'b1;
    defparam u_pll_base.CLKOUT_DLY_STEP = 0;
    defparam u_pll_base.CLKOUTP_DLY_STEP = 0;
    defparam u_pll_base.CLKFB_SEL = "internal";
    defparam u_pll_base.CLKOUT_BYPASS = "false";
    defparam u_pll_base.CLKOUTP_BYPASS = "false";
    defparam u_pll_base.CLKOUTD_BYPASS = "false";
    defparam u_pll_base.DYN_SDIV_SEL = 2;
    defparam u_pll_base.CLKOUTD_SRC = "CLKOUT";
    defparam u_pll_base.CLKOUTD3_SRC = "CLKOUT";
    defparam u_pll_base.DEVICE = "GW2AR-18C";

    /***************************************************************
     * 107.4MHz / 5 = 21.48MHz
     ***************************************************************/
    CLKDIV u_div_21m (
        .CLKOUT(CLK_21M),
        .HCLKIN(CLK_BASE),
        .RESETN(CLK_BASE_READY),
        .CALIB(1'b0)
    );
    defparam u_div_21m.DIV_MODE = "5";
    defparam u_div_21m.GSREN = "false";
endmodule

`default_nettype wire
