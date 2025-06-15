//
// cartridge_fm.sv
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
 * FM 音源カードリッジ
 ***************************************************************/
module CARTRIDGE_FM #(
    parameter               RAM_ADDR_BIOS = 0,
    parameter               RAM_ADDR_PAC = 0,
    parameter               MIRROR = 0
) (
    input   wire            RESET_n,
    CLOCK_IF.SRC            Clock,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    PAC_IF.HOST             PAC,
    SOUND_IF.OUT            Sound,
    output  wire            Output_En
);
    localparam [7:0]    IO_BASE_ADDR = 8'h7C;
    localparam [15:0]   MIO_BASE_ADDR = 16'h7FF4;

    /***************************************************************
     * メガロムコントローラ
     ***************************************************************/
    BUS_IF ExtBus[0:0]();
    PACROM_CONTROLLER #(
        .RAM_ADDR_BIOS(RAM_ADDR_BIOS),
        .RAM_ADDR_PAC(RAM_ADDR_PAC),
        .COUNT(1)
    ) u_rom (
        .RESET_n,
        .CLK(Clock.OP_CLK),
        .Bus,
        .Ram,
        .ExtBus,
        .SramEnable(PAC.SramEnable)
    );

    /***************************************************************
     * 未使用の出力信号の処理
     ***************************************************************/
    assign ExtBus[0].INT_n = 1;
    assign ExtBus[0].WAIT_n = 1;

    /***************************************************************
     * メモリリード/ライト
     ***************************************************************/
    wire    rd_mem_n = ExtBus[0].RD_n || ExtBus[0].SLTSL_n;
    wire    wr_mem_n = ExtBus[0].WR_n || ExtBus[0].SLTSL_n;

    /***************************************************************
     * リード/ライト エッジ検出
     ***************************************************************/
    reg     prev_wr_mem_n;
    wire    det_wr_mem = (prev_wr_mem_n && !wr_mem_n);
    always_ff @(posedge Clock.OP_CLK or negedge RESET_n)
    begin
        if(!RESET_n) prev_wr_mem_n <= 1;
        else         prev_wr_mem_n <= wr_mem_n;
    end

    /***************************************************************
     * アドレスデコード(7FF6h)
     ***************************************************************/
    wire cs_mem_iosw_n = (ExtBus[0].ADDR[15:2] != MIO_BASE_ADDR[15:2]) || (ExtBus[0].ADDR[1:0] != 2'b10);

    /***************************************************************
     * i/o bus switch register ライト(7FF6h の bit0 が 1 で I/O ポートを有効化)
     ***************************************************************/
    reg [7:0] iosw_reg;
    wire ena_io;
    if(MIRROR) begin
        assign ena_io = 1;
        assign Output_En = iosw_reg[0];
    end
    else begin
        assign ena_io = iosw_reg[0];
        assign Output_En = 1;
    end
    always_ff @(posedge Clock.OP_CLK or negedge RESET_n) begin
        if(!RESET_n || !ExtBus[0].RESET_n) begin
            iosw_reg <= 8'h00;
        end
        else if(det_wr_mem && !cs_mem_iosw_n) begin
            iosw_reg <= ExtBus[0].DIN;
        end
    end

    /***************************************************************
     * リード
     ***************************************************************/
    always_ff @(posedge Clock.OP_CLK or negedge RESET_n) begin
        if(!RESET_n || !ExtBus[0].RESET_n) begin
            ExtBus[0].BUSDIR_n <= 1;
            ExtBus[0].DOUT <= 0;
        end
        // INACTIVE RD_n
        else if(rd_mem_n) begin
            ExtBus[0].BUSDIR_n <= 1;
            ExtBus[0].DOUT <= 0;
        end
        // IO SWITCH(7FF6h)
        else if(!cs_mem_iosw_n) begin
            ExtBus[0].BUSDIR_n <= 0;
            ExtBus[0].DOUT <= iosw_reg;
        end
        // NO DATA
        else begin
            ExtBus[0].BUSDIR_n <= 1;
            ExtBus[0].DOUT <= 0;
        end
    end

    /***************************************************************
     * OPLL module
     ***************************************************************/
    if(CONFIG::ENABLE_FM == CONFIG::ENABLE_IKAOPLL) begin
        /***************************************************************
         * IKA OPLL
         ***************************************************************/
        wire cs_io_n = ((ExtBus[0].ADDR[7:1] != IO_BASE_ADDR[7:1]) || ExtBus[0].IORQ_n) || !ena_io;                // 7Ch~7Dh
        wire cs_mem_opll_n = (ExtBus[0].ADDR[15:1] != MIO_BASE_ADDR[15:1]) || ExtBus[0].SLTSL_n;    // 7FF4h~7FF5h

        //
        reg ff_reset_n;
        reg ff_cs_n;
        reg ff_wr_n;
        reg ff_a0;
        reg [7:0] ff_d;

        always_ff @(posedge Clock.OP_CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                ff_reset_n <= 0;
                ff_cs_n    <= 1;
                ff_wr_n    <= 1;
                ff_a0      <= 0;
                ff_d       <= 0;
            end
            else if(Clock.OP_OPLL_EN) begin
                ff_reset_n <= ExtBus[0].RESET_n;
                ff_cs_n    <= cs_io_n && cs_mem_opll_n;
                ff_wr_n    <= ExtBus[0].WR_n;
                ff_a0      <= ExtBus[0].ADDR[0];
                ff_d       <= ExtBus[0].DIN;
            end
        end

        // IKA-OPLL
        wire w_dac_stb;
        wire [15:0] w_dac_sig;
        IKAOPLL #(
            .FULLY_SYNCHRONOUS          (1'b1                       ),
            .FAST_RESET                 (1'b1                       ),
            .ALTPATCH_CONFIG_MODE       (1'b0                       ),
            .USE_PIPELINED_MULTIPLIER   (1'b1                       )
        ) u_opll (
            .i_XIN_EMUCLK               (Clock.OPLL_CLK             ),
            .o_XOUT                     (                           ),

            .i_phiM_PCEN_n              (!Clock.OPLL_4M_EN          ),

            .i_IC_n                     (ff_reset_n                 ),
            .i_ALTPATCH_EN              (1'b0                       ),

            .i_CS_n                     (ff_cs_n                    ),
            .i_WR_n                     (ff_wr_n                    ),
            .i_A0                       (ff_a0                      ),

            .i_D                        (ff_d                       ),
            .o_D                        (                           ),
            .o_D_OE                     (                           ),

            .o_DAC_EN_MO                (                           ),
            .o_DAC_EN_RO                (                           ),

            .o_IMP_NOFLUC_SIGN          (                           ),
            .o_IMP_NOFLUC_MAG           (                           ),

            .o_IMP_FLUC_SIGNED_MO       (                           ),
            .o_IMP_FLUC_SIGNED_RO       (                           ),
            .i_ACC_SIGNED_MOVOL         (5'sd2                      ),
            .i_ACC_SIGNED_ROVOL         (5'sd1                      ),
            .o_ACC_SIGNED_STRB          (w_dac_stb                  ),
            .o_ACC_SIGNED               (w_dac_sig                  )
        );

        // 音声信号取得タイミング
        reg ff_dac_stb_delay;
        always_ff @(posedge Clock.OP_CLK or negedge RESET_n) begin
            if(!RESET_n)              ff_dac_stb_delay <= 0;
            else if(Clock.OP_OPLL_EN) ff_dac_stb_delay <= w_dac_stb;
        end

        // ビットを拡張
        wire [15:0] w_dac_sig_ext = {w_dac_sig[12:0], 3'd0};

        // 音声信号を出力
        always_ff @(posedge Clock.OP_CLK or negedge RESET_n) begin
            if(!RESET_n)                                               Sound.Signal <= 0;
            else if(Clock.OP_OPLL_EN & !ff_dac_stb_delay & w_dac_stb) Sound.Signal <= w_dac_sig_ext[15:16-$bits(Sound.Signal)];
        end
    end
    else begin
        assign Sound.Signal = 0;
    end
endmodule

`default_nettype wire
