//
// tnCart_board_rev1_top.sv
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

localparam DEBUG = 0;
localparam BUS_SIM = 0;

module TNCART_BOARD_REV1_TOP (
    input   wire            CLK_27M,

    // JUMPER
    input   wire            JUMPER,

    // SDRAM
    output  wire            O_sdram_clk,
    output  wire            O_sdram_cke,
    output  wire            O_sdram_cs_n,
    output  wire            O_sdram_cas_n,
    output  wire            O_sdram_ras_n,
    output  wire            O_sdram_wen_n,
    inout   wire    [31:0]  IO_sdram_dq,
    output  wire    [10:0]  O_sdram_addr,
    output  wire    [1:0]   O_sdram_ba,
    output  wire    [3:0]   O_sdram_dqm,

    // BUS
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

    // SOUND
    output  wire            SOUND_INT,
    output  wire            SOUND_EXT,

    // LED
    output  wire            LED,

    // TMDS
    output wire             tmds_clk_p,
    output wire             tmds_clk_n,
    output wire    [2:0]    tmds_data_p,
    output wire    [2:0]    tmds_data_n,

    // SPI FLASH
    output  wire            mspi_cs,
    output  wire            mspi_sclk,
    input   wire            mspi_miso,
    output  wire            mspi_mosi,
    output  wire            mspi_hold,

    // TF
    output  wire            TF_SCLK,    // SCLK
    output  wire            TF_CMD,     // MOSI
    input   wire            TF_DAT0,    // MISO
    inout   wire            TF_DAT1,    // NC
    inout   wire            TF_DAT2,    // NC
    inout   wire            TF_DAT3,    // CS_n

    // UART
    input   wire            UART_RX,
    output  wire            UART_TX
);
    /***************************************************************
     * CLOCK
     ***************************************************************/
    logic CLK_BASE;
    logic CLK_BASE_READY;
    logic CLK_MEM;
    logic CLK_MEM_P;
    logic CLK_MEM_READY;
    logic CLK_TMDS_S;
    logic CLK_TMDS_P;
    logic CLK_TMDS_READY;
    logic CLK_21M;
    logic CLK_14M;
    BOARD_REV1_CLOCK u_clk (
        .RESET_n        (1'b1),
        .CLK_27M,
        .CLK_BASE,
        .CLK_BASE_READY,
        .CLK_MEM,
        .CLK_MEM_P,
        .CLK_MEM_READY,
        .CLK_TMDS_S,
        .CLK_TMDS_P,
        .CLK_TMDS_READY,
        .CLK_21M,
        .CLK_14M
    );

    /***************************************************************
     * UART
     ***************************************************************/
    UART_RX_IF RXD();
    UART_RX #(
        .CLKFREQ(108_000_000)
    ) u_rxd (
        .RESET_n,
        .CLK,
        .RXD(UART_RX),
        .Uart_rx_interface(RXD)
    );

    UART_TX_IF TXD();
    UART_TX #(
        .CLKFREQ(108_000_000)
    ) u_txd (
        .RESET_n,
        .CLK,
        .TXD(UART_TX),
        .Uart_tx_interface(TXD)
    );

    /***************************************************************
     * MSX バス
     ***************************************************************/
    wire RESET_n;
    wire CLK = CLK_BASE;
    BUS_IF Bus();
    if(DEBUG) begin
        assign RESET_n = CLK_BASE_READY && sdram_ready && RESET_OUT_n;
        BUS_IF BusMsx();
        if(BUS_SIM) begin
            DEBUGGER_BUS_SIM u_bus (
                .RESET_n,
                .CLK,
                .CLK_21M,
                .Bus(BusMsx)
            );
            BUS_IF BusDummy();
            BOARD_REV1_BUS u_bus_dmy (
                .RESET_n,
                .CLK,
                .CLK_21M,
                .CART_BUSDIR_n,
                .CART_INT_n,
                .CART_WAIT_n,
                .CART_SLTSL_n,
                .CART_RD_n,
                .CART_WR_n,
                .CART_CLOCK,
                .CART_MUX_SIG,
                .CART_MUX_CS_n,
                .CART_DATA_SIG,
                .CART_DATA_DIR,
                .Bus(BusDummy)
            );
            assign BusDummy.DOUT = 0;
            assign BusDummy.BUSDIR_n = 1;
            assign BusDummy.INT_n = 1;
            assign BusDummy.WAIT_n = 1;
        end
        else begin
            BOARD_REV1_BUS u_bus (
                .RESET_n,
                .CLK,
                .CLK_21M,
                .CART_BUSDIR_n,
                .CART_INT_n,
                .CART_WAIT_n,
                .CART_SLTSL_n,
                .CART_RD_n,
                .CART_WR_n,
                .CART_CLOCK,
                .CART_MUX_SIG,
                .CART_MUX_CS_n,
                .CART_DATA_SIG,
                .CART_DATA_DIR,
                .Bus(BusMsx)
            );
        end
        logic RESET_OUT_n;
        DEBUGGER u_dbg (
            .RESET_n,
            .CLK,
            .IN(BusMsx),
            .OUT(Bus),
            .RESET_OUT_n,
            .TXD,
            .RXD
        );
    end
    else begin
        assign RESET_n = CLK_BASE_READY && sdram_ready;
        BOARD_REV1_BUS u_bus (
            .RESET_n,
            .CLK,
            .CLK_21M,
            .CART_BUSDIR_n,
            .CART_INT_n,
            .CART_WAIT_n,
            .CART_SLTSL_n,
            .CART_RD_n,
            .CART_WR_n,
            .CART_CLOCK,
            .CART_MUX_SIG,
            .CART_MUX_CS_n,
            .CART_DATA_SIG,
            .CART_DATA_DIR,
            .Bus
        );
    end

    /***************************************************************
     * SDRAM
     ***************************************************************/
    RAM_IF Ram();
    logic sdram_ready;
    SDRAM #(
        .SDRAM_A_WIDTH(11),
        .SDRAM_BA_WIDTH(2),
        .SDRAM_COL_WIDTH(8),
        .SDRAM_ROW_WIDTH(11),
        .SDRAM_DQ_WIDTH(32)
    ) u_sdram (
        .CLK                (CLK_MEM),
        .CLK_PS             (CLK_MEM_P),
        .RESET_n            (CLK_MEM_READY),

        .READY              (sdram_ready),

        .SDRAM_CLK          (O_sdram_clk),
        .SDRAM_CKE          (O_sdram_cke),
        .SDRAM_CS_n         (O_sdram_cs_n),
        .SDRAM_RAS_n        (O_sdram_ras_n),
        .SDRAM_CAS_n        (O_sdram_cas_n),
        .SDRAM_WE_n         (O_sdram_wen_n),
        .SDRAM_A            (O_sdram_addr),
        .SDRAM_BA           (O_sdram_ba),
        .SDRAM_DQM          (O_sdram_dqm),
        .SDRAM_DQ           (IO_sdram_dq),

        .Ram
    );

    /***************************************************************
     * UMA
     ***************************************************************/
    UMA_IF Uma();
    assign Uma.ADDR[0] = 0;
    assign Uma.ADDR[1] = 24'h780000;

    RAM_IF UmaRam[0:Uma.COUNT-1]();

    if(CONFIG::ENABLE_UMA) begin
        UMA #(
            .COUNT(Uma.COUNT),
            .DIV(30)                // 108MHz/3.58MHz = 30
        ) u_uma (
            .RESET_n,
            .CLK,
            .CLK_EN(Bus.CLK_EN),
            .Primary(Ram),
            .Secondary(UmaRam),
            .Uma
        );
    end
    else begin
        BYPASS_RAM u_bypass_uma (
            .Primary(Ram),
            .Secondary(UmaRam[0])
        );
    end

    assign UmaRam[1].ADDR = 0;
    assign UmaRam[1].OE_n = 1;
    assign UmaRam[1].WE_n = 1;
    assign UmaRam[1].RFSH_n = 1;
    assign UmaRam[1].DIN = 0;
    assign UmaRam[1].DIN_SIZE = 0;

    /***************************************************************
     * TF
     ***************************************************************/
    SPI_IF TF();
    SPI #(
        .CLK_DIV        (2'd2)      // 108 / 2 / (2+1) = 18MHz
    ) u_tf_spi (
        .CLK,
        .RESET_n,
        .SCLK           (TF_SCLK),
        .MOSI           (TF_CMD),
        .MISO           (TF_DAT0),
        .CS_n           (TF_DAT3),
        .SPI_Interface  (TF)
    );
    assign TF_DAT1 = 1'bZ;
    assign TF_DAT2 = 1'bZ;

    /***************************************************************
     * FLASH
     ***************************************************************/
    FLASH_IF Flash();
    FLASH_SPI u_flash (
        .RESET_n,
        .CLK,
        .SPI                (Flash_SPI),
        .Flash              (Flash)
    );

    SPI_IF #(
        .MOSI_BIT_WIDTH(Flash.ADDR_WIDTH+8)
    ) Flash_SPI();
    SPI #(
        .CLK_DIV            (2'd2)  // 108 / 2 / (2+1) = 18MHz
    ) u_flash_spi (
        .RESET_n,
        .CLK,
        .SCLK               (mspi_sclk),
        .MOSI               (mspi_mosi),
        .MISO               (mspi_miso),
        .CS_n               (mspi_cs),
        .SPI_Interface      (Flash_SPI)
    );
    assign mspi_hold = 1;

    /***************************************************************
     * LED
     ***************************************************************/
    LED_IF LedNextor();
    LED_IF LedBoot();
    LED #(
        .DELAY          (108_000_000 / 2),
        .BLINK          (108_000_000 / 20)
    ) u_led (
        .CLK,
        .RESET_n,
        .LedPort        (LED),
        .LedNextor,
        .LedBoot
    );

    /***************************************************************
     * cartridge sound out
     ***************************************************************/
    SOUND_IF SoundInternal();
    DAC_1BIT u_dac_int (
        .CLK,
        .RESET_n,
        .IN             (SoundInternal),
        .OUT            (SOUND_INT)
    );

    /***************************************************************
     * external sound out
     ***************************************************************/
    SOUND_IF SoundExternal();
    DAC_1BIT u_dac_ext (
        .CLK,
        .RESET_n,
        .IN             (SoundExternal),
        .OUT            (SOUND_EXT)
    );

    /***************************************************************
     * VIDEO
     ***************************************************************/
    VIDEO_IF Video();
    VIDEO_DUMMY u_video (
        .RESET_n,
        .CLK,
        .CLK_27M,
        .CLK_21M,
        .CLK_14M,
        .RESOLUTION(VIDEO::RESOLUTION_B3),
        .OUT(Video)
    );

    VIDEO_IF VideoTmds();
    VIDEO_UPSCAN u_upscan (
        .RESET_n,
        .DCLK(CLK_TMDS_P),
        .IN(Video),
        .OUT(VideoTmds)
    );

    BOARD_REV1_TMDS_OUT u_tmds (
        .RESET_n,
        .IN(VideoTmds),
        .TMDS_READY(CLK_TMDS_READY),
        .CLK_S(CLK_TMDS_S),
        .CLK_P(CLK_TMDS_P),
        .TMDS_CLKP(tmds_clk_p),
        .TMDS_CLKN(tmds_clk_n),
        .TMDS_DATAP(tmds_data_p),
        .TMDS_DATAN(tmds_data_n)
    );

    /***************************************************************
     * MAIN
     ***************************************************************/
    MAIN u_main (
        .RESET_n,
        .CLK,
        .Bus,
        .Ram(UmaRam[0]),
        .TF,
        .LedNextor,
        .Flash,
        .LedBoot,
        .SoundInternal,
        .SoundExternal
    );

endmodule


`default_nettype wire
