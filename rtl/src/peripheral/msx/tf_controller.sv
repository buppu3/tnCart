//
// tf_controller.sv
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
 * TF コントロールモジュール
 ***********************************************************************/
module TF_CONTROLLER #(
    parameter           USE_WAIT_SIGNAL = 0
) (
    input wire          RESET_n,
    input wire          CLK,
    BUS_IF.CARTRIDGE    Bus,        // バス
    input wire          ENA_n,      // イネーブル信号
    SPI_IF.HOST         TF,         // TF
    LED_IF.HOST         Led         // LED
);
    /***************************************************************
     * リード/ライト
     ***************************************************************/
    logic   rd_n;
    logic   wr_n;
    always_comb begin
        rd_n = Bus.RD_n || Bus.SLTSL_n || Bus.MERQ_n || ENA_n;
        wr_n = Bus.WR_n || Bus.SLTSL_n || Bus.MERQ_n || ENA_n;
    end

    /***************************************************************
     * リード/ライト エッジ検出
     ***************************************************************/
    reg     prev_rd_n;
    reg     prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n)
    begin
        if(!RESET_n)
        begin
            prev_rd_n <= 1;
            prev_wr_n <= 1;
        end else begin
            prev_rd_n <= rd_n;
            prev_wr_n <= wr_n;
        end
    end

    logic   det_rd;
    logic   det_wr;
    always_comb begin
        det_rd = (prev_rd_n && !rd_n);
        det_wr = (prev_wr_n && !wr_n);
    end

    /***************************************************************
     * アドレスデコード(Bank40h,4000h～5FFFh)
     ***************************************************************/
    logic   cs_ctrl_bank_n;
    logic   cs_spi_n;
    logic   cs_sel_n;
    always_comb begin
        //
        cs_ctrl_bank_n = (Bus.ADDR[15:13] != 3'b010);

        // SPI 転送エリア 4000h~57FFh
        cs_spi_n = cs_ctrl_bank_n || (Bus.ADDR[12:11] == 2'b11);

        // ドライブ選択エリア 5800h~5FFFh
        cs_sel_n = cs_ctrl_bank_n || (Bus.ADDR[12:11] != 2'b11);
    end

    /***************************************************************
     * SPI 転送条件検出
     ***************************************************************/
    logic det_xfer;
    always_comb begin
        det_xfer = (!cs_spi_n) && (det_rd || det_wr) && (sel_drv == 0);
    end

    /***************************************************************
     * ドライブ切り替え条件検出
     ***************************************************************/
    logic det_sel;
    always_comb begin
        det_sel = (!cs_sel_n) && det_wr;
    end

    /***************************************************************
     * データバス出力制御
     ***************************************************************/
    wire busdir_n = rd_n || cs_ctrl_bank_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Bus.RESET_n) Bus.BUSDIR_n <= 1;
        else                         Bus.BUSDIR_n <= busdir_n;
    end

    /***************************************************************
     * ドライブ選択レジスタ処理
     ***************************************************************/
    logic   [7:0]   sel_drv;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n || !Bus.RESET_n) sel_drv <= 0;
        else if(det_sel)             sel_drv <= Bus.DIN;
        else                         sel_drv <= sel_drv;
    end

    /***************************************************************
     * SPI 転送レジスタ処理
     ***************************************************************/
    enum logic[1:0] {
        STATE_IDLE,     // 待機中
        STATE_WAIT_ACK, // 転送開始待ち
        STATE_WAIT_BUSY // 転送完了待ち
    } state;

    // state
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            state <= STATE_IDLE;
        else case (state)
            STATE_IDLE:         state <= (det_xfer) ? STATE_WAIT_ACK  : STATE_IDLE;
            STATE_WAIT_ACK:     state <= ( TF.BUSY) ? STATE_WAIT_BUSY : STATE_WAIT_ACK;
            STATE_WAIT_BUSY:    state <= (!TF.BUSY) ? STATE_IDLE      : STATE_WAIT_BUSY;
        endcase
    end

    // LED
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            Led.State <= Led.LED_STATE_OFF;
        else case (state)
            default:            Led.State <= Led.LED_STATE_ON;
            STATE_IDLE:         Led.State <= Led.LED_STATE_OFF;
        endcase
    end

    // DOUT
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            Bus.DOUT <= 0;
        else                    Bus.DOUT <= busdir_n ? 0 : (det_xfer ? TF.MISO[7:0] : miso);
    end

    // MISO
    logic [7:0] miso;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            miso <= 0;
        else case (state)
            default:            miso <= miso;
            STATE_IDLE:         miso <= det_xfer ? TF.MISO[7:0] : miso;
        endcase
    end

    // CS
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            TF.CS_n <= 1;
        else case (state)
            default:            TF.CS_n <= TF.CS_n;
            STATE_IDLE:         TF.CS_n <= det_xfer ? Bus.ADDR[12] : TF.CS_n;
        endcase
    end

    // MOSI
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            TF.MOSI <= 0;
        else                    TF.MOSI[$bits(TF.MOSI)-1:$bits(TF.MOSI)-8] <= Bus.WR_n ? 8'hFF : Bus.DIN;
    end

    // REQ
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            TF.REQ <= 0;
        else case (state)
            default:            TF.REQ <= 0;
            STATE_IDLE:         TF.REQ <= det_xfer;
            STATE_WAIT_ACK:     TF.REQ <= 1;
        endcase
    end

    // LEN
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)            TF.LEN <= 4'd8;
        else                    TF.LEN <= 4'd8;
    end

    /***************************************************************
     * INT
     ***************************************************************/
    always_comb begin
        Bus.INT_n = 1;
    end

    /***************************************************************
     * WAIT
     ***************************************************************/
    generate
        if(USE_WAIT_SIGNAL) begin
            always_comb begin
                Bus.WAIT_n = (state == STATE_IDLE);
            end
        end
        else begin
            always_comb begin
                Bus.WAIT_n = 1;
            end
        end
    endgenerate

endmodule

`default_nettype wire
