//
// limiter.sv
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

module LIMITER #(
    parameter   IN_WIDTH = 11,
    parameter   OUT_WIDTH = 10
)(
    input wire [IN_WIDTH-1:0] IN,
    output wire [OUT_WIDTH-1:0] OUT
);

    localparam [IN_WIDTH-OUT_WIDTH:0] sign_bits = -1;
    localparam [IN_WIDTH-OUT_WIDTH:0] zero_bits = 0;
    localparam [OUT_WIDTH - 1 : 0] max = ( (2**(OUT_WIDTH-1)) - 1);
    localparam [OUT_WIDTH - 1 : 0] min = (-(2**(OUT_WIDTH-1))    );

    assign OUT = (IN[IN_WIDTH-1:OUT_WIDTH-1] == sign_bits) ? IN[OUT_WIDTH-1:0] :
                 (IN[IN_WIDTH-1:OUT_WIDTH-1] == zero_bits) ? IN[OUT_WIDTH-1:0] :
                 (IN[IN_WIDTH-1])                          ? min : max;
endmodule

module LIMITER_FF #(
    parameter   IN_WIDTH = 11,
    parameter   OUT_WIDTH = 10
)(
    input wire                  CLK,
    input wire                  RESET_n,
    input wire [IN_WIDTH-1:0]   IN,
    output reg [OUT_WIDTH-1:0]  OUT
);

    localparam [IN_WIDTH-OUT_WIDTH:0] sign_bits = -1;
    localparam [IN_WIDTH-OUT_WIDTH:0] zero_bits = 0;
    localparam [OUT_WIDTH - 1 : 0] max = ( (2**(OUT_WIDTH-1)) - 1);
    localparam [OUT_WIDTH - 1 : 0] min = (-(2**(OUT_WIDTH-1))    );

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)    OUT <= 0;
        else            OUT <= (IN[IN_WIDTH-1:OUT_WIDTH-1] == sign_bits) ? IN[OUT_WIDTH-1:0] :
                               (IN[IN_WIDTH-1:OUT_WIDTH-1] == zero_bits) ? IN[OUT_WIDTH-1:0] :
                               (IN[IN_WIDTH-1])                          ? min : max;
    end

endmodule

`default_nettype wire
