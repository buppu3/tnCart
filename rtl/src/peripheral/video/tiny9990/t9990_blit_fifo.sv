//
// t9990_blit_fifo.sv
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

module T9990_BLIT_FIFO (
    input wire          RESET_n,
    input wire          CLK,
    input wire          CLK_EN,

    input wire [1:0]    CLRM,           // カラーモード
    output reg [5:0]    FREE_COUNT,     // FIFO 空き数
    output reg [5:0]    AVAIL_COUNT,    // FIFO 格納数

    input wire          CLEAR,          // FIFO クリアフラグ

    input wire          ENQUEUE,        // FIFO 格納フラグ
    input wire [4:0]    ENQUEUE_COUNT,  // FIFO 格納ドット数
    input wire [31:0]   ENQUEUE_DATA,   // 2BPP/4BPP/8BPP/16BPP データ入力

    input wire          DEQUEUE,        // FIFO 取り出しフラグ
    input wire [4:0]    DEQUEUE_COUNT,  // FIFO 取り出しドット数
    output reg [31:0]   DEQUEUE_DATA2,  // 2BPP データ出力
    output reg [31:0]   DEQUEUE_DATA4,  // 4BPP データ出力
    output reg [31:0]   DEQUEUE_DATA8,  // 8BPP データ出力
    output reg [31:0]   DEQUEUE_DATA16  // 16BPP データ出力
);
    reg enq[0:15];
    reg w_inc;
    always_ff @(posedge CLK) begin
        if(CLK_EN && ENQUEUE) begin
            enq[ 0] <= (ENQUEUE_COUNT >  0);
            enq[ 1] <= (ENQUEUE_COUNT >  1);
            enq[ 2] <= (ENQUEUE_COUNT >  2);
            enq[ 3] <= (ENQUEUE_COUNT >  3);
            enq[ 4] <= (ENQUEUE_COUNT >  4);
            enq[ 5] <= (ENQUEUE_COUNT >  5);
            enq[ 6] <= (ENQUEUE_COUNT >  6);
            enq[ 7] <= (ENQUEUE_COUNT >  7);
            enq[ 8] <= (ENQUEUE_COUNT >  8);
            enq[ 9] <= (ENQUEUE_COUNT >  9);
            enq[10] <= (ENQUEUE_COUNT > 10);
            enq[11] <= (ENQUEUE_COUNT > 11);
            enq[12] <= (ENQUEUE_COUNT > 12);
            enq[13] <= (ENQUEUE_COUNT > 13);
            enq[14] <= (ENQUEUE_COUNT > 14);
            enq[15] <= (ENQUEUE_COUNT > 15);
            w_inc <= 1;
        end
        else begin
            enq[ 0] <= 0;
            enq[ 1] <= 0;
            enq[ 2] <= 0;
            enq[ 3] <= 0;
            enq[ 4] <= 0;
            enq[ 5] <= 0;
            enq[ 6] <= 0;
            enq[ 7] <= 0;
            enq[ 8] <= 0;
            enq[ 9] <= 0;
            enq[10] <= 0;
            enq[11] <= 0;
            enq[12] <= 0;
            enq[13] <= 0;
            enq[14] <= 0;
            enq[15] <= 0;
            w_inc <= 0;
        end
    end

    /***************************************************************
     * 2BPP
     ***************************************************************/
    wire [1:0] in_pixel_2[0:15];
    assign in_pixel_2[ 0] = ENQUEUE_DATA[31:30];
    assign in_pixel_2[ 1] = ENQUEUE_DATA[29:28];
    assign in_pixel_2[ 2] = ENQUEUE_DATA[27:26];
    assign in_pixel_2[ 3] = ENQUEUE_DATA[25:24];
    assign in_pixel_2[ 4] = ENQUEUE_DATA[23:22];
    assign in_pixel_2[ 5] = ENQUEUE_DATA[21:20];
    assign in_pixel_2[ 6] = ENQUEUE_DATA[19:18];
    assign in_pixel_2[ 7] = ENQUEUE_DATA[17:16];
    assign in_pixel_2[ 8] = ENQUEUE_DATA[15:14];
    assign in_pixel_2[ 9] = ENQUEUE_DATA[13:12];
    assign in_pixel_2[10] = ENQUEUE_DATA[11:10];
    assign in_pixel_2[11] = ENQUEUE_DATA[ 9: 8];
    assign in_pixel_2[12] = ENQUEUE_DATA[ 7: 6];
    assign in_pixel_2[13] = ENQUEUE_DATA[ 5: 4];
    assign in_pixel_2[14] = ENQUEUE_DATA[ 3: 2];
    assign in_pixel_2[15] = ENQUEUE_DATA[ 1: 0];

    reg [4:0] w_offset_2[0:15];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            w_offset_2[ 0] <= 5'd0;
            w_offset_2[ 1] <= 5'd1;
            w_offset_2[ 2] <= 5'd2;
            w_offset_2[ 3] <= 5'd3;
            w_offset_2[ 4] <= 5'd4;
            w_offset_2[ 5] <= 5'd5;
            w_offset_2[ 6] <= 5'd6;
            w_offset_2[ 7] <= 5'd7;
            w_offset_2[ 8] <= 5'd8;
            w_offset_2[ 9] <= 5'd9;
            w_offset_2[10] <= 5'd10;
            w_offset_2[11] <= 5'd11;
            w_offset_2[12] <= 5'd12;
            w_offset_2[13] <= 5'd13;
            w_offset_2[14] <= 5'd14;
            w_offset_2[15] <= 5'd15;
        end
        else if(w_inc) begin
            w_offset_2[ 0] <= (w_offset_2[ 0] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 1] <= (w_offset_2[ 1] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 2] <= (w_offset_2[ 2] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 3] <= (w_offset_2[ 3] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 4] <= (w_offset_2[ 4] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 5] <= (w_offset_2[ 5] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 6] <= (w_offset_2[ 6] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 7] <= (w_offset_2[ 7] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 8] <= (w_offset_2[ 8] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[ 9] <= (w_offset_2[ 9] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[10] <= (w_offset_2[10] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[11] <= (w_offset_2[11] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[12] <= (w_offset_2[12] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[13] <= (w_offset_2[13] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[14] <= (w_offset_2[14] + ENQUEUE_COUNT) & 5'd31;
            w_offset_2[15] <= (w_offset_2[15] + ENQUEUE_COUNT) & 5'd31;
        end
    end

    reg [1:0] buffer_2[0:31]/* synthesis syn_ramstyle="registers" */;
    always_ff @(posedge CLK) begin
        //if(CLK_EN) begin
            if(enq[ 0]) buffer_2[w_offset_2[ 0]] <= in_pixel_2[ 0];
            if(enq[ 1]) buffer_2[w_offset_2[ 1]] <= in_pixel_2[ 1];
            if(enq[ 2]) buffer_2[w_offset_2[ 2]] <= in_pixel_2[ 2];
            if(enq[ 3]) buffer_2[w_offset_2[ 3]] <= in_pixel_2[ 3];
            if(enq[ 4]) buffer_2[w_offset_2[ 4]] <= in_pixel_2[ 4];
            if(enq[ 5]) buffer_2[w_offset_2[ 5]] <= in_pixel_2[ 5];
            if(enq[ 6]) buffer_2[w_offset_2[ 6]] <= in_pixel_2[ 6];
            if(enq[ 7]) buffer_2[w_offset_2[ 7]] <= in_pixel_2[ 7];
            if(enq[ 8]) buffer_2[w_offset_2[ 8]] <= in_pixel_2[ 8];
            if(enq[ 9]) buffer_2[w_offset_2[ 9]] <= in_pixel_2[ 9];
            if(enq[10]) buffer_2[w_offset_2[10]] <= in_pixel_2[10];
            if(enq[11]) buffer_2[w_offset_2[11]] <= in_pixel_2[11];
            if(enq[12]) buffer_2[w_offset_2[12]] <= in_pixel_2[12];
            if(enq[13]) buffer_2[w_offset_2[13]] <= in_pixel_2[13];
            if(enq[14]) buffer_2[w_offset_2[14]] <= in_pixel_2[14];
            if(enq[15]) buffer_2[w_offset_2[15]] <= in_pixel_2[15];
        //end
    end

    /***************************************************************
     * 4BPP
     ***************************************************************/
    wire [3:0] in_pixel_4[0:7];
    assign in_pixel_4[ 0] = ENQUEUE_DATA[31:28];
    assign in_pixel_4[ 1] = ENQUEUE_DATA[27:24];
    assign in_pixel_4[ 2] = ENQUEUE_DATA[23:20];
    assign in_pixel_4[ 3] = ENQUEUE_DATA[19:16];
    assign in_pixel_4[ 4] = ENQUEUE_DATA[15:12];
    assign in_pixel_4[ 5] = ENQUEUE_DATA[11: 8];
    assign in_pixel_4[ 6] = ENQUEUE_DATA[ 7: 4];
    assign in_pixel_4[ 7] = ENQUEUE_DATA[ 3: 0];

    logic [3:0] w_offset_4[0:7];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            w_offset_4[0] <= 4'd0;
            w_offset_4[1] <= 4'd1;
            w_offset_4[2] <= 4'd2;
            w_offset_4[3] <= 4'd3;
            w_offset_4[4] <= 4'd4;
            w_offset_4[5] <= 4'd5;
            w_offset_4[6] <= 4'd6;
            w_offset_4[7] <= 4'd7;
        end
        else if(w_inc) begin
            w_offset_4[0] <= (w_offset_4[0] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[1] <= (w_offset_4[1] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[2] <= (w_offset_4[2] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[3] <= (w_offset_4[3] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[4] <= (w_offset_4[4] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[5] <= (w_offset_4[5] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[6] <= (w_offset_4[6] + ENQUEUE_COUNT) & 4'd15;
            w_offset_4[7] <= (w_offset_4[7] + ENQUEUE_COUNT) & 4'd15;
        end
    end

    reg [3:0] buffer_4[0:15]/* synthesis syn_ramstyle="registers" */;
    always_ff @(posedge CLK) begin
        //if(CLK_EN) begin
            if(enq[0]) buffer_4[w_offset_4[0]] <= in_pixel_4[0];
            if(enq[1]) buffer_4[w_offset_4[1]] <= in_pixel_4[1];
            if(enq[2]) buffer_4[w_offset_4[2]] <= in_pixel_4[2];
            if(enq[3]) buffer_4[w_offset_4[3]] <= in_pixel_4[3];
            if(enq[4]) buffer_4[w_offset_4[4]] <= in_pixel_4[4];
            if(enq[5]) buffer_4[w_offset_4[5]] <= in_pixel_4[5];
            if(enq[6]) buffer_4[w_offset_4[6]] <= in_pixel_4[6];
            if(enq[7]) buffer_4[w_offset_4[7]] <= in_pixel_4[7];
        //end
    end

    /***************************************************************
     * 8BPP
     ***************************************************************/
    wire [7:0] in_pixel_8[0:3];
    assign in_pixel_8[ 0] = ENQUEUE_DATA[31:24];
    assign in_pixel_8[ 1] = ENQUEUE_DATA[23:16];
    assign in_pixel_8[ 2] = ENQUEUE_DATA[15: 8];
    assign in_pixel_8[ 3] = ENQUEUE_DATA[ 7: 0];

    logic [2:0] w_offset_8[0:3];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            w_offset_8[0] <= 3'd0;
            w_offset_8[1] <= 3'd1;
            w_offset_8[2] <= 3'd2;
            w_offset_8[3] <= 3'd3;
        end
        else if(w_inc) begin
            w_offset_8[0] <= (w_offset_8[0] + ENQUEUE_COUNT) & 3'd7;
            w_offset_8[1] <= (w_offset_8[1] + ENQUEUE_COUNT) & 3'd7;
            w_offset_8[2] <= (w_offset_8[2] + ENQUEUE_COUNT) & 3'd7;
            w_offset_8[3] <= (w_offset_8[3] + ENQUEUE_COUNT) & 3'd7;
        end
    end

    reg [7:0] buffer_8[0:7]/* synthesis syn_ramstyle="registers" */;
    always_ff @(posedge CLK) begin
        //if(CLK_EN) begin
            if(enq[0]) buffer_8[w_offset_8[0]] <= in_pixel_8[0];
            if(enq[1]) buffer_8[w_offset_8[1]] <= in_pixel_8[1];
            if(enq[2]) buffer_8[w_offset_8[2]] <= in_pixel_8[2];
            if(enq[3]) buffer_8[w_offset_8[3]] <= in_pixel_8[3];
        //end
    end

    /***************************************************************
     * 16BPP
     ***************************************************************/
    wire [15:0] in_pixel_16[0:1];
    assign in_pixel_16[ 0] = ENQUEUE_DATA[31:16];
    assign in_pixel_16[ 1] = ENQUEUE_DATA[15: 0];

    logic [1:0] w_offset_16[0:1];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            w_offset_16[0] <= 2'd0;
            w_offset_16[1] <= 2'd1;
        end
        else if(w_inc) begin
            w_offset_16[0] <= (w_offset_16[0] + ENQUEUE_COUNT) & 2'd3;
            w_offset_16[1] <= (w_offset_16[1] + ENQUEUE_COUNT) & 2'd3;
        end
    end

    reg [15:0] buffer_16[0:3]/* synthesis syn_ramstyle="registers" */;
    always_ff @(posedge CLK) begin
        //if(CLK_EN) begin
            if(enq[0]) buffer_16[w_offset_16[0]] <= in_pixel_16[0];
            if(enq[1]) buffer_16[w_offset_16[1]] <= in_pixel_16[1];
        //end
    end

    /***************************************************************
     * DEQUEUE
     ***************************************************************/
    reg [4:0] out_offset_2[0:15];
    reg [3:0] out_offset_4[0:7];
    reg [2:0] out_offset_8[0:3];
    reg [1:0] out_offset_16[0:1];

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            out_offset_2[0] <= 5'd0;
            out_offset_2[1] <= 5'd1;
            out_offset_2[2] <= 5'd2;
            out_offset_2[3] <= 5'd3;
            out_offset_2[4] <= 5'd4;
            out_offset_2[5] <= 5'd5;
            out_offset_2[6] <= 5'd6;
            out_offset_2[7] <= 5'd7;
            out_offset_2[8] <= 5'd8;
            out_offset_2[9] <= 5'd9;
            out_offset_2[10] <= 5'd10;
            out_offset_2[11] <= 5'd11;
            out_offset_2[12] <= 5'd12;
            out_offset_2[13] <= 5'd13;
            out_offset_2[14] <= 5'd14;
            out_offset_2[15] <= 5'd15;

            out_offset_4[0] <= 4'd0;
            out_offset_4[1] <= 4'd1;
            out_offset_4[2] <= 4'd2;
            out_offset_4[3] <= 4'd3;
            out_offset_4[4] <= 4'd4;
            out_offset_4[5] <= 4'd5;
            out_offset_4[6] <= 4'd6;
            out_offset_4[7] <= 4'd7;

            out_offset_8[0] <= 3'd0;
            out_offset_8[1] <= 3'd1;
            out_offset_8[2] <= 3'd2;
            out_offset_8[3] <= 3'd3;

            out_offset_16[0] <= 2'd0;
            out_offset_16[1] <= 2'd1;
        end
        else if(DEQUEUE && CLK_EN) begin
            DEQUEUE_DATA2[31:30] <= buffer_2[out_offset_2[ 0]];
            DEQUEUE_DATA2[29:28] <= buffer_2[out_offset_2[ 1]];
            DEQUEUE_DATA2[27:26] <= buffer_2[out_offset_2[ 2]];
            DEQUEUE_DATA2[25:24] <= buffer_2[out_offset_2[ 3]];
            DEQUEUE_DATA2[23:22] <= buffer_2[out_offset_2[ 4]];
            DEQUEUE_DATA2[21:20] <= buffer_2[out_offset_2[ 5]];
            DEQUEUE_DATA2[19:18] <= buffer_2[out_offset_2[ 6]];
            DEQUEUE_DATA2[17:16] <= buffer_2[out_offset_2[ 7]];
            DEQUEUE_DATA2[15:14] <= buffer_2[out_offset_2[ 8]];
            DEQUEUE_DATA2[13:12] <= buffer_2[out_offset_2[ 9]];
            DEQUEUE_DATA2[11:10] <= buffer_2[out_offset_2[10]];
            DEQUEUE_DATA2[ 9: 8] <= buffer_2[out_offset_2[11]];
            DEQUEUE_DATA2[ 7: 6] <= buffer_2[out_offset_2[12]];
            DEQUEUE_DATA2[ 5: 4] <= buffer_2[out_offset_2[13]];
            DEQUEUE_DATA2[ 3: 2] <= buffer_2[out_offset_2[14]];
            DEQUEUE_DATA2[ 1: 0] <= buffer_2[out_offset_2[15]];
            out_offset_2[ 0] <= (out_offset_2[ 0] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 1] <= (out_offset_2[ 1] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 2] <= (out_offset_2[ 2] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 3] <= (out_offset_2[ 3] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 4] <= (out_offset_2[ 4] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 5] <= (out_offset_2[ 5] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 6] <= (out_offset_2[ 6] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 7] <= (out_offset_2[ 7] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 8] <= (out_offset_2[ 8] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[ 9] <= (out_offset_2[ 9] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[10] <= (out_offset_2[10] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[11] <= (out_offset_2[11] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[12] <= (out_offset_2[12] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[13] <= (out_offset_2[13] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[14] <= (out_offset_2[14] + DEQUEUE_COUNT) & 5'd31;
            out_offset_2[15] <= (out_offset_2[15] + DEQUEUE_COUNT) & 5'd31;

            DEQUEUE_DATA4[31:28] <= buffer_4[out_offset_4[ 0]];
            DEQUEUE_DATA4[27:24] <= buffer_4[out_offset_4[ 1]];
            DEQUEUE_DATA4[23:20] <= buffer_4[out_offset_4[ 2]];
            DEQUEUE_DATA4[19:16] <= buffer_4[out_offset_4[ 3]];
            DEQUEUE_DATA4[15:12] <= buffer_4[out_offset_4[ 4]];
            DEQUEUE_DATA4[11: 8] <= buffer_4[out_offset_4[ 5]];
            DEQUEUE_DATA4[ 7: 4] <= buffer_4[out_offset_4[ 6]];
            DEQUEUE_DATA4[ 3: 0] <= buffer_4[out_offset_4[ 7]];
            out_offset_4[0] <= (out_offset_4[0] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[1] <= (out_offset_4[1] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[2] <= (out_offset_4[2] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[3] <= (out_offset_4[3] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[4] <= (out_offset_4[4] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[5] <= (out_offset_4[5] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[6] <= (out_offset_4[6] + DEQUEUE_COUNT) & 4'd15;
            out_offset_4[7] <= (out_offset_4[7] + DEQUEUE_COUNT) & 4'd15;

            DEQUEUE_DATA8[31:24] <= buffer_8[out_offset_8[ 0]];
            DEQUEUE_DATA8[23:16] <= buffer_8[out_offset_8[ 1]];
            DEQUEUE_DATA8[15: 8] <= buffer_8[out_offset_8[ 2]];
            DEQUEUE_DATA8[ 7: 0] <= buffer_8[out_offset_8[ 3]];
            out_offset_8[0] <= (out_offset_8[0] + DEQUEUE_COUNT) & 3'd7;
            out_offset_8[1] <= (out_offset_8[1] + DEQUEUE_COUNT) & 3'd7;
            out_offset_8[2] <= (out_offset_8[2] + DEQUEUE_COUNT) & 3'd7;
            out_offset_8[3] <= (out_offset_8[3] + DEQUEUE_COUNT) & 3'd7;

            DEQUEUE_DATA16[31:16] <= buffer_16[out_offset_16[ 0]];
            DEQUEUE_DATA16[15: 0] <= buffer_16[out_offset_16[ 1]];
            out_offset_16[0] <= (out_offset_16[0] + DEQUEUE_COUNT) & 2'd3;
            out_offset_16[1] <= (out_offset_16[1] + DEQUEUE_COUNT) & 2'd3;
        end
    end

    /***************************************************************
     * counter
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            AVAIL_COUNT <= 0;
        end
        else if(CLK_EN && ENQUEUE && DEQUEUE) begin
            AVAIL_COUNT <= AVAIL_COUNT + ENQUEUE_COUNT - DEQUEUE_COUNT;
        end
        else if(CLK_EN && ENQUEUE) begin
            AVAIL_COUNT <= AVAIL_COUNT + ENQUEUE_COUNT;
        end
        else if(CLK_EN && DEQUEUE) begin
            AVAIL_COUNT <= AVAIL_COUNT - DEQUEUE_COUNT;
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            FREE_COUNT <= 0;
        end
        else begin
            case (CLRM)
                T9990_REG::CLRM_2BPP:  FREE_COUNT <= 6'd32 - AVAIL_COUNT;
                T9990_REG::CLRM_4BPP:  FREE_COUNT <= 6'd16 - AVAIL_COUNT;
                T9990_REG::CLRM_8BPP:  FREE_COUNT <= 6'd 8 - AVAIL_COUNT;
                T9990_REG::CLRM_16BPP: FREE_COUNT <= 6'd 4 - AVAIL_COUNT;
            endcase
        end
    end
endmodule

`default_nettype wire
