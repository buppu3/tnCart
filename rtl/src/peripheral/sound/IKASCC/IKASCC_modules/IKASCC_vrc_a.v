module IKASCC_vrc_a (
    //reset
    input   wire            i_RST_n, //synchronous reset

    //vrc decoder
    input   wire            i_CS_n, //asynchronous bus control signal
    input   wire            i_WR_n,
    input   wire            i_RD_n, 

    //SCC mapper output
    output  wire            o_ROMCS_n,
    output  reg     [5:0]   o_ROMADDR,

    //vrc register
    input   wire    [7:0]   i_DB,
    input   wire    [4:0]   i_ABHI,
    input   wire    [7:0]   i_ABLO,

    //SCC sound register enable
    output  reg             o_SCCREG_EN
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////  ROM bank registers
////

assign  o_ROMCS_n = i_CS_n | i_RD_n;

reg     [5:0]   bankreg0, bankreg1, bankreg2, bankreg3;
always @(posedge i_WR_n or negedge rst_n) begin
    if(!rst_n) begin
        bankreg0 <= 6'h00;
        bankreg1 <= 6'h01;
        bankreg2 <= 6'h02;
        bankreg3 <= 6'h03;
    end
    else begin
        if(~i_CS_n && i_ABHI[1:0] == 2'b10) begin
            case(i_ABHI[4:2])
                3'b010: bankreg0 <= i_DB[5:0]; //BR0, 0x5000-0x57FF
                3'b011: bankreg1 <= i_DB[5:0]; //BR1, 0x7000-0x77FF
                3'b100: bankreg2 <= i_DB[5:0]; //BR2, 0x9000-0x97FF
                3'b101: bankreg3 <= i_DB[5:0]; //BR3, 0xB000-0xB7FF
                default: ;
            endcase
        end
    end
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

always @(*) o_SCCREG_EN = (bankreg2 == 6'h3F) & (i_ABHI == 5'b10011);


endmodule