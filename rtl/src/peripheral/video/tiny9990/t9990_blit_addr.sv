//
// t9990_blit_addr.sv
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
 * アドレス計算
 ***************************************************************/
module T9990_BLIT_ADDR (
    input wire              CLK,
    input wire [1:0]        XIMM,
    input wire [1:0]        CLRM,
    input wire [10:0]       X,
    input wire [11:0]       Y,
    output reg [18:0]       ADDR
);
    always_ff @(posedge CLK) begin
        case ({CLRM, XIMM})
            {T9990_REG::CLRM_2BPP,  T9990_REG::XIMM_256 }:  ADDR <= {1'b0, Y[11:0], X[ 7:4], 2'b00};
            {T9990_REG::CLRM_2BPP,  T9990_REG::XIMM_512 }:  ADDR <= {      Y[11:0], X[ 8:4], 2'b00};
            {T9990_REG::CLRM_2BPP,  T9990_REG::XIMM_1024}:  ADDR <= {      Y[10:0], X[ 9:4], 2'b00};
            {T9990_REG::CLRM_2BPP,  T9990_REG::XIMM_2048}:  ADDR <= {      Y[ 9:0], X[10:4], 2'b00};

            {T9990_REG::CLRM_4BPP,  T9990_REG::XIMM_256 }:  ADDR <= {      Y[11:0], X[ 7:3], 2'b00};
            {T9990_REG::CLRM_4BPP,  T9990_REG::XIMM_512 }:  ADDR <= {      Y[10:0], X[ 8:3], 2'b00};
            {T9990_REG::CLRM_4BPP,  T9990_REG::XIMM_1024}:  ADDR <= {      Y[ 9:0], X[ 9:3], 2'b00};
            {T9990_REG::CLRM_4BPP,  T9990_REG::XIMM_2048}:  ADDR <= {      Y[ 8:0], X[10:3], 2'b00};

            {T9990_REG::CLRM_8BPP,  T9990_REG::XIMM_256 }:  ADDR <= {      Y[10:0], X[ 7:2], 2'b00};
            {T9990_REG::CLRM_8BPP,  T9990_REG::XIMM_512 }:  ADDR <= {      Y[ 9:0], X[ 8:2], 2'b00};
            {T9990_REG::CLRM_8BPP,  T9990_REG::XIMM_1024}:  ADDR <= {      Y[ 8:0], X[ 9:2], 2'b00};
            {T9990_REG::CLRM_8BPP,  T9990_REG::XIMM_2048}:  ADDR <= {      Y[ 7:0], X[10:2], 2'b00};

            {T9990_REG::CLRM_16BPP, T9990_REG::XIMM_256 }:  ADDR <= {      Y[ 9:0], X[ 7:1], 2'b00};
            {T9990_REG::CLRM_16BPP, T9990_REG::XIMM_512 }:  ADDR <= {      Y[ 8:0], X[ 8:1], 2'b00};
            {T9990_REG::CLRM_16BPP, T9990_REG::XIMM_1024}:  ADDR <= {      Y[ 7:0], X[ 9:1], 2'b00};
            {T9990_REG::CLRM_16BPP, T9990_REG::XIMM_2048}:  ADDR <= {      Y[ 6:0], X[10:1], 2'b00};
        endcase
    end
endmodule

`default_nettype wire
