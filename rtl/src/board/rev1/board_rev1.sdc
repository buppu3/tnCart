// 27MHz入力(CLK_27M)
create_clock -name CLK_27M -period 37.037 -waveform {0 18.518} [get_ports {CLK_27M}] -add

// 135MHz(CLK_TMDS_S)
create_generated_clock -name CLK_TMDS_S -source [get_ports {CLK_27M}] -master_clock CLK_27M -divide_by 1 -multiply_by 5 -add [get_nets {CLK_TMDS_S}]

// 27MHz(CLK_TMDS_P)
create_generated_clock -name CLK_TMDS_P -source [get_nets {CLK_TMDS_S}] -master_clock CLK_TMDS_S -divide_by 5 -multiply_by 1 -add [get_nets {VideoTmds.DCLK}]

// 108MHz(CLK_BASE)
create_generated_clock -name CLK_BASE -source [get_nets {CLK_27M}] -master_clock CLK_27M -divide_by 1 -multiply_by 4 -add [get_nets {CLK_BASE}]

// 21.6MHz(CLK_21M)
create_generated_clock -name CLK_21M -source [get_nets {CLK_BASE}] -divide_by 5 -multiply_by 1 -add [get_nets {Bus.CLK_21M}]

// 10.8MHz(DCLK)
create_generated_clock -name DCLK -source [get_nets {CLK_BASE}] -master_clock CLK_BASE -divide_by 10 -multiply_by 1 -add [get_nets {Video.DCLK}]
set_clock_groups -asynchronous -group {DCLK} -group {CLK_TMDS_P}
