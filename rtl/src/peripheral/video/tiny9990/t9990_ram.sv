//
// t9990_ram.sv
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
 * CPU MEM R/W I/F
 ***************************************************************/
interface T9990_CPU_MEM_IF;
    logic           OE_n;
    logic           WE_n;
    logic [18:0]    ADDR;
    logic [7:0]     DIN;
    logic [7:0]     DOUT;
    logic           BUSY;
    logic           REQ;
    modport CPU (
                    output  OE_n, WE_n, ADDR, DIN,
                    input   DOUT, BUSY, REQ//, ACK
                );
    modport RAM (
                    input   OE_n, WE_n, ADDR, DIN,
                    output  DOUT, BUSY, REQ//, ACK
                );
endinterface

/***************************************************************
 * CMD MEM R/W I/F
 ***************************************************************/
interface T9990_CMD_MEM_IF;
    logic           OE_n;
    logic           WE_n;
    logic [18:0]    ADDR;
    logic [31:0]    DIN;
    logic [31:0]    DOUT;
    logic           BUSY;
    logic           REQ;
    logic [2:0]     DIN_SIZE;
    logic [1:0]     ADDR_MODE;    // VRAM マッピングモード

    modport VDP (
                    output  OE_n, WE_n, ADDR, DIN, DIN_SIZE, ADDR_MODE,
                    input   DOUT, BUSY, REQ//, ACK
                );
    modport RAM (
                    input   OE_n, WE_n, ADDR, DIN, DIN_SIZE, ADDR_MODE,
                    output  DOUT, BUSY, REQ//, ACK
                );
endinterface

/***************************************************************
 * VDP CMD / CPU MEM R/W I/F
 ***************************************************************/
interface T9990_VC_MEM_IF;
    logic           REQ;
    logic           OE_n;
    logic           WE_n;
    logic [18:0]    ADDR;
    logic [31:0]    DIN;
    logic [2:0]     DIN_SIZE;
    logic           ACK;
    logic [31:0]    DOUT;
    logic [1:0]     ADDR_MODE;    // VRAM マッピングモード

    modport VDP (
                    input   REQ, ACK, DOUT,
                    output  OE_n, WE_n, ADDR, DIN, DIN_SIZE, ADDR_MODE
                );
    modport RAM (
                    output  REQ, ACK, DOUT,
                    input   OE_n, WE_n, ADDR, DIN, DIN_SIZE, ADDR_MODE
                );
endinterface

/***************************************************************
 * VDP MEM I/F
 ***************************************************************/
interface T9990_VDP_MEM_IF;
    logic           REQ;    // アドレス問い合わせフラグ
    logic [18:0]    ADDR;   // アドレス問い合わせに対する応答
    logic           ACK;    // メモリ読み出し完了フラグ
    logic [31:0]    DOUT;   // 読み出したデータ

    modport VDP (
                    input   REQ, ACK, DOUT,
                    output  ADDR
                );
    modport RAM (
                    output  REQ, ACK, DOUT,
                    input   ADDR
                );
endinterface

/***************************************************************
 * VDP コマンド / CPU メモリ振り分けモジュール
 ***************************************************************/
module T9990_URB_RAM_VC (
    input wire              RESET_n,
    input wire              CLK,
    input wire [1:0]        DSPM,
    T9990_VC_MEM_IF.VDP     VC_MEM,
    T9990_CPU_MEM_IF.RAM    CPU_MEM,
    T9990_CMD_MEM_IF.RAM    CMD_MEM
);
/*
    logic prev_cpu_we_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_cpu_we_n <= 1;
        else         prev_cpu_we_n <= CPU_MEM.WE_n;
    end

    logic prev_cpu_oe_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_cpu_oe_n <= 1;
        else         prev_cpu_oe_n <= CPU_MEM.OE_n;
    end

    logic prev_cmd_we_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_cmd_we_n <= 1;
        else         prev_cmd_we_n <= CMD_MEM.WE_n;
    end

    logic prev_cmd_oe_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_cmd_oe_n <= 1;
        else         prev_cmd_oe_n <= CMD_MEM.OE_n;
    end

    wire det_cpu_oe = prev_cpu_oe_n && !CPU_MEM.OE_n;
    wire det_cpu_we = prev_cpu_we_n && !CPU_MEM.WE_n;
    wire det_cmd_oe = prev_cmd_oe_n && !CMD_MEM.OE_n;
    wire det_cmd_we = prev_cmd_we_n && !CMD_MEM.WE_n;
*/

    enum logic[0:0] {
        STATE_IDLE,
        STATE_WAIT_ACK
    } state;

    enum logic[0:0] {
        SELECT_CPU,
        SELECT_CMD
    } select;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            VC_MEM.OE_n <= 1;
            VC_MEM.WE_n <= 1;
            VC_MEM.ADDR <= 0;
            VC_MEM.DIN  <= 0;
            VC_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;

            CPU_MEM.BUSY <= 0;
            CMD_MEM.BUSY <= 0;
            CPU_MEM.REQ <= 0;
            CMD_MEM.REQ <= 0;
            state <= STATE_IDLE;
            select <= SELECT_CPU;
        end
        else if(state == STATE_IDLE && !VC_MEM.REQ) begin
            CPU_MEM.REQ <= 0;
            CMD_MEM.REQ <= 0;
        end
        else if(state == STATE_IDLE && VC_MEM.REQ) begin
            if(!CPU_MEM.WE_n || !CPU_MEM.OE_n) begin
                state <= STATE_WAIT_ACK;
                select <= SELECT_CPU;

                CPU_MEM.BUSY <= 1;

                VC_MEM.OE_n <= CPU_MEM.OE_n;
                VC_MEM.WE_n <= CPU_MEM.WE_n;
                VC_MEM.ADDR <= CPU_MEM.ADDR;
                VC_MEM.DIN  <= {CPU_MEM.DIN,CPU_MEM.DIN,CPU_MEM.DIN,CPU_MEM.DIN};
                VC_MEM.DIN_SIZE <= RAM::DIN_SIZE_8;
                VC_MEM.ADDR_MODE <= DSPM;

                CPU_MEM.REQ <= 0;
                CMD_MEM.REQ <= 0;
            end
            else if(!CMD_MEM.WE_n || !CMD_MEM.OE_n) begin
                state <= STATE_WAIT_ACK;
                select <= SELECT_CMD;

                CMD_MEM.BUSY <= 1;

                VC_MEM.OE_n <= CMD_MEM.OE_n;
                VC_MEM.WE_n <= CMD_MEM.WE_n;
                VC_MEM.ADDR <= CMD_MEM.ADDR;
                VC_MEM.DIN  <= CMD_MEM.DIN;
                VC_MEM.DIN_SIZE <= CMD_MEM.DIN_SIZE;
                VC_MEM.ADDR_MODE <= CMD_MEM.ADDR_MODE;

                CPU_MEM.REQ <= 0;
                CMD_MEM.REQ <= 0;
            end
            else begin
                CPU_MEM.REQ <= 1;
                CMD_MEM.REQ <= 1;
            end
        end
        else if(state == STATE_WAIT_ACK && VC_MEM.ACK) begin
            state <= STATE_IDLE;

            case (select)
                SELECT_CPU: CPU_MEM.DOUT <= VC_MEM.DOUT[7:0];
                SELECT_CMD: CMD_MEM.DOUT <= VC_MEM.DOUT;
            endcase

            CPU_MEM.BUSY <= 0;
            CMD_MEM.BUSY <= 0;

            VC_MEM.OE_n <= 1;
            VC_MEM.WE_n <= 1;
            VC_MEM.ADDR <= 0;
            VC_MEM.DIN  <= 0;
            VC_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
        end
    end
endmodule

/***************************************************************
 * 各モジュールの要求をまとめる
 ***************************************************************/
module T9990_RAM (
    input wire              RESET_n,
    input wire              CLK,
    input wire              CLK_21M_EN,

    // RAM I/F
    output reg              RAM_OE_n,
    output reg              RAM_WE_n,
    output reg              RAM_RFSH_n,
    output reg [18:0]       RAM_ADDR,
    output reg [31:0]       RAM_DIN,
    output reg [2:0]        RAM_DIN_SIZE,
    input wire [31:0]       RAM_DOUT,
    input wire              RAM_ACK_n,

    output reg              VMREQ_n,

    //
    T9990_MEM_TIMING.RAM    TIMING,

    input wire [1:0]        DSPM,

    //
    T9990_VC_MEM_IF.RAM     VC_MEM,
    T9990_VDP_MEM_IF.RAM    SP_MEM,
    T9990_VDP_MEM_IF.RAM    BP_MEM,
    T9990_VDP_MEM_IF.RAM    PA_MEM,
    T9990_VDP_MEM_IF.RAM    PB_MEM
);
    wire [18:0] addr = timing_state == T9990_MEM_CONNECT::RAM_VC ? VC_MEM.ADDR :
                       timing_state == T9990_MEM_CONNECT::RAM_SP ? SP_MEM.ADDR :
                       timing_state == T9990_MEM_CONNECT::RAM_BP ? BP_MEM.ADDR :
                       timing_state == T9990_MEM_CONNECT::RAM_PA ? PA_MEM.ADDR :
                       timing_state == T9990_MEM_CONNECT::RAM_PB ? PB_MEM.ADDR : 0;

    wire [2:0] dsize = timing_state == T9990_MEM_CONNECT::RAM_VC ? VC_MEM.DIN_SIZE : RAM::DIN_SIZE_32;

    wire [1:0] dspm = timing_state == T9990_MEM_CONNECT::RAM_VC ? VC_MEM.ADDR_MODE : DSPM;

    wire is_P2_PGT = (addr[18:15] != 4'b1111);
    wire is_P2_SPAT = (addr[14] == 0);

    assign VC_MEM.REQ = TIMING.STATE == T9990_MEM_CONNECT::RAM_VC ? TIMING.PREP : 0;
    assign SP_MEM.REQ = TIMING.STATE == T9990_MEM_CONNECT::RAM_SP ? TIMING.PREP : 0;
    assign BP_MEM.REQ = TIMING.STATE == T9990_MEM_CONNECT::RAM_BP ? TIMING.PREP : 0;
    assign PA_MEM.REQ = TIMING.STATE == T9990_MEM_CONNECT::RAM_PA ? TIMING.PREP : 0;
    assign PB_MEM.REQ = TIMING.STATE == T9990_MEM_CONNECT::RAM_PB ? TIMING.PREP : 0;

    logic [$bits(TIMING.STATE)-1:0] timing_state;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)         timing_state <= T9990_MEM_CONNECT::RAM_XX;
        else if(TIMING.PREP) timing_state <= TIMING.STATE;
    end

    localparam ACK_VC    = 0;
    localparam ACK_SP    = 1;
    localparam ACK_BP    = 2;
    localparam ACK_PA    = 3;
    localparam ACK_PB    = 4;
    localparam ACK_RF    = 5;
    localparam ACK_COUNT = 6;

    localparam [ACK_COUNT-1:0] ack_bits_none = 6'b000000;
    localparam [ACK_COUNT-1:0] ack_bits_vc   = 6'b000001;
    localparam [ACK_COUNT-1:0] ack_bits_sp   = 6'b000010;
    localparam [ACK_COUNT-1:0] ack_bits_bp   = 6'b000100;
    localparam [ACK_COUNT-1:0] ack_bits_pa   = 6'b001000;
    localparam [ACK_COUNT-1:0] ack_bits_pb   = 6'b010000;
    localparam [ACK_COUNT-1:0] ack_bits_rf   = 6'b100000;

    logic [ACK_COUNT-1:0] ack = ack_bits_none;

    enum logic [1:0] {
        STATE_WAIT_REQ,
        STATE_WAIT_ACK,
        STATE_WAIT_BUSY
    } state;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            state <= STATE_WAIT_REQ;
            RAM_ADDR <= 0;
            RAM_OE_n <= 1;
            RAM_WE_n <= 1;
            RAM_RFSH_n <= 1;
            RAM_DIN  <= 0;
            RAM_DIN_SIZE  <= RAM::DIN_SIZE_32;
            ack <= ack_bits_none;
            VC_MEM.ACK <= 0;
            SP_MEM.ACK <= 0;
            BP_MEM.ACK <= 0;
            PA_MEM.ACK <= 0;
            PB_MEM.ACK <= 0;
            VMREQ_n <= 1;
        end
        else if(state == STATE_WAIT_REQ) begin
            if(TIMING.EXEC) begin
                case (timing_state)
                    default:                     state <= STATE_WAIT_REQ;
                    T9990_MEM_CONNECT::RAM_VC:   state <= (VC_MEM.OE_n && VC_MEM.WE_n) ? STATE_WAIT_REQ : STATE_WAIT_ACK;
                    T9990_MEM_CONNECT::RAM_SP:   state <= STATE_WAIT_ACK;
                    T9990_MEM_CONNECT::RAM_BP:   state <= STATE_WAIT_ACK;
                    T9990_MEM_CONNECT::RAM_PA:   state <= STATE_WAIT_ACK;
                    T9990_MEM_CONNECT::RAM_PB:   state <= STATE_WAIT_ACK;
                    T9990_MEM_CONNECT::RAM_RF:   state <= STATE_WAIT_ACK;
                endcase

                // memory address mapping
                //
                // SDRAM    P2,Bx   P1      V9990 VRAM
                // ---------------------------------------
                // 00000h   00000h  00000h  VRAM0, 00000h
                // 00001h   00001h  40000h  VRAM1, 00000h
                // 00002h   00002h  00001h  VRAM0, 00001h
                // 00003h   00003h  40001h  VRAM1, 00001h
                // 00004h   00004h  00002h  VRAM0, 00002h
                // 00005h   00005h  40002h  VRAM1, 00002h
                // 00006h   00006h  00003h  VRAM0, 00003h
                // 00007h   00007h  40003h  VRAM1, 00003h

                if(dspm[1]) begin
                    // Bx
                    RAM_ADDR <= addr;
                end
                else if(dspm[0]) begin
                    // P2
                    //RAM_ADDR <= addr;
                    if(is_P2_PGT)       RAM_ADDR <= addr;                                                     // PGT (00000h~77FFFh)
                    else if(is_P2_SPAT) RAM_ADDR <= {addr[17:16], 1'b1, addr[14:0], 1'b0};                    // SPAT(78000h~7BFFFh) -> 3C000h~3FFFFh, VRAM0
                    else                RAM_ADDR <= {addr[17:0], (dsize == RAM::DIN_SIZE_8) ? 1'b1 : 1'b0};   // PNT (7C000h~7FFFFh) -> 3C000h~3FFFFh, VRAM1
                end
                else begin
                    // P1
                    RAM_ADDR <= {addr[17:0], (VC_MEM.DIN_SIZE == RAM::DIN_SIZE_8) ? addr[18] : 1'b0};
                end

                if(dsize != RAM::DIN_SIZE_32) begin
                    RAM_DIN_SIZE <= dsize;
                end
                else if(dspm[1]) begin
                    // Bx
                    RAM_DIN_SIZE <= dsize;
                end
                else if(dspm[0]) begin
                    // P2
                    //RAM_DIN_SIZE <= dsize;
                    if(is_P2_PGT)       RAM_DIN_SIZE <= dsize;                // PGT (00000h~77FFFh)
                    else if(is_P2_SPAT) RAM_DIN_SIZE <= RAM::DIN_SIZE_32_E;   // SPAT(78000h~7BFFFh) -> 3C000h~3FFFFh, VRAM0
                    else                RAM_DIN_SIZE <= RAM::DIN_SIZE_32_O;   // PNT (7C000h~7FFFFh) -> 3C000h~3FFFFh, VRAM1
                end
                else begin
                    // P1
                    RAM_DIN_SIZE <= addr[18] ? RAM::DIN_SIZE_32_O : RAM::DIN_SIZE_32_E;
                end

                case (timing_state)
                    default:                     RAM_OE_n <= 1;
                    T9990_MEM_CONNECT::RAM_VC:   RAM_OE_n <= VC_MEM.OE_n;
                    T9990_MEM_CONNECT::RAM_SP:   RAM_OE_n <= 0;
                    T9990_MEM_CONNECT::RAM_BP:   RAM_OE_n <= 0;
                    T9990_MEM_CONNECT::RAM_PA:   RAM_OE_n <= 0;
                    T9990_MEM_CONNECT::RAM_PB:   RAM_OE_n <= 0;
                    T9990_MEM_CONNECT::RAM_RF:   RAM_OE_n <= 1;
                endcase

                case (timing_state)
                    default:                     RAM_WE_n <= 1;
                    T9990_MEM_CONNECT::RAM_VC:   RAM_WE_n <= VC_MEM.WE_n;
                    T9990_MEM_CONNECT::RAM_SP:   RAM_WE_n <= 1;
                    T9990_MEM_CONNECT::RAM_BP:   RAM_WE_n <= 1;
                    T9990_MEM_CONNECT::RAM_PA:   RAM_WE_n <= 1;
                    T9990_MEM_CONNECT::RAM_PB:   RAM_WE_n <= 1;
                    T9990_MEM_CONNECT::RAM_RF:   RAM_WE_n <= 1;
                endcase

                case (timing_state)
                    default:                     RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_VC:   RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_SP:   RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_BP:   RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_PA:   RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_PB:   RAM_RFSH_n <= 1;
                    T9990_MEM_CONNECT::RAM_RF:   RAM_RFSH_n <= 0;
                endcase

                case (timing_state)
                    default:                     RAM_DIN <= 0;
                    T9990_MEM_CONNECT::RAM_VC:   RAM_DIN <= VC_MEM.DIN;
                    T9990_MEM_CONNECT::RAM_SP:   RAM_DIN <= 0;
                    T9990_MEM_CONNECT::RAM_BP:   RAM_DIN <= 0;
                    T9990_MEM_CONNECT::RAM_PA:   RAM_DIN <= 0;
                    T9990_MEM_CONNECT::RAM_PB:   RAM_DIN <= 0;
                    T9990_MEM_CONNECT::RAM_RF:   RAM_DIN <= 0;
                endcase

                case (timing_state)
                    default:                     ack <= ack_bits_none;
                    T9990_MEM_CONNECT::RAM_VC:   ack <= (VC_MEM.OE_n && VC_MEM.WE_n) ? ack_bits_none : ack_bits_vc;
                    T9990_MEM_CONNECT::RAM_SP:   ack <= ack_bits_sp;
                    T9990_MEM_CONNECT::RAM_BP:   ack <= ack_bits_bp;
                    T9990_MEM_CONNECT::RAM_PA:   ack <= ack_bits_pa;
                    T9990_MEM_CONNECT::RAM_PB:   ack <= ack_bits_pb;
                    T9990_MEM_CONNECT::RAM_RF:   ack <= ack_bits_rf;
                endcase

                VC_MEM.ACK <= 0;
                SP_MEM.ACK <= 0;
                BP_MEM.ACK <= 0;
                PA_MEM.ACK <= 0;
                PB_MEM.ACK <= 0;

                VMREQ_n <= 0;
            end
            else begin
                state <= STATE_WAIT_REQ;

                RAM_ADDR <= RAM_ADDR;
                RAM_OE_n <= 1;
                RAM_WE_n <= 1;
                RAM_RFSH_n <= 1;
                RAM_DIN  <= RAM_DIN;
                RAM_DIN_SIZE  <= RAM_DIN_SIZE;

                ack <= ack_bits_none;

                VC_MEM.ACK <= 0;
                SP_MEM.ACK <= 0;
                BP_MEM.ACK <= 0;
                PA_MEM.ACK <= 0;
                PB_MEM.ACK <= 0;

                VMREQ_n <= 1;
            end
        end
        else if(state == STATE_WAIT_ACK) begin
            if(!RAM_ACK_n) begin
                state <= STATE_WAIT_BUSY;

                RAM_ADDR <= RAM_ADDR;
                RAM_OE_n <= 1;
                RAM_WE_n <= 1;
                RAM_RFSH_n <= 1;
                RAM_DIN  <= RAM_DIN;
                RAM_DIN_SIZE  <= RAM_DIN_SIZE;

                ack <= ack;

                VC_MEM.ACK <= 0;
                SP_MEM.ACK <= 0;
                BP_MEM.ACK <= 0;
                PA_MEM.ACK <= 0;
                PB_MEM.ACK <= 0;

                VMREQ_n <= 0;
            end
            else begin
                state <= STATE_WAIT_ACK;

                RAM_ADDR <= RAM_ADDR;
                RAM_OE_n <= RAM_OE_n;
                RAM_WE_n <= RAM_WE_n;
                RAM_RFSH_n <= RAM_RFSH_n;
                RAM_DIN  <= RAM_DIN;
                RAM_DIN_SIZE  <= RAM_DIN_SIZE;

                ack <= ack;

                VC_MEM.ACK <= 0;
                SP_MEM.ACK <= 0;
                BP_MEM.ACK <= 0;
                PA_MEM.ACK <= 0;
                PB_MEM.ACK <= 0;

                VMREQ_n <= 0;
            end
        end
        else if(state == STATE_WAIT_BUSY) begin
            if(RAM_ACK_n) begin
                state <= STATE_WAIT_REQ;

                RAM_ADDR <= RAM_ADDR;
                RAM_OE_n <= 1;
                RAM_WE_n <= 1;
                RAM_RFSH_n <= 1;
                RAM_DIN  <= RAM_DIN;
                RAM_DIN_SIZE  <= RAM_DIN_SIZE;

                ack <= ack_bits_none;

                VC_MEM.ACK <= ack[ACK_VC];
                SP_MEM.ACK <= ack[ACK_SP];
                BP_MEM.ACK <= ack[ACK_BP];
                PA_MEM.ACK <= ack[ACK_PA];
                PB_MEM.ACK <= ack[ACK_PB];

                if(ack[ACK_VC]) VC_MEM.DOUT <= RAM_DOUT;
                if(ack[ACK_SP]) SP_MEM.DOUT <= RAM_DOUT;
                if(ack[ACK_BP]) BP_MEM.DOUT <= RAM_DOUT;
                if(ack[ACK_PA]) PA_MEM.DOUT <= RAM_DOUT;
                if(ack[ACK_PB]) PB_MEM.DOUT <= RAM_DOUT;

                VMREQ_n <= 1;
            end
            else begin
                state <= STATE_WAIT_BUSY;

                RAM_ADDR <= RAM_ADDR;
                RAM_OE_n <= 1;
                RAM_WE_n <= 1;
                RAM_RFSH_n <= 1;
                RAM_DIN  <= RAM_DIN;
                RAM_DIN_SIZE  <= RAM_DIN_SIZE;

                ack <= ack;

                VC_MEM.ACK <= 0;
                SP_MEM.ACK <= 0;
                BP_MEM.ACK <= 0;
                PA_MEM.ACK <= 0;
                PB_MEM.ACK <= 0;

                VMREQ_n <= 0;
            end
        end
    end

endmodule

`default_nettype wire
