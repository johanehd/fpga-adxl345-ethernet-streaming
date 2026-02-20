library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic (
        g_clk_freq  : integer := 25_000_000; -- MUST MATCH clk_i
        g_sclk_freq : integer := 1_000_000 -- must be below 5 MMHz   
    );
    Port (
        clk_i      : in  std_logic;
        reset_n_i  : in  std_logic;
        start_i    : in  std_logic;
        last_i     : in  std_logic;
        data_in    : in  std_logic_vector(7 downto 0);
        data_out   : out std_logic_vector(7 downto 0);
        busy_o     : out std_logic;
        done_o     : out std_logic;
        spi_sclk_o : out std_logic;
        spi_mosi_o : out std_logic;
        spi_miso_i : in  std_logic;
        spi_cs_n_o : out std_logic
    );
end spi_master;

architecture Behavioral of spi_master is

    constant c_div  : integer := g_clk_freq / g_sclk_freq;
    constant c_half     : integer := (c_div / 2) - 1;
    constant c_full     : integer := c_div - 1;

    type state_t is (S_IDLE, S_TRANSFER, S_FINISH);
    signal state : state_t := S_IDLE;
    
    signal sclk_reg : std_logic := '1';
    signal cpt      : integer range 0 to c_full := 0;
    signal bit_idx  : integer range 0 to 7 := 7;
    signal shift_reg : std_logic_vector(7 downto 0);
    signal last_latched : std_logic := '0';

begin

    process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            state        <= S_IDLE;
            spi_cs_n_o   <= '1';
            busy_o       <= '0';
            done_o       <= '0';
            sclk_reg     <= '1';
            spi_mosi_o   <= '0';
            shift_reg    <= (others => '0');
            last_latched <= '0';
            
        elsif rising_edge(clk_i) then
            done_o <= '0';

            case state is
                when S_IDLE =>
                    sclk_reg <= '1';
                    if start_i = '1' then
                        busy_o       <= '1';
                        spi_cs_n_o   <= '0';
                        last_latched <= last_i;
                        shift_reg    <= data_in;
                        bit_idx      <= 7;
                        cpt          <= 0;
                        state        <= S_TRANSFER;
                    end if;

                when S_TRANSFER =>
                    if cpt = c_half then
                        sclk_reg   <= '0';
                        spi_mosi_o <= shift_reg(bit_idx);
                        cpt        <= cpt + 1;
                        
                    elsif cpt = c_full then
                        sclk_reg <= '1';
                        shift_reg(bit_idx) <= spi_miso_i;
                        cpt <= 0;
                        
                        if bit_idx = 0 then
                            state <= S_FINISH;
                        else
                            bit_idx <= bit_idx - 1;
                        end if;
                    else
                        cpt <= cpt + 1;
                    end if;

                when S_FINISH =>
                    data_out <= shift_reg;
                    done_o   <= '1';
                    busy_o   <= '0';
                    
                    if last_latched = '1' then
                        spi_cs_n_o <= '1';
                    end if;
                    
                    state <= S_IDLE;
                    
            end case;
        end if;
    end process;

    spi_sclk_o <= sclk_reg;

end Behavioral;