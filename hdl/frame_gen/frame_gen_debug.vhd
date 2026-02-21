library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_gen_debug is
    generic (
        mac_source : std_logic_vector(47 downto 0) := x"112233445566";
        mac_dest : std_logic_vector(47 downto 0) := x"AABBCCDDEEFF";
        ip_source : std_logic_vector(31 downto 0) := x"0A0A0A0A";
        ip_dest : std_logic_vector(31 downto 0) := x"0A0A0A01";
        payload_size : integer := 6
    );
    Port (
        clk_i           : in  STD_LOGIC;
        reset_n_i         : in  STD_LOGIC;
        
        trigger_i       : in  STD_LOGIC;
        
        m_axis_tdata_o  : out STD_LOGIC_VECTOR(7 downto 0);
        m_axis_tvalid_o : out STD_LOGIC;
        m_axis_tready_i : in  STD_LOGIC;
        m_axis_tlast_o  : out STD_LOGIC
    );
end frame_gen_debug;

architecture Behavioral of frame_gen_debug is

    -- header IP (20) + header UDP (8) + payload (6)
    constant ip_lenght  : integer := 20 + 8 + payload_size;
    constant udp_length : integer := 8 + payload_size;
    
    constant ip_lenght_vector  : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(ip_lenght, 16));
    constant udp_length_vector : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(udp_length, 16));

    signal ip_checksum : std_logic_vector(15 downto 0) := (others => '0');

    signal running  : std_logic := '0';
    signal trig_old : std_logic := '0';
    signal byte_idx : integer range 0 to 63 := 0;

    -- registres AXI
    signal out_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal out_last  : std_logic := '0';
    signal out_valid : std_logic := '0';

begin

    m_axis_tdata_o  <= out_data;
    m_axis_tlast_o  <= out_last;
    m_axis_tvalid_o <= out_valid;

    process(clk_i)
        variable ck32 : unsigned(31 downto 0);
        variable ck16 : unsigned(15 downto 0);
        variable handshake : std_logic;
    begin
        if rising_edge(clk_i) then
            if reset_n_i = '0' then
                running     <= '0';
                trig_old    <= '0';
                byte_idx    <= 0;
                out_valid   <= '0';
                out_last    <= '0';
                out_data    <= (others => '0');
                ip_checksum <= (others => '0');

            else
                trig_old <= trigger_i;
                               
                -- checksum IPv4 
                ck32 := to_unsigned(0, 32) + x"4500" + unsigned(ip_lenght_vector) + x"0000" + x"0000" + x"8011"
                      + unsigned(ip_source(31 downto 16)) + unsigned(ip_source(15 downto 0))
                      + unsigned(ip_dest(31 downto 16)) + unsigned(ip_dest(15 downto 0));

                ck16 := ck32(31 downto 16) + ck32(15 downto 0);
                ip_checksum <= not std_logic_vector(ck16);


                handshake := out_valid and m_axis_tready_i;
                
                -- AXI-Stream transmission  
                if running = '0' then
                    out_valid <= '0';
                    out_last  <= '0';

                    if trigger_i = '1' and trig_old = '0' then
                        running   <= '1';
                        byte_idx  <= 0;
                        out_valid <= '1';

                        -- byte 0
                        out_data <= mac_dest(47 downto 40);
                    end if;

                else
                    out_valid <= '1';

                    if handshake = '1' then
                        -- end of frame at byte 59 (payload & padding included)
                        if byte_idx = 59 then
                            running   <= '0';
                            out_valid <= '0';
                            out_last  <= '0';
                        else
                            byte_idx <= byte_idx + 1;

                            case (byte_idx + 1) is
                                --ethernet (14)
                                when 0  => out_data <= mac_dest(47 downto 40);
                                when 1  => out_data <= mac_dest(39 downto 32);
                                when 2  => out_data <= mac_dest(31 downto 24);
                                when 3  => out_data <= mac_dest(23 downto 16);
                                when 4  => out_data <= mac_dest(15 downto  8);
                                when 5  => out_data <= mac_dest( 7 downto  0);

                                when 6  => out_data <= mac_source(47 downto 40);
                                when 7  => out_data <= mac_source(39 downto 32);
                                when 8  => out_data <= mac_source(31 downto 24);
                                when 9  => out_data <= mac_source(23 downto 16);
                                when 10 => out_data <= mac_source(15 downto  8);
                                when 11 => out_data <= mac_source( 7 downto  0);
                                    -- ether type
                                when 12 => out_data <= x"08"; -- 
                                when 13 => out_data <= x"00";

                                ---IPV4 (20)
                                when 14 => out_data <= x"45"; -- version 4, header lenght 5
                                when 15 => out_data <= x"00"; -- type of service
                                when 16 => out_data <= ip_lenght_vector(15 downto 8);
                                when 17 => out_data <= ip_lenght_vector(7 downto 0);


                                    --IPV4 gragmentation not  used (18 to 21)!!
                                when 18 => out_data <= x"00"; -- datagram id msb 
                                when 19 => out_data <= x"00"; -- datagram id lsb
                                when 20 => out_data <= x"00"; -- flag + fragment offset (msb) 
                                when 21 => out_data <= x"00"; -- fragment offset (lsb)

                                when 22 => out_data <= x"80"; -- Time To Live = 128 (only decremented by routers -> could be smaller for direct FPGA->PC link)
                                when 23 => out_data <= x"11"; -- UDP

                                when 24 => out_data <= ip_checksum(15 downto 8);
                                when 25 => out_data <= ip_checksum(7 downto 0);

                                when 26 => out_data <= ip_source(31 downto 24);
                                when 27 => out_data <= ip_source(23 downto 16);
                                when 28 => out_data <= ip_source(15 downto 8);
                                when 29 => out_data <= ip_source(7 downto 0);

                                when 30 => out_data <= ip_dest(31 downto 24);
                                when 31 => out_data <= ip_dest(23 downto 16);
                                when 32 => out_data <= ip_dest(15 downto 8);
                                when 33 => out_data <= ip_dest(7 downto 0);

                                ---UDP (8) src : 4096 dst : 4096
                                when 34 => out_data <= x"10"; -- src port msb
                                when 35 => out_data <= x"00"; -- src port lsb
                                when 36 => out_data <= x"10"; -- dst port msb
                                when 37 => out_data <= x"00"; -- dst port port
                                when 38 => out_data <= udp_length_vector(15 downto 8);
                                when 39 => out_data <= udp_length_vector(7 downto 0);
                                
                                    -- checksum udp not used
                                when 40 => out_data <= x"00"; -- checksum msb (0)
                                when 41 => out_data <= x"00"; -- checksum lsb (0)

                                --payload (6)
                                when 42 => out_data <= x"DE";
                                when 43 => out_data <= x"AD";
                                when 44 => out_data <= x"BE";
                                when 45 => out_data <= x"EF";
                                when 46 => out_data <= x"01";
                                when 47 => out_data <= x"02";
                                when 48 to 59 => out_data <= x"00"; -- padding to satisfy IEEE 802.3 minimum frame length
                                when others => out_data <= x"00";
                            end case;

                            -- tlast asserted on byte 59
                            if (byte_idx + 1) = 59 then
                                out_last <= '1';
                            else
                                out_last <= '0';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
