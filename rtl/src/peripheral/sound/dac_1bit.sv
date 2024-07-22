//
// dac_1bit.sv
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
`define DAC_USE_ALU

/***********************************************************************
 * 1bit DAC module
 *  1ビット DAC 出力を行う
 ***********************************************************************/
module DAC_1BIT (
    input wire                  CLK,            // クロック
    input wire                  CLK_EN,
    input wire                  RESET_n,        // リセット信号

    SOUND_IF.IN                 IN,             // 再生信号

    output reg                  OUT             // 出力ポート
);
`ifdef DAC_USE_ALU
    localparam BIT_WIDTH = $bits(IN.Signal);

    /***************************************************************
     * 加算 alu_out = in + 512 - (alu_out[9] ? 1024 : 0);
     ***************************************************************/
    wire [53:0] alu_sign = 54'd0 - 54'd1;
    wire [53:0] alu_zero = 54'd0;
    wire [53:0] alu_in = {IN.Signal[BIT_WIDTH-1] ? alu_sign[53:BIT_WIDTH] : alu_zero[53:BIT_WIDTH], IN.Signal};
    wire [10:0] alu_out;
    wire [42:0] alu_out_dummy;
    wire [54:0] alu_caso;
    wire [53:0] alu_offset = 2 ** (BIT_WIDTH - 1);
    wire [53:0] alu_reset = 2 ** (BIT_WIDTH);

    ALU54D alu54d_inst (
        .DOUT({alu_out_dummy,alu_out}),
        .CASO(alu_caso),
        .A(alu_in),
        .B(alu_out[BIT_WIDTH] ? (alu_offset - alu_reset) : alu_offset),
        .ASIGN(1'b1),
        .BSIGN(1'b1),
        .CASI(55'd0),
        .ACCLOAD(1'b1),
        .CE(CLK_EN),
        .CLK(CLK),
        .RESET(!RESET_n)
    );

    defparam alu54d_inst.AREG = 1'b1;
    defparam alu54d_inst.BREG = 1'b0;
    defparam alu54d_inst.ASIGN_REG = 1'b0;
    defparam alu54d_inst.BSIGN_REG = 1'b0;
    defparam alu54d_inst.ACCLOAD_REG = 1'b0;
    defparam alu54d_inst.OUT_REG = 1'b1;
    defparam alu54d_inst.B_ADD_SUB = 1'b0;
    defparam alu54d_inst.C_ADD_SUB = 1'b0;
    defparam alu54d_inst.ALUD_MODE = 0;
    defparam alu54d_inst.ALU_RESET_MODE = "SYNC";

    /***************************************************************
     * 出力
     ***************************************************************/
    reg [10:0] alu_out2;
    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            OUT <= 0;
        end
        else if(CLK_EN) begin
            OUT <= alu_out[BIT_WIDTH];
        end
    end

`else

    /***************************************************************
     * バッファ
     ***************************************************************/
    localparam BIT_WIDTH = $bits(IN.Signal);
    localparam [BIT_WIDTH - 1 : 0] OFFSET = (2 ** (BIT_WIDTH - 1));

    logic [BIT_WIDTH-1:0]   in0;
    logic [BIT_WIDTH-1:0]   in1;
    logic [BIT_WIDTH-1:0]   in_unsigned;

    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            in0 <= 0;
            in1 <= 0;
        end
        else if(CLK_EN) begin
            in0 <= IN.Signal;
            in1 <= in0;
            in_unsigned <= in1 + OFFSET;
        end
    end

    /***************************************************************
     * 加算
     ***************************************************************/
    reg     [BIT_WIDTH:0]   sum;
    wire    [BIT_WIDTH:0]   added = sum + in_unsigned;
    wire                    overflow = added[BIT_WIDTH];

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n) begin
            sum <= 0;
            OUT <= 0;
        end
        else if(CLK_EN) begin
            sum <= added[BIT_WIDTH-1:0];
            OUT <= overflow;
        end
    end
`endif
endmodule


`default_nettype wire
