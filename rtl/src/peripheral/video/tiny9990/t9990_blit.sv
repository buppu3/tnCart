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

// POINT, PSET, ADVANCE, LINE, SEARCH のテストはまだ
`define ENABLE_POINT
`define ENABLE_PSET
`define ENABLE_ADVANCE
`define ENABLE_LINE
`define ENABLE_SRCH

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

`ifndef ENABLE_SRCH
    assign STATUS.BD = 0;
    assign STATUS.BX = 0;
`endif

    reg src_is_cpu;
    reg src_is_linear;
    reg src_is_xy;
    reg src_is_vdp;
    reg src_is_rom;
    reg src_is_char;
    reg dst_is_cpu;
    reg dst_is_linear;
    reg dst_is_xy;

    // CHAR 用ワーク構造体
    typedef struct {
        reg [5:0] decode_count;
        reg [31:0] decode_data;
    } char_work_t;

    // LINE 用ワーク構造体
    typedef struct {
        reg [11:0]   cnt;       // ループ回数
        reg [11+1:0] sum;       // DDA 用
    } line_work_t;

    // SEARCH 用ワーク構造体
    typedef struct {
        reg clr_neq;            // 色データ不一致
        reg edge_left;          // 左端検出
        reg edge_right;         // 右端検出
    } srch_work_t;
wire srch_clr_neq = work.srch.clr_neq;
wire srch_edge_left = work.srch.edge_left;
wire srch_edge_right = work.srch.edge_left;

    // LINE / SEARCH 用ワーク
    union {
        char_work_t char;
        line_work_t line;
        srch_work_t srch;
    } work;

    reg is_line;                // LINE コマンド実行中
    reg is_srch;                // SEARCH コマンド実行中
    reg is_point;               // POINT コマンド実行中
    reg req_dst_vram;           // DST 読み出し要求
    reg src_enable;             // SRC 読み出し許可

    reg [1:0]  XIMM;
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
    reg [3:0] ENQUEUE_SHIFT;
    reg [31:0] ENQUEUE_DATA;
    reg DEQUEUE;
    reg [4:0] DEQUEUE_COUNT;
    reg [3:0] DEQUEUE_SHIFT;
    wire [31:0] DEQUEUE_DATA;
    wire [5:0] FREE_COUNT;
    wire [5:0] AVAIL_COUNT;
    T9990_BLIT_FIFO u_fifo (
        .RESET_n,
        .CLK,
        .CLK_EN,
        .CLRM(SRC_CLRM),
        .FREE_COUNT,
        .AVAIL_COUNT,
        .CLEAR(FIFO_CLEAR),
        .ENQUEUE,
        .ENQUEUE_COUNT,
//        .ENQUEUE_SHIFT,
        .ENQUEUE_DATA,
        .DEQUEUE,
        .DEQUEUE_COUNT,
        .DEQUEUE_SHIFT,
        .DEQUEUE_DATA
    );

    reg [18:0] SRC_XY_ADDR;
    T9990_BLIT_ADDR u_src_addr (
        .CLK,
        .CLRM(SRC_CLRM),
        .P1,
        .XIMM,
        .X(SRC_X[10:0]),
        .Y(SRC_Y),
        .ADDR(SRC_XY_ADDR)
    );

    reg [18:0] DST_XY_ADDR;
    T9990_BLIT_ADDR u_dst_addr (
        .CLK,
        .CLRM(DST_CLRM),
        .P1,
        .XIMM,
        .X(DST_X[10:0]),
        .Y(DST_Y),
        .ADDR(DST_XY_ADDR)
    );

    reg [4:0] SRC_COUNT;
    T9990_BLIT_CALC_COUNT u_src_cnt (
        .CLK,
        .CPU_MODE(src_is_cpu),
        .IS_POINT(is_point || is_srch),
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
        .IS_POINT(is_point || is_srch),
        .CLRM(DST_CLRM),
        .DIX(DST_DIX),
        .OFFSET(DST_X[3:0]),
        .REMAIN(DST_NX),
        .COUNT(DST_COUNT)
    );

    // 転送先座標からビットマスクを計算
    reg [31:0] BIT_MASK;
    T9990_BLIT_BITMASK u_bitmsk (
        .CLK,
        .WM(REG.WM),
        .CLRM(DST_CLRM),
        .DIX(DST_DIX),
        .OFFSET(DST_X[3:0]),
        .COUNT(DST_COUNT),
        .BIT_MASK(BIT_MASK)
    );

    // P1 モード検出
    reg P1;

    // ENQUEUE 可能か？
    reg ena_enqueue;
    always_ff @(posedge CLK) if(CLK_EN) ena_enqueue <= FREE_COUNT >= SRC_OUT_COUNT && src_enable;

    reg [15:0] save_mem_dout;       // P1 モード VRAM0 データ一時保存用

    wire [31:0] src_data_le = {SRC_DATA[7:0], SRC_DATA[15:8], SRC_DATA[23:16], SRC_DATA[31:24]};        // ロジカルオペレーション SRC データ(リトルエンディアン)
    wire [31:0] bit_mask_le = {BIT_MASK[7:0], BIT_MASK[15:8], BIT_MASK[23:16], BIT_MASK[31:24]};        // ビットマスク(リトルエンディアン)
    wire [31:0] masked_src_data_le = src_data_le & bit_mask_le;                                         // ビットマスク後の SRC データ(リトルエンディアン)

    wire [31:0] cmd_mem_dout_p1_be  = { save_mem_dout[7:0], CMD_MEM.DOUT[7:0], save_mem_dout[15:8], CMD_MEM.DOUT[15:8]};    // 転送元 VRAM 読み出しデータ(P1モード、ビッグエンディアン)
    wire [31:0] cmd_mem_dout_np1_be = { CMD_MEM.DOUT[7:0], CMD_MEM.DOUT[15:8], CMD_MEM.DOUT[23:16], CMD_MEM.DOUT[31:24]};   // 転送元 VRAM 読み出しデータ(ビッグエンディアン)
    wire [31:0] cmd_mem_dout_be  = P1 ? cmd_mem_dout_p1_be : cmd_mem_dout_np1_be;                                           // 転送元 VRAM 読み出しデータ

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
        STATE_LINE_LOOP,
        STATE_LINE_CHECK,
        STATE_LINE_NEXT_MI,
        STATE_LINE_NEXT_MJ,
        STATE_SEARCH,
        STATE_SEARCH_LOOP,
        STATE_SEARCH_CHECK,
        STATE_SEARCH_NEXT,
        STATE_SETUP,
        STATE_SETUP2,
        STATE_SETUP3,
        STATE_SRC_IN,
        STATE_SRC_READ_P1_EVEN_VRAM_WAIT_ACK,
        STATE_SRC_READ_P1_EVEN_VRAM_WAIT_BUSY,
        STATE_SRC_READ_P1_ODD_VRAM_WAIT_ACK,
        STATE_SRC_READ_P1_ODD_VRAM_WAIT_BUSY,
        STATE_SRC_READ_VRAM_WAIT_ACK,
        STATE_SRC_READ_VRAM_WAIT_BUSY,
        STATE_SRC_READ_VRAM_CONV_2N,
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
        STATE_DST_READ_P1_EVEN_VRAM_WAIT_ACK,
        STATE_DST_READ_P1_EVEN_VRAM_WAIT_BUSY,
        STATE_DST_READ_P1_ODD_VRAM_WAIT_ACK,
        STATE_DST_READ_P1_ODD_VRAM_WAIT_BUSY,
        STATE_DST_READ_VRAM_WAIT_ACK,
        STATE_DST_READ_VRAM_WAIT_BUSY,
        STATE_SRC_DEQUEUE_DONE,
        STATE_LOGOP,
        STATE_DST_WRITE,
        STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_ACK,
        STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_BUSY,
        STATE_DST_WRITE_P1_ODD_VRAM_WAIT_ACK,
        STATE_DST_WRITE_VRAM_WAIT_ACK,
        STATE_DST_WRITE_CPU_H_WAIT_ACK,
        STATE_DST_WRITE_CPU_H_WAIT_BUSY,
        STATE_DST_WRITE_CPU_WAIT_ACK,
        STATE_DST_WRITE_WAIT,
        STATE_COMPLETE
    } state;
localparam STATE_DST_WRITE_P1_ODD_VRAM_WAIT_BUSY = STATE_DST_WRITE_WAIT;
localparam STATE_DST_WRITE_VRAM_WAIT_BUSY        = STATE_DST_WRITE_WAIT;
localparam STATE_DST_WRITE_CPU_WAIT_BUSY         = STATE_DST_WRITE_WAIT;

    reg src_nx_over;
    reg dst_nx_over;
    reg src_change_x;
    reg dst_change_x;
    reg src_change_y;
    reg dst_change_y;

    always_ff @(posedge CLK) begin
        src_nx_over <= SRC_NX <= SRC_POS_COUNT;
        dst_nx_over <= DST_NX <= DST_POS_COUNT;
        src_change_x <= !(is_srch || is_line);
        dst_change_x <= !(is_srch || is_line);
        src_change_y <= !(is_srch || is_line) && SRC_NX <= SRC_POS_COUNT;
        dst_change_y <= !(is_srch || is_line) && DST_NX <= DST_POS_COUNT;
    end

    always_ff @(posedge CLK) begin
        if(REG.DSPM[1]) begin
            // bitmap mode
            XIMM <= REG.XIMM;
            P1 <= 0;
        end
        else if(REG.DSPM[0]) begin
            // P2 mode
            XIMM <= T9990_REG::XIMM_512;
            P1 <= 0;
        end
        else begin
            // P1 mode
            XIMM <= T9990_REG::XIMM_256;
            P1 <= 1;
        end
    end

    always_ff @(posedge CLK) begin
        // SRC_CLRM
        if(REG.OP == T9990_REG::CMD_CMMM || REG.OP == T9990_REG::CMD_BMXL|| REG.OP == T9990_REG::CMD_BMLL) begin
            // byte mode
            SRC_CLRM <= T9990_REG::CLRM_8BPP;
        end
        else if(REG.DSPM[1]) begin
            // bitmap mode
            SRC_CLRM <= REG.CLRM;
        end
        else begin
            // P1/P2 mode
            SRC_CLRM <= T9990_REG::CLRM_4BPP;
        end
    end

    always_ff @(posedge CLK) begin
        // DST_CLRM
        if(REG.OP == T9990_REG::CMD_BMLX || REG.OP == T9990_REG::CMD_BMLL) begin
            // byte mode
            DST_CLRM <= T9990_REG::CLRM_8BPP;
        end
        else if(REG.DSPM[1]) begin
            // bitmap mode
            DST_CLRM <= REG.CLRM;
        end
        else begin
            // P1/P2 mode
            DST_CLRM <= T9990_REG::CLRM_4BPP;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            P2_CPU_TO_VDP.REQ <= 0;
            P2_VDP_TO_CPU.REQ <= 0;
            STATUS.TR <= 0;
            STATUS.CE <= 0;
            STATUS.CE_intr <= 0;
            state <= STATE_IDLE;
            FIFO_CLEAR <= 0;
            CMD_MEM.OE_n <= 1;
            CMD_MEM.WE_n <= 1;
            CMD_MEM.ADDR <= 0;
            CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
        end

        //
        // STOP 書き込み時処理
        //
        else if(START && REG.OP == T9990_REG::CMD_STOP) begin
            state <= STATE_STOP;
            P2_CPU_TO_VDP.REQ <= 0;
            P2_VDP_TO_CPU.REQ <= 0;
            STATUS.TR <= 0;
            STATUS.CE_intr <= 0;
        end

        //
        // STOP コマンド: 転送が終了するまで待機
        //
        else if(state == STATE_STOP) begin
            if(!P2_CPU_TO_VDP.ACK && !P2_VDP_TO_CPU.ACK) begin
                STATUS.CE <= 0;
                STATUS.CE_intr <= 0;
                state <= STATE_IDLE;
            end
        end

        //
        // アイドル
        //
        else if(state == STATE_IDLE) begin
            STATUS.CE_intr <= 0;

            if(START) begin
                FIFO_CLEAR <= 1;

                STATUS.CE <= 1;

                src_enable <= 1;

                work.char.decode_data <= 0;
                work.char.decode_count <= 0;

                // SRC_NX, SRC_NY, DST_NX, DST_NY
                if(REG.OP == T9990_REG::CMD_BMLL) begin
                    // 転送バイト数
                    SRC_NX <= REG.NA;
                    SRC_NY <= 1'd1;
                    DST_NX <= REG.NA;
                    DST_NY <= 1'd1;
                end
                else if(REG.OP == T9990_REG::CMD_POINT || REG.OP == T9990_REG::CMD_PSET || REG.OP == T9990_REG::CMD_ADVN) begin
                    // 転送ドット数
                    SRC_NX <= 1;
                    SRC_NY <= 1;
                    DST_NX <= 1;
                    DST_NY <= 1;
                end
                else begin
                    // 転送ドット数
                    SRC_NX <= REG.NX == 0 ? 12'd2048 : REG.NX;
                    SRC_NY <= REG.NY;
                    DST_NX <= REG.NX == 0 ? 12'd2048 : REG.NX;
                    DST_NY <= REG.NY;
                end

                // SRC_X, SRC_Y, SRC_DIX
                if(REG.OP == T9990_REG::CMD_CMMM || REG.OP == T9990_REG::CMD_BMXL || REG.OP == T9990_REG::CMD_BMLL) begin
                    // 転送元アドレス
                    SRC_X <= REG.SA;
                    SRC_Y <= 0;
                    SRC_DIX <= 0;
                    src_is_linear <= 1;
                end
                else begin
                    // 転送元座標
                    SRC_X <= REG.SX;
                    SRC_Y <= REG.SY;
                    SRC_DIX <= REG.DIX;
                    src_is_linear <= 0;
                end

                // DST_X, DST_Y, DST_DIX
                if(REG.OP == T9990_REG::CMD_BMLX || REG.OP == T9990_REG::CMD_BMLL) begin
                    // 転送先アドレス
                    DST_X <= REG.DA;
                    DST_Y <= 0;
                    DST_DIX <= 0;
                    dst_is_linear <= 1;
                end
                else begin
                    // 転送先座標
                    DST_X <= REG.DX;
                    DST_Y <= REG.DY;
                    DST_DIX <= REG.DIX;
                    dst_is_linear <= 0;
                end

                //
                src_is_cpu <= (REG.OP == T9990_REG::CMD_LMMC) || (REG.OP == T9990_REG::CMD_CMMC);
                src_is_rom <= (REG.OP == T9990_REG::CMD_CMMK);
                src_is_vdp <= (REG.OP == T9990_REG::CMD_LMMV) || (REG.OP == T9990_REG::CMD_LINE) || (REG.OP == T9990_REG::CMD_PSET) || (REG.OP == T9990_REG::CMD_ADVN);
                src_is_char <= (REG.OP == T9990_REG::CMD_CMMC) || (REG.OP == T9990_REG::CMD_CMMK) || (REG.OP == T9990_REG::CMD_CMMM);
                dst_is_cpu <= (REG.OP == T9990_REG::CMD_LMCM) || (REG.OP == T9990_REG::CMD_POINT);
                src_is_xy <= (REG.OP == T9990_REG::CMD_LMCM) || (REG.OP == T9990_REG::CMD_LMMM) || (REG.OP == T9990_REG::CMD_BMLX) || (REG.OP == T9990_REG::CMD_SRCH) || (REG.OP == T9990_REG::CMD_POINT);
                dst_is_xy <= (REG.OP == T9990_REG::CMD_LMMC) || (REG.OP == T9990_REG::CMD_LMMV) || (REG.OP == T9990_REG::CMD_LMMM) || (REG.OP == T9990_REG::CMD_LINE) || (REG.OP == T9990_REG::CMD_PSET) || (REG.OP == T9990_REG::CMD_CMMC) || (REG.OP == T9990_REG::CMD_CMMK) || (REG.OP == T9990_REG::CMD_CMMM) || (REG.OP == T9990_REG::CMD_BMXL);

                //
                is_line <= (REG.OP == T9990_REG::CMD_LINE);
                is_srch <= (REG.OP == T9990_REG::CMD_SRCH);
                is_point <= (REG.OP == T9990_REG::CMD_POINT);

                // state
                case (REG.OP)
                    T9990_REG::CMD_LMMC:    state <= STATE_SETUP;
                    T9990_REG::CMD_LMMV:    state <= STATE_SETUP;
                    T9990_REG::CMD_LMCM:    state <= STATE_SETUP;
                    T9990_REG::CMD_LMMM:    state <= STATE_SETUP;
                    T9990_REG::CMD_CMMC:    state <= STATE_SETUP;
                    T9990_REG::CMD_CMMK:    state <= STATE_SETUP;
                    T9990_REG::CMD_CMMM:    state <= STATE_SETUP;
                    T9990_REG::CMD_BMXL:    state <= STATE_SETUP;
                    T9990_REG::CMD_BMLX:    state <= STATE_SETUP;
                    T9990_REG::CMD_BMLL:    state <= STATE_SETUP;
`ifdef ENABLE_LINE
                    T9990_REG::CMD_LINE:    state <= STATE_LINE;
`endif
`ifdef ENABLE_SRCH
                    T9990_REG::CMD_SRCH:    state <= STATE_SEARCH;
`endif
`ifdef ENABLE_POINT
                    T9990_REG::CMD_POINT:   state <= STATE_SETUP;
`endif
`ifdef ENABLE_PSET
                    T9990_REG::CMD_PSET:    state <= STATE_SETUP;
`endif
`ifdef ENABLE_ADVANCE
                    T9990_REG::CMD_ADVN:    state <= STATE_SETUP;
`endif
                    default:                state <= STATE_STOP;
                endcase
            end
        end

        //
        // 何もしない
        //
        else if(!CLK_EN) begin
        end

        //
        // SRC_COUNT, BIT_MASK 計算
        //
        else if(state == STATE_SETUP) begin
            FIFO_CLEAR <= 0;
            state <= STATE_SETUP2;
        end

        //
        // SRC_COUNT, BIT_MASK 確定
        //
        else if(state == STATE_SETUP2) begin
            state <= STATE_SETUP3;
        end

        //
        // ena_enqueue 確定
        //
        else if(state == STATE_SETUP3) begin
            state <= STATE_SRC_IN;
        end

        //
        // 転送元リード
        //
        else if(state == STATE_SRC_IN) begin
            //
            ENQUEUE_COUNT <= SRC_OUT_COUNT;

            // キャラクタデータが残ってるならデコード
            if(src_is_rom && work.char.decode_count != 0) begin
                state <= STATE_SRC_DECODE;
            end

            // 転送元データが必要なら読み出し開始
            else if(ena_enqueue) begin
                // VRAM リニア(P1モード)
                if(P1 && src_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= {1'b0, SRC_X[18:2], 1'b0};          // 偶数アドレス(VRAM0)読み出し
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                    state <= STATE_SRC_READ_P1_EVEN_VRAM_WAIT_ACK;
                end

                // VRAM 矩形(P1モード)
                //else if(P1 && src_is_xy) begin
                //    CMD_MEM.OE_n <= 0;
                //    CMD_MEM.ADDR <= {1'b0, SRC_XY_ADDR[18:2], 1'b0};    // 偶数アドレス(VRAM0)読み出し
                //    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                //    state <= STATE_SRC_READ_P1_EVEN_VRAM_WAIT_ACK;
                //end

                // VRAM リニア
                else if(src_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= {SRC_X[18:2], 2'b00};
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                    state <= STATE_SRC_READ_VRAM_WAIT_ACK;
                end

                // VRAM 矩形
                else if(src_is_xy) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= SRC_XY_ADDR;
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                    state <= STATE_SRC_READ_VRAM_WAIT_ACK;
                end

                // P#2
                else if(src_is_cpu) begin
                    P2_CPU_TO_VDP.REQ <= 1;
                    STATUS.TR <= 1;
                    state <= STATE_SRC_READ_CPU_WAIT_ACK;
                end

                // ROM
                else if(src_is_rom) begin
                    work.char.decode_data <= 0;
                    work.char.decode_count <= 6'd32;
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
        else if(state == STATE_SRC_READ_P1_EVEN_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_SRC_READ_P1_EVEN_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 読み出し完了したら 奇数アドレスを読み出し
        //
        else if(state == STATE_SRC_READ_P1_EVEN_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                // 偶数アドレスデータを保存
                save_mem_dout <= CMD_MEM.DOUT[15:0];

                // VRAM リニア(P1モード)
                //if(src_is_linear) begin
                    CMD_MEM.ADDR <= {1'b1, SRC_X[18:2], 1'b0};          // 奇数アドレス(VRAM1)読み出し
                //end
                // VRAM 矩形(P1モード)
                //else begin
                //    CMD_MEM.ADDR <= {1'b1, SRC_XY_ADDR[18:2], 1'b0};    // 奇数アドレス(VRAM1)読み出し
                //end

                CMD_MEM.OE_n <= 0;
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                state <= STATE_SRC_READ_P1_ODD_VRAM_WAIT_ACK;
            end
        end

        //
        // VRAM 読み出し要求を受け付けるまで待つ
        //
        else if(state == STATE_SRC_READ_P1_ODD_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_SRC_READ_P1_ODD_VRAM_WAIT_BUSY;
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
        else if(state == STATE_SRC_READ_VRAM_WAIT_BUSY || state == STATE_SRC_READ_P1_ODD_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                if(src_is_char) begin
                    state <= STATE_SRC_READ_VRAM_CONV_8C;
                    ENQUEUE_DATA <= cmd_mem_dout_be;
                end
                else begin
                    if(SRC_DIX) begin
                        // ドットを左右反転して転送元 VRAM データを ENQUEUE_DATA に格納
                        case (SRC_CLRM)
                            T9990_REG::CLRM_2BPP:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 1: 0], cmd_mem_dout_be[ 3: 2], cmd_mem_dout_be[ 5: 4], cmd_mem_dout_be[ 7: 6], cmd_mem_dout_be[ 9: 8], cmd_mem_dout_be[11:10], cmd_mem_dout_be[13:12], cmd_mem_dout_be[15:14], cmd_mem_dout_be[17:16], cmd_mem_dout_be[19:18], cmd_mem_dout_be[21:20], cmd_mem_dout_be[23:22], cmd_mem_dout_be[25:24], cmd_mem_dout_be[27:26], cmd_mem_dout_be[29:28], cmd_mem_dout_be[31:30]};
                            T9990_REG::CLRM_4BPP:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 3: 0], cmd_mem_dout_be[ 7: 4], cmd_mem_dout_be[11: 8], cmd_mem_dout_be[15:12], cmd_mem_dout_be[19:16], cmd_mem_dout_be[23:20], cmd_mem_dout_be[27:24], cmd_mem_dout_be[31:28]};
                            T9990_REG::CLRM_8BPP:   ENQUEUE_DATA <= {cmd_mem_dout_be[ 7: 0], cmd_mem_dout_be[15: 8], cmd_mem_dout_be[23:16], cmd_mem_dout_be[31:24]};
                            T9990_REG::CLRM_16BPP:  ENQUEUE_DATA <= {cmd_mem_dout_be[15: 0], cmd_mem_dout_be[31:16]};
                        endcase
                    end
                    else begin
                        // ドットを反転しないで転送元 VRAM データを ENQUEUE_DATA に格納
                        ENQUEUE_DATA <= cmd_mem_dout_be;
                    end

                    state <= STATE_SRC_READ_VRAM_CONV_2N;
                end

                // ビットシフト量を計算
                case ({SRC_DIX, SRC_CLRM})
                    {1'b0, T9990_REG::CLRM_2BPP}:   ENQUEUE_SHIFT <=   SRC_X[3:0];
                    {1'b0, T9990_REG::CLRM_4BPP}:   ENQUEUE_SHIFT <= { SRC_X[2:0], 1'b0};
                    {1'b0, T9990_REG::CLRM_8BPP}:   ENQUEUE_SHIFT <= { SRC_X[1:0], 2'b00};
                    {1'b0, T9990_REG::CLRM_16BPP}:  ENQUEUE_SHIFT <= { SRC_X[0:0], 3'b000};
                    {1'b1, T9990_REG::CLRM_2BPP}:   ENQUEUE_SHIFT <=  ~SRC_X[3:0];
                    {1'b1, T9990_REG::CLRM_4BPP}:   ENQUEUE_SHIFT <= {~SRC_X[2:0], 1'b0};
                    {1'b1, T9990_REG::CLRM_8BPP}:   ENQUEUE_SHIFT <= {~SRC_X[1:0], 2'b00};
                    {1'b1, T9990_REG::CLRM_16BPP}:  ENQUEUE_SHIFT <= {~SRC_X[0:0], 3'b000};
                endcase
            end
        end

        //
        // ビットシフトしてから FIFO へ格納
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_2N) begin
            case (ENQUEUE_SHIFT)
                4'd0:   ENQUEUE_DATA <= ENQUEUE_DATA;
                4'd1:   ENQUEUE_DATA <= {ENQUEUE_DATA[29:0],  2'b0};
                4'd2:   ENQUEUE_DATA <= {ENQUEUE_DATA[27:0],  4'b0};
                4'd3:   ENQUEUE_DATA <= {ENQUEUE_DATA[25:0],  6'b0};
                4'd4:   ENQUEUE_DATA <= {ENQUEUE_DATA[23:0],  8'b0};
                4'd5:   ENQUEUE_DATA <= {ENQUEUE_DATA[21:0], 10'b0};
                4'd6:   ENQUEUE_DATA <= {ENQUEUE_DATA[19:0], 12'b0};
                4'd7:   ENQUEUE_DATA <= {ENQUEUE_DATA[17:0], 14'b0};
                4'd8:   ENQUEUE_DATA <= {ENQUEUE_DATA[15:0], 16'b0};
                4'd9:   ENQUEUE_DATA <= {ENQUEUE_DATA[13:0], 18'b0};
                4'd10:  ENQUEUE_DATA <= {ENQUEUE_DATA[11:0], 20'b0};
                4'd11:  ENQUEUE_DATA <= {ENQUEUE_DATA[ 9:0], 22'b0};
                4'd12:  ENQUEUE_DATA <= {ENQUEUE_DATA[ 7:0], 24'b0};
                4'd13:  ENQUEUE_DATA <= {ENQUEUE_DATA[ 5:0], 26'b0};
                4'd14:  ENQUEUE_DATA <= {ENQUEUE_DATA[ 3:0], 28'b0};
                4'd15:  ENQUEUE_DATA <= {ENQUEUE_DATA[ 1:0], 30'b0};
            endcase

            ENQUEUE <= 1;
            state <= STATE_SRC_ENQUEUE_WAIT1;
        end

        //
        // データを順方向に並び替えて デコード
        //
        else if(state == STATE_SRC_READ_VRAM_CONV_8C) begin
            case (SRC_X[1:0])
                2'd0:   work.char.decode_data <= ENQUEUE_DATA;
                2'd1:   work.char.decode_data <= {ENQUEUE_DATA[23:0],  8'b0};
                2'd2:   work.char.decode_data <= {ENQUEUE_DATA[15:0], 16'b0};
                2'd3:   work.char.decode_data <= {ENQUEUE_DATA[ 7:0], 24'b0};
            endcase
            work.char.decode_count <= {SRC_OUT_COUNT[2:0], 3'b000};
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
                    work.char.decode_data <= {P2_CPU_TO_VDP.DATA, 24'b0};
                    work.char.decode_count <= 6'd8;
                    state <= STATE_SRC_DECODE;
                end
                else if(SRC_CLRM == T9990_REG::CLRM_16BPP) begin
                    ENQUEUE_DATA <= {8'b0, P2_CPU_TO_VDP.DATA, 16'b0};
                    P2_CPU_TO_VDP.REQ <= 1;
                    STATUS.TR <= 1;
                    state <= STATE_SRC_READ_CPU_H_WAIT_ACK;
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
            work.char.decode_count <= work.char.decode_count - 1'd1;

            if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                ENQUEUE_DATA <= {
                                    work.char.decode_data[31] ? REG.FC[15:14] : REG.BC[15:14],
                                    work.char.decode_data[30] ? REG.FC[13:12] : REG.BC[13:12],
                                    work.char.decode_data[29] ? REG.FC[11:10] : REG.BC[11:10],
                                    work.char.decode_data[28] ? REG.FC[ 9: 8] : REG.BC[ 9: 8],
                                    work.char.decode_data[27] ? REG.FC[ 7: 6] : REG.BC[ 7: 6],
                                    work.char.decode_data[26] ? REG.FC[ 5: 4] : REG.BC[ 5: 4],
                                    work.char.decode_data[25] ? REG.FC[ 3: 2] : REG.BC[ 3: 2],
                                    work.char.decode_data[24] ? REG.FC[ 1: 0] : REG.BC[ 1: 0],
                                    work.char.decode_data[23] ? REG.FC[15:14] : REG.BC[15:14],
                                    work.char.decode_data[22] ? REG.FC[13:12] : REG.BC[13:12],
                                    work.char.decode_data[21] ? REG.FC[11:10] : REG.BC[11:10],
                                    work.char.decode_data[20] ? REG.FC[ 9: 8] : REG.BC[ 9: 8],
                                    work.char.decode_data[19] ? REG.FC[ 7: 6] : REG.BC[ 7: 6],
                                    work.char.decode_data[18] ? REG.FC[ 5: 4] : REG.BC[ 5: 4],
                                    work.char.decode_data[17] ? REG.FC[ 3: 2] : REG.BC[ 3: 2],
                                    work.char.decode_data[16] ? REG.FC[ 1: 0] : REG.BC[ 1: 0]
                                };
                work.char.decode_data <= {work.char.decode_data[15:0], work.char.decode_data[31:16]};
            end
            else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                ENQUEUE_DATA <= {
                                    work.char.decode_data[31] ? REG.FC[15:12] : REG.BC[15:12],
                                    work.char.decode_data[30] ? REG.FC[11: 8] : REG.BC[11: 8],
                                    work.char.decode_data[29] ? REG.FC[ 7: 4] : REG.BC[ 7: 4],
                                    work.char.decode_data[28] ? REG.FC[ 3: 0] : REG.BC[ 3: 0],
                                    work.char.decode_data[27] ? REG.FC[15:12] : REG.BC[15:12],
                                    work.char.decode_data[26] ? REG.FC[11: 8] : REG.BC[11: 8],
                                    work.char.decode_data[25] ? REG.FC[ 7: 4] : REG.BC[ 7: 4],
                                    work.char.decode_data[24] ? REG.FC[ 3: 0] : REG.BC[ 3: 0]
                                };
                work.char.decode_data <= {work.char.decode_data[23:0], work.char.decode_data[31:24]};
            end
            else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                ENQUEUE_DATA <= {
                                    work.char.decode_data[31] ? REG.FC[15: 8] : REG.BC[15: 8],
                                    work.char.decode_data[30] ? REG.FC[ 7: 0] : REG.BC[ 7: 0],
                                    work.char.decode_data[29] ? REG.FC[15: 8] : REG.BC[15: 8],
                                    work.char.decode_data[28] ? REG.FC[ 7: 0] : REG.BC[ 7: 0]
                                };
                work.char.decode_data <= {work.char.decode_data[27:0], work.char.decode_data[31:28]};
            end
            else begin
                ENQUEUE_DATA <= {
                                    work.char.decode_data[31] ? REG.FC[15: 0] : REG.BC[15: 0],
                                    work.char.decode_data[30] ? REG.FC[15: 0] : REG.BC[15: 0]
                                };
                work.char.decode_data <= {work.char.decode_data[29:0], work.char.decode_data[31:30]};
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

            // 残り回数
            if(src_is_linear) begin
                SRC_NX <= SRC_NX - SRC_POS_COUNT;
            end
            else if(src_nx_over) begin
                // SRC_NY が 1->0 で転送元入力を禁止
                if(SRC_NY == 1'd1) src_enable <= 0;

                SRC_NX <= REG.NX == 0 ? 12'd2048 : REG.NX;
                SRC_NY <= SRC_NY - 1'd1;
            end
            else begin
                SRC_NX <= SRC_NX - SRC_POS_COUNT;
            end

            // 座標更新
            if(src_is_linear) begin
                // 隣へ移動
                SRC_X <= SRC_X + SRC_POS_COUNT;
            end
            else if(src_change_y) begin
                // 次の行の準備
                SRC_X <= REG.SX;
                SRC_Y <= REG.DIY ? (SRC_Y - 1'd1) : (SRC_Y + 1'd1);
            end
            else if(src_change_x) begin
                // 隣へ移動
                SRC_X <= SRC_DIX ? (SRC_X - SRC_POS_COUNT) : (SRC_X + SRC_POS_COUNT);
            end

            state <= STATE_SRC_DEQUEUE;
        end

        //
        // 出力データの準備
        //
        else if(state == STATE_SRC_DEQUEUE) begin
            // 転送先側の VRAM データが必要かどうかをチェック
            if(!(dst_is_linear || dst_is_xy))               req_dst_vram <= 0;  // VRAM に出力しない場合は必要なし
            else if(BIT_MASK != 32'hFFFF_FFFF)              req_dst_vram <= 1;  // ビットマスクに抜けがある場合は必要
            else if(REG.TP)                                 req_dst_vram <= 1;  // 透明色を使う場合は必要
            else if(REG.LO != 4'b1100 && REG.LO != 4'b0011) req_dst_vram <= 1;  // ビット演算を行う場合は必要
            else                                            req_dst_vram <= 0;  // それ以外は必要なし

            if(AVAIL_COUNT < DST_IN_COUNT) begin
                // 出力のためのデータが足りないので FIFO 入力を繰り返す
                state <= STATE_SETUP2;//state <= STATE_SRC_IN;
            end
            else begin
                // FIFO から取り出し
                DEQUEUE_COUNT <= DST_IN_COUNT;
                case ({DST_DIX, DST_CLRM})
                    {1'b0, T9990_REG::CLRM_2BPP}:  DEQUEUE_SHIFT <=   DST_X[3:0];
                    {1'b0, T9990_REG::CLRM_4BPP}:  DEQUEUE_SHIFT <= { DST_X[2:0], 1'b0};
                    {1'b0, T9990_REG::CLRM_8BPP}:  DEQUEUE_SHIFT <= { DST_X[1:0], 2'b0};
                    {1'b0, T9990_REG::CLRM_16BPP}: DEQUEUE_SHIFT <= { DST_X[0:0], 3'b0};
                    {1'b1, T9990_REG::CLRM_2BPP}:  DEQUEUE_SHIFT <=  ~DST_X[3:0];
                    {1'b1, T9990_REG::CLRM_4BPP}:  DEQUEUE_SHIFT <= {~DST_X[2:0], 1'b0};
                    {1'b1, T9990_REG::CLRM_8BPP}:  DEQUEUE_SHIFT <= {~DST_X[1:0], 2'b0};
                    {1'b1, T9990_REG::CLRM_16BPP}: DEQUEUE_SHIFT <= {~DST_X[0:0], 3'b0};
                endcase
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
                if(P1 && dst_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= {1'b0, DST_X[18:2], 1'b0};
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                    state <= STATE_DST_READ_P1_EVEN_VRAM_WAIT_ACK;
                end
                //else if(P1) begin
                //    CMD_MEM.OE_n <= 0;
                //    CMD_MEM.ADDR <= {1'b0, DST_XY_ADDR[18:2], 1'b0};
                //    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                //    state <= STATE_DST_READ_P1_EVEN_VRAM_WAIT_ACK;
                //end
                else if(dst_is_linear) begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= {DST_X[18:2], 2'b00};
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                    state <= STATE_DST_READ_VRAM_WAIT_ACK;
                end
                else begin
                    CMD_MEM.OE_n <= 0;
                    CMD_MEM.ADDR <= DST_XY_ADDR;
                    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                    state <= STATE_DST_READ_VRAM_WAIT_ACK;
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
        else if(state == STATE_DST_READ_P1_EVEN_VRAM_WAIT_ACK) begin
            DEQUEUE <= 0;
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_DST_READ_P1_EVEN_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 読み出し完了したら 奇数アドレス読み出し
        //
        else if(state == STATE_DST_READ_P1_EVEN_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                save_mem_dout <= CMD_MEM.DOUT[15:0];

                //if(dst_is_linear) begin
                    CMD_MEM.ADDR <= {1'b1, DST_X[18:2], 1'b0};
                //end
                //else begin
                //    CMD_MEM.ADDR <= {1'b1, DST_XY_ADDR[18:2], 1'b0};
                //end

                CMD_MEM.OE_n <= 0;
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                state <= STATE_DST_READ_P1_ODD_VRAM_WAIT_ACK;
            end
        end

        //
        // VRAM 読み出し要求を受け付けるまで待つ
        //
        else if(state == STATE_DST_READ_P1_ODD_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.OE_n <= 1;
                state <= STATE_DST_READ_P1_ODD_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 読み出し完了したら DST_DATA へ格納
        //
        else if(state == STATE_DST_READ_P1_ODD_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                // 偶数アドレスと奇数アドレスのデータを合成
                DST_DATA <= {CMD_MEM.DOUT[15:8], save_mem_dout[15:8], CMD_MEM.DOUT[7:0], save_mem_dout[7:0]};
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
        // VRAM 読み出し完了したら DST_DATA へ格納
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
                // 左右反転して SRC_DATA へ格納
                case (DST_CLRM)
                    T9990_REG::CLRM_2BPP:   SRC_DATA <= {DEQUEUE_DATA[ 1: 0], DEQUEUE_DATA[ 3: 2], DEQUEUE_DATA[ 5: 4], DEQUEUE_DATA[ 7: 6], DEQUEUE_DATA[ 9: 8], DEQUEUE_DATA[11:10], DEQUEUE_DATA[13:12], DEQUEUE_DATA[15:14], DEQUEUE_DATA[17:16], DEQUEUE_DATA[19:18], DEQUEUE_DATA[21:20], DEQUEUE_DATA[23:22], DEQUEUE_DATA[25:24], DEQUEUE_DATA[27:26], DEQUEUE_DATA[29:28], DEQUEUE_DATA[31:30]};
                    T9990_REG::CLRM_4BPP:   SRC_DATA <= {DEQUEUE_DATA[ 3: 0], DEQUEUE_DATA[ 7: 4], DEQUEUE_DATA[11: 8], DEQUEUE_DATA[15:12], DEQUEUE_DATA[19:16], DEQUEUE_DATA[23:20], DEQUEUE_DATA[27:24], DEQUEUE_DATA[31:28]};
                    T9990_REG::CLRM_8BPP:   SRC_DATA <= {DEQUEUE_DATA[ 7: 0], DEQUEUE_DATA[15: 8], DEQUEUE_DATA[23:16], DEQUEUE_DATA[31:24]};
                    T9990_REG::CLRM_16BPP:  SRC_DATA <= {DEQUEUE_DATA[15: 0], DEQUEUE_DATA[31:16]};
                endcase
            end
            else begin
                // 左右反転せずに SRC_DATA へ格納
                SRC_DATA <= DEQUEUE_DATA;
            end

            state <= STATE_LOGOP;
        end

        //
        // ロジカルオペレーション
        //
        else if(state == STATE_LOGOP) begin
            if(REG.TP) begin
                // 1ドット毎に 0 と比較してライトデータを作成
                if(DST_CLRM == T9990_REG::CLRM_2BPP) begin
                    WRT_DATA <= {
                        (masked_src_data_le[31:30] != 0) ? LOGOP[31:30] : DST_DATA[31:30],
                        (masked_src_data_le[29:28] != 0) ? LOGOP[29:28] : DST_DATA[29:28],
                        (masked_src_data_le[27:26] != 0) ? LOGOP[27:26] : DST_DATA[27:26],
                        (masked_src_data_le[25:24] != 0) ? LOGOP[25:24] : DST_DATA[25:24],
                        (masked_src_data_le[23:22] != 0) ? LOGOP[23:22] : DST_DATA[23:22],
                        (masked_src_data_le[21:20] != 0) ? LOGOP[21:20] : DST_DATA[21:20],
                        (masked_src_data_le[19:18] != 0) ? LOGOP[19:18] : DST_DATA[19:18],
                        (masked_src_data_le[17:16] != 0) ? LOGOP[17:16] : DST_DATA[17:16],
                        (masked_src_data_le[15:14] != 0) ? LOGOP[15:14] : DST_DATA[15:14],
                        (masked_src_data_le[13:12] != 0) ? LOGOP[13:12] : DST_DATA[13:12],
                        (masked_src_data_le[11:10] != 0) ? LOGOP[11:10] : DST_DATA[11:10],
                        (masked_src_data_le[ 9: 8] != 0) ? LOGOP[ 9: 8] : DST_DATA[ 9: 8],
                        (masked_src_data_le[ 7: 6] != 0) ? LOGOP[ 7: 6] : DST_DATA[ 7: 6],
                        (masked_src_data_le[ 5: 4] != 0) ? LOGOP[ 5: 4] : DST_DATA[ 5: 4],
                        (masked_src_data_le[ 3: 2] != 0) ? LOGOP[ 3: 2] : DST_DATA[ 3: 2],
                        (masked_src_data_le[ 1: 0] != 0) ? LOGOP[ 1: 0] : DST_DATA[ 1: 0]
                    };
                end
                else if(DST_CLRM == T9990_REG::CLRM_4BPP) begin
                    WRT_DATA <= {
                        (masked_src_data_le[31:28] != 0) ? LOGOP[31:28] : DST_DATA[31:28],
                        (masked_src_data_le[27:24] != 0) ? LOGOP[27:24] : DST_DATA[27:24],
                        (masked_src_data_le[23:20] != 0) ? LOGOP[23:20] : DST_DATA[23:20],
                        (masked_src_data_le[19:16] != 0) ? LOGOP[19:16] : DST_DATA[19:16],
                        (masked_src_data_le[15:12] != 0) ? LOGOP[15:12] : DST_DATA[15:12],
                        (masked_src_data_le[11: 8] != 0) ? LOGOP[11: 8] : DST_DATA[11: 8],
                        (masked_src_data_le[ 7: 4] != 0) ? LOGOP[ 7: 4] : DST_DATA[ 7: 4],
                        (masked_src_data_le[ 3: 0] != 0) ? LOGOP[ 3: 0] : DST_DATA[ 3: 0]
                    };
                end
                else if(DST_CLRM == T9990_REG::CLRM_8BPP) begin
                    WRT_DATA <= {
                        (masked_src_data_le[31:24] != 0) ? LOGOP[31:24] : DST_DATA[31:24],
                        (masked_src_data_le[23:16] != 0) ? LOGOP[23:16] : DST_DATA[23:16],
                        (masked_src_data_le[15: 8] != 0) ? LOGOP[15: 8] : DST_DATA[15: 8],
                        (masked_src_data_le[ 7: 0] != 0) ? LOGOP[ 7: 0] : DST_DATA[ 7: 0]
                    };
                end
                else begin
                    WRT_DATA <= {
                        (masked_src_data_le[31:16] != 0) ? LOGOP[31:16] : DST_DATA[31:16],
                        (masked_src_data_le[15: 0] != 0) ? LOGOP[15: 0] : DST_DATA[15: 0]
                    };
                end
            end
            else begin
                // ライトデータを作成
                WRT_DATA <= (LOGOP & bit_mask_le) | (DST_DATA & ~bit_mask_le);
            end

            state <= STATE_DST_WRITE;
        end

        //
        // データ書き込み
        //
        else if(state == STATE_DST_WRITE) begin
            if(P1 && dst_is_linear) begin
                CMD_MEM.WE_n <= 0;
                CMD_MEM.ADDR <= { 1'b0, DST_X[18:2], 1'b0};         // 偶数アドレス(VRAM0)書き込み
                CMD_MEM.DIN <= {WRT_DATA[23:16], WRT_DATA[7:0], WRT_DATA[23:16], WRT_DATA[7:0]};
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                state <= STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_ACK;
            end
            //else if(P1 && dst_is_xy) begin
            //    CMD_MEM.WE_n <= 0;
            //    CMD_MEM.ADDR <= { 1'b0, DST_XY_ADDR[18:2], 1'b0}; // 偶数アドレス(VRAM0)書き込み
            //    CMD_MEM.DIN <= {WRT_DATA[23:16], WRT_DATA[7:0], WRT_DATA[23:16], WRT_DATA[7:0]};
            //    CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
            //    state <= STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_ACK;
            //end
            else if(dst_is_linear) begin
                CMD_MEM.WE_n <= 0;
                CMD_MEM.ADDR <= {DST_X[18:2], 2'b00};
                CMD_MEM.DIN <= WRT_DATA;
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                state <= STATE_DST_WRITE_VRAM_WAIT_ACK;
            end
            else if(dst_is_xy) begin
                CMD_MEM.WE_n <= 0;
                CMD_MEM.ADDR <= DST_XY_ADDR;
                CMD_MEM.DIN <= WRT_DATA;
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_32;
                state <= STATE_DST_WRITE_VRAM_WAIT_ACK;
            end
            else if(dst_is_cpu) begin
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
            else begin
                state <= STATE_DST_WRITE_CPU_WAIT_BUSY;
            end
        end

        //
        // VRAM 書き込み要求を受け付けるまで待つ
        //
        else if(state == STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.WE_n <= 1;
                state <= STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_BUSY;
            end
        end

        //
        // VRAM 書き込み完了したら 奇数を書き込み
        //
        else if(state == STATE_DST_WRITE_P1_EVEN_VRAM_WAIT_BUSY) begin
            if(!CMD_MEM.BUSY) begin
                //if(dst_is_linear) begin
                    CMD_MEM.ADDR <= { 1'b1, DST_X[18:2], 1'b0};         // 奇数アドレス(VRAM1)書き込み
                //end
                //else begin
                //    CMD_MEM.ADDR <= { 1'b1, DST_XY_ADDR[18:2], 1'b0}; // 奇数アドレス(VRAM1)書き込み
                //end
                CMD_MEM.DIN <= {WRT_DATA[31:24], WRT_DATA[15:8], WRT_DATA[31:24], WRT_DATA[15:8]};
                CMD_MEM.WE_n <= 0;
                CMD_MEM.DIN_SIZE <= RAM::DIN_SIZE_16;
                state <= STATE_DST_WRITE_P1_ODD_VRAM_WAIT_ACK;
            end
        end

        //
        // VRAM 書き込み要求を受け付けるまで待つ
        //
        else if(state == STATE_DST_WRITE_P1_ODD_VRAM_WAIT_ACK) begin
            if(CMD_MEM.BUSY) begin
                CMD_MEM.WE_n <= 1;
                state <= STATE_DST_WRITE_P1_ODD_VRAM_WAIT_BUSY;
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
        else if(state == STATE_DST_WRITE_WAIT) begin
            if(!CMD_MEM.BUSY && !P2_VDP_TO_CPU.ACK) begin
                // 残り回数
                if(dst_is_linear) begin
                    DST_NX <= DST_NX - DST_POS_COUNT;

                    // 終わり?
                    if(DST_NX <= DST_POS_COUNT) begin
                        state <= STATE_COMPLETE;
                    end
                    else begin
                        state <= STATE_SRC_IN;
                    end
                end
                else if(dst_nx_over) begin
                    DST_NX <= REG.NX == 0 ? 12'd2048 : REG.NX;
                    DST_NY <= DST_NY - 1'd1;

                    // 終わり?
                    if(DST_NY == 1'd1) begin
                        state <= STATE_COMPLETE;
                    end
                    else begin
                        state <= STATE_SRC_IN;
                    end
                end
                else begin
                    DST_NX <= DST_NX - DST_POS_COUNT;
                    state <= STATE_SRC_IN;
                end

                // 座標更新
                if(dst_is_linear) begin
                    DST_X <= DST_X + DST_POS_COUNT;
                end
                else if(dst_change_y) begin
                    DST_X <= REG.DX;
                    DST_Y <= REG.DIY ? (DST_Y - 1'd1) : (DST_Y + 1'd1);
                end
                else if(dst_change_x) begin
                    DST_X <= DST_DIX ? (DST_X - DST_POS_COUNT) : (DST_X + DST_POS_COUNT);
                end
            end
        end

        else if(state == STATE_COMPLETE) begin
`ifdef ENABLE_LINE
            if(is_line) begin
                state <= STATE_LINE_LOOP;
            end
            else
`endif
`ifdef ENABLE_SRCH
            if(is_srch) begin
                state <= STATE_SEARCH_LOOP;
            end
            else
`endif
            begin
                //
                // ToDo:PSET と ADVANCE の座標更新
                //
                STATUS.CE <= 0;
                STATUS.CE_intr <= 1;
                state <= STATE_IDLE;
            end
        end

`ifdef ENABLE_LINE
        //
        // LINE
        //
        else if(state == STATE_LINE) begin
            //
            work.line.cnt <= REG.MJ;
            work.line.sum <= REG.MJ - 1'd1;
            SRC_DIX <= 0;
            DST_DIX <= 0;

            // PSET 実行
            SRC_X <= DST_X;
            SRC_Y <= DST_Y;
            SRC_NX <= 1;
            SRC_NY <= 1;
            DST_NX <= 1;
            DST_NY <= 1;
            src_enable <= 1;
            state <= STATE_SETUP;
        end
        else if(state == STATE_LINE_LOOP) begin
            work.line.sum <= work.line.sum - REG.MI;
            state <= STATE_LINE_CHECK;
        end
        else if(state == STATE_LINE_CHECK) begin
            // 終わりチェック
            work.line.cnt <= work.line.cnt - 1'd1;
            if(work.line.cnt == 1'd1) begin
                is_line <= 0;
                state <= STATE_COMPLETE;
            end
            else if(work.line.sum[$bits(work.line.sum)-1]) begin
                state <= STATE_LINE_NEXT_MI;
            end
            else begin
                state <= STATE_LINE_NEXT_MJ;
            end
        end
        else if(state == STATE_LINE_NEXT_MI) begin
            work.line.sum <= work.line.sum + REG.MJ;

            // マイナー軸移動
            if(REG.MAJ) begin
                DST_X <= REG.DIX ? (DST_X - 1'd1) : (DST_X + 1'd1);
            end
            else begin
                DST_Y <= REG.DIY ? (DST_Y - 1'd1) : (DST_Y + 1'd1);
            end
            state <= STATE_LINE_NEXT_MJ;
        end
        else if(state == STATE_LINE_NEXT_MJ) begin
            // メジャー軸移動
            if(REG.MAJ) begin
                DST_Y <= REG.DIY ? (DST_Y - 1'd1) : (DST_Y + 1'd1);
            end
            else begin
                DST_X <= REG.DIX ? (DST_X - 1'd1) : (DST_X + 1'd1);
            end

            // PSET 実行
            SRC_X <= DST_X;
            SRC_Y <= DST_Y;
            SRC_NX <= 1;
            SRC_NY <= 1;
            DST_NX <= 1;
            DST_NY <= 1;
            src_enable <= 1;
            state <= STATE_SETUP;
        end
`endif
`ifdef ENABLE_SRCH
        //
        // SEARCH
        //
        else if(state == STATE_SEARCH) begin
            // フラグクリア
            STATUS.BD <= 0;
            SRC_DIX <= 0;
            DST_DIX <= 0;

            // POINT 実行
            DST_X <= SRC_X;
            DST_Y <= SRC_Y;
            SRC_NX <= 1;
            SRC_NY <= 1;
            DST_NX <= 1;
            DST_NY <= 1;
            src_enable <= 1;
            state <= STATE_SETUP;
        end
        else if(state == STATE_SEARCH_LOOP) begin
            // ピクセルを比較
            work.srch.clr_neq <= ((SRC_DATA ^ {REG.FC,REG.FC}) & BIT_MASK) != 32'd0;
/*
            case(DST_CLRM)
                T9990_REG::CLRM_2BPP:   work.srch.clr_neq <= (WRT_DATA[15:14] ^ REG.FC[15:14]) != 2'b00;
                T9990_REG::CLRM_4BPP:   work.srch.clr_neq <= (WRT_DATA[15:12] ^ REG.FC[15:12]) != 4'b0000;
                T9990_REG::CLRM_8BPP:   work.srch.clr_neq <= (WRT_DATA[15: 8] ^ REG.FC[15: 8]) != 8'b0000_0000;
                default:                work.srch.clr_neq <= (WRT_DATA[15: 0] ^ REG.FC[15: 0]) != 16'b0000_0000_0000_0000;
            endcase
*/
            // 画面左端検出
            case(XIMM)
                T9990_REG::XIMM_256:    work.srch.edge_left <= SRC_X[ 7:0] == 0;
                T9990_REG::XIMM_512:    work.srch.edge_left <= SRC_X[ 8:0] == 0;
                T9990_REG::XIMM_1024:   work.srch.edge_left <= SRC_X[ 9:0] == 0;
                default:                work.srch.edge_left <= SRC_X[10:0] == 0;
            endcase
            // 画面右端検出
            case(XIMM)
                T9990_REG::XIMM_256:    work.srch.edge_right <= SRC_X[ 7:0] ==  8'b1111_1111;
                T9990_REG::XIMM_512:    work.srch.edge_right <= SRC_X[ 8:0] ==  9'b1_1111_1111;
                T9990_REG::XIMM_1024:   work.srch.edge_right <= SRC_X[ 9:0] == 10'b11_1111_1111;
                default:                work.srch.edge_right <= SRC_X[10:0] == 11'b111_1111_1111;
            endcase

            state <= STATE_SEARCH_CHECK;
        end
        else if(state == STATE_SEARCH_CHECK) begin
            // ピクセルデータチェック
            if(REG.NEQ == work.srch.clr_neq) begin
                // 完了
                STATUS.BD <= 1;
                STATUS.BX <= SRC_X[10:0];
                is_srch <= 0;
                state <= STATE_COMPLETE;
            end
            else begin
                state <= STATE_SEARCH_NEXT;
            end
        end
        else if(state == STATE_SEARCH_NEXT) begin
            SRC_NX <= 1;
            SRC_NY <= 1;
            DST_NX <= 1;
            DST_NY <= 1;
            src_enable <= 1;

            // 隣へ移動
            if(REG.DIX) begin
                // 左端チェック
                if(work.srch.edge_left) begin
                    // 左端で終了
                    is_srch <= 0;
                    state <= STATE_COMPLETE;
                end
                else begin
                    // 左へ移動
                    SRC_X[10:0] <= SRC_X[10:0] - 1'd1;
                    DST_X[10:0] <= SRC_X[10:0] - 1'd1;
                    // POINT 実行
                    state <= STATE_SETUP;
                end
            end
            else begin
                // 右端チェック
                if(work.srch.edge_right) begin
                    // 右端で終了
                    is_srch <= 0;
                    state <= STATE_COMPLETE;
                end
                else begin
                    // 右へ移動
                    SRC_X[10:0] <= SRC_X[10:0] + 1'd1;
                    DST_X[10:0] <= SRC_X[10:0] + 1'd1;
                    // POINT 実行
                    state <= STATE_SETUP;
                end
            end
        end
`endif
    end
endmodule

/***************************************************************
 * 処理するドット数を計算
 ***************************************************************/
module T9990_BLIT_CALC_COUNT (
    input wire          CLK,
    input wire          CPU_MODE,
    input wire          IS_POINT,
    input wire [1:0]    CLRM,
    input wire          DIX,
    input wire [3:0]    OFFSET,
    input wire [18:0]   REMAIN,
    output reg [4:0]    COUNT
);
    // 1クロック目
    reg [4:0] remain;
    always_ff @(posedge CLK) begin
        if(IS_POINT) remain <= 5'd1;
        else         remain <= (REMAIN[18:4] != 0) ? 5'd16 : REMAIN[3:0];
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

`default_nettype wire
