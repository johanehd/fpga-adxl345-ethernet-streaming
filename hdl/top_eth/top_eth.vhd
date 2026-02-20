library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_eth is
    Port ( 
        clk  : in  std_logic; 
        reset_n   : in  std_logic; 
        
        trigger_from_adxl    : in  STD_LOGIC;
        ax_i         : in std_logic_vector(15 downto 0); 
        ay_i         : in std_logic_vector(15 downto 0);
        az_i         : in std_logic_vector(15 downto 0);
        
        -- PHY ethernet tx mii
        eth_txd     : out STD_LOGIC_VECTOR(3 downto 0);
        eth_tx_en   : out std_logic;
        eth_ref_clk : out std_logic;
        eth_rstn    : out std_logic
    );
end top_eth;

architecture Behavioral of top_eth is


    signal axis_data   : std_logic_vector(7 downto 0);
    signal axis_valid  : std_logic;
    signal axis_ready  : std_logic;
    signal axis_last   : std_logic;

begin

    eth_ref_clk <= clk;     
    eth_rstn    <= '1';      
    
    
    Inst_frame_gen: entity work.frame_gen
        generic map (
            mac_source => x"112233445566",  -- replace with your fpga mac @
            mac_dest => x"AABBCCDDEEFF",    -- replace with your pc mac @ (on your fpga sticker)
            ip_source => x"0A0A0A0A",
            ip_dest => x"0A0A0A01"
        )
        port map (
            clk_i           => clk,
            reset_n_i       => reset_n, 
            trigger_i       => trigger_from_adxl,
            ax_i            => ax_i,
            ay_i            => ay_i,
            az_i            => az_i,
            m_axis_tdata_o  => axis_data,
            m_axis_tvalid_o => axis_valid,
            m_axis_tready_i => axis_ready,
            m_axis_tlast_o  => axis_last
        );

    Inst_mii_phy: entity work.mii_phy
        port map (
            clk_i       => clk,
            reset_n_i     => reset_n,
            s_tdata_i     => axis_data,
            s_tvalid_i    => axis_valid,
            s_tready_o    => axis_ready,
            s_tlast_i     => axis_last,
            eth_txd_o   => eth_txd,
            eth_tx_en_o => eth_tx_en
        );

end Behavioral;