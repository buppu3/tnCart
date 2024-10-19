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
    input   wire            CLK,
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
        .COUNT(1),
        .USE_FF(0)
    ) u_rom (
        .RESET_n,
        .CLK,
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
    wire    rd_mem_n = ExtBus[0].RD_n || ExtBus[0].SLTSL_n || ExtBus[0].MERQ_n;
    wire    wr_mem_n = ExtBus[0].WR_n || ExtBus[0].SLTSL_n || ExtBus[0].MERQ_n;

    /***************************************************************
     * リード/ライト エッジ検出
     ***************************************************************/
    reg     prev_wr_mem_n;
    wire    det_wr_mem = (prev_wr_mem_n && !wr_mem_n);
    always_ff @(posedge CLK or negedge RESET_n)
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
    always_ff @(posedge CLK or negedge RESET_n) begin
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
    always_ff @(posedge CLK or negedge RESET_n) begin
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
        // NO DATA AREA
        else begin
            ExtBus[0].BUSDIR_n <= 1;
            ExtBus[0].DOUT <= 0;
        end
    end

if(CONFIG::ENABLE_FM == CONFIG::ENABLE_IKAOPLL) begin
    /***************************************************************
     * IKA OPLL
     ***************************************************************/
    wire cs_io_n = ((ExtBus[0].ADDR[7:1] != IO_BASE_ADDR[7:1]) || ExtBus[0].IORQ_n) || !ena_io;                // 7Ch~7Dh
    wire cs_mem_opll_n = (ExtBus[0].ADDR[15:1] != MIO_BASE_ADDR[15:1]) || ExtBus[0].MERQ_n || ExtBus[0].SLTSL_n;    // 7FF4h~7FF5h

    wire dac_stb;
    wire [15:0] dac_sig;

    IKAOPLL #(
        .FULLY_SYNCHRONOUS          (1'b1                       ),
        .FAST_RESET                 (1'b1                       ),
        .ALTPATCH_CONFIG_MODE       (1'b0                       ),
        .USE_PIPELINED_MULTIPLIER   (1'b1                       )
    ) u_opll (
        .i_XIN_EMUCLK               (ExtBus[0].CLK_21M          ),
        .o_XOUT                     (                           ),

        .i_phiM_PCEN_n              (!ExtBus[0].CLK_EN_21M      ),

        .i_IC_n                     (ExtBus[0].RESET_n          ),
        .i_ALTPATCH_EN              (1'b0                       ),

        .i_CS_n                     (cs_io_n && cs_mem_opll_n   ),
        .i_WR_n                     (ExtBus[0].WR_n             ),
        .i_A0                       (ExtBus[0].ADDR[0]          ),

        .i_D                        (ExtBus[0].DIN              ),
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
        .o_ACC_SIGNED_STRB          (dac_stb                    ),
        .o_ACC_SIGNED               (dac_sig                    )
    );

/*
    always_ff @(posedge dac_stb or negedge RESET_n) begin
        if(!RESET_n) begin
            Sound.Signal <= 0;
        end
        else begin
            Sound.Signal <= dac_sig[12:3];
        end
    end
*/
    reg dac_stb_delay;
    always_ff @(posedge Bus.CLK_21M) dac_stb_delay <= dac_stb;

    wire [15:0] dac_sig_ext = {dac_sig[12:0], 3'd0};

    always_ff @(posedge Bus.CLK_21M or negedge RESET_n) begin
        if(!RESET_n) begin
            Sound.Signal <= 0;
        end
        else if(!dac_stb_delay && dac_stb) begin
            Sound.Signal <= dac_sig_ext[15:16-$bits(Sound.Signal)];
        end
    end

end
else if(CONFIG::ENABLE_FM == CONFIG::ENABLE_VM2413) begin
    /***************************************************************
     * VM2413
     ***************************************************************/
    wire unsigned [9:0]           ro;
    wire unsigned [$bits(ro)-1:0] mo;
    wire cs_io_n = ((ExtBus[0].ADDR[7:1] != IO_BASE_ADDR[7:1]) || ExtBus[0].IORQ_n) || !ena_io;                // 7Ch~7Dh
    wire cs_mem_opll_n = (ExtBus[0].ADDR[15:1] != MIO_BASE_ADDR[15:1]) || ExtBus[0].MERQ_n || ExtBus[0].SLTSL_n;    // 7FF4h~7FF5h
    opll u_vm2413 (
        .xin        (ExtBus[0].CLK_21M),
        .xena       (ExtBus[0].CLK_EN_21M),
        .d          (ExtBus[0].DIN),
        .a          (ExtBus[0].ADDR[0]),
        .cs_n       (cs_io_n && cs_mem_opll_n),
        .we_n       (ExtBus[0].WR_n),
        .ic_n       (ExtBus[0].RESET_n),
        .mo         (mo),
        .ro         (ro)
    );

    /***************************************************************
     * LPF
     ***************************************************************/
    logic [9:0] lpf_mo;
    logic [9:0] lpf_ro;
    LPF_OPLL #(
        .GAIN_M     (1),
        .GAIN_D     (16)
    ) u_mo_lpf (
        .CLK        (ExtBus[0].CLK_21M),
        .CLK_EN     (ExtBus[0].CLK_EN_21M),
        .RESET_n    (ExtBus[0].RESET_n),
        .IN         (mo - 10'd512),
        .OUT        (lpf_mo)
    );
    LPF_OPLL #(
        .GAIN_M     (1),
        .GAIN_D     (16)
    ) u_ro_lpf (
        .CLK        (ExtBus[0].CLK_21M),
        .CLK_EN     (ExtBus[0].CLK_EN_21M),
        .RESET_n    (ExtBus[0].RESET_n),
        .IN         (ro - 10'd512),
        .OUT        (lpf_ro)
    );

    /***************************************************************
     * mixer
     ***************************************************************/
    logic [$bits(Sound.Signal)-1:0] out0;
    LIMITER_FF #(
        .IN_WIDTH($bits(lpf_mo) + 1),
        .OUT_WIDTH($bits(Sound.Signal))
    ) u_limiter (
        .CLK(CLK),
        .RESET_n(RESET_n && ExtBus[0].RESET_n),
        .IN({lpf_mo[9], lpf_mo } + {lpf_ro[9], lpf_ro }),
        .OUT(out0)
    );

    logic [$bits(Sound.Signal)-1:0] out_ff;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            out_ff <= 0;
        end
        else begin
            Sound.Signal <= out_ff;
            out_ff <= out0;
        end
    end
end

endmodule

/***********************************************************************
 * OPLL 用ローパスフィルタ
 ***********************************************************************/
module LPF_OPLL #(
    parameter   GAIN_M = 1,
    parameter   GAIN_D = 1,
    parameter   SIGNAL_BIT_WIDTH = 10,
    parameter   PERIOD = 18
)(
    input wire          CLK,
    input wire          CLK_EN,
    input wire          RESET_n,
    input wire [SIGNAL_BIT_WIDTH-1:0] IN,
    output reg [SIGNAL_BIT_WIDTH-1:0] OUT
);
    localparam PERIOD_BIT_WIDTH = $clog2(PERIOD+1);
    localparam SUM_BIT_WIDTH = (PERIOD_BIT_WIDTH + SIGNAL_BIT_WIDTH);

    /***************************************************************
     * CLK 1/4
     ***************************************************************/
    logic [1:0] div_cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                div_cnt <= 0;
        else if(!CLK_EN)            div_cnt <= div_cnt;
        else                        div_cnt <= div_cnt + 1'd1;
    end

    /***************************************************************
     * バッファインデックス更新
     ***************************************************************/
    logic [PERIOD_BIT_WIDTH-1:0]    index;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                index <= 0;
        else if(!CLK_EN)            index <= index;
        else if(div_cnt != 0)       index <= index;
        else if(index == PERIOD - 1)index = 0;
        else                        index <= index + 1'd1;
    end

    /***************************************************************
     * バッファ格納
     ***************************************************************/
    logic [SIGNAL_BIT_WIDTH-1:0]    buffer[0:PERIOD-1];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                buffer[0] <= 0;
        else if(!CLK_EN)            buffer[index] <= buffer[index];
        else if(div_cnt != 0)       buffer[index] <= buffer[index];
        else                        buffer[index] <= IN;
    end

    /***************************************************************
     * バッファ格納数更新
     ***************************************************************/
    logic [PERIOD_BIT_WIDTH-1:0]    count;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                count <= 0;
        else if(!CLK_EN)            count <= count;
        else if(div_cnt != 0)       count <= count;
        else if(count != PERIOD)    count <= count + 1'd1;
        else                        count <= count;
    end

    /***************************************************************
     * ビット拡張
     ***************************************************************/
    logic [SUM_BIT_WIDTH-1:0] in_extend;
    if(1) begin
        wire [(SUM_BIT_WIDTH-$bits(IN))-1:0] sign = -1;
        wire [(SUM_BIT_WIDTH-$bits(IN))-1:0] zero = 0;
        assign in_extend = IN[$bits(IN)-1] ? { sign, IN } : { zero, IN };
    end
    else begin
        assign in_extend = SUM_BIT_WIDTH'(signed'(IN));
    end

    logic [SUM_BIT_WIDTH-1:0] buffer_extend;
    if(1) begin
        wire [(SUM_BIT_WIDTH-$bits(buffer[index]))-1:0] sign = -1;
        wire [(SUM_BIT_WIDTH-$bits(buffer[index]))-1:0] zero = 0;
        assign buffer_extend = buffer[index][$bits(buffer[index])-1] ? { sign, buffer[index] } : { zero, buffer[index] };
    end
    else begin
        assign buffer_extend = SUM_BIT_WIDTH'(signed'(buffer[index]));
    end

    /***************************************************************
     * 加算値計算
     ***************************************************************/
    logic [SUM_BIT_WIDTH-1:0] adder;
    always_comb begin
        adder = in_extend - buffer_extend;
    end

    /***************************************************************
     * 加算
     ***************************************************************/
    logic [SUM_BIT_WIDTH-1:0] sum;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                sum <= 0;
        else if(!CLK_EN)            sum <= sum;
        else if(div_cnt != 0)       sum <= sum;
        else if(count == PERIOD)    sum <= sum + adder;
        else                        sum <= sum + in_extend;
    end

    /***************************************************************
     * バッファアンプ
     ***************************************************************/
    logic [SUM_BIT_WIDTH-1:0] amp;
    ATT_CONST #(
        .BIT_WIDTH(SUM_BIT_WIDTH),
        .MUL(GAIN_M),
        .DIV(GAIN_D)
    ) u_amp (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .IN(sum),
        .OUT(amp)
    );

    /***************************************************************
     * リミッタ
     ***************************************************************/
    LIMITER_FF #(
        .IN_WIDTH($bits(amp)),
        .OUT_WIDTH($bits(OUT))
    ) u_limiter (
        .CLK(CLK),
        .RESET_n(RESET_n),
        .IN(amp),
        .OUT(OUT)
    );
endmodule

`default_nettype wire
