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
`ifdef TEST
    input wire [3:0]    ENQUEUE_SHIFT,  // FIFO 格納ビットシフト数
`endif
    input wire [31:0]   ENQUEUE_DATA,   // 2BPP/4BPP/8BPP/16BPP データ入力

    input wire          DEQUEUE,        // FIFO 取り出しフラグ
    input wire [4:0]    DEQUEUE_COUNT,  // FIFO 取り出しドット数
    input wire [3:0]    DEQUEUE_SHIFT,  // FIFO 格納ビットシフト数
    output reg [31:0]   DEQUEUE_DATA    // 2BPP データ出力
);
    /***************************************************************
     * ENQUEUE
     ***************************************************************/
    reg enq[0:15];
    reg w_inc;
    reg [4:0] w_inc_val;
    always_ff @(posedge CLK) begin
        if(CLK_EN && ENQUEUE && CLRM == T9990_REG::CLRM_2BPP) begin
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
            w_inc_val <= ENQUEUE_COUNT;
        end
        else if(CLK_EN && ENQUEUE && CLRM == T9990_REG::CLRM_4BPP) begin
            enq[ 0] <= (ENQUEUE_COUNT > 0);
            enq[ 1] <= (ENQUEUE_COUNT > 0);
            enq[ 2] <= (ENQUEUE_COUNT > 1);
            enq[ 3] <= (ENQUEUE_COUNT > 1);
            enq[ 4] <= (ENQUEUE_COUNT > 2);
            enq[ 5] <= (ENQUEUE_COUNT > 2);
            enq[ 6] <= (ENQUEUE_COUNT > 3);
            enq[ 7] <= (ENQUEUE_COUNT > 3);
            enq[ 8] <= (ENQUEUE_COUNT > 4);
            enq[ 9] <= (ENQUEUE_COUNT > 4);
            enq[10] <= (ENQUEUE_COUNT > 5);
            enq[11] <= (ENQUEUE_COUNT > 5);
            enq[12] <= (ENQUEUE_COUNT > 6);
            enq[13] <= (ENQUEUE_COUNT > 6);
            enq[14] <= (ENQUEUE_COUNT > 7);
            enq[15] <= (ENQUEUE_COUNT > 7);
            w_inc <= 1;
            w_inc_val <= {ENQUEUE_COUNT[3:0], 1'b0};
        end
        else if(CLK_EN && ENQUEUE && CLRM == T9990_REG::CLRM_8BPP) begin
            enq[ 0] <= (ENQUEUE_COUNT > 0);
            enq[ 1] <= (ENQUEUE_COUNT > 0);
            enq[ 2] <= (ENQUEUE_COUNT > 0);
            enq[ 3] <= (ENQUEUE_COUNT > 0);
            enq[ 4] <= (ENQUEUE_COUNT > 1);
            enq[ 5] <= (ENQUEUE_COUNT > 1);
            enq[ 6] <= (ENQUEUE_COUNT > 1);
            enq[ 7] <= (ENQUEUE_COUNT > 1);
            enq[ 8] <= (ENQUEUE_COUNT > 2);
            enq[ 9] <= (ENQUEUE_COUNT > 2);
            enq[10] <= (ENQUEUE_COUNT > 2);
            enq[11] <= (ENQUEUE_COUNT > 2);
            enq[12] <= (ENQUEUE_COUNT > 3);
            enq[13] <= (ENQUEUE_COUNT > 3);
            enq[14] <= (ENQUEUE_COUNT > 3);
            enq[15] <= (ENQUEUE_COUNT > 3);
            w_inc <= 1;
            w_inc_val <= {ENQUEUE_COUNT[2:0], 2'b00};
        end
        else if(CLK_EN && ENQUEUE && CLRM == T9990_REG::CLRM_16BPP) begin
            enq[ 0] <= (ENQUEUE_COUNT > 0);
            enq[ 1] <= (ENQUEUE_COUNT > 0);
            enq[ 2] <= (ENQUEUE_COUNT > 0);
            enq[ 3] <= (ENQUEUE_COUNT > 0);
            enq[ 4] <= (ENQUEUE_COUNT > 0);
            enq[ 5] <= (ENQUEUE_COUNT > 0);
            enq[ 6] <= (ENQUEUE_COUNT > 0);
            enq[ 7] <= (ENQUEUE_COUNT > 0);
            enq[ 8] <= (ENQUEUE_COUNT > 1);
            enq[ 9] <= (ENQUEUE_COUNT > 1);
            enq[10] <= (ENQUEUE_COUNT > 1);
            enq[11] <= (ENQUEUE_COUNT > 1);
            enq[12] <= (ENQUEUE_COUNT > 1);
            enq[13] <= (ENQUEUE_COUNT > 1);
            enq[14] <= (ENQUEUE_COUNT > 1);
            enq[15] <= (ENQUEUE_COUNT > 1);
            w_inc <= 1;
            w_inc_val <= {ENQUEUE_COUNT[1:0], 3'b000};
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

`ifdef TEST
    reg [31:0] enqueue_shift_data;
    always_ff @(posedge CLK) begin
        if(CLK_EN && ENQUEUE) begin
            case (ENQUEUE_SHIFT)
                4'd0:   enqueue_shift_data <=  ENQUEUE_DATA;
                4'd1:   enqueue_shift_data <= {ENQUEUE_DATA[29:0],  2'b0};
                4'd2:   enqueue_shift_data <= {ENQUEUE_DATA[27:0],  4'b0};
                4'd3:   enqueue_shift_data <= {ENQUEUE_DATA[25:0],  6'b0};
                4'd4:   enqueue_shift_data <= {ENQUEUE_DATA[23:0],  8'b0};
                4'd5:   enqueue_shift_data <= {ENQUEUE_DATA[21:0], 10'b0};
                4'd6:   enqueue_shift_data <= {ENQUEUE_DATA[19:0], 12'b0};
                4'd7:   enqueue_shift_data <= {ENQUEUE_DATA[17:0], 14'b0};
                4'd8:   enqueue_shift_data <= {ENQUEUE_DATA[15:0], 16'b0};
                4'd9:   enqueue_shift_data <= {ENQUEUE_DATA[13:0], 18'b0};
                4'd10:  enqueue_shift_data <= {ENQUEUE_DATA[11:0], 20'b0};
                4'd11:  enqueue_shift_data <= {ENQUEUE_DATA[ 9:0], 22'b0};
                4'd12:  enqueue_shift_data <= {ENQUEUE_DATA[ 7:0], 24'b0};
                4'd13:  enqueue_shift_data <= {ENQUEUE_DATA[ 5:0], 26'b0};
                4'd14:  enqueue_shift_data <= {ENQUEUE_DATA[ 3:0], 28'b0};
                4'd15:  enqueue_shift_data <= {ENQUEUE_DATA[ 1:0], 30'b0};
            endcase
        end
    end

    wire [1:0] in_pixel_2[0:15];
    assign in_pixel_2[ 0] = enqueue_shift_data[31:30];
    assign in_pixel_2[ 1] = enqueue_shift_data[29:28];
    assign in_pixel_2[ 2] = enqueue_shift_data[27:26];
    assign in_pixel_2[ 3] = enqueue_shift_data[25:24];
    assign in_pixel_2[ 4] = enqueue_shift_data[23:22];
    assign in_pixel_2[ 5] = enqueue_shift_data[21:20];
    assign in_pixel_2[ 6] = enqueue_shift_data[19:18];
    assign in_pixel_2[ 7] = enqueue_shift_data[17:16];
    assign in_pixel_2[ 8] = enqueue_shift_data[15:14];
    assign in_pixel_2[ 9] = enqueue_shift_data[13:12];
    assign in_pixel_2[10] = enqueue_shift_data[11:10];
    assign in_pixel_2[11] = enqueue_shift_data[ 9: 8];
    assign in_pixel_2[12] = enqueue_shift_data[ 7: 6];
    assign in_pixel_2[13] = enqueue_shift_data[ 5: 4];
    assign in_pixel_2[14] = enqueue_shift_data[ 3: 2];
    assign in_pixel_2[15] = enqueue_shift_data[ 1: 0];
`else
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
`endif

    reg [4:0] w_offset[0:15];
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            w_offset[ 0] <= 5'd0;
            w_offset[ 1] <= 5'd1;
            w_offset[ 2] <= 5'd2;
            w_offset[ 3] <= 5'd3;
            w_offset[ 4] <= 5'd4;
            w_offset[ 5] <= 5'd5;
            w_offset[ 6] <= 5'd6;
            w_offset[ 7] <= 5'd7;
            w_offset[ 8] <= 5'd8;
            w_offset[ 9] <= 5'd9;
            w_offset[10] <= 5'd10;
            w_offset[11] <= 5'd11;
            w_offset[12] <= 5'd12;
            w_offset[13] <= 5'd13;
            w_offset[14] <= 5'd14;
            w_offset[15] <= 5'd15;
        end
        else if(w_inc) begin
            w_offset[ 0] <= (w_offset[ 0] + w_inc_val) & 5'd31;
            w_offset[ 1] <= (w_offset[ 1] + w_inc_val) & 5'd31;
            w_offset[ 2] <= (w_offset[ 2] + w_inc_val) & 5'd31;
            w_offset[ 3] <= (w_offset[ 3] + w_inc_val) & 5'd31;
            w_offset[ 4] <= (w_offset[ 4] + w_inc_val) & 5'd31;
            w_offset[ 5] <= (w_offset[ 5] + w_inc_val) & 5'd31;
            w_offset[ 6] <= (w_offset[ 6] + w_inc_val) & 5'd31;
            w_offset[ 7] <= (w_offset[ 7] + w_inc_val) & 5'd31;
            w_offset[ 8] <= (w_offset[ 8] + w_inc_val) & 5'd31;
            w_offset[ 9] <= (w_offset[ 9] + w_inc_val) & 5'd31;
            w_offset[10] <= (w_offset[10] + w_inc_val) & 5'd31;
            w_offset[11] <= (w_offset[11] + w_inc_val) & 5'd31;
            w_offset[12] <= (w_offset[12] + w_inc_val) & 5'd31;
            w_offset[13] <= (w_offset[13] + w_inc_val) & 5'd31;
            w_offset[14] <= (w_offset[14] + w_inc_val) & 5'd31;
            w_offset[15] <= (w_offset[15] + w_inc_val) & 5'd31;
        end
    end

    reg [1:0] buffer[0:31]/* synthesis syn_ramstyle="registers" */;
    always_ff @(posedge CLK) begin
        if(enq[ 0]) buffer[w_offset[ 0]] <= in_pixel_2[ 0];
        if(enq[ 1]) buffer[w_offset[ 1]] <= in_pixel_2[ 1];
        if(enq[ 2]) buffer[w_offset[ 2]] <= in_pixel_2[ 2];
        if(enq[ 3]) buffer[w_offset[ 3]] <= in_pixel_2[ 3];
        if(enq[ 4]) buffer[w_offset[ 4]] <= in_pixel_2[ 4];
        if(enq[ 5]) buffer[w_offset[ 5]] <= in_pixel_2[ 5];
        if(enq[ 6]) buffer[w_offset[ 6]] <= in_pixel_2[ 6];
        if(enq[ 7]) buffer[w_offset[ 7]] <= in_pixel_2[ 7];
        if(enq[ 8]) buffer[w_offset[ 8]] <= in_pixel_2[ 8];
        if(enq[ 9]) buffer[w_offset[ 9]] <= in_pixel_2[ 9];
        if(enq[10]) buffer[w_offset[10]] <= in_pixel_2[10];
        if(enq[11]) buffer[w_offset[11]] <= in_pixel_2[11];
        if(enq[12]) buffer[w_offset[12]] <= in_pixel_2[12];
        if(enq[13]) buffer[w_offset[13]] <= in_pixel_2[13];
        if(enq[14]) buffer[w_offset[14]] <= in_pixel_2[14];
        if(enq[15]) buffer[w_offset[15]] <= in_pixel_2[15];
    end

    /***************************************************************
     * DEQUEUE
     ***************************************************************/
    reg [4:0] r_offset[0:15];

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
            r_offset[0] <= 5'd0;
            r_offset[1] <= 5'd1;
            r_offset[2] <= 5'd2;
            r_offset[3] <= 5'd3;
            r_offset[4] <= 5'd4;
            r_offset[5] <= 5'd5;
            r_offset[6] <= 5'd6;
            r_offset[7] <= 5'd7;
            r_offset[8] <= 5'd8;
            r_offset[9] <= 5'd9;
            r_offset[10] <= 5'd10;
            r_offset[11] <= 5'd11;
            r_offset[12] <= 5'd12;
            r_offset[13] <= 5'd13;
            r_offset[14] <= 5'd14;
            r_offset[15] <= 5'd15;
        end
        else if(DEQUEUE && CLK_EN) begin
            if(CLRM == T9990_REG::CLRM_2BPP) begin
                r_offset[ 0] <= (r_offset[ 0] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 1] <= (r_offset[ 1] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 2] <= (r_offset[ 2] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 3] <= (r_offset[ 3] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 4] <= (r_offset[ 4] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 5] <= (r_offset[ 5] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 6] <= (r_offset[ 6] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 7] <= (r_offset[ 7] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 8] <= (r_offset[ 8] + DEQUEUE_COUNT) & 5'd31;
                r_offset[ 9] <= (r_offset[ 9] + DEQUEUE_COUNT) & 5'd31;
                r_offset[10] <= (r_offset[10] + DEQUEUE_COUNT) & 5'd31;
                r_offset[11] <= (r_offset[11] + DEQUEUE_COUNT) & 5'd31;
                r_offset[12] <= (r_offset[12] + DEQUEUE_COUNT) & 5'd31;
                r_offset[13] <= (r_offset[13] + DEQUEUE_COUNT) & 5'd31;
                r_offset[14] <= (r_offset[14] + DEQUEUE_COUNT) & 5'd31;
                r_offset[15] <= (r_offset[15] + DEQUEUE_COUNT) & 5'd31;
            end
            else if(CLRM == T9990_REG::CLRM_4BPP) begin
                r_offset[ 0] <= (r_offset[ 0] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 1] <= (r_offset[ 1] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 2] <= (r_offset[ 2] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 3] <= (r_offset[ 3] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 4] <= (r_offset[ 4] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 5] <= (r_offset[ 5] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 6] <= (r_offset[ 6] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 7] <= (r_offset[ 7] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 8] <= (r_offset[ 8] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[ 9] <= (r_offset[ 9] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[10] <= (r_offset[10] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[11] <= (r_offset[11] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[12] <= (r_offset[12] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[13] <= (r_offset[13] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[14] <= (r_offset[14] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
                r_offset[15] <= (r_offset[15] + {DEQUEUE_COUNT[3:0], 1'b0}) & 5'd31;
            end
            else if(CLRM == T9990_REG::CLRM_8BPP) begin
                r_offset[ 0] <= (r_offset[ 0] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 1] <= (r_offset[ 1] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 2] <= (r_offset[ 2] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 3] <= (r_offset[ 3] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 4] <= (r_offset[ 4] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 5] <= (r_offset[ 5] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 6] <= (r_offset[ 6] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 7] <= (r_offset[ 7] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 8] <= (r_offset[ 8] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[ 9] <= (r_offset[ 9] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[10] <= (r_offset[10] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[11] <= (r_offset[11] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[12] <= (r_offset[12] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[13] <= (r_offset[13] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[14] <= (r_offset[14] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
                r_offset[15] <= (r_offset[15] + {DEQUEUE_COUNT[2:0], 2'b00}) & 5'd31;
            end
            else if(CLRM == T9990_REG::CLRM_16BPP) begin
                r_offset[ 0] <= (r_offset[ 0] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 1] <= (r_offset[ 1] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 2] <= (r_offset[ 2] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 3] <= (r_offset[ 3] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 4] <= (r_offset[ 4] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 5] <= (r_offset[ 5] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 6] <= (r_offset[ 6] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 7] <= (r_offset[ 7] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 8] <= (r_offset[ 8] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[ 9] <= (r_offset[ 9] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[10] <= (r_offset[10] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[11] <= (r_offset[11] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[12] <= (r_offset[12] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[13] <= (r_offset[13] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[14] <= (r_offset[14] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
                r_offset[15] <= (r_offset[15] + {DEQUEUE_COUNT[1:0], 3'b000}) & 5'd31;
            end
        end
    end

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || CLEAR) begin
        end
        else if(DEQUEUE && CLK_EN) begin
            case (DEQUEUE_SHIFT)
                4'd0: begin
                    DEQUEUE_DATA[31:30] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[29:28] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[27:26] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[25:24] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[23:22] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[10]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[11]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[12]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[13]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[14]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[15]];
                end
                4'd1: begin
                    DEQUEUE_DATA[29:28] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[27:26] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[25:24] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[23:22] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[10]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[11]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[12]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[13]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[14]];
                end
                4'd2: begin
                    DEQUEUE_DATA[27:26] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[25:24] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[23:22] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[10]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[11]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[12]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[13]];
                end
                4'd3: begin
                    DEQUEUE_DATA[25:24] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[23:22] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[10]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[11]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[12]];
                end
                4'd4: begin
                    DEQUEUE_DATA[23:22] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[10]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[11]];
                end
                4'd5: begin
                    DEQUEUE_DATA[21:20] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 9]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[10]];
                end
                4'd6: begin
                    DEQUEUE_DATA[19:18] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 8]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 9]];
                end
                4'd7: begin
                    DEQUEUE_DATA[17:16] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 7]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 8]];
                end
                4'd8: begin
                    DEQUEUE_DATA[15:14] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 6]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 7]];
                end
                4'd9: begin
                    DEQUEUE_DATA[13:12] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 5]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 6]];
                end
                4'd10: begin
                    DEQUEUE_DATA[11:10] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 4]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 5]];
                end
                4'd11: begin
                    DEQUEUE_DATA[ 9: 8] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 3]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 4]];
                end
                4'd12: begin
                    DEQUEUE_DATA[ 7: 6] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 2]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 3]];
                end
                4'd13: begin
                    DEQUEUE_DATA[ 5: 4] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 1]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 2]];
                end
                4'd14: begin
                    DEQUEUE_DATA[ 3: 2] <= buffer[r_offset[ 0]];
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 1]];
                end
                4'd15: begin
                    DEQUEUE_DATA[ 1: 0] <= buffer[r_offset[ 0]];
                end
            endcase
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
        else if(CLK_EN) begin
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
