//
// expansion_slot.sv
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
 * 基本スロットを拡張する
 ***************************************************************/
module EXPANSION_SLOT #(
    parameter               SLTEXP_ADDR = 16'hFFFF,
    parameter               COUNT = 4
) (
    input   wire            RESET_n,
    CLOCK_IF.SRC            Clock,
    BUS_IF.CARTRIDGE        Primary,
    BUS_IF.MSX              Secondary[0:COUNT-1],
    input   wire            WAIT_n
);
    localparam OPTIMAIZE = 0;

    /***************************************************************
     * ライト検出
     ***************************************************************/
    wire wr_n = Primary.SLTSL_n || Primary.WR_n || (Primary.ADDR != SLTEXP_ADDR);
    logic prev_wr_n;
    always_ff @(posedge Clock.MEM_CLK or negedge RESET_n) begin
        if(!RESET_n)              prev_wr_n <= 1;
        else if(!Primary.RESET_n) prev_wr_n <= 1;
        else                      prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;

    /***************************************************************
     * write register
     ***************************************************************/
    reg [7:0] sltexp;
    always_ff @(posedge Clock.MEM_CLK or negedge RESET_n) begin
        if(!RESET_n || !Primary.RESET_n) begin
            sltexp <= 0;
        end
        else if(det_wr) begin
            sltexp <= Primary.DIN;
        end
    end

    /***************************************************************
     * リード検出
     ***************************************************************/
    wire rd_n = Primary.SLTSL_n || Primary.RD_n || (Primary.ADDR != SLTEXP_ADDR);

    /***************************************************************
     * read register
     ***************************************************************/
    reg my_busdir_n;
    always_ff @(posedge Clock.MEM_CLK or negedge RESET_n) begin
        if(!RESET_n || !Primary.RESET_n) begin
            my_busdir_n <= 1;
        end
        else if(!rd_n) begin
            my_busdir_n <= 0;
        end
        else begin
            my_busdir_n <= 1;
        end
    end

    /***************************************************************
     * 各ページのセカンダリスロット番号
     ***************************************************************/
    wire [1:0] curr_slot[0:3];
    assign curr_slot[0] = sltexp[1:0];
    assign curr_slot[1] = sltexp[3:2];
    assign curr_slot[2] = sltexp[5:4];
    assign curr_slot[3] = sltexp[7:6];

    /***************************************************************
     * Primary.ADDR のページ番号
     ***************************************************************/
    wire [1:0] curr_page = Primary.ADDR[15:14];

    /***************************************************************
     * Secondary へ接続
     ***************************************************************/
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: sec
            always_ff @(posedge Clock.MEM_CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    Secondary[num].SLTSL_n    <= 1;
                    Secondary[num].ADDR       <= 0;
                    Secondary[num].DIN        <= 0;
                    Secondary[num].RFSH_n     <= 1;
                    Secondary[num].RD_n       <= 1;
                    Secondary[num].WR_n       <= 1;
                    Secondary[num].IORQ_n     <= 1;
                    Secondary[num].RESET_n    <= 0;
                    Secondary[num].CLK        <= 0;
                end
                else if(!Primary.RESET_n) begin
                    Secondary[num].SLTSL_n    <= 1;
                    Secondary[num].ADDR       <= 0;
                    Secondary[num].DIN        <= 0;
                    Secondary[num].RFSH_n     <= Primary.RFSH_n;
                    Secondary[num].RD_n       <= 1;
                    Secondary[num].WR_n       <= 1;
                    Secondary[num].IORQ_n     <= 1;
                    Secondary[num].RESET_n    <= 0;
                    Secondary[num].CLK        <= Primary.CLK;
                end
                else begin
                    Secondary[num].SLTSL_n    <= Primary.SLTSL_n || ((num < 4) ? (curr_slot[curr_page] != num) : 1);
                    Secondary[num].ADDR       <= Primary.ADDR;
                    Secondary[num].DIN        <= Primary.DIN;
                    Secondary[num].RFSH_n     <= Primary.RFSH_n;
                    Secondary[num].RD_n       <= Primary.RD_n;
                    Secondary[num].WR_n       <= Primary.WR_n;
                    Secondary[num].IORQ_n     <= Primary.IORQ_n;
                    Secondary[num].RESET_n    <= Primary.RESET_n;
                    Secondary[num].CLK        <= Primary.CLK;
                end
            end
        end
    endgenerate

    /***************************************************************
     * secondary 信号の前処理
     ***************************************************************/
    wire [COUNT-1:0] int_n_n;
    wire [COUNT:0] wait_n_n;
    wire [COUNT:0] busdir_n_n;
    wire [$bits(Primary.DOUT)-1:0] dout[0:COUNT];
    generate
        genvar i;
        for(i = 0; i < COUNT; i = i + 1) begin: lp
            assign int_n_n[i] = ~Secondary[i].INT_n;
            assign wait_n_n[i+1] = ~Secondary[i].WAIT_n;
            assign busdir_n_n[i+1] = ~Secondary[i].BUSDIR_n;
            assign dout[i+1] = Secondary[i].DOUT;
        end
    endgenerate
    assign wait_n_n[0] = ~WAIT_n;
    assign busdir_n_n[0] = ~my_busdir_n;
    assign dout[0] = ~sltexp;

    /***************************************************************
     * DOUT_n の出力
     ***************************************************************/
    ARRAY_SELECTOR #(
        .COMB(1),
        .DEFAULT(8'hFF),
        .WIDTH($bits(Primary.DOUT)),
        .COUNT(COUNT+1)
    ) u_select_dout (
        .RESET_n(RESET_n & Primary.RESET_n),
        .CLK(Clock.MEM_CLK),
        .ENA(1'b1),
        .IN(dout),
        .OE(busdir_n_n),
        .OUT(Primary.DOUT)
    );

    /***************************************************************
     * BUSDIR_n の出力
     ***************************************************************/
    NOR_Nbits #(
        .COMB(1),
        .COUNT($bits(busdir_n_n))
    ) u_nor_busdir_n (
        .RESET_n(RESET_n & Primary.RESET_n),
        .CLK(Clock.MEM_CLK),
        .IN(busdir_n_n),
        .ENA(1'b1),
        .OUT(Primary.BUSDIR_n)
    );

    /***************************************************************
     * INT_n の出力
     ***************************************************************/
    NOR_Nbits #(
        .COUNT($bits(int_n_n))
    ) u_nor_int_n (
        .RESET_n(RESET_n & Primary.RESET_n),
        .CLK(Clock.MEM_CLK),
        .IN(int_n_n),
        .ENA(1'b1),
        .OUT(Primary.INT_n)
    );

    /***************************************************************
     * WAIT_n の出力
     ***************************************************************/
    NOR_Nbits #(
        .COUNT($bits(wait_n_n))
    ) u_nor_wait_n (
        .RESET_n(RESET_n & Primary.RESET_n),
        .CLK(Clock.MEM_CLK),
        .IN(wait_n_n),
        .ENA(1'b1),
        .OUT(Primary.WAIT_n)
    );

endmodule

`default_nettype wire
