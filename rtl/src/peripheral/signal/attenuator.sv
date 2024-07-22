//
// attenuator.sv
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
`define ATT_USE_MUL

/***********************************************************************
 * アッテネーターパッケージ
 ***********************************************************************/
package ATTENUATOR;
    localparam [15:0] ATT_MUTE  = 0;
    localparam [15:0] ATT_m0dB  = { 8'd  1, 8'd  1}; //  1/1
    localparam [15:0] ATT_m1dB  = { 8'd  8, 8'd  9}; //  1/1.122
    localparam [15:0] ATT_m2dB  = { 8'd 23, 8'd 29}; //  1/1.259
    localparam [15:0] ATT_m3dB  = { 8'd 12, 8'd 17}; //  1/1.413
    localparam [15:0] ATT_m4dB  = { 8'd 12, 8'd 19}; //  1/1.585
    localparam [15:0] ATT_m5dB  = { 8'd  9, 8'd 16}; //  1/1.778
    localparam [15:0] ATT_m6dB  = { 8'd  1, 8'd  2}; //  1/1.995
    localparam [15:0] ATT_m7dB  = { 8'd 21, 8'd 47}; //  1/2.239
    localparam [15:0] ATT_m8dB  = { 8'd 41, 8'd103}; //  1/2.512
    localparam [15:0] ATT_m9dB  = { 8'd 11, 8'd 31}; //  1/2.818
    localparam [15:0] ATT_m10dB = { 8'd  6, 8'd 19}; //  1/3.162
    localparam [15:0] ATT_m11dB = { 8'd 11, 8'd 39}; //  1/3.548
    localparam [15:0] ATT_m12dB = { 8'd  1, 8'd  4}; //  1/3.981
    localparam [15:0] ATT_m13dB = { 8'd 15, 8'd 67}; //  1/4.467
    localparam [15:0] ATT_m14dB = { 8'd  1, 8'd  5}; //  1/5.012
    localparam [15:0] ATT_m15dB = { 8'd  8, 8'd 45}; //  1/5.623
    localparam [15:0] ATT_m16dB = { 8'd 13, 8'd 82}; //  1/6.310
    localparam [15:0] ATT_m17dB = { 8'd 13, 8'd 92}; //  1/7.079
    localparam [15:0] ATT_m18dB = { 8'd  1, 8'd  8}; //  1/7.943
    localparam [15:0] ATT_m19dB = { 8'd 11, 8'd 98}; //  1/8.913
    localparam [15:0] ATT_m20dB = { 8'd  1, 8'd 10}; //  1/10.00
endpackage

/***********************************************************************
 * アッテネーターモジュール
 ***********************************************************************/
module ATT_CONST #( 
    parameter   BIT_WIDTH = 10,
    parameter   MUL = 4,
    parameter   DIV = 4
)(
    input wire          CLK,
    input wire          RESET_n,
    input  wire [BIT_WIDTH-1:0]     IN,
    output reg  [BIT_WIDTH-1:0]     OUT
);
`ifdef ATT_USE_MUL
    if(MUL == 0 || DIV == 0) begin
        // 0 の場合は MUTE
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= 0;
        end
    end
    else begin
        wire [17:0] sign = -1;
        wire [17:0] zero = 0;
        wire [17:0] mul_a = {(IN[BIT_WIDTH-1] ? sign[17:BIT_WIDTH] : zero[17:BIT_WIDTH]), IN[BIT_WIDTH-1:0]};
        wire [17:0] mul_b = 1024 * MUL / DIV;
        logic [35:0] mul_out;
        MULT18X18 mult18x18_inst (
            .DOUT(mul_out),
            .SOA(),
            .SOB(),
            .A(mul_a),
            .B(mul_b),
            .ASIGN(1'b1),
            .BSIGN(1'b0),
            .SIA(18'd0),
            .SIB(18'd0),
            .CE(1'b1),
            .CLK(CLK),
            .RESET(!RESET_n),
            .ASEL(1'b0),
            .BSEL(1'b0)
        );

        defparam mult18x18_inst.AREG = 1'b1;
        defparam mult18x18_inst.BREG = 1'b1;
        defparam mult18x18_inst.OUT_REG = 1'b1;
        defparam mult18x18_inst.PIPE_REG = 1'b0;
        defparam mult18x18_inst.ASIGN_REG = 1'b0;
        defparam mult18x18_inst.BSIGN_REG = 1'b0;
        defparam mult18x18_inst.SOA_REG = 1'b0;
        defparam mult18x18_inst.MULT_RESET_MODE = "SYNC";

        assign OUT = mul_out[BIT_WIDTH+10-1:10];
    end
`else
    if(MUL == 0 || DIV == 0) begin
        // 0 の場合は MUTE
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= 0;
        end
    end
    else if(MUL == DIV) begin
        // 0dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= IN;
        end
    end
    else if(MUL * 2 == DIV) begin
        // -6dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= { IN[$bits(IN)-1], IN[$bits(IN)-1:1]};
        end
    end
    else if(MUL * 4 == DIV) begin
        // -12dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= { IN[$bits(IN)-1],IN[$bits(IN)-1], IN[$bits(IN)-1:2]};
        end
    end
    else if(MUL * 8 == DIV) begin
        // -18dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= { IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1], IN[$bits(IN)-1:3]};
        end
    end
    else if(MUL * 16 == DIV) begin
        // -18dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= { IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1], IN[$bits(IN)-1:4]};
        end
    end
    else if(MUL * 32 == DIV) begin
        // -24dB
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n)    OUT <= 0;
            else            OUT <= { IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1],IN[$bits(IN)-1], IN[$bits(IN)-1:5]};
        end
    end
    else begin

        localparam RESO = 4;    // 1LSB の分解能
        wire sign = IN[BIT_WIDTH - 1];

        /***************************************************************
         * 絶対値を得る
         ***************************************************************/
        logic [BIT_WIDTH-1:0] abs_value;
        always_comb begin
            abs_value = sign ? (~IN + 1'd1) : IN;
        end

        /***************************************************************
         * ビット毎に計算
         ***************************************************************/
        logic [BIT_WIDTH+RESO-1:0] bit_val[0:BIT_WIDTH-1];
        genvar bit_cnt;
        for(bit_cnt = 0; bit_cnt < BIT_WIDTH; bit_cnt = bit_cnt + 1) begin: bit_loop
            always_comb begin
                bit_val[bit_cnt] = abs_value[bit_cnt] ? ((2 ** (bit_cnt + RESO)) * MUL / DIV) : 0;
            end
        end

        /***************************************************************
         * 全ビットの値を加算
         ***************************************************************/
        logic [BIT_WIDTH+RESO-1:0] sum[0:BIT_WIDTH-1];
        genvar sum_cnt;
        for(sum_cnt = 0; sum_cnt < BIT_WIDTH; sum_cnt = sum_cnt + 1) begin: sum_loop
            if(sum_cnt == BIT_WIDTH-1) begin
                always_comb begin
                    sum[sum_cnt] = bit_val[sum_cnt];
                end
            end
            else begin
                always_comb begin
                    sum[sum_cnt] = sum[sum_cnt + 1] + bit_val[sum_cnt];
                end
            end
        end

        /***************************************************************
         * RESO のビット数だけ丸める
         ***************************************************************/
        wire [BIT_WIDTH-1:0] result = sum[0][$bits(sum[0])-1:RESO];

        /***************************************************************
         * 結果を格納
         ***************************************************************/
        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) OUT <= 0;
            else OUT <= sign ? (~(result - 1'd1)) : result;
        end
    end
`endif
endmodule

`default_nettype wire
