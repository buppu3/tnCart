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
 * フラッシュパッケージ
 ***********************************************************************/
package FLASH;

    /***************************************************************
     * フラッシュ動作
     ***************************************************************/
    typedef enum logic[1:0]{
        FLASH_MODE_READ,
        FLASH_MODE_WRITE,
        FLASH_MODE_ERASE
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
    logic [7:0]             RData;          // リードデータ信号
    logic [7:0]             WData;          // ライトデータ信号

    modport HOST  (output Address, Mode, Enable_n, REQ_n, WData, input  ACK_n, RData);
    modport DEVICE(input  Address, Mode, Enable_n, REQ_n, WData, output ACK_n, RData);
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
    localparam       CMD_WIDTH          = 8;
    localparam [7:0] CMD_READ           = 8'h03;
    localparam [7:0] CMD_WRITE_ENABLE   = 8'h06;
    localparam [7:0] CMD_WRITE_DISABLE  = 8'h04;
    localparam [7:0] CMD_READ_STATUS    = 8'h05;
    localparam [7:0] CMD_PAGE_PROGRAM   = 8'h02;
    localparam [7:0] CMD_BLOCK_ERASE_64 = 8'hD8;

    localparam cs_delay = 10;
    logic [$clog2(cs_delay+1)-1:0] delay_count; // 一定時間待機用

    logic [$bits(Flash.Address)-1:0] addr;          // ライトアドレス
    logic [$bits(Flash.Address)-1:0] pp_addr;       // PageProgram アドレス
    logic pp_flag;                                  // PageProgram フラグ

    enum logic [4:0] {
        SUB_STATE_IDLE,
        SUB_STATE_EXIT,
        SUB_STATE_EXIT_COMP,

        SUB_STATE_WRITE_ENABLE,
        SUB_STATE_WRITE_ENABLE_SEND,

        SUB_STATE_WRITE_DISABLE,
        SUB_STATE_WRITE_DISABLE_SEND,

        SUB_STATE_WAIT_WIP,
        SUB_STATE_WAIT_WIP_INA1,
        SUB_STATE_WAIT_WIP_ACT,
        SUB_STATE_WAIT_WIP_SEND,
        SUB_STATE_WAIT_WIP_INA,
        SUB_STATE_WAIT_WIP_CHECK,

        SUB_STATE_ERASE,
        SUB_STATE_ERASE_SEND,

        SUB_STATE_PROGRAM,
        SUB_STATE_PROGRAM_SEND
    } sub_state;

    enum logic[3:0] {
        STATE_IDLE,

        STATE_READ_SEND_CMD,                // 開始
        STATE_READ_WAIT_DATA_REQ,           // データ待ち
        STATE_READ_WAIT_DATA_BUSY,          // 待機

        STATE_ERASE,                        // 開始
        STATE_ERASE_SEND,                   // イレーズ
        STATE_ERASE_WAIT,                   // イレーズ完了待ち
        STATE_ERASE_DISABLE,                // 終了

        STATE_WRITE,                        // 開始
        STATE_WRITE_WAIT_DATA,              // データ待ち, 終了チェック
        STATE_WRITE_CHECK,                  // ページ境界チェック
        STATE_WRITE_PP,                     // PageProgram
        STATE_WRITE_SEND_DATA,              // データ送信
        STATE_WRITE_END                     // 終了
    } state;

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            sub_state <= SUB_STATE_IDLE;
            state <= STATE_IDLE;
            Flash.ACK_n <= 1;
            SPI.REQ <= 0;
            SPI.CS_n <= 1;
            delay_count <= 0;
        end
        else if(delay_count != 0) begin
            delay_count <= delay_count - 1'd1;
        end
        else if(SPI.REQ) begin
            // SPI 転送開始待ち
            if(SPI.BUSY) SPI.REQ <= 0;
        end
        else if(SPI.BUSY) begin
            // SPI 転送完了待ち
        end
        else begin
            if(sub_state != 0) begin
                case (sub_state)
                    SUB_STATE_EXIT:
                    begin
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_EXIT_COMP;
                    end
                    SUB_STATE_EXIT_COMP:
                    begin
                        SPI.CS_n <= 1;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_IDLE;
                    end

                    /*****************************************************************************
                     * WRITE ENABLE
                     *****************************************************************************/
                    SUB_STATE_WRITE_ENABLE:
                    begin
                        SPI.CS_n <= 0;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WRITE_ENABLE_SEND;
                    end

                    SUB_STATE_WRITE_ENABLE_SEND:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(CMD_WRITE_ENABLE))] <= { CMD_WRITE_ENABLE };
                        SPI.LEN <= $bits(CMD_WRITE_ENABLE);
                        SPI.REQ <= 1;
                        sub_state <= SUB_STATE_EXIT;
                    end

                    /*****************************************************************************
                     * WRITE DISABLE
                     *****************************************************************************/
                    SUB_STATE_WRITE_DISABLE:
                    begin
                        SPI.CS_n <= 0;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WRITE_DISABLE_SEND;
                    end

                    SUB_STATE_WRITE_DISABLE_SEND:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(CMD_WRITE_DISABLE))] <= { CMD_WRITE_DISABLE };
                        SPI.LEN <= $bits(CMD_WRITE_DISABLE);
                        SPI.REQ <= 1;
                        sub_state <= SUB_STATE_EXIT;
                    end

                    /*****************************************************************************
                     * WAIT 
                     *****************************************************************************/
                    SUB_STATE_WAIT_WIP:
                    begin
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WAIT_WIP_INA1;
                    end
                    SUB_STATE_WAIT_WIP_INA1:
                    begin
                        SPI.CS_n <= 1;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WAIT_WIP_ACT;
                    end
                    SUB_STATE_WAIT_WIP_ACT:
                    begin
                        SPI.CS_n <= 0;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WAIT_WIP_SEND;
                    end
                    SUB_STATE_WAIT_WIP_SEND:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-(8 + $bits(CMD_READ_STATUS))] <= { CMD_READ_STATUS, 8'h00 };
                        SPI.LEN <= 8 + $bits(CMD_READ_STATUS);
                        SPI.REQ <= 1;
                        sub_state <= SUB_STATE_WAIT_WIP_INA;
                    end
                    SUB_STATE_WAIT_WIP_INA:
                    begin
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_WAIT_WIP_CHECK;
                    end
                    SUB_STATE_WAIT_WIP_CHECK:
                    begin
                        SPI.CS_n <= 1;
                        if(SPI.MISO[0]) begin
                            sub_state <= SUB_STATE_WAIT_WIP;
                        end
                        else begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    /*****************************************************************************
                     * ERASE
                     *****************************************************************************/
                    SUB_STATE_ERASE:
                    begin
                        SPI.CS_n <= 0;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_ERASE_SEND;
                    end
                    SUB_STATE_ERASE_SEND:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(Flash.Address) + $bits(CMD_BLOCK_ERASE_64))] <= { CMD_BLOCK_ERASE_64, Flash.Address };
                        SPI.LEN <= $bits(Flash.Address) + $bits(CMD_BLOCK_ERASE_64);
                        SPI.REQ <= 1;
                        sub_state <= SUB_STATE_EXIT;
                    end

                    /*****************************************************************************
                     * PROGRAM
                     *****************************************************************************/
                    SUB_STATE_PROGRAM:
                    begin
                        SPI.CS_n <= 0;
                        delay_count <= cs_delay;
                        sub_state <= SUB_STATE_PROGRAM_SEND;
                    end
                    SUB_STATE_PROGRAM_SEND:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(pp_addr) + $bits(CMD_PAGE_PROGRAM))] <= { CMD_PAGE_PROGRAM, pp_addr };
                        SPI.LEN <= $bits(pp_addr) + $bits(CMD_PAGE_PROGRAM);
                        SPI.REQ <= 1;
                        sub_state <= SUB_STATE_IDLE;
                    end
                endcase
            end
            else begin
                case (state)
                    /*****************************************************************************
                     * IDLE
                     *****************************************************************************/
                    STATE_IDLE:
                    begin
                        if(Flash.Enable_n != 0)
                        begin
                            SPI.CS_n <= 1;
                            Flash.ACK_n <= 1;
                        end
                        else if(Flash.Mode == FLASH::FLASH_MODE_READ) begin
                            state <= STATE_READ_SEND_CMD;
                            Flash.ACK_n <= 0;
                            SPI.CS_n <= 0;
                            delay_count <= cs_delay;
                        end
                        else if(Flash.Mode == FLASH::FLASH_MODE_ERASE) begin
                            state <= STATE_ERASE;
                            SPI.CS_n <= 1;
                            Flash.ACK_n <= 0;
                        end
                        else if(Flash.Mode == FLASH::FLASH_MODE_WRITE) begin
                            state <= STATE_WRITE;
                            SPI.CS_n <= 1;
                            Flash.ACK_n <= 0;
                        end
                        else begin
                            SPI.CS_n <= 1;
                            Flash.ACK_n <= 1;
                        end
                    end

                    /*****************************************************************************
                     * READ
                     *****************************************************************************/
                    //
                    // SEND FLASH READ COMMAND
                    //
                    STATE_READ_SEND_CMD:
                    begin
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-($bits(Flash.Address) + $bits(CMD_READ))] <= { CMD_READ, Flash.Address };
                        SPI.LEN <= $bits(Flash.Address) + $bits(CMD_READ);
                        SPI.REQ <= 1;
                        state <= STATE_READ_WAIT_DATA_REQ;
                    end

                    //
                    //
                    //
                    STATE_READ_WAIT_DATA_REQ:
                    begin
                        if(Flash.Enable_n != 0) begin
                            SPI.CS_n <= 1;
                            delay_count <= cs_delay;
                            state <= STATE_IDLE;
                        end
                        else if(Flash.REQ_n == 0)
                        begin
                            Flash.ACK_n <= 0;

                            SPI.MOSI <= 0;
                            SPI.LEN <= $bits(Flash.RData);
                            SPI.REQ <= 1;
                            state <= STATE_READ_WAIT_DATA_BUSY;
                        end
                        else begin
                            Flash.ACK_n <= 1;
                        end
                    end

                    //
                    // WAIT XFER
                    //
                    STATE_READ_WAIT_DATA_BUSY:
                    begin
                        if(Flash.REQ_n != 0)
                        begin
                            state <= STATE_READ_WAIT_DATA_REQ;
                            Flash.ACK_n <= 1;
                            Flash.RData <= SPI.MISO;
                        end
                    end

                    /*****************************************************************************
                     * ERASE
                     *****************************************************************************/
                    STATE_ERASE:
                    begin
                        if(Flash.Enable_n != 0 && Flash.WData == CMD_BLOCK_ERASE_64) begin
                            sub_state <= SUB_STATE_WRITE_ENABLE;
                            state <= STATE_ERASE_SEND;
                        end
                    end
                    STATE_ERASE_SEND:
                    begin
                        sub_state <= SUB_STATE_ERASE;
                        state <= STATE_ERASE_WAIT;
                    end
                    STATE_ERASE_WAIT:
                    begin
                        sub_state <= SUB_STATE_WAIT_WIP;
                        state <= STATE_ERASE_DISABLE;
                    end
                    STATE_ERASE_DISABLE:
                    begin
                        sub_state <= SUB_STATE_WRITE_DISABLE;
                        state <= STATE_IDLE;
                    end

                    /*****************************************************************************
                     * WRITE
                     *****************************************************************************/
                    STATE_WRITE:
                    begin
                        pp_flag <= 1;
                        addr <= Flash.Address;
                        state <= STATE_WRITE_WAIT_DATA;
                    end

                    STATE_WRITE_WAIT_DATA:
                    begin
                        if(Flash.Enable_n != 0) begin
                            sub_state <= SUB_STATE_WAIT_WIP;
                            state <= STATE_WRITE_END;
                        end
                        else if(Flash.REQ_n == 0) begin
                            Flash.ACK_n <= 0;
                            state <= STATE_WRITE_CHECK;
                        end
                        else begin
                            Flash.ACK_n <= 1;
                        end
                    end

                    STATE_WRITE_CHECK:
                    begin
                        if(Flash.REQ_n == 1) begin
                            // WriteEnable コマンド送信
                            if(pp_flag) begin
                                sub_state <= SUB_STATE_WRITE_ENABLE;
                            end
                            state <= STATE_WRITE_PP;
                        end
                    end

                    STATE_WRITE_PP:
                    begin
                        // PageProgram コマンド送信
                        if(pp_flag) begin
                            pp_addr <= addr;
                            pp_flag <= 0;
                            sub_state <= SUB_STATE_PROGRAM;
                        end

                        addr <= addr + 1'd1;
                        state <= STATE_WRITE_SEND_DATA;
                    end

                    STATE_WRITE_SEND_DATA:
                    begin
                        // データの送信
                        SPI.MOSI[$bits(SPI.MOSI)-1:$bits(SPI.MOSI)-8] <= Flash.WData;
                        SPI.LEN <= 8;
                        SPI.REQ <= 1;

                        // ページ境界なら WIP チェック
                        if(addr[7:0] == 0) begin
                            pp_flag <= 1;
                            sub_state <= SUB_STATE_WAIT_WIP;
                        end

                        state <= STATE_WRITE_WAIT_DATA;
                    end

                    STATE_WRITE_END:
                    begin
                        sub_state <= SUB_STATE_WRITE_DISABLE;
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end
endmodule

`default_nettype wire
