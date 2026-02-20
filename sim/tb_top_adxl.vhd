library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_top_adxl is
end tb_top_adxl;

architecture sim of tb_top_adxl is
    signal clk          : std_logic := '0';
    signal reset_n      : std_logic := '0';
    signal ja_sclk      : std_logic;
    signal ja_mosi      : std_logic;
    signal ja_miso      : std_logic := '0';
    signal ja_cs        : std_logic;
    signal uart_tx_pin  : std_logic;
    signal leds         : std_logic_vector(3 downto 0);

    constant clk_period : time := 10 ns; -- 100 MHz
    
    type data_array is array (0 to 5) of std_logic_vector(7 downto 0);
    constant accel_x_y_z : data_array := (x"02", x"01", x"04", x"03", x"06", x"05");

begin

    uut: entity work.top_adxl
        port map (
            clk          => clk,
            reset_n      => reset_n,
            ja_sclk      => ja_sclk,
            ja_mosi      => ja_mosi,
            ja_miso      => ja_miso,
            ja_cs        => ja_cs,
            uart_tx_pin  => uart_tx_pin,
            leds         => leds
        );


    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

   -- adxl emulator
    adxl_emulator : process
        variable v_addr_byte : std_logic_vector(7 downto 0);
        constant C_ID_VAL : std_logic_vector(7 downto 0) := x"E5";
    begin
        loop
            -- wait sof
            wait until falling_edge(ja_cs);
            
            -- read the 8 bit from master (MOSI)
            for i in 7 downto 0 loop
                wait until rising_edge(ja_sclk);
                v_addr_byte(i) := ja_mosi;
            end loop;

            -- analyse and respond via MISO
            if v_addr_byte = x"80" then -- single read ID
                for i in 7 downto 0 loop
                    wait until falling_edge(ja_sclk);
                    ja_miso <= C_ID_VAL(i);
                end loop;
            
            elsif v_addr_byte = x"F2" or v_addr_byte = x"C0" then -- burst read DATAX0
                for byte_idx in 0 to 5 loop
                    for bit_idx in 7 downto 0 loop
                        wait until falling_edge(ja_sclk);
                        ja_miso <= accel_x_y_z(byte_idx)(bit_idx);
                    end loop;
                    if ja_cs = '1' then exit; end if; 
                end loop;
            end if;

            wait until rising_edge(ja_cs);
            ja_miso <= '0';
        end loop;
    end process;

    
    stim_proc: process
    begin        

        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        
        wait for 2 ms; 

        assert false report "End of Simulation" severity failure;
        wait;
    end process;

end sim;