library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic (
        g_clk_freq_in_hz : integer := 25000000;  
        g_baud_rate : integer := 115200
    );
    port (
        clk_i   : in  std_logic;
        reset_n_i : in std_logic;
        start_i : in  std_logic;
        data_i : in  std_logic_vector(7 downto 0);
        busy_o : out std_logic;
        tx_o  : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is

    constant c_ticks_per_bit_max : integer := (g_clk_freq_in_hz / g_baud_rate) - 1;

    signal ticks_per_bit  : integer range 0 to c_ticks_per_bit_max := 0;
    signal bit_idx   : integer range 0 to 9 := 0;
    signal shift_reg : std_logic_vector(9 downto 0) := (others => '1');
    signal busy    : std_logic := '0';

begin

    busy_o <= busy;

    process(clk_i, reset_n_i)
    begin
        if reset_n_i= '0' then
                busy          <= '0';
                tx_o          <= '1';
                ticks_per_bit <= 0;
                bit_idx       <= 0;
                shift_reg     <= (others => '1');
        elsif rising_edge(clk_i) then

            if busy = '0' then
                tx_o <= '1';

                if start_i = '1' then
                    shift_reg <= '1' & data_i & '0'; -- start bit + data
                    busy    <= '1';
                    ticks_per_bit  <= 0;
                    bit_idx   <= 0;
                end if;

            else
                if ticks_per_bit = c_ticks_per_bit_max then
                    ticks_per_bit <= 0;

                    tx_o <= shift_reg(bit_idx);

                    if bit_idx = 9 then
                        busy <= '0';
                    else
                        bit_idx <= bit_idx + 1;
                    end if;

                else
                    ticks_per_bit <= ticks_per_bit + 1;
                end if;
            end if;

        end if;
    end process;

end rtl;
