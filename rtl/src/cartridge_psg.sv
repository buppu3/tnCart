//
// cartridge_psg.sv
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
 * PSG カートリッジ
 ***************************************************************/
module CARTRIDGE_PSG #(
    parameter [7:0]         IO_BASE_ADDR = 8'hA0,
    parameter               MIRROR = 1
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    SOUND_IF.OUT            Sound
);

    /***************************************************************
     * 未使用の出力信号の処理
     ***************************************************************/
    assign Bus.INT_n = 1;
    assign Bus.WAIT_n = 1;

    /***************************************************************
     * アドレスデコーダ
     ***************************************************************/
    wire cs_psg   = (Bus.ADDR[7:2] == IO_BASE_ADDR[7:2]) && !Bus.IORQ_n;
    wire cs_addr  = ((Bus.ADDR[1:0] == 2'b00) && !Bus.WR_n);
    wire cs_write = ((Bus.ADDR[1:0] == 2'b01) && !Bus.WR_n);
    wire cs_read  = ((Bus.ADDR[1:0] == 2'b10) && !Bus.RD_n);

    /***************************************************************
     * レジスタ読み込み時の処理
     ***************************************************************/
    logic [7:0] dout;
    wire read_n = MIRROR || !(cs_read && cs_psg);
    assign          Bus.BUSDIR_n = read_n;
    assign          Bus.DOUT = read_n ? 0 : dout;

    /***************************************************************
     * ym2149_audio
     ***************************************************************/
    ym2149_audio u_ym2149_audio (
        .clk_i          (CLK),
        .en_clk_psg_i   (Bus.CLK_EN),
        .sel_n_i        (1'b0),
        .reset_n_i      (Bus.RESET_n && Bus.RESET_n),
        .bc_i           ((cs_addr || cs_read ) && cs_psg),
        .bdir_i         ((cs_addr || cs_write) && cs_psg),
        .data_i         (Bus.DIN),
        .data_r_o       (dout),
        .ch_a_o         (),
        .ch_b_o         (),
        .ch_c_o         (),
        .mix_audio_o    (out),
        .pcm14s_o       ()
    );

    /***************************************************************
     * 出力変換
     ***************************************************************/
    logic [13:0] out;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Bus.RESET_n) begin
            Sound.Signal <= 0;
        end
        else begin
            Sound.Signal <= { 1'b0, out[$bits(out)-1: $bits(out)-($bits(Sound.Signal)-1)] };
        end
    end

endmodule

`default_nettype wire
