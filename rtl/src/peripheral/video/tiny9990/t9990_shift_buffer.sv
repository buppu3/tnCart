//
// t9990_shift_buffer.sv
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

module T9990_SHIFT_BUFFER #(
    parameter BIT_WIDTH         = 32,
    parameter COUNT             = 32
) (
    input wire                          RESET_n,
    input wire                          CLK,
    input wire                          DCLK_EN,
    input wire                          DISABLE,
    input wire [$clog2(COUNT)-1:0]      OFFSET,
    input wire [BIT_WIDTH-1:0]          IN,
    output reg [BIT_WIDTH-1:0]          OUT
);
    reg [BIT_WIDTH-1:0] buffer[0:31] /* synthesis syn_ramstyle = "block_ram" */;
    logic [4:0] in_index;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            in_index <= 0;
        end
        else if(DCLK_EN) begin
            in_index <= in_index + 1'd1;
        end
    end

    always_ff @(posedge CLK) begin
        if(DCLK_EN) begin
            buffer[in_index] <= IN;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            OUT <= 0;
        end
        else if(DISABLE) begin
        end
        else if(!DCLK_EN) begin
            OUT <= buffer[(in_index + OFFSET) & 5'd31];
        end
    end

endmodule

`default_nettype wire
