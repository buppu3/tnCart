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
module BOARD_REV1_CLOCK /* synthesis syn_preserve=1 */ (
    input wire      RESET_n,
    input wire      CART_CLOCK,
    input wire      CLK_27M,
    CLOCK_IF.DST    Clock
);
    /***************************************************************
     * TMDS シリアルクロック 135MHz = 27MHz * 5
     ***************************************************************/
    wire clk_tmds_s /* synthesis syn_keep=1 */;
    assign Clock.TMDS_S_CLK = clk_tmds_s;
    assign Clock.TMDS_READY = RESET_n && lock_135m;
    wire lock_135m;
    rPLL u_pll_tmds (
        .CLKOUT(clk_tmds_s),
        .LOCK(lock_135m),
        .CLKOUTP(),
        .CLKOUTD(),
        .CLKOUTD3(),
        .RESET(!RESET_n),
        .RESET_P(1'b0),
        .CLKIN(CLK_27M),
        .CLKFB(1'b0),
        .FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PSDA({1'b0,1'b0,1'b0,1'b0}),
        .DUTYDA({1'b0,1'b0,1'b0,1'b0}),
        .FDLY({1'b0,1'b0,1'b0,1'b0})
    );

    defparam u_pll_tmds.FCLKIN = "27";
    defparam u_pll_tmds.DYN_IDIV_SEL = "false";
    defparam u_pll_tmds.IDIV_SEL = 0;
    defparam u_pll_tmds.DYN_FBDIV_SEL = "false";
    defparam u_pll_tmds.FBDIV_SEL = 4;
    defparam u_pll_tmds.DYN_ODIV_SEL = "false";
    defparam u_pll_tmds.ODIV_SEL = 4;
    defparam u_pll_tmds.PSDA_SEL = "0000";
    defparam u_pll_tmds.DYN_DA_EN = "false";
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
     * TMDS ドットクロック 27MHz = 135MHz / 5
     ***************************************************************/
    wire clk_tmds_p /* synthesis syn_keep=1 */;
    assign Clock.TMDS_P_CLK = clk_tmds_p;
    CLKDIV u_div_tmds (
        .CLKOUT(clk_tmds_p),
        .HCLKIN(Clock.TMDS_S_CLK),
        .RESETN(Clock.TMDS_READY),
        .CALIB(1'b0)
    );
    defparam u_div_tmds.DIV_MODE = "5";
    defparam u_div_tmds.GSREN = "false";


    /***************************************************************
     * 動作クロック
     ***************************************************************/
    wire w_pll_ready;
    wire clk_108m /* synthesis syn_keep=1 */;
    wire clk_43m /* synthesis syn_keep=1 */;
    wire clk_21m /* synthesis syn_keep=1 */;

    if(CONFIG_BOARD::SYNC_CPU_CLK) begin
        // 214.7727MHz = 3.579545MHz * 60
        wire clk_215m /* synthesis syn_keep=1 */;
        wire lock_215m;
        assign w_pll_ready = lock_215m;
        rPLL u_pll_215m (
            .CLKOUT(clk_215m),
            .LOCK(lock_215m),
            .CLKOUTP(),
            .CLKOUTD(),
            .CLKOUTD3(),
            .RESET(!RESET_n),
            .RESET_P(1'b0),
            .CLKIN(CART_CLOCK),
            .CLKFB(1'b0),
            .FBDSEL(6'b000000),
            .IDSEL(6'b000000),
            .ODSEL(6'b000000),
            .PSDA(4'b0000),
            .DUTYDA(4'b0000),
            .FDLY(4'b0000)
        );

        defparam u_pll_215m.FCLKIN = "3.580";
        defparam u_pll_215m.DYN_IDIV_SEL = "false";
        defparam u_pll_215m.IDIV_SEL = 0;
        defparam u_pll_215m.DYN_FBDIV_SEL = "false";
        defparam u_pll_215m.FBDIV_SEL = 59;
        defparam u_pll_215m.DYN_ODIV_SEL = "false";
        defparam u_pll_215m.ODIV_SEL = 4;
        defparam u_pll_215m.PSDA_SEL = "0000";
        defparam u_pll_215m.DYN_DA_EN = "false";
        defparam u_pll_215m.DUTYDA_SEL = "1000";
        defparam u_pll_215m.CLKOUT_FT_DIR = 1'b1;
        defparam u_pll_215m.CLKOUTP_FT_DIR = 1'b1;
        defparam u_pll_215m.CLKOUT_DLY_STEP = 0;
        defparam u_pll_215m.CLKOUTP_DLY_STEP = 0;
        defparam u_pll_215m.CLKFB_SEL = "internal";
        defparam u_pll_215m.CLKOUT_BYPASS = "false";
        defparam u_pll_215m.CLKOUTP_BYPASS = "false";
        defparam u_pll_215m.CLKOUTD_BYPASS = "false";
        defparam u_pll_215m.DYN_SDIV_SEL = 2;
        defparam u_pll_215m.CLKOUTD_SRC = "CLKOUT";
        defparam u_pll_215m.CLKOUTD3_SRC = "CLKOUT";
        defparam u_pll_215m.DEVICE = "GW2AR-18C";

        // 107.38635MHz = 214.7727MHz / 2
        DIV_CLK #(
            .DIV(2),
            .GCLK(1)
        ) u_div_108m (
            .RESET_n,
            .IN(clk_215m),
            .OUT(clk_108m)
        );

        // 42.95454MHz = 214.7727MHz / 5
        DIV_CLK #(
            .DIV(5),
            .GCLK(1)
        ) u_div_43m (
            .RESET_n,
            .IN(clk_215m),
            .OUT(clk_43m)
        );

        // 21.47727MHz = 214.7727MHz / 10
        DIV_CLK #(
            .DIV(10),
            .GCLK(1)
        ) u_div_21m (
            .RESET_n,
            .IN(clk_215m),
            .OUT(clk_21m)
        );
    end
    else begin
        // 432.0MHz = 27MHz * 16
        wire clk_432m /* synthesis syn_keep=1 */;
        wire lock_432m;
        assign w_pll_ready = lock_432m;
        rPLL u_pll_432m (
            .CLKOUT(clk_432m),
            .LOCK(lock_432m),
            .CLKOUTP(),
            .CLKOUTD(),
            .CLKOUTD3(),
            .RESET(!RESET_n),
            .RESET_P(1'b0),
            .CLKIN(CLK_27M),
            .CLKFB(1'b0),
            .FBDSEL(6'b000000),
            .IDSEL(6'b000000),
            .ODSEL(6'b000000),
            .PSDA(4'b0000),
            .DUTYDA(4'b0000),
            .FDLY(4'b0000)
        );

        defparam u_pll_432m.FCLKIN = "27";
        defparam u_pll_432m.DYN_IDIV_SEL = "false";
        defparam u_pll_432m.IDIV_SEL = 0;
        defparam u_pll_432m.DYN_FBDIV_SEL = "false";
        defparam u_pll_432m.FBDIV_SEL = 15;
        defparam u_pll_432m.DYN_ODIV_SEL = "false";
        defparam u_pll_432m.ODIV_SEL = 2;
        defparam u_pll_432m.PSDA_SEL = "0000";
        defparam u_pll_432m.DYN_DA_EN = "false";
        defparam u_pll_432m.DUTYDA_SEL = "1000";
        defparam u_pll_432m.CLKOUT_FT_DIR = 1'b1;
        defparam u_pll_432m.CLKOUTP_FT_DIR = 1'b1;
        defparam u_pll_432m.CLKOUT_DLY_STEP = 0;
        defparam u_pll_432m.CLKOUTP_DLY_STEP = 0;
        defparam u_pll_432m.CLKFB_SEL = "internal";
        defparam u_pll_432m.CLKOUT_BYPASS = "false";
        defparam u_pll_432m.CLKOUTP_BYPASS = "false";
        defparam u_pll_432m.CLKOUTD_BYPASS = "false";
        defparam u_pll_432m.DYN_SDIV_SEL = 2;
        defparam u_pll_432m.CLKOUTD_SRC = "CLKOUT";
        defparam u_pll_432m.CLKOUTD3_SRC = "CLKOUT";
        defparam u_pll_432m.DEVICE = "GW2AR-18C";

        // 108.0MHz = 432.0MHz / 4
        DIV_CLK #(
            .DIV(4),
            .GCLK(1)
        ) u_div_108m (
            .RESET_n,
            .IN(clk_432m),
            .OUT(clk_108m)
        );

        // 43.2MHz = 432.0MHz / 10
        DIV_CLK #(
            .DIV(10),
            .GCLK(1)
        ) u_div_43m (
            .RESET_n,
        .IN(clk_432m),
            .OUT(clk_43m)
        );

        // 21.6MHz = 432.0MHz / 20
        DIV_CLK #(
            .DIV(20),
            .GCLK(1)
        ) u_div_21m (
            .RESET_n,
            .IN(clk_432m),
            .OUT(clk_21m)
        );
    end

    /***************************************************************
     * enable
     ***************************************************************/
    wire w_ena_43m_108;
    wire w_ena_21m_108;
    wire w_ena_4m_108;
    wire w_ena_1m_108;
    DIV_EN #(.COUNT(  5)) u_43m_108 (.RESET_n, .IN(clk_108m), .OUT(w_ena_43m_108)); // 43.2M
    DIV_EN #(.COUNT(  5)) u_21m_108 (.RESET_n, .IN(clk_108m), .OUT(w_ena_21m_108)); // 21.6M
    DIV_EN #(.COUNT( 30)) u_4m_108  (.RESET_n, .IN(clk_108m), .OUT(w_ena_4m_108 )); //  3.6M
    DIV_EN #(.COUNT(120)) u_1m_108  (.RESET_n, .IN(clk_108m), .OUT(w_ena_1m_108 )); //  0.9M

    wire w_ena_21m_43;
    wire w_ena_4m_43;
    wire w_ena_dac_43;
    DIV_EN #(.COUNT( 2)) u_21m_43 (.RESET_n, .IN(clk_43m), .OUT(w_ena_21m_43));     // 21M
    DIV_EN #(.COUNT(12)) u_4m_43  (.RESET_n, .IN(clk_43m), .OUT(w_ena_4m_43 ));     //  4M
    DIV_EN #(.COUNT(CONFIG_BOARD::DAC_FREQ_DIV)) u_dac_43 (.RESET_n, .IN(clk_43m), .OUT(w_ena_dac_43)); // DAC_FREQ_DIV

    wire w_ena_4m_21;
    wire w_ena_1m_21;
    DIV_EN #(.COUNT( 6)) u_4m_21 (.RESET_n, .IN(clk_21m), .OUT(w_ena_4m_21));        // 4M
    DIV_EN #(.COUNT(24)) u_1m_21 (.RESET_n, .IN(clk_21m), .OUT(w_ena_1m_21));        // 1M

    /***************************************************************
     * assign
     ***************************************************************/
    assign Clock.MEM_READY = RESET_n && w_pll_ready;
    assign Clock.MEM_CLK = clk_108m;

    assign Clock.OP_READY = Clock.MEM_READY;
    assign Clock.OP_CLK = clk_108m;
    assign Clock.OP_PSG_EN = 1;
    assign Clock.OP_SCC_EN = 1;
    assign Clock.OP_OPLL_EN = w_ena_21m_108;

    assign Clock.VDP_CLK = clk_43m;

    assign Clock.PSG_CLK = clk_108m;
    assign Clock.PSG_4M_EN = w_ena_4m_108;

    assign Clock.SCC_CLK = clk_108m;
    assign Clock.SCC_4M_EN = w_ena_4m_108;

    assign Clock.OPLL_CLK = clk_21m;
    assign Clock.OPLL_4M_EN = w_ena_4m_21;

    assign Clock.LED_CLK = clk_108m;
    assign Clock.LED_ENA = w_ena_1m_108;

    assign Clock.DAC_CLK = clk_43m;
    assign Clock.DAC_ENA = w_ena_dac_43;

    module DIV_EN #(
        parameter   COUNT = 2
    ) (
        input wire RESET_n,
        input wire IN,
        output wire OUT
    );
        if(COUNT <= 1) begin
            assign OUT = 1'b1;
        end
        else begin
            reg [$clog2(COUNT)-1:0] ff_cnt;
            always_ff @(posedge IN or negedge RESET_n) begin
                if(!RESET_n)         ff_cnt <= COUNT - 1'd1;
                else if(ff_cnt == 0) ff_cnt <= COUNT - 1'd1;
                else                 ff_cnt <= ff_cnt - 1'd1;
            end

            reg ff_out;
            always_ff @(posedge IN or negedge RESET_n) begin
                if(!RESET_n)         ff_out <= 1;
                else if(ff_cnt == 0) ff_out <= 1;
                else                 ff_out <= 0;
            end

            assign OUT = ff_out;
        end
    endmodule

    module DIV_CLK #(
        parameter DIV = 2,
        parameter GCLK = 0
    ) (
        input wire IN,
        input wire RESET_n,
        output wire OUT
    );
        reg ff_out = 0;

        if(DIV > 2) begin
            localparam DIV_E = (DIV / 2);
            localparam DIV_O = (DIV - DIV_E);
            localparam DIV_CNT_E = (DIV_E - 1);
            localparam DIV_CNT_O = (DIV_O - 1);
            localparam DIV_CNT_BITS = $clog2(DIV_CNT_O+1);

            reg [DIV_CNT_BITS-1:0] ff_cnt = 0;

            always_ff @(posedge IN or negedge RESET_n) begin
                if(!RESET_n)         ff_cnt <= 0;
                else if(ff_cnt == 0) ff_cnt <= ff_out ? DIV_CNT_E : DIV_CNT_O;
                else                 ff_cnt <= ff_cnt - 1'd1;
            end

            always_ff @(posedge IN or negedge RESET_n) begin
                if(!RESET_n)         ff_out <= 0;
                else if(ff_cnt == 0) ff_out <= ~ff_out;
            end
        end
        else begin
            always_ff @(posedge IN or negedge RESET_n) begin
                if(!RESET_n) ff_out <= 0;
                else         ff_out <= ~ff_out;
            end
        end

        if(GCLK) begin
            DQCE u_dqce (
                .CLKIN(ff_out),
                .CE(1'b1),
                .CLKOUT(OUT)
            );
        end
        else begin
            assign OUT = ff_out;
        end
    endmodule
endmodule

`default_nettype wire
