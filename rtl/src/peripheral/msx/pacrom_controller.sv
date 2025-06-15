//
// pacrom_controller.sv
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
 * PAC ROM コントローラ
 ***************************************************************/
module PACROM_CONTROLLER #(
    parameter               RAM_ADDR_BIOS = 0,
    parameter               RAM_ADDR_PAC = 0,
    parameter               COUNT = 1
) (
    input   wire            RESET_n,
    input   wire            CLK,
    BUS_IF.CARTRIDGE        Bus,
    RAM_IF.HOST             Ram,
    BUS_IF.MSX              ExtBus[0:COUNT-1],
    output wire             SramEnable
);
    localparam [15:0] BankRegAddr = 16'h7FFF;
    localparam [15:0] SramEnableRegAddr = 16'h5FFE;
    localparam [15:0] SramEnableValue = 16'h694D;

    /***************************************************************
     * external signal
     ***************************************************************/
    generate
        genvar num;
        for(num = 0; num < COUNT; num = num + 1) begin: extbus_loop
            always @(posedge CLK or negedge RESET_n) begin
                if(!RESET_n) begin
                    ExtBus[num].ADDR        <= 0;
                    ExtBus[num].DIN         <= 0;
                    ExtBus[num].RFSH_n      <= 1;
                    ExtBus[num].RD_n        <= 1;
                    ExtBus[num].WR_n        <= 1;
                    ExtBus[num].IORQ_n      <= 1;
                    ExtBus[num].SLTSL_n     <= 1;
                    ExtBus[num].RESET_n     <= 0;
                    ExtBus[num].CLK         <= 0;
                end
                else if(!Bus.RESET_n) begin
                    ExtBus[num].ADDR        <= 0;
                    ExtBus[num].DIN         <= 0;
                    ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                    ExtBus[num].RD_n        <= 1;
                    ExtBus[num].WR_n        <= 1;
                    ExtBus[num].IORQ_n      <= 1;
                    ExtBus[num].SLTSL_n     <= 1;
                    ExtBus[num].RESET_n     <= 0;
                    ExtBus[num].CLK         <= Bus.CLK;
                end
                else begin
                    ExtBus[num].ADDR        <= Bus.ADDR;
                    ExtBus[num].DIN         <= Bus.DIN;
                    ExtBus[num].RFSH_n      <= Bus.RFSH_n;
                    ExtBus[num].RD_n        <= Bus.RD_n;
                    ExtBus[num].WR_n        <= Bus.WR_n;
                    ExtBus[num].IORQ_n      <= Bus.IORQ_n;
                    ExtBus[num].SLTSL_n     <= Bus.SLTSL_n;
                    ExtBus[num].RESET_n     <= Bus.RESET_n;
                    ExtBus[num].CLK         <= Bus.CLK;
                end
            end
        end
    endgenerate

    /***************************************************************
     * INT / WAIT
     ***************************************************************/
    wire [COUNT-1:0] w_int_n_n;
    wire [COUNT-1:0] w_wait_n_n;
    generate
        genvar i;
        for(i = 0; i < COUNT; i = i + 1) begin: lp
            assign w_int_n_n[i]  = ~ExtBus[i].INT_n;
            assign w_wait_n_n[i] = ~ExtBus[i].WAIT_n;
        end
    endgenerate

    NOR_Nbits #(
        .COUNT(COUNT)
    ) u_nor_int (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_int_n_n),
        .OUT(Bus.INT_n)
    );

    NOR_Nbits #(
        .COUNT(COUNT)
    ) u_nor_wait (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_wait_n_n),
        .OUT(Bus.WAIT_n)
    );

    /***************************************************************
     * アドレスデコード(4000h~7FFFh)
     ***************************************************************/
    wire cs1_n  =  Bus.ADDR[15] || ~Bus.ADDR[14];

    /***************************************************************
     * アドレスデコード(SRAM)
     ***************************************************************/
    wire w_sram_sel = ff_sram_enable && (Bus.ADDR[15:13] == 2'b010);

    /***************************************************************
     * memory read / write strobe
     ***************************************************************/
    wire wr_n = Bus.SLTSL_n || Bus.WR_n;
    wire rd_n = Bus.SLTSL_n || Bus.RD_n;
    wire wr_mem_n  = cs1_n || wr_n || !w_sram_sel;
    wire rd_mem_n  = cs1_n || rd_n;

    /***************************************************************
     * ライト検出
     ***************************************************************/
    logic prev_wr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)          prev_wr_n <= 1;
        else if(!Bus.RESET_n) prev_wr_n <= 1;
        else                  prev_wr_n <= wr_n;
    end
    wire det_wr = prev_wr_n && !wr_n;

    /***************************************************************
     * rom bank register
     ***************************************************************/
    reg [1:0] ff_rom_bank;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ff_rom_bank <= 0;
        end
        else if(!Bus.RESET_n) begin
            ff_rom_bank <= 0;
        end
        else if(det_wr && (Bus.ADDR == BankRegAddr)) begin
            ff_rom_bank <= Bus.DIN[1:0];
        end
    end

    /***************************************************************
     * sram enable register
     ***************************************************************/
    reg [7:0] ff_sram_enable_reg[0:1];

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ff_sram_enable_reg[0] <= 0;
            ff_sram_enable_reg[1] <= 0;
        end
        else if(!Bus.RESET_n) begin
            ff_sram_enable_reg[0] <= 0;
            ff_sram_enable_reg[1] <= 0;
        end
        else if(det_wr && (Bus.ADDR[15:1] == SramEnableRegAddr[15:1])) begin
            ff_sram_enable_reg[Bus.ADDR[0]] <= Bus.DIN;
        end
    end

    reg ff_sram_enable;
    assign SramEnable = ff_sram_enable;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            ff_sram_enable <= 0;
        end
        else if(!Bus.RESET_n) begin
            ff_sram_enable <= 0;
        end
        else begin
            ff_sram_enable <= (ff_sram_enable_reg[0] == SramEnableValue[7:0]) && (ff_sram_enable_reg[1] == SramEnableValue[15:8]);
        end
    end

    /***************************************************************
     * アドレス計算
     ***************************************************************/
    wire [32:0] w_addr = w_sram_sel ? {RAM_ADDR_PAC[23:13], Bus.ADDR[12:0]} : {RAM_ADDR_BIOS[23:16], ff_rom_bank, Bus.ADDR[13:0]};

    /***************************************************************
     * memory r/w
     ***************************************************************/
    wire [COUNT:0] w_busdir_n_n;
    assign w_busdir_n_n[COUNT] = ~rd_mem_n;
    generate
        genvar busdir_i;
        for(busdir_i = 0; busdir_i < COUNT; busdir_i = busdir_i + 1) begin: busdir_lp
            assign w_busdir_n_n[busdir_i] = ~ExtBus[busdir_i].BUSDIR_n;
        end
    endgenerate

    NOR_Nbits #(
        .COUNT(COUNT+1)
    ) u_nor_busdir (
        .RESET_n,
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_busdir_n_n),
        .OUT(Bus.BUSDIR_n)
    );

    wire [7:0] w_dout[0:COUNT];
    assign w_dout[COUNT] = Ram.DOUT[7:0];
    generate
        genvar dout_i;
        for(dout_i = 0; dout_i < COUNT; dout_i = dout_i + 1) begin: dout_lp
            assign w_dout[dout_i] = ExtBus[dout_i].DOUT;
        end
    endgenerate

    ARRAY_SELECTOR #(
        .WIDTH(8),
        .COUNT(COUNT+1)
    ) u_select_dout (
        .RESET_n(RESET_n & Bus.RESET_n),
        .CLK(CLK),
        .ENA(1'b1),
        .IN(w_dout),
        .OE(w_busdir_n_n),
        .OUT(Bus.DOUT)
    );

    assign Ram.DSIZE = RAM::DSIZE_8;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Ram.ADDR <= 0;
            Ram.WE_n <= 1;
            Ram.DIN <= 0;
            //Ram.DSIZE <= RAM::DSIZE_8;
            Ram.OE_n <= 1;
            Ram.RFSH_n <= 1;
        end
        else if(!Bus.RESET_n) begin
            Ram.ADDR <= 0;
            Ram.WE_n <= 1;
            Ram.DIN <= 0;
            //Ram.DSIZE <= RAM::DSIZE_8;
            Ram.OE_n <= 1;
            Ram.RFSH_n <= Bus.RFSH_n;
        end
        else begin
            // address
            Ram.ADDR <= w_addr[$bits(Ram.ADDR)-1:0];

            // memory write
            Ram.WE_n <= wr_mem_n;
            Ram.DIN <= Bus.DIN;
            //Ram.DSIZE <= RAM::DSIZE_8;

            // memory read
            Ram.OE_n <= rd_mem_n;

            // memory refresh
            Ram.RFSH_n <= Bus.RFSH_n;
        end
    end
endmodule


`default_nettype wire
