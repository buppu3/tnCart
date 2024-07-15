//
// debugger_bus_sim.sv
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
 * 
 ***************************************************************/
module DEBUGGER_BUS_SIM (
    input wire              RESET_n,
    input wire              CLK,
    input wire              CLK_21M,
    input wire              CLK_14M,
    BUS_IF.MSX              Bus
);

    /***************************************************************
     * リセット
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.RESET_n <= 0;
        end
        else begin
            Bus.RESET_n <= 1;
        end
    end

    /***************************************************************
     * クロック生成
     ***************************************************************/
    wire clk_rise = (div_cnt == DIV - 1);
    wire clk_fall = (div_cnt == DIV / 2 - 1);
    wire clk_edge = clk_rise || clk_fall;

    localparam DIV = 30;
    logic [$clog2(DIV+1)-1:0] div_cnt;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            div_cnt <= DIV - 1;
            Bus.CLK <= 0;
            Bus.CLK_EN <= 0;
        end
        else if(clk_rise) begin
            div_cnt <= 0;
            Bus.CLK <= 1;
            Bus.CLK_EN <= 1;
        end
        else if(clk_fall) begin
            div_cnt <= div_cnt + 1'd1;
            Bus.CLK <= 0;
            Bus.CLK_EN <= 0;
        end
        else begin
            div_cnt <= div_cnt + 1'd1;
            Bus.CLK <= Bus.CLK;
            Bus.CLK_EN <= 0;
        end
    end

    /***************************************************************
     * CLK_EN_21M
     ***************************************************************/
    logic prev_clk_21m;
    always_ff @(posedge CLK_21M or negedge RESET_n) begin
        if(!RESET_n)    prev_clk_21m <= 0;
        else            prev_clk_21m <= Bus.CLK;
    end

    assign Bus.CLK_21M = CLK_21M;
    assign Bus.CLK_EN_21M = Bus.CLK && !prev_clk_21m;

    /***************************************************************
     * CLK_14M
     ***************************************************************/
    assign Bus.CLK_14M = CLK_14M;

    /***************************************************************
     * 遷移状態
     ***************************************************************/
    enum logic[3:0] {
        STATE_T1_0,
        STATE_T1_1,
        STATE_T2_0,
        STATE_T2_1,
        STATE_T3_0,
        STATE_T3_1,
        STATE_T4_0,
        STATE_T4_1
    } state;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            state <= STATE_T4_1;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: state <= STATE_T1_0;
                STATE_T1_0: state <= STATE_T1_1;
                STATE_T1_1: state <= STATE_T2_0;
                STATE_T2_0: state <= Bus.WAIT_n ? STATE_T2_1 : STATE_T2_0;
                STATE_T2_1: state <= STATE_T3_0;
                STATE_T3_0: state <= STATE_T3_1;
                STATE_T3_1: state <= STATE_T4_0;
                STATE_T4_0: state <= STATE_T4_1;
            endcase
        end 
    end

    /***************************************************************
     * ADDR
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.ADDR <= 0;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: Bus.ADDR <= addr_pc;    // T1-0
                STATE_T1_0: Bus.ADDR <= addr_pc;    // T1-1
                STATE_T1_1: Bus.ADDR <= addr_pc;    // T2-0
                STATE_T2_0: Bus.ADDR <= addr_pc;    // T2-1
                STATE_T2_1: Bus.ADDR <= { 8'b0, 1'b0, addr_rfsh};  // T3-0
                STATE_T3_0: Bus.ADDR <= { 8'b0, 1'b0, addr_rfsh};  // T3-1
                STATE_T3_1: Bus.ADDR <= { 8'b0, 1'b0, addr_rfsh};  // T4-0
                STATE_T4_0: Bus.ADDR <= { 8'b0, 1'b0, addr_rfsh};  // T4-1
            endcase
        end 
    end

    /***************************************************************
     * PC
     ***************************************************************/
    logic [15:0] addr_pc;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            addr_pc <= 0;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T2_1: addr_pc <= addr_pc + 1'd1;
            endcase
        end 
    end

    /***************************************************************
     * R
     ***************************************************************/
    logic [7:0] addr_rfsh;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            addr_rfsh <= 0;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: addr_rfsh <= addr_rfsh + 1'd1;
            endcase
        end 
    end

    /***************************************************************
     * MERQ
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.MERQ_n <= 1;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: Bus.MERQ_n <= 1;  // T1-0
                STATE_T1_0: Bus.MERQ_n <= 0;  // T1-1
                STATE_T1_1: Bus.MERQ_n <= 0;  // T2-0
                STATE_T2_0: Bus.MERQ_n <= 0;  // T2-1
                STATE_T2_1: Bus.MERQ_n <= 1;  // T3-0
                STATE_T3_0: Bus.MERQ_n <= 0;  // T3-1
                STATE_T3_1: Bus.MERQ_n <= 0;  // T4-0
                STATE_T4_0: Bus.MERQ_n <= 1;  // T4-1
            endcase
        end 
    end

    /***************************************************************
     * IORQ
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.IORQ_n <= 1;
        end
        else if(clk_edge) begin
            Bus.IORQ_n <= 1;
        end 
    end

    /***************************************************************
     * RD
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.RD_n <= 1;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: Bus.RD_n <= 1;  // T1-0
                STATE_T1_0: Bus.RD_n <= 0;  // T1-1
                STATE_T1_1: Bus.RD_n <= 0;  // T2-0
                STATE_T2_0: Bus.RD_n <= 0;  // T2-1
                STATE_T2_1: Bus.RD_n <= 1;  // T3-0
                STATE_T3_0: Bus.RD_n <= 1;  // T3-1
                STATE_T3_1: Bus.RD_n <= 1;  // T4-0
                STATE_T4_0: Bus.RD_n <= 1;  // T4-1
            endcase
        end 
    end

    /***************************************************************
     * WR
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.WR_n <= 1;
        end
        else if(clk_edge) begin
            Bus.WR_n <= 1;
        end 
    end

    /***************************************************************
     * M1
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.M1_n <= 1;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: Bus.M1_n <= 0;  // T1-0
                STATE_T1_0: Bus.M1_n <= 0;  // T1-1
                STATE_T1_1: Bus.M1_n <= 0;  // T2-0
                STATE_T2_0: Bus.M1_n <= 0;  // T2-1
                STATE_T2_1: Bus.M1_n <= 1;  // T3-0
                STATE_T3_0: Bus.M1_n <= 1;  // T3-1
                STATE_T3_1: Bus.M1_n <= 1;  // T4-0
                STATE_T4_0: Bus.M1_n <= 1;  // T4-1
            endcase
        end 
    end

    /***************************************************************
     * RFSH
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.RFSH_n <= 1;
        end
        else if(clk_edge) begin
            case(state)
                STATE_T4_1: Bus.RFSH_n <= 1;  // T1-0
                STATE_T1_0: Bus.RFSH_n <= 1;  // T1-1
                STATE_T1_1: Bus.RFSH_n <= 1;  // T2-0
                STATE_T2_0: Bus.RFSH_n <= 1;  // T2-1
                STATE_T2_1: Bus.RFSH_n <= 0;  // T3-0
                STATE_T3_0: Bus.RFSH_n <= 0;  // T3-1
                STATE_T3_1: Bus.RFSH_n <= 0;  // T4-0
                STATE_T4_0: Bus.RFSH_n <= 0;  // T4-1
            endcase
        end 
    end

    /***************************************************************
     * DIN
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.DIN <= 0;
        end
        else if(clk_edge) begin
            Bus.DIN <= 0;
        end
    end

    /***************************************************************
     * CS1
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.CS1_n <= 1;
        end
        else begin
            Bus.CS1_n <= Bus.ADDR[15:4] != 2'b01;
        end
    end

    /***************************************************************
     * CS2
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.CS2_n <= 1;
        end
        else begin
            Bus.CS2_n <= Bus.ADDR[15:4] != 2'b10;
        end
    end

    /***************************************************************
     * CS12
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.CS12_n <= 1;
        end
        else begin
            Bus.CS12_n <= (Bus.ADDR[15:4] != 2'b10) && (Bus.ADDR[15:4] != 2'b01);
        end
    end

    /***************************************************************
     * SLTSL
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            Bus.SLTSL_n <= 1;
        end
        else begin
            Bus.SLTSL_n <= 1;
        end
    end

endmodule

`default_nettype wire
