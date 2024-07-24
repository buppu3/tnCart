//
// t9990_sprite.sv
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

`define SPR_PAT_USE_DPB
//`define SPR_ATR_USE_DPB

/***************************************************************
 * スプライト/カーソル生成
 ***************************************************************/
module T9990_SPRITE #(
    parameter SPR_ATR_ADDR_P1 = 19'h3FE00,
    parameter SPR_ATR_ADDR_P2 = 19'h7BE00,
    parameter CUR_ATR_ADDR = 19'h7FE00,
    parameter CUR_PAT_ADDR = 19'h7FF00
) (
    input wire              RESET_n,
    input wire              CLK,
    input wire              DCLK_EN,
    input wire              DISABLE,

    T9990_REGISTER_IF.VDP   REG,

    input wire              FETCH_START,
    input wire              OUT_START,
    input wire [8:0]        VCNT,

    T9990_VDP_MEM_IF.VDP    MEM,

    output reg [5:0]        PA,
    output reg              EOR,
    output reg [1:0]        PRI
);

    localparam  MAX_SPR_PLANE_COUNT = 125;
    localparam  MAX_SPR_VIEW_COUNT = 16;
    localparam  MAX_CUR_PLANE_COUNT = 2;

    // Mode flag
    wire IS_P2 = REG.DSPM[0];
    wire IS_CUR = REG.DSPM == T9990_REG::DSPM_BITMAP;

    enum logic[3:0] {
        STATE_IDLE,
        STATE_SPR_ATR,
        STATE_SPR_PAT_START,
        STATE_SPR_PAT_L,
        STATE_SPR_PAT_R,
        STATE_CUR_ATR_L,
        STATE_CUR_ATR_H,
        STATE_CUR_PAT_START,
        STATE_CUR_PAT,
        STATE_OUT_INIT
    } state;

    /***************************************************************
     * アドレス
     ***************************************************************/
    wire [18:0] SPR_ATR_P1        = { SPR_ATR_ADDR_P1[18:9] , fetch_index[6:0], 2'b00 };
    wire [18:0] SPR_ATR_P2        = { SPR_ATR_ADDR_P2[18:9] , fetch_index[6:0], 2'b00 };
    wire [18:0] SPR_PAT_ADDR_P1_L = {1'b0, REG.SGBA[3:1], fetch_pat_num[7:4], fetch_pat_line[3:0], fetch_pat_num[3:0], 3'b000};
    wire [18:0] SPR_PAT_ADDR_P1_R = {1'b0, REG.SGBA[3:1], fetch_pat_num[7:4], fetch_pat_line[3:0], fetch_pat_num[3:0], 3'b100};
    wire [18:0] SPR_PAT_ADDR_P2_L = {      REG.SGBA[3:0], fetch_pat_num[7:5], fetch_pat_line[3:0], fetch_pat_num[4:0], 3'b000};
    wire [18:0] SPR_PAT_ADDR_P2_R = {      REG.SGBA[3:0], fetch_pat_num[7:5], fetch_pat_line[3:0], fetch_pat_num[4:0], 3'b100};
    wire [18:0] CUR_ATR_ADDR_L    = { CUR_ATR_ADDR[18:4], fetch_index[0], 3'b000 };
    wire [18:0] CUR_ATR_ADDR_H    = { CUR_ATR_ADDR[18:4], fetch_index[0], 3'b100 };
    wire [18:0] CUR_PAT_ADDR_LR   = { CUR_PAT_ADDR[18:8], fetch_index[0], fetch_pat_line[4:0], 2'b00 };

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            MEM.ADDR <= 0;
        end
        else if(DISABLE) begin
        end
        else if(FETCH_START) begin
            MEM.ADDR <= 0;
        end
        else if(MEM.REQ) begin
            case (state)
                STATE_SPR_ATR:   MEM.ADDR <= IS_P2 ? SPR_ATR_P2 : SPR_ATR_P1;
                STATE_SPR_PAT_L: MEM.ADDR <= IS_P2 ? SPR_PAT_ADDR_P2_L : SPR_PAT_ADDR_P1_L;
                STATE_SPR_PAT_R: MEM.ADDR <= IS_P2 ? SPR_PAT_ADDR_P2_R : SPR_PAT_ADDR_P1_R;
                STATE_CUR_ATR_L: MEM.ADDR <= CUR_ATR_ADDR_L;
                STATE_CUR_ATR_H: MEM.ADDR <= CUR_ATR_ADDR_H;
                STATE_CUR_PAT:   MEM.ADDR <= CUR_PAT_ADDR_LR;
            endcase
        end
    end

    /***************************************************************
     * リードデータ処理
     ***************************************************************/
    // Y座標が表示範囲内？
    wire [8:0] spr_signed_y = MEM.DOUT[7:0] >= 8'd240 ?  {1'b1, MEM.DOUT[7:0]} : {1'b0,MEM.DOUT[7:0]};
    wire [8:0] spr_offset_y = VCNT - spr_signed_y;
    wire spr_y_flag = (spr_offset_y[8:4] == 0);

    wire [8:0] cur_signed_y = {MEM.DOUT[16], MEM.DOUT[31:24]};
    wire [8:0] cur_offset_y = VCNT - cur_signed_y;
    wire cur_y_flag = (cur_offset_y[8:5] == 0);

`ifdef SPR_PAT_USE_DPB
    reg [3:0]   spr_pat_r_addr;
    wire [63:0] spr_pat_r_data;
    reg [3:0]   spr_pat_w_addr;
    reg         spr_pat_w_en;
    reg [63:0]  spr_pat_w_data;
    T9990_SPRITE_PATTERN u_pat (
        .RESET_n,
        .CLK,
        .W_ADDR(spr_pat_w_addr),
        .W_DATA(spr_pat_w_data),
        .W_EN(spr_pat_w_en),
        .R_ADDR(spr_pat_r_addr),
        .R_DATA(spr_pat_r_data)
    );

    // パターン読み出し
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            spr_pat_r_addr <= 0;
        end
        else if(FETCH_START) begin
            spr_pat_r_addr <= 0;
        end
        else if(!copy_count[4] || state == STATE_OUT_INIT) begin
            spr_pat_r_addr <= spr_pat_r_addr + 1'd1;
        end
        else begin
            spr_pat_r_addr <= 0;
        end
    end

    // パターン書き込み
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            spr_pat_w_en <= 0;
        end
        else if(MEM.ACK && state == STATE_SPR_PAT_L) begin
            spr_pat_w_data[63:32] <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24]};
            spr_pat_w_en <= 0;
        end
        else if(MEM.ACK && state == STATE_SPR_PAT_R) begin
            if(fetch_pat_xpos[9:4] == 6'b111111) begin
                // クリッピング
                spr_pat_w_data <= { spr_pat_w_data[63:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24]} << (4 * (1 + ~fetch_pat_xpos[3:0]));
/*
                case (fetch_pat_xpos[3:0])
                    4'b1111:    spr_pat_w_data <= { spr_pat_w_data[59:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24],  4'd0};  //  -1
                    4'b1110:    spr_pat_w_data <= { spr_pat_w_data[55:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24],  8'd0};  //  -2
                    4'b1101:    spr_pat_w_data <= { spr_pat_w_data[51:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 12'd0};  //  -3
                    4'b1100:    spr_pat_w_data <= { spr_pat_w_data[47:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 16'd0};  //  -4
                    4'b1011:    spr_pat_w_data <= { spr_pat_w_data[43:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 20'd0};  //  -5
                    4'b1010:    spr_pat_w_data <= { spr_pat_w_data[39:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 24'd0};  //  -6
                    4'b1001:    spr_pat_w_data <= { spr_pat_w_data[35:32], MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 28'd0};  //  -7
                    4'b1000:    spr_pat_w_data <= {                        MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 32'd0};  //  -8
                    4'b0111:    spr_pat_w_data <= {                        MEM.DOUT[3:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 36'd0};  //  -9
                    4'b0110:    spr_pat_w_data <= {                                       MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 40'd0};  // -10
                    4'b0101:    spr_pat_w_data <= {                                       MEM.DOUT[11:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 44'd0};  // -11
                    4'b0100:    spr_pat_w_data <= {                                                       MEM.DOUT[23:16], MEM.DOUT[31:24], 48'd0};  // -12
                    4'b0011:    spr_pat_w_data <= {                                                       MEM.DOUT[19:16], MEM.DOUT[31:24], 52'd0};  // -13
                    4'b0010:    spr_pat_w_data <= {                                                                        MEM.DOUT[31:24], 56'd0};  // -14
                    4'b0001:    spr_pat_w_data <= {                                                                        MEM.DOUT[27:24], 60'd0};  // -15
                    4'b0000:    spr_pat_w_data <= {                                                                                         64'd0};  // -16
                endcase
*/
            end
            else begin
                spr_pat_w_data[31:0] <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24]};
            end
            spr_pat_w_addr <= fetch_index[3:0];
            spr_pat_w_en <= 1;
        end
        else if(MEM.ACK && state == STATE_CUR_PAT) begin
            if(fetch_pat_xpos[9:5] == 5'b11111) begin
                // クリッピング
                spr_pat_w_data <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 32'h00000000 } << (1 + ~fetch_pat_xpos[4:0]);
/*
                case (fetch_pat_xpos[4:0])
                    5'b11111:   spr_pat_w_data <= { MEM.DOUT[6:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 33'd0 };   //  -1
                    5'b11110:   spr_pat_w_data <= { MEM.DOUT[5:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 34'd0 };   //  -2
                    5'b11101:   spr_pat_w_data <= { MEM.DOUT[4:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 35'd0 };   //  -3
                    5'b11100:   spr_pat_w_data <= { MEM.DOUT[3:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 36'd0 };   //  -4
                    5'b11011:   spr_pat_w_data <= { MEM.DOUT[2:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 37'd0 };   //  -5
                    5'b11010:   spr_pat_w_data <= { MEM.DOUT[1:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 38'd0 };   //  -6
                    5'b11001:   spr_pat_w_data <= { MEM.DOUT[0:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 39'd0 };   //  -7
                    5'b11000:   spr_pat_w_data <= {                MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 40'd0 };   //  -8
                    5'b10111:   spr_pat_w_data <= {                MEM.DOUT[14:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 41'd0 };   //  -9
                    5'b10110:   spr_pat_w_data <= {                MEM.DOUT[13:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 42'd0 };   // -10
                    5'b10101:   spr_pat_w_data <= {                MEM.DOUT[12:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 43'd0 };   // -11
                    5'b10100:   spr_pat_w_data <= {                MEM.DOUT[11:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 44'd0 };   // -12
                    5'b10011:   spr_pat_w_data <= {                MEM.DOUT[10:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 45'd0 };   // -13
                    5'b10010:   spr_pat_w_data <= {                MEM.DOUT[ 9:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 46'd0 };   // -14
                    5'b10001:   spr_pat_w_data <= {                MEM.DOUT[ 8:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 47'd0 };   // -15
                    5'b10000:   spr_pat_w_data <= {                                MEM.DOUT[23:16], MEM.DOUT[31:24], 48'd0 };   // -16
                    5'b01111:   spr_pat_w_data <= {                                MEM.DOUT[22:16], MEM.DOUT[31:24], 49'd0 };   // -17
                    5'b01110:   spr_pat_w_data <= {                                MEM.DOUT[21:16], MEM.DOUT[31:24], 50'd0 };   // -18
                    5'b01101:   spr_pat_w_data <= {                                MEM.DOUT[20:16], MEM.DOUT[31:24], 51'd0 };   // -19
                    5'b01100:   spr_pat_w_data <= {                                MEM.DOUT[19:16], MEM.DOUT[31:24], 52'd0 };   // -20
                    5'b01011:   spr_pat_w_data <= {                                MEM.DOUT[18:16], MEM.DOUT[31:24], 53'd0 };   // -21
                    5'b01010:   spr_pat_w_data <= {                                MEM.DOUT[17:16], MEM.DOUT[31:24], 54'd0 };   // -22
                    5'b01001:   spr_pat_w_data <= {                                MEM.DOUT[16:16], MEM.DOUT[31:24], 55'd0 };   // -23
                    5'b01000:   spr_pat_w_data <= {                                                 MEM.DOUT[31:24], 56'd0 };   // -24
                    5'b00111:   spr_pat_w_data <= {                                                 MEM.DOUT[30:24], 57'd0 };   // -25
                    5'b00110:   spr_pat_w_data <= {                                                 MEM.DOUT[29:24], 58'd0 };   // -26
                    5'b00101:   spr_pat_w_data <= {                                                 MEM.DOUT[28:24], 59'd0 };   // -27
                    5'b00100:   spr_pat_w_data <= {                                                 MEM.DOUT[27:24], 60'd0 };   // -28
                    5'b00011:   spr_pat_w_data <= {                                                 MEM.DOUT[26:24], 61'd0 };   // -29
                    5'b00010:   spr_pat_w_data <= {                                                 MEM.DOUT[25:24], 62'd0 };   // -30
                    5'b00001:   spr_pat_w_data <= {                                                 MEM.DOUT[24:24], 63'd0 };   // -31
                    5'b00000:   spr_pat_w_data <= {                                                                  64'd0 };   // -32
                endcase
*/
            end
            else begin
                spr_pat_w_data <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 32'h00000000 };
            end
            spr_pat_w_en <= 1;
            spr_pat_w_addr <= fetch_index[3:0];
        end
        else begin
            spr_pat_w_en <= 0;
        end
    end
`else
    logic [63:0] pat_buff[0:MAX_SPR_VIEW_COUNT-1] /* synthesis syn_ramstyle="block_ram" */;
`endif

`ifdef SPR_ATR_USE_DPB
    reg [3:0]   spr_atr_r_addr;
    wire [31:0] spr_atr_r_data;
    reg [3:0]   spr_atr_w_addr;
    reg         spr_atr_w_en;
    reg [31:0]  spr_atr_w_data;
    T9990_SPRITE_ATTRIBUTE u_atr (
        .RESET_n,
        .CLK,
        .W_ADDR(spr_atr_w_addr),
        .W_DATA(spr_atr_w_data),
        .W_EN(spr_atr_w_en),
        .R_ADDR(spr_atr_r_addr),
        .R_DATA(spr_atr_r_data)
    );

    // アトリビュート読み出し
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            spr_atr_r_addr <= 0;
        end
        else if(state == STATE_OUT_INIT) begin
            spr_atr_r_addr <= 4'd1;
        end
        else if(state == STATE_SPR_PAT_START) begin
            spr_atr_r_addr <= 4'd1;
        end
        else if(state == STATE_CUR_PAT_START) begin
            spr_atr_r_addr <= 4'd1;
        end
        else if(MEM.ACK && (state == STATE_SPR_PAT_R || state == STATE_CUR_PAT)) begin
            if(fetch_remain == 0) spr_atr_r_addr <= 0;
            else                  spr_atr_r_addr <= spr_atr_r_addr + 1'd1;
        end
        else if(state == STATE_IDLE && spr_atr_r_addr != 0) begin
            spr_atr_r_addr <= spr_atr_r_addr + 1'd1;
        end
    end

    // アトリビュート書き込み
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            spr_atr_w_en <= 0;
        end
        else if(fetch_attr) begin
            spr_atr_w_addr <= fetch_visible_count[3:0];
            spr_atr_w_data <= MEM.DOUT;
            spr_atr_w_en <= 1;
        end
        else if(MEM.ACK && state == STATE_CUR_ATR_L) begin
            spr_atr_w_data[15:0] <= {MEM.DOUT[7:0], MEM.DOUT[23:16]};
            spr_atr_w_en <= 0;
        end
        else if(MEM.ACK && state == STATE_CUR_ATR_L) begin
            spr_atr_w_data[15:0] <= {MEM.DOUT[7:0], MEM.DOUT[23:16]};
            spr_atr_w_en <= 0;
        end
        else if(MEM.ACK && state == STATE_CUR_ATR_H) begin
            spr_atr_w_addr <= fetch_index[3:0];
            spr_atr_w_data[31:16] <= cur_y_flag ? {MEM.DOUT[7:0], MEM.DOUT[23:16]} : 16'b0001_0000_0000_0000;
            spr_atr_w_en <= 1;
        end
        else begin
            spr_atr_w_en <= 0;
        end
    end

`else
    logic [31:0] atr_buff[0:MAX_SPR_VIEW_COUNT-1] /* synthesis syn_ramstyle="block_ram" */;
    logic [6:0] fetch_index_next;
`endif

    logic [6:0] fetch_remain;
    logic [6:0] fetch_index;
    logic [4:0] fetch_visible_count;
    logic [7:0] fetch_pat_num;
    logic [4:0] fetch_pat_line;
    logic       fetch_attr;
    logic [9:0] fetch_pat_xpos;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            fetch_attr <= 0;
            fetch_index <= 0;
            fetch_remain <= 0;
            state <= STATE_SPR_ATR;
        end
        else if(DISABLE) begin
        end

        // FETCH 開始
        else if(FETCH_START) begin
            fetch_attr <= 0;
            fetch_index <= 0;
            fetch_visible_count <= 0;
            fetch_remain <= IS_CUR ? (MAX_CUR_PLANE_COUNT - 1'd1) : (MAX_SPR_PLANE_COUNT - 1'd1);
            state <= IS_CUR ? STATE_CUR_ATR_L : STATE_SPR_ATR;
        end

        // 出力開始
        else if(state == STATE_OUT_INIT) begin
            state <= STATE_IDLE;
        end

        // スプライトパターン取得準備
        else if(state == STATE_SPR_PAT_START) begin
            // 最初のパターン
`ifdef SPR_ATR_USE_DPB
            fetch_pat_num <= spr_atr_r_data[15:8];
            fetch_pat_xpos <= spr_atr_r_data[25:16];
            fetch_pat_line <= spr_atr_r_data[4:0];
`else
            fetch_pat_num <= atr_buff[0][15:8];
            fetch_pat_xpos <= atr_buff[0][25:16];
            fetch_pat_line <= VCNT[4:0] - atr_buff[0][4:0];
            fetch_index_next <= 1'd1;
`endif

            fetch_index <= 0;
            fetch_remain <= MAX_SPR_VIEW_COUNT - 1'd1;
            state <= STATE_SPR_PAT_L;
        end

        // カーソルパターン取得準備
        else if(state == STATE_CUR_PAT_START) begin
            // 最初のパターン
`ifdef SPR_ATR_USE_DPB
            fetch_pat_xpos <= spr_atr_r_data[25:16];
            fetch_pat_line <= VCNT[4:0] - spr_atr_r_data[4:0];
`else
            fetch_pat_xpos <= atr_buff[0][25:16];
            fetch_pat_line <= VCNT[4:0] - atr_buff[0][4:0];
            fetch_index_next <= 1'd1;
`endif

            fetch_index <= 0;
            fetch_remain <= MAX_CUR_PLANE_COUNT - 1'd1;
            state <= STATE_CUR_PAT;
        end

        // アトリビュートを取り込む
        else if(fetch_attr) begin
            fetch_attr <= 0;
`ifndef SPR_ATR_USE_DPB
            atr_buff[fetch_visible_count] <= MEM.DOUT;
`endif
            fetch_visible_count <= fetch_visible_count + 1'd1;
        end

        // メモリリード完了
        else if(MEM.ACK) begin
            case (state)
                /***************************************************************
                * スプライト
                 ***************************************************************/
                // アトリビュート
                STATE_SPR_ATR: begin
                    // Y 座標が範囲内?
                    fetch_attr <= (fetch_visible_count != MAX_SPR_VIEW_COUNT) && spr_y_flag;

                    // 次に取得するアトリビュート
                    fetch_index <= fetch_index + 1'd1;

                    // 125枚をカウント
                    fetch_remain <= fetch_remain - 1'd1;
                    if(fetch_remain == 0) state <= STATE_SPR_PAT_START;
                end

                // パターン(左半分)
                STATE_SPR_PAT_L: begin
                    // パターンをバッファへ格納
`ifndef SPR_PAT_USE_DPB
                    pat_buff[fetch_index][63:32] <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24]};
`endif
                    state <= STATE_SPR_PAT_R;
                end

                // パターン(右半分)
                STATE_SPR_PAT_R: begin
                    // パターンをバッファへ格納
`ifndef SPR_PAT_USE_DPB
                    pat_buff[fetch_index][31:0] <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24]};
`endif
                    fetch_index <= fetch_index + 1'd1;

                    // 次のパターン番号を取得
`ifdef SPR_ATR_USE_DPB
                    fetch_pat_num <= spr_atr_r_data[15:8];
                    fetch_pat_xpos <= spr_atr_r_data[25:16];
                    fetch_pat_line <= VCNT[4:0] - spr_atr_r_data[4:0];
`else
                    fetch_pat_num <= atr_buff[fetch_index_next][15:8];
                    fetch_pat_xpos <= atr_buff[fetch_index_next][25:16];
                    fetch_pat_line <= VCNT[4:0] - atr_buff[fetch_index_next][4:0];
                    fetch_index_next <= fetch_index_next + 1'd1;
`endif

                    // 16枚をカウント
                    fetch_remain <= fetch_remain - 1'd1;
                    if(fetch_remain == 0) state <= STATE_OUT_INIT;
                    else                  state <= STATE_SPR_PAT_L;
                end

                /***************************************************************
                * カーソル
                 ***************************************************************/
                // アトリビュート(下位)
                STATE_CUR_ATR_L: begin
`ifndef SPR_ATR_USE_DPB
                    atr_buff[fetch_index][15:0] <= {MEM.DOUT[7:0], MEM.DOUT[23:16]};
`endif
                    fetch_visible_count <= fetch_visible_count + 1'd1;
                    state <= STATE_CUR_ATR_H;
                end

                // アトリビュート(上位)
                STATE_CUR_ATR_H: begin
`ifndef SPR_ATR_USE_DPB
                    atr_buff[fetch_index][31:16] <= cur_y_flag ? {MEM.DOUT[7:0], MEM.DOUT[23:16]} : 16'b0001_0000_0000_0000;
`endif
                    fetch_index <= fetch_index + 1'd1;

                    // 2枚をカウント
                    fetch_remain <= fetch_remain - 1'd1;
                    if(fetch_remain == 0) state <= STATE_SPR_PAT_START;
                    else                  state <= STATE_CUR_ATR_L;
                end

                // パターン
                STATE_CUR_PAT: begin
                    // パターンをバッファへ格納
`ifndef SPR_PAT_USE_DPB
                    pat_buff[fetch_index] <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24], 32'h00000000 };
`endif
                    fetch_index <= fetch_index + 1'd1;

                    // 次のパターン Y オフセットを取得
`ifdef SPR_ATR_USE_DPB
                    fetch_pat_xpos <= spr_atr_r_data[25:16];
                    fetch_pat_line <= VCNT[4:0] - spr_atr_r_data[4:0];
`else
                    fetch_pat_xpos <= atr_buff[fetch_index_next][25:16];
                    fetch_pat_line <= VCNT[4:0] - atr_buff[fetch_index_next][4:0];
                    fetch_index_next <= fetch_index_next + 1'd1;
`endif

                    // 2枚をカウント
                    fetch_remain <= fetch_remain - 1'd1;
                    if(fetch_remain == 0) state <= STATE_OUT_INIT;
                end
            endcase
        end
    end

    /***************************************************************
     * リードデータを出力側バッファへ転送
     ***************************************************************/
    logic [63:0] view_pat[0:MAX_SPR_VIEW_COUNT-1];
    logic [9:0] view_x[0:MAX_SPR_VIEW_COUNT-1];
    logic [1:0] view_pri[0:MAX_SPR_VIEW_COUNT-1];
    logic [1:0] view_sc[0:MAX_SPR_VIEW_COUNT-1];

    // 1クロックで 1個ずつ attr->view へコピーするためのカウンタ
    logic [4:0] copy_count;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            copy_count <= MAX_SPR_VIEW_COUNT;
        end
        else if(state == STATE_OUT_INIT) begin
            copy_count <= 0;
        end
        else if(!copy_count[4]) begin
            copy_count <= copy_count + 1'd1;
        end
    end

    generate
        genvar v_num;
        for(v_num = 0; v_num < MAX_SPR_VIEW_COUNT; v_num = v_num + 1) begin: view
`ifdef SPR_PAT_USE_DPB
            wire [63:0] curr_copy_pat = spr_pat_r_data;
`else
            wire [63:0] curr_copy_pat = pat_buff[v_num];
`endif
`ifdef SPR_ATR_USE_DPB
            wire [31:0] curr_copy_atr = spr_atr_r_data;
`else
            wire [31:0] curr_copy_atr = atr_buff[v_num];
`endif

            // 表示範囲内に入ったら X 座標値をシフト
            always_ff @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    view_pat[v_num] <= 0;
                    view_x[v_num] <= 0;
                    view_pri[v_num] <= 0;
                    view_sc[v_num] <= 0;
                end
                else if(DISABLE) begin
                end

                // 表示データの初期設定
                else if({1'b0, v_num} == copy_count) begin
                    if(v_num >= fetch_visible_count) begin
                        view_pat[v_num] <= 0;
                        view_x[v_num] <= 0;
                        view_pri[v_num] <= 2'b01;
                        view_sc[v_num] <= 0;
                    end
                    else begin
                        // パターンをコピー
                        view_pat[v_num] <= curr_copy_pat;

                        // アトリビュートをコピー
                        view_x[v_num] <= {curr_copy_atr[25:24], curr_copy_atr[23:16]} + (IS_CUR ? 6'd32 : 5'd16);
                        view_pri[v_num] <= curr_copy_atr[29:28];
                        view_sc[v_num] <= curr_copy_atr[31:30];
                    end
                end

                // X 座標をデクリメントして 0~15 になったら出力
                else if(DCLK_EN && spr_out_flag) begin
                    view_x[v_num] <= view_x[v_num] - 1'd1;
                    if(spr_area[v_num]) view_pat[v_num] <= {view_pat[v_num][64-4-1:0], 4'b0000};
                end

                // X 座標をデクリメントして 0~31 になったら出力
                else if(DCLK_EN && cur_out_flag && v_num < MAX_CUR_PLANE_COUNT) begin
                    view_x[v_num] <= view_x[v_num] - 1'd1;
                    if(cur_area[v_num]) view_pat[v_num] <= {view_pat[v_num][64-1-1:0], 1'b0};
                end
            end
        end
    endgenerate

    /***************************************************************
     * スプライト生成
     ***************************************************************/
    wire        spr_area[0:MAX_SPR_VIEW_COUNT-1];
    wire [3:0]  spr_clr[0:MAX_SPR_VIEW_COUNT-1];
    wire        spr_flg[0:MAX_SPR_VIEW_COUNT-1];
    //wire [5:0]  spr_pa[0:MAX_SPR_VIEW_COUNT-1];
    //wire [1:0]  spr_pri[0:MAX_SPR_VIEW_COUNT-1];
    reg [5:0]  spr_pa[0:MAX_SPR_VIEW_COUNT-1];
    reg [1:0]  spr_pri[0:MAX_SPR_VIEW_COUNT-1];

    generate
        genvar s_num;
        for(s_num = 0; s_num < MAX_SPR_VIEW_COUNT; s_num = s_num + 1) begin: spr_plane
            // 色
            assign spr_clr[s_num] = view_pat[s_num][64-1:64-4];

            // 範囲フラグ
            assign spr_area[s_num] = view_x[s_num][9:4] == 0;

            // 表示フラグ
            assign spr_flg[s_num] = spr_area[s_num] && (spr_clr[s_num] != 0) && !view_pri[s_num][0];

            // パレットアドレス
            //assign spr_pa[s_num] = {view_sc[s_num], spr_clr[s_num]};

            // PRIORITY
            //assign spr_pri[s_num] = view_pri[s_num];

            always_ff @(posedge CLK) begin
                if(!DCLK_EN) begin
                    spr_pa[s_num] <= {view_sc[s_num], spr_clr[s_num]};
                    spr_pri[s_num] <= view_pri[s_num];
                end
            end

        end
    endgenerate

    /***************************************************************
     * カーソル生成
     ***************************************************************/
    wire        cur_area[0:MAX_CUR_PLANE_COUNT-1];
    wire        cur_flg[0:MAX_CUR_PLANE_COUNT-1];
    wire [5:0]  cur_pa[0:MAX_CUR_PLANE_COUNT-1];
    wire [0:0]  cur_pri[0:MAX_CUR_PLANE_COUNT-1];
    wire        cur_eor[0:MAX_CUR_PLANE_COUNT-1];
    wire        cur_pset[0:MAX_CUR_PLANE_COUNT-1];

    generate
        genvar c_num;
        for(c_num = 0; c_num < MAX_CUR_PLANE_COUNT; c_num = c_num + 1) begin: cur_plane
            // EOR フラグ
            assign cur_eor[c_num] = (view_sc[c_num] == 0) && view_pri[c_num][1] && view_pat[c_num][63];

            // パターン描画フラグ
            assign cur_pset[c_num] = view_pat[c_num][63] && ({view_sc[c_num], view_pri[c_num][1]} != 3'b000);

            // 表示フラグ
            assign cur_area[c_num] = view_x[c_num][9:5] == 0;
             
            // 表示フラグ
            assign cur_flg[c_num] = cur_area[c_num] && (cur_pset[c_num] || cur_eor[c_num]);

            // 色
            assign cur_pa[c_num] = {REG.CSP, view_sc[c_num]};

            // PRIORITY
            assign cur_pri[c_num] = view_pri[c_num][0];
        end
    endgenerate

    /***************************************************************
     * 出力開始タイミング
     ***************************************************************/
    logic spr_out_flag;
    logic cur_out_flag;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            spr_out_flag <= 0;
            cur_out_flag <= 0;
        end
        else if(DISABLE) begin
        end
        else if(state == STATE_OUT_INIT) begin
            spr_out_flag <= 0;
            cur_out_flag <= 0;
        end
        else if(OUT_START) begin
            spr_out_flag <= !IS_CUR;
            cur_out_flag <= IS_CUR;
        end
    end

    /***************************************************************
     * データ出力
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            PA <= 0;
            PRI <= 2'b01;
            EOR <= 0;
        end

        // 動作禁止
        else if(DISABLE) begin
        end

        // 表示範囲内のスプライトがあれば出力
        else if(DCLK_EN && spr_out_flag) begin
`ifdef TEST
            integer i;
            for(i = 0; i < MAX_SPR_VIEW_COUNT; i = i + 1) begin: spr_prio
                if(spr_flg[i]) begin
                    PA <= spr_pa[i];
                    PRI <= spr_pri[i];
                    disable spr_prio;
                end
            end
`else
            // PALETTE ADDRESS を出力
            if(spr_flg[ 0])      PA <= spr_pa[ 0];      //  1番目のスプライトを表示
            else if(spr_flg[ 1]) PA <= spr_pa[ 1];      //  2番目のスプライトを表示
            else if(spr_flg[ 2]) PA <= spr_pa[ 2];      //  3番目のスプライトを表示
            else if(spr_flg[ 3]) PA <= spr_pa[ 3];      //  4番目のスプライトを表示
            else if(spr_flg[ 4]) PA <= spr_pa[ 4];      //  5番目のスプライトを表示
            else if(spr_flg[ 5]) PA <= spr_pa[ 5];      //  6番目のスプライトを表示
            else if(spr_flg[ 6]) PA <= spr_pa[ 6];      //  7番目のスプライトを表示
            else if(spr_flg[ 7]) PA <= spr_pa[ 7];      //  8番目のスプライトを表示
            else if(spr_flg[ 8]) PA <= spr_pa[ 8];      //  9番目のスプライトを表示
            else if(spr_flg[ 9]) PA <= spr_pa[ 9];      // 10番目のスプライトを表示
            else if(spr_flg[10]) PA <= spr_pa[10];      // 11番目のスプライトを表示
            else if(spr_flg[11]) PA <= spr_pa[11];      // 12番目のスプライトを表示
            else if(spr_flg[12]) PA <= spr_pa[12];      // 13番目のスプライトを表示
            else if(spr_flg[13]) PA <= spr_pa[13];      // 14番目のスプライトを表示
            else if(spr_flg[14]) PA <= spr_pa[14];      // 15番目のスプライトを表示
            else if(spr_flg[15]) PA <= spr_pa[15];      // 16番目のスプライトを表示
            else                 PA <= 0;               // 表示するスプライトが無い

            // PRIORITY を出力
            if(spr_flg[ 0])      PRI <= spr_pri[ 0];    //  1番目のスプライトを表示
            else if(spr_flg[ 1]) PRI <= spr_pri[ 1];    //  2番目のスプライトを表示
            else if(spr_flg[ 2]) PRI <= spr_pri[ 2];    //  3番目のスプライトを表示
            else if(spr_flg[ 3]) PRI <= spr_pri[ 3];    //  4番目のスプライトを表示
            else if(spr_flg[ 4]) PRI <= spr_pri[ 4];    //  5番目のスプライトを表示
            else if(spr_flg[ 5]) PRI <= spr_pri[ 5];    //  6番目のスプライトを表示
            else if(spr_flg[ 6]) PRI <= spr_pri[ 6];    //  7番目のスプライトを表示
            else if(spr_flg[ 7]) PRI <= spr_pri[ 7];    //  8番目のスプライトを表示
            else if(spr_flg[ 8]) PRI <= spr_pri[ 8];    //  9番目のスプライトを表示
            else if(spr_flg[ 9]) PRI <= spr_pri[ 9];    // 10番目のスプライトを表示
            else if(spr_flg[10]) PRI <= spr_pri[10];    // 11番目のスプライトを表示
            else if(spr_flg[11]) PRI <= spr_pri[11];    // 12番目のスプライトを表示
            else if(spr_flg[12]) PRI <= spr_pri[12];    // 13番目のスプライトを表示
            else if(spr_flg[13]) PRI <= spr_pri[13];    // 14番目のスプライトを表示
            else if(spr_flg[14]) PRI <= spr_pri[14];    // 15番目のスプライトを表示
            else if(spr_flg[15]) PRI <= spr_pri[15];    // 16番目のスプライトを表示
            else                 PRI <= 2'b01;          // 表示するスプライトが無い
`endif

            EOR <= 0;
        end

        // 表示範囲内のカーソルがあれば出力
        else if(DCLK_EN && cur_out_flag) begin
`ifdef TEST
            integer i;
            for(i = 0; i < MAX_CUR_PLANE_COUNT; i = i + 1) begin: cur_prio
                if(cur_flg[i]) begin
                    PA <= cur_pa[i];
                    PRI <= cur_pri[i];
                    EOR <= cur_eor[i];
                    disable cur_prio;
                end
            end
`else
            // PALETTE ADDRESS を出力
            if(cur_flg[ 0])      PA <= cur_pa[ 0];      //  1番目のカーソルを表示
            else if(cur_flg[ 1]) PA <= spr_pa[ 1];      //  2番目のカーソルを表示
            else                 PA <= 0;               // 表示するカーソルが無い

            // EOR を出力
            if(cur_flg[ 0])      EOR <= cur_eor[ 0];    //  1番目のカーソルを表示
            else if(cur_flg[ 1]) EOR <= cur_eor[ 1];    //  2番目のカーソルを表示
            else                 EOR <= 2'b01;          // 表示するカーソルが無い

            // PRIORITY を出力
            if(cur_flg[ 0])      PRI <= {1'b0, cur_pri[ 0]};    //  1番目のカーソルを表示
            else if(cur_flg[ 1]) PRI <= {1'b0, cur_pri[ 1]};    //  2番目のカーソルを表示
            else                 PRI <= 2'b01;                  // 表示するカーソルが無い
`endif
        end
    end

endmodule

module T9990_SPRITE_ATTRIBUTE (
    input wire          RESET_n,
    input wire          CLK,

    input wire [3:0]    W_ADDR,
    input wire [31:0]   W_DATA,
    input wire          W_EN,

    input wire [3:0]    R_ADDR,
    output wire [31:0]  R_DATA
);
    wire [15:0] dummy_0;
    wire [15:0] dummy_1;

    DPB dpb_inst_0 (
        .DOA(R_DATA[15:0]),
        .DOB(dummy_0),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[15:0])
    );

    defparam dpb_inst_0.READ_MODE0 = 1'b0;
    defparam dpb_inst_0.READ_MODE1 = 1'b0;
    defparam dpb_inst_0.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_0.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_0.BIT_WIDTH_0 = 16;
    defparam dpb_inst_0.BIT_WIDTH_1 = 16;
    defparam dpb_inst_0.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_0.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_0.RESET_MODE = "SYNC";

    DPB dpb_inst_1 (
        .DOA(R_DATA[31:16]),
        .DOB(dummy_1),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[31:16])
    );

    defparam dpb_inst_1.READ_MODE0 = 1'b0;
    defparam dpb_inst_1.READ_MODE1 = 1'b0;
    defparam dpb_inst_1.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_1.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_1.BIT_WIDTH_0 = 16;
    defparam dpb_inst_1.BIT_WIDTH_1 = 16;
    defparam dpb_inst_1.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_1.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_1.RESET_MODE = "SYNC";

endmodule

module T9990_SPRITE_PATTERN (
    input wire          RESET_n,
    input wire          CLK,

    input wire [3:0]    W_ADDR,
    input wire [63:0]   W_DATA,
    input wire          W_EN,

    input wire [3:0]    R_ADDR,
    output wire [63:0]  R_DATA
);
    wire [15:0] dummy_0;
    wire [15:0] dummy_1;
    wire [15:0] dummy_2;
    wire [15:0] dummy_3;

    DPB dpb_inst_0 (
        .DOA(R_DATA[15:0]),
        .DOB(dummy_0),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[15:0])
    );

    defparam dpb_inst_0.READ_MODE0 = 1'b0;
    defparam dpb_inst_0.READ_MODE1 = 1'b0;
    defparam dpb_inst_0.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_0.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_0.BIT_WIDTH_0 = 16;
    defparam dpb_inst_0.BIT_WIDTH_1 = 16;
    defparam dpb_inst_0.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_0.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_0.RESET_MODE = "SYNC";

    DPB dpb_inst_1 (
        .DOA(R_DATA[31:16]),
        .DOB(dummy_1),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[31:16])
    );

    defparam dpb_inst_1.READ_MODE0 = 1'b0;
    defparam dpb_inst_1.READ_MODE1 = 1'b0;
    defparam dpb_inst_1.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_1.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_1.BIT_WIDTH_0 = 16;
    defparam dpb_inst_1.BIT_WIDTH_1 = 16;
    defparam dpb_inst_1.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_1.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_1.RESET_MODE = "SYNC";

    DPB dpb_inst_2 (
        .DOA(R_DATA[47:32]),
        .DOB(dummy_2),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[47:32])
    );

    defparam dpb_inst_2.READ_MODE0 = 1'b0;
    defparam dpb_inst_2.READ_MODE1 = 1'b0;
    defparam dpb_inst_2.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_2.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_2.BIT_WIDTH_0 = 16;
    defparam dpb_inst_2.BIT_WIDTH_1 = 16;
    defparam dpb_inst_2.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_2.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_2.RESET_MODE = "SYNC";

    DPB dpb_inst_3 (
        .DOA(R_DATA[63:48]),
        .DOB(dummy_3),
        .CLKA(CLK),
        .OCEA(1'b1),
        .CEA(1'b1),
        .RESETA(!RESET_n),
        .WREA(1'b0),
        .CLKB(CLK),
        .OCEB(1'b1),
        .CEB(1'b1),
        .RESETB(!RESET_n),
        .WREB(W_EN),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({6'b000000,R_ADDR[3:0],4'b0011}),
        .DIA(16'd0),
        .ADB({6'b000000,W_ADDR[3:0],4'b0011}),
        .DIB(W_DATA[63:48])
    );

    defparam dpb_inst_3.READ_MODE0 = 1'b0;
    defparam dpb_inst_3.READ_MODE1 = 1'b0;
    defparam dpb_inst_3.WRITE_MODE0 = 2'b00;
    defparam dpb_inst_3.WRITE_MODE1 = 2'b00;
    defparam dpb_inst_3.BIT_WIDTH_0 = 16;
    defparam dpb_inst_3.BIT_WIDTH_1 = 16;
    defparam dpb_inst_3.BLK_SEL_0 = 3'b000;
    defparam dpb_inst_3.BLK_SEL_1 = 3'b000;
    defparam dpb_inst_3.RESET_MODE = "SYNC";

endmodule

`default_nettype wire
