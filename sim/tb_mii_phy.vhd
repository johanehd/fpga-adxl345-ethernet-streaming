library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mii_phy is
end tb_mii_phy;

architecture sim of tb_mii_phy is


    signal clk_i          : std_logic := '0'; 
    signal reset_n_i      : std_logic := '0';
    

    signal s_tdata_i      : std_logic_vector(7 downto 0) := (others => '0');
    signal s_tvalid_i     : std_logic := '0';
    signal s_tready_o     : std_logic;
    signal s_tlast_i      : std_logic := '0';

    signal eth_txd_o      : std_logic_vector(3 downto 0);
    signal eth_tx_en_o    : std_logic;

    constant clk_i_period : time := 40 ns; -- 25 MHz = 40ns period

begin


    uut: entity work.mii_phy
        port map (
            clk_i       => clk_i,
            reset_n_i   => reset_n_i,
            s_tdata_i   => s_tdata_i,
            s_tvalid_i  => s_tvalid_i,
            s_tready_o  => s_tready_o,
            s_tlast_i   => s_tlast_i,
            eth_txd_o   => eth_txd_o,
            eth_tx_en_o => eth_tx_en_o
        );


    clk_i_process : process
    begin
        clk_i <= '0';
        wait for clk_i_period/2;
        clk_i <= '1';
        wait for clk_i_period/2;
    end process;


    stim_proc: process
    begin        

        reset_n_i  <= '0';
        s_tvalid_i <= '0';
        s_tlast_i  <= '0';
        s_tdata_i  <= (others => '0');
        wait for 200 ns;    
        reset_n_i  <= '1';
        wait until rising_edge(clk_i);
        
        report "DEADBEEF Payload";

        
        s_tvalid_i <= '1';
        s_tdata_i  <= x"DE";
        wait until s_tready_o = '1' and rising_edge(clk_i);
        
        s_tdata_i  <= x"AD";
        wait until s_tready_o = '1' and rising_edge(clk_i);

        s_tdata_i  <= x"BE";
        wait until s_tready_o = '1' and rising_edge(clk_i);

        s_tdata_i  <= x"EF";
        s_tlast_i  <= '1';
        
        -- wait for Handshake to complete for the last byte
        wait until rising_edge(clk_i);
        if s_tready_o = '0' then 
            wait until s_tready_o = '1' and rising_edge(clk_i); 
        end if;
        
        -- end of stream
        s_tvalid_i <= '0';
        s_tlast_i  <= '0';
        s_tdata_i  <= x"00";


        wait; 
    end process;

end sim;