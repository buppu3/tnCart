module IKASCC_primitive_dncntr #(parameter W = 4) (
    input   wire                i_EMUCLK,
    input   wire                i_MCLK_PCEN_n,

    input   wire                i_SET,
    input   wire                i_LD,
    input   wire                i_CNT,
    
    input   wire    [W-1:0]     i_D, //data in
    output  wire    [W-1:0]     o_Q, //data out
    output  wire                o_BO //borrow out
);

reg     [W-1:0]     cntr;
always @(posedge i_EMUCLK) if(!i_MCLK_PCEN_n) begin
    if(i_SET) begin
        cntr <= {W{1'b1}};
    end
    else begin
        if(i_LD) begin
            cntr <= i_D;
        end
        else begin
            if(i_CNT) cntr <= (cntr == {W{1'b0}}) ? {W{1'b1}} : cntr - {{(W-1){1'b0}}, 1'b1};
        end
    end
end

assign  o_Q = cntr;
assign  o_BO = ~|{cntr};

endmodule

`timescale 10ns/1ns
module IKASCC_primitive_buf (
    input   wire            i_A,
    output  wire            o_Y
);

`ifdef IKASCC_ASYNC_VENDOR_SIMULATION
assign #1 o_Y = i_A;
`else
assign o_Y = i_A;
`endif 

endmodule

`ifdef IKASCC_ASYNC_VENDOR_GOWIN
module BUFG (O, I);
output O;
input I;
endmodule
`endif