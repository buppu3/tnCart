//
// array_selector.sv
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

module ARRAY_SELECTOR #(
    parameter   COMB = 0,
    parameter   DEFAULT = 0,
    parameter   WIDTH = 8,
    parameter   COUNT = 8
) (
    input wire RESET_n,
    input wire CLK,
    input wire ENA,
    input wire  [WIDTH-1:0] IN[0:COUNT-1],
    input wire  [COUNT-1:0] OE,
    output wire [WIDTH-1:0] OUT
);

    if(COMB) begin
        assign OUT =    (!RESET_n            ) ? DEFAULT :
                        (COUNT >  0 && OE[ 0]) ? IN[ 0] :
                        (COUNT >  1 && OE[ 1]) ? IN[ 1] :
                        (COUNT >  2 && OE[ 2]) ? IN[ 2] :
                        (COUNT >  3 && OE[ 3]) ? IN[ 3] :
                        (COUNT >  4 && OE[ 4]) ? IN[ 4] :
                        (COUNT >  5 && OE[ 5]) ? IN[ 5] :
                        (COUNT >  6 && OE[ 6]) ? IN[ 6] :
                        (COUNT >  7 && OE[ 7]) ? IN[ 7] :
                        (COUNT >  8 && OE[ 8]) ? IN[ 8] :
                        (COUNT >  9 && OE[ 9]) ? IN[ 9] :
                        (COUNT > 10 && OE[10]) ? IN[10] :
                        (COUNT > 11 && OE[11]) ? IN[11] :
                        (COUNT > 12 && OE[12]) ? IN[12] :
                        (COUNT > 13 && OE[13]) ? IN[13] :
                        (COUNT > 14 && OE[14]) ? IN[14] :
                        (COUNT > 15 && OE[15]) ? IN[15] : DEFAULT;
    end
    else begin

        reg [WIDTH-1:0] ff_out;
        assign OUT = ff_out;

        always_ff @(posedge CLK or negedge RESET_n) begin
            if(!RESET_n) begin
                ff_out <= 0;
            end
            else if(ENA) begin
                // "for~disble" 使うと Fmax が下がるので、ループを展開しておく
                // integer i;
                // for(i = 0; i < COUNT; i = i + 1) begin:lp
                //     if(OE[i]) begin
                //         ff_out <= IN[i];
                //         disable lp;
                //     end
                // end
                if(COUNT > 0 && OE[0]) ff_out <= IN[0];
                else if(COUNT >  1 && OE[ 1]) ff_out <= IN[ 1];
                else if(COUNT >  2 && OE[ 2]) ff_out <= IN[ 2];
                else if(COUNT >  3 && OE[ 3]) ff_out <= IN[ 3];
                else if(COUNT >  4 && OE[ 4]) ff_out <= IN[ 4];
                else if(COUNT >  5 && OE[ 5]) ff_out <= IN[ 5];
                else if(COUNT >  6 && OE[ 6]) ff_out <= IN[ 6];
                else if(COUNT >  7 && OE[ 7]) ff_out <= IN[ 7];
                else if(COUNT >  8 && OE[ 8]) ff_out <= IN[ 8];
                else if(COUNT >  9 && OE[ 9]) ff_out <= IN[ 9];
                else if(COUNT > 10 && OE[10]) ff_out <= IN[10];
                else if(COUNT > 11 && OE[11]) ff_out <= IN[11];
                else if(COUNT > 12 && OE[12]) ff_out <= IN[12];
                else if(COUNT > 13 && OE[13]) ff_out <= IN[13];
                else if(COUNT > 14 && OE[14]) ff_out <= IN[14];
                else if(COUNT > 15 && OE[15]) ff_out <= IN[15];
                else                          ff_out <= DEFAULT;
            end
        end
    end
endmodule

`default_nettype wire
