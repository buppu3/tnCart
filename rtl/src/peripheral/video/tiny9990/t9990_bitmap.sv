//
// t9990_bitmap.sv
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
 * Bx 画面生成
 ***************************************************************/
module T9990_BITMAP (
    input wire              RESET_n,
    input wire              CLK,
    input wire              DCLK_EN,
    input wire              DISABLE,

    T9990_REGISTER_IF.VDP   REG,
    input wire [10:0]       SCX,
    input wire [12:0]       SCY,

    input wire [9:0]        HCNT,
    input wire [8:0]        VCNT,
    input wire              START,

    T9990_VDP_MEM_IF.VDP    MEM,

    output reg [5:0]        PA,
    output reg [0:0]        PRI,
    output reg [15:0]       CLR
);
    /***************************************************************
     * 倍密度フラグ
     ***************************************************************/
    reg DBL;
    always_ff @(posedge CLK) DBL <= REG.MCS ? REG.DCKM[1] : REG.DCKM[0];

    /***************************************************************
     * 信号の生成
     ***************************************************************/
    logic [$bits(PA)-1:0] PA_GEN;
    logic [$bits(PRI)-1:0] PRI_GEN;
    logic [$bits(CLR)-1:0] CLR_GEN;

    wire [10:0] x = DBL ? {SCX[10:5], 5'b00000} : {SCX[10:4], 4'b0000};

    TINY9990_BITMAP_GEN u_gen (
        .RESET_n,
        .CLK,
        .DCLK_EN,
        .DISABLE,

        .REG,
        .DBL,

        .X(x + HCNT),
        .Y(SCY+VCNT),
        .START,

        .MEM,

        .PA(PA_GEN),
        .PRI(PRI_GEN),
        .CLR(CLR_GEN)
    );

    /***************************************************************
     * 水平方向シフト
     ***************************************************************/
    logic [$bits(PRI_GEN)+$bits(PA_GEN)+$bits(CLR_GEN)-1:0] OUT;

    T9990_SHIFT_BUFFER #(
        .BIT_WIDTH($bits(OUT)),
        .COUNT(32)
    ) u_sht_buf (
        .RESET_n,
        .CLK,
        .DCLK_EN,
        .DISABLE,
        .OFFSET(DBL ? SCX[4:0] : {1'b1, SCX[3:0]}),
        .IN({PRI_GEN, PA_GEN, CLR_GEN}),
        .OUT
    );

    assign CLR = OUT[$bits(CLR_GEN)-1:0];
    assign PA = OUT[$bits(PA_GEN)+$bits(CLR_GEN)-1:$bits(CLR_GEN)];
    assign PRI = OUT[$bits(PRI_GEN)+$bits(PA_GEN)+$bits(CLR_GEN)-1:$bits(PA_GEN)+$bits(CLR_GEN)];
endmodule

module TINY9990_BITMAP_GEN (
    input wire              RESET_n,
    input wire              CLK,
    input wire              DCLK_EN,
    input wire              DISABLE,

    T9990_REGISTER_IF.VDP   REG,
    input wire              DBL,

    input wire [10:0]       X,
    input wire [12:0]       Y,
    input wire              START,

    T9990_VDP_MEM_IF.VDP    MEM,

    output reg [5:0]        PA,
    output reg [0:0]        PRI,
    output reg [15:0]       CLR
);

    /***************************************************************
     * アドレス計算
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            MEM.ADDR <= 0;
        end
        else if(DISABLE) begin
        end
        else if(MEM.REQ) begin
            if(REG.CLRM == T9990_REG::CLRM_2BPP) begin
                     if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R256) MEM.ADDR <= {2'h0, Y[ 7:0], X[10:4], 2'h0 };  // X=0~2047,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R512) MEM.ADDR <= {1'h0, Y[ 8:0], X[10:4], 2'h0 };  // X=0~2047,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_2048            ) MEM.ADDR <= {      Y[ 9:0], X[10:4], 2'h0 };  // X=0~2047,Y=0~1023
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R256) MEM.ADDR <= {3'h0, Y[ 7:0], X[ 9:4], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R512) MEM.ADDR <= {2'h0, Y[ 8:0], X[ 9:4], 2'h0 };  // X=0~1023,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_1024            ) MEM.ADDR <= {      Y[10:0], X[ 9:4], 2'h0 };  // X=0~1023,Y=0~2047
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R256) MEM.ADDR <= {4'h0, Y[ 7:0], X[ 8:4], 2'h0 };  // X=0~ 511,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R512) MEM.ADDR <= {3'h0, Y[ 8:0], X[ 8:4], 2'h0 };  // X=0~ 511,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_512             ) MEM.ADDR <= {      Y[11:0], X[ 8:4], 2'h0 };  // X=0~ 511,Y=0~4095
                else if(                                    REG.R256) MEM.ADDR <= {5'h0, Y[ 7:0], X[ 7:4], 2'h0 };  // X=0~ 255,Y=0~ 255
                else if(                                    REG.R512) MEM.ADDR <= {4'h0, Y[ 8:0], X[ 7:4], 2'h0 };  // X=0~ 255,Y=0~ 511
                else                                                  MEM.ADDR <= {      Y[12:0], X[ 7:4], 2'h0 };  // X=0~ 255,Y=0~8191
            end
            else if(REG.CLRM == T9990_REG::CLRM_4BPP) begin
                     if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R256) MEM.ADDR <= {1'h0, Y[ 7:0], X[10:3], 2'h0 };  // X=0~2047,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R512) MEM.ADDR <= {      Y[ 8:0], X[10:3], 2'h0 };  // X=0~2047,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_2048            ) MEM.ADDR <= {      Y[ 8:0], X[10:3], 2'h0 };  // X=0~2047,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R256) MEM.ADDR <= {2'h0, Y[ 7:0], X[ 9:3], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R512) MEM.ADDR <= {1'h0, Y[ 8:0], X[ 9:3], 2'h0 };  // X=0~1023,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_1024            ) MEM.ADDR <= {      Y[ 9:0], X[ 9:3], 2'h0 };  // X=0~1023,Y=0~1023
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R256) MEM.ADDR <= {3'h0, Y[ 7:0], X[ 8:3], 2'h0 };  // X=0~ 511,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R512) MEM.ADDR <= {2'h0, Y[ 8:0], X[ 8:3], 2'h0 };  // X=0~ 511,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_512             ) MEM.ADDR <= {      Y[10:0], X[ 8:3], 2'h0 };  // X=0~ 511,Y=0~2047
                else if(                                    REG.R256) MEM.ADDR <= {4'h0, Y[ 7:0], X[ 7:3], 2'h0 };  // X=0~ 255,Y=0~ 255
                else if(                                    REG.R512) MEM.ADDR <= {3'h0, Y[ 8:0], X[ 7:3], 2'h0 };  // X=0~ 255,Y=0~ 511
                else                                                  MEM.ADDR <= {      Y[11:0], X[ 7:3], 2'h0 };  // X=0~ 255,Y=0~4095
            end
            else if(REG.CLRM == T9990_REG::CLRM_8BPP) begin
                     if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R256) MEM.ADDR <= {      Y[ 7:0], X[10:2], 2'h0 };  // X=0~2047,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R512) MEM.ADDR <= {      Y[ 7:0], X[10:2], 2'h0 };  // X=0~2047,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_2048            ) MEM.ADDR <= {      Y[ 7:0], X[10:2], 2'h0 };  // X=0~2047,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R256) MEM.ADDR <= {1'h0, Y[ 7:0], X[ 9:2], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R512) MEM.ADDR <= {      Y[ 8:0], X[ 9:2], 2'h0 };  // X=0~1023,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_1024            ) MEM.ADDR <= {      Y[ 8:0], X[ 9:2], 2'h0 };  // X=0~1023,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R256) MEM.ADDR <= {2'h0, Y[ 7:0], X[ 8:2], 2'h0 };  // X=0~ 511,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R512) MEM.ADDR <= {1'h0, Y[ 8:0], X[ 8:2], 2'h0 };  // X=0~ 511,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_512             ) MEM.ADDR <= {      Y[ 9:0], X[ 8:2], 2'h0 };  // X=0~ 511,Y=0~1023
                else if(                                    REG.R256) MEM.ADDR <= {3'h0, Y[ 7:0], X[ 7:2], 2'h0 };  // X=0~ 255,Y=0~ 255
                else if(                                    REG.R512) MEM.ADDR <= {2'h0, Y[ 8:0], X[ 7:2], 2'h0 };  // X=0~ 255,Y=0~ 511
                else                                                  MEM.ADDR <= {      Y[10:0], X[ 7:2], 2'h0 };  // X=0~ 255,Y=0~2047
            end
            else begin
                     if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R256) MEM.ADDR <= {      Y[ 6:0], X[10:1], 2'h0 };  // X=0~2047,Y=0~ 127
                else if(REG.XIMM == T9990_REG::XIMM_2048 && REG.R512) MEM.ADDR <= {      Y[ 6:0], X[10:1], 2'h0 };  // X=0~2047,Y=0~ 127
                else if(REG.XIMM == T9990_REG::XIMM_2048            ) MEM.ADDR <= {      Y[ 6:0], X[10:1], 2'h0 };  // X=0~2047,Y=0~ 127
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R256) MEM.ADDR <= {      Y[ 7:0], X[ 9:1], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024 && REG.R512) MEM.ADDR <= {      Y[ 7:0], X[ 9:1], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_1024            ) MEM.ADDR <= {      Y[ 7:0], X[ 9:1], 2'h0 };  // X=0~1023,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R256) MEM.ADDR <= {1'h0, Y[ 7:0], X[ 8:1], 2'h0 };  // X=0~ 511,Y=0~ 255
                else if(REG.XIMM == T9990_REG::XIMM_512  && REG.R512) MEM.ADDR <= {      Y[ 8:0], X[ 8:1], 2'h0 };  // X=0~ 511,Y=0~ 511
                else if(REG.XIMM == T9990_REG::XIMM_512             ) MEM.ADDR <= {      Y[ 8:0], X[ 8:1], 2'h0 };  // X=0~ 511,Y=0~ 511
                else if(                                    REG.R256) MEM.ADDR <= {2'h0, Y[ 7:0], X[ 7:1], 2'h0 };  // X=0~ 255,Y=0~ 255
                else if(                                    REG.R512) MEM.ADDR <= {1'h0, Y[ 8:0], X[ 7:1], 2'h0 };  // X=0~ 255,Y=0~ 511
                else                                                  MEM.ADDR <= {      Y[ 9:0], X[ 7:1], 2'h0 };  // X=0~ 255,Y=0~1023
            end
        end
    end


    /***************************************************************
     * バッファ
     ***************************************************************/
    logic [0:0] W_NUM;
    logic [3:0] W_ADDR;
    logic [31:0] W_DATA;
    logic W_STROBE;
    logic [0:0] R_NUM;
    logic [4:0] R_POS;
    logic [15:0] R_DATA;

    T9990_BITMAP_BUFFER u_buff (
        .CLK,
        .DISABLE,
        .CLRM(REG.CLRM),
        .W_NUM,
        .W_ADDR,
        .W_DATA,
        .W_STROBE,
        .R_NUM,
        .R_POS,
        .R_DATA
    );

    /***************************************************************
     * 読み出しデータ格納
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            W_STROBE <= 0;
            W_DATA <= 0;
        end
        else if(DISABLE) begin
        end
        else if(MEM.ACK) begin
            W_DATA <= { MEM.DOUT[7:0], MEM.DOUT[15:8], MEM.DOUT[23:16], MEM.DOUT[31:24] };
            W_STROBE <= 1;
        end
        else begin
            W_STROBE <= 0;
        end
    end

    logic [4:0] w_state;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            W_ADDR <= 0;
            W_NUM <= 0;
            w_state <= 0;
        end
        else if(DISABLE) begin
        end
        else if(START) begin
            W_ADDR <= 0;
            W_NUM <= 0;
            w_state <= 0;
        end
        else if(MEM.ACK) begin
            if(DBL) begin
                if(REG.CLRM == T9990_REG::CLRM_2BPP) begin
                    W_ADDR <= w_state[0];
                    W_NUM <= w_state[1];
                end
                else if(REG.CLRM == T9990_REG::CLRM_4BPP) begin
                    W_ADDR <= w_state[1:0];
                    W_NUM <= w_state[2];
                end
                else if(REG.CLRM == T9990_REG::CLRM_8BPP) begin
                    W_ADDR <= w_state[2:0];
                    W_NUM <= w_state[3];
                end
                else begin
                    W_ADDR <= w_state[3:0];
                    W_NUM <= w_state[4];
                end
            end
            else begin
                if(REG.CLRM == T9990_REG::CLRM_2BPP) begin
                    W_ADDR <= 0;
                    W_NUM <= w_state[0];
                end
                else if(REG.CLRM == T9990_REG::CLRM_4BPP) begin
                    W_ADDR <= w_state[0];
                    W_NUM <= w_state[1];
                end
                else if(REG.CLRM == T9990_REG::CLRM_8BPP) begin
                    W_ADDR <= w_state[1:0];
                    W_NUM <= w_state[2];
                end
                else begin
                    W_ADDR <= w_state[2:0];
                    W_NUM <= w_state[3];
                end
            end

            w_state <= w_state + 1'd1;
        end
    end

    /***************************************************************
     * ドット出力カウンタ
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            R_POS <= 0;
            R_NUM <= 1;
        end
        else if(DISABLE) begin
        end
        else if(START) begin
            if(DBL) begin
                R_POS <= 5'd31;
            end
            else begin
                R_POS <= 5'd15;
            end
            R_NUM <= 0;
        end
        else if(DCLK_EN) begin
            if(DBL) begin
                if(R_POS == 5'd31) begin
                    R_POS <= 0;
                    R_NUM <= !R_NUM;
                end
                else begin
                    R_POS <= R_POS + 1'd1;
                end
            end
            else begin
                if(R_POS == 5'd15) begin
                    R_POS <= 0;
                    R_NUM <= !R_NUM;
                end
                else begin
                    R_POS <= R_POS + 1'd1;
                end
            end
        end
    end

    /***************************************************************
     * ドット出力
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            PRI <= 1;
            PA <= 0;
            CLR <= 0;
        end
        else if(DISABLE) begin
        end
        else if(DCLK_EN) begin
            if(REG.CLRM == T9990_REG::CLRM_2BPP) begin
                PRI <= (R_DATA[1:0] == 0);
                PA <= { REG.PLT[3:0], R_DATA[1:0] };
                CLR <= 0;
            end
            else if(REG.CLRM == T9990_REG::CLRM_4BPP) begin
                PRI <= (R_DATA[3:0] == 0);
                PA <= { REG.PLT[3:2], R_DATA[3:0] };
                CLR <= 0;
            end
            else if(REG.CLRM == T9990_REG::CLRM_8BPP) begin
                if(REG.YAE) begin
                    if(R_DATA[3]) begin
                        PRI <= (R_DATA[7:4] == 0);
                        PA  <= { REG.PLT[3:2], R_DATA[7:4] };
                        CLR <= 0;
                    end
                    else begin
                        PRI <= 1;
                        PA  <= 0;
                        CLR <= R_DATA[7:0];
                    end
                end
                else if(REG.PLTM == T9990_REG::PLTM_PALETTE) begin
                    PRI <= (R_DATA[5:0] == 0);
                    PA <= R_DATA[5:0];
                    CLR <= 0;
                end
                else begin
                    PRI <= 1;
                    PA <= 0;
                    CLR <= R_DATA[7:0];
                end
            end
            else begin
                PRI <= 0;
                PA <= 0;
                CLR <= R_DATA[15:0];
            end
        end
    end
endmodule

module T9990_BITMAP_MEM (
    input wire          CLK,

    input wire [3:0]    W_ADDR,
    input wire [31:0]   W_DATA,
    input wire          W_STROBE,

    input wire [3:0]    R_ADDR,
    output reg [31:0]   R_DATA
);
    reg [31:0] buffer[0:16-1] /* synthesis syn_ramstyle="block_ram" */;

    always_ff @(posedge CLK)
    begin
        if(W_STROBE) begin
            buffer[W_ADDR] <= W_DATA;
        end
        R_DATA <= buffer[R_ADDR];
    end
endmodule

module T9990_BITMAP_BUFFER (
    input wire          CLK,
    input wire          DISABLE,

    input wire [1:0]    CLRM,

    input wire [0:0]    W_NUM,
    input wire [3:0]    W_ADDR,
    input wire [31:0]   W_DATA,
    input wire          W_STROBE,

    input wire [0:0]    R_NUM,
    input wire [4:0]    R_POS,
    output reg [15:0]   R_DATA
);
    logic w_strobe_0;
    logic w_strobe_1;
    logic [31:0] r_data_0;
    logic [31:0] r_data_1;
    wire [31:0] r_data = R_NUM ? r_data_1 : r_data_0;
    wire [3:0] r_addr = (CLRM == T9990_REG::CLRM_2BPP) ? R_POS[4] :
                        (CLRM == T9990_REG::CLRM_4BPP) ? R_POS[4:3] :
                        (CLRM == T9990_REG::CLRM_8BPP) ? R_POS[4:2] : R_POS[4:1];

    T9990_BITMAP_MEM u_mem0 (
        .CLK,
        .W_ADDR,
        .W_DATA,
        .W_STROBE(w_strobe_0),
        .R_ADDR(r_addr),
        .R_DATA(r_data_0)
    );

    T9990_BITMAP_MEM u_mem1 (
        .CLK,
        .W_ADDR,
        .W_DATA,
        .W_STROBE(w_strobe_1),
        .R_ADDR(r_addr),
        .R_DATA(r_data_1)
    );

    always_ff @(posedge CLK)
    begin
        if(DISABLE) begin
        end
        else if(CLRM == T9990_REG::CLRM_2BPP) begin
            case (R_POS[3:0])
                5'd 0:  R_DATA <= r_data[31:30];
                5'd 1:  R_DATA <= r_data[29:28];
                5'd 2:  R_DATA <= r_data[27:26];
                5'd 3:  R_DATA <= r_data[25:24];
                5'd 4:  R_DATA <= r_data[23:22];
                5'd 5:  R_DATA <= r_data[21:20];
                5'd 6:  R_DATA <= r_data[19:18];
                5'd 7:  R_DATA <= r_data[17:16];
                5'd 8:  R_DATA <= r_data[15:14];
                5'd 9:  R_DATA <= r_data[13:12];
                5'd10:  R_DATA <= r_data[11:10];
                5'd11:  R_DATA <= r_data[ 9: 8];
                5'd12:  R_DATA <= r_data[ 7: 6];
                5'd13:  R_DATA <= r_data[ 5: 4];
                5'd14:  R_DATA <= r_data[ 3: 2];
                5'd15:  R_DATA <= r_data[ 1: 0];
            endcase
        end
        else if(CLRM == T9990_REG::CLRM_4BPP) begin
            case (R_POS[2:0])
                5'd 0:  R_DATA <= r_data[31:28];
                5'd 1:  R_DATA <= r_data[27:24];
                5'd 2:  R_DATA <= r_data[23:20];
                5'd 3:  R_DATA <= r_data[19:16];
                5'd 4:  R_DATA <= r_data[15:12];
                5'd 5:  R_DATA <= r_data[11: 8];
                5'd 6:  R_DATA <= r_data[ 7: 4];
                5'd 7:  R_DATA <= r_data[ 3: 0];
            endcase
        end
        else if(CLRM == T9990_REG::CLRM_8BPP) begin
            case (R_POS[1:0])
                5'd 0:  R_DATA <= r_data[31:24];
                5'd 1:  R_DATA <= r_data[23:16];
                5'd 2:  R_DATA <= r_data[15: 8];
                5'd 3:  R_DATA <= r_data[ 7: 0];
            endcase
        end
        else begin
            case (R_POS[0])
                5'd 0:  R_DATA <= r_data[31:16];
                5'd 1:  R_DATA <= r_data[15: 0];
            endcase
        end
    end

    always_ff @(posedge CLK)
    begin
        if(DISABLE) begin
        end
        else if(W_STROBE) begin
            if(W_NUM) begin
                w_strobe_0 <= 0;
                w_strobe_1 <= 1;
            end
            else begin
                w_strobe_0 <= 1;
                w_strobe_1 <= 0;
            end
        end
        else begin
            w_strobe_0 <= 0;
            w_strobe_1 <= 0;
        end
    end
endmodule

`default_nettype wire
