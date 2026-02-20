library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_adxl_debug is
    Port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        ja_sclk      : out std_logic;
        ja_mosi      : out std_logic;
        ja_cs        : out std_logic;
        ja_miso      : in  std_logic;
        
        
        -- debug ports uart & leds 
        uart_tx_pin  : out std_logic;
        leds         : out std_logic_vector(3 downto 0) -- debug leds
        
        -- data outputs & data valid (comment for debug mode(arty_a7_adxl_debug.xdc))
        
        -- ax_o         : out std_logic_vector(15 downto 0); 
        -- ay_o         : out std_logic_vector(15 downto 0);
        -- az_o         : out std_logic_vector(15 downto 0);
        -- data_valid_o : out std_logic -- trigger for eth
    );
end top_adxl_debug;

architecture Behavioral of top_adxl_debug is

    signal pll_reset : std_logic;
    
    -- frequency configuration
    constant c_clk_freq_hz : integer := 25_000_000; --must match the actual clock frequency
 
    
    signal clk_sys    : std_logic; 
    signal pll_locked : std_logic; 
    signal sys_rst_n  : std_logic;
       
    -- dynamic constant for 100us power-up delay
    constant c_wait_100us : integer := (c_clk_freq_hz / 1000000) * 100;

    -- adxl
    signal init_start    : std_logic;
    signal init_ok       : std_logic;
    signal sample_start  : std_logic;
    signal sample_valid  : std_logic;
    signal ax            : signed(15 downto 0);
    signal ay            : signed(15 downto 0);
    signal az            : signed(15 downto 0);
    
    -- uart
    signal uart_start : std_logic := '0';
    signal uart_data  : std_logic_vector(7 downto 0);
    signal uart_busy  : std_logic;
    signal char_idx   : integer range 0 to 17 := 0;

    signal heartbeat_cpt : unsigned(25 downto 0) := (others => '0');
    signal sample_cpt    : unsigned(19 downto 0) := (others => '0');
     
    component clk_wiz_0
    port (
        clk_out1 : out std_logic; -- 25 MHz
        reset    : in  std_logic;
        locked   : out std_logic;
        clk_in1  : in  std_logic
    );
    end component;
begin
    pll_reset <= not reset_n;
    PLL_Inst : clk_wiz_0
    port map (
        clk_in1  => clk,
        clk_out1 => clk_sys,
        reset    => pll_reset,
        locked   => pll_locked
    );
    
    sys_rst_n <= '0' when (reset_n = '0' or pll_locked = '0') else '1'; -- rst systeme
     
    -- boot and sampling sequencer
    process(clk_sys, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            heartbeat_cpt <= (others => '0');
            sample_cpt    <= (others => '0');
            init_start    <= '0';
            sample_start  <= '0';

        elsif rising_edge(clk_sys) then
            if heartbeat_cpt < c_wait_100us then -- wait for the sensor to power up before init
                heartbeat_cpt <= heartbeat_cpt + 1; 
                init_start    <= '0';

            elsif heartbeat_cpt = c_wait_100us then
                init_start    <= '1'; -- trig init once
                heartbeat_cpt <= heartbeat_cpt + 1;

            else
                init_start <= '0';
            end if;

            -- if init OK => start sampling process
            if init_ok = '1' then
                sample_cpt <= sample_cpt + 1;

                if sample_cpt = 0 then 
                    sample_start <= '1'; 
                else 
                    sample_start <= '0'; 
                end if;
            end if;
        end if;
    end process;

    U_ADXL: entity work.adxl345_controller
        port map (
            clk_i          => clk_sys,
            reset_n_i      => sys_rst_n,
            init_start_i   => init_start,
            init_ok_o      => init_ok,
            init_done_o    => open,     --debug      
            sample_start_i => sample_start,
            sample_valid_o => sample_valid,
            accel_x_o      => ax,
            accel_y_o      => ay,
            accel_z_o      => az,
            debug_state_o  => open,     -- debug      
            spi_cs_n_o     => ja_cs,
            spi_sclk_o     => ja_sclk,
            spi_mosi_o     => ja_mosi,
            spi_miso_i     => ja_miso
        );
        
        
    -- DATA OUTPUTS (comment for debug Mode)
    -- ax_o <= std_logic_vector(ax);
    -- ay_o <= std_logic_vector(ay);
    -- az_o <= std_loagic_vector(az);
    -- data_valid_o <= sample_valid;
    
   
    -- DEBUG LOGIC: UART & LEDS 
    -- (YOU CAN COMMENT ALL CODE BELOW FOR ETHERNET MODE) 

    -- converts raw acceleration data into an ASCII string for serial terminal on PC
    U_UART: entity work.uart_tx
        generic map (
            g_clk_freq_in_hz => c_clk_freq_hz,
            g_baud_rate      => 115_200
        )
        port map (
            clk_i      => clk_sys,
            reset_n_i  => sys_rst_n,
            start_i    => uart_start,
            data_i     => uart_data,
            busy_o     => uart_busy,
            tx_o       => uart_tx_pin
        );
        


    -- The sequencer converts the 16-bit signed integers from the accelerometer into an ASCII string format:
    -- 'X:+0000 Y:+0000\r\n',
    -- allowing the data to be displayed clearly on a Serial Terminal.
    process(clk_sys, sys_rst_n)
        variable v_abs : integer;
    begin
        if sys_rst_n = '0' then
            char_idx   <= 0;
            uart_start <= '0';

        elsif rising_edge(clk_sys) then
            uart_start <= '0'; 

            if sample_valid = '1' and char_idx = 0 then
                char_idx <= 1;
            end if;

            if char_idx > 0 and uart_busy = '0' and uart_start = '0' then

                case char_idx is

                    when 1  =>
                        uart_data <= x"58"; -- 'X'

                    when 2  =>
                        uart_data <= x"3A"; -- ':'

                    when 3  =>
                        if ax >= 0 then 
                            uart_data <= x"2B"; 
                        else
                            uart_data <= x"2D";
                        end if;

                    when 4  =>
                        v_abs := to_integer(abs(ax));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 1000) mod 10 + 48, 8));

                    when 5  =>
                        v_abs := to_integer(abs(ax));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 100) mod 10 + 48, 8));

                    when 6  =>
                        v_abs := to_integer(abs(ax));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 10) mod 10 + 48, 8));

                    when 7  =>
                        v_abs := to_integer(abs(ax));
                        uart_data <= std_logic_vector(to_unsigned(v_abs mod 10 + 48, 8));

                    when 8  =>
                        uart_data <= x"20"; -- spce

                    when 9  =>
                        uart_data <= x"59"; -- 'Y'

                    when 10 =>
                        uart_data <= x"3A"; -- ':'

                    when 11 =>
                        if ay >= 0 then 
                            uart_data <= x"2B"; 
                        else 
                            uart_data <= x"2D"; 
                        end if;

                    when 12 =>
                        v_abs := to_integer(abs(ay));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 1000) mod 10 + 48, 8));

                    when 13 =>
                        v_abs := to_integer(abs(ay));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 100) mod 10 + 48, 8));

                    when 14 =>
                        v_abs := to_integer(abs(ay));
                        uart_data <= std_logic_vector(to_unsigned((v_abs / 10) mod 10 + 48, 8));

                    when 15 =>
                        v_abs := to_integer(abs(ay));
                        uart_data <= std_logic_vector(to_unsigned(v_abs mod 10 + 48, 8));

                    when 16 =>
                        uart_data <= x"0D"; -- \r

                    when 17 =>
                        uart_data <= x"0A"; -- \n

                    when others =>
                        null;

                end case;

                uart_start <= '1';

                if char_idx = 17 then
                    char_idx <= 0;
                else
                    char_idx <= char_idx + 1;
                end if;

            end if;
        end if;
    end process;

    -- visual debug 
    process(clk_sys) 
    begin
        if rising_edge(clk_sys) then
            leds <= (others => '0');
            
            if ax > 10 then 
                leds(0) <= '1';
            elsif ax < -10 then 
                leds(1) <= '1';
            end if;
            
            if ay > 10 then 
                leds(2) <= '1'; 
            elsif ay < -10 then 
                leds(3) <= '1'; 
            end if;
        end if;
    end process;

end Behavioral;