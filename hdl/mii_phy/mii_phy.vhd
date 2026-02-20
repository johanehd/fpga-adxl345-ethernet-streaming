library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mii_phy is
    Port ( 
        clk_i         : in  STD_LOGIC; -- 25 MHz
        reset_n_i       : in  STD_LOGIC;
        
        s_tdata_i       : in  STD_LOGIC_VECTOR(7 downto 0);
        s_tvalid_i      : in  STD_LOGIC;
        s_tready_o      : out STD_LOGIC;
        s_tlast_i       : in  STD_LOGIC;
        
        eth_txd_o     : out STD_LOGIC_VECTOR(3 downto 0);
        eth_tx_en_o   : out STD_LOGIC
    );
end mii_phy;

architecture Behavioral of mii_phy is

    type state_t is (S_IDLE, S_PREAMBLE, S_SEND_LSB, S_SEND_MSB, S_SEND_CRC, S_IFG);
    signal state : state_t := S_IDLE;
    
    signal byte_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal last_byte    : std_logic := '0';
    signal preamble_cpt : integer range 0 to 15 := 0;
    signal ifg_cpt      : integer range 0 to 31 := 0;

    -- CRC
    signal crc_current  : std_logic_vector(31 downto 0) := (others => '1');
    signal crc_next     : std_logic_vector(31 downto 0);
    signal crc_data_in  : std_logic_vector(3 downto 0) := (others => '0');
    signal crc_final    : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_idx    : integer range 0 to 7 := 0;

begin

    CRC_INST : entity work.crc
        port map (
            crcIn  => crc_current,
            data   => crc_data_in,
            crcOut => crc_next
        );

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if reset_n_i = '0' then
                state <= S_IDLE;
                eth_tx_en_o <= '0';
                eth_txd_o <= "0000";
                s_tready_o <= '0';
                crc_current <= (others => '1');
            else
                s_tready_o <= '0'; 

                case state is
                    when S_IDLE =>
                        eth_tx_en_o <= '0'; 
                        eth_txd_o   <= "0000";
                        if s_tvalid_i = '1' then
                            state        <= S_PREAMBLE;
                            preamble_cpt <= 0;
                        end if;

                    when S_PREAMBLE =>
                        eth_tx_en_o <= '1';
                        -- sending 15 nibbles of 0x5 followed by 1 nibble of 0xD (SFD)
                        if preamble_cpt < 15 then
                            eth_txd_o      <= "0101"; -- 0x5
                            preamble_cpt <= preamble_cpt + 1;
                        else
                            eth_txd_o <= "1101"; -- 0xD 
                            crc_current <= (others => '1');
                            
                            if s_tvalid_i = '1' then
                                byte_reg  <= s_tdata_i;
                                last_byte <= s_tlast_i;
                                s_tready_o    <= '1'; -- frame_gen ack
                                state     <= S_SEND_LSB;
                            else
                                state <= S_IDLE; 
                            end if;
                        end if;

                    when S_SEND_LSB =>
                        eth_tx_en_o <= '1';
                        eth_txd_o   <= byte_reg(3 downto 0); -- send lsb first (mii requierment) 
                        crc_data_in <= byte_reg(3 downto 0);
                        crc_current <= crc_next;
                        state <= S_SEND_MSB;

                    when S_SEND_MSB =>
                        eth_tx_en_o <= '1';
                        eth_txd_o   <= byte_reg(7 downto 4); -- send msb to complete the byte
                        crc_data_in <= byte_reg(7 downto 4);
                        crc_current <= crc_next;
                        
                        if last_byte = '1' then
                            crc_final <= not crc_next; -- final inversion for FCS (Frame Check Sequence)
                            crc_idx  <= 0;
                            state    <= S_SEND_CRC;
                        else
                            if s_tvalid_i = '1' then
                                byte_reg  <= s_tdata_i; -- fetch next byte from frame_gen
                                last_byte <= s_tlast_i; -- check if it's the end of stream
                                s_tready_o    <= '1';   -- send ack : frame_gen_can continue
                                state     <= S_SEND_LSB;
                            else
                                eth_tx_en_o <= '0'; 
                                state <= S_IDLE;
                            end if;
                        end if;

                        when S_SEND_CRC =>
                            eth_tx_en_o <= '1';
                            case crc_idx is
                                when 0 => eth_txd_o <= crc_final(27 downto 24); 
                                when 1 => eth_txd_o <= crc_final(31 downto 28); 

                                when 2 => eth_txd_o <= crc_final(19 downto 16); 
                                when 3 => eth_txd_o <= crc_final(23 downto 20); 

                                when 4 => eth_txd_o <= crc_final(11 downto 8);  
                                when 5 => eth_txd_o <= crc_final(15 downto 12); 

                                when 6 => eth_txd_o <= crc_final(3 downto 0);   
                                when 7 => eth_txd_o <= crc_final(7 downto 4);   
                            end case;
                        
                        if crc_idx = 7 then
                            state <= S_IFG;
                            ifg_cpt <= 0;
                        else
                            crc_idx <= crc_idx + 1;
                        end if;
                    -- Inter-Frame Gap (IFG) counter
                    -- IEEE 802.3 requires a minimum gap of 96 bit-times (12 bytes)
                    when S_IFG =>
                        eth_tx_en_o <= '0';
                        eth_txd_o <= "0000";
                        if ifg_cpt < 12 then 
                            ifg_cpt <= ifg_cpt + 1; 
                        else 
                            -- IFG period complete, return to IDLE to allow next transmission
                            state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;