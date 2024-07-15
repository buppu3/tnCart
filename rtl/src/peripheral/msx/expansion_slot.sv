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
    parameter               COUNT = 4,
    parameter               USE_FF = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,

    BUS_IF.CARTRIDGE        Primary,
    BUS_IF.MSX              Secondary[0:COUNT-1],
    input   wire            WAIT_n
);

    /***************************************************************
     * ライト検出
     ***************************************************************/
    wire wr_n = Primary.SLTSL_n || Primary.MERQ_n || Primary.WR_n;
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)              prev_wr_n <= 1;
        else if(!Primary.RESET_n) prev_wr_n <= 1;
        else                      prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;

    /***************************************************************
     * write register
     ***************************************************************/
    logic [7:0] sltexp;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Primary.RESET_n) begin
            sltexp <= 0;
        end
        else if(det_wr && Primary.ADDR == 16'hFFFF) begin
            sltexp <= Primary.DIN;
        end
    end

    /***************************************************************
     * read register
     ***************************************************************/
    logic [7:0] my_dout;
    logic my_busdir_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Primary.RESET_n) begin
            my_dout <= 0;
            my_busdir_n <= 1;
        end
        else if(!Primary.RD_n && !Primary.SLTSL_n && !Primary.MERQ_n && Primary.ADDR == 16'hFFFF) begin
            my_dout <= ~sltexp;
            my_busdir_n <= 0;
        end
        else begin
            my_dout <= 0;
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
    wire [7:0] tmp_dout    [0:COUNT-1];
    wire       tmp_busdir_n[0:COUNT-1];
    wire       tmp_int_n   [0:COUNT-1];
    wire       tmp_wait_n  [0:COUNT-1];
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: sec
            if(USE_FF) begin
                always_ff @(posedge Primary.CLK_21M or negedge RESET_n) begin
                    if(!RESET_n) begin
                        Secondary[num].CLK_EN_21M <= 0;
                    end
                    else begin
                        Secondary[num].CLK_EN_21M <= Primary.CLK_EN_21M;
                    end
                end

                always_ff @(posedge CLK or negedge RESET_n) begin
                    if(!RESET_n) begin
                        Secondary[num].SLTSL_n    <= 1;
                        Secondary[num].ADDR       <= 0;
                        Secondary[num].DIN        <= 0;
                        Secondary[num].RFSH_n     <= 1;
                        Secondary[num].RD_n       <= 1;
                        Secondary[num].WR_n       <= 1;
                        Secondary[num].MERQ_n     <= 1;
                        Secondary[num].IORQ_n     <= 1;
                        Secondary[num].CS1_n      <= 1;
                        Secondary[num].CS2_n      <= 1;
                        Secondary[num].CS12_n     <= 1;
                        Secondary[num].M1_n       <= 1;
                        Secondary[num].RESET_n    <= 0;
                        Secondary[num].CLK        <= 0;
                        Secondary[num].CLK_EN     <= 0;
                    end
                    else if(!Primary.RESET_n) begin
                        Secondary[num].SLTSL_n    <= 1;
                        Secondary[num].ADDR       <= 0;
                        Secondary[num].DIN        <= 0;
                        Secondary[num].RFSH_n     <= Primary.RFSH_n;
                        Secondary[num].RD_n       <= 1;
                        Secondary[num].WR_n       <= 1;
                        Secondary[num].MERQ_n     <= 1;
                        Secondary[num].IORQ_n     <= 1;
                        Secondary[num].CS1_n      <= 1;
                        Secondary[num].CS2_n      <= 1;
                        Secondary[num].CS12_n     <= 1;
                        Secondary[num].M1_n       <= 1;
                        Secondary[num].RESET_n    <= 0;
                        Secondary[num].CLK        <= Primary.CLK;
                        Secondary[num].CLK_EN     <= Primary.CLK_EN;
                    end
                    else begin
                        Secondary[num].SLTSL_n    <= Primary.SLTSL_n || ((num < 4) ? (curr_slot[curr_page] != num) : 1);
                        Secondary[num].ADDR       <= Primary.ADDR;
                        Secondary[num].DIN        <= Primary.DIN;
                        Secondary[num].RFSH_n     <= Primary.RFSH_n;
                        Secondary[num].RD_n       <= Primary.RD_n;
                        Secondary[num].WR_n       <= Primary.WR_n;
                        Secondary[num].MERQ_n     <= Primary.MERQ_n;
                        Secondary[num].IORQ_n     <= Primary.IORQ_n;
                        Secondary[num].CS1_n      <= Primary.CS1_n;
                        Secondary[num].CS2_n      <= Primary.CS2_n;
                        Secondary[num].CS12_n     <= Primary.CS12_n;
                        Secondary[num].M1_n       <= Primary.M1_n;
                        Secondary[num].RESET_n    <= Primary.RESET_n;
                        Secondary[num].CLK        <= Primary.CLK;
                        Secondary[num].CLK_EN     <= Primary.CLK_EN;
                    end
                end
            end
            else begin
                assign Secondary[num].SLTSL_n    = Primary.SLTSL_n || ((num < 4) ? (curr_slot[curr_page] != num) : 1);
                assign Secondary[num].ADDR       = Primary.ADDR;
                assign Secondary[num].DIN        = Primary.DIN;
                assign Secondary[num].RFSH_n     = Primary.RFSH_n;
                assign Secondary[num].RD_n       = Primary.RD_n;
                assign Secondary[num].WR_n       = Primary.WR_n;
                assign Secondary[num].MERQ_n     = Primary.MERQ_n;
                assign Secondary[num].IORQ_n     = Primary.IORQ_n;
                assign Secondary[num].CS1_n      = Primary.CS1_n;
                assign Secondary[num].CS2_n      = Primary.CS2_n;
                assign Secondary[num].CS12_n     = Primary.CS12_n;
                assign Secondary[num].M1_n       = Primary.M1_n;
                assign Secondary[num].RESET_n    = Primary.RESET_n;
                assign Secondary[num].CLK        = Primary.CLK;
                assign Secondary[num].CLK_EN     = Primary.CLK_EN;
                assign Secondary[num].CLK_EN_21M = Primary.CLK_EN_21M;
            end

            assign Secondary[num].CLK_21M = Primary.CLK_21M;
            assign Secondary[num].CLK_14M = Primary.CLK_14M;

            assign tmp_dout    [num] = Secondary[num].DOUT     | ((num < COUNT-1) ? tmp_dout    [num + 1] : 0);
            assign tmp_busdir_n[num] = Secondary[num].BUSDIR_n & ((num < COUNT-1) ? tmp_busdir_n[num + 1] : 1);
            assign tmp_int_n   [num] = Secondary[num].INT_n    & ((num < COUNT-1) ? tmp_int_n   [num + 1] : 1);
            assign tmp_wait_n  [num] = Secondary[num].WAIT_n   & ((num < COUNT-1) ? tmp_wait_n  [num + 1] : 1);
        end
    endgenerate

    if(USE_FF) begin
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                Primary.DOUT     <= 0;
                Primary.BUSDIR_n <= 1;
                Primary.INT_n    <= 1;
                Primary.WAIT_n   <= 0;
            end
            else if(!Primary.RESET_n) begin
                Primary.DOUT     <= 0;
                Primary.BUSDIR_n <= 1;
                Primary.INT_n    <= 1;
                Primary.WAIT_n   <= WAIT_n;
            end
            else begin
                Primary.DOUT     <= my_busdir_n ? tmp_dout    [0] : my_dout;
                Primary.BUSDIR_n <= my_busdir_n ? tmp_busdir_n[0] : 0;
                Primary.INT_n    <= tmp_int_n   [0];
                Primary.WAIT_n   <= tmp_wait_n  [0] & WAIT_n;
            end
        end
    end
    else begin
        assign Primary.DOUT     = my_busdir_n ? tmp_dout    [0] : my_dout;
        assign Primary.BUSDIR_n = my_busdir_n ? tmp_busdir_n[0] : 0;
        assign Primary.INT_n    = tmp_int_n   [0];
        assign Primary.WAIT_n   = tmp_wait_n  [0] & WAIT_n;
    end

endmodule


`default_nettype wire
