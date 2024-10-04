module IKASCC_vrc_s #(parameter RAMCTRL_ASYNC = 0) (
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock

    //clock endables
    input   wire            i_MCLK_PCEN_n, //phiM positive edge clock enable(negative logic)

    //reset
    input   wire            i_RST_n, //synchronous reset

    //vrc decoder
    input   wire            i_CS_n, //asynchronous bus control signal
    input   wire            i_RD_n, 

    //SCC mapper output
    output  wire            o_ROMCS_n,
    output  reg     [5:0]   o_ROMADDR,

    //vrc register
    input   wire            i_WRRQ, //synchronous write request
    input   wire    [7:0]   i_DB,
    input   wire    [4:0]   i_ABHI,
    input   wire    [7:0]   i_ABLO,

    //SCC sound register enable
    output  reg             o_SCCREG_EN
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            mclkpcen_n = i_MCLK_PCEN_n;
wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  ROM bank registers
////

assign  o_ROMCS_n = i_CS_n | i_RD_n;

//synchronizer
reg     [7:0]   db_z;
reg     [4:0]   abhi_z;
always @(posedge emuclk) if(!mclkpcen_n) begin
    db_z   <= i_DB;
    abhi_z <= i_ABHI;
end

reg     [5:0]   bankreg0, bankreg1, bankreg2, bankreg3;
always @(posedge emuclk) begin
    if(!rst_n) begin
        bankreg0 <= 6'h00;
        bankreg1 <= 6'h01;
        bankreg2 <= 6'h02;
        bankreg3 <= 6'h03;
    end
    else begin if(!mclkpcen_n) begin
        if(i_WRRQ && abhi_z[1:0] == 2'b10) begin
            case(abhi_z[4:2])
                3'b010: bankreg0 <= db_z[5:0]; //BR0, 0x5000-0x57FF
                3'b011: bankreg1 <= db_z[5:0]; //BR1, 0x7000-0x77FF
                3'b100: bankreg2 <= db_z[5:0]; //BR2, 0x9000-0x97FF
                3'b101: bankreg3 <= db_z[5:0]; //BR3, 0xB000-0xB7FF
                default: ;
            endcase
        end
    end end
end



///////////////////////////////////////////////////////////
//////  Bank register output select
////

always @(*) begin
    case({~i_ABHI[3], i_ABHI[2]})
        2'b00: o_ROMADDR = bankreg0;
        2'b01: o_ROMADDR = bankreg1;
        2'b10: o_ROMADDR = bankreg2;
        2'b11: o_ROMADDR = bankreg3;
    endcase
end



///////////////////////////////////////////////////////////
//////  SCC register enable
////

generate
if(RAMCTRL_ASYNC == 0) begin : ramctrl_sync
always @(posedge emuclk) if(!mclkpcen_n) o_SCCREG_EN = (bankreg2 == 6'h3F) & (i_ABHI == 5'b10011); //synchronized
end
else begin : ramctrl_async
always @(*) o_SCCREG_EN = (bankreg2 == 6'h3F) & (i_ABHI == 5'b10011);
end
endgenerate



endmodule