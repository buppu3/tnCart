//
// t9990_blit.sv
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
 * VDP コマンド
 ***************************************************************/
module T9990_BLIT (
    input wire                  RESET_n,
    input wire                  CLK,
    input wire                  CLK_EN,

    T9990_CMD_MEM_IF.VDP        CMD_MEM,
    T9990_P2_CPU_TO_VDP_IF.VDP  P2_CPU_TO_VDP,
    T9990_P2_VDP_TO_CPU_IF.VDP  P2_VDP_TO_CPU,
    T9990_REGISTER_IF.VDP       REG,
    T9990_STATUS_IF.CMD         STATUS,

    // CONTROL
    input wire                  START          // 開始
);
    assign STATUS.BD = 0;
    assign STATUS.BX = 0;


    reg src_is_cpu;
    reg src_is_linear;
    reg src_is_xy;
    reg src_is_vdp;
    reg src_is_rom;
    reg src_is_char;
    reg dst_is_cpu;
    reg dst_is_linear;
    reg dst_is_xy;

    reg req_dst_vram;
    reg src_enable;
    reg [5:0] decode_count;
    reg [31:0] decode_data;

    reg [1:0]  SRC_CLRM;
    reg [18:0] SRC_X;
    reg [18:0] SRC_NX;
    reg [11:0] SRC_Y;
    reg [11:0] SRC_NY;
    reg        SRC_DIX;
    reg [1:0]  DST_CLRM;
    reg [18:0] DST_X;
    reg [18:0] DST_NX;
    reg [11:0] DST_Y;
    reg [11:0] DST_NY;
    reg        DST_DIX;

    reg [31:0] SRC_DATA;
    reg [31:0] DST_DATA;
    reg [31:0] WRT_DATA;

    reg FIFO_CLEAR;
    reg ENQUEUE;
    reg [4:0] ENQUEUE_COUNT;
    reg [31:0] ENQUEUE_DATA;
    reg DEQUEUE;
    reg [4:0] DEQUEUE_COUNT;
    wire [31:0] DEQUEUE_DATA2;
    wire [31:0] DEQUEUE_DATA4;
    wire [31:0] DEQUEUE_DATA8;
    wire [31:0] DEQUEUE_DATA16;
    wire [5:0] FREE_COUNT;
    wire [5:0] AVAIL_COUNT;
    T9990_BLIT_FIFO u_fifo (
        .RESET_n,
        .CLK,
        .CLK_EN,
        .CLRM(REG.CLRM),
        .FREE_COUNT,
        .AVAIL_COUNT,
        .CLEAR(FIFO_CLEAR),
        .ENQUEUE,
        .ENQUEUE_COUNT,
        .ENQUEUE_DATA,
        .DEQUEUE,
        .DEQUEUE_COUNT,
        .DEQUEUE_DATA2,
        .DEQUEUE_DATA4,
        .DEQUEUE_DATA8,
        .DEQUEUE_DATA16
    );

    reg [18:0] SRC_XY_ADDR;
    T9990_BLIT_ADDR u_src_addr (
        .CLK,
        .CLRM(SRC_CLRM),
        .XIMM(REG.XIMM),
        .X(SRC_X[10:0]),
        .Y(SRC_Y),
        .ADDR(SRC_XY_ADDR)
    );

    reg [18:0] DST_XY_ADDR;
    T9990_BLIT_ADDR u_dst_addr (
        .CLK,
        .CLRM(DST_CLRM),
        .XIMM(REG.XIMM),
        .X(DST_X[10:0]),
        .Y(DST_Y),
        .ADDR(DST_XY_ADDR)
    );

    reg [4:0] SRC_COUNT;
    T9990_BLIT_CALC_COUNT u_src_cnt (
        .CLK,
        .CPU_MODE(src_is_cpu),
        .CLRM(SRC_CLRM),
        .DIX(SRC_DIX),
        .OFFSET(SRC_X[3:0]),
        .REMAIN(SRC_NX),
        .COUNT(SRC_COUNT)
    );

    reg [4:0] DST_COUNT;
    T9990_BLIT_CALC_COUNT u_dst_cnt (
        .CLK,
        .CPU_MODE(dst_is_cpu),
        .CLRM(DST_CLRM),
        .DIX(DST_DIX),
        .OFFSET(DST_X[3:0]),
        .REMAIN(DST_NX),
        .COUNT(DST_COUNT)
    );

    reg [31:0] BIT_MASK;
    reg P1;
    always_ff @(posedge CLK) begin
        P1 <= REG.DSPM == T9990_REG::DSPM_P1;
    end
    T9990_BLIT_BITMASK u_bitmsk (
        .CLK,
        .P1,                                            // P1 mode flag
        .VRAM(dst_is_xy ? DST_XY_ADDR[18] : DST_X[18]), // VRAM ADDRESS MSB
        .WM(REG.WM),
        .CLRM(DST_CLRM),
        .DIX(DST_DIX),
        .OFFSET(DST_X[3:0]),
        .COUNT(DST_COUNT),
        .BIT_MASK(BIT_MASK)
    );

    wire [31:0] cmd_mem_dout_be = { CMD_MEM.DOUT[7:0], CMD_MEM.DOUT[15:8], CMD_MEM.DOUT[23:16], CMD_MEM.DOUT[31:24]};
    wire [31:0] src_data_le = {SRC_DATA[7:0], SRC_DATA[15:8], SRC_DATA[23:16], SRC_DATA[31:24]};
    wire [31:0] bit_mask_le = {BIT_MASK[7:0], BIT_MASK[15:8], BIT_MASK[23:16], BIT_MASK[31:24]};

    wire [4:0] SRC_OUT_COUNT = SRC_COUNT;
    wire [4:0] SRC_POS_COUNT = SRC_COUNT;
    wire [4:0] DST_IN_COUNT = DST_COUNT;
    wire [4:0] DST_POS_COUNT = DST_COUNT;
    wire [31:0] LOGOP = ((REG.LO[2'b00] ? (~src_data_le & ~DST_DATA) : 32'b0) |
                         (REG.LO[2'b01] ? (~src_data_le &  DST_DATA) : 32'b0) |
                         (REG.LO[2'b10] ? ( src_data_le & ~DST_DATA) : 32'b0) |
                         (REG.LO[2'b11] ? ( src_data_le &  DST_DATA) : 32'b0));

    enum logic [5:0] {
        STATE_IDLE,
        STATE_STOP,
        STATE_LINE,
        STATE_SEARCH,
        STATE_POINT,
        STATE_PSET,
        STATE_ADVANCE,
        STATE_SETUP,
        STATE_SETUP2,
        STATE_SRC_IN,
        STATE_SRC_READ_VRAM_WAIT_ACK,
        STATE_SRC_READ_VRAM_WAIT_BUSY,
        STATE_SRC_READ_VRAM_CONV_2I,
        STATE_SRC_READ_VRAM_CONV_4I,
        STATE_SRC_READ_VRAM_CONV_8I,
        STATE_SRC_READ_VRAM_CONV_16I,
        STATE_SRC_READ_VRAM_CONV_2N,
        STATE_SRC_READ_VRAM_CONV_4N,
        STATE_SRC_READ_VRAM_CONV_8N,
        STATE_SRC_READ_VRAM_CONV_16N,
        STATE_SRC_READ_VRAM_CONV_8C,
        STATE_SRC_READ_CPU_WAIT_ACK,
        STATE_SRC_READ_CPU_WAIT_BUSY,
        STATE_SRC_READ_CPU_H_WAIT_ACK,
        STATE_SRC_READ_CPU_H_WAIT_BUSY,
        STATE_SRC_DECODE,
        STATE_SRC_ENQUEUE_WAIT1,
        STATE_SRC_ENQUEUE_WAIT2,
        STATE_SRC_ENQUEUE_DONE,
        STATE_SRC_DEQUEUE,
        STATE_DST_READ_VRAM,
        STATE_DST_READ_VRAM_WAIT_ACK,
        STATE_DST_READ_VRAM_WAIT_BUSY,
        STATE_SRC_DEQUEUE_DONE,
        STATE_LOGOP,
        STATE_DST_WRITE,
        STATE_DST_WRITE_VRAM_WAIT_ACK,
        STATE_DST_WRITE_CPU_H_WAIT_ACK,
        STATE_DST_WRITE_CPU_H_WAIT_BUSY,
        STATE_DST_WRITE_CPU_WAIT_ACK,
        STATE_DST_WRITE_VRAM_WAIT_BUSY,
        STATE_DST_WRITE_CPU_WAIT_BUSY
    } state;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            P2_CPU_TO_VDP.REQ <= 0;
            P2_VDP_TO_CPU.REQ <= 0;
            STATUS.TR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
            FIFO_CLEAR <= 0;
            CMD_MEM.OE_n <= 1;
            CMD_MEM.WE_n <= 1;
            CMD_MEM.ADDR <= 0;
        end

        //
        // STOP 書き込み時処理
        //
        else if(START && REG.OP == T9990_REG::CMD_STOP) begin
            state <= STATE_STOP;
            P2_CPU_TO_VDP.REQ <= 0;
            P2_VDP_TO_CPU.REQ <= 0;
            STATUS.TR <= 0;
        end

        //
        // STOP コマンド: 転送が終了するまで待機
        //
        else if(state == STATE_STOP) begin
            if(!P2_CPU_TO_VDP.ACK && !P2_VDP_TO_CPU.ACK) begin
                STATUS.CE <= 0;
                state <= STATE_IDLE;
            end
        end

        //
        // アイドル
        //
        else if(state == STATE_IDLE) begin
            if(START) begin
                FIFO_CLEAR <= 1;

                STATUS.CE <= 1;

                src_enable <= 1;

                decode_data <= 0;
                decode_count <= 0;

                if(REG.OP == T9990_REG::CMD_BMLL) begin
                    SRC_NX <= REG.NA;
                    SRC_NY <= 1'd1;
                    DST_NX <= REG.NA;
                    DST_NY <= 1'd1;
                end
                else begin
                    SRC_NX <= REG.NX;
                    SRC_NY <= REG.NY;
                    DST_NX <= REG.NX;
                    DST_NY <= REG.NY;
                end

                if(REG.OP == T9990_REG::CMD_LMMC) begin
                    src_is_linear <= 0;
                    src_is_xy <= 0;
                    src_is_cpu <= 1;
                    src_is_rom <= 0;
                    src_is_vdp <= 0;
                    src_is_char <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_LMMV) begin
                    src_is_linear <= 0;
                    src_is_xy <= 0;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_vdp <= 1;
                    src_is_char <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_LMCM) begin
                    src_is_linear <= 0;
                    src_is_xy <= 1;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_vdp <= 0;
                    src_is_char <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 0;
                    dst_is_cpu <= 1;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_LMMM) begin
                    src_is_linear <= 0;
                    src_is_xy <= 1;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_vdp <= 0;
                    src_is_char <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_CMMC) begin
                    src_is_linear <= 0;
                    src_is_xy <= 0;
                    src_is_cpu <= 1;
                    src_is_rom <= 0;
                    src_is_vdp <= 0;
                    src_is_char <= 1;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_CMMK) begin
                    src_is_linear <= 0;
                    src_is_xy <= 0;
                    src_is_cpu <= 0;
                    src_is_rom <= 1;
                    src_is_char <= 1;
                    src_is_vdp <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_CMMM) begin
                    src_is_linear <= 1;
                    src_is_xy <= 0;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_char <= 1;
                    src_is_vdp <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SA;
                    SRC_Y <= 0;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= 0;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= T9990_REG::CLRM_8BPP;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_BMXL) begin
                    src_is_linear <= 1;
                    src_is_xy <= 0;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_char <= 0;
                    src_is_vdp <= 0;
                    dst_is_linear <= 0;
                    dst_is_xy <= 1;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SA;
                    SRC_Y <= 0;
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;

                    SRC_DIX <= 0;
                    DST_DIX <= REG.DIX;

                    SRC_CLRM <= T9990_REG::CLRM_8BPP;
                    DST_CLRM <= REG.CLRM;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_BMLX) begin
                    src_is_linear <= 0;
                    src_is_xy <= 1;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_char <= 0;
                    src_is_vdp <= 0;
                    dst_is_linear <= 1;
                    dst_is_xy <= 0;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    DST_X <= REG.DA;
                    DST_Y <= 0;

                    SRC_DIX <= REG.DIX;
                    DST_DIX <= 0;

                    SRC_CLRM <= REG.CLRM;
                    DST_CLRM <= T9990_REG::CLRM_8BPP;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_BMLL) begin
                    src_is_linear <= 1;
                    src_is_xy <= 0;
                    src_is_cpu <= 0;
                    src_is_rom <= 0;
                    src_is_char <= 0;
                    src_is_vdp <= 0;
                    dst_is_linear <= 1;
                    dst_is_xy <= 0;
                    dst_is_cpu <= 0;

                    SRC_X <= REG.SA;
                    SRC_Y <= 0;
                    DST_X <= REG.DA;
                    DST_Y <= 0;

                    SRC_DIX <= 0;
                    DST_DIX <= 0;

                    SRC_CLRM <= T9990_REG::CLRM_8BPP;
                    DST_CLRM <= T9990_REG::CLRM_8BPP;
                    state <= STATE_SETUP;
                end
                else if(REG.OP == T9990_REG::CMD_LINE) begin
                    state <= STATE_LINE;
                end
                else if(REG.OP == T9990_REG::CMD_SRCH) begin
                    state <= STATE_SEARCH;
                end
                else if(REG.OP == T9990_REG::CMD_POINT) begin
                    state <= STATE_POINT;
                end
                else if(REG.OP == T9990_REG::CMD_PSET) begin
                    state <= STATE_PSET;
                end
                else if(REG.OP == T9990_REG::CMD_ADVN) begin
                    state <= STATE_ADVANCE;
                end
                // 未対応のコマンド
                else begin
                    state <= STATE_STOP;
                end
            end
        end

        //
        // 何もしない
        //
        else if(!CLK_EN) begin
        end

        //
        // SRC_XY_ADDR, SRC_COUNT, BIT_MASK を計算
        //
        else if(state == STATE_SETUP) begin
            FIFO_CLEAR <= 0;
            state <= STATE_SETUP2;
        end

        //
        // SRC_XY_ADDR, SRC_COUNT, BIT_MASK を計算
        //
        else if(state == STATE_SETUP2) begin
            state <= STATE_SRC_IN;
        end

        //
        // 転送元リード
        //
        else if(state == STATE_SRC_IN) begin
            //
            ENQUEUE_COUNT <= SRC_OUT_COUNT;

            // キャラクタデータが残ってるならデコード
            if(decode_count != 0) begin
                state <= STATE_SRC_DECODE;
            end

            // 転送元データが必要なら読み出し開始
            else if(FREE_COUNT >= SRC_OUT_COUNT && src_enable) begin
                // VRAM リニア
                if(src_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= SRC_X;
                    state = STATE_SRC_READ_VRAM_WAIT_ACK;
                end

                // VRAM 矩形
                else if(src_is_xy) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= SRC_XY_ADDR;
                    state = STATE_SRC_READ_VRAM_WAIT_ACK;
                end

                // P#2
                else if(src_is_cpu) begin
                    P2_CPU_TO_VDP.REQ <= 1;
                    STATUS.TR <= 1;
                    state = STATE_SRC_READ_CPU_WAIT_ACK;
                end

                // ROM
                else if(src_is_rom) begin
                    decode_data <= 0;
                    decode_count <= 6'd32;
                    state <= STATE_SRC_IN;  // ToDo: 漢字 ROM から読み出す
                end

                // VDP
                else begin
                    ENQUEUE_DATA <= {REG.FC,REG.FC};
                    ENQUEUE <= 1;
                    state <= STATE_SRC_ENQUEUE_WAIT1;
                end
            end
            else begin
                state <= STATE_SRC_DEQUEUE;
            end
        end

        //
        // VRAM 読み出し要求を受け付けるまで待つ
        //
        else if(state == STATE_SRC_READ_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_SRC_READ_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 読み出し完了したらデータを並び替え
        //
        else if(state == STATE_SRC_READ_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                if(src_is_char) begin
                    state <= STATE_SRC_READ_VRAM_CONV_8C;
                end
                else begin
                    case ({SRC_DIX, SRC_CLRM})
                        {1'b0, T9990_REG::CLRM_2BPP }:  state <= STATE_SRC_READ_VRAM_CONV_2N;
                        {1'b0, T9990_REG::CLRM_4BPP }:  state <= STATE_SRC_READ_VRAM_CONV_4N;
                        {1'b0, T9990_REG::CLRM_8BPP }:  state <= STATE_SRC_READ_VRAM_CONV_8N;
                        {1'b0, T9990_REG::CLRM_16BPP}:  state <= STATE_SRC_READ_VRAM_CONV_16N;
                        {1'b1, T9990_REG::CLRM_2BPP }:  state <= STATE_SRC_READ_VRAM_CONV_2I;
                        {1'b1, T9990_REG::CLRM_4BPP }:  state <= STATE_SRC_READ_VRAM_CONV_4I;
                        {1'b1, T9990_REG::CLRM_8BPP }:  state <= STATE_SRC_READ_VRAM_CONV_8I;
                        {1'b1, T9990_REG::CLRM_16BPP}:  state <= STATE_SRC_READ_VRAM_CONV_16I;
                    endcase
                end
            end
        end

        //
        // データを逆方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_2I) begin
            case (SRC_X[3:0])
                4'd0:   ENQUEUE_DATA <= {cmd_mem_dout_be[31:30], 30'b0};
                4'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 28'b0};
                4'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 26'b0};
                4'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 24'b0};
                4'd4:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 22'b0};
                4'd5:   ENQUEUE_DATA <= {cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 20'b0};
                4'd6:   ENQUEUE_DATA <= {cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 18'b0};
                4'd7:   ENQUEUE_DATA <= {cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 16'b0};
                4'd8:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 14'b0};
                4'd9:   ENQUEUE_DATA <= {cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 12'b0};
                4'd10:  ENQUEUE_DATA <= {cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 10'b0};
                4'd11:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 8'b0};
                4'd12:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 7: 6], cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 6'b0};
                4'd13:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 5: 4], cmd_mem_dout_be[ 7: 6], cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 4'b0};
                4'd14:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 3: 2], cmd_mem_dout_be[ 5: 4], cmd_mem_dout_be[ 7: 6], cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30], 2'b0};
                4'd15:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 1: 0], cmd_mem_dout_be[ 3: 2], cmd_mem_dout_be[ 5: 4], cmd_mem_dout_be[ 7: 6], cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30]};
            endcase

            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを逆方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_4I) begin
            case (SRC_X[2:0])
                3'd0:   ENQUEUE_DATA <= {cmd_mem_dout_be[31:28], 28'b0};
                3'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 24'b0};
                3'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 20'b0};
                3'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 16'b0};
                3'd4:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:12], cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 12'b0};
                3'd5:   ENQUEUE_DATA <= {cmd_mem_dout_be[11: 8], cmd_mem_dout_be[15:12], cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 8'b0};
                3'd6:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 7: 4], cmd_mem_dout_be[11: 8], cmd_mem_dout_be[15:12], cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28], 4'b0};
                3'd7:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 3: 0], cmd_mem_dout_be[ 7: 4], cmd_mem_dout_be[11: 8], cmd_mem_dout_be[15:12], cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28]};
            endcase
            
            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを逆方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_8I) begin
            case (SRC_X[1:0])
                2'd0:   ENQUEUE_DATA <= {cmd_mem_dout_be[31:24], 24'b0};
                2'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:16], cmd_mem_dout_be[31:24], 16'b0};
                2'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[15: 8], cmd_mem_dout_be[23:16], cmd_mem_dout_be[31:24], 8'b0};
                2'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 7: 0], cmd_mem_dout_be[15: 8], cmd_mem_dout_be[23:16], cmd_mem_dout_be[31:24]};
            endcase

            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを逆方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_16I) begin
            case (SRC_X[0:0])
                1'd0:   ENQUEUE_DATA <= {cmd_mem_dout_be[31:16], 16'b0};
                1'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[15: 0], cmd_mem_dout_be[31:16]};
            endcase

            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_2N) begin
            case (SRC_X[3:0])
                4'd0:   ENQUEUE_DATA <= cmd_mem_dout_be;
                4'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[29:0],  2'b0};
                4'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[27:0],  4'b0};
                4'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[25:0],  6'b0};
                4'd4:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:0],  8'b0};
                4'd5:   ENQUEUE_DATA <= {cmd_mem_dout_be[21:0], 10'b0};
                4'd6:   ENQUEUE_DATA <= {cmd_mem_dout_be[19:0], 12'b0};
                4'd7:   ENQUEUE_DATA <= {cmd_mem_dout_be[17:0], 14'b0};
                4'd8:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:0], 16'b0};
                4'd9:   ENQUEUE_DATA <= {cmd_mem_dout_be[13:0], 18'b0};
                4'd10:  ENQUEUE_DATA <= {cmd_mem_dout_be[11:0], 20'b0};
                4'd11:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 9:0], 22'b0};
                4'd12:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 7:0], 24'b0};
                4'd13:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 5:0], 26'b0};
                4'd14:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 3:0], 28'b0};
                4'd15:  ENQUEUE_DATA <= {cmd_mem_dout_be[ 1:0], 30'b0};
            endcase
            
            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_4N) begin
            case (SRC_X[2:0])
                3'd0:   ENQUEUE_DATA <= cmd_mem_dout_be;
                3'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[27:0],  4'b0};
                3'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:0],  8'b0};
                3'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[19:0], 12'b0};
                3'd4:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:0], 16'b0};
                3'd5:   ENQUEUE_DATA <= {cmd_mem_dout_be[11:0], 20'b0};
                3'd6:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 7:0], 24'b0};
                3'd7:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 3:0], 28'b0};
            endcase
            
            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_8N) begin
            case (SRC_X[1:0])
                2'd0:   ENQUEUE_DATA <= cmd_mem_dout_be;
                2'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[23:0],  8'b0};
                2'd2:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:0], 16'b0};
                2'd3:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 7:0], 24'b0};
            endcase
            
            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_16N) begin
            case (SRC_X[0:0])
                1'd0:   ENQUEUE_DATA <= cmd_mem_dout_be;
                1'd1:   ENQUEUE_DATA <= {cmd_mem_dout_be[15:0], 16'b0};
            endcase

            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて デコード
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_8C) begin
            case (SRC_X[1:0])
                2'd0:   decode_data <= cmd_mem_dout_be;
                2'd1:   decode_data <= {cmd_mem_dout_be[23:0],  8'b0};
                2'd2:   decode_data <= {cmd_mem_dout_be[15:0], 16'b0};
                2'd3:   decode_data <= {cmd_mem_dout_be[ 7:0], 24'b0};
            endcase
            decode_count <= {SRC_OUT_COUNT[2:0], 3'b000};
            state <= STATE_SRC_DECODE;
        end

        //
        // P2 にデータが書き込まれるまで待つ
        //
        else if(state == STATE_SRC_READ_CPU_WAIT_ACK) begin
            if(P2_CPU_TO_VDP.ACK) begin
                P2_CPU_TO_VDP.REQ <= 0;
                STATUS.TR <= 0;
                state <= STATE_SRC_READ_CPU_WAIT_BUSY;
            end
        end

        //
        // P2 がアイドルになったら、FIFO に格納
        //
        else if(state == STATE_SRC_READ_CPU_WAIT_BUSY) begin
            if(!P2_CPU_TO_VDP.ACK) begin
                if(src_is_char) begin
                    decode_data <= {P2_CPU_TO_VDP.DATA, 24'b0};
                    decode_count <= 6'd8;
                    state <= STATE_SRC_DECODE;
                end
                else if(SRC_CLRM == T9990_REG::CLRM_16BPP) begin
                    ENQUEUE_DATA <= {8'b0, P2_CPU_TO_VDP.DATA, 16'b0};
                    P2_CPU_TO_VDP.REQ <= 1;
                    STATUS.TR <= 1;
                    state = STATE_SRC_READ_CPU_H_WAIT_ACK;
                end
                else begin
                    ENQUEUE_DATA <= {P2_CPU_TO_VDP.DATA, 24'b0};
                    ENQUEUE <= 1;
                    state <= STATE_SRC_ENQUEUE_WAIT1;
                end
            end
        end

        //
        // P2 にデータが書き込まれるまで待つ
        //
        else if(state == STATE_SRC_READ_CPU_H_WAIT_ACK) begin
            if(P2_CPU_TO_VDP.ACK) begin
                P2_CPU_TO_VDP.REQ <= 0;
                STATUS.TR <= 0;
                state <= STATE_SRC_READ_CPU_H_WAIT_BUSY;
            end
        end

        //
        // P2 がアイドルになったら、FIFO に格納
        //
        else if(state == STATE_SRC_READ_CPU_H_WAIT_BUSY) begin
            if(!P2_CPU_TO_VDP.ACK) begin
                ENQUEUE_DATA <= {P2_CPU_TO_VDP.DATA, ENQUEUE_DATA[23:0]};
                ENQUEUE <= 1;
                state <= STATE_SRC_ENQUEUE_WAIT1;
            end
        end

        //
        // キャラクタデータをデコード
        //
        else if(state == STATE_SRC_DECODE) begin
            decode_count <= decode_count - 1'd1;

            if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                ENQUEUE_DATA <= {
                                    decode_data[31] ? REG.FC[15:14] : REG.BC[15:14],
                                    decode_data[30] ? REG.FC[13:12] : REG.BC[13:12],
                                    decode_data[29] ? REG.FC[11:10] : REG.BC[11:10],
                                    decode_data[28] ? REG.FC[ 9: 8] : REG.BC[ 9: 8],
                                    decode_data[27] ? REG.FC[ 7: 6] : REG.BC[ 7: 6],
                                    decode_data[26] ? REG.FC[ 5: 4] : REG.BC[ 5: 4],
                                    decode_data[25] ? REG.FC[ 3: 2] : REG.BC[ 3: 2],
                                    decode_data[24] ? REG.FC[ 1: 0] : REG.BC[ 1: 0],
                                    decode_data[23] ? REG.FC[15:14] : REG.BC[15:14],
                                    decode_data[22] ? REG.FC[13:12] : REG.BC[13:12],
                                    decode_data[21] ? REG.FC[11:10] : REG.BC[11:10],
                                    decode_data[20] ? REG.FC[ 9: 8] : REG.BC[ 9: 8],
                                    decode_data[19] ? REG.FC[ 7: 6] : REG.BC[ 7: 6],
                                    decode_data[18] ? REG.FC[ 5: 4] : REG.BC[ 5: 4],
                                    decode_data[17] ? REG.FC[ 3: 2] : REG.BC[ 3: 2],
                                    decode_data[16] ? REG.FC[ 1: 0] : REG.BC[ 1: 0]
                                };
                decode_data <= {decode_data[15:0], decode_data[31:16]};
            end
            else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                ENQUEUE_DATA <= {
                                    decode_data[31] ? REG.FC[15:12] : REG.BC[15:12],
                                    decode_data[30] ? REG.FC[11: 8] : REG.BC[11: 8],
                                    decode_data[29] ? REG.FC[ 7: 4] : REG.BC[ 7: 4],
                                    decode_data[28] ? REG.FC[ 3: 0] : REG.BC[ 3: 0],
                                    decode_data[27] ? REG.FC[15:12] : REG.BC[15:12],
                                    decode_data[26] ? REG.FC[11: 8] : REG.BC[11: 8],
                                    decode_data[25] ? REG.FC[ 7: 4] : REG.BC[ 7: 4],
                                    decode_data[24] ? REG.FC[ 3: 0] : REG.BC[ 3: 0]
                                };
                decode_data <= {decode_data[23:0], decode_data[31:24]};
            end
            else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                ENQUEUE_DATA <= {
                                    decode_data[31] ? REG.FC[15: 8] : REG.BC[15: 8],
                                    decode_data[30] ? REG.FC[ 7: 0] : REG.BC[ 7: 0],
                                    decode_data[29] ? REG.FC[15: 8] : REG.BC[15: 8],
                                    decode_data[28] ? REG.FC[ 7: 0] : REG.BC[ 7: 0]
                                };
                decode_data <= {decode_data[27:0], decode_data[31:28]};
            end
            else begin
                ENQUEUE_DATA <= {
                                    decode_data[31] ? REG.FC[15: 0] : REG.BC[15: 0],
                                    decode_data[30] ? REG.FC[15: 0] : REG.BC[15: 0]
                                };
                decode_data <= {decode_data[29:0], decode_data[31:30]};
            end

            case (DST_CLRM)
                T9990_REG::CLRM_2BPP:  ENQUEUE_COUNT <= 5'd16;
                T9990_REG::CLRM_4BPP:  ENQUEUE_COUNT <= 5'd8;
                T9990_REG::CLRM_8BPP:  ENQUEUE_COUNT <= 5'd4;
                T9990_REG::CLRM_16BPP: ENQUEUE_COUNT <= 5'd2;
            endcase
            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // FIFO に格納待ち
        //
        else if(state == STATE_SRC_ENQUEUE_WAIT1) begin
            ENQUEUE <= 0;
            state <= STATE_SRC_ENQUEUE_WAIT2;
        end

        //
        // FIFO に格納待ち
        //
        else if(state == STATE_SRC_ENQUEUE_WAIT2) begin
            ENQUEUE <= 0;
            state <= STATE_SRC_ENQUEUE_DONE;
        end

        //
        // FIFO 格納が完了したので転送元座標の更新
        //
        else if(state == STATE_SRC_ENQUEUE_DONE) begin
            ENQUEUE <= 0;

            if(src_is_linear) begin
                // 隣へ移動
                SRC_X <= SRC_X + SRC_POS_COUNT;
                SRC_NX <= SRC_NX - SRC_POS_COUNT;
            end
            else if(SRC_NX <= SRC_POS_COUNT) begin
                // SRC_NY が 1->0 で転送元入力を禁止
                if(SRC_NY == 1'd1) src_enable <= 0;

                // 次の行の準備
                SRC_X <= REG.SX;
                SRC_Y = REG.DIY ? (SRC_Y - 1'd1) : (SRC_Y + 1'd1);
                SRC_NX <= REG.NX;
                SRC_NY <= SRC_NY - 1'd1;
            end
            else begin
                // 隣へ移動
                SRC_NX <= SRC_NX - SRC_POS_COUNT;
                SRC_X <= SRC_DIX ? (SRC_X - SRC_POS_COUNT) : (SRC_X + SRC_POS_COUNT);
            end

            state <= STATE_SRC_DEQUEUE;
        end

        //
        // 出力データの準備
        //
        else if(state == STATE_SRC_DEQUEUE) begin
            // 転送先側の VRAM データが必要かどうかをチェック
            if(!(dst_is_linear || dst_is_xy))                req_dst_vram <= 0;  // VRAM に出力しない場合は必要なし
            else if(BIT_MASK != 32'hFFFF_FFFF)              req_dst_vram <= 1;  // ビットマスクに抜けがある場合は必要
            else if(REG.TP)                                 req_dst_vram <= 1;  // 透明色を使う場合は必要
            else if(REG.LO != 4'b1100 && REG.LO != 4'b0011) req_dst_vram <= 1;  // ビット演算を行う場合は必要
            else                                            req_dst_vram <= 0;  // それ以外は必要なし

            if(AVAIL_COUNT < DST_IN_COUNT) begin
                // 出力のためのデータが足りないので FIFO 入力を繰り返す
                state <= STATE_SRC_IN;
            end
            else begin
                // FIFO から取り出し
                DEQUEUE_COUNT <= DST_IN_COUNT;
                DEQUEUE <= 1;
                state <= STATE_DST_READ_VRAM;
            end
        end

        //
        // 転送先データのリード
        //
        else if(state == STATE_DST_READ_VRAM) begin
            DEQUEUE <= 0;

            // DST 側の VRAM データが必要なら読み出し
            if(req_dst_vram) begin
                if(dst_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= DST_X;
                    state = STATE_DST_READ_VRAM_WAIT_ACK;
                end
                else begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= DST_XY_ADDR;
                    state = STATE_DST_READ_VRAM_WAIT_ACK;
                end
            end
            else begin
                DST_DATA <= 0;
                state <= STATE_SRC_DEQUEUE_DONE;
            end
        end

        //
        // VRAM 読み出し要求を受け付けるまで待つ
        //
        else if(state == STATE_DST_READ_VRAM_WAIT_ACK) begin
            DEQUEUE <= 0;
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_DST_READ_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 読み出し完了したら FIFO へ格納
        //
        else if(state == STATE_DST_READ_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                DST_DATA <= CMD_MEM.DOUT;
                state <= STATE_SRC_DEQUEUE_DONE;
            end
        end

        //
        // FIFO から取り出したデータを加工
        //
        else if(state == STATE_SRC_DEQUEUE_DONE) begin
            if(DST_DIX) begin
                if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                    case (DST_X[3:0])
                        4'd0:   SRC_DATA <= {DEQUEUE_DATA2[31:30], 30'b0};
                        4'd1:   SRC_DATA <= {DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 28'b0};
                        4'd2:   SRC_DATA <= {DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 26'b0};
                        4'd3:   SRC_DATA <= {DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 24'b0};
                        4'd3:   SRC_DATA <= {DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 22'b0};
                        4'd4:   SRC_DATA <= {DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 20'b0};
                        4'd5:   SRC_DATA <= {DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 18'b0};
                        4'd6:   SRC_DATA <= {DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 16'b0};
                        4'd7:   SRC_DATA <= {DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 14'b0};
                        4'd8:   SRC_DATA <= {DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 12'b0};
                        4'd9:   SRC_DATA <= {DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 10'b0};
                        4'd11:  SRC_DATA <= {DEQUEUE_DATA2[ 9: 8], DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 8'b0};
                        4'd12:  SRC_DATA <= {DEQUEUE_DATA2[ 7: 6], DEQUEUE_DATA2[ 9: 8], DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 6'b0};
                        4'd13:  SRC_DATA <= {DEQUEUE_DATA2[ 5: 4], DEQUEUE_DATA2[ 7: 6], DEQUEUE_DATA2[ 9: 8], DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 4'b0};
                        4'd14:  SRC_DATA <= {DEQUEUE_DATA2[ 3: 2], DEQUEUE_DATA2[ 5: 4], DEQUEUE_DATA2[ 7: 6], DEQUEUE_DATA2[ 9: 8], DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30], 2'b0};
                        4'd14:  SRC_DATA <= {DEQUEUE_DATA2[ 1: 0], DEQUEUE_DATA2[ 3: 2], DEQUEUE_DATA2[ 5: 4], DEQUEUE_DATA2[ 7: 6], DEQUEUE_DATA2[ 9: 8], DEQUEUE_DATA2[11:10], DEQUEUE_DATA2[13:12], DEQUEUE_DATA2[15:14], DEQUEUE_DATA2[17:16], DEQUEUE_DATA2[19:18], DEQUEUE_DATA2[21:20], DEQUEUE_DATA2[23:22], DEQUEUE_DATA2[25:24], DEQUEUE_DATA2[27:26], DEQUEUE_DATA2[29:28], DEQUEUE_DATA2[31:30]};
                    endcase
                end
                else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                    case (DST_X[2:0])
                        3'd0:   SRC_DATA <= {DEQUEUE_DATA4[31:28], 28'b0};
                        3'd1:   SRC_DATA <= {DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 24'b0};
                        3'd2:   SRC_DATA <= {DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 20'b0};
                        3'd3:   SRC_DATA <= {DEQUEUE_DATA4[19:16], DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 16'b0};
                        3'd4:   SRC_DATA <= {DEQUEUE_DATA4[15:12], DEQUEUE_DATA4[19:16], DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 12'b0};
                        3'd5:   SRC_DATA <= {DEQUEUE_DATA4[11: 8], DEQUEUE_DATA4[15:12], DEQUEUE_DATA4[19:16], DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 8'b0};
                        3'd6:   SRC_DATA <= {DEQUEUE_DATA4[ 7: 4], DEQUEUE_DATA4[11: 8], DEQUEUE_DATA4[15:12], DEQUEUE_DATA4[19:16], DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28], 4'b0};
                        3'd7:   SRC_DATA <= {DEQUEUE_DATA4[ 3: 0], DEQUEUE_DATA4[ 7: 4], DEQUEUE_DATA4[11: 8], DEQUEUE_DATA4[15:12], DEQUEUE_DATA4[19:16], DEQUEUE_DATA4[23:20], DEQUEUE_DATA4[27:24], DEQUEUE_DATA4[31:28]};
                    endcase
                end
                else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                    case (DST_X[1:0])
                        2'd0:   SRC_DATA <= {DEQUEUE_DATA8[31:24], 24'b0};
                        2'd1:   SRC_DATA <= {DEQUEUE_DATA8[23:16], DEQUEUE_DATA8[31:24], 16'b0};
                        2'd2:   SRC_DATA <= {DEQUEUE_DATA8[15: 8], DEQUEUE_DATA8[23:16], DEQUEUE_DATA8[31:24], 8'b0};
                        2'd2:   SRC_DATA <= {DEQUEUE_DATA8[ 7: 0], DEQUEUE_DATA8[15: 8], DEQUEUE_DATA8[23:16], DEQUEUE_DATA8[31:24]};
                    endcase
                end
                else begin
                    case (DST_X[0:0])
                        2'd0:   SRC_DATA <= {DEQUEUE_DATA16[31:16], 16'b0};
                        2'd1:   SRC_DATA <= {DEQUEUE_DATA16[15: 0], DEQUEUE_DATA16[31:16]};
                    endcase
                end
            end
            else begin
                if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                    case (DST_X[3:0])
                        4'd0:   SRC_DATA <= DEQUEUE_DATA2;
                        4'd1:   SRC_DATA <= { 2'b0, DEQUEUE_DATA2[31: 2]};
                        4'd2:   SRC_DATA <= { 4'b0, DEQUEUE_DATA2[31: 4]};
                        4'd3:   SRC_DATA <= { 6'b0, DEQUEUE_DATA2[31: 6]};
                        4'd4:   SRC_DATA <= { 8'b0, DEQUEUE_DATA2[31: 8]};
                        4'd5:   SRC_DATA <= {10'b0, DEQUEUE_DATA2[31:10]};
                        4'd6:   SRC_DATA <= {12'b0, DEQUEUE_DATA2[31:12]};
                        4'd7:   SRC_DATA <= {14'b0, DEQUEUE_DATA2[31:14]};
                        4'd8:   SRC_DATA <= {16'b0, DEQUEUE_DATA2[31:16]};
                        4'd9:   SRC_DATA <= {18'b0, DEQUEUE_DATA2[31:18]};
                        4'd10:  SRC_DATA <= {20'b0, DEQUEUE_DATA2[31:20]};
                        4'd11:  SRC_DATA <= {22'b0, DEQUEUE_DATA2[31:22]};
                        4'd12:  SRC_DATA <= {24'b0, DEQUEUE_DATA2[31:24]};
                        4'd13:  SRC_DATA <= {26'b0, DEQUEUE_DATA2[31:26]};
                        4'd14:  SRC_DATA <= {28'b0, DEQUEUE_DATA2[31:28]};
                        4'd15:  SRC_DATA <= {30'b0, DEQUEUE_DATA2[31:30]};
                    endcase
                end
                else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                    case (DST_X[2:0])
                        3'd0:   SRC_DATA <= DEQUEUE_DATA4;
                        3'd1:   SRC_DATA <= { 4'b0, DEQUEUE_DATA4[31: 4]};
                        3'd2:   SRC_DATA <= { 8'b0, DEQUEUE_DATA4[31: 8]};
                        3'd3:   SRC_DATA <= {12'b0, DEQUEUE_DATA4[31:12]};
                        3'd4:   SRC_DATA <= {16'b0, DEQUEUE_DATA4[31:16]};
                        3'd5:   SRC_DATA <= {20'b0, DEQUEUE_DATA4[31:20]};
                        3'd6:   SRC_DATA <= {24'b0, DEQUEUE_DATA4[31:24]};
                        3'd7:   SRC_DATA <= {28'b0, DEQUEUE_DATA4[31:28]};
                    endcase
                end
                else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                    case (DST_X[1:0])
                        2'd0:   SRC_DATA <= DEQUEUE_DATA8;
                        2'd1:   SRC_DATA <= { 8'b0, DEQUEUE_DATA8[31: 8]};
                        2'd2:   SRC_DATA <= {16'b0, DEQUEUE_DATA8[31:16]};
                        2'd3:   SRC_DATA <= {24'b0, DEQUEUE_DATA8[31:24]};
                    endcase
                end
                else begin
                    case (DST_X[0:0])
                        1'd0:   SRC_DATA <= DEQUEUE_DATA16;
                        1'd1:   SRC_DATA <= {16'b0, DEQUEUE_DATA16[31:16]};
                    endcase
                end
            end

            state <= STATE_LOGOP;
        end

        //
        // ロジカルオペレーション1
        //
        else if(state == STATE_LOGOP) begin
            if(REG.TP) begin
                // ビットマスク更新
                if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                    WRT_DATA <= {
                        (src_data_le[31:30] != 0 && bit_mask_le[30] != 0) ? LOGOP[31:30] : DST_DATA[31:30],
                        (src_data_le[29:28] != 0 && bit_mask_le[28] != 0) ? LOGOP[29:28] : DST_DATA[29:28],
                        (src_data_le[27:26] != 0 && bit_mask_le[26] != 0) ? LOGOP[27:26] : DST_DATA[27:26],
                        (src_data_le[25:24] != 0 && bit_mask_le[24] != 0) ? LOGOP[25:24] : DST_DATA[25:24],
                        (src_data_le[23:22] != 0 && bit_mask_le[22] != 0) ? LOGOP[23:22] : DST_DATA[23:22],
                        (src_data_le[21:20] != 0 && bit_mask_le[20] != 0) ? LOGOP[21:20] : DST_DATA[21:20],
                        (src_data_le[19:18] != 0 && bit_mask_le[18] != 0) ? LOGOP[19:18] : DST_DATA[19:18],
                        (src_data_le[17:16] != 0 && bit_mask_le[16] != 0) ? LOGOP[17:16] : DST_DATA[17:16],
                        (src_data_le[15:14] != 0 && bit_mask_le[14] != 0) ? LOGOP[15:14] : DST_DATA[15:14],
                        (src_data_le[13:12] != 0 && bit_mask_le[12] != 0) ? LOGOP[13:12] : DST_DATA[13:12],
                        (src_data_le[11:10] != 0 && bit_mask_le[10] != 0) ? LOGOP[11:10] : DST_DATA[11:10],
                        (src_data_le[ 9: 8] != 0 && bit_mask_le[ 8] != 0) ? LOGOP[ 9: 8] : DST_DATA[ 9: 8],
                        (src_data_le[ 7: 6] != 0 && bit_mask_le[ 6] != 0) ? LOGOP[ 7: 6] : DST_DATA[ 7: 6],
                        (src_data_le[ 5: 4] != 0 && bit_mask_le[ 4] != 0) ? LOGOP[ 5: 4] : DST_DATA[ 5: 4],
                        (src_data_le[ 3: 2] != 0 && bit_mask_le[ 2] != 0) ? LOGOP[ 3: 2] : DST_DATA[ 3: 2],
                        (src_data_le[ 1: 0] != 0 && bit_mask_le[ 0] != 0) ? LOGOP[ 1: 0] : DST_DATA[ 1: 0]
                    };
                end
                else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                    WRT_DATA <= {
                        (src_data_le[31:28] != 0 && bit_mask_le[28] != 0) ? LOGOP[31:28] : DST_DATA[31:28],
                        (src_data_le[27:24] != 0 && bit_mask_le[24] != 0) ? LOGOP[27:24] : DST_DATA[27:24],
                        (src_data_le[23:20] != 0 && bit_mask_le[20] != 0) ? LOGOP[23:20] : DST_DATA[23:20],
                        (src_data_le[19:16] != 0 && bit_mask_le[16] != 0) ? LOGOP[19:16] : DST_DATA[19:16],
                        (src_data_le[15:12] != 0 && bit_mask_le[12] != 0) ? LOGOP[15:12] : DST_DATA[15:12],
                        (src_data_le[11: 8] != 0 && bit_mask_le[ 8] != 0) ? LOGOP[11: 8] : DST_DATA[11: 8],
                        (src_data_le[ 7: 4] != 0 && bit_mask_le[ 4] != 0) ? LOGOP[ 7: 4] : DST_DATA[ 7: 4],
                        (src_data_le[ 3: 0] != 0 && bit_mask_le[ 0] != 0) ? LOGOP[ 3: 0] : DST_DATA[ 3: 0]
                    };
                end
                else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                    WRT_DATA <= {
                        (src_data_le[31:24] != 0 && bit_mask_le[24] != 0) ? LOGOP[31:24] : DST_DATA[31:24],
                        (src_data_le[23:16] != 0 && bit_mask_le[16] != 0) ? LOGOP[23:16] : DST_DATA[23:16],
                        (src_data_le[15: 8] != 0 && bit_mask_le[ 8] != 0) ? LOGOP[15: 8] : DST_DATA[15: 8],
                        (src_data_le[ 7: 0] != 0 && bit_mask_le[ 0] != 0) ? LOGOP[ 7: 0] : DST_DATA[ 7: 0]
                    };
                end
                else begin
                    WRT_DATA <= {
                        (src_data_le[31:16] != 0 && bit_mask_le[16] != 0) ? LOGOP[31:16] : DST_DATA[31:16],
                        (src_data_le[15: 0] != 0 && bit_mask_le[ 0] != 0) ? LOGOP[15: 0] : DST_DATA[15: 0]
                    };
                end
            end
            else begin
                WRT_DATA <= (LOGOP & bit_mask_le) | (DST_DATA & ~bit_mask_le);
            end

            state <= STATE_DST_WRITE;
        end

        //
        // データ書き込み
        //
        else if(state == STATE_DST_WRITE) begin
            if(dst_is_linear) begin
                CMD_MEM.WE_n <= 0;
                CMD_MEM.ADDR <= DST_X;
                CMD_MEM.DIN <= WRT_DATA;
                state <= STATE_DST_WRITE_VRAM_WAIT_ACK;
            end
            else if(dst_is_xy) begin
                CMD_MEM.WE_n <= 0;
                CMD_MEM.ADDR <= DST_XY_ADDR;
                CMD_MEM.DIN <= WRT_DATA;
                state <= STATE_DST_WRITE_VRAM_WAIT_ACK;
            end
            else begin
                P2_VDP_TO_CPU.REQ <= 1;
                STATUS.TR <= 1;
                if(DST_CLRM == T9990_REG::CLRM_16BPP) begin
                    P2_VDP_TO_CPU.DATA <= WRT_DATA[23:16];
                    state <= STATE_DST_WRITE_CPU_H_WAIT_ACK;
                end
                else begin
                    P2_VDP_TO_CPU.DATA <= WRT_DATA[31:24];
                    state <= STATE_DST_WRITE_CPU_WAIT_ACK;
                end
            end
        end

        //
        // VRAM 書き込み要求を受け付けるまで待つ
        //
        else if(state == STATE_DST_WRITE_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.WE_n <= 1;
                state <= STATE_DST_WRITE_VRAM_WAIT_BUSY;
            end
        end

        //
        // P2 にデータが上位データが書き込まれるまで待つ
        //
        else if(state == STATE_DST_WRITE_CPU_H_WAIT_ACK) begin
            if(P2_VDP_TO_CPU.ACK) begin
                P2_VDP_TO_CPU.REQ <= 0;
                STATUS.TR <= 0;
                state <= STATE_DST_WRITE_CPU_H_WAIT_BUSY;
            end
        end

        //
        // P2 がアイドルになるまで待つ
        //
        else if(state == STATE_DST_WRITE_CPU_H_WAIT_BUSY) begin
            if(!P2_VDP_TO_CPU.ACK) begin
                P2_VDP_TO_CPU.REQ <= 1;
                P2_VDP_TO_CPU.DATA <= WRT_DATA[31:24];
                STATUS.TR <= 1;
                state <= STATE_DST_WRITE_CPU_WAIT_ACK;
            end
        end

        //
        // P2 にデータが下位データが書き込まれるまで待つ
        //
        else if(state == STATE_DST_WRITE_CPU_WAIT_ACK) begin
            if(P2_VDP_TO_CPU.ACK) begin
                P2_VDP_TO_CPU.REQ <= 0;
                STATUS.TR <= 0;
                state <= STATE_DST_WRITE_CPU_WAIT_BUSY;
            end
        end

        //
        // VRAM 書き込み完了 or P2 がアイドル なら次へ
        //
        else if((state == STATE_DST_WRITE_VRAM_WAIT_BUSY) || (state == STATE_DST_WRITE_CPU_WAIT_BUSY)) begin
            if(!CMD_MEM.BUSY && !P2_VDP_TO_CPU.ACK) begin
                if(dst_is_linear) begin
                    // 隣に移動
                    DST_X = DST_X + DST_POS_COUNT;
                    DST_NX <= DST_NX - DST_POS_COUNT;

                    // 終わり?
                    if(DST_NX <= DST_POS_COUNT) begin
                        STATUS.CE <= 0;
                        state <= STATE_IDLE;
                    end
                    else begin
                        state <= STATE_SRC_IN;
                    end
                end
                else if(DST_NX <= DST_POS_COUNT) begin
                    // 次の行の準備
                    DST_X <= REG.DX;
                    DST_Y = REG.DIY ? (DST_Y - 1'd1) : (DST_Y + 1'd1);
                    DST_NX <= REG.NX;
                    DST_NY <= DST_NY - 1'd1;

                    // 終わり?
                    if(DST_NY == 1'd1) begin
                        STATUS.CE <= 0;
                        state <= STATE_IDLE;
                    end
                    else begin
                        state <= STATE_SRC_IN;
                    end
                end
                else begin
                    // 隣に移動
                    DST_NX <= DST_NX - DST_POS_COUNT;
                    DST_X = DST_DIX ? (DST_X - DST_POS_COUNT) : (DST_X + DST_POS_COUNT);
                    state <= STATE_SRC_IN;
                end
            end
        end

        else if(state == STATE_LINE) begin
            FIFO_CLEAR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
        end

        else if(state == STATE_SEARCH) begin
            FIFO_CLEAR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
        end

        else if(state == STATE_POINT) begin
            FIFO_CLEAR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
        end

        else if(state == STATE_PSET) begin
            FIFO_CLEAR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
        end

        else if(state == STATE_ADVANCE) begin
            FIFO_CLEAR <= 0;
            STATUS.CE <= 0;
            state <= STATE_IDLE;
        end
    end
endmodule

/***************************************************************
 * 処理するドット数を計算
 ***************************************************************/
module T9990_BLIT_CALC_COUNT (
    input wire          CLK,
    input wire          CPU_MODE,
    input wire [1:0]    CLRM,
    input wire          DIX,
    input wire [3:0]    OFFSET,
    input wire [18:0]   REMAIN,
    output reg [4:0]    COUNT
);
    // 1クロック目
    reg [4:0] remain;
    always_ff @(posedge CLK) begin
        remain <= (REMAIN[18:4] != 0) ? 5'd16 : REMAIN[3:0];
    end

    reg [4:0] count;
    always_ff @(posedge CLK) begin
        if(CPU_MODE) begin
            case (CLRM)
                T9990_REG::CLRM_2BPP:   count <= 4;
                T9990_REG::CLRM_4BPP:   count <= 2;
                T9990_REG::CLRM_8BPP:   count <= 1;
                T9990_REG::CLRM_16BPP:  count <= 1;
            endcase
        end
        else case (CLRM)
            T9990_REG::CLRM_2BPP:   count <= DIX ? (OFFSET[3:0] + 5'd1) : (5'd16 - OFFSET[3:0]);
            T9990_REG::CLRM_4BPP:   count <= DIX ? (OFFSET[2:0] + 5'd1) : (5'd8  - OFFSET[2:0]);
            T9990_REG::CLRM_8BPP:   count <= DIX ? (OFFSET[1:0] + 5'd1) : (5'd4  - OFFSET[1:0]);
            T9990_REG::CLRM_16BPP:  count <= DIX ? (OFFSET[0:0] + 5'd1) : (5'd2  - OFFSET[0:0]);
        endcase
    end

    // 2クロック目
    always_ff @(posedge CLK) begin
        COUNT <= count > remain ? remain : count;
    end
endmodule

/***************************************************************
 * ビットマスク
 ***************************************************************/
module T9990_BLIT_BITMASK (
    input wire          CLK,
    input wire [15:0]   WM,
    input wire          P1,
    input wire          VRAM,
    input wire [1:0]    CLRM,
    input wire          DIX,
    input wire [3:0]    OFFSET,
    input wire [4:0]    COUNT,
    output reg [31:0]   BIT_MASK
);
    /***************************************************************
     * COUNT の値で mask を生成
     ***************************************************************/
    reg [31:0] mask;
    always_ff @(posedge CLK) begin
        if(!DIX && CLRM == T9990_REG::CLRM_2BPP) begin
            mask[31:30] <= (COUNT >  5'd0) ? 2'b11 : 2'b00;
            mask[29:28] <= (COUNT >  5'd1) ? 2'b11 : 2'b00;
            mask[27:26] <= (COUNT >  5'd2) ? 2'b11 : 2'b00;
            mask[25:24] <= (COUNT >  5'd3) ? 2'b11 : 2'b00;
            mask[23:22] <= (COUNT >  5'd4) ? 2'b11 : 2'b00;
            mask[21:20] <= (COUNT >  5'd5) ? 2'b11 : 2'b00;
            mask[19:18] <= (COUNT >  5'd6) ? 2'b11 : 2'b00;
            mask[17:16] <= (COUNT >  5'd7) ? 2'b11 : 2'b00;
            mask[15:14] <= (COUNT >  5'd8) ? 2'b11 : 2'b00;
            mask[13:12] <= (COUNT >  5'd9) ? 2'b11 : 2'b00;
            mask[11:10] <= (COUNT > 5'd10) ? 2'b11 : 2'b00;
            mask[ 9: 8] <= (COUNT > 5'd11) ? 2'b11 : 2'b00;
            mask[ 7: 6] <= (COUNT > 5'd12) ? 2'b11 : 2'b00;
            mask[ 5: 4] <= (COUNT > 5'd13) ? 2'b11 : 2'b00;
            mask[ 3: 2] <= (COUNT > 5'd14) ? 2'b11 : 2'b00;
            mask[ 1: 0] <= (COUNT > 5'd15) ? 2'b11 : 2'b00;
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_4BPP) begin
            mask[31:28] <= (COUNT >  5'd0) ? 4'b1111 : 4'b0000;
            mask[27:24] <= (COUNT >  5'd1) ? 4'b1111 : 4'b0000;
            mask[23:20] <= (COUNT >  5'd2) ? 4'b1111 : 4'b0000;
            mask[19:16] <= (COUNT >  5'd3) ? 4'b1111 : 4'b0000;
            mask[15:12] <= (COUNT >  5'd4) ? 4'b1111 : 4'b0000;
            mask[11: 8] <= (COUNT >  5'd5) ? 4'b1111 : 4'b0000;
            mask[ 7: 4] <= (COUNT >  5'd6) ? 4'b1111 : 4'b0000;
            mask[ 3: 0] <= (COUNT >  5'd7) ? 4'b1111 : 4'b0000;
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_8BPP) begin
            mask[31:24] <= (COUNT >  5'd0) ? 8'b11111111 : 8'b00000000;
            mask[23:16] <= (COUNT >  5'd1) ? 8'b11111111 : 8'b00000000;
            mask[15: 8] <= (COUNT >  5'd2) ? 8'b11111111 : 8'b00000000;
            mask[ 7: 0] <= (COUNT >  5'd3) ? 8'b11111111 : 8'b00000000;
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_16BPP) begin
            mask[31:16] <= (COUNT >  5'd0) ? 16'b1111111111111111 : 16'b0000000000000000;
            mask[15: 0] <= (COUNT >  5'd1) ? 16'b1111111111111111 : 16'b0000000000000000;
        end

        else if(DIX && CLRM == T9990_REG::CLRM_2BPP) begin
            mask[ 1: 0] <= (COUNT >  5'd0) ? 2'b11 : 2'b00;
            mask[ 3: 2] <= (COUNT >  5'd1) ? 2'b11 : 2'b00;
            mask[ 5: 4] <= (COUNT >  5'd2) ? 2'b11 : 2'b00;
            mask[ 7: 6] <= (COUNT >  5'd3) ? 2'b11 : 2'b00;
            mask[ 9: 8] <= (COUNT >  5'd4) ? 2'b11 : 2'b00;
            mask[11:10] <= (COUNT >  5'd5) ? 2'b11 : 2'b00;
            mask[13:12] <= (COUNT >  5'd6) ? 2'b11 : 2'b00;
            mask[15:14] <= (COUNT >  5'd7) ? 2'b11 : 2'b00;
            mask[17:16] <= (COUNT >  5'd8) ? 2'b11 : 2'b00;
            mask[19:18] <= (COUNT >  5'd9) ? 2'b11 : 2'b00;
            mask[21:20] <= (COUNT > 5'd10) ? 2'b11 : 2'b00;
            mask[23:22] <= (COUNT > 5'd11) ? 2'b11 : 2'b00;
            mask[25:24] <= (COUNT > 5'd12) ? 2'b11 : 2'b00;
            mask[27:26] <= (COUNT > 5'd13) ? 2'b11 : 2'b00;
            mask[29:28] <= (COUNT > 5'd14) ? 2'b11 : 2'b00;
            mask[31:30] <= (COUNT > 5'd15) ? 2'b11 : 2'b00;
        end
        else if(DIX && CLRM == T9990_REG::CLRM_8BPP) begin
            mask[ 3: 0] <= (COUNT >  5'd0) ? 4'b1111 : 4'b0000;
            mask[ 7: 4] <= (COUNT >  5'd1) ? 4'b1111 : 4'b0000;
            mask[11: 8] <= (COUNT >  5'd2) ? 4'b1111 : 4'b0000;
            mask[15:12] <= (COUNT >  5'd3) ? 4'b1111 : 4'b0000;
            mask[19:16] <= (COUNT >  5'd4) ? 4'b1111 : 4'b0000;
            mask[23:20] <= (COUNT >  5'd5) ? 4'b1111 : 4'b0000;
            mask[27:24] <= (COUNT >  5'd6) ? 4'b1111 : 4'b0000;
            mask[31:28] <= (COUNT >  5'd7) ? 4'b1111 : 4'b0000;
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_8BPP) begin
            mask[ 7: 0] <= (COUNT >  5'd0) ? 8'b11111111 : 8'b00000000;
            mask[15: 8] <= (COUNT >  5'd1) ? 8'b11111111 : 8'b00000000;
            mask[23:16] <= (COUNT >  5'd2) ? 8'b11111111 : 8'b00000000;
            mask[31:24] <= (COUNT >  5'd3) ? 8'b11111111 : 8'b00000000;
        end
        else begin
            mask[15: 0] <= (COUNT >  5'd0) ? 16'b1111111111111111 : 16'b0000000000000000;
            mask[31:16] <= (COUNT >  5'd1) ? 16'b1111111111111111 : 16'b0000000000000000;
        end
    end

    /***************************************************************
     * mask をビットシフト
     ***************************************************************/
    reg [31:0] shifted_mask;
    always_ff @(posedge CLK) begin
        if(!DIX && CLRM == T9990_REG::CLRM_2BPP) begin
            case (OFFSET[3:0])
                5'd0:   shifted_mask <= mask;
                5'd1:   shifted_mask <= { 2'h0, mask[31: 2]};
                5'd2:   shifted_mask <= { 4'h0, mask[31: 4]};
                5'd3:   shifted_mask <= { 6'h0, mask[31: 6]};
                5'd4:   shifted_mask <= { 8'h0, mask[31: 8]};
                5'd5:   shifted_mask <= {10'h0, mask[31:10]};
                5'd6:   shifted_mask <= {12'h0, mask[31:12]};
                5'd7:   shifted_mask <= {14'h0, mask[31:14]};
                5'd8:   shifted_mask <= {16'h0, mask[31:16]};
                5'd9:   shifted_mask <= {18'h0, mask[31:18]};
                5'd10:  shifted_mask <= {20'h0, mask[31:20]};
                5'd11:  shifted_mask <= {22'h0, mask[31:22]};
                5'd12:  shifted_mask <= {24'h0, mask[31:24]};
                5'd13:  shifted_mask <= {26'h0, mask[31:26]};
                5'd14:  shifted_mask <= {28'h0, mask[31:28]};
                5'd15:  shifted_mask <= {30'h0, mask[31:30]};
            endcase
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_4BPP) begin
            case (OFFSET[2:0])
                5'd0:   shifted_mask <= mask;
                5'd1:   shifted_mask <= { 4'h0, mask[31: 4]};
                5'd2:   shifted_mask <= { 8'h0, mask[31: 8]};
                5'd3:   shifted_mask <= {12'h0, mask[31:12]};
                5'd4:   shifted_mask <= {16'h0, mask[31:16]};
                5'd5:   shifted_mask <= {20'h0, mask[31:20]};
                5'd6:   shifted_mask <= {24'h0, mask[31:24]};
                5'd7:   shifted_mask <= {28'h0, mask[31:28]};
            endcase
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_8BPP) begin
            case (OFFSET[1:0])
                5'd0:   shifted_mask <= mask;
                5'd1:   shifted_mask <= { 8'h0, mask[31: 8]};
                5'd2:   shifted_mask <= {16'h0, mask[31:16]};
                5'd3:   shifted_mask <= {24'h0, mask[31:24]};
            endcase
        end
        else if(!DIX && CLRM == T9990_REG::CLRM_16BPP) begin
            case (OFFSET[0:0])
                5'd0:   shifted_mask <= mask;
                5'd1:   shifted_mask <= {16'h0, mask[31:16]};
            endcase
        end

        else if(DIX && CLRM == T9990_REG::CLRM_2BPP) begin
            case (OFFSET[3:0])
                5'd15:  shifted_mask <= mask;
                5'd14:  shifted_mask <= {mask[29:0],  2'h0};
                5'd13:  shifted_mask <= {mask[27:0],  4'h0};
                5'd12:  shifted_mask <= {mask[25:0],  6'h0};
                5'd11:  shifted_mask <= {mask[23:0],  8'h0};
                5'd10:  shifted_mask <= {mask[21:0], 10'h0};
                5'd9:   shifted_mask <= {mask[19:0], 12'h0};
                5'd8:   shifted_mask <= {mask[17:0], 14'h0};
                5'd7:   shifted_mask <= {mask[15:0], 16'h0};
                5'd6:   shifted_mask <= {mask[13:0], 18'h0};
                5'd5:   shifted_mask <= {mask[11:0], 20'h0};
                5'd4:   shifted_mask <= {mask[ 9:0], 22'h0};
                5'd3:   shifted_mask <= {mask[ 7:0], 24'h0};
                5'd2:   shifted_mask <= {mask[ 5:0], 26'h0};
                5'd1:   shifted_mask <= {mask[ 3:0], 28'h0};
                5'd0:   shifted_mask <= {mask[ 1:0], 30'h0};
            endcase
        end
        else if(DIX && CLRM == T9990_REG::CLRM_4BPP) begin
            case (OFFSET[2:0])
                5'd7:   shifted_mask <= mask;
                5'd6:   shifted_mask <= {mask[27:0],  4'h0};
                5'd5:   shifted_mask <= {mask[23:0],  8'h0};
                5'd4:   shifted_mask <= {mask[19:0], 12'h0};
                5'd3:   shifted_mask <= {mask[15:0], 16'h0};
                5'd2:   shifted_mask <= {mask[11:0], 20'h0};
                5'd1:   shifted_mask <= {mask[ 7:0], 24'h0};
                5'd0:   shifted_mask <= {mask[ 3:0], 28'h0};
            endcase
        end
        else if(DIX && CLRM == T9990_REG::CLRM_8BPP) begin
            case (OFFSET[1:0])
                5'd3:   shifted_mask <= mask;
                5'd2:   shifted_mask <= {mask[23:0],  8'h0};
                5'd1:   shifted_mask <= {mask[15:0], 16'h0};
                5'd0:   shifted_mask <= {mask[ 7:0], 24'h0};
            endcase
        end
        else begin
            case (OFFSET[0:0])
                5'd1:   shifted_mask <= mask;
                5'd0:   shifted_mask <= {mask[15:0], 16'h0};
            endcase
        end
    end

    /***************************************************************
     * WM レジスタでマスク
     ***************************************************************/
    always_ff @(posedge CLK) begin
        if(!P1)       BIT_MASK <= shifted_mask & {WM, WM};                                  // P1 モード以外
        else if(VRAM) BIT_MASK <= shifted_mask & {WM[15:8], WM[15:8], WM[15:8], WM[15:8]};  // P1 モード VRAM1
        else          BIT_MASK <= shifted_mask & {WM[ 7:0], WM[ 7:0], WM[ 7:0], WM[ 7:0]};  // P1 モード VRAM0
    end
endmodule

`default_nettype wire
