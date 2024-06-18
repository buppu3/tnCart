//
// cartridge_megarom.sv
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
 * MEGA ROM カードリッジ
 ***************************************************************/
module CARTRIDGE_MEGAROM #(
    parameter               RAM_ADDR = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    SOUND_IF.OUT            Sound
);

    /***************************************************************
     * メガロム設定
     ***************************************************************/
    MEGAROM_IF Megarom();
    logic SCC_ENA;
    MEGAROM_CONFIGURE #(
        .RAM_ADDR(RAM_ADDR)
    ) u_conf (
        .RESET_n,
        .CLK,
        .Bus(ExtBus[BUS_CONFIG]),
        .Megarom,
        .SCC_ENA
    );

    /***************************************************************
     * メガロムコントローラ
     ***************************************************************/
    localparam BUS_CONFIG     = 0;
    localparam BUS_SCC        = 1;
    localparam BUS_COUNT      = 2;
    BUS_IF  ExtBus[0:BUS_COUNT-1]();
    MEGAROM_CONTROLLER #(
        .COUNT(BUS_COUNT),
        .USE_FF(1)
    ) u_rom (
        .RESET_n,
        .CLK,
        .Megarom,
        .Bus,
        .Ram,
        .ExtBus
    );

    /***************************************************************
     * SCC
     ***************************************************************/
    assign ExtBus[BUS_SCC].INT_n = 1;
    assign ExtBus[BUS_SCC].WAIT_n = 1;
    if(CONFIG::ENABLE_SCC) begin
        logic scc_bank_n;
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      scc_bank_n <= 1;
            else if(!ExtBus[BUS_SCC].RESET_n) scc_bank_n <= 1;
            else                              scc_bank_n <= Megarom.BankReg[{ExtBus[BUS_SCC].ADDR[15], ExtBus[BUS_SCC].ADDR[13]}] != 8'd63;
        end

        logic scc_cs_n;
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      scc_cs_n <= 1;
            else if(!ExtBus[BUS_SCC].RESET_n) scc_cs_n <= 1;
            else                              scc_cs_n <= ExtBus[BUS_SCC].ADDR[15:8] != 8'h98;
        end

        logic busdir_n;
        logic [7:0] dout;
        wire  [10:0] sound;
        SCC u_scc (
            .RESET_n    (RESET_n && ExtBus[BUS_SCC].RESET_n),
`ifdef SCC_CLK_21M
            .CLK        (ExtBus[BUS_SCC].CLK_21M),
            .CLK_EN     (ExtBus[BUS_SCC].CLK_EN_21M),
`else
            .CLK        (CLK),
            .CLK_EN     (ExtBus[BUS_SCC].CLK_EN),
`endif
            .ADDR       (ExtBus[BUS_SCC].ADDR[7:0]),
            .CS_n       (scc_cs_n || ExtBus[BUS_SCC].SLTSL_n || ExtBus[BUS_SCC].MERQ_n || !SCC_ENA || scc_bank_n),
            .RD_n       (ExtBus[BUS_SCC].RD_n),
            .WR_n       (ExtBus[BUS_SCC].WR_n),
            .DIN        (ExtBus[BUS_SCC].DIN),
            .DOUT       (dout),
            .BUSDIR_n   (busdir_n),
            .OUT        (sound)
        );

        assign Sound.Signal = sound[10:1];

`ifdef SCC_CLK_21M
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      ExtBus[BUS_SCC].BUSDIR_n <= 1;
            else if(!ExtBus[BUS_SCC].RESET_n) ExtBus[BUS_SCC].BUSDIR_n <= 1;
            else                              ExtBus[BUS_SCC].BUSDIR_n <= ExtBus[BUS_SCC].RD_n ? 1'b1 : busdir_n;
        end

        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)                      ExtBus[BUS_SCC].DOUT <= 8'h00;
            else if(!ExtBus[BUS_SCC].RESET_n) ExtBus[BUS_SCC].DOUT <= 8'h00;
            else                              ExtBus[BUS_SCC].DOUT <= ExtBus[BUS_SCC].RD_n ? 8'h00 : dout;
        end
`else
        assign ExtBus[BUS_SCC].BUSDIR_n = busdir_n;
        assign ExtBus[BUS_SCC].DOUT = dout;
`endif
    end
    else begin
        assign ExtBus[BUS_SCC].BUSDIR_n = 1;
        assign ExtBus[BUS_SCC].DOUT = 0;
        assign Sound.Signal = 0;
    end

endmodule

`default_nettype wire
