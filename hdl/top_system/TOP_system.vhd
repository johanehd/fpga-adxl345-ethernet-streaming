library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_system is
    Port ( 
        clk_100M    : in  std_logic; 
        reset_btn   : in  std_logic; 
        
        -- ADXL345 (Pmod JA)
        ja_sclk     : out std_logic;
        ja_mosi     : out std_logic;
        ja_cs       : out std_logic;
        ja_miso     : in  std_logic;
        
        -- ethernet PHY (MII)
        eth_txd     : out std_logic_vector(3 downto 0);
        eth_tx_en   : out std_logic;
        eth_ref_clk : out std_logic;
        eth_rstn    : out std_logic;
        
        leds        : out std_logic_vector(3 downto 0)
    );
end top_system;

architecture Behavioral of top_system is

    signal clk_25M    : std_logic;
    signal pll_locked : std_logic;
    signal sys_rst_n  : std_logic;

    signal accel_x    : std_logic_vector(15 downto 0);
    signal accel_y    : std_logic_vector(15 downto 0);
    signal accel_z    : std_logic_vector(15 downto 0);
    signal accel_valid : std_logic;

    component clk_wiz_0
    port (
        clk_in1  : in  std_logic;
        clk_out1 : out std_logic; -- 25 MHz
        reset    : in  std_logic;
        locked   : out std_logic
    );
    end component;

begin


    PLL_Inst : clk_wiz_0
    port map (
        clk_in1  => clk_100M,
        clk_out1 => clk_25M,
        reset    => reset_btn,
        locked   => pll_locked
    );

    sys_rst_n <= '0' when (reset_btn = '1' or pll_locked = '0') else '1';

    leds(0) <= pll_locked;

    Inst_ADXL : entity work.top_adxl
    port map (
        clk          => clk_25M,
        reset_n      => sys_rst_n,
        ja_sclk      => ja_sclk,
        ja_mosi      => ja_mosi,
        ja_cs        => ja_cs,
        ja_miso      => ja_miso,
        ax_o         => accel_x,
        ay_o         => accel_y,
        az_o         => accel_z,
        data_valid_o => accel_valid
    );

    Inst_ETH : entity work.top_eth
    port map (
        clk               => clk_25M,
        reset_n           => sys_rst_n,
        trigger_from_adxl => accel_valid,
        ax_i              => accel_x,
        ay_i              => accel_y,
        az_i              => accel_z,
        eth_txd           => eth_txd,
        eth_tx_en         => eth_tx_en,
        eth_ref_clk       => eth_ref_clk,
        eth_rstn          => eth_rstn
    );

end Behavioral;