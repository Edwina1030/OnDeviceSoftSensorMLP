library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;               -- for type conversions
library work;
use work.all;
use work.userlogicinterface.all; 
entity env5_top_reconfig is
port (
clk_100m     : in std_logic;
spi_clk      : in std_logic;
spi_ss_n     : in std_logic;
spi_mosi     : in std_logic;
spi_miso     : out std_logic;
fpga_busy    : out std_logic;
leds         : out std_logic_vector(3 downto 0)
);
end env5_top_reconfig;
architecture rtl of env5_top_reconfig is
    signal reset : std_logic := '0';
    signal spi_reset_n : std_logic := '0';
    type buf_t is array (0 to 13) of std_logic_vector(7 downto 0);
    signal data_buf : buf_t := (x"ee", x"dd", x"cc", x"bb", x"aa", x"99", x"88", x"77", x"66", x"55", x"44", x"33", x"22", x"11");
    signal sram_address : std_logic_vector(15 downto 0);
    signal sram_data_in, sram_data_out : std_logic_vector(7 downto 0);
    signal sram_wr, sram_rd : std_logic;
    signal spi_miso_s : std_logic;
    signal mw_leds : std_logic_vector(3 downto 0);
    signal mw_flash_unavailable : std_logic; -- '1' means can be use by the FPGA, '0' means it is hold by the MCU
    -- signals for user logic
    signal userlogic_reset, userlogic_rd, userlogic_wr : std_logic;
    signal userlogic_data_in : std_logic_vector(7 downto 0);
    signal userlogic_data_out : std_logic_vector(7 downto 0);
    signal userlogic_address : std_logic_vector(15 downto 0);
    signal userlogic_clock, userlogic_busy, userlogic_wake_up: std_logic;
    signal userlogic_led_ctrl: std_logic_vector(3 downto 0);
    signal led_debug : std_logic_vector(3 downto 0);
    signal sys_clk : std_logic;
begin
--    i_clk_wiz: clk_wiz_0
--    port map(
--            clk_in => clk_100m,
--            clk_out => sys_clk
--    );
    sys_clk <= clk_100m;
    leds(0) <= mw_leds(0);
    leds(1) <= mw_leds(1);
    leds(2) <= mw_leds(2);
    leds(3) <= mw_leds(3);
    fpga_busy <= userlogic_busy;
    --  leds <= led_debug;
    --  rtx_process: process(sys_clk)
    --  variable addr_var : integer range 0 to 20000;
    --  variable var_data : std_logic_vector(7 downto 0);
    --  begin
    --     if userlogic_reset='1' then
    --         led_debug <= (others=>'0');
    --     elsif rising_edge(sys_clk) then
    --          addr_var := to_integer(unsigned(userlogic_address));
            
    --              if userlogic_wr='1' then
    --                 if addr_var=20 then
    --                     led_debug <= userlogic_data_in(3 downto 0);
    --                     var_data := userlogic_data_in;
    --                 end if;
    --              end if;
    --               if userlogic_rd='1' then
    --                 if addr_var=20 then
    --                     userlogic_data_out <= var_data;
    --                 end if;
    --              end if;
    --      end if;
    --  end process rtx_process;
    i_spi_slaver: entity work.spi_slave(rtl)
    port map(
        reset_n => spi_reset_n,
        sclk => spi_clk,
        ss_n => spi_ss_n,
        mosi => spi_mosi,
        miso => spi_miso,
        clk => sys_clk,
        addr => sram_address,
        data_wr => sram_data_in,  -- tx_data,
        data_rd => sram_data_out, -- rx_data,
        we => sram_wr,            -- tx_en,
        re => sram_rd             -- rx_en
    );
    spi_reset_n <= not reset;
    i_middleware: entity work.middleware(rtl)
    port map(
        reset => reset,
        clk => sys_clk,
        -- userlogic
        userlogic_reset => userlogic_reset,
        userlogic_data_in => userlogic_data_in,
        userlogic_data_out => userlogic_data_out,
        userlogic_address => userlogic_address,
        userlogic_rd => userlogic_rd,
        userlogic_wr => userlogic_wr,
        -- debug
        interface_leds => mw_leds,
        -- flash
        flash_unavailable => mw_flash_unavailable,
        -- psram
        sram_address => sram_address,
        sram_data_out => sram_data_out,
        sram_data_in => sram_data_in,
        sram_rd => sram_rd,
        sram_wr => sram_wr
    );
    -- process to delay reset for fsm
	process (sys_clk, reset)
		constant reset_count : integer := 300000; -- 1ms @ 100MHz
		variable count : integer range 0 to reset_count := 0;
	begin
		if reset = '1' then	
			if rising_edge(sys_clk) then
				if count < reset_count then
					count := count + 1;
					reset <= '1';
				else
					reset <= '0';
				end if;
			end if;
		end if;
	end process;
    userlogic_clock <= sys_clk;
    --    ul : entity xil_defaultlib.lstm_cell_skeleton PORT MAP
    ul : entity work.skeleton PORT MAP
        (
        clock => userlogic_clock,
        reset => userlogic_reset, -- H -> reset
        busy => userlogic_busy,
        wake_up => userlogic_wake_up,
        rd => userlogic_rd,
        wr => userlogic_wr,
        data_in => userlogic_data_in,
        address_in => userlogic_address,
        data_out => userlogic_data_out,
        led_ctrl => userlogic_led_ctrl
        );
end rtl;
