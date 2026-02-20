library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_spi_master is
end tb_spi_master;

architecture sim of tb_spi_master is
    constant c_clk_period : time := 10 ns;
    
    signal clk_i      : std_logic := '0';
    signal reset_n_i  : std_logic := '0';
    signal start_i    : std_logic := '0';
    signal data_in    : std_logic_vector(7 downto 0) := x"00";
    signal data_out   : std_logic_vector(7 downto 0) := x"00";
    signal busy_o     : std_logic;
    signal done_o     : std_logic;
    signal spi_sclk_o : std_logic;
    signal spi_mosi_o : std_logic;
    signal spi_miso_i : std_logic := '0';
    signal spi_cs_n_o : std_logic;

begin

    uut: entity work.spi_master
        port map (
            clk_i      => clk_i,
            reset_n_i  => reset_n_i,
            start_i    => start_i,
            last_i     => '1',
            data_in    => data_in,
            data_out   => data_out,
            busy_o     => busy_o,
            done_o     => done_o,
            spi_sclk_o => spi_sclk_o,
            spi_mosi_o => spi_mosi_o,
            spi_miso_i => spi_miso_i,
            spi_cs_n_o => spi_cs_n_o
        );

      clk_process : process
      begin
        clk_i <= '0';
        wait for c_clk_period/2;
        clk_i <= '1';
        wait for c_clk_period/2;
      end process;

    -- slave emulation injects 0xB1 on MISO
    process
        variable v_to_send : std_logic_vector(7 downto 0) := x"B1"; 
    begin
        spi_miso_i <= '0';
        wait until falling_edge(spi_cs_n_o); 
        
        for i in 7 downto 0 loop
            wait until falling_edge(spi_sclk_o); 
            spi_miso_i <= v_to_send(i);
        end loop;
        
        wait until rising_edge(spi_cs_n_o);
    end process;

    -- stimulus process sends 0xD4 via MOSI 
    process
    begin
        reset_n_i <= '0';
        wait for 100 ns;
        reset_n_i <= '1';
        wait for 100 ns;

        wait until falling_edge(clk_i);
        data_in <= x"D4"; 
        start_i <= '1';
        wait until falling_edge(clk_i);
        start_i <= '0';

        wait until rising_edge(done_o);
        
        -- result Verification
        assert (data_out = x"B1")  report "MISO ERROR: Expected B1, received " & to_hstring(data_out) severity error;

        if data_out = x"B1" then
            report "SUCCESS: MOSI sent A5, MISO received B1" severity note;
        end if;

        assert false report "Simulation finished" severity failure;
        wait;
    end process;

end sim;