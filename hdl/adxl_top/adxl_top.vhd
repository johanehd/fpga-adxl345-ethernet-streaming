library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_adxl is
    Port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        
        ja_sclk      : out std_logic;
        ja_mosi      : out std_logic;
        ja_cs        : out std_logic;
        ja_miso      : in  std_logic;
               
        ax_o         : out std_logic_vector(15 downto 0); 
        ay_o         : out std_logic_vector(15 downto 0);
        az_o         : out std_logic_vector(15 downto 0);
        data_valid_o : out std_logic -- trigger for eth
    );
end top_adxl;

architecture Behavioral of top_adxl is

    -- frequency configuration
    constant c_clk_freq_hz : integer := 25_000_000; --must match the actual clock frequency
      
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

begin

    -- boot and sampling sequencer
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            heartbeat_cpt <= (others => '0');
            sample_cpt    <= (others => '0');
            init_start    <= '0';
            sample_start  <= '0';

        elsif rising_edge(clk) then
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
            clk_i          => clk,
            reset_n_i      => reset_n,
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
        
        
    ax_o <= std_logic_vector(ax);
    ay_o <= std_logic_vector(ay);
    az_o <= std_logic_vector(az);
    data_valid_o <= sample_valid;
    
  

end Behavioral;