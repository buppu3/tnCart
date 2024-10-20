//
// board_rev2_bus.sv
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
 * MSX バスの入力
 ***************************************************************/
module BOARD_REV2_BUS(
    input wire              RESET_n,
    input wire              CLK,
    input wire              CLK_21M,

    output  wire            CART_BUSDIR_n,
    output  wire            CART_INT_n,
    output  wire            CART_WAIT_n,
    input   wire            CART_CLOCK,
    input   wire    [5:0]   CART_MUX_SIG,
    output  wire    [1:0]   CART_MUX_CS_A,
    inout   wire    [7:0]   CART_DATA_SIG,

    BUS_IF.MSX              Bus
);
    /***************************************************************
     * バッファの切り替え
     ***************************************************************/
    localparam  CS_A0       = 0,    BIT_A0      = 0;
    localparam  CS_A1       = 0,    BIT_A1      = 1;
    localparam  CS_A2       = 0,    BIT_A2      = 2;
    localparam  CS_A3       = 0,    BIT_A3      = 3;
    localparam  CS_A4       = 0,    BIT_A4      = 4;
    localparam  CS_A5       = 0,    BIT_A5      = 5;

    localparam  CS_A6       = 1,    BIT_A6      = 0;
    localparam  CS_A7       = 1,    BIT_A7      = 1;
    localparam  CS_A8       = 1,    BIT_A8      = 2;
    localparam  CS_A9       = 1,    BIT_A9      = 3;
    localparam  CS_A10      = 1,    BIT_A10     = 4;
    localparam  CS_A11      = 1,    BIT_A11     = 5;

    localparam  CS_A12      = 2,    BIT_A12     = 0;
    localparam  CS_A13      = 2,    BIT_A13     = 1;
    localparam  CS_A14      = 2,    BIT_A14     = 2;
    localparam  CS_A15      = 2,    BIT_A15     = 3;
    localparam  CS_RD       = 2,    BIT_RD      = 4;
    localparam  CS_WR       = 2,    BIT_WR      = 5;

    localparam  CS_RFSH     = 3,    BIT_RFSH    = 0;
    localparam  CS_SLTSL    = 3,    BIT_SLTSL   = 1;
    localparam  CS_MERQ     = 3,    BIT_MERQ    = 2;
    localparam  CS_IORQ     = 3,    BIT_IORQ    = 3;
    localparam  CS_RESET    = 3,    BIT_RESET   = 4;

    // バッファの OE 信号
    reg [1:0]   mux_cs_ff;
    assign      CART_MUX_CS_A = mux_cs_ff;
    localparam  MUX_SEL_0   = 2'b00;
    localparam  MUX_SEL_1   = 2'b01;
    localparam  MUX_SEL_2   = 2'b10;
    localparam  MUX_SEL_3   = 2'b11;

    //
    logic [3:0] state;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            state <= 0;
            mux_cs_ff <= MUX_SEL_0;
        end else begin
            state <= (state == 4'd8) ? 4'd0 : (state + 1'd1);
            case (state)
                4'd0:       begin   mux_cs_ff <= MUX_SEL_0;    end  // read0
                4'd1:       begin   mux_cs_ff <= MUX_SEL_1;    end  // read0 change 1
                4'd2:       begin   mux_cs_ff <= MUX_SEL_1;    end  // wait
                4'd3:       begin   mux_cs_ff <= MUX_SEL_1;    end  // read1
                4'd4:       begin   mux_cs_ff <= MUX_SEL_2;    end  // read1 change 2
                4'd5:       begin   mux_cs_ff <= MUX_SEL_2;    end  // wait
                4'd6:       begin   mux_cs_ff <= MUX_SEL_2;    end  // read2
                4'd7:       begin   mux_cs_ff <= MUX_SEL_3;    end  // read2 change 3
                4'd8:       begin   mux_cs_ff <= MUX_SEL_3;    end  // wait
                4'd9:       begin   mux_cs_ff <= MUX_SEL_3;    end  // read3
                4'd10:      begin   mux_cs_ff <= MUX_SEL_0;    end  // read3 change 0
                4'd11:      begin   mux_cs_ff <= MUX_SEL_0;    end  // wait
            endcase
        end
    end

    wire [3:0]  mux_active;
    assign      mux_active[0] = state == 4'd0 || state == 4'd1;
    assign      mux_active[1] = state == 4'd3 || state == 4'd4;
    assign      mux_active[2] = state == 4'd6 || state == 4'd7;
    assign      mux_active[3] = state == 4'd9 || state == 4'd10;

    /***************************************************************
     * アドレスバスの取得
     ***************************************************************/
    logic [15:0] ADDR;
    PIN_FILTER u_a0    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A0 ]), .IN(CART_MUX_SIG[BIT_A0 ]), .OUT(ADDR[ 0]));
    PIN_FILTER u_a1    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A1 ]), .IN(CART_MUX_SIG[BIT_A1 ]), .OUT(ADDR[ 1]));
    PIN_FILTER u_a2    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A2 ]), .IN(CART_MUX_SIG[BIT_A2 ]), .OUT(ADDR[ 2]));
    PIN_FILTER u_a3    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A3 ]), .IN(CART_MUX_SIG[BIT_A3 ]), .OUT(ADDR[ 3]));
    PIN_FILTER u_a4    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A4 ]), .IN(CART_MUX_SIG[BIT_A4 ]), .OUT(ADDR[ 4]));
    PIN_FILTER u_a5    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A5 ]), .IN(CART_MUX_SIG[BIT_A5 ]), .OUT(ADDR[ 5]));
    PIN_FILTER u_a6    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A6 ]), .IN(CART_MUX_SIG[BIT_A6 ]), .OUT(ADDR[ 6]));
    PIN_FILTER u_a7    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A7 ]), .IN(CART_MUX_SIG[BIT_A7 ]), .OUT(ADDR[ 7]));
    PIN_FILTER u_a8    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A8 ]), .IN(CART_MUX_SIG[BIT_A8 ]), .OUT(ADDR[ 8]));
    PIN_FILTER u_a9    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A9 ]), .IN(CART_MUX_SIG[BIT_A9 ]), .OUT(ADDR[ 9]));
    PIN_FILTER u_a10   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A10]), .IN(CART_MUX_SIG[BIT_A10]), .OUT(ADDR[10]));
    PIN_FILTER u_a11   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A11]), .IN(CART_MUX_SIG[BIT_A11]), .OUT(ADDR[11]));
    PIN_FILTER u_a12   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A12]), .IN(CART_MUX_SIG[BIT_A12]), .OUT(ADDR[12]));
    PIN_FILTER u_a13   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A13]), .IN(CART_MUX_SIG[BIT_A13]), .OUT(ADDR[13]));
    PIN_FILTER u_a14   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A14]), .IN(CART_MUX_SIG[BIT_A14]), .OUT(ADDR[14]));
    PIN_FILTER u_a15   (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_A15]), .IN(CART_MUX_SIG[BIT_A15]), .OUT(ADDR[15]));

    /***************************************************************
     * その他の信号の取得
     ***************************************************************/
    logic RD_n;
    logic WR_n;
    logic RFSH_n;
    logic SLTSL_n;
    logic MERQ_n;
    logic IORQ_n;
    logic CLOCK;
    PIN_FILTER u_clock  (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1                ), .IN(CART_CLOCK             ), .OUT(CLOCK      ));
    PIN_FILTER u_nrd    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_RD   ]), .IN(CART_MUX_SIG[BIT_RD   ]), .OUT(RD_n       ));
    PIN_FILTER u_nwr    (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_WR   ]), .IN(CART_MUX_SIG[BIT_WR   ]), .OUT(WR_n       ));
    PIN_FILTER u_nrfsh  (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_RFSH ]), .IN(CART_MUX_SIG[BIT_RFSH ]), .OUT(RFSH_n     ));
    PIN_FILTER u_nsltsl (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_SLTSL]), .IN(CART_MUX_SIG[BIT_SLTSL]), .OUT(SLTSL_n    ));
    PIN_FILTER u_nmerq  (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_MERQ ]), .IN(CART_MUX_SIG[BIT_MERQ ]), .OUT(MERQ_n     ));
    PIN_FILTER u_niorq  (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_IORQ ]), .IN(CART_MUX_SIG[BIT_IORQ ]), .OUT(IORQ_n     ));
    PIN_FILTER u_nreset (.CLK(CLK), .RESET_n(RESET_n), .ENA(mux_active[CS_RESET]), .IN(CART_MUX_SIG[BIT_RESET]), .OUT(Bus.RESET_n));

    /***************************************************************
     * その他の信号の出力
     ***************************************************************/
    assign  CART_INT_n = !Bus.INT_n;
    assign  CART_WAIT_n = !Bus.WAIT_n;

    /***************************************************************
     * データバス
     ***************************************************************/
    logic [7:0] DIN;
    wire dir = !(!Bus.RD_n && !Bus.BUSDIR_n);
    assign  CART_BUSDIR_n = dir;
    assign  CART_DATA_SIG = dir ? 8'bZZZZ_ZZZZ : Bus.DOUT;
    PIN_FILTER u_d0_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[0]), .OUT(DIN[0]));
    PIN_FILTER u_d1_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[1]), .OUT(DIN[1]));
    PIN_FILTER u_d2_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[2]), .OUT(DIN[2]));
    PIN_FILTER u_d3_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[3]), .OUT(DIN[3]));
    PIN_FILTER u_d4_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[4]), .OUT(DIN[4]));
    PIN_FILTER u_d5_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[5]), .OUT(DIN[5]));
    PIN_FILTER u_d6_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[6]), .OUT(DIN[6]));
    PIN_FILTER u_d7_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[7]), .OUT(DIN[7]));

    /***************************************************************
     * RD_n, WR_n, CLOCK の遅延
     ***************************************************************/
    logic [9-1:0] delay_clk;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    delay_clk <= -1;
        else            delay_clk <= { CLOCK, delay_clk[$bits(delay_clk)-1:1] };
    end

    logic delay_clk2/* synthesis syn_maxfan=15 */;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    delay_clk2 <= 0;
        else            delay_clk2 <= delay_clk[1];
    end

    /***************************************************************
     * アドレスバスの更新タイミングを MERQ や IORQ 等と合わせる
     ***************************************************************/
    reg [15:0] ff_addr;
    always_ff @(posedge CLK) if(mux_active[2]) ff_addr <= ADDR;

    /***************************************************************
     * 信号を Bus I/F に出力
     ***************************************************************/
    assign Bus.ADDR    = ff_addr;
    assign Bus.DIN     = DIN;
    assign Bus.SLTSL_n = SLTSL_n;
    assign Bus.MERQ_n  = MERQ_n;
    assign Bus.IORQ_n  = IORQ_n;
    assign Bus.CS1_n   = ff_addr[15:14] != 2'b01;
    assign Bus.CS2_n   = ff_addr[15:14] != 2'b10;
    assign Bus.CS12_n  = ff_addr[15] == ff_addr[14];
    assign Bus.M1_n    = 1'b1;
    assign Bus.WR_n    = WR_n;
    assign Bus.RD_n    = RD_n;
    assign Bus.RFSH_n  = RFSH_n;

    /***************************************************************
     * CLK_EN
     ***************************************************************/
    wire curr_clk = delay_clk[0];
    logic prev_clk;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    prev_clk <= 0;
        else            prev_clk <= curr_clk;
    end

    assign Bus.CLK = curr_clk;
    assign Bus.CLK_EN = curr_clk && !prev_clk;

    /***************************************************************
     * CLK_EN(21.6MHzドメイン)
     ***************************************************************/
    assign Bus.CLK_21M = CLK_21M;   // 21.6MHz

    // 3.58MHz エッジ
    wire curr_clk_d21m;
    if(CONFIG::ENABLE_SCC == CONFIG::ENABLE_IKASCC) begin
        assign curr_clk_d21m = delay_clk2;
    end
    else begin
        assign curr_clk_d21m = delay_clk[0];
    end
    logic prev_clk_d21m;
    always_ff @(posedge CLK_21M or negedge RESET_n) begin
        if(!RESET_n)    prev_clk_d21m <= 0;
        else            prev_clk_d21m <= curr_clk_d21m;
    end

    // 3.58MHz CLK_EN
    assign Bus.CLK_EN_21M = curr_clk_d21m && !prev_clk_d21m;
endmodule

/***************************************************************
 * input filter
 ***************************************************************/
module PIN_FILTER #(
    parameter   DEFAULT = 1    
) (
    input   wire        CLK,
    input   wire        RESET_n,
    input   wire        ENA,
    input   wire        IN,
    output  reg         OUT
) /* synthesis syn_preserve=1 */;
    logic prev;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            OUT <= DEFAULT;
            prev <= DEFAULT;
        end
        else if(ENA) begin
            OUT <= (prev == IN) ? prev : OUT;
            prev <= IN;
        end
    end
endmodule

`default_nettype wire
