--
-- Simple Testbench
-- YM-2149 / AY-3-8910 Complex Sound Generator
-- Matthew Hagerty
-- June 2020
-- https://dnotq.io
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ym2149 is
end tb_ym2149;

architecture behavior of tb_ym2149 is

   -- Unit Under Test (UUT)
   component ym2149_audio
   port
   ( clk_i        : in     std_logic
   ; en_clk_psg_i : in     std_logic
   ; sel_n_i      : in     std_logic
   ; reset_n_i    : in     std_logic
   ; bc_i         : in     std_logic
   ; bdir_i       : in     std_logic
   ; data_i       : in     std_logic_vector(7 downto 0)
   ; data_r_o     : out    std_logic_vector(7 downto 0)
   ; ch_a_o       : out    unsigned(11 downto 0)
   ; ch_b_o       : out    unsigned(11 downto 0)
   ; ch_c_o       : out    unsigned(11 downto 0)
   ; mix_audio_o  : out    unsigned(13 downto 0)
   ; pcm14s_o     : out    unsigned(13 downto 0)
   );
   end component;


   -- Inputs
   signal clk_i         : std_logic := '0';
   signal en_clk_psg_i  : std_logic := '0';
   signal sel_n_i       : std_logic := '0';
   signal reset_n_i     : std_logic := '0';
   signal bc_i          : std_logic := '0';
   signal bdir_i        : std_logic := '0';
   signal data_i        : std_logic_vector(7 downto 0) := (others => '0');

   --Outputs
   signal data_r_o      : std_logic_vector(7 downto 0);
   signal ch_a_o        : unsigned(11 downto 0);
   signal ch_b_o        : unsigned(11 downto 0);
   signal ch_c_o        : unsigned(11 downto 0);
   signal mix_audio_o   : unsigned(13 downto 0);
   signal pcm14s_o      : unsigned(13 downto 0);

   -- Clock period definitions
   constant clk_i_period : time := 46.560852 ns;

   signal clk_psg_r : unsigned(2 downto 0) := "000";

begin


   -- Instantiate the Unit Under Test (UUT)
   uut: ym2149_audio
   port map
   ( clk_i        => clk_i
   , en_clk_psg_i => en_clk_psg_i
   , sel_n_i      => sel_n_i
   , reset_n_i    => reset_n_i
   , bc_i         => bc_i
   , bdir_i       => bdir_i
   , data_i       => data_i
   , data_r_o     => data_r_o
   , ch_a_o       => ch_a_o
   , ch_b_o       => ch_b_o
   , ch_c_o       => ch_c_o
   , mix_audio_o  => mix_audio_o
   , pcm14s_o     => pcm14s_o
   );


   -- Clock process definitions
   clk_i_process :process
   begin
      clk_i <= '1';
      wait for clk_i_period/2;
      clk_i <= '0';
      wait for clk_i_period/2;
   end process;

   en_clk_psg_i_process :process ( clk_i )
   begin
      if rising_edge(clk_i) then
         if clk_psg_r = 5 then
            clk_psg_r <= "000";
         else
            clk_psg_r <= clk_psg_r + 1;
         end if;

         if clk_psg_r = 2 then
            en_clk_psg_i <= '1';
         else
            en_clk_psg_i <= '0';
         end if;
      end if;
   end process;


   -- Stimulus process
   stim_proc: process
   begin
      sel_n_i   <= '0';
      reset_n_i <= '0';
      bc_i      <= '0';
      bdir_i    <= '0';
      data_i    <= x"00";
      wait for clk_i_period*6*12;
      reset_n_i <= '1';
      wait for clk_i_period*2*12;
      -- insert stimulus here

      wait for clk_i_period*32*12;


      -- See the PSG datasheet for programming details.
      -- Set up channels A, B, C for tone output, constant amplitude.

      -- Channel A
      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"00"; -- R0 (Channel A low 8-bits of tone counter).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"20"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"08"; -- R8 (Channel A amplitude).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"0F"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      -- Channel B
      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"02"; -- R2 (Channel B low 8-bits of tone counter).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"38"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"09"; -- R9 (Channel B amplitude).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"0A"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      -- Channel C
      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"04"; -- R4 (Channel C low 8-bits of tone counter).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"42"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"0A"; -- R10 (Channel C amplitude).
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"07"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;



      -- Mixer Settings, enable tones without noise.
      -- Latch the register address.
      wait for 150 ns;
      bc_i   <= '1';
      bdir_i <= '1';
      data_i <= x"07"; -- R7, mixer control
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;

      -- Write a value to the register.
      wait for 150 ns;
      bc_i   <= '0';
      bdir_i <= '1';
      data_i <= x"38"; -- register value
      wait for 300 ns;
      bc_i   <= '0';
      bdir_i <= '0';
      wait for 150 ns;


      wait;
   end process;

end;
