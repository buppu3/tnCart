//*************************************************************
// CONFIG::SYNC_CPU_CLK が 1 の時に使用するタイミング制約ファイル
//*************************************************************

//------------------------
// 入力
//------------------------
// 27MHz入力(CLK_27M)
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {CLK_27M}] -add

// 3.58MHz入力
create_clock -name CLK_3_58M -period 279.330 -waveform {0 139.665} [get_ports {CART_CLOCK}] -add

//------------------------
// メイン
//------------------------
// 107.4MHz(CLK_BASE = CLK_3_58M * 30)
create_generated_clock -name CLK_BASE -source [get_ports {CART_CLOCK}] -master_clock CLK_3_58M -divide_by 1 -multiply_by 30 -add [get_nets {CLK_BASE}]

// 21.48MHz(CLK_21M = CLK_BASE / 5)
create_generated_clock -name CLK_21M -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 5 -multiply_by 1 -add [get_nets {CLK_21M}]

// 14.32MHz(DCLK = CLK_BASE / 7.5)
create_generated_clock -name DCLK -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 15 -multiply_by 2 -duty_cycle 10 -offset 9.31 -add [get_nets {Video.DCLK}]

//------------------------
// TMDS
//------------------------
// 134.25MHz(CLK_TMDS_S = CLK_BASE * 5 / 4)
create_generated_clock -name CLK_TMDS_S -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 4 -multiply_by 5 -add [get_nets {CLK_TMDS_S}]

// 26.85MHz(CLK_TMDS_P = CLK_TMDS_S / 5)
create_generated_clock -name CLK_TMDS_P -source [get_nets {CLK_TMDS_S}] -master_clock CLK_TMDS_S -divide_by 5 -multiply_by 1 -add [get_pins {u_clk/u_div_tmds/CLKOUT}]

//------------------------
// I2S
//------------------------
// 1.41MHz(DAC_BCLK = CLK_BASE / 2 / 38)
create_generated_clock -name I2S_BCLK -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 76 -multiply_by 1 -add [get_ports {I2S_BCLK}]

//------------------------
// グループ
//------------------------
set_clock_groups -asynchronous -group [get_clocks {CLK_3_58M}] -group [get_clocks {CLK_BASE CLK_21M}] -group [get_clocks {DCLK}] -group [get_clocks {CLK_TMDS_S CLK_TMDS_P}]
