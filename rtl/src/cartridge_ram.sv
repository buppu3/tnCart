//
// cartridge_ram.sv
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
 * RAM カードリッジ
 ***************************************************************/
module CARTRIDGE_RAM #(
    parameter [23:0]        RAM_ADDR = 0
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram
);
    localparam [7:0] IO_BASE_ADDR = 8'hFC;

    /***************************************************************
     * I/O ライト検出
     ***************************************************************/
    wire io_wr_n = Bus.IORQ_n || Bus.WR_n;
    logic prev_io_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_io_wr_n <= 1;
        else if(!Bus.RESET_n) prev_io_wr_n <= 1;
        else                  prev_io_wr_n <= io_wr_n;
    end
    wire det_io_wr = prev_io_wr_n && !io_wr_n;

    /***************************************************************
     * バンクレジスタ
     ***************************************************************/
    logic [7:0] bank[0:3];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Bus.RESET_n) begin
            bank[0] <= 3;
            bank[1] <= 2;
            bank[2] <= 1;
            bank[3] <= 0;
        end
        else if(det_io_wr && Bus.ADDR[7:2] == IO_BASE_ADDR[7:2]) begin
            bank[Bus.ADDR[1:0]] <= Bus.DIN;
        end
    end

    /***************************************************************
     * メモリ R/W 検出
     ***************************************************************/
    wire mem_rd_n = Bus.MERQ_n || Bus.SLTSL_n || Bus.RD_n;
    wire mem_wr_n = Bus.MERQ_n || Bus.SLTSL_n || Bus.WR_n;
    logic prev_mem_rd_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_mem_rd_n <= 1;
        else if(!Bus.RESET_n) prev_mem_rd_n <= 1;
        else                  prev_mem_rd_n <= mem_rd_n;
    end
    logic prev_mem_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_mem_wr_n <= 1;
        else if(!Bus.RESET_n) prev_mem_wr_n <= 1;
        else                  prev_mem_wr_n <= mem_wr_n;
    end
    wire det_mem_rd = prev_mem_rd_n && !mem_rd_n;
    wire det_mem_wr = prev_mem_wr_n && !mem_wr_n;

    /***************************************************************
     * RD_n または WR_n の立下りでアドレスを保持
     ***************************************************************/
    logic [$bits(Bus.ADDR)-1:0] save_addr;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                      save_addr <= 0;
        else if(!Bus.RESET_n)             save_addr <= 0;
        else if(det_mem_wr)               save_addr <= Bus.ADDR;
    end
    wire [$bits(Bus.ADDR)-1:0] addr = (!mem_rd_n || det_mem_wr) ? Bus.ADDR : save_addr;

    /***************************************************************
     * メモリ R/W
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.DOUT <= 0;
            Bus.BUSDIR_n <= 1;

            Ram.ADDR <= 0;
            Ram.DIN <= 0;
            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
            Ram.OE_n <= 1;
            Ram.WE_n <= 1;
            Ram.RFSH_n <= 1;
        end
        else if(!Bus.RESET_n) begin
            Bus.DOUT <= 0;
            Bus.BUSDIR_n <= 1;

            Ram.ADDR <= 0;
            Ram.DIN <= 0;
            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
            Ram.OE_n <= 1;
            Ram.WE_n <= 1;
            Ram.RFSH_n <= Bus.RFSH_n;
        end
        else begin
            Bus.DOUT <= mem_rd_n ? 0 : Ram.DOUT[7:0];
            Bus.BUSDIR_n <= mem_rd_n;

            Ram.ADDR <= (mem_wr_n & mem_rd_n) ? 0 : (RAM_ADDR + {2'b00, bank[addr[15:14]], addr[13:0]});
//            Ram.ADDR <= (mem_wr_n & mem_rd_n) ? 0 : (RAM_ADDR + {8'h00, addr[15:0]});
            Ram.DIN <= mem_wr_n ? 0 : Bus.DIN;
            Ram.DIN_SIZE <= RAM::DIN_SIZE_8;
            Ram.OE_n <= mem_rd_n;
            Ram.WE_n <= mem_wr_n;
            Ram.RFSH_n <= Bus.RFSH_n;
        end
    end

    /***************************************************************
     * 未使用信号
     ***************************************************************/
    assign  Bus.INT_n = 1;
    assign  Bus.WAIT_n = 1;

`ifdef DEBUG
    /***************************************************************
     * デバグ用
     ***************************************************************/
    wire debug_wr_n = Bus.MERQ_n || Bus.WR_n;
    logic prev_debug_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_debug_wr_n <= 1;
        else if(!Bus.RESET_n) prev_debug_wr_n <= 1;
        else                  prev_debug_wr_n <= debug_wr_n;
    end
    wire det_debug_wr = prev_debug_wr_n && !debug_wr_n;
    reg [7:0] debug_data;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          debug_data <= 0;
        else if(det_debug_wr && Bus.ADDR == 16'hFCC7) debug_data <= Bus.DIN;
    end
`endif

endmodule

`default_nettype wire
