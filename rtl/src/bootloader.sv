//
// bootloader.sv
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
 * ブートローダー
 ***************************************************************/
module BOOTLOADER #(
    // FLASH から転送する領域
    parameter               XFER_DST_ADDR = 0,
    parameter               XFER_SIZE = 32768,
    parameter               XFER_SRC_ADDR = 24'h10_0000,

    // ClearMegarom が 1 の時にクリアする領域
    parameter               MEGAROM_CLEAR_ADDR = 0,
    parameter               MEGAROM_CLEAR_SIZE = 32768,

    // クリアする領域
    parameter               RAM_CLEAR_ADDR = 0,
    parameter               RAM_CLEAR_SIZE = 65536
) (
    input wire              RESET_n,
    input wire              CLK,
    RAM_IF.HOST             Ram,
    FLASH_IF.HOST           Flash,
    LED_IF.HOST             Led,
    input wire              ClearMegarom,
    output  reg             READY
);

    /***************************************************************
     * メモリ転送
     ***************************************************************/
    reg     [$bits(Ram.ADDR)-1:0]       Xfer_RamAddress;
    reg     [$bits(Flash.Address)-1:0]  Xfer_FlashAddress;
    reg     [$bits(Ram.ADDR)-1:0]       Xfer_Size;
    reg     [7:0]                       Xfer_Data;
    reg     [3:0]                       Xfer_Mode;
    reg                                 Xfer_Start;
    wire                                Xfer_Busy;
    reg                                 Xfer_MemoryHold;

    XFER_MEMORY u_xfer (
        .RESET_n,
        .CLK,
        .Flash,
        .Ram,

        .Xfer_RamAddress    (Xfer_RamAddress),
        .Xfer_FlashAddress  (Xfer_FlashAddress),
        .Xfer_Size          (Xfer_Size),
        .Xfer_Data          (Xfer_Data),
        .Xfer_Mode          (Xfer_Mode),
        .Xfer_Start         (Xfer_Start),
        .Xfer_Busy          (Xfer_Busy),
        .Xfer_MemoryHold    (Xfer_MemoryHold)
    );

    /***************************************************************
     * 
     ***************************************************************/
    enum logic [3:0] {
        STATE_LOAD_BIOS = 0,
        STATE_LOAD_BIOS_WAIT_START,
        STATE_LOAD_BIOS_WAIT_COMPLETE,
        STATE_CLEAR_MEGAROM,
        STATE_CLEAR_MEGAROM_WAIT_START,
        STATE_CLEAR_MEGAROM_WAIT_COMPLETE,
        STATE_CLEAR_MMAPPER,
        STATE_CLEAR_MMAPPER_WAIT_START,
        STATE_CLEAR_MMAPPER_WAIT_COMPLETE,
        STATE_COMPLETE
    } state;

    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            READY <= 0;

            Xfer_MemoryHold <= 1;

            Xfer_Start <= 0;
            state <= STATE_LOAD_BIOS;

            Led.State <= Led.LED_STATE_ON;

        end else begin
            case (state)
                //------------------------------
                // LOAD BIOS IMAGE 
                //------------------------------
                STATE_LOAD_BIOS:
                begin
                    Xfer_RamAddress <= XFER_DST_ADDR;
                    Xfer_FlashAddress <= XFER_SRC_ADDR;
                    Xfer_Size <= XFER_SIZE;
                    Xfer_Mode <= XFER_MEMORY.MODE_FLASH_TO_RAM;
                    Xfer_Start <= 1;
                    state <= STATE_LOAD_BIOS_WAIT_START;
                end
                STATE_LOAD_BIOS_WAIT_START:
                begin
                    if(Xfer_Busy)
                    begin
                        Xfer_Start <= 0;
                        state <= STATE_LOAD_BIOS_WAIT_COMPLETE;
                    end
                end
                STATE_LOAD_BIOS_WAIT_COMPLETE:
                begin
                    if(!Xfer_Busy)
                    begin
                        state <= STATE_CLEAR_MEGAROM;
                    end
                end

                //------------------------------
                // CLEAR MEGAROM 
                //------------------------------
                STATE_CLEAR_MEGAROM:
                begin
                    if(ClearMegarom) begin
                        Xfer_RamAddress <= MEGAROM_CLEAR_ADDR;
                        Xfer_Size <= MEGAROM_CLEAR_SIZE;
                        Xfer_Mode <= XFER_MEMORY.MODE_FILL;
                        Xfer_Data <= 8'hFF;
                        Xfer_Start <= 1;
                        state <= STATE_CLEAR_MEGAROM_WAIT_START;
                    end
                    else begin
                        state <= STATE_CLEAR_MMAPPER;
                    end
                end
                STATE_CLEAR_MEGAROM_WAIT_START:
                begin
                    if(Xfer_Busy)
                    begin
                        Xfer_Start <= 0;
                        state <= STATE_CLEAR_MEGAROM_WAIT_COMPLETE;
                    end
                end
                STATE_CLEAR_MEGAROM_WAIT_COMPLETE:
                begin
                    if(!Xfer_Busy)
                    begin
                        state <= STATE_CLEAR_MMAPPER;
                    end
                end

                //------------------------------
                // CLEAR MMAPPER 
                //------------------------------
                STATE_CLEAR_MMAPPER:
                begin
                    Xfer_RamAddress <= RAM_CLEAR_ADDR;
                    Xfer_Size <= RAM_CLEAR_SIZE;
                    Xfer_Mode <= XFER_MEMORY.MODE_FILL;
                    Xfer_Data <= 8'h00;
                    Xfer_Start <= 1;
                    state <= STATE_CLEAR_MMAPPER_WAIT_START;
                end
                STATE_CLEAR_MMAPPER_WAIT_START:
                begin
                    if(Xfer_Busy)
                    begin
                        Xfer_Start <= 0;
                        state <= STATE_CLEAR_MMAPPER_WAIT_COMPLETE;
                    end
                end
                STATE_CLEAR_MMAPPER_WAIT_COMPLETE:
                begin
                    if(!Xfer_Busy)
                    begin
                        state <= STATE_COMPLETE;
                    end
                end

                //------------------------------
                // COMPLETE 
                //------------------------------
                STATE_COMPLETE:
                begin
                    READY <= 1;
                    Xfer_MemoryHold <= 0;
                    Led.State <= Led.LED_STATE_OFF;
                end
            endcase
        end
    end

endmodule

/***********************************************************************
 * メモリ転送モジュール
 ***********************************************************************/
module XFER_MEMORY #(
    parameter   MODE_FILL           = 4'd0,     // FILL
    parameter   MODE_FLASH_TO_RAM   = 4'd1      // FLASH -> RAM
) (
    input   wire                                RESET_n,
    input   wire                                CLK,

    // FLASH
    RAM_IF.HOST                                 Ram,
    FLASH_IF.HOST                               Flash,

    input   wire    [$bits(Ram.ADDR)-1:0]       Xfer_RamAddress,
    input   wire    [$bits(Flash.Address)-1:0]  Xfer_FlashAddress,
    input   wire    [$bits(Ram.ADDR)-1:0]       Xfer_Size,
    input   wire    [7:0]                       Xfer_Data,
    input   wire    [3:0]                       Xfer_Mode,
    input   wire                                Xfer_Start,
    output  wire                                Xfer_Busy,
    input   wire                                Xfer_MemoryHold
);

    /***************************************************************
     * RAM
     ***************************************************************/
    reg     [8:0]       refresh_counter;                // 0~511

    /***************************************************************
     * state
     ***************************************************************/
    enum logic [3:0] {
        STATE_IDLE = 0,

        STATE_F2R_ENABLE_FLASH,
        STATE_F2R_READ_FLASH,
        STATE_F2R_REFRESH_RAM,
        STATE_F2R_WRITE_RAM,

        STATE_FILL,
        STATE_FILL_REFRESH_RAM,
        STATE_FILL_WRITE_RAM
    } state;

    reg     [$bits(Flash.Address)-1:0]  remain;

    enum logic [3:0] {
        SUB_STATE_IDLE = 0,

        SUB_STATE_REFRESH_RAM,
        SUB_STATE_WAIT_REFRESH_ACK,
        SUB_STATE_WAIT_REFRESH_BUSY,

        SUB_STATE_WRITE_RAM,
        SUB_STATE_WAIT_WRITE_ACK,
        SUB_STATE_WAIT_WRITE_BUSY,

        SUB_STATE_READ_FLASH,
        SUB_STATE_WAIT_FLASH_ACK,
        SUB_STATE_WAIT_FLASH_BUSY,

        SUB_STATE_ENABLE_FLASH,
        SUB_STATE_WAIT_ENABLE_ACK,
        SUB_STATE_WAIT_ENABLE_BUSY
    } sub_state;

    logic   [7:0]                   rw_data;
    logic   [$bits(Ram.ADDR)-1:0]   rw_addr;

    /***************************************************************
     * 
     ***************************************************************/
    assign          Xfer_Busy = state != STATE_IDLE;
    
    /***************************************************************
     * xfer 
     ***************************************************************/
    always @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            state <= STATE_IDLE;
            sub_state <= SUB_STATE_IDLE;

            Ram.RFSH_n <= 1;
            Ram.WE_n <= 1;
            Ram.OE_n <= 1;
            Ram.ADDR <= 0;
            Ram.DIN <= 0;

            Flash.Enable_n <= 1;
            Flash.REQ_n <= 1;
            Flash.Mode <= FLASH::FLASH_MODE_READ;

        end else begin

            if(sub_state != SUB_STATE_IDLE)
            begin
                case (sub_state)
                    //
                    // RAM をリフレッシュ
                    //
                    SUB_STATE_REFRESH_RAM:
                    begin
                        refresh_counter <= refresh_counter + 1'd1;
                        if(refresh_counter == 0)
                        begin
                            Ram.RFSH_n <= 0;
                            sub_state <= SUB_STATE_WAIT_REFRESH_ACK;
                        end else begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    SUB_STATE_WAIT_REFRESH_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WAIT_REFRESH_BUSY;
                            Ram.RFSH_n <= 1;
                        end
                    end

                    SUB_STATE_WAIT_REFRESH_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // RAM へ1バイト書き込み
                    //
                    SUB_STATE_WRITE_RAM:
                    begin
                        Ram.WE_n <= 0;
                        Ram.DIN <= rw_data;
                        Ram.ADDR <= rw_addr;
                        sub_state <= SUB_STATE_WAIT_WRITE_ACK;
                    end

                    SUB_STATE_WAIT_WRITE_ACK:
                    begin
                        if(Ram.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WAIT_WRITE_BUSY;
                            Ram.WE_n <= 1;
                            Ram.DIN <= 0;
                            Ram.ADDR <= 0;
                        end
                    end

                    SUB_STATE_WAIT_WRITE_BUSY:
                    begin
                        if(Ram.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                            remain = remain - 1'd1;
                            rw_addr <= rw_addr + 1'd1;
                        end
                    end

                    //
                    // FLASH から 1バイト取得
                    //
                    SUB_STATE_READ_FLASH:
                    begin
                        Flash.REQ_n <= 0;
                        sub_state <= SUB_STATE_WAIT_FLASH_ACK;
                    end

                    SUB_STATE_WAIT_FLASH_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WAIT_FLASH_BUSY;
                            Flash.REQ_n <= 1;
                        end
                    end

                    SUB_STATE_WAIT_FLASH_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end

                    //
                    // FLASH 読み出し開始
                    //
                    SUB_STATE_ENABLE_FLASH:
                    begin
                        Flash.Address <= Xfer_FlashAddress;
                        Flash.Enable_n <= 0;
                        Flash.Mode <= FLASH::FLASH_MODE_READ;
                        sub_state <= SUB_STATE_WAIT_ENABLE_ACK;
                    end

                    SUB_STATE_WAIT_ENABLE_ACK:
                    begin
                        if(Flash.ACK_n == 0)
                        begin
                            sub_state <= SUB_STATE_WAIT_ENABLE_BUSY;
                        end
                    end

                    SUB_STATE_WAIT_ENABLE_BUSY:
                    begin
                        if(Flash.ACK_n == 1)
                        begin
                            sub_state <= SUB_STATE_IDLE;
                        end
                    end
                endcase
            end else 

            case (state)
                STATE_IDLE:
                begin
                    Flash.Enable_n <= 1;
                    Flash.REQ_n <= 1;

                    Ram.RFSH_n <= 1;
                    Ram.OE_n <= 1;
                    Ram.WE_n <= 1;
                    Ram.DIN <= 0;
                    Ram.ADDR <= 0;

                    if(Xfer_Start)
                    begin
                        case (Xfer_Mode)
                            MODE_FILL:          state <= STATE_FILL;
                            MODE_FLASH_TO_RAM:  state <= STATE_F2R_ENABLE_FLASH;
                        endcase
                    end
                end

                //---------------------------------------
                // FLASH to RAM
                //---------------------------------------
                // FLASH 読み出し開始
                STATE_F2R_ENABLE_FLASH:
                begin
                    rw_addr <= Xfer_RamAddress;
                    remain <= Xfer_Size;
                    refresh_counter <= 0;
                    sub_state <= SUB_STATE_ENABLE_FLASH;
                    state <= STATE_F2R_READ_FLASH;
                end

                // FLASH から 1バイト取得
                STATE_F2R_READ_FLASH:
                begin
                    if(remain == 0)
                    begin
                        Flash.Enable_n <= 1;
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_READ_FLASH;
                        state <= STATE_F2R_REFRESH_RAM;
                    end
                end

                // RAM をリフレッシュ
                STATE_F2R_REFRESH_RAM:
                begin
                    sub_state <= SUB_STATE_REFRESH_RAM;
                    state <= STATE_F2R_WRITE_RAM;
                end

                // RAM に1バイト書く
                STATE_F2R_WRITE_RAM:
                begin
                    rw_data <= Flash.Data;
                    sub_state <= SUB_STATE_WRITE_RAM;
                    state <= STATE_F2R_READ_FLASH;
                end

                //---------------------------------------
                // メモリフィル
                //---------------------------------------
                STATE_FILL:
                begin
                    rw_addr <= Xfer_RamAddress;
                    remain <= Xfer_Size;
                    rw_data <= Xfer_Data;
                    refresh_counter <= 0;
                    state <= STATE_FILL_REFRESH_RAM;
                end

                // RAM をリフレッシュ
                STATE_FILL_REFRESH_RAM:
                begin
                    if(remain == 0)
                    begin
                        state <= STATE_IDLE;
                    end else begin
                        sub_state <= SUB_STATE_REFRESH_RAM;
                        state <= STATE_FILL_WRITE_RAM;
                    end
                end

                // RAM に1バイト書く
                STATE_FILL_WRITE_RAM:
                begin
                    sub_state <= SUB_STATE_WRITE_RAM;
                    state <= STATE_FILL_REFRESH_RAM;
                end

            endcase
        end
    end

endmodule

`default_nettype wire
