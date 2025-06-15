//
// signal.sv
//
// BSD 3-Clause License
// 
// Copyright (c) 2025, Shinobu Hashimoto
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

module NOR_Nbits #(
    parameter   COMB = 0,           // 組み合わせ回路で構成するか?
    parameter   ENA_FF_IN = 0,      // 入力を FF で受けるか？
    parameter   ENA_FF_OUT = 1,     // 出力に FF を入れるか?
    parameter   COUNT = 8,
    parameter   DEFAULT_VALUE = 1
) (
    input wire RESET_n,
    input wire CLK,
    input wire [COUNT-1:0] IN,
    input wire ENA,
    output wire OUT
);
    localparam _ena_ff_in = ENA_FF_IN & ~COMB;
    localparam _ena_ff_out = ENA_FF_OUT & ~COMB;

    wire [COUNT-1:0] w_in;

    if(_ena_ff_in) begin
        reg [COUNT-1:0] ff_in;
        assign w_in = ff_in;
        always_ff @(posedge CLK) ff_in <= IN;
    end
    else begin
        assign w_in = IN;
    end

    if(_ena_ff_out) begin
        reg ff_out;
        assign OUT = ff_out;

        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                ff_out <= DEFAULT_VALUE;
            end
            else if(ENA) begin
                ff_out <= w_in == 0;
            end
        end
    end
    else begin
        assign OUT = w_in == 0;
    end
endmodule

`default_nettype wire
