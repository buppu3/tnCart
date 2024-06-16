//
// debugger.sv
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

`include "debugger_char.inc"    // キャラクターコード定義

localparam VERSION = 1;

localparam TYPE_MEMORY_READ = 3'd0;
localparam TYPE_MEMORY_WRITE = 3'd1;
localparam TYPE_IO_READ = 3'd2;
localparam TYPE_IO_WRITE = 3'd3;
localparam TYPE_RAM_READ = 3'd4;
localparam TYPE_RAM_WRITE = 3'd5;
localparam TYPE_BUS_RESET = 3'd6;
localparam TYPE_SYS_RESET = 3'd7;

/***********************************************************************
 * デバッガモジュール
 ***********************************************************************/

// メモリバスリード
//     MR [アドレス],[バイト数]
// メモリバスライト
//     MW [アドレス],[データ],・・・
// I/Oバスリード
//     IR [アドレス],[バイト数]
// I/Oバスライト
//     IW [アドレス],[データ],・・・
// バスリセット
//     BR
// システムリセット
//     SR

module DEBUGGER (
    input wire          RESET_n,
    input wire          CLK,
    BUS_IF.CARTRIDGE    IN,
    BUS_IF.MSX          OUT,
    output wire         RESET_OUT_n,
    UART_TX_IF.HOST     TXD,    // UART 送信
    UART_RX_IF.HOST     RXD     // UART 受信
);

    /***************************************************************
     * バス操作
     ***************************************************************/
    reg [31:0]  bus_addr;
    reg [7:0]   bus_din;
    wire [7:0]  bus_dout;
    reg [3:0]   bus_type;
    reg         bus_req_n;
    wire        bus_ack_n;

    DEBUGGER_BUS_OP u_bus_op (
        .CLK            (CLK),
        .RESET_n        (RESET_n),
        .IN             (IN),
        .OUT            (OUT),
        .RESET_OUT_n    (RESET_OUT_n),

        .ADDR           (bus_addr),
        .DIN            (bus_din),
        .DOUT           (bus_dout),
        .TYPE           (bus_type),
        .REQ_n          (bus_req_n),
        .ACK_n          (bus_ack_n)
    );

    /***************************************************************
     * UART IN
     ***************************************************************/
    localparam                      INPUT_COUNT = 64;
    reg                             input_req_n;
    wire                            input_ack_n;
    wire [$clog2(INPUT_COUNT+1):0]  input_length;
    wire [7:0]                      input_data[0:INPUT_COUNT-1];
    DEBUGGER_INPUT #(
        .COUNT(INPUT_COUNT)
    ) u_input (
        .CLK            (CLK),
        .RESET_n        (RESET_n),
        .RXD            (RXD),
        .REQ_n          (input_req_n),
        .ACK_n          (input_ack_n),
        .LENGTH         (input_length),
        .DATA           (input_data)
    );

    /***************************************************************
     * UART OUT
     ***************************************************************/
    localparam                      OUTPUT_COUNT = 12;
    reg                             output_req_n;
    reg [1:0]                       output_type;
    wire                            output_ack_n;
    reg [$clog2(OUTPUT_COUNT+1):0]  output_length;
    reg [7:0]                       output_data[0:OUTPUT_COUNT-1];
    DEBUGGER_OUTPUT #(
        .COUNT(OUTPUT_COUNT)
    ) u_output (
        .CLK            (CLK),
        .RESET_n        (RESET_n),
        .TXD            (TXD),
        .REQ_n          (output_req_n),
        .TYPE           (output_type),
        .DATA           (output_data),
        .LENGTH         (output_length),
        .ACK_n          (output_ack_n)
    );

    /***************************************************************
     * 
     ***************************************************************/
    reg                             hex_conv_req_n;
    wire                            hex_conv_ack_n;
    wire [31:0]                     hex_conv_value;
    reg  [$clog2(INPUT_COUNT+1):0]  hex_conv_start;
    wire [$clog2(INPUT_COUNT+1):0]  hex_conv_index;
    DEBUGGER_GET_HEX #(
        .COUNT(INPUT_COUNT)
    ) u_hex_conv (
        .CLK            (CLK),
        .RESET_n        (RESET_n),
        .LENGTH         (input_length),
        .DATA           (input_data),
        .REQ_n          (hex_conv_req_n),
        .ACK_n          (hex_conv_ack_n),
        .START          (hex_conv_start),
        .VALUE          (hex_conv_value),
        .INDEX          (hex_conv_index)
    );

    /***************************************************************
     * 
     ***************************************************************/
    enum logic[4:0] {
        STATE_IDLE=0,
        STATE_INPUT_COMMAND,
        STATE_PARSE_COMMAND,
        STATE_SKIP_SPC,
        STATE_EXEC_COMMAND,

        STATE_ERROR,

        STATE_READ,
        STATE_READ_GET_ADDR,
        STATE_READ_GOT_ADDR,
        STATE_READ_GET_LEN,
        STATE_READ_GOT_LEN,
        STATE_READ_CHECK_REMAIN,
        STATE_READ_GET_DATA,
        STATE_READ_GOT_DATA,
        STATE_READ_COMPLETE,

        STATE_WRITE,
        STATE_WRITE_GET_ADDR,
        STATE_WRITE_GOT_ADDR,
        STATE_WRITE_CHECK_REMAIN,
        STATE_WRITE_GET_DATA,
        STATE_WRITE_GOT_DATA,
        STATE_WRITE_NEXT,
        STATE_WRITE_COMPLETE,

        STATE_RESET,
        STATE_RESET_COMPLETE
    } state;

localparam COMMAND_MEMORY_READ = { 8'h00, 8'h00, CHAR_M, CHAR_R };
localparam COMMAND_MEMORY_WRITE = { 8'h00, 8'h00, CHAR_M, CHAR_W };
localparam COMMAND_IO_READ = { 8'h00, 8'h00, CHAR_I, CHAR_R };
localparam COMMAND_IO_WRITE = { 8'h00, 8'h00, CHAR_I, CHAR_W };
localparam COMMAND_RAM_READ = { 8'h00, 8'h00, CHAR_R, CHAR_R };
localparam COMMAND_RAM_WRITE = { 8'h00, 8'h00, CHAR_R, CHAR_W };
localparam COMMAND_BUS_RESET = { 8'h00, 8'h00, CHAR_B, CHAR_R };
localparam COMMAND_SYS_RESET = { 8'h00, 8'h00, CHAR_S, CHAR_R };

    reg [31:0]                      command;
    reg [$clog2(INPUT_COUNT+1):0]   index;
    reg [15:0]                      remain;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            bus_addr <= 0;
            bus_din <= 0;
            bus_req_n <= 1;
            bus_type <= 0;
            
            input_req_n <= 1;

            output_req_n <= 1;
            output_type <= 0;
            output_length <= 0;

            hex_conv_req_n <= 1;
            hex_conv_start <= 0;

            command <= 0;
            index <= 0;

            state <= STATE_IDLE;
        end

        // バス操作の実行中チェック
        else if(!bus_req_n && bus_ack_n) begin
            // bus_ack_n が 0 になるまで待つ
            bus_req_n <= 0;
        end
        else if(!bus_ack_n) begin
            // bus_ack_n が 1 になるまで待つ
            bus_req_n <= 1;
        end

        // UART 入力の実行中チェック
        else if(!input_req_n && input_ack_n) begin
            // input_ack_n が 0 になるまで待つ
            input_req_n <= 0;
        end
        else if(!input_ack_n) begin
            // input_ack_n が 1 になるまで待つ
            input_req_n <= 1;
        end

        // UART 出力の実行中チェック
        else if(!output_req_n && output_ack_n) begin
            // output_ack_n が 0 になるまで待つ
            output_req_n <= 0;
        end
        else if(!output_ack_n) begin
            // output_ack_n が 1 になるまで待つ
            output_req_n <= 1;
        end

        // HEX 変換器の実行中チェック
        else if(!hex_conv_req_n && hex_conv_ack_n) begin
            // hex_conv_ack_n が 0 になるまで待つ
            hex_conv_req_n <= 0;
        end
        else if(!hex_conv_ack_n) begin
            // hex_conv_ack_n が 1 になるまで待つ
            hex_conv_req_n <= 1;
        end

        // ステート処理
        else case (state)
            default:
            begin
                state <= STATE_IDLE;
            end

            //
            // 起動時
            //
            STATE_IDLE:
            begin
                // UART へ DBG\r を出力
                output_type <= 2'd0;
                output_length <= 4'd12;
                output_data[ 0] <= CHAR_t;
                output_data[ 1] <= CHAR_n;
                output_data[ 2] <= CHAR_C;
                output_data[ 3] <= CHAR_a;
                output_data[ 4] <= CHAR_r;
                output_data[ 5] <= CHAR_t;
                output_data[ 6] <= CHAR_SPC;
                output_data[ 7] <= CHAR_V;
                output_data[ 8] <= CHAR_0 + (VERSION / 10);
                output_data[ 9] <= CHAR_DOT;
                output_data[10] <= CHAR_0 + (VERSION % 10);
                output_data[11] <= CHAR_CR;
                output_req_n <= 0;

                state <= STATE_INPUT_COMMAND;
            end

            //
            // コマンド入力
            //
            STATE_INPUT_COMMAND:
            begin
                input_req_n <= 0;
                command <= 0;
                index <= 0;
                state <= STATE_PARSE_COMMAND;
            end

            //
            // コマンドチェック
            //
            STATE_PARSE_COMMAND:
            begin
                if(index >= input_length) begin
                    state <= STATE_SKIP_SPC;
                end
                else if(input_data[index] <= CHAR_A) begin
                    state <= STATE_SKIP_SPC;
                end
                else begin
                    command <= { command[$bits(command) - 9: 0], input_data[index] };
                    index <= index + 1'd1;
                end
            end

            //
            // コマンド名の後ろのスペースを飛ばす
            //
            STATE_SKIP_SPC:
            begin
                if(index >= input_length) begin
                    state <= STATE_EXEC_COMMAND;
                end
                else if(input_data[index] > CHAR_SPC) begin
                    state <= STATE_EXEC_COMMAND;
                end
                else begin
                    index <= index + 1'd1;
                end
            end

            //
            // コマンドの実行開始
            //
            STATE_EXEC_COMMAND:
            begin
                case (command)
                    default:    state <= STATE_ERROR;
                    COMMAND_MEMORY_READ:    begin   state <= STATE_READ;    bus_type <= TYPE_MEMORY_READ;   end
                    COMMAND_IO_READ:        begin   state <= STATE_READ;    bus_type <= TYPE_IO_READ;       end
                    //COMMAND_RAM_READ:     begin   state <= STATE_READ;    bus_type <= TYPE_RAM_READ;      end
                    COMMAND_MEMORY_WRITE:   begin   state <= STATE_WRITE;   bus_type <= TYPE_MEMORY_WRITE;  end
                    COMMAND_IO_WRITE:       begin   state <= STATE_WRITE;   bus_type <= TYPE_IO_WRITE;      end
                    //COMMAND_RAM_WRITE:    begin   state <= STATE_WRITE;   bus_type <= TYPE_RAM_WRITE;     end
                    COMMAND_BUS_RESET:      begin   state <= STATE_RESET;   bus_type <= TYPE_BUS_RESET;     end
                    COMMAND_SYS_RESET:      begin   state <= STATE_RESET;   bus_type <= TYPE_SYS_RESET;     end
                endcase
            end

            //
            // エラー
            //
            STATE_ERROR:
            begin
                // UART へ ERR\r を出力
                output_type <= 2'd0;
                output_length <= 3'd4;
                output_data[0] <= CHAR_E;
                output_data[1] <= CHAR_R;
                output_data[2] <= CHAR_R;
                output_data[3] <= CHAR_CR;
                output_req_n <= 0;

                state <= STATE_INPUT_COMMAND;
            end

            //
            // READ コマンド
            //
            STATE_READ:
            begin
                state <= STATE_READ_GET_ADDR;
            end

            STATE_READ_GET_ADDR:            // コマンドラインからアドレスを取得する
            begin
                if(index >= input_length) begin
                    // アドレスが指定されていないのでエラー
                    state <= STATE_ERROR;
                end
                else begin
                    // アドレスを取得
                    hex_conv_start <= index;
                    hex_conv_req_n <= 0;
                    state <= STATE_READ_GOT_ADDR;
                end
            end

            STATE_READ_GOT_ADDR:            // アドレスを取得した
            begin
                // アドレスを格納
                bus_addr <= hex_conv_value;
                index <= hex_conv_index;

                state <= STATE_READ_GET_LEN;
            end

            STATE_READ_GET_LEN:             // コマンドラインから長さを取得する
            begin
                if(index >= input_length) begin
                    // 長さが指定されていない場合は 1 とする
                    remain <= 1'd1;

                    // 残数チェックへ進む
                    state <= STATE_READ_CHECK_REMAIN;
                end
                else begin
                    // 長さを取得
                    hex_conv_start <= index;
                    hex_conv_req_n <= 0;
                    state <= STATE_READ_GOT_LEN;
                end
            end

            STATE_READ_GOT_LEN:             // 長さを取得した
            begin
                // 長さを格納
                remain <= hex_conv_value[15:0];

                // 残数チェックへ進む
                state <= STATE_READ_CHECK_REMAIN;
            end

            STATE_READ_CHECK_REMAIN:        // 残数をチェック
            begin
                if(remain == 0) begin
                    // READ コマンド完了へ進む
                    state <= STATE_READ_COMPLETE;
                end
                else begin
                    // データ取得へ進む
                    state <= STATE_READ_GET_DATA;
                end
            end

            STATE_READ_GET_DATA:            // バス等からデータを取得
            begin
                // バスからデータを取得する
                bus_req_n <= 0;
                state <= STATE_READ_GOT_DATA;
            end

            STATE_READ_GOT_DATA:            // データを取得した
            begin
                // 残数減らす
                remain <= remain - 1'd1;
                
                // アドレス増やす
                if(bus_type != TYPE_IO_READ) begin
                    bus_addr <= bus_addr + 1'd1;
                end

                // 取得したデータを UART へ出力
                output_type <= 2'd1;
                output_length <= 1'd1;
                output_data[0] <= bus_dout;
                output_req_n <= 0;

                // 残数チェックへ戻る
                state <= STATE_READ_CHECK_REMAIN;
            end

            STATE_READ_COMPLETE:           // READ コマンドの完了
            begin
                // UART へ \r を出力
                output_type <= 2'd0;
                output_length <= 3'd4;
                output_data[0] <= CHAR_CR;
                output_data[1] <= CHAR_O;
                output_data[2] <= CHAR_K;
                output_data[3] <= CHAR_CR;
                output_req_n <= 0;

                state <= STATE_INPUT_COMMAND;
            end

            //
            // WRITE コマンド
            //
            STATE_WRITE:
            begin
                state <= STATE_WRITE_GET_ADDR;
            end

            STATE_WRITE_GET_ADDR:       // コマンドラインからアドレスを取得する
            begin
                if(index >= input_length) begin
                    // アドレスが指定されていないのでエラー
                    state <= STATE_ERROR;
                end
                else begin
                    // アドレスを取得
                    hex_conv_start <= index;
                    hex_conv_req_n <= 0;
                    state <= STATE_WRITE_GOT_ADDR;
                end
            end

            STATE_WRITE_GOT_ADDR:       // アドレスを取得した
            begin
                // アドレスを格納
                bus_addr <= hex_conv_value;
                index <= hex_conv_index;

                // 残数チェックに進む
                state <= STATE_WRITE_CHECK_REMAIN;
            end

            STATE_WRITE_CHECK_REMAIN:   // コマンドラインの残りデータをチェック
            begin
                if(index >= input_length) begin
                    // WRITE コマンド完了
                    state <= STATE_WRITE_COMPLETE;
                end
                else begin
                    // データを取得へ進む
                    state <= STATE_WRITE_GET_DATA;
                end
            end

            STATE_WRITE_GET_DATA:       // コマンドラインから書き込むデータを取得
            begin
                // データを取得
                hex_conv_start <= index;
                hex_conv_req_n <= 0;
                state <= STATE_WRITE_GOT_DATA;
            end

            STATE_WRITE_GOT_DATA:       // データを取得したので、バスなどに書き込む
            begin
                // コマンドライン位置を保存
                index <= hex_conv_index;

                // バスに書き込む
                bus_din <= hex_conv_value[7:0];
                bus_req_n <= 0;

                // 次の準備へ進む
                state <= STATE_WRITE_NEXT;
            end

            STATE_WRITE_NEXT:           // 次の準備
            begin
                // アドレスを増やす
                if(bus_type != TYPE_IO_WRITE) begin
                    bus_addr <= bus_addr + 1'd1;
                end

                // 残数チェックに戻る
                state <= STATE_WRITE_CHECK_REMAIN;
            end

            STATE_WRITE_COMPLETE,       // WRITE コマンドの完了
            STATE_RESET_COMPLETE:       // RESET コマンドの完了
            begin
                // UART へ OK\r を出力
                output_type <= 2'd0;
                output_length <= 3'd3;
                output_data[0] <= CHAR_O;
                output_data[1] <= CHAR_K;
                output_data[2] <= CHAR_CR;
                output_req_n <= 0;

                state <= STATE_INPUT_COMMAND;
            end

            //
            //
            //
            STATE_RESET:
            begin
                bus_req_n <= 0;
                state <= STATE_RESET_COMPLETE;
            end
        endcase
    end
endmodule




module DEBUGGER_BUS_OP (
    input wire          CLK,
    input wire          RESET_n,

    BUS_IF.CARTRIDGE    IN,         // 上位側バス
    BUS_IF.MSX          OUT,        // 下位側バス
    output reg          RESET_OUT_n,

    input wire [31:0]   ADDR,       // アドレスを取得
    input wire [7:0]    DIN,        // 書き込みデータ
    output reg [7:0]    DOUT,       // 読み込んだデータ
    input wire [3:0]    TYPE,       // 操作タイプ
    input wire          REQ_n,      // リクエスト
    output reg          ACK_n       // REQ_n に対する応答
);

    /***************************************************************
     * バスクロックのエッジ検出用
     ***************************************************************/
    reg prev_clk_bus;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_clk_bus <= 0;
        else prev_clk_bus <= IN.CLK;
    end

    /***************************************************************
     * バス操作
     ***************************************************************/
    enum logic[3:0] {
        STATE_IDLE,
        STATE_CHECK_BUS,
        STATE_SET_RD,
        STATE_SET_SLTSL,
        STATE_SET_CS,
        STATE_SET_DIN,
        STATE_SET_WR,
        STATE_CHECK_WAIT,

        STATE_BUS_RESET_SET,
        STATE_BUS_RESET_CLEAR,

        STATE_COMPLETE
    } state;

    reg         bus_sw;         // バススイッチ(0=上位と下位を接続 / 1=下位側をこのモジュールに接続)
    reg         op_wait_n;
    reg         op_rd_n;        
    reg         op_wr_n;
    reg [7:0]   op_din;
    reg [15:0]  op_addr;
    reg         op_merq_n;
    reg         op_iorq_n;
    reg         op_cs1_n;
    reg         op_cs2_n;
    reg         op_cs12_n;
    reg         op_sltsl_n;
    reg         op_brst_n;

    assign OUT.ADDR        = bus_sw ? op_addr    : IN.ADDR;
    assign OUT.DIN         = bus_sw ? op_din     : IN.DIN;
    assign OUT.RFSH_n      = bus_sw ? 1'b1       : IN.RFSH_n;
    assign OUT.RD_n        = bus_sw ? op_rd_n    : IN.RD_n;
    assign OUT.WR_n        = bus_sw ? op_wr_n    : IN.WR_n;
    assign OUT.MERQ_n      = bus_sw ? op_merq_n  : IN.MERQ_n;
    assign OUT.IORQ_n      = bus_sw ? op_iorq_n  : IN.IORQ_n;
    assign OUT.CS1_n       = bus_sw ? op_cs1_n   : IN.CS1_n;
    assign OUT.CS2_n       = bus_sw ? op_cs2_n   : IN.CS2_n;
    assign OUT.CS12_n      = bus_sw ? op_cs12_n  : IN.CS12_n;
    assign OUT.M1_n        = IN.M1_n;
    assign OUT.SLTSL_n     = bus_sw ? op_sltsl_n : IN.SLTSL_n;
    assign OUT.RESET_n     = IN.RESET_n && op_brst_n;
    assign OUT.CLK         = IN.CLK;
    assign OUT.CLK_EN      = IN.CLK_EN;
    assign OUT.CLK_21M     = IN.CLK_21M;
    assign OUT.CLK_EN_21M  = IN.CLK_EN_21M;
    assign IN.DOUT         = bus_sw ? 8'hFF      : OUT.DOUT;
    assign IN.BUSDIR_n     = bus_sw ? 1'b1       : OUT.BUSDIR_n;
    assign IN.INT_n        = bus_sw ? 1'b1       : OUT.INT_n;
    assign IN.WAIT_n       = op_wait_n && OUT.WAIT_n;

//    assign op_cs1_n = (op_addr[15:14] != 2'b01) || op_merq_n || op_rd_n;
//    assign op_cs2_n = (op_addr[15:14] != 2'b10) || op_merq_n || op_rd_n;
//    assign op_cs12_n = !(op_addr[15] ^ op_addr[14]) || op_merq_n || op_rd_n;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            state <= STATE_IDLE;
            bus_sw <= 0;
            op_wait_n <= 1;
            op_addr <= 0;
            op_din <= 0;
            op_rd_n <= 1;
            op_wr_n <= 1;
            op_merq_n <= 1;
            op_iorq_n <= 1;
            op_sltsl_n <= 1;
            op_brst_n <= 1;
            RESET_OUT_n <= 1;
            DOUT <= 0;
            ACK_n <= 1;
        end
        else case (state)
            //
            // REQ_n が 0 になるまで待つ
            //
            STATE_IDLE:
            begin
                if(!REQ_n && TYPE == TYPE_BUS_RESET) begin
                    state <= STATE_BUS_RESET_SET;
                    ACK_n <= 0;
                end
                else if(!REQ_n && TYPE == TYPE_SYS_RESET) begin
                    state <= STATE_BUS_RESET_SET;
                    ACK_n <= 0;
                end
                else if(!REQ_n) begin
                    state <= STATE_CHECK_BUS;
                    ACK_n <= 0;

                    op_addr <= ADDR[15:0];
                    op_merq_n <= !((TYPE == TYPE_MEMORY_READ) || (TYPE == TYPE_MEMORY_WRITE));
                    op_iorq_n <= !((TYPE == TYPE_IO_READ) || (TYPE == TYPE_IO_WRITE));

                    op_cs1_n <= 1;
                    op_cs2_n <= 1;
                    op_cs12_n <= 1;
                    op_rd_n <= 1;
                    op_sltsl_n <= 1;
                    op_wr_n <= 1;
                end
            end

            //
            // 上位が RD, WR, RFSH、下位側が WAIT 中は待つ
            //
            STATE_CHECK_BUS:
            begin
                if((prev_clk_bus != IN.CLK) && OUT.WAIT_n && IN.RD_n && IN.WR_n && IN.RFSH_n) begin
                    op_wait_n <= 0;
                    bus_sw <= 1;
                    state <= STATE_SET_RD;
                end
            end

            //
            // RD
            //
            STATE_SET_RD:
            begin
                op_rd_n <= !((TYPE == TYPE_MEMORY_READ) || (TYPE == TYPE_IO_READ));
                state <= STATE_SET_SLTSL;
            end

            //
            // SLTSL
            //
            STATE_SET_SLTSL:
            begin
                op_sltsl_n <= !((TYPE == TYPE_MEMORY_READ) || (TYPE == TYPE_MEMORY_WRITE));
                state <= STATE_SET_CS;
            end

            //
            // CS
            //
            STATE_SET_CS:
            begin
                op_cs1_n <= (op_addr[15:14] != 2'b01) || op_merq_n || op_rd_n;
                op_cs2_n <= (op_addr[15:14] != 2'b10) || op_merq_n || op_rd_n;
                op_cs12_n <= !(op_addr[15] ^ op_addr[14]) || op_merq_n || op_rd_n;
                state <= STATE_SET_DIN;
            end

            //
            // DIN
            //
            STATE_SET_DIN:
            begin
                op_din <= DIN;
                state <= STATE_SET_WR;
            end

            //
            // WR
            //
            STATE_SET_WR:
            begin
                if(!prev_clk_bus && IN.CLK) begin
                    op_wr_n <= !((TYPE == TYPE_MEMORY_WRITE) || (TYPE == TYPE_IO_WRITE));
                    state <= STATE_CHECK_WAIT;
                end
            end

            //
            // 下位側が WAIT なら待つ
            //
            STATE_CHECK_WAIT:
            begin
                if(!prev_clk_bus && IN.CLK && OUT.WAIT_n) begin
                    bus_sw <= 0;
                    op_wait_n <= 1;
                    DOUT <= OUT.DOUT;
                    state <= STATE_COMPLETE;
                end
            end

            //
            // 処理が完了したので REQ_n が 1 になるまで待つ
            //
            STATE_COMPLETE:
            begin
                if(REQ_n) begin
                    ACK_n <= 1;
                    state <= STATE_IDLE;
                end
            end

            //
            // バスリセット
            //
            STATE_BUS_RESET_SET:
            begin
                if(IN.RD_n && IN.WR_n && IN.RFSH_n) begin
                    if(TYPE == TYPE_BUS_RESET) op_brst_n <= 0;
                    if(TYPE == TYPE_SYS_RESET) RESET_OUT_n <= 0;
                    state <= STATE_BUS_RESET_CLEAR;
                end
            end
            STATE_BUS_RESET_CLEAR:
            begin
                if(!prev_clk_bus && IN.CLK) begin
                    if(TYPE == TYPE_BUS_RESET) op_brst_n <= 1;
                    if(TYPE == TYPE_SYS_RESET) RESET_OUT_n <= 1;
                    state <= STATE_COMPLETE;
                end
            end
        endcase
    end

endmodule

`default_nettype wire
