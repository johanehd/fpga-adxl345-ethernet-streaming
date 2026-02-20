library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_eth_debug is
    Port ( 
        clk  : in  STD_LOGIC; 
        reset_btn   : in  STD_LOGIC; 
        send_btn    : in  STD_LOGIC; 
        
        -- PHY ethernet tx mii
        eth_txd     : out STD_LOGIC_VECTOR(3 downto 0);
        eth_tx_en   : out STD_LOGIC;
        eth_ref_clk : out STD_LOGIC;
        eth_rstn    : out STD_LOGIC
    );
end top_eth_debug;

architecture Behavioral of top_eth_debug is

    signal clk_sys     : std_logic; 
    signal pll_locked  : std_logic;
    signal sys_rst_n   : std_logic;

    signal axis_data   : std_logic_vector(7 downto 0);
    signal axis_valid  : std_logic;
    signal axis_ready  : std_logic;
    signal axis_last   : std_logic;

    component clk_wiz_0
    port (
        clk_out1 : out std_logic; -- 25 MHz
        reset    : in  std_logic;
        locked   : out std_logic;
        clk_in1  : in  std_logic
    );
    end component;

begin

    eth_ref_clk <= clk_sys;  -- uncomment for debug mode
    eth_rstn    <= '1';      -- activation PHY
    
    sys_rst_n   <= '0' when (reset_btn = '1' or pll_locked = '0') else '1'; -- rst systeme

    -- PLL 100 -> 25 MHz
    PLL_Inst : clk_wiz_0
    port map (
        clk_in1  => clk,
        clk_out1 => clk_sys,
        reset    => reset_btn,
        locked   => pll_locked
    );

    
    Inst_frame_gen: entity work.frame_gen_debug
        generic map (
            mac_source => x"112233445566",
            mac_dest => x"AABBCCDDEEFF",
            ip_source => x"0A0A0A0A",
            ip_dest => x"0A0A0A01"
        )
        port map (
            clk_i           => clk_sys,
            reset_n_i         => sys_rst_n,
            trigger_i       => send_btn,
            m_axis_tdata_o  => axis_data,
            m_axis_tvalid_o => axis_valid,
            m_axis_tready_i => axis_ready,
            m_axis_tlast_o  => axis_last
        );

    Inst_mii_phy: entity work.mii_phy
        port map (
            clk_i       => clk_sys,
            reset_n_i     => sys_rst_n,
            s_tdata_i     => axis_data,
            s_tvalid_i    => axis_valid,
            s_tready_o    => axis_ready,
            s_tlast_i     => axis_last,
            eth_txd_o   => eth_txd,
            eth_tx_en_o => eth_tx_en
        );

end Behavioral;