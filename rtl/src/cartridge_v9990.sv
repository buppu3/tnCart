//
// cartridge_v9990.sv
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
 * V9990 カートリッジ
 ***************************************************************/
module CARTRIDGE_V9990 #(
    parameter [7:0]         IO_BASE_ADDR = 8'h60,
    parameter               MIRROR = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    UMA_IF.CLK              UmaClock,
    VIDEO_IF.OUT            Video
);
    /***************************************************************
     * MSXバス
     ***************************************************************/
    logic wait_n;
    logic int0_n;
    logic int1_n;
    assign Bus.INT_n = MIRROR || (int0_n && int1_n);
    assign Bus.WAIT_n = MIRROR || wait_n;

    wire cs_n = Bus.IORQ_n || (Bus.ADDR[7:4] != IO_BASE_ADDR[7:4]);
    logic [7:0] dout;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.BUSDIR_n <= 1;
            Bus.DOUT <= 0;
        end
        else if(!MIRROR && !cs_n && !Bus.RD_n && !cs_n) begin
            Bus.BUSDIR_n <= 0;
            Bus.DOUT <= dout;
        end
        else begin
            Bus.BUSDIR_n <= 1;
            Bus.DOUT <= 0;
        end
    end

    logic reset;
    logic CSR_n;
    logic CSW_n;
    logic [3:0] MODE;
    logic [7:0] CD_IN;
    always_ff @(posedge CLK) begin
        reset <= Bus.RESET_n && RESET_n;
        CSR_n <= Bus.RD_n || cs_n;
        CSW_n <= Bus.WR_n || cs_n;
        MODE <= Bus.ADDR[3:0];
        CD_IN <= Bus.DIN;
    end

    /***************************************************************
     * VDP
     ***************************************************************/
    logic [4:0] r;
    logic [4:0] g;
    logic [4:0] b;
    logic hs;
    logic vs;
    logic [2:0] RESO;
    logic [18:0] addr;
    assign Ram.ADDR = {5'b00000, addr};
    T9990 u_vdp (
        .RESET_n(RESET_n && Bus.RESET_n),
        .CLK,
        .CLK_21M_EN(UmaClock.CLK21M_EN),
        .CLK_14M_EN(UmaClock.CLK14M_EN),
        .CLK_25M_EN(UmaClock.CLK25M_EN),

        .CSR_n,
        .CSW_n,
        .MODE,
        .CD_IN,
        .CD_OUT(dout),
        .WAIT_n(wait_n),
        .INT0_n(int0_n),
        .INT1_n(int1_n),
        .DREQ_n(),
        .VMREQ_n(),

        .RAM_REQ(Ram.TIMING),
        .RAM_OE_n(Ram.OE_n),
        .RAM_WE_n(Ram.WE_n),
        .RAM_RFSH_n(Ram.RFSH_n),
        .RAM_ADDR(addr),
        .RAM_DIN(Ram.DIN),
        .RAM_DIN_SIZE(Ram.DIN_SIZE),
        .RAM_DOUT(Ram.DOUT),
        .RAM_ACK_n(Ram.ACK_n),

        .HS(hs),
        .VS(vs),
        .R(r),
        .G(g),
        .B(b),
        .Ys(),
        .DCLK_EN(Video.DCLK),
        .RESO,
        .IL(),
        .EO()
    );

    /***************************************************************
     * ビデオ出力
     ***************************************************************/
    localparam FF_CNT = 2;
    generate
        if(FF_CNT > 0) begin
            logic [4:0] ff_r[0:FF_CNT-1];
            logic [4:0] ff_g[0:FF_CNT-1];
            logic [4:0] ff_b[0:FF_CNT-1];
            logic       ff_hs[0:FF_CNT-1];
            logic       ff_vs[0:FF_CNT-1];
            logic [2:0] ff_reso[0:FF_CNT-1];

            genvar num;
            for(num = 0; num < FF_CNT; num = num + 1) begin: dly
                if(num == FF_CNT - 1) begin
                    always_ff @(posedge Video.DCLK) begin
                        ff_r[num]    <= r;
                        ff_g[num]    <= g;
                        ff_b[num]    <= b;
                        ff_hs[num]   <= hs;
                        ff_vs[num]   <= vs;
                        ff_reso[num] <= RESO;
                    end
                end
                else begin
                    always_ff @(posedge Video.DCLK) begin
                        ff_r[num]    <= ff_r[num+1];
                        ff_g[num]    <= ff_g[num+1];
                        ff_b[num]    <= ff_b[num+1];
                        ff_hs[num]   <= ff_hs[num+1];
                        ff_vs[num]   <= ff_vs[num+1];
                        ff_reso[num] <= ff_reso[num+1];
                    end
                end
            end

            logic [7:0] r_out;
            logic [7:0] g_out;
            logic [7:0] b_out;
            logic       hs_n_out;
            logic       vs_n_out;

            assign Video.R = r_out;
            assign Video.G = g_out;
            assign Video.B = b_out;
            assign Video.HS_n = hs_n_out;
            assign Video.VS_n = vs_n_out;

            always_ff @(posedge Video.DCLK) begin
                r_out <= {ff_r[0], ff_r[0][4:2]};
                g_out <= {ff_g[0], ff_g[0][4:2]};
                b_out <= {ff_b[0], ff_b[0][4:2]};
                hs_n_out <= !ff_hs[0];
                vs_n_out <= !ff_vs[0];

                case (ff_reso[0])
                    default:        Video.RESOLUTION <= VIDEO::RESOLUTION_B1;
                    T9990::RESO_B1: Video.RESOLUTION <= VIDEO::RESOLUTION_B1;
                    T9990::RESO_B2: Video.RESOLUTION <= VIDEO::RESOLUTION_B2;
                    T9990::RESO_B3: Video.RESOLUTION <= VIDEO::RESOLUTION_B3;
                    T9990::RESO_B4: Video.RESOLUTION <= VIDEO::RESOLUTION_B4;
                    T9990::RESO_B5: Video.RESOLUTION <= VIDEO::RESOLUTION_B5;
                    T9990::RESO_B6: Video.RESOLUTION <= VIDEO::RESOLUTION_B6;
                endcase
            end
        end
        else begin
            assign Video.R = {r, r[4:2]};
            assign Video.R = {g, g[4:2]};
            assign Video.R = {b, b[4:2]};
            assign Video.HS_n = !hs;
            assign Video.VS_n = !vs;
            assign Video.RESOLUTION = (RESO == T9990::RESO_B1) ? VIDEO::RESOLUTION_B1 :
                                      (RESO == T9990::RESO_B2) ? VIDEO::RESOLUTION_B2 :
                                      (RESO == T9990::RESO_B3) ? VIDEO::RESOLUTION_B3 :
                                      (RESO == T9990::RESO_B4) ? VIDEO::RESOLUTION_B4 :
                                      (RESO == T9990::RESO_B5) ? VIDEO::RESOLUTION_B5 :
                                      (RESO == T9990::RESO_B6) ? VIDEO::RESOLUTION_B6 : VIDEO::RESOLUTION_B1;
        end
    endgenerate

endmodule

`default_nettype wire
