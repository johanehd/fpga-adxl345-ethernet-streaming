library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity adxl345_controller is
  port (
    clk_i          : in  std_logic;
    reset_n_i      : in  std_logic;
    
    -- ctrl interface 
    init_start_i   : in  std_logic; 
    init_done_o    : out std_logic; 
    init_ok_o      : out std_logic;     
    sample_start_i : in  std_logic; 
    sample_valid_o : out std_logic; 
    
    -- output data
    accel_x_o      : out signed(15 downto 0);
    accel_y_o      : out signed(15 downto 0);
    accel_z_o      : out signed(15 downto 0);
    
    -- debug 
    debug_state_o  : out std_logic_vector(3 downto 0);
    
    -- spi
    spi_cs_n_o     : out std_logic;
    spi_sclk_o     : out std_logic;
    spi_mosi_o     : out std_logic;
    spi_miso_i     : in  std_logic
  );
end adxl345_controller;

architecture rtl of adxl345_controller is

  type state_t is ( S_IDLE,
    -- initialisation
    S_INIT_SEND_DEVID_CMD, S_INIT_READ_DEVID_DATA, S_INIT_SEND_BW_RATE_ADDR, S_INIT_SEND_BW_RATE_DATA, S_INIT_SEND_DATA_FORMAT_ADDR,
    S_INIT_SEND_DATA_FORMAT_DATA, S_INIT_SEND_POWER_CTL_ADDR, S_INIT_SEND_POWER_CTL_DATA, S_INIT_DONE,
    
    -- sampling
    S_SAMP_SEND_BURST_CMD, S_SAMP_READ_X_LSB, S_SAMP_READ_X_MSB, S_SAMP_READ_Y_LSB, S_SAMP_READ_Y_MSB, S_SAMP_READ_Z_LSB, S_SAMP_READ_Z_MSB,S_SAMP_DONE,

    S_ERROR
  );

  signal state : state_t := S_IDLE;
  
  -- spi ctrl
  signal spi_start, spi_last, spi_done, spi_busy : std_logic;
  signal spi_din, spi_dout : std_logic_vector(7 downto 0);
  
  -- burst buffers
  signal b0, b1, b2, b3, b4, b5 : std_logic_vector(7 downto 0);
  signal init_ok_r : std_logic := '0';

begin

  init_ok_o <= init_ok_r;

  -- debug state encoding (ILA)
  process(state) 
  begin
    case state is
      when S_IDLE                        => debug_state_o <= x"0";
      when S_INIT_SEND_DEVID_CMD          => debug_state_o <= x"1";
      when S_INIT_READ_DEVID_DATA         => debug_state_o <= x"2";
      when S_INIT_SEND_BW_RATE_ADDR       => debug_state_o <= x"3";
      when S_INIT_SEND_BW_RATE_DATA       => debug_state_o <= x"4";
      when S_INIT_SEND_DATA_FORMAT_ADDR   => debug_state_o <= x"5";
      when S_INIT_SEND_DATA_FORMAT_DATA   => debug_state_o <= x"6";
      when S_INIT_SEND_POWER_CTL_ADDR     => debug_state_o <= x"7";
      when S_INIT_SEND_POWER_CTL_DATA     => debug_state_o <= x"8";
      when S_INIT_DONE                    => debug_state_o <= x"9";
      when S_SAMP_SEND_BURST_CMD          => debug_state_o <= x"A";
      when S_SAMP_READ_X_LSB              => debug_state_o <= x"B";
      when S_SAMP_READ_X_MSB              => debug_state_o <= x"C";
      when S_SAMP_READ_Y_LSB              => debug_state_o <= x"D";
      when S_SAMP_READ_Y_MSB              => debug_state_o <= x"E";
      when S_SAMP_READ_Z_LSB              => debug_state_o <= x"F";
      when others                         => debug_state_o <= x"E";
    end case;
  end process;


  u_spi: entity work.spi_master 
    port map (
      clk_i      => clk_i, 
      reset_n_i  => reset_n_i, 
      start_i    => spi_start, 
      last_i     => spi_last, 
      data_in    => spi_din,
      data_out   => spi_dout, 
      busy_o     => spi_busy, 
      done_o     => spi_done, 
      spi_sclk_o => spi_sclk_o, 
      spi_mosi_o => spi_mosi_o, 
      spi_miso_i => spi_miso_i, 
      spi_cs_n_o => spi_cs_n_o
    );

  -- FSM
  process(clk_i, reset_n_i) 
  begin
    if reset_n_i = '0' then
      state <= S_IDLE;
      init_ok_r <= '0';
      spi_start <= '0';
      spi_last <= '0';
      init_done_o <= '0';
      sample_valid_o <= '0';
      
    elsif rising_edge(clk_i) then
      spi_start <= '0';
      init_done_o <= '0';
      sample_valid_o <= '0';

      case state is

        when S_IDLE =>
          if init_start_i = '1' then
            state <= S_INIT_SEND_DEVID_CMD;
          elsif sample_start_i = '1' and init_ok_r = '1' then
            state <= S_SAMP_SEND_BURST_CMD;
          end if;

        -- initialization
        when S_INIT_SEND_DEVID_CMD =>
          if spi_busy = '0' then
            spi_din <= x"80"; -- read devid ( R/W=1 , devid addr=0x00)
            spi_last <= '0';
            spi_start <= '1';
            state <= S_INIT_READ_DEVID_DATA;
          end if;

        when S_INIT_READ_DEVID_DATA =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"00"; -- dummy
            spi_last <= '1'; 
            spi_start <= '1';
            state <= S_INIT_SEND_BW_RATE_ADDR;
          end if;

        when S_INIT_SEND_BW_RATE_ADDR =>
          if spi_done = '1' then
            if spi_dout = x"E5" then -- check device ID
              if spi_busy = '0' then
                spi_din <= x"2C"; -- BW_RATE register address
                spi_last <= '0';
                spi_start <= '1';
                state <= S_INIT_SEND_BW_RATE_DATA;
              end if;
            else
              state <= S_ERROR; -- wrong ID
            end if;
          end if;

        when S_INIT_SEND_BW_RATE_DATA =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"0D"; -- BW_RATE value = 800 Hz => bandwitdth = 400 Hz
            spi_last <= '1';
            spi_start <= '1';
            state <= S_INIT_SEND_DATA_FORMAT_ADDR;
          end if;

        when S_INIT_SEND_DATA_FORMAT_ADDR =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"31"; -- DATA_FORMAT register address (configures data resolution and range)
            spi_last <= '0';
            spi_start <= '1';
            state <= S_INIT_SEND_DATA_FORMAT_DATA;
          end if;

        when S_INIT_SEND_DATA_FORMAT_DATA =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"08"; -- DATA_FORMAT = 0x08 (full resolution, �2g)
            spi_last <= '1';
            spi_start <= '1';
            state <= S_INIT_SEND_POWER_CTL_ADDR;
          end if;

        when S_INIT_SEND_POWER_CTL_ADDR =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"2D"; -- POWER_CTL register address (power control)
            spi_last <= '0';
            spi_start <= '1';
            state <= S_INIT_SEND_POWER_CTL_DATA;
          end if;

        when S_INIT_SEND_POWER_CTL_DATA =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"08"; -- enable measurement mode ( Measure Bit = 1)
            spi_last <= '1';
            spi_start <= '1';
            state <= S_INIT_DONE;
          end if;

        when S_INIT_DONE =>
          if spi_done = '1' and spi_busy = '0' then
            init_ok_r <= '1';
            init_done_o <= '1';
            state <= S_IDLE;
          end if;

        -- Sampling (burst read)
        when S_SAMP_SEND_BURST_CMD =>
          if spi_busy = '0' then
            spi_din <= x"F2"; -- burst read from DATAX0 (R/W = 1, multi-byte = 1, DATAX0 register addr = 0x32 ) 
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_X_LSB;
          end if;

        when S_SAMP_READ_X_LSB =>
          if spi_done = '1' and spi_busy = '0' then
            spi_din <= x"00";
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_X_MSB;
          end if;

        when S_SAMP_READ_X_MSB =>
          if spi_done = '1' and spi_busy = '0' then
            b0 <= spi_dout;
            spi_din <= x"00";
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_Y_LSB;
          end if;

        when S_SAMP_READ_Y_LSB =>
          if spi_done = '1' and spi_busy = '0' then
            b1 <= spi_dout;
            spi_din <= x"00";
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_Y_MSB;
          end if;

        when S_SAMP_READ_Y_MSB =>
          if spi_done = '1' and spi_busy = '0' then
            b2 <= spi_dout;
            spi_din <= x"00";
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_Z_LSB;
          end if;

        when S_SAMP_READ_Z_LSB =>
          if spi_done = '1' and spi_busy = '0' then
            b3 <= spi_dout;
            spi_din <= x"00";
            spi_last <= '0';
            spi_start <= '1';
            state <= S_SAMP_READ_Z_MSB;
          end if;

        when S_SAMP_READ_Z_MSB =>
          if spi_done = '1' and spi_busy = '0' then
            b4 <= spi_dout;
            spi_din <= x"00";
            spi_last <= '1';
            spi_start <= '1';
            state <= S_SAMP_DONE;
          end if;

        when S_SAMP_DONE =>
          if spi_done = '1' then
            b5 <= spi_dout;
            accel_x_o <= signed(b1 & b0);
            accel_y_o <= signed(b3 & b2);
            accel_z_o <= signed(spi_dout & b4);
            sample_valid_o <= '1';
            state <= S_IDLE;
          end if;

        when S_ERROR =>
          state <= S_ERROR;

        when others =>
          state <= S_IDLE;

      end case;
    end if;
  end process;

end rtl;
