module IKASCC_player_a #(
    parameter DELAY_LENGTH = 1
) (
    input   wire            i_EMUCLK,
    input   wire            i_RST_n,

    input   wire            i_SCCREG_EN,
    input   wire            i_CS_n, i_RD_n, i_WR_n,
    input   wire    [7:0]   i_ABLO,
    input   wire    [7:0]   i_DB,
    output  reg     [7:0]   o_DB,

    output  reg             o_TEST,

    output  reg  signed     [10:0]   o_SOUND
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  Delay chain
////

`define IKASCC_SIMULATION

`ifdef IKASCC_SIMULATION
wire [DELAY_LENGTH:0] delay;
wire i_DELAYED_WR = delay[DELAY_LENGTH];

`elsif IKASCC_ASYNC_VENDOR_ALTERA
wire [DELAY_LENGTH:0] delay /* synthesis keep */; 
(* altera_attribute = "-name GLOBAL_SIGNAL GLOBAL_CLOCK" *) wire i_DELAYED_WR = delay[DELAY_LENGTH];

`elsif IKASCC_ASYNC_VENDOR_XILINX
(* keep = "true" *) wire [DELAY_LENGTH:0] delay;
(* CLOCK_BUFFER_TYPE = "BUFG" *) wire i_DELAYED_WR = delay[DELAY_LENGTH];

`elsif IKASCC_ASYNC_VENDOR_LATTICE
wire [DELAY_LENGTH:0] delay /* synthesis syn_keep=1 nomerge=""*/;
wire i_DELAYED_WR = delay[DELAY_LENGTH]; //TODO: how to use global buffer manually??

`elsif IKASCC_ASYNC_VENDOR_GOWIN
wire [DELAY_LENGTH:0] delay /* synthesis syn_keep=1 */;
wire            i_DELAYED_WR;
BUFG u_bufg(i_DELAYED_WR, delay[DELAY_LENGTH])
`endif

assign  delay[0] = ~i_WR_n;

genvar d;
generate
for(d=0; d<DELAY_LENGTH; d=d+1) begin : delay_chain
IKASCC_primitive_buf u_dlybuf(delay[d], delay[d+1]);
end
endgenerate



///////////////////////////////////////////////////////////
//////  Test register
////

wire    test_wr = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == 3'b111);
reg     [7:0]   test;
always @(posedge i_WR_n or negedge rst_n) begin
    if(!rst_n) test <= 8'h00;
    else begin
        if(test_wr) test <= i_DB;
    end
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
    else begin
        o_SOUND <= ch1_sound + ch2_sound + ch3_sound + ch4_sound + ch5_sound;
    end
end



///////////////////////////////////////////////////////////
//////  Channel 1
////

wire            ch1_ram_cs;
wire    [4:0]   ch1_ram_addr_cntr, ch1_ram_addr_cpu;
wire    [4:0]   ch1_ram_addr = ch1_ram_cs ? ch1_ram_addr_cpu : ch1_ram_addr_cntr;
wire    [7:0]   ch1_ram_d, ch1_ram_q;

IKASCC_player_memory_a #(.INITFILE()) u_mem_ch1 (
    .i_RAM_CS                   (ch1_ram_cs & ~test[6]      ),
    .i_RAM_WR                   (i_DELAYED_WR               ),
    .i_RAM_ADDR                 (ch1_ram_addr               ),
    .i_RAM_D                    (ch1_ram_d                  ),
    .o_RAM_Q                    (ch1_ram_q                  )
);

IKASCC_player_control_a #(
    .ADDR_RAM_BASE              (8'h00                      ),
    .ADDR_FREQ_BASE             (8'h80                      ),
    .ADDR_VOL                   (8'h8A                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (0                          )
) u_ctrl_ch1 (
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n),
    .i_WR_n(i_WR_n), .i_DELAYED_WR(i_DELAYED_WR),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_CS                   (ch1_ram_cs                 ),
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

wire            ch2_ram_cs;
wire    [4:0]   ch2_ram_addr_cntr, ch2_ram_addr_cpu;
wire    [4:0]   ch2_ram_addr = ch2_ram_cs ? ch2_ram_addr_cpu : ch2_ram_addr_cntr;
wire    [7:0]   ch2_ram_d, ch2_ram_q;

IKASCC_player_memory_a #(.INITFILE()) u_mem_ch2 (
    .i_RAM_CS                   (ch2_ram_cs & ~test[6]      ),
    .i_RAM_WR                   (i_DELAYED_WR               ),
    .i_RAM_ADDR                 (ch2_ram_addr               ),
    .i_RAM_D                    (ch2_ram_d                  ),
    .o_RAM_Q                    (ch2_ram_q                  )
);

IKASCC_player_control_a #(
    .ADDR_RAM_BASE              (8'h20                      ),
    .ADDR_FREQ_BASE             (8'h82                      ),
    .ADDR_VOL                   (8'h8B                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (1                          )
) u_ctrl_ch2 (
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n),
    .i_WR_n(i_WR_n), .i_DELAYED_WR(i_DELAYED_WR),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_CS                   (ch2_ram_cs                 ),
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

wire            ch3_ram_cs;
wire    [4:0]   ch3_ram_addr_cntr, ch3_ram_addr_cpu;
wire    [4:0]   ch3_ram_addr = ch3_ram_cs ? ch3_ram_addr_cpu : ch3_ram_addr_cntr;
wire    [7:0]   ch3_ram_d, ch3_ram_q;

IKASCC_player_memory_a #(.INITFILE()) u_mem_ch3 (
    .i_RAM_CS                   (ch3_ram_cs & ~test[6]      ),
    .i_RAM_WR                   (i_DELAYED_WR               ),
    .i_RAM_ADDR                 (ch3_ram_addr               ),
    .i_RAM_D                    (ch3_ram_d                  ),
    .o_RAM_Q                    (ch3_ram_q                  )
);

IKASCC_player_control_a #(
    .ADDR_RAM_BASE              (8'h40                      ),
    .ADDR_FREQ_BASE             (8'h84                      ),
    .ADDR_VOL                   (8'h8C                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (2                          )
) u_ctrl_ch3 (
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n),
    .i_WR_n(i_WR_n), .i_DELAYED_WR(i_DELAYED_WR),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_CS                   (ch3_ram_cs                 ),
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
    else begin
        ch45_cntr <= ch45_cntr == 3'd0 ? 3'd7 : ch45_cntr - 3'd1;

        if(ch45_cntr == 3'd0) begin
            ch45_sr[0] <= ~ch45_sr[1];
            ch45_sr[1] <= ch45_sr[0];
        end
    end
end

//ram r/w control and address/data
wire            ch45_ram_cs;
assign  ch45_ram_addrsel[1] = ((~ch45_sr[1] & ~ch45_ram_cs) | test[7]) & ~test[7];
assign  ch45_ram_addrsel[0] = (( ch45_sr[1] & ~ch45_ram_cs) | test[6]) & ~test[6];
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
always @(posedge emuclk) begin
    if(ch4_wavelatch_tick_pcen) ch4_wavelatch <= ch45_ram_q;
    if(ch5_wavelatch_tick_pcen) ch5_wavelatch <= ch45_ram_q;
end

IKASCC_player_memory_a #(.INITFILE()) u_mem_ch45 (
    .i_RAM_CS                   (ch45_ram_cs & ~test[6] & ~test[7]),
    .i_RAM_WR                   (i_DELAYED_WR               ),
    .i_RAM_ADDR                 (ch45_ram_addr              ),
    .i_RAM_D                    (ch45_ram_d                 ),
    .o_RAM_Q                    (ch45_ram_q                 )
);

IKASCC_player_control_a #(
    .ADDR_RAM_BASE              (8'h60                      ),
    .ADDR_FREQ_BASE             (8'h86                      ),
    .ADDR_VOL                   (8'h8D                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (3                          )
) u_ctrl_ch4(
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n),
    .i_WR_n(i_WR_n), .i_DELAYED_WR(i_DELAYED_WR),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_CS                   (ch45_ram_cs                ),
    .o_RAM_ADDR_CNTR            (ch4_ram_addr_cntr          ),
    .o_RAM_ADDR_CPU             (ch45_ram_addr_cpu          ),
    .o_RAM_D                    (ch45_ram_d                 ),
    .i_RAM_Q                    (ch4_wavelatch              ),

    .o_FRACCNTR_LD_n            (fraccntr_ld_n[3]           ),

    .o_SOUND                    (ch4_sound                  )
);

IKASCC_player_control_a #(
    .ADDR_RAM_BASE              (8'h60                      ),
    .ADDR_FREQ_BASE             (8'h88                      ),
    .ADDR_VOL                   (8'h8E                      ),
    .ADDR_MUTE                  (8'h8F                      ),
    .BIT_MUTE                   (4                          )
) u_ctrl_ch5(
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (i_SCCREG_EN                ),
    .i_CS_n(i_CS_n), .i_RD_n(i_RD_n),
    .i_WR_n(i_WR_n), .i_DELAYED_WR(i_DELAYED_WR),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .i_TEST                     (test                       ),

    .o_RAM_CS                   (                           ),
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

         if(ch1_ram_cs) o_DB = ch1_ram_q;
    else if(ch2_ram_cs) o_DB = ch2_ram_q;
    else if(ch3_ram_cs) o_DB = ch3_ram_q;
    else if(ch45_ram_cs) o_DB = ch45_ram_q;
end

endmodule

module IKASCC_player_control_a #(
    parameter ADDR_RAM_BASE  = 8'h00,
    parameter ADDR_FREQ_BASE = 8'h00,
    parameter ADDR_VOL  = 8'h00,
    parameter ADDR_MUTE = 8'h00,
    parameter BIT_MUTE = 0
    ) (
    input   wire            i_EMUCLK,
    input   wire            i_RST_n,

    input   wire            i_SCCREG_EN,
    input   wire            i_CS_n, i_RD_n,
    input   wire            i_WR_n, i_DELAYED_WR, //promoted clock
    input   wire    [7:0]   i_ABLO,
    input   wire    [7:0]   i_DB,
    input   wire    [7:0]   i_TEST,

    output  wire            o_RAM_CS,
    output  wire    [4:0]   o_RAM_ADDR_CNTR, o_RAM_ADDR_CPU,
    output  wire    [7:0]   o_RAM_D,
    input   wire    [7:0]   i_RAM_Q,

    output  wire            o_FRACCNTR_LD_n,

    output  wire signed     [7:0]  o_SOUND
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  SCC wavetable CPU R/W
////

assign  o_RAM_CS = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == ADDR_RAM_BASE[7:5]);
assign  o_RAM_ADDR_CPU = i_ABLO[4:0];
assign  o_RAM_D = i_DB;



///////////////////////////////////////////////////////////
//////  Frequency register
////

wire    freq_lo_wr = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] ==  ADDR_FREQ_BASE[3:0]);
wire    freq_hi_wr = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] == (ADDR_FREQ_BASE[3:0] + 4'h1));
reg     [11:0]  freq;
always @(posedge i_WR_n or negedge rst_n) begin
    if(!rst_n) freq <= 12'h000;
    else begin
        if(freq_lo_wr) freq[7:0] <= i_DB;
        if(freq_hi_wr) freq[11:8] <= i_DB[3:0];
    end
end



///////////////////////////////////////////////////////////
//////  Counter
////

wire    intcntr_cnt, intcntr_set, fraccntr_ld;
assign  o_FRACCNTR_LD_n = ~fraccntr_ld;

wire    [3:0]   cyccntr;
IKASCC_primitive_dncntr #(.W(4)) u_cyccntr (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(1'b0),
    .i_SET(fraccntr_ld), .i_LD(1'b0), .i_CNT(1'b1),
    .i_D(4'hF), .o_Q(cyccntr), .o_BO()
);

wire    [3:0]   fraccntr_a;
wire            fraccntr_a_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_a (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(1'b0),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(1'b1),
    .i_D(freq_lo_wr ? i_DB[3:0] : freq[3:0]), .o_Q(fraccntr_a), .o_BO(fraccntr_a_bo)
);

wire    [3:0]   fraccntr_b;
wire            fraccntr_b_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_b (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(1'b0),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(fraccntr_a_bo),
    .i_D(freq_lo_wr ? i_DB[7:4] : freq[7:4]), .o_Q(fraccntr_b), .o_BO(fraccntr_b_bo)
);

wire            fraccntr_c_cnt = i_TEST[0] ? 1'b1 : fraccntr_a_bo & fraccntr_b_bo;
wire    [3:0]   fraccntr_c;
wire            fraccntr_c_bo;
IKASCC_primitive_dncntr #(.W(4)) u_fraccntr_c (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(1'b0),
    .i_SET(1'b0 | ~rst_n), .i_LD(fraccntr_ld), .i_CNT(fraccntr_c_cnt),
    .i_D(freq_hi_wr ? i_DB[3:0] : freq[11:8]), .o_Q(fraccntr_c), .o_BO(fraccntr_c_bo)
);

assign  intcntr_cnt = i_TEST[1] ? fraccntr_a_bo & fraccntr_b_bo : fraccntr_c_cnt & fraccntr_c_bo;

wire    [4:0]   intcntr;
IKASCC_primitive_dncntr #(.W(5)) u_intcntr (
    .i_EMUCLK(emuclk), .i_MCLK_PCEN_n(1'b0),
    .i_SET(intcntr_set | ~rst_n), .i_LD(1'b0), .i_CNT(intcntr_cnt),
    .i_D(5'd0), .o_Q(intcntr), .o_BO()
);

assign  o_RAM_ADDR_CNTR = ~intcntr;
wire    [11:0]  fraccntr = {fraccntr_c, fraccntr_b, fraccntr_a};



///////////////////////////////////////////////////////////
//////  Frequency dirty flag
////

wire            freq_changed;
assign  freq_changed = (~i_WR_n & ~i_CS_n & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] ==  ADDR_FREQ_BASE[3:0])) |
                       (~i_WR_n & ~i_CS_n & i_SCCREG_EN & (i_ABLO[7:5] == ADDR_FREQ_BASE[7:5]) & (i_ABLO[3:0] == (ADDR_FREQ_BASE[3:0] + 4'h1)));

reg             freq_changed_z;
always @(posedge emuclk) freq_changed_z <= freq_changed;

assign  fraccntr_ld = intcntr_cnt | (freq_changed | freq_changed_z); //emulates asynchronous set(will generated 1.5-cycle pulse)
assign  intcntr_set = i_TEST[5] & (freq_changed | freq_changed_z);



///////////////////////////////////////////////////////////
//////  Mute
////

wire            mute_wr = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == ADDR_MUTE[7:5]) & (i_ABLO[3:0] ==  ADDR_MUTE[3:0]);
reg             mute;
always @(posedge i_WR_n or negedge rst_n) begin
    if(!rst_n) mute <= 1'b0;
    else begin
        if(mute_wr) mute <= i_DB[BIT_MUTE];
    end
end



///////////////////////////////////////////////////////////
//////  Serial multiplier
////

//multiplier re-set
wire            mul_rst = fraccntr_ld;
wire            mul_rst_pcen = intcntr_cnt | freq_lo_wr | freq_hi_wr; //positive edge enable of originally asynchronous mul_rst

//volume register
wire    vol_wr = i_SCCREG_EN & ~i_CS_n & (i_ABLO[7:5] == ADDR_VOL[7:5]) & (i_ABLO[3:0] ==  ADDR_VOL[3:0]);
reg     [3:0]  vol;
always @(posedge i_WR_n) if(vol_wr) vol <= i_DB[3:0];

//current volume register
reg     [3:0]  curr_vol;
always @(posedge emuclk or negedge rst_n) begin
    if(!rst_n) curr_vol <=  4'd0;
    else begin
        if(mul_rst_pcen) curr_vol <= vol;
    end
end

//select a bit and latch
reg             wavedata_serial;
always @(posedge emuclk) wavedata_serial <= i_RAM_Q[~cyccntr[2:0]];

//keep the previous sound data bit
reg             mul_rst_z;
reg             wavedata_serial_z;
always @(posedge emuclk) begin
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
always @(posedge emuclk) begin
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
always @(posedge emuclk) begin
    if(mul_rst) accshft <= 8'h00;
    else begin
        if(accshft_en_z) accshft <= accshft_next;
    end

    //asynchronous outlatch/mute emulation
    if(mute_wr && ~i_DB[BIT_MUTE]) final_sound <= 8'h00;
    else if(!mute) final_sound <= 8'h0;
    else begin
        if(accshft_en_z && (~cyccntr == 4'd8)) final_sound <= accshft_next;
    end
end


endmodule

module IKASCC_player_memory_a #(parameter INITFILE = "") (
    input   wire            i_RAM_CS,
    input   wire            i_RAM_WR, //clock
    input   wire    [4:0]   i_RAM_ADDR,
    input   wire    [7:0]   i_RAM_D,
    output  wire    [7:0]   o_RAM_Q
);


///////////////////////////////////////////////////////////
//////  Wavetable
////

reg     [7:0]   wavetable_ram[0:31];
reg     [7:0]   wavedata;
initial if(INITFILE != "") $readmemh(INITFILE, wavetable_ram);

always @(posedge i_RAM_WR) if(i_RAM_CS) wavetable_ram[i_RAM_ADDR] <= i_RAM_D;

always @(*) begin
    if(i_RAM_WR) wavedata = i_RAM_D;
    else wavedata = wavetable_ram[i_RAM_ADDR];
end

assign  o_RAM_Q = wavedata;

endmodule