`timescale 10ns/1ns
module IKASCC_tb;

//BUS IO wires
reg             CLK = 1'b1;
reg             RST_n = 1'b1;
reg             CS_n = 1'b1;
reg             RD_n = 1'b1;
reg             WR_n = 1'b1;
reg     [15:0]  AB = 16'h0000;
reg     [7:0]   DB = 8'hZZ;
reg     [7:0]   INLATCH;

//generate clock
always #140 CLK = ~CLK; //3.58MHz

reg     [2:0]   prescaler = 3'd0;
always @(posedge CLK) prescaler <= prescaler + 3'd1;

reg             EMUCLK; always @(*) EMUCLK = prescaler[2];
wire            EMUCLK_PCEN = prescaler == 3'd3;

//async reset
initial begin
    #30 RST_n <= 1'b0;
    #1300 RST_n <= 1'b1;
end

//define bus transaction
task automatic IKASCC_write (
    input       [15:0]  i_TARGET_ADDR,
    input       [7:0]   i_WRITE_DATA,
    ref logic           i_CLK,
    ref logic           o_CS_n,
    ref logic           o_WR_n,
    ref logic   [15:0]  o_ADDR,
    ref logic   [7:0]   o_DATA
); begin
    @(posedge i_CLK) o_ADDR = #130 i_TARGET_ADDR;
    @(negedge i_CLK) o_CS_n = #115 1'b0;
    @(posedge i_CLK) o_DATA = #30 i_WRITE_DATA;
    @(negedge i_CLK) o_WR_n = #100 1'b0;
    @(posedge i_CLK) ;
    @(negedge i_CLK) o_WR_n = #80 1'b1;
                     o_CS_n = #35 1'b1;
    @(posedge i_CLK) o_DATA = #30 8'hZZ;
end endtask

task automatic IKASCC_read (
    input       [15:0]  i_TARGET_ADDR,
    ref logic           i_CLK,
    ref logic           o_CS_n,
    ref logic           o_RD_n,
    ref logic   [15:0]  o_ADDR,
    ref logic   [7:0]   i_DATA,
    ref logic   [7:0]   o_DATA
); begin
    @(posedge i_CLK) o_ADDR = #130 i_TARGET_ADDR;
    @(negedge i_CLK) o_CS_n = #115 1'b0;
                     o_RD_n = 1'b0;
    @(posedge i_CLK) ;
    @(negedge i_CLK) ;
    @(posedge i_CLK) ;
    @(negedge i_CLK) o_RD_n = #105 1'b1;
                     o_DATA = i_DATA;
                     o_CS_n = #10 1'b1;
    @(posedge i_CLK) ;
end endtask

initial begin
    #2000

    #100 IKASCC_write(16'h9000, 8'h3F, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_write(16'h9880, 8'h1C, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9881, 8'h00, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_write(16'h9886, 8'h1C, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9887, 8'h00, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_write(16'h9888, 8'h38, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9889, 8'h00, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_write(16'h988A, 8'h0D, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h988D, 8'h0D, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h988E, 8'h07, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_write(16'h988F, 8'h19, EMUCLK, CS_n, WR_n, AB, DB);

    #100 IKASCC_read(16'h9860, EMUCLK, CS_n, RD_n, AB, DB, INLATCH);
    #100 IKASCC_read(16'h9861, EMUCLK, CS_n, RD_n, AB, DB, INLATCH);
    #100 IKASCC_write(16'h9802, 8'h0C, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9803, 8'h17, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9862, 8'h0C, EMUCLK, CS_n, WR_n, AB, DB);
    #100 IKASCC_write(16'h9863, 8'h17, EMUCLK, CS_n, WR_n, AB, DB);
    
end


IKASCC #(.IMPL_TYPE(1), .RAM_BLOCK(1)) u_dut (
    .i_EMUCLK                   (CLK                        ),
    .i_MCLK_PCEN_n              (~EMUCLK_PCEN               ),
    .i_RST_n                    (RST_n                      ),

    .i_CS_n                     (CS_n                       ),
    .i_RD_n                     (RD_n                       ),
    .i_WR_n                     (WR_n                       ),
    .i_ABLO                     (AB[7:0]                    ),
    .i_ABHI                     (AB[15:11]                  ),

    .i_DB                       (DB                         ),
    .o_DB                       (                           ),
    .o_D_OE                     (                           ),

    .o_ROMCS_n                  (                           ),
    .o_ROMADDR                  (                           ),

    .o_SOUND                    (                           ),

    .o_TEST                     (                           )
);


IKASCC #(.IMPL_TYPE(3), .RAM_BLOCK(0)) u_dut_async (
    .i_EMUCLK                   (EMUCLK                     ),
    .i_MCLK_PCEN_n              (1'b0                       ),
    .i_RST_n                    (RST_n                      ),

    .i_CS_n                     (CS_n                       ),
    .i_RD_n                     (RD_n                       ),
    .i_WR_n                     (WR_n                       ),
    .i_ABLO                     (AB[7:0]                    ),
    .i_ABHI                     (AB[15:11]                  ),

    .i_DB                       (DB                         ),
    .o_DB                       (                           ),
    .o_D_OE                     (                           ),

    .o_ROMCS_n                  (                           ),
    .o_ROMADDR                  (                           ),

    .o_SOUND                    (                           ),

    .o_TEST                     (                           )
);

endmodule