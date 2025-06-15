//
// board_rev1_bus.sv
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
module BOARD_REV1_BUS (
    input wire              RESET_n,
    input wire              CLK,

    output  wire            CART_BUSDIR_n,
    output  wire            CART_INT_n,
    output  wire            CART_WAIT_n,
    input   wire            CART_SLTSL_n,
    input   wire            CART_RD_n,
    input   wire            CART_WR_n,
    input   wire            CART_CLOCK,
    input   wire    [7:0]   CART_MUX_SIG,
    output  wire    [2:0]   CART_MUX_CS_n,
    inout   wire    [7:0]   CART_DATA_SIG,
    output  wire            CART_DATA_DIR,

    BUS_IF.MSX              Bus
);
    localparam  SCAN_ORDER_0 = 0;
    localparam  SCAN_ORDER_1 = 1;
    localparam  SCAN_ORDER_2 = 2;

    localparam DLY = 2;     // バッファの遅延時間(9.7nsec)

    assign Bus.CLK = w_bus_clock;

    /***************************************************************
     * ポートアサイン
     ***************************************************************/
    // スキャン順序の定義
    localparam  CS_MSEL2    = SCAN_ORDER_0;
    localparam  CS_MSEL0    = SCAN_ORDER_1;
    localparam  CS_MSEL1    = SCAN_ORDER_2;

    // ポート割り当て定義
    localparam  CS_MERQ     = CS_MSEL2,    BIT_MERQ    = 0;
    localparam  CS_IORQ     = CS_MSEL2,    BIT_IORQ    = 1;
    localparam  CS_CS1      = CS_MSEL2,    BIT_CS1     = 2;
    localparam  CS_CS2      = CS_MSEL2,    BIT_CS2     = 3;
    localparam  CS_RESET    = CS_MSEL2,    BIT_RESET   = 4;
    localparam  CS_RFSH     = CS_MSEL2,    BIT_RFSH    = 5;
    localparam  CS_CS12     = CS_MSEL2,    BIT_CS12    = 6;
    localparam  CS_M1       = CS_MSEL2,    BIT_M1      = 7;
    localparam  CS_A8       = CS_MSEL0,    BIT_A8      = 0;
    localparam  CS_A9       = CS_MSEL0,    BIT_A9      = 1;
    localparam  CS_A10      = CS_MSEL0,    BIT_A10     = 2;
    localparam  CS_A11      = CS_MSEL0,    BIT_A11     = 3;
    localparam  CS_A12      = CS_MSEL0,    BIT_A12     = 4;
    localparam  CS_A13      = CS_MSEL0,    BIT_A13     = 5;
    localparam  CS_A14      = CS_MSEL0,    BIT_A14     = 6;
    localparam  CS_A15      = CS_MSEL0,    BIT_A15     = 7;
    localparam  CS_A0       = CS_MSEL1,    BIT_A0      = 0;
    localparam  CS_A1       = CS_MSEL1,    BIT_A1      = 1;
    localparam  CS_A2       = CS_MSEL1,    BIT_A2      = 2;
    localparam  CS_A3       = CS_MSEL1,    BIT_A3      = 3;
    localparam  CS_A4       = CS_MSEL1,    BIT_A4      = 4;
    localparam  CS_A5       = CS_MSEL1,    BIT_A5      = 5;
    localparam  CS_A6       = CS_MSEL1,    BIT_A6      = 6;
    localparam  CS_A7       = CS_MSEL1,    BIT_A7      = 7;

    // バッファ IC の OE ピンの定義
    assign CART_MUX_CS_n[2] = w_mux_cs[CS_MSEL2];
    assign CART_MUX_CS_n[1] = w_mux_cs[CS_MSEL1];
    assign CART_MUX_CS_n[0] = w_mux_cs[CS_MSEL0];

    /***************************************************************
     * バススキャン開始/停止条件
     ***************************************************************/
    // メモリ read/write/refresh
    wire w_mem_rd_n = w_bus_rd_n | w_bus_sltsl_n;   //CART_RD_n | CART_SLTSL_n;
    wire w_mem_wr_n = w_bus_wr_n | w_bus_sltsl_n;   //CART_WR_n | CART_SLTSL_n;
    wire w_mem_rfsh_n = w_bus_rfsh_n;               //CART_MUX_SIG[BIT_RFSH];

    // I/O read/write
    wire w_io_rd_n = w_bus_rd_n | w_bus_iorq_n;     //CART_RD_n | CART_MUX_SIG[BIT_IORQ];
    wire w_io_wr_n = w_bus_wr_n | w_bus_iorq_n;     //CART_WR_n | CART_MUX_SIG[BIT_IORQ];

    // リセット信号
    wire w_reset_n = w_bus_reset_n;                 //CART_MUX_SIG[BIT_RESET];

    //
    reg ff_curr_mem_rd_n;
    reg ff_curr_mem_wr_n;
    reg ff_curr_mem_rfsh_n;
    reg ff_curr_io_rd_n;
    reg ff_curr_io_wr_n;

    // w_rd_n/w_wr_n/w_rfsh_n/w_reset_n の変化を検出
    wire w_change_mem_rd = (w_mem_rd_n ^ ff_curr_mem_rd_n);// | (~w_mem_rd_n);
    wire w_change_mem_wr = (w_mem_wr_n ^ ff_curr_mem_wr_n);// | (~w_mem_wr_n);
    wire w_change_io_rd = (w_io_rd_n ^ ff_curr_io_rd_n);// | (~w_io_rd_n);
    wire w_change_io_wr = (w_io_wr_n ^ ff_curr_io_wr_n);// | (~w_io_wr_n);
    wire w_change_rfsh = w_mem_rfsh_n ^ ff_curr_mem_rfsh_n;
    wire w_change_reset = w_reset_n ^ Bus.RESET_n;

    /***************************************************************
     * バススキャン処理
     ***************************************************************/
    localparam  STATE_COUNT = (DLY*3);

    // スキャン開始条件
    wire w_scan_start = ff_scan_state[0] & (w_change_mem_rd | w_change_io_rd | w_change_mem_wr | w_change_io_wr | w_change_rfsh | w_change_reset);

    // スキャン動作
    wire w_scan_running = ~ff_scan_state[0];

    // BUS I/F 更新条件
    wire w_bus_if_update = w_fetch_enable[SCAN_ORDER_2];//ff_scan_state[STATE_COUNT - 1];

    reg [STATE_COUNT-1:0] ff_scan_state;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                           ff_scan_state <= 2'b01;
        else if(w_scan_start | w_scan_running) ff_scan_state <= { ff_scan_state[STATE_COUNT - 2:0], ff_scan_state[STATE_COUNT - 1] };
    end

    /***************************************************************
     * マルチプレクサ切り替え
     ***************************************************************/
    reg [2:0] w_mux_cs;
    if(1) begin
        wire w_mux_change = w_scan_start | ff_scan_state[DLY*1] | ff_scan_state[DLY*2];
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)          w_mux_cs <= 3'b110;
            else if(w_mux_change) w_mux_cs <= { w_mux_cs[$bits(w_mux_cs)-2:0], w_mux_cs[$bits(w_mux_cs)-1] };
        end
    end
    else begin
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                  w_mux_cs <= 3'b110;
            else if(w_scan_start)         w_mux_cs <= 3'b101;
            else if(ff_scan_state[DLY*1]) w_mux_cs <= 3'b011;
            else if(ff_scan_state[DLY*2]) w_mux_cs <= 3'b110;
        end
    end

    /***************************************************************
     * 信号取り込み許可
     ***************************************************************/
    wire [2:0] w_fetch_enable;
    assign w_fetch_enable[SCAN_ORDER_0] = ff_scan_state[DLY*0];
    assign w_fetch_enable[SCAN_ORDER_1] = ff_scan_state[DLY*1];
    assign w_fetch_enable[SCAN_ORDER_2] = ff_scan_state[DLY*2];

    /***************************************************************
     * Bus I/F の更新
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.ADDR[15:8]    <= 8'hFF;
            Bus.DIN     <= 8'hFF;
            Bus.SLTSL_n <= 1;
            Bus.IORQ_n  <= 1;
            Bus.RD_n    <= 1;
            Bus.WR_n    <= 1;
            Bus.RFSH_n  <= 1;
            Bus.RESET_n <= 1;

            ff_curr_mem_rd_n <= 1;
            ff_curr_mem_wr_n <= 1;
            ff_curr_mem_rfsh_n <= 1;
            ff_curr_io_rd_n = 1;
            ff_curr_io_wr_n = 1;
        end
        else if(w_bus_if_update) begin
            Bus.ADDR[15:8]    <= w_bus_addr[15:8];
            Bus.DIN     <= w_bus_din;
            Bus.SLTSL_n <= w_bus_sltsl_n;
            Bus.IORQ_n  <= w_bus_iorq_n;
            Bus.RD_n    <= w_bus_rd_n;
            Bus.WR_n    <= w_bus_wr_n;
            Bus.RFSH_n  <= w_bus_rfsh_n;
            Bus.RESET_n <= w_bus_reset_n;

            ff_curr_mem_rd_n <= w_bus_rd_n | w_bus_sltsl_n;
            ff_curr_mem_wr_n <= w_bus_wr_n | w_bus_sltsl_n;
            ff_curr_mem_rfsh_n <= w_bus_rfsh_n;
            ff_curr_io_rd_n = w_bus_rd_n | w_bus_iorq_n;
            ff_curr_io_wr_n = w_bus_wr_n | w_bus_iorq_n;
        end
    end

    assign Bus.ADDR[0] = w_bus_addr[0];
    assign Bus.ADDR[1] = w_bus_addr[1];
    assign Bus.ADDR[2] = w_bus_addr[2];
    assign Bus.ADDR[3] = w_bus_addr[3];
    assign Bus.ADDR[4] = w_bus_addr[4];
    assign Bus.ADDR[5] = w_bus_addr[5];
    assign Bus.ADDR[6] = w_bus_addr[6];
    assign Bus.ADDR[7] = w_bus_addr[7];

    /***************************************************************
     * アドレスバスの取得
     ***************************************************************/
    wire [15:0] w_bus_addr;
    PIN_FILTER u_a0    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A0 ]), .IN(CART_MUX_SIG[BIT_A0 ]), .OUT(w_bus_addr[ 0]));
    PIN_FILTER u_a1    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A1 ]), .IN(CART_MUX_SIG[BIT_A1 ]), .OUT(w_bus_addr[ 1]));
    PIN_FILTER u_a2    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A2 ]), .IN(CART_MUX_SIG[BIT_A2 ]), .OUT(w_bus_addr[ 2]));
    PIN_FILTER u_a3    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A3 ]), .IN(CART_MUX_SIG[BIT_A3 ]), .OUT(w_bus_addr[ 3]));
    PIN_FILTER u_a4    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A4 ]), .IN(CART_MUX_SIG[BIT_A4 ]), .OUT(w_bus_addr[ 4]));
    PIN_FILTER u_a5    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A5 ]), .IN(CART_MUX_SIG[BIT_A5 ]), .OUT(w_bus_addr[ 5]));
    PIN_FILTER u_a6    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A6 ]), .IN(CART_MUX_SIG[BIT_A6 ]), .OUT(w_bus_addr[ 6]));
    PIN_FILTER u_a7    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A7 ]), .IN(CART_MUX_SIG[BIT_A7 ]), .OUT(w_bus_addr[ 7]));
    PIN_FILTER u_a8    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A8 ]), .IN(CART_MUX_SIG[BIT_A8 ]), .OUT(w_bus_addr[ 8]));
    PIN_FILTER u_a9    (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A9 ]), .IN(CART_MUX_SIG[BIT_A9 ]), .OUT(w_bus_addr[ 9]));
    PIN_FILTER u_a10   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A10]), .IN(CART_MUX_SIG[BIT_A10]), .OUT(w_bus_addr[10]));
    PIN_FILTER u_a11   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A11]), .IN(CART_MUX_SIG[BIT_A11]), .OUT(w_bus_addr[11]));
    PIN_FILTER u_a12   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A12]), .IN(CART_MUX_SIG[BIT_A12]), .OUT(w_bus_addr[12]));
    PIN_FILTER u_a13   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A13]), .IN(CART_MUX_SIG[BIT_A13]), .OUT(w_bus_addr[13]));
    PIN_FILTER u_a14   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A14]), .IN(CART_MUX_SIG[BIT_A14]), .OUT(w_bus_addr[14]));
    PIN_FILTER u_a15   (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_A15]), .IN(CART_MUX_SIG[BIT_A15]), .OUT(w_bus_addr[15]));

    /***************************************************************
     * その他の信号の取得
     ***************************************************************/
    wire w_bus_sltsl_n;
    wire w_bus_iorq_n;
    wire w_bus_rd_n;
    wire w_bus_wr_n;
    wire w_bus_rfsh_n;
    wire w_bus_reset_n;
    wire w_bus_clock;
    PIN_FILTER u_nsltsl (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1                    ), .IN(CART_SLTSL_n           ), .OUT(w_bus_sltsl_n));
    PIN_FILTER u_nrd    (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1                    ), .IN(CART_RD_n              ), .OUT(w_bus_rd_n   ));
    PIN_FILTER u_nwr    (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1                    ), .IN(CART_WR_n              ), .OUT(w_bus_wr_n  ));
    PIN_FILTER u_niorq  (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_IORQ ]), .IN(CART_MUX_SIG[BIT_IORQ ]), .OUT(w_bus_iorq_n ));
    PIN_FILTER u_nreset (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_RESET]), .IN(CART_MUX_SIG[BIT_RESET]), .OUT(w_bus_reset_n));
    PIN_FILTER u_nrfsh  (.CLK(CLK), .RESET_n(RESET_n), .ENA(w_fetch_enable[CS_RFSH ]), .IN(CART_MUX_SIG[BIT_RFSH ]), .OUT(w_bus_rfsh_n ));
    PIN_FILTER u_clock  (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1                    ), .IN(CART_CLOCK             ), .OUT(w_bus_clock  ));

    /***************************************************************
     * データバス
     ***************************************************************/
    wire [7:0] w_bus_din;
    wire dir = !(/*!CART_RD_n &&*/ !Bus.BUSDIR_n);
    assign  CART_DATA_DIR = dir;
    assign  CART_BUSDIR_n = dir;
    assign  CART_DATA_SIG = dir ? 8'bZZZZ_ZZZZ : Bus.DOUT;
    PIN_FILTER u_d0_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[0]), .OUT(w_bus_din[0]));
    PIN_FILTER u_d1_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[1]), .OUT(w_bus_din[1]));
    PIN_FILTER u_d2_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[2]), .OUT(w_bus_din[2]));
    PIN_FILTER u_d3_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[3]), .OUT(w_bus_din[3]));
    PIN_FILTER u_d4_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[4]), .OUT(w_bus_din[4]));
    PIN_FILTER u_d5_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[5]), .OUT(w_bus_din[5]));
    PIN_FILTER u_d6_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[6]), .OUT(w_bus_din[6]));
    PIN_FILTER u_d7_in (.CLK(CLK), .RESET_n(RESET_n), .ENA(1'b1), .IN(CART_DATA_SIG[7]), .OUT(w_bus_din[7]));

    /***************************************************************
     * その他の信号の出力
     ***************************************************************/
    if(CONFIG_BOARD::BOARD_ID == BOARD_ID::WonderTANG_101c) begin
        assign  CART_INT_n = Bus.INT_n;
    end
    else begin
        assign  CART_INT_n = !Bus.INT_n;
    end
    assign  CART_WAIT_n = !Bus.WAIT_n;

    /***************************************************************
     * 信号の取り込み
     ***************************************************************/
    module PIN_FILTER #(
        parameter   DEFAULT = 1    
    ) (
        input   wire        CLK,
        input   wire        RESET_n,
        input   wire        ENA,
        input   wire        IN,
        output  wire        OUT
    ) /* synthesis syn_preserve=1 */;

        reg ff_delay;

        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) ff_delay <= DEFAULT;
            else if(ENA) ff_delay <= IN;
        end

        assign OUT = ff_delay;

    endmodule

endmodule

`default_nettype wire
