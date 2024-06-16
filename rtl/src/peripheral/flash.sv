//
// flash.sv
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

/***********************************************************************
 * アッテネーターパッケージ
 ***********************************************************************/
package FLASH;

    /***************************************************************
     * フラッシュ動作
     ***************************************************************/
    typedef enum logic[1:0]{
        FLASH_MODE_READ
        //FLASH_MODE_WRITE,
        //FLASH_MODE_ERASE
    } FLASH_MODE_t;

endpackage

/***********************************************************************
 * フラッシュメモリインターフェース
 ***********************************************************************/
interface FLASH_IF #(parameter ADDR_WIDTH = 24);
    logic [ADDR_WIDTH-1:0]  Address;        // 先頭アドレス
    FLASH::FLASH_MODE_t     Mode;           // モード
    logic                   Enable_n;       // 利用開始信号
    logic                   REQ_n;          // データ R/W 要求信号
    logic                   ACK_n;          // Enable_n, REQ_n に対する応答信号
    logic [7:0]             Data;           // リードデータ信号

    modport HOST  (output Address, Mode, Enable_n, REQ_n, input  ACK_n, Data);
    modport DEVICE(input  Address, Mode, Enable_n, REQ_n, output ACK_n, Data);
endinterface

/***********************************************************************
 * SPI FLASH メモリ module
 ***********************************************************************/
module FLASH_SPI (
    input   wire            CLK,            // 駆動クロック
    input   wire            RESET_n,        // リセット

    SPI_IF.HOST             SPI,            // SPI デバイスインターフェース
    FLASH_IF.DEVICE         Flash           // ホスト通信インターフェース
);
    localparam  CMD_WIDTH = 8;
    localparam  CMD_READ = 8'h03;

    enum logic[2:0] {
        STATE_IDLE,
        STATE_READ_SEND_CMD,
        STATE_READ_WAIT_CMD_ACK,
        STATE_READ_WAIT_CMD_BUSY,
        STATE_READ_WAIT_DATA_REQ,
        STATE_READ_WAIT_DATA_ACK,
        STATE_READ_WAIT_DATA_BUSY
    } state;

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            state <= STATE_IDLE;
            Flash.ACK_n <= 1;
            SPI.REQ <= 0;
            SPI.CS_n <= 1;

        end else begin
            if(state == STATE_IDLE)
            begin
                if(Flash.Enable_n == 0)
                begin
                    state <= STATE_READ_SEND_CMD;
                    SPI.CS_n <= 0;
                    Flash.ACK_n <= 0;
                end else begin
                    SPI.CS_n <= 1;
                end

            end else if(Flash.Enable_n == 1)
            begin
                state <= STATE_IDLE;
                SPI.CS_n <= 1;
                Flash.ACK_n <= 1;

            end else begin
                case (state)

                    //
                    // SEND FLASH READ COMMAND
                    //
                    STATE_READ_SEND_CMD:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(Flash.Address) + $bits(CMD_READ))] <= { CMD_READ, Flash.Address };
                        SPI.LEN <= $bits(Flash.Address) + $bits(CMD_READ);
                        SPI.REQ <= 1;
                        state <= STATE_READ_WAIT_CMD_ACK;
                    end

                    //
                    // WAIT CMD ACK
                    //
                    STATE_READ_WAIT_CMD_ACK:
                    begin
                        if(SPI.BUSY == 1)
                        begin
                            state <= STATE_READ_WAIT_CMD_BUSY;
                            SPI.REQ <= 0;
                        end
                    end

                    //
                    // WAIT CMD XFER
                    //
                    STATE_READ_WAIT_CMD_BUSY:
                    begin
                        if(SPI.BUSY == 0)
                        begin
                            state <= STATE_READ_WAIT_DATA_REQ;
                            Flash.ACK_n <= 1;
                        end
                    end

                    //
                    //
                    //
                    STATE_READ_WAIT_DATA_REQ:
                    begin
                        if(Flash.REQ_n == 0)
                        begin
                            Flash.ACK_n <= 0;

                            SPI.MOSI <= 0;
                            SPI.LEN <= $bits(Flash.Data);
                            SPI.REQ <= 1;
                            state <= STATE_READ_WAIT_DATA_ACK;
                        end
                    end

                    //
                    // WAIT DATA ACK
                    //
                    STATE_READ_WAIT_DATA_ACK:
                    begin
                        if(SPI.BUSY == 1)
                        begin
                            state <= STATE_READ_WAIT_DATA_BUSY;
                            SPI.REQ <= 0;
                        end
                    end

                    //
                    // WAIT XFER
                    //
                    STATE_READ_WAIT_DATA_BUSY:
                    begin
                        if(SPI.BUSY == 0)
                        begin
                            state <= STATE_READ_WAIT_DATA_REQ;
                            Flash.ACK_n <= 1;
                            Flash.Data <= SPI.MISO;
                        end
                    end

                endcase
            end
        end
    end
endmodule

`default_nettype wire
