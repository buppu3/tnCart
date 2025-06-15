//*************************************************************
// CONFIG::SYNC_CPU_CLK が 1 の時に使用するタイミング制約ファイル
//*************************************************************

//------------------------
// 入力
//------------------------
// 27MHz入力(CLK_27M)
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {CLK_27M}] -add

// 3.579545MHz入力
create_clock -name CLK_3_58M -period 279.365 -waveform {0 139.682} [get_ports {CART_CLOCK}] -add

// SDRAM CLK
create_clock -name CLK_DQ_I -period 9.312 -waveform {0 4.656} [get_pins {u_sdram/u_buf_clk_dq/I}] -add

//------------------------
// メイン
//------------------------
// 214.7727MHz(CLK_215M = CLK_3_58M  * 60)
create_generated_clock -name CLK_215M -source [get_ports {CART_CLOCK}] -master_clock CLK_3_58M -divide_by 1 -multiply_by 60 -add [get_nets {u_clk/clk_215m}]

// 107.38635MHz(CLK_108M = CLK_215M / 2)
create_generated_clock -name CLK_108M -source [get_nets {u_clk/clk_215m}] -divide_by 2 -add [get_nets {u_clk/clk_108m}]

// DQ
create_generated_clock -name CLK_DQ -source [get_pins {u_sdram/u_buf_clk_dq/I}] -master_clock CLK_DQ_I -add [get_pins {u_sdram/u_dqce_dq/CLKOUT}] -offset 0.688

// 42.95454MHz(CLK_43M = CLK_215M / 5)
create_generated_clock -name CLK_43M -source [get_nets {u_clk/clk_215m}] -divide_by 5 -add [get_nets {u_clk/clk_43m}]

// 21.6MHz(CLK_21M = CLK_215M / 10)
create_generated_clock -name CLK_21M -source [get_nets {u_clk/clk_215m}] -divide_by 10 -add [get_nets {u_clk/clk_21m}]

//------------------------
// TMDS
//------------------------
// 135MHz(CLK_TMDS_S = CLK_27M * 5)
create_generated_clock -name CLK_TMDS_S -source [get_nets {CLK_27M}] -master_clock CLK_27M -divide_by 1 -multiply_by 5 -add [get_nets {u_clk/clk_tmds_s}]

// 27MHz(CLK_TMDS_P = CLK_TMDS_S / 5)
create_generated_clock -name CLK_TMDS_P -source [get_nets {u_clk/clk_tmds_s}] -divide_by 5 -multiply_by 1 -add [get_nets {u_clk/clk_tmds_p}]

// 14.4MHz(DCLK = CLK_BASE / 7.5)
//create_generated_clock -name DCLK -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 15 -multiply_by 2 -duty_cycle 10 -offset 9.25 -add [get_nets {Video.DCLK}]

//------------------------
// GAO
//------------------------
//create_clock -name tck_pad_i -period 200 -waveform {0 100} [get_ports {tck_pad_i}]

//------------------------
// グループ
//------------------------
set_clock_groups -asynchronous /*-group [get_clocks {tck_pad_i}]*/ -group [get_clocks {CLK_3_58M}] -group [get_clocks {CLK_215M}] -group [get_clocks {CLK_108M CLK_43M CLK_21M}] /*-group [get_clocks {DCLK}]*/ -group [get_clocks {CLK_TMDS_S CLK_TMDS_P}]
