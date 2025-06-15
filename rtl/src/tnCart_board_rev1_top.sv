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

module TNCART_BOARD_REV1_TOP (
    input   wire            CLK_27M,

    // JUMPER
    input   wire            JUMPER,

    // SDRAM
    inout  wire            O_sdram_clk,
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
    CLOCK_IF Clock();
    BOARD_REV1_CLOCK u_clk (
        .RESET_n        (1'b1),
        .CART_CLOCK,
        .CLK_27M,
        .Clock
    );

    /***************************************************************
     * UART
     ***************************************************************/
    if(CONFIG_BOARD::ENABLE_UART_MODULE) begin
        UART_RX_IF RXD();
        UART_RX #(
            .CLKFREQ            (CONFIG_BOARD::OP_CLK_FREQ)
        ) u_rxd (
            .RESET_n,
            .CLK                (Clock.OP_CLK),
            .RXD                (UART_RX),
            .Uart_rx_interface  (RXD)
        );

        UART_TX_IF TXD();
        UART_TX #(
            .CLKFREQ            (CONFIG_BOARD::OP_CLK_FREQ)
        ) u_txd (
            .RESET_n,
            .CLK                (Clock.OP_CLK),
            .TXD                (UART_TX),
            .Uart_tx_interface  (TXD)
        );

        assign RXD.READ = 0;
        assign RXD.CLEAR = 0;
        assign TXD.DATA = 0;
        assign TXD.STROBE = 0;
    end
    else begin
        assign UART_TX = 1;
    end

    /***************************************************************
     * MSX バス
     ***************************************************************/
    wire RESET_n;
    BUS_IF Bus();

    // リセット信号処理
    reg reset_n = 0;
    assign RESET_n = reset_n;
    always_ff @(posedge Clock.MEM_CLK or negedge Clock.MEM_READY or negedge sdram_ready) begin
        if(!Clock.MEM_READY) reset_n <= 0;       // PLL 準備中ならリセット
        else if(!sdram_ready) reset_n <= 0;     // SDRAM 準備中ならリセット
        else reset_n <= 1; 
    end

    // バス信号処理
    BOARD_REV1_BUS u_bus (
        .RESET_n,
        .CLK(Clock.MEM_CLK),
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

    /***************************************************************
     * SDRAM
     ***************************************************************/
    RAM_IF Ram[0:CONFIG::RAM_COUNT-1]();
    logic sdram_ready;
    wire [23:0] sdram_address_offset[0:CONFIG::RAM_COUNT-1];
    assign sdram_address_offset[CONFIG::RAM_MEGAROM   ] = 24'h0;
    assign sdram_address_offset[CONFIG::RAM_FMPAC     ] = 24'h0;
    assign sdram_address_offset[CONFIG::RAM_NEXTOR    ] = 24'h0;
    assign sdram_address_offset[CONFIG::RAM_EXPRAM    ] = 24'h0;
    assign sdram_address_offset[CONFIG::RAM_BOOTLOADER] = 24'h0;
    assign sdram_address_offset[CONFIG::RAM_V9990     ] = CONFIG::RAM_ADDR_VRAM;

    SDRAM #(
        .COUNT              (CONFIG::RAM_COUNT),
        .SDRAM_A_WIDTH      (11),
        .SDRAM_BA_WIDTH     (2),
        .SDRAM_COL_WIDTH    (8),
        .SDRAM_ROW_WIDTH    (11),
        .SDRAM_DQ_WIDTH     (32)
    ) u_sdram (
        .CLK                (Clock.MEM_CLK),
        .RESET_n            (Clock.MEM_READY),

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

        .OFFSET             (sdram_address_offset),
        .Ram                (Ram)
    );

    /***************************************************************
     * TF
     ***************************************************************/
    SPI_IF TF();
    SPI #(
        .CLK_DIV        (CONFIG_BOARD::TF_CLK_DIV)
    ) u_tf_spi (
        .CLK            (Clock.OP_CLK),
        .RESET_n,
        .SCLK           (TF_SCLK),
        .MOSI           (TF_CMD),
        .MISO           (TF_DAT0),
        .CS_n           (TF_DAT3),
        .SPI_Interface  (TF)
    );

    // 未使用ピンの処理
    assign TF_DAT1 = 1'bZ;
    assign TF_DAT2 = 1'bZ;

    /***************************************************************
     * FLASH
     ***************************************************************/
    FLASH_IF Flash();
    FLASH_SPI u_flash (
        .RESET_n,
        .CLK                (Clock.OP_CLK),
        .SPI                (Flash_SPI),
        .Flash              (Flash)
    );

    SPI_IF #(
        .MOSI_BIT_WIDTH(Flash.ADDR_WIDTH+8)
    ) Flash_SPI();
    SPI #(
        .CLK_DIV            (CONFIG_BOARD::FLASH_CLK_DIV)
    ) u_flash_spi (
        .RESET_n,
        .CLK                (Clock.OP_CLK),
        .SCLK               (mspi_sclk),
        .MOSI               (mspi_mosi),
        .MISO               (mspi_miso),
        .CS_n               (mspi_cs),
        .SPI_Interface      (Flash_SPI)
    );

    // 未使用ピンの処理
    assign mspi_hold = 1;

    /***************************************************************
     * LED
     ***************************************************************/
    LED_IF LedNextor();
    LED_IF LedBoot();
    LED #(
        .DELAY          (CONFIG_BOARD::LED_CLK_FREQ / 2),
        .BLINK          (CONFIG_BOARD::LED_CLK_FREQ / 20)
    ) u_led (
        .Clock,
        .RESET_n,
        .LedPort        (LED),
        .LedNextor,
        .LedBoot
    );

    /***************************************************************
     * cartridge sound out
     ***************************************************************/
    SOUND_IF #(.BIT_WIDTH(CONFIG_BOARD::DAC_BIT_WIDTH)) SoundInternal();
    DAC_1BIT u_dac_int (
        .CLK            (Clock.DAC_CLK),
        .CLK_EN         (Clock.DAC_ENA),
        .RESET_n,
        .IN             (SoundInternal),
        .OUT            (SOUND_INT)
    );

    /***************************************************************
     * external sound out
     ***************************************************************/
    SOUND_IF #(.BIT_WIDTH(CONFIG_BOARD::DAC_BIT_WIDTH)) SoundExternal[0:0]();
    DAC_1BIT u_dac_ext (
        .CLK            (Clock.DAC_CLK),
        .CLK_EN         (Clock.DAC_ENA),
        .RESET_n,
        .IN             (SoundExternal[0]),
        .OUT            (SOUND_EXT)
    );

    /***************************************************************
     * VIDEO
     ***************************************************************/
    VIDEO_IF Video();
    VIDEO_IF VideoTmds();
    VIDEO_UPSCAN #(
        .ENABLE_SCANLINE(CONFIG::ENABLE_SCANLINE)
    ) u_upscan (
        .RESET_n,
        .DCLK           (Clock.TMDS_P_CLK),
        .IN             (Video),
        .OUT            (VideoTmds)
    );

    BOARD_REV1_TMDS_OUT u_tmds (
        .RESET_n,
        .IN             (VideoTmds),
        .TMDS_READY     (Clock.TMDS_READY),
        .CLK_S          (Clock.TMDS_S_CLK),
        .CLK_P          (Clock.TMDS_P_CLK),
        .TMDS_CLKP      (tmds_clk_p),
        .TMDS_CLKN      (tmds_clk_n),
        .TMDS_DATAP     (tmds_data_p),
        .TMDS_DATAN     (tmds_data_n)
    );

    /***************************************************************
     * MAIN
     ***************************************************************/
    MAIN #(
        .RAM_COUNT      (CONFIG::RAM_COUNT),
        .RAM_MEGAROM    (CONFIG::RAM_MEGAROM),
        .RAM_FMPAC      (CONFIG::RAM_FMPAC),
        .RAM_NEXTOR     (CONFIG::RAM_NEXTOR),
        .RAM_EXPRAM     (CONFIG::RAM_EXPRAM),
        .RAM_BOOTLOADER (CONFIG::RAM_BOOTLOADER),
        .RAM_V9990      (CONFIG::RAM_V9990)
    ) u_main (
        .RESET_n,
        .Clock,
        .Bus,
        .Ram,
        .TF,
        .LedNextor,
        .Flash,
        .LedBoot,
        .Video,
        .SoundInternal,
        .SoundExternal
    );

endmodule


`default_nettype wire
