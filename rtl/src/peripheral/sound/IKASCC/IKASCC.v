module IKASCC #(parameter IMPL_TYPE = 0, parameter RAM_BLOCK = 1) (
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock enables
    input   wire            i_MCLK_PCEN_n, //phiM positive edge clock enable(negative logic)

    //reset
    input   wire            i_RST_n, //synchronous reset

    //bus control
    input   wire            i_CS_n, //asynchronous bus control signal
    input   wire            i_RD_n, 
    input   wire            i_WR_n, 
    input   wire    [7:0]   i_ABLO, //address bus low(AB7:0), for the SCC
    input   wire    [4:0]   i_ABHI, //address bus high(AB15:11), for the mapper

    //bus data
    input   wire    [7:0]   i_DB,
    output  wire    [7:0]   o_DB,

    //output driver enable
    output  wire            o_DB_OE,

    //SCC mapper output
    output  wire            o_ROMCS_n,
    output  wire    [5:0]   o_ROMADDR, //MA[18:13]

    //SCC sound output
    output  wire signed     [10:0]  o_SOUND,

    //test
    output  wire            o_TEST
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

/*
    IMPLEMENTATION TYPE
    0: (sync)SoC implementation with fast clock above 10MHz
    1: (sync)SoC implementation/standalone module with slow clock around 3.58MHz
    2: (async)standalone module with slow clock around 3.58MHz
*/

localparam  RAMCTRL_ASYNC = 1; //TBD
localparam  RAM_ASYNC_WRITE_DELAY_CHAIN_LENGTH = 20;
localparam  FULLY_ASYNC = (IMPL_TYPE == 2) ? 1 : 0;
localparam  RAM_TYPE    = (IMPL_TYPE == 2) ? 0 : RAM_BLOCK;
localparam  FAST_CLOCK  = (IMPL_TYPE == 0) ? 1 : 0;

`define IKASCC_SIMULATION
//`define IKASCC_ASYNC_VENDOR_ALTERA
//`define IKASCC_ASYNC_VENDOR_XILINX
//`define IKASCC_ASYNC_VENDOR_LATTICE
//`define IKASCC_ASYNC_VENDOR_GOWIN



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            mclkpcen_n = i_MCLK_PCEN_n;
wire            rst_n = i_RST_n;

wire            sccreg_en; //common wire



///////////////////////////////////////////////////////////
//////  SCC Modules
////

generate
if(FULLY_ASYNC == 0) begin : IKASCC_SYNC_MODE

///////////////////////////////////////////////////////////
//////  Async bus control synchronizer
////

//See MSX2 Technical Handbook at page 400
//All rising and falling edges of the slot clock are guaranteed
//to occur while /RD or /WR by the main CPU is being asserted. 
//These chain are synchronized to the emulator clock. If you force 
//the clock enable to be stuck at 0, this would run at 3.58 MHz.

/*
    MSX default slots
                       <---- 280ns ---->
    CPU clock   _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_____
    Slot clock  ¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|__
                       |--> 40ns delayed
    /WR         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    /RD         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    MSX expansion slots
                       <---- 280ns ---->
    CPU clock   _______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_____
    Slot clock  ¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯
                       |---> 80ns delayed
    /WR         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    /RD         ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

    wr_request  ____________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________
                                                                            *<--- register update
*/


//declare synchronized signals: every module must use these things!
wire            read_request, write_request;

reg     [1:0]   rd_syncchain, wr_syncchain;
always @(posedge emuclk) if(!mclkpcen_n) begin
    rd_syncchain[0] <= i_CS_n; // | i_RD_n;
    wr_syncchain[0] <= i_CS_n | i_WR_n;

    rd_syncchain[1] <= rd_syncchain[0];
    wr_syncchain[1] <= wr_syncchain[0];
end

//edge detector
assign  read_request  = rd_syncchain == 2'b10 || rd_syncchain == 2'b00;
assign  write_request = wr_syncchain == 2'b10;



///////////////////////////////////////////////////////////
//////  Virtual ROM Controller(synchronous)
////

IKASCC_vrc_s #(.RAMCTRL_ASYNC(RAMCTRL_ASYNC)) u_vrc_s_main (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),

    .o_ROMCS_n                  (o_ROMCS_n                  ),
    .o_ROMADDR                  (o_ROMADDR                  ),

    .i_WRRQ                     (write_request              ),
    .i_DB                       (i_DB                       ),
    .i_ABHI                     (i_ABHI                     ),
    .i_ABLO                     (i_ABLO                     ),

    .o_SCCREG_EN                (sccreg_en                  )
);



///////////////////////////////////////////////////////////
//////  Wavetable player(synchronous)
////

IKASCC_player_s #(.RAM_TYPE(RAM_TYPE), .FAST_CLOCK(FAST_CLOCK), .RAMCTRL_ASYNC(RAMCTRL_ASYNC)) u_player_main (
    .i_EMUCLK                   (emuclk                     ),
    .i_MCLK_PCEN_n              (mclkpcen_n                 ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (sccreg_en                  ),
    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_RDRQ                     (read_request               ),
    .i_WRRQ                     (write_request              ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .o_DB                       (o_DB                       ),

    .o_TEST                     (o_TEST                     ),

    .o_SOUND                    (o_SOUND                    )
);

end
else begin : IKASCC_ASYNC_MODE

///////////////////////////////////////////////////////////
//////  Virtual ROM Controller(asynchronous)
////

IKASCC_vrc_a u_vrc_a_main (
    .i_RST_n                    (rst_n                      ),

    .i_WR_n                     (i_WR_n                     ),
    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),

    .o_ROMCS_n                  (o_ROMCS_n                  ),
    .o_ROMADDR                  (o_ROMADDR                  ),

    .i_DB                       (i_DB                       ),
    .i_ABHI                     (i_ABHI                     ),
    .i_ABLO                     (i_ABLO                     ),

    .o_SCCREG_EN                (sccreg_en                  )
);



///////////////////////////////////////////////////////////
//////  Wavetable player(asynchronous)
////

IKASCC_player_a #(.DELAY_LENGTH(RAM_ASYNC_WRITE_DELAY_CHAIN_LENGTH)) u_player_main2 (
    .i_EMUCLK                   (emuclk                     ),
    .i_RST_n                    (rst_n                      ),

    .i_SCCREG_EN                (sccreg_en                  ),
    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_ABLO                     (i_ABLO                     ),
    .i_DB                       (i_DB                       ),
    .o_DB                       (o_DB                       ),

    .o_TEST                     (o_TEST                     ),

    .o_SOUND                    (o_SOUND                    )
);

end
endgenerate

//data output enable
assign  o_DB_OE = (sccreg_en & ~i_CS_n & ~i_RD_n & ~i_ABLO[7]);

endmodule