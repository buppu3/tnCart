module IKASCC_player_s #(
    parameter RAM_TYPE = 1,
    parameter FAST_CLOCK = 0,
    parameter RAMCTRL_ASYNC = 0 //depends on the TC22SC characteristics
) (
    input   wire            i_EMUCLK,
    input   wire            i_MCLK_PCEN_n,
    input   wire            i_RST_n,

    input   wire            i_SCCREG_EN,
    input   wire            i_CS_n, i_RD_n, i_WR_n,
    input   wire            i_RDRQ, i_WRRQ,
    input   wire    [7:0]   i_ABLO,
    input   wire    [7:0]   i_DB,
    output  reg     [7:0]   o_DB,

    output  reg             o_TEST,

    output  reg signed      [10:0]  o_SOUND
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            mclkpcen_n = i_MCLK_PCEN_n;
wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  Test register
////

reg     [7:0]   db_z;
wire            test_wr = i_WRRQ & i_SCCREG_EN & (i_ABLO[7:5] == 3'b111);
reg     [7:0]   test;
always @(posedge emuclk) begin
    if(!rst_n) test <= 8'h00;
    else begin if(!mclkpcen_n) begin
        db_z <= i_DB;
        if(test_wr) test <= db_z;
    end end
end

wire    [4:0]   fraccntr_ld_n;
wire    [1:0]   ch45_ram_addrsel;
always @(*) begin
    case(test[4:2])
        3'd0: o_TEST = fraccntr_ld_n[0];
        3'd1: o_TEST = fraccntr_ld_n[1];
        3'd2: o_TEST = fraccntr_ld_n[2];
        3'd3: o_TEST = fraccntr_ld_n[3];
        3'd4: o_TEST = fraccntr_ld_n[4];
        3'd5: o_TEST = ch45_ram_addrsel[0];
        3'd6: o_TEST = ch45_ram_addrsel[1];
        3'd7: o_TEST = 1'b0;
    endcase
end


///////////////////////////////////////////////////////////
//////  Sound summer
////

wire signed     [7:0]   ch1_sound, ch2_sound, ch3_sound, ch4_sound, ch5_sound;
always @(posedge emuclk) begin
    if(!rst_n) o_SOUND <= 11'h000;
    else begin if(!mclkpcen_n) begin
        o_SOUND <= ch1_sound + ch2_sound + ch3_sound + ch4_sound + ch5_sound;
    end end
end



///////////////////////////////////////////////////////////
//////  Channel 1
////

wire            ch1_ram_rdrq, ch1_ram_wrrq;
wire    [4:0]   ch1_ram_addr_cntr, ch1_ram_addr_cpu;
wire    [4:0]   ch1_ram_addr = ch1_ram_rdrq ? ch1_ram_addr_cpu : ch1_ram_addr_cntr;
wire    [7:0]   ch1_ram_d, ch1_ram_q;

IKASCC_player_memory_s #(.RAM_TYPE(RAM_TYPE), .INITFILE()) u_mem_ch1 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),

    .i_RAM_WRRQ                 (ch1_ram_wrrq & ~test[6]    ),
    .i_RAM_ADDR                 (ch1_ram_addr               ),
    .i_RAM_D                    (ch1_ram_d                  ),
    .o_RAM_Q                    (ch1_ram_q                  )
);

IKASCC_player_control_s #(
    .RAMCTRL_ASYNC              (RAMCTRL_ASYNC              ), //depends on the TC22SC characteristics
    .ADDR_RAM_BASE              (8'h00                      ),
    .ADDR_FREQ_BASE             (8'h80                      ),
    .ADDR_VOL                   (8'h8A                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (0                          )
) u_ctrl_ch1 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n), .i_WR_n(i_WR_n),
    .i_RDRQ(i_RDRQ), .i_WRRQ(i_WRRQ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_RDRQ                 (ch1_ram_rdrq               ),
    .o_RAM_WRRQ                 (ch1_ram_wrrq               ),
    .o_RAM_ADDR_CNTR            (ch1_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (ch1_ram_addr_cpu           ),
    .o_RAM_D                    (ch1_ram_d                  ),
    .i_RAM_Q                    (ch1_ram_q                  ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[0]           ),

    .o_SOUND                    (ch1_sound                  )
);



///////////////////////////////////////////////////////////
//////  Channel 2
////

wire            ch2_ram_rdrq, ch2_ram_wrrq;
wire    [4:0]   ch2_ram_addr_cntr, ch2_ram_addr_cpu;
wire    [4:0]   ch2_ram_addr = ch2_ram_rdrq ? ch2_ram_addr_cpu : ch2_ram_addr_cntr;
wire    [7:0]   ch2_ram_d, ch2_ram_q;

IKASCC_player_memory_s #(.RAM_TYPE(RAM_TYPE), .INITFILE()) u_mem_ch2 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),

    .i_RAM_WRRQ                 (ch2_ram_wrrq & ~test[6]    ),
    .i_RAM_ADDR                 (ch2_ram_addr               ),
    .i_RAM_D                    (ch2_ram_d                  ),
    .o_RAM_Q                    (ch2_ram_q                  )
);

IKASCC_player_control_s #(
    .RAMCTRL_ASYNC              (RAMCTRL_ASYNC              ), //depends on the TC22SC characteristics
    .ADDR_RAM_BASE              (8'h20                      ),
    .ADDR_FREQ_BASE             (8'h82                      ),
    .ADDR_VOL                   (8'h8B                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (1                          )
) u_ctrl_ch2 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n), .i_WR_n(i_WR_n),
    .i_RDRQ(i_RDRQ), .i_WRRQ(i_WRRQ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_RDRQ                 (ch2_ram_rdrq               ),
    .o_RAM_WRRQ                 (ch2_ram_wrrq               ),
    .o_RAM_ADDR_CNTR            (ch2_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (ch2_ram_addr_cpu           ),
    .o_RAM_D                    (ch2_ram_d                  ),
    .i_RAM_Q                    (ch2_ram_q                  ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[1]           ),

    .o_SOUND                    (ch2_sound                  )
);



///////////////////////////////////////////////////////////
//////  Channel 3
////

wire            ch3_ram_rdrq, ch3_ram_wrrq;
wire    [4:0]   ch3_ram_addr_cntr, ch3_ram_addr_cpu;
wire    [4:0]   ch3_ram_addr = ch3_ram_rdrq ? ch3_ram_addr_cpu : ch3_ram_addr_cntr;
wire    [7:0]   ch3_ram_d, ch3_ram_q;

IKASCC_player_memory_s #(.RAM_TYPE(RAM_TYPE), .INITFILE()) u_mem_ch3 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),

    .i_RAM_WRRQ                 (ch3_ram_wrrq & ~test[6]    ),
    .i_RAM_ADDR                 (ch3_ram_addr               ),
    .i_RAM_D                    (ch3_ram_d                  ),
    .o_RAM_Q                    (ch3_ram_q                  )
);

IKASCC_player_control_s #(
    .RAMCTRL_ASYNC              (RAMCTRL_ASYNC              ), //depends on the TC22SC characteristics
    .ADDR_RAM_BASE              (8'h40                      ),
    .ADDR_FREQ_BASE             (8'h84                      ),
    .ADDR_VOL                   (8'h8C                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (2                          )
) u_ctrl_ch3 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n), .i_WR_n(i_WR_n),
    .i_RDRQ(i_RDRQ), .i_WRRQ(i_WRRQ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_RDRQ                 (ch3_ram_rdrq               ),
    .o_RAM_WRRQ                 (ch3_ram_wrrq               ),
    .o_RAM_ADDR_CNTR            (ch3_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (ch3_ram_addr_cpu           ),
    .o_RAM_D                    (ch3_ram_d                  ),
    .i_RAM_Q                    (ch3_ram_q                  ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[2]           ),

    .o_SOUND                    (ch3_sound                  )
);



///////////////////////////////////////////////////////////
//////  Channel 4 and 5
////

//time-division timing generator
reg     [2:0]   ch45_cntr;
reg     [1:0]   ch45_sr;
wire            ch4_wavelatch_tick_pcen = ch45_cntr == 3'd0 && ch45_sr == 2'b00;
wire            ch5_wavelatch_tick_pcen = ch45_cntr == 3'd0 && ch45_sr == 2'b11;
always @(posedge emuclk) begin
    if(!rst_n) begin
        ch45_cntr <= 3'd0;
        ch45_sr <= 2'b00;
    end
    else begin if(!mclkpcen_n) begin
        ch45_cntr <= ch45_cntr == 3'd0 ? 3'd7 : ch45_cntr - 3'd1;

        if(ch45_cntr == 3'd0) begin
            ch45_sr[0] <= ~ch45_sr[1];
            ch45_sr[1] <= ch45_sr[0];
        end
    end end
end

//ram r/w control and address/data
wire            ch45_ram_rdrq, ch45_ram_wrrq;
assign  ch45_ram_addrsel[1] = ((~ch45_sr[1] & ~ch45_ram_rdrq) | test[7]) & ~test[7];
assign  ch45_ram_addrsel[0] = (( ch45_sr[1] & ~ch45_ram_rdrq) | test[6]) & ~test[6];
wire    [4:0]   ch4_ram_addr_cntr, ch5_ram_addr_cntr, ch45_ram_addr_cpu;
reg     [4:0]   ch45_ram_addr;
always @(*) begin
    case(ch45_ram_addrsel)
        2'd0: ch45_ram_addr = ch45_ram_addr_cpu;
        2'd1: ch45_ram_addr = ch5_ram_addr_cntr;
        2'd2: ch45_ram_addr = ch4_ram_addr_cntr;
        2'd3: ch45_ram_addr = 5'd31;
    endcase
end
wire    [7:0]   ch45_ram_d, ch45_ram_q;

//wave data latch
reg     [7:0]   ch4_wavelatch, ch5_wavelatch;
always @(posedge emuclk) if(!mclkpcen_n) begin
    if(ch4_wavelatch_tick_pcen) ch4_wavelatch <= ch45_ram_q;
    if(ch5_wavelatch_tick_pcen) ch5_wavelatch <= ch45_ram_q;
end

IKASCC_player_memory_s #(.RAM_TYPE(RAM_TYPE), .INITFILE()) u_mem_ch45 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),

    .i_RAM_WRRQ                 (ch45_ram_wrrq & ~test[6] & ~test[7]),
    .i_RAM_ADDR                 (ch45_ram_addr               ),
    .i_RAM_D                    (ch45_ram_d                  ),
    .o_RAM_Q                    (ch45_ram_q                  )
);

IKASCC_player_control_s #(
    .RAMCTRL_ASYNC              (RAMCTRL_ASYNC              ), //depends on the TC22SC characteristics
    .ADDR_RAM_BASE              (8'h60                      ),
    .ADDR_FREQ_BASE             (8'h86                      ),
    .ADDR_VOL                   (8'h8D                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (3                          )
) u_ctrl_ch4 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n), .i_WR_n(i_WR_n),
    .i_RDRQ(i_RDRQ), .i_WRRQ(i_WRRQ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_RDRQ                 (ch45_ram_rdrq              ),
    .o_RAM_WRRQ                 (ch45_ram_wrrq              ),
    .o_RAM_ADDR_CNTR            (ch4_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (ch45_ram_addr_cpu          ),
    .o_RAM_D                    (ch45_ram_d                 ),
    .i_RAM_Q                    (ch4_wavelatch              ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[3]           ),

    .o_SOUND                    (ch4_sound                  )
);

IKASCC_player_control_s #(
    .RAMCTRL_ASYNC              (RAMCTRL_ASYNC              ), //depends on the TC22SC characteristics
    .ADDR_RAM_BASE              (8'h60                      ),
    .ADDR_FREQ_BASE             (8'h88                      ),
    .ADDR_VOL                   (8'h8E                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (4                          )
) u_ctrl_ch5 (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n), .i_WR_n(i_WR_n),
    .i_RDRQ(i_RDRQ), .i_WRRQ(i_WRRQ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_RDRQ                 (                           ),
    .o_RAM_WRRQ                 (                           ),
    .o_RAM_ADDR_CNTR            (ch5_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (                           ),
    .o_RAM_D                    (                           ),
    .i_RAM_Q                    (ch5_wavelatch              ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[4]           ),

    .o_SOUND                    (ch5_sound                  )
);



///////////////////////////////////////////////////////////
//////  BUS SELECTOR
////

always @(*) begin
    o_DB = 8'h00;

         if(ch1_ram_rdrq) o_DB = ch1_ram_q;
    else if(ch2_ram_rdrq) o_DB = ch2_ram_q;
    else if(ch3_ram_rdrq) o_DB = ch3_ram_q;
    else if(ch45_ram_rdrq) o_DB = ch45_ram_q;
end

endmodule



module IKASCC_player_control_s #(
    parameter RAMCTRL_ASYNC = 0, //depends on the TC22SC characteristics
    parameter ADDR_RAM_BASE  = 8'h00,
    parameter ADDR_FREQ_BASE = 8'h00,
    parameter ADDR_VOL  = 8'h00,
    parameter ADDR_MUTE = 8'h00,
    parameter BIT_MUTE = 0
    ) (
    input   wire            i_EMUCLK,
    input   wire            i_MCLK_PCEN_n,
    input   wire            i_RST_n,

    input   wire            i_SCCREG_EN,
    input   wire            i_CS_n, i_RD_n, i_WR_n,
    input   wire            i_RDRQ, i_WRRQ,
    input   wire    [7:0]   i_ABLO,
    input   wire    [7:0]   i_DB,
    input   wire    [7:0]   i_TEST,

    output  wire            o_RAM_RDRQ, o_RAM_WRRQ,
    output  wire    [4:0]   o_RAM_ADDR_CNTR, o_RAM_ADDR_CPU,
    output  wire    [7:0]   o_RAM_D,
    input   wire    [7:0]   i_RAM_Q,

    output  wire            o_FRACCNTR_LD_n,

    output  wire signed     [7:0]   o_SOUND
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            mclkpcen_n = i_MCLK_PCEN_n;
wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  SCC wavetable CPU R/W
////

//delay addr/data
reg     [7:0]   i_ABLO_Z, i_DB_Z;
wire    [7:0]   addr_lo, data;
always @(posedge emuclk) if(!mclkpcen_n) begin
    i_ABLO_Z <= i_ABLO;
    i_DB_Z <= i_DB;
end

//RAM read/write request
/*
    MODE DESCRIPTION

                       <---- 280ns ---->
    CPU clock   _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_____
    Slot clock  ¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯
                       |---> 80ns delayed
                                                         |-| <-- 40ns interval
    /WR         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    ram_wrrq    ___________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_________________________
                                        RAMCTRL_ASYNC      ^ <------ RAM WRITE TIMING
                                        RAMCTRL_SYNC                       ^ <----- RAM WRITE TIMING

    The rising edge of the clock comes 40 ns after the /WR of the MSX goes to zero. Given the advertised
    TC22SC's NAND2 tpd, the time for CPU data to occupy the RAM bus is about 10 ns after the falling edge
    of /WR. However, for some reason, the DFF sampling the RAM bus may not be able to sample "new" data
    from the CPU. At the time of writing this code, I don't know the exact behavior of the actual chip,
    so I added the parameter for adjustment.
*/

generate
if(RAMCTRL_ASYNC == 0) begin : ramctrl_sync
assign  addr_lo = i_ABLO_Z;
assign  data = i_DB_Z;
wire            ram_rdrq = i_RDRQ & i_SCCREG_EN & (addr_lo[7:5] == ADDR_RAM_BASE[7:5]);
wire            ram_wrrq = i_WRRQ & i_SCCREG_EN & (addr_lo[7:5] == ADDR_RAM_BASE[7:5]);
assign  o_RAM_RDRQ = ram_rdrq;
assign  o_RAM_WRRQ = ram_wrrq;

end
else begin : ramctrl_async
assign  addr_lo = i_ABLO;
assign  data = i_DB;
//wire            ram_rdrq = ~(i_CS_n | i_RD_n) & i_SCCREG_EN & (addr_lo[7:5] == ADDR_RAM_BASE[7:5]);
wire            ram_rdrq = ~(i_CS_n) & i_SCCREG_EN & (addr_lo[7:5] == ADDR_RAM_BASE[7:5]);
wire            ram_wrrq = ~(i_CS_n | i_WR_n) & i_SCCREG_EN & (addr_lo[7:5] == ADDR_RAM_BASE[7:5]);
assign  o_RAM_RDRQ = ram_rdrq;
assign  o_RAM_WRRQ = ram_wrrq;
end
endgenerate

assign  o_RAM_ADDR_CPU = addr_lo[4:0];
assign  o_RAM_D = data;



///////////////////////////////////////////////////////////
//////  Frequency register
////

wire    freq_lo_wr = i_WRRQ & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] ==  ADDR_FREQ_BASE[3:0]);
wire    freq_hi_wr = i_WRRQ & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] == (ADDR_FREQ_BASE[3:0] + 4'h1));
reg     [11:0]  freq;
always @(posedge emuclk) if(!mclkpcen_n) begin
    if(freq_lo_wr) freq[7:0] <= i_DB_Z;
    if(freq_hi_wr) freq[11:8] <= i_DB_Z[3:0];
end



///////////////////////////////////////////////////////////
//////  Counter
////

wire    intcntr_cnt, intcntr_set, fraccntr_ld;
assign  o_FRACCNTR_LD_n = ~fraccntr_ld;

wire    [3:0]   cyccntr;
IKASCC_primitive_dncntr #(.W(4)) u_cyccntr (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(mclkpcen_n),
    .i_SET(fraccntr_ld), .i_LD(1'b0), .i_CNT(1'b1),
    .i_D(4'hF), .o_Q(cyccntr), .o_BO()
);

wire    [3:0]   fraccntr_a;
wire            fraccntr_a_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_a (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(mclkpcen_n),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(1'b1),
    .i_D(freq_lo_wr ? i_DB_Z[3:0] : freq[3:0]), .o_Q(fraccntr_a), .o_BO(fraccntr_a_bo)
);

wire    [3:0]   fraccntr_b;
wire            fraccntr_b_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_b (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(mclkpcen_n),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(fraccntr_a_bo),
    .i_D(freq_lo_wr ? i_DB_Z[7:4] : freq[7:4]), .o_Q(fraccntr_b), .o_BO(fraccntr_b_bo)
);

wire            fraccntr_c_cnt = i_TEST[0] ? 1'b1 : fraccntr_a_bo & fraccntr_b_bo;
wire    [3:0]   fraccntr_c;
wire            fraccntr_c_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_c (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(mclkpcen_n),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(fraccntr_c_cnt),
    .i_D(freq_hi_wr ? i_DB_Z[3:0] : freq[11:8]), .o_Q(fraccntr_c), .o_BO(fraccntr_c_bo)
);

assign  intcntr_cnt = i_TEST[1] ? fraccntr_a_bo & fraccntr_b_bo : fraccntr_c_cnt & fraccntr_c_bo;

wire    [4:0]   intcntr;
IKASCC_primitive_dncntr #(.W(5)) u_intcntr (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(mclkpcen_n),
    .i_SET(intcntr_set | ~rst_n), .i_LD(1'b0), .i_CNT(intcntr_cnt),
    .i_D(5'd0), .o_Q(intcntr), .o_BO()
);

assign  o_RAM_ADDR_CNTR = ~intcntr;
wire    [11:0]  fraccntr = {fraccntr_c, fraccntr_b, fraccntr_a};



///////////////////////////////////////////////////////////
//////  Frequency dirty flag
////

wire            freq_changed;
assign  freq_changed = (~i_WR_n & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] ==  ADDR_FREQ_BASE[3:0])) |
                       (~i_WR_n & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] == (ADDR_FREQ_BASE[3:0] + 4'h1)));

reg             freq_changed_z;
always @(posedge emuclk) if(!mclkpcen_n) freq_changed_z <= freq_changed;

assign  fraccntr_ld = intcntr_cnt | (freq_changed | freq_changed_z); //emulates asynchronous set(will generated 1.5-cycle pulse)
assign  intcntr_set = i_TEST[5] & (freq_changed | freq_changed_z);



///////////////////////////////////////////////////////////
//////  Mute
////

wire            mute_wr = i_WRRQ & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_MUTE[7:5]) & (i_ABLO[3:0] ==  ADDR_MUTE[3:0]);
reg             mute;
always @(posedge emuclk) begin
    if(!i_RST_n) mute <= 1'b0;
    else begin if(!mclkpcen_n) begin
        if(mute_wr) mute <= i_DB_Z[BIT_MUTE];
    end end
end



///////////////////////////////////////////////////////////
//////  Serial multiplier
////

//multiplier re-set
wire            mul_rst = fraccntr_ld;
wire            mul_rst_pcen = intcntr_cnt | freq_lo_wr | freq_hi_wr; //positive edge enable of originally asynchronous mul_rst

//volume register
wire    vol_wr = i_WRRQ & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_VOL[7:5]) & (i_ABLO[3:0] ==  ADDR_VOL[3:0]);
reg     [3:0]  vol;
always @(posedge emuclk) if(!mclkpcen_n) begin
    if(vol_wr) vol <= i_DB_Z[3:0];
end

//current volume register
reg     [3:0]  curr_vol;
always @(posedge emuclk) begin
    if(!i_RST_n) curr_vol <=  4'd0;
    else begin if(!mclkpcen_n) begin
        if(mul_rst_pcen) curr_vol <= vol;
    end end
end

/*
do not use this expression

//latch cyccntr once more
reg     [2:0]   cyccntr_z;
always @(posedge emuclk) if(!mclkpcen_n) cyccntr_z <= ~cyccntr[2:0];

//serialized sound data
wire            wavedata_serial = i_RAM_Q[cyccntr_z];
*/

reg             wavedata_serial;
always @(posedge emuclk) if(!mclkpcen_n) wavedata_serial <= i_RAM_Q[~cyccntr[2:0]];

//keep the previous sound data bit
reg             mul_rst_z;
reg             wavedata_serial_z;
always @(posedge emuclk) if(!mclkpcen_n) begin
    mul_rst_z <= mul_rst;

    if(mul_rst | mul_rst_z) wavedata_serial_z <= 1'b0;
    else wavedata_serial_z <= wavedata_serial;
end

//make the addend
reg     [4:0]   weighted_vol;
reg             weighted_vol_carry;
always @(*) begin
    if(wavedata_serial == wavedata_serial_z) begin
        weighted_vol = 5'd0;
        weighted_vol_carry = 1'd0;
    end
    else begin
        weighted_vol = {wavedata_serial, curr_vol ^ {4{wavedata_serial}}};
        weighted_vol_carry = wavedata_serial;
    end
end

//calculation enable
reg             accshft_en, accshft_en_z;
always @(posedge emuclk) if(!mclkpcen_n) begin
    if(mul_rst) accshft_en <= 1'b1;
    else begin
        if(~cyccntr == 4'd7) accshft_en <= 1'b0;
    end

    accshft_en_z <= accshft_en;
end

//accumulation and shift
reg     [7:0]   accshft;
reg     [7:0]   accshft_next;
always @(*) begin
    accshft_next[7:3] = {accshft[7], accshft[7:4]} + weighted_vol + weighted_vol_carry; //discard carry
    accshft_next[2:0] = accshft[3:1];
end

reg     [7:0]   final_sound;
assign  o_SOUND = $signed(final_sound);
always @(posedge emuclk) if(!mclkpcen_n) begin
    if(mul_rst) accshft <= 8'h00;
    else begin
        if(accshft_en_z) accshft <= accshft_next;
    end

    //asynchronous outlatch/mute emulation
    if(mute_wr && ~i_DB_Z[BIT_MUTE]) final_sound <= 8'h00;
    else if(!mute) final_sound <= 8'h0;
    else begin
        if(accshft_en_z && (~cyccntr == 4'd8)) final_sound <= accshft_next;
    end
end

endmodule


module IKASCC_player_memory_s #(parameter RAM_TYPE = 1, parameter FAST_CLOCK = 0, parameter INITFILE = "") (
    input   wire            i_EMUCLK,
    input   wire            i_MCLK_PCEN_n,
    input   wire            i_RAM_WRRQ,
    input   wire    [4:0]   i_RAM_ADDR,
    input   wire    [7:0]   i_RAM_D,
    output  wire    [7:0]   o_RAM_Q
);


///////////////////////////////////////////////////////////
//////  Clock
////

wire            emuclk = i_EMUCLK;
wire            mclkpcen_n = i_MCLK_PCEN_n;



///////////////////////////////////////////////////////////
//////  wavetable
////

//declare wavetable RAM
reg     [7:0]   wavetable_ram[0:31];
initial if(INITFILE != "") $readmemh(INITFILE, wavetable_ram);

generate
if(RAM_TYPE == 0) begin : ramstyle_distributed
assign  o_RAM_Q = i_RAM_WRRQ ? i_RAM_D : wavetable_ram[i_RAM_ADDR];

always @(posedge emuclk) begin
    if(i_RAM_WRRQ) wavetable_ram[i_RAM_ADDR] <= i_RAM_D;
end
end

else if(RAM_TYPE == 1) begin : ramstyle_block
reg     [7:0]   wavedata_ram;
reg     [7:0]   wavedata_cpu; //for noise emulation
assign  o_RAM_Q = i_RAM_WRRQ ? wavedata_cpu : wavedata_ram;

    if(FAST_CLOCK == 1) begin : block_fast
    always @(posedge emuclk) begin
        if(i_RAM_WRRQ) wavetable_ram[i_RAM_ADDR] <= i_RAM_D;
        else wavedata_ram <= wavetable_ram[i_RAM_ADDR];

        if(i_RAM_WRRQ) wavedata_cpu <= i_RAM_D;
    end
    end
    else begin : block_slow
    always @(negedge emuclk) begin
        if(i_RAM_WRRQ) wavetable_ram[i_RAM_ADDR] <= i_RAM_D;
        else wavedata_ram <= wavetable_ram[i_RAM_ADDR];

        if(i_RAM_WRRQ) wavedata_cpu <= i_RAM_D;
    end
    end

end
endgenerate

endmodule