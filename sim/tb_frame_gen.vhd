library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_frame_gen is
end tb_frame_gen;

architecture sim of tb_frame_gen is

    signal clk            : std_logic := '0';
    signal reset_n          : std_logic := '0';
    signal trigger        : std_logic := '0';
    
    signal ax_i           : std_logic_vector(15 downto 0) := (others => '0');
    signal ay_i           : std_logic_vector(15 downto 0) := (others => '0');
    signal az_i           : std_logic_vector(15 downto 0) := (others => '0');

    signal m_axis_tdata   : std_logic_vector(7 downto 0);
    signal m_axis_tvalid  : std_logic;
    signal m_axis_tready  : std_logic := '0';
    signal m_axis_tlast   : std_logic;

    constant clk_period : time := 40 ns; 

begin

    uut: entity work.frame_gen
        generic map (
            mac_source => x"001122334455",
            mac_dest   => x"AABBCCDDEEFF",
            ip_source  => x"0A0A0A0A", 
            ip_dest    => x"0A0A0A01", 
            payload_size => 6
        )
        port map (
            clk_i           => clk,
            reset_n_i         => reset_n,
            trigger_i       => trigger,

            ax_i            => ax_i,
            ay_i            => ay_i,
            az_i            => az_i,
            m_axis_tdata_o  => m_axis_tdata,
            m_axis_tvalid_o => m_axis_tvalid,
            m_axis_tready_i => m_axis_tready,
            m_axis_tlast_o  => m_axis_tlast
        );


    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;


    stim_proc: process
    begin        
        reset_n <= '0';
        trigger <= '0';
        m_axis_tready <= '0';
        -- initializing sensor data
        ax_i <= x"1234"; 
        ay_i <= x"5678";
        az_i <= x"9ABC";
        
        wait for 100 ns;    
        reset_n <= '1';
        wait for 50 ns;


        report "Starting Test 1: normal transmission ";
        m_axis_tready <= '1'; -- receiver is ready
        wait until rising_edge(clk);
        trigger <= '1';       -- start generation
        wait until rising_edge(clk);
        trigger <= '0';

        -- wait for the end of the frame (tlast handshake)
        wait until m_axis_tlast = '1' and m_axis_tvalid = '1' and m_axis_tready = '1';
        wait until rising_edge(clk);
        report " Test 1 Complete: packet sent ";
        
        wait for 200 ns;


        -- TEST 2: Backpressure Simulation 

        report " Starting Test 2: Backpressure Simulation ";
        -- changing sensor data to see if latching works
        ax_i <= x"AAAA"; 
        ay_i <= x"BBBB";
        az_i <= x"CCCC";
        
        trigger <= '1';
        wait for clk_period;
        trigger <= '0';

        -- wait until we are midway through the Ethernet Header
        wait for 160 ns; 
        
        -- simulate the mii_phy becoming busy
        wait until rising_edge(clk);
        m_axis_tready <= '0';
        report "mii driver busy (Ready=0), frame_gen output should freeze !!!";
        wait for 400 ns; 

        -- resume transmission
        wait until rising_edge(clk);
        m_axis_tready <= '1';
        report " mii driver ready (Ready=1) - frame_gen can resume the transmission ";


        wait until m_axis_tlast = '1' and m_axis_tvalid = '1' and m_axis_tready = '1';
        wait until rising_edge(clk);
        
        report "### Simulation Successfully Finished ###";
        
        assert false report "Simulation reached end of file" severity failure;
        wait;
    end process;

end sim;