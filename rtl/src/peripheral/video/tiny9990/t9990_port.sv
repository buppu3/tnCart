//
// t9990_port.sv
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
 * レジスタ定義
 ***************************************************************/
package T9990_REG;
    // OP
    localparam [3:0] CMD_STOP       = 4'b0000;
    localparam [3:0] CMD_LMMC       = 4'b0001;
    localparam [3:0] CMD_LMMV       = 4'b0010;
    localparam [3:0] CMD_LMCM       = 4'b0011;
    localparam [3:0] CMD_LMMM       = 4'b0100;
    localparam [3:0] CMD_CMMC       = 4'b0101;
    localparam [3:0] CMD_CMMK       = 4'b0110;
    localparam [3:0] CMD_CMMM       = 4'b0111;
    localparam [3:0] CMD_BMXL       = 4'b1000;
    localparam [3:0] CMD_BMLX       = 4'b1001;
    localparam [3:0] CMD_BMLL       = 4'b1010;
    localparam [3:0] CMD_LINE       = 4'b1011;
    localparam [3:0] CMD_SRCH       = 4'b1100;
    localparam [3:0] CMD_POINT      = 4'b1101;
    localparam [3:0] CMD_PSET       = 4'b1110;
    localparam [3:0] CMD_ADVN       = 4'b1111;

    // CLRM(R#6[1:0])
    localparam [1:0] CLRM_2BPP      = 2'b00;    //  2bit/pixel
    localparam [1:0] CLRM_4BPP      = 2'b01;    //  4bit/pixel
    localparam [1:0] CLRM_8BPP      = 2'b10;    //  8bit/pixel
    localparam [1:0] CLRM_16BPP     = 2'b11;    // 16bit/pixel

    // XIMM(R#6[3:2])
    localparam [1:0] XIMM_256       = 2'b00;    // 横幅 256dots
    localparam [1:0] XIMM_512       = 2'b01;    //      512dots
    localparam [1:0] XIMM_1024      = 2'b10;    //     1024dots
    localparam [1:0] XIMM_2048      = 2'b11;    //     2048dots

    // DCKM(R#6[5:4])
    localparam [1:0] DCKM_DIV4      = 2'b00;    // クロック分周比 1/4
    localparam [1:0] DCKM_DIV2      = 2'b01;    // クロック分周比 1/2
    localparam [1:0] DCKM_DIV1      = 2'b10;    // クロック分周比 1/1
    localparam [1:0] DCKM_NA        = 2'b11;    // クロック分周比 N/A

    // DSPM(R#6[7:6])
    localparam [1:0] DSPM_STANDBY   = 2'b11;    // STAND-BY
    localparam [1:0] DSPM_BITMAP    = 2'b10;    // BITMAP
    localparam [1:0] DSPM_P2        = 2'b01;    // P2
    localparam [1:0] DSPM_P1        = 2'b00;    // P1

    // MCS(P#7[0], P#5[2])
    localparam [0:0] MCS_14MHZ      = 1'b1;     // 14MHz
    localparam [0:0] MCS_21MHZ      = 1'b0;     // 21MHz

    // C25M(R#7[6])
    localparam [0:0] C25M_25MHZ     = 1'b1;     // 25MHz
    localparam [0:0] C25M_OTHER     = 1'b0;     //

    // EO(R#7[2])
    localparam [0:0] EO_DISABLE     = 1'b0;     // non interlace
    localparam [0:0] EO_ENABLE      = 1'b1;     // x2 vertical resolution

    // IL(R#7[1])
    localparam [0:0] IL_DISABLE     = 1'b0;     // interlace
    localparam [0:0] IL_ENABLE      = 1'b1;     // non interlace

    // HSCN(R#7[0])
    localparam [0:0] HSCN_HIGH      = 1'b1;     // high scan mode
    localparam [0:0] HSCN_LOW       = 1'b0;     // low scan mode

    // DISP(R#8[7])
    localparam [0:0] DISP_ENABLE    = 1'b1;     //
    localparam [0:0] DISP_DISABLE   = 1'b0;     //

    // SPD(R#8[6])
    localparam [0:0] SPD_ENABLE     = 1'b0;     //
    localparam [0:0] SPD_DISABLE    = 1'b1;     //

    // YSE(R#8[5])
    localparam [0:0] YSE_ENABLE     = 1'b1;     //
    localparam [0:0] YSE_DISABLE    = 1'b0;     //

    // DMAE(R#8[2])
    localparam [0:0] DMAE_ENABLE    = 1'b1;     //
    localparam [0:0] DMAE_DISABLE   = 1'b0;     //

    // PLTM(R#13[7:6])
    localparam [1:0] PLTM_YUV       = 2'b11;    // YUV
    localparam [1:0] PLTM_YJK       = 2'b10;    // YJK
    localparam [1:0] PLTM_256       = 2'b01;    // RGB
    localparam [1:0] PLTM_PALETTE   = 2'b00;    // PALETTE

    // VAE(R#13[5])
    localparam [0:0] YAE_MIX        = 1'b1;
    localparam [0:0] YAE_ONLY       = 1'b0;

    // PLTAIH(R#14[4])
    localparam [0:0] PLTAIH_NO_INC  = 1'b1;
    localparam [0:0] PLTAIH_INC     = 1'b0;

    // PLTP(R#14[1:0])
    localparam [1:0] PLTP_R         = 2'b00;    // R
    localparam [1:0] PLTP_G         = 2'b01;    // G
    localparam [1:0] PLTP_B         = 2'b10;    // B
endpackage

/***************************************************************
 * ステータス I/F
 ***************************************************************/
interface T9990_STATUS_IF;
    logic           TR;
    logic           VR;
    logic           HR;
    logic           BD;
    logic           EO;
    logic           CE;
    logic           CE_intr;
    logic           HI;
    logic           VI;
    logic [10:0]    BX;
    modport CPU ( input     TR, VR, HR, BD, EO, CE, CE_intr, HI, VI, BX  );
    modport CMD ( output    TR, BD, CE, CE_intr, BX );
    modport TIM ( output    VR, HR, EO, HI, VI );
endinterface

/***************************************************************
 * レジスタ I/F
 ***************************************************************/
interface T9990_REGISTER_IF;
    logic           SRS;
    logic           MCS;
    logic [18:0]    CVWA;
    logic           CVWAIH;
    logic [18:0]    CVRA;
    logic           CVRAIH;
    logic [1:0]     DSPM;
    logic [1:0]     DCKM;
    logic [1:0]     XIMM;
    logic [1:0]     CLRM;
    logic           C25M;
    logic           EO;
    logic           ILM;
    logic           HSCN;
    logic           DISP;
    logic           SPD;
    logic           YSE;
    logic           DMAE;
    logic           IECE;
    logic           IEH;
    logic           IEV;
    logic           IEHM;
    logic [9:0]     IL;
    logic [3:0]     IX;
    logic [3:0]     PLT;
    logic           PLTAIH;
    logic           YAE;
    logic [1:0]     PLTM;
    logic [5:0]     PLTA;
    logic [1:0]     PLTP;
    logic [5:0]     BDC;
    logic [12:0]    SCAY;
    logic           R256;
    logic           R512;
    logic [10:0]    SCAX;
    logic [ 8:0]    SCBY;
    logic [ 8:0]    SCBX;
    logic [ 3:0]    SGBA;
    logic [ 1:0]    PRY;
    logic [ 1:0]    PRX;
    logic [ 3:0]    CSP;
    logic [10:0]    SX;
    logic [11:0]    SY;
    logic [18:0]    SA;
    logic [17:0]    KA;
    logic [10:0]    DX;
    logic [11:0]    DY;
    logic [18:0]    DA;
    logic [10:0]    NX;
    logic [11:0]    NY;
    logic [11:0]    MJ;
    logic [11:0]    MI;
    logic [18:0]    NA;
    logic           DIY;
    logic           DIX;
    logic           NEQ;
    logic           MAJ;
    logic           TP;
    logic [ 3:0]    LO;
    logic [15:0]    WM;
    logic [15:0]    FC;
    logic [15:0]    BC;
    logic [ 3:0]    OP;
    logic           AYM;
    logic           AYE;
    logic           AXM;
    logic           AXE;


    modport CPU ( output    SRS,    MCS,
                            CVWA,   CVWAIH, CVRA,   CVRAIH,
                            DSPM,   DCKM,   XIMM,   CLRM,
                            C25M,   EO,     ILM,    HSCN,
                            DISP,   SPD,    YSE,    DMAE,
                            IECE,   IEH,    IEV,
                            IEHM,   IL,     IX,
                            PLT,    YAE,    PLTAIH, PLTM,
                            PLTA,   PLTP,
                            BDC,
                            SCAY,   R256,   R512,   SCAX,
                            SCBY,   SCBX,
                            SGBA,
                            PRY,    PRX,
                            CSP,
                            SX,     SY,     SA,     KA,
                            DX,     DY,     DA,
                            NX,     NY,     MJ,     MI,     NA,
                            DIY,    DIX,    NEQ,    MAJ,
                            TP,     LO,
                            WM,
                            FC,     BC,
                            OP,     AYM,    AYE,    AXM,    AXE
                );
    modport VDP ( input     SRS,    MCS,
                            CVWA,   CVWAIH, CVRA,   CVRAIH,
                            DSPM,   DCKM,   XIMM,   CLRM,
                            C25M,   EO,     ILM,    HSCN,
                            DISP,   SPD,    YSE,    DMAE,
                            IECE,   IEH,    IEV,
                            IEHM,   IL,     IX,
                            PLT,    YAE,    PLTAIH, PLTM,
                            PLTA,   PLTP,
                            BDC,
                            SCAY,   R256,   R512,   SCAX,
                            SCBY,   SCBX,
                            SGBA,
                            PRY,    PRX,
                            CSP,
                            SX,     SY,     SA,     KA,
                            DX,     DY,     DA,
                            NX,     NY,     MJ,     MI,     NA,
                            DIY,    DIX,    NEQ,    MAJ,
                            TP,     LO,
                            WM,
                            FC,     BC,
                            OP,     AYM,    AYE,    AXM,    AXE
                );
endinterface

/***************************************************************
 * P#2 CPU->VDP I/F
 ***************************************************************/
interface T9990_P2_CPU_TO_VDP_IF;
    logic       REQ;
    logic [7:0] DATA;
    logic       ACK;

    modport CPU (   output  DATA, ACK,
                    input   REQ
                );
    modport VDP (   input  DATA, ACK,
                    output REQ
                );
endinterface

/***************************************************************
 * P#2 VDP->CPU I/F
 ***************************************************************/
interface T9990_P2_VDP_TO_CPU_IF;
    logic       ACK;
    logic       REQ;
    logic [7:0] DATA;

    modport CPU (   output  ACK,
                    input   REQ, DATA
                );
    modport VDP (   input   ACK,
                    output  REQ, DATA
                );
endinterface

/***************************************************************
 * P#1 PALETTE I/F
 ***************************************************************/
interface T9990_PALETTE_IF;
    logic           W_STROBE;
    logic [5:0]     W_ADDR;
    logic [1:0]     W_PTR;
    logic [5:0]     W_DATA;
    logic           W_ACK;

    logic           R_STROBE;
    logic [5:0]     R_ADDR;
    logic [1:0]     R_PTR;
    logic [5:0]     R_DATA;
    logic           R_ACK;

    modport PAL (
                    input   W_STROBE, W_ADDR, W_PTR, W_DATA,
                    output  W_ACK,
                    input   R_STROBE, R_ADDR, R_PTR,
                    output  R_DATA, R_ACK
                );
    modport CPU(
                    output  W_STROBE, W_ADDR, W_PTR, W_DATA,
                    input   W_ACK,
                    output  R_STROBE, R_ADDR, R_PTR,
                    input   R_DATA, R_ACK
                );
endinterface

/***************************************************************
 * I/O ポートモジュール
 ***************************************************************/
module T9990_PORT (
    input wire              RESET_n,
    input wire              CLK,

    input wire              CSR_n,
    input wire              CSW_n,
    input wire [3:0]        MODE,
    input wire [7:0]        CD_IN,
    output reg [7:0]        CD_OUT,
    output wire             INT0_n,
    output wire             INT1_n,
    output reg              WAIT_n,

    //
    T9990_CPU_MEM_IF.CPU            CPU_MEM,
    T9990_P2_CPU_TO_VDP_IF.CPU      P2_CPU_TO_VDP,
    T9990_P2_VDP_TO_CPU_IF.CPU      P2_VDP_TO_CPU,
    T9990_STATUS_IF.CPU             STATUS,
    T9990_REGISTER_IF.CPU           REG,
    T9990_PALETTE_IF.CPU            PAL,

    //
    output reg              CMD_START
);

    /***************************************************************
     * レジスタ
     ***************************************************************/
    reg          srs_ff;            // P7.SRS
    reg          mcs_ff;            // P7.MCS
    reg [7:0]    vdp_reg[0:63];     // R#0~#63

    assign REG.SRS  = srs_ff;
    assign REG.MCS  = mcs_ff;

    assign REG.CVWA = {vdp_reg[2][2:0],vdp_reg[1],vdp_reg[0]};
    assign REG.CVWAIH = vdp_reg[2][7];
    assign REG.CVRA = {vdp_reg[5][2:0],vdp_reg[4],vdp_reg[3]};
    assign REG.CVRAIH = vdp_reg[5][7];
    assign REG.DSPM =  vdp_reg[ 6][7:6];
    assign REG.DCKM =  vdp_reg[ 6][5:4];
    assign REG.XIMM =  vdp_reg[ 6][3:2];
    assign REG.CLRM =  vdp_reg[ 6][1:0];
    assign REG.C25M =  vdp_reg[ 7][  7];
    assign REG.EO   =  vdp_reg[ 7][  2];
    assign REG.ILM  =  vdp_reg[ 7][  1];
    assign REG.HSCN =  vdp_reg[ 7][  0];
    assign REG.DISP =  vdp_reg[ 8][  7];
    assign REG.SPD  =  vdp_reg[ 8][  6];
    assign REG.YSE  =  vdp_reg[ 8][  5];
    assign REG.DMAE =  vdp_reg[ 8][  2];
    assign REG.IECE =  vdp_reg[ 9][  2];
    assign REG.IEH  =  vdp_reg[ 9][  1];
    assign REG.IEV  =  vdp_reg[ 9][  0];
    assign REG.IEHM =  vdp_reg[11][  7];
    assign REG.IL   = {vdp_reg[11][1:0], vdp_reg[10][7:0]};
    assign REG.IX   =  vdp_reg[12][3:0];
    assign REG.PLT  =  vdp_reg[13][3:0];
    assign REG.PLTA =  vdp_reg[14][7:2];
    assign REG.PLTP =  vdp_reg[14][1:0];
    assign REG.PLTAIH =  vdp_reg[13][  4];
    assign REG.YAE  =  vdp_reg[13][  5];
    assign REG.PLTM =  vdp_reg[13][7:6];
    assign REG.BDC  =  vdp_reg[15][5:0];
    assign REG.SCAY = {vdp_reg[18][4:0], vdp_reg[17][7:0]};
    assign REG.R256 =  vdp_reg[18][  6];
    assign REG.R512 =  vdp_reg[18][  7];
    assign REG.SCAX = {vdp_reg[20][7:0], vdp_reg[19][2:0]};
    assign REG.SCBY = {vdp_reg[22][  0], vdp_reg[21][7:0]};
    assign REG.SCBX = {vdp_reg[24][5:0], vdp_reg[23][2:0]};
    assign REG.SGBA =  vdp_reg[25][3:0];
    assign REG.PRY  =  vdp_reg[27][3:2];
    assign REG.PRX  =  vdp_reg[27][1:0];
    assign REG.CSP  =  vdp_reg[28][3:0];
    assign REG.SX   = {vdp_reg[33][2:0], vdp_reg[32][7:0]};
    assign REG.SY   = {vdp_reg[35][3:0], vdp_reg[34][7:0]};
    assign REG.SA   = {vdp_reg[35][2:0], vdp_reg[34][7:0], vdp_reg[32][7:0]};
    assign REG.KA   = {vdp_reg[35][1:0], vdp_reg[34][7:0], vdp_reg[32][7:0]};
    assign REG.DX   = {vdp_reg[37][2:0], vdp_reg[36][7:0]};
    assign REG.DY   = {vdp_reg[39][3:0], vdp_reg[38][7:0]};
    assign REG.DA   = {vdp_reg[39][2:0], vdp_reg[38][7:0], vdp_reg[36][7:0]};
    assign REG.NX   = {vdp_reg[41][2:0], vdp_reg[40][7:0]};
    assign REG.NY   = {vdp_reg[43][3:0], vdp_reg[42][7:0]};
    assign REG.MJ   = {vdp_reg[41][3:0], vdp_reg[40][7:0]};
    assign REG.MI   = {vdp_reg[43][3:0], vdp_reg[42][7:0]};
    assign REG.NA   = {vdp_reg[43][2:0], vdp_reg[42][7:0], vdp_reg[40][7:0]};
    assign REG.DIY  =  vdp_reg[44][  3];
    assign REG.DIX  =  vdp_reg[44][  2];
    assign REG.NEQ  =  vdp_reg[44][  1];
    assign REG.MAJ  =  vdp_reg[44][  0];
    assign REG.TP   =  vdp_reg[45][  4];
    assign REG.LO   =  vdp_reg[45][3:0];
    assign REG.WM   = {vdp_reg[47][7:0], vdp_reg[46][7:0]};
    assign REG.FC   = {vdp_reg[49][7:0], vdp_reg[48][7:0]};
    assign REG.BC   = {vdp_reg[51][7:0], vdp_reg[50][7:0]};
    assign REG.OP   =  vdp_reg[52][7:4];
    assign REG.AYM  =  vdp_reg[52][  3];
    assign REG.AYE  =  vdp_reg[52][  2];
    assign REG.AXM  =  vdp_reg[52][  1];
    assign REG.AXE  =  vdp_reg[52][  0];

    /***************************************************************
     * CSR/CSW
     ***************************************************************/
    logic prev_csw_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_csw_n <= 1;
        else         prev_csw_n <= CSW_n;
    end
    wire det_w = prev_csw_n && !CSW_n;

    logic prev_csr_n;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) prev_csr_n <= 1;
        else         prev_csr_n <= CSR_n;
    end
    wire det_r = prev_csr_n && !CSR_n;

    /***************************************************************
     * WAIT_n
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                             WAIT_n <= 1;
        else if(vram_cd_update)                  WAIT_n <= 1;                                           // P#0 read/write done
        else if(palette_cd_update)               WAIT_n <= 1;                                           // P#1 read/write done
        else if((det_w | det_r) && MODE == 4'h0) WAIT_n <= 0;//(REG.DSPM == T9990_REG::DSPM_STANDBY);       // P#0 read/write start
        else if((det_w | det_r) && MODE == 4'h1) WAIT_n <= 0;                                           // P#1 read/write start
    end

    /***************************************************************
     * CD_OUT
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                                                 CD_OUT <= 8'hFF;
        else if(vram_cd_update)                                      CD_OUT <= vram_cd_data;    // P#0 read
        else if(palette_cd_update)                                   CD_OUT <= palette_cd_data; // P#1 read
        else if(det_r && MODE == 4'h2)                               CD_OUT <= p2_cd_data;      // P#2 read
        else if(det_r && MODE == 4'h5)                               CD_OUT <= p5_cd_data;      // P#5 read 
        else if(det_r && MODE == 4'h6)                               CD_OUT <= p6_cd_data;      // P#6 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd53) CD_OUT <= STATUS.BX[7:0];  // R#53 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd54) CD_OUT <= {5 'b00000, STATUS.BX[2:0]}; // R#54 read
        else if(det_r && MODE == 4'h3)                               CD_OUT <= vdp_reg[port4_regnum[5:0]];     // R#n read
/*
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd 6) CD_OUT <= vdp_reg[ 6];     // R#6 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd 7) CD_OUT <= vdp_reg[ 7];     // R#7 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd 8) CD_OUT <= vdp_reg[ 8];     // R#8 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd 9) CD_OUT <= vdp_reg[ 9];     // R#9 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd10) CD_OUT <= vdp_reg[10];     // R#10 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd11) CD_OUT <= vdp_reg[11];     // R#11 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd12) CD_OUT <= vdp_reg[12];     // R#12 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd15) CD_OUT <= vdp_reg[15];     // R#15 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd16) CD_OUT <= vdp_reg[16];     // R#16 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd17) CD_OUT <= vdp_reg[17];     // R#17 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd18) CD_OUT <= vdp_reg[18];     // R#18 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd19) CD_OUT <= vdp_reg[19];     // R#19 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd20) CD_OUT <= vdp_reg[20];     // R#20 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd21) CD_OUT <= vdp_reg[21];     // R#21 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd22) CD_OUT <= vdp_reg[22];     // R#22 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd23) CD_OUT <= vdp_reg[23];     // R#23 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd24) CD_OUT <= vdp_reg[24];     // R#24 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd25) CD_OUT <= vdp_reg[25];     // R#25 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd26) CD_OUT <= vdp_reg[26];     // R#26 read
        else if(det_r && MODE == 4'h3 && port4_regnum[5:0] == 6'd27) CD_OUT <= vdp_reg[27];     // R#27 read
*/
        else if(det_r)                                               CD_OUT <= 8'hFF;           // default
    end

    /***************************************************************
     * P#0 VRAM R/W
     ***************************************************************/
    enum logic [2:0] {
        VRAM_IDLE,
        VRAM_WRITE_WAIT_ACK,
        VRAM_WRITE_WAIT_BUSY,
        VRAM_READ_WAIT_ACK,
        VRAM_READ_WAIT_BUSY
    } vram_state;

    logic vram_cd_update;
    logic [7:0] vram_cd_data;
    wire [18:0] vram_r_addr = REG.CVRA;
    wire [18:0] vram_w_addr = REG.CVWA;
    wire [18:0] vram_r_addr_inc = vram_r_addr + 1'd1;
    wire [18:0] vram_w_addr_inc = vram_w_addr + 1'd1;

    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            vram_state <= VRAM_IDLE;
            vram_cd_update <= 0;
            vram_cd_data <= 0;
            CPU_MEM.OE_n <= 1;
            CPU_MEM.WE_n <= 1;
            CPU_MEM.ADDR <= 0;
            CPU_MEM.DIN <= 0;
        end
        else if(vram_state == VRAM_IDLE) begin
            vram_cd_update <= 0;

            //if(REG.DSPM != T9990_REG::DSPM_STANDBY) begin
                if(MODE == 4'h0 && det_w) begin
                    vram_state <= VRAM_WRITE_WAIT_ACK;
                    CPU_MEM.WE_n <= 0;
                    CPU_MEM.OE_n <= 1;
                    CPU_MEM.ADDR <= vram_w_addr[18:0];
                    CPU_MEM.DIN <= CD_IN;
                end

                else if(MODE == 4'h0 && det_r) begin
                    vram_state <= VRAM_READ_WAIT_ACK;
                    CPU_MEM.WE_n <= 1;
                    CPU_MEM.OE_n <= 0;
                    CPU_MEM.ADDR <= vram_r_addr[18:0];
                    CPU_MEM.DIN <= 0;
                end
            //end
        end

        else if(vram_state == VRAM_WRITE_WAIT_ACK) begin
            if(CPU_MEM.BUSY) begin
                CPU_MEM.WE_n <= 1;
                vram_state <= VRAM_WRITE_WAIT_BUSY;
            end
        end

        else if(vram_state == VRAM_WRITE_WAIT_BUSY) begin
            if(!CPU_MEM.BUSY) begin
                vram_state <= VRAM_IDLE;
                vram_cd_update <= 1;
                vram_cd_data <= vram_cd_data;
            end
        end

        else if(vram_state == VRAM_READ_WAIT_ACK) begin
            if(CPU_MEM.BUSY) begin
                CPU_MEM.OE_n <= 1;
                vram_state <= VRAM_READ_WAIT_BUSY;
            end
        end

        else if(vram_state == VRAM_READ_WAIT_BUSY) begin
            if(!CPU_MEM.BUSY) begin
                vram_state <= VRAM_IDLE;
                vram_cd_update <= 1;
                vram_cd_data <= CPU_MEM.DOUT;
            end
        end
    end

    /***************************************************************
     * P#1 PALETTE R/W
     ***************************************************************/
    logic [7:0] palette_cd_data;
    logic palette_cd_update;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            PAL.W_DATA <= 0;
            PAL.W_ADDR <= 0;
            PAL.W_PTR <= 0;
            PAL.W_STROBE <= 0;
            PAL.R_ADDR <= 0;
            PAL.R_PTR <= 0;
            PAL.R_STROBE <= 0;
            palette_cd_data <= 0;
            palette_cd_update <= 0;
        end

        // 書き込み完了チェック
        else if(PAL.W_STROBE) begin
            if(PAL.W_ACK) begin
                PAL.W_STROBE <= 0;
                palette_cd_update <= 1;
            end
        end

        // 読み出し完了チェック
        else if(PAL.R_STROBE) begin
            if(PAL.R_ACK) begin
                PAL.R_STROBE <= 0;
                palette_cd_data <= { PAL.R_DATA[5], 2'b00, PAL.R_DATA[4:0] };
                palette_cd_update <= 1;
            end
        end

        // P#1 ライトチェック
        else if(det_w && MODE == 4'h1) begin
            PAL.W_DATA <= {CD_IN[7], CD_IN[4:0]};
            PAL.W_ADDR <= REG.PLTA;
            PAL.W_PTR <= REG.PLTP;
            PAL.W_STROBE <= 1;
            palette_cd_update <= 0;
        end

        // P#1 リードチェック
        else if(det_r && MODE == 4'h1) begin
            PAL.R_ADDR <= REG.PLTA;
            PAL.R_PTR <= REG.PLTP;
            PAL.R_STROBE <= 1;
            palette_cd_update <= 0;
        end

        else begin
            palette_cd_update <= 0;
        end
    end

    /***************************************************************
     * P#2 VDP DATA R/W
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            P2_CPU_TO_VDP.DATA <= 0;
            P2_CPU_TO_VDP.ACK <= 0;
        end
        else if(P2_CPU_TO_VDP.REQ && !P2_CPU_TO_VDP.ACK) begin
            if(MODE == 4'h2 && det_w) begin
                P2_CPU_TO_VDP.DATA <= CD_IN;
                P2_CPU_TO_VDP.ACK <= 1;
            end
        end
        else if(!P2_CPU_TO_VDP.REQ && P2_CPU_TO_VDP.ACK) begin
            P2_CPU_TO_VDP.ACK <= 0;
        end
    end

    logic [7:0] p2_cd_data;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            P2_VDP_TO_CPU.ACK <= 0;
        end
        else if(P2_VDP_TO_CPU.REQ && !P2_VDP_TO_CPU.ACK) begin
            p2_cd_data <= P2_VDP_TO_CPU.DATA;
            if(MODE == 4'h2 && det_r) begin
                P2_VDP_TO_CPU.ACK <= 1;
            end
        end
        else if(!P2_VDP_TO_CPU.REQ && P2_VDP_TO_CPU.ACK) begin
            P2_VDP_TO_CPU.ACK <= 0;
        end
    end

    /***************************************************************
     * P#3 write / VDP register value update
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
//`define DEBUG
`ifdef DEBUG
            vdp_reg[ 0] <= 0;
            vdp_reg[ 1] <= 0;
            vdp_reg[ 2] <= 0;
            vdp_reg[ 3] <= 0;
            vdp_reg[ 4] <= 0;
            vdp_reg[ 5] <= 0;
            vdp_reg[ 6] <= { T9990_REG::DSPM_P1, T9990_REG::DCKM_DIV4, T9990_REG::XIMM_256, T9990_REG::CLRM_4BPP };
            vdp_reg[ 7] <= { 1'b0, T9990_REG::C25M_OTHER, 1'b0, 1'b0, 1'b0, T9990_REG::EO_DISABLE, T9990_REG::IL_DISABLE, T9990_REG::HSCN_LOW};
            vdp_reg[ 8] <= { T9990_REG::DISP_ENABLE, T9990_REG::SPD_ENABLE, T9990_REG::YSE_ENABLE, 1'b0, 1'b0, T9990_REG::DMAE_ENABLE, 2'b00 };
            vdp_reg[ 9] <= 0;
            vdp_reg[10] <= 0;
            vdp_reg[11] <= 0;
            vdp_reg[12] <= 0;
            vdp_reg[13] <= {T9990_REG::PLTM_PALETTE, T9990_REG::YAE_ONLY, T9990_REG::PLTAIH_INC, 4'b0000 };
            vdp_reg[14] <= 0;
            vdp_reg[15] <= 5'd7;
            vdp_reg[16] <= 0;
            vdp_reg[17] <= 0;
            vdp_reg[18] <= 0;
            vdp_reg[19] <= 0;
            vdp_reg[20] <= 0;
            vdp_reg[21] <= 0;
            vdp_reg[22] <= 0;
            vdp_reg[23] <= 0;
            vdp_reg[24] <= 0;
            vdp_reg[25] <= 0;
            vdp_reg[26] <= 0;
            vdp_reg[27] <= 0;
            vdp_reg[28] <= 0;
            vdp_reg[29] <= 0;
            vdp_reg[30] <= 0;
            vdp_reg[31] <= 0;
            vdp_reg[32] <= 8'h00;
            vdp_reg[33] <= 8'h00;
            vdp_reg[34] <= 8'h00;
            vdp_reg[35] <= 8'h00;
            vdp_reg[36] <= 8'h21;
            vdp_reg[37] <= 8'h00;
            vdp_reg[38] <= 8'h10;
            vdp_reg[39] <= 8'h00;
            vdp_reg[40] <= 8'h10;
            vdp_reg[41] <= 8'h00;
            vdp_reg[42] <= 8'h02;
            vdp_reg[43] <= 8'h00;
            vdp_reg[44] <= 0;
            vdp_reg[45] <= 8'b000_0_1100;
            vdp_reg[46] <= 8'hFF;
            vdp_reg[47] <= 8'hFF;
            vdp_reg[48] <= 0;
            vdp_reg[49] <= 0;
            vdp_reg[50] <= 0;
            vdp_reg[51] <= 0;
            vdp_reg[52] <= 0;
            vdp_reg[53] <= 0;
            vdp_reg[54] <= 0;
`else
            vdp_reg[ 0] <= 0;
            vdp_reg[ 1] <= 0;
            vdp_reg[ 2] <= 0;
            vdp_reg[ 3] <= 0;
            vdp_reg[ 4] <= 0;
            vdp_reg[ 5] <= 0;
            vdp_reg[ 6] <= 0;
            vdp_reg[ 7] <= 0;
            vdp_reg[ 8] <= 0;
            vdp_reg[ 9] <= 0;
            vdp_reg[10] <= 0;
            vdp_reg[11] <= 0;
            vdp_reg[12] <= 0;
            vdp_reg[13] <= 0;
            vdp_reg[14] <= 0;
            vdp_reg[15] <= 0;
            vdp_reg[16] <= 0;
            vdp_reg[17] <= 0;
            vdp_reg[18] <= 0;
            vdp_reg[19] <= 0;
            vdp_reg[20] <= 0;
            vdp_reg[21] <= 0;
            vdp_reg[22] <= 0;
            vdp_reg[23] <= 0;
            vdp_reg[24] <= 0;
            vdp_reg[25] <= 0;
            vdp_reg[26] <= 0;
            vdp_reg[27] <= 0;
            vdp_reg[28] <= 0;
            vdp_reg[29] <= 0;
            vdp_reg[30] <= 0;
            vdp_reg[31] <= 0;
            vdp_reg[32] <= 0;
            vdp_reg[33] <= 0;
            vdp_reg[34] <= 0;
            vdp_reg[35] <= 0;
            vdp_reg[36] <= 0;
            vdp_reg[37] <= 0;
            vdp_reg[38] <= 0;
            vdp_reg[39] <= 0;
            vdp_reg[40] <= 0;
            vdp_reg[41] <= 0;
            vdp_reg[42] <= 0;
            vdp_reg[43] <= 0;
            vdp_reg[44] <= 0;
            vdp_reg[45] <= 0;
            vdp_reg[46] <= 0;
            vdp_reg[47] <= 0;
            vdp_reg[48] <= 0;
            vdp_reg[49] <= 0;
            vdp_reg[50] <= 0;
            vdp_reg[51] <= 0;
            vdp_reg[52] <= 0;
            vdp_reg[53] <= 0;
            vdp_reg[54] <= 0;
`endif
        end

        // P#0 write
        else if(det_w && MODE == 4'h0) begin
            if(!REG.CVWAIH) begin
                vdp_reg[0] <= vram_w_addr_inc[7:0];
                vdp_reg[1] <= vram_w_addr_inc[15:8];
                vdp_reg[2][2:0] <= vram_w_addr_inc[18:16];
            end
        end

        // P#0 read
        else if(det_r && MODE == 4'h0) begin
            // inc vram address
            if(!REG.CVRAIH) begin
                vdp_reg[3] <= vram_r_addr_inc[7:0];
                vdp_reg[4] <= vram_r_addr_inc[15:8];
                vdp_reg[5][2:0] <= vram_r_addr_inc[18:16];
            end
        end

        // P#1 read/write
        else if((det_w | det_r) && MODE == 4'h1) begin
            if(det_w || !REG.PLTAIH) begin
                if(REG.PLTP == T9990_REG::PLTP_B) begin
                    vdp_reg[14][1:0] <= T9990_REG::PLTP_R;
                    vdp_reg[14][7:2] <= REG.PLTA + 1'd1;
                end
                else begin
                    vdp_reg[14][1:0] <= REG.PLTP + 1'd1;
                end
            end
        end

        // P#3 write
        else if( det_w && MODE == 4'h3) begin
            vdp_reg[port4_regnum[5:0]] <= CD_IN;
        end
    end

    /***************************************************************
     * P#4 VDP REGISTER NUMBER write
     ***************************************************************/
    logic [7:0] port4_regnum;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n)                   port4_regnum <= 0;
        else if(det_w && MODE == 4'h3) port4_regnum[5:0] <= port4_regnum[7] ? port4_regnum[5:0] : (port4_regnum[5:0] + 1'd1);   // P#3 write
        else if(det_r && MODE == 4'h3) port4_regnum[5:0] <= port4_regnum[6] ? port4_regnum[5:0] : (port4_regnum[5:0] + 1'd1);   // P#3 read
        else if(det_w && MODE == 4'h4) port4_regnum <= CD_IN;                                                                   // P#4 write
    end

    /***************************************************************
     * P#5 STATUS read
     ***************************************************************/
    wire [7:0] p5_cd_data = {
            STATUS.TR,
            STATUS.VR,
            STATUS.HR,
            STATUS.BD,
            1'b0,
            mcs_ff,
            STATUS.EO,
            STATUS.CE
        };

    /***************************************************************
     * P#6 INTERRUPT FLAG read
     ***************************************************************/
    wire [7:0] p6_cd_data = { 5'b00000, CE_save | STATUS.CE, HI_save | STATUS.HI, VI_save | STATUS.VI };

    /***************************************************************
     * P#6 INTERRUPT FLAG write / update
     ***************************************************************/
    assign INT0_n = ((CE_save && REG.IECE) || (VI_save && REG.IEV)) ? 0 : 1;
    assign INT1_n = (HI_save && REG.IEH) ? 0 : 1;
    logic CE_save;
    logic HI_save;
    logic VI_save;
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            CE_save <= 0;
            HI_save <= 0;
            VI_save <= 0;
        end
        else if(MODE == 4'h6 && det_w) begin
            CE_save <= CD_IN[2] ? 0 : CE_save;
            HI_save <= CD_IN[1] ? 0 : HI_save;
            VI_save <= CD_IN[0] ? 0 : VI_save;
        end
        else begin
            CE_save <= CE_save | STATUS.CE_intr;
            HI_save <= HI_save | STATUS.HI;
            VI_save <= VI_save | STATUS.VI;
        end
    end

    /***************************************************************
     * P#7 write
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            srs_ff <= 0;
            mcs_ff <= 0;
        end
        else if(det_w && MODE == 4'h7) begin
            srs_ff <= CD_IN[1];
            mcs_ff <= CD_IN[0];
        end
    end

    /***************************************************************
     * CMD START
     ***************************************************************/
    always_ff @(posedge CLK or negedge RESET_n) begin
        if(!RESET_n) begin
            CMD_START <= 0;
        end
        else if(MODE == 4'h3 && det_w && port4_regnum[5:0] == 6'd52) begin
            CMD_START <= CONFIG::ENABLE_V9990_CMD;
        end
        else begin
            CMD_START <= 0;
        end
    end
endmodule

`default_nettype wire
