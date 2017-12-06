----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: lock_server - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;


       
entity lock_server is
    generic (
        NUMBER_OF_HOST_THREADS : integer := 1;
        NUMBER_OF_DEVICE_THREADS : integer := 1
    );
    port (
        -- clk and reset
        clk             : in std_logic;
        resetn          : in std_logic;
        -- Avalon-MM slave
        csr_address : in std_logic_vector(2 downto 0);
        csr_write : in std_logic;
        csr_read : in std_logic;
        csr_writedata : in std_logic_vector(31 downto 0);
        csr_byteenable : in std_logic_vector(3 downto 0);
        csr_readdata : out std_logic_vector(31 downto 0);
        csr_waitrequest : out std_logic;
        csr_readdatavalid : out std_logic
    );
end lock_server;

architecture Behavioral of lock_server is
 
    type avalon_state_type is (s_idle, s_read_request_accept, s_write_request_accept);

    type request_state_type is (s_norequest,
                                s_acquire,
                                s_release
                                );

    type lock_state_type is (s_noaccess,
                            s_hostaccess,
                            s_deviceaccess);
    
    type request_register_type is array(0 to 1) of request_state_type;

    signal avalon_state : avalon_state_type;

    signal lock_request_register : request_register_type;
    signal lock_status_register : lock_state_type;
    signal request_serviced : std_logic_vector(0 to 1);

    signal csr_readdata_int : std_logic_vector(31 downto 0);

    signal read_request_reg : std_logic;

begin


    slave_response_proc : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                avalon_state <= s_idle;
                read_request_reg <= '0';
            else
                case avalon_state is
                    when s_idle =>
                        if csr_write  = '1' then
                            avalon_state <= s_write_request_accept;
                        elsif csr_read = '1' then
                            avalon_state <= s_read_request_accept;                        
                        end if;
                    when s_write_request_accept =>                        
                        avalon_state <= s_idle;
                    when s_read_request_accept =>                        
                        avalon_state <= s_idle;
                end case;

                if  avalon_state = s_read_request_accept then
                    read_request_reg <= '1';
                else 
                    read_request_reg <= '0';
                end if;

            end if;
        end if;
    end process;

    read_request_proc : process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
	            for i in 0 to 1 loop
                    lock_request_register(i) <= s_norequest;
	            end loop;
            else
                if avalon_state = s_idle and csr_address = "000" and csr_write = '1' and csr_writedata = x"00000001" then
                    lock_request_register(0) <= s_acquire;   
                elsif avalon_state = s_idle and csr_address = "000" and csr_write = '1' and csr_writedata = x"00000000" then
                    lock_request_register(0) <= s_release;               
                elsif avalon_state = s_idle and csr_address = "001" and csr_write = '1' and csr_writedata = x"00000001" then
                    lock_request_register(1) <= s_acquire;
                elsif avalon_state = s_idle and csr_address = "001" and csr_write = '1' and csr_writedata = x"00000000" then
                    lock_request_register(1) <= s_release;   
                else
                    if request_serviced(0) = '1' then
                        lock_request_register(0) <= s_norequest;
                    end if;
                    if request_serviced(1) = '1' then
                        lock_request_register(1) <= s_norequest;
                    end if;
                end if;
            end if; 
        end if;           
    end process;
   

    serve_request_proc : process (clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                lock_status_register <= s_noaccess;
            else
                if lock_request_register(1) = s_acquire and lock_status_register = s_noaccess then
                    lock_status_register <= s_deviceaccess;                   
                elsif lock_request_register(1) = s_release and lock_status_register = s_deviceaccess then
                    lock_status_register <= s_noaccess;
                elsif lock_request_register(0) = s_acquire and lock_status_register = s_noaccess then
                    lock_status_register <= s_hostaccess;  
                elsif lock_request_register(0) = s_release and lock_status_register = s_hostaccess then
                    lock_status_register <= s_noaccess;
                end if;
            end if;   
        end if;         
    end process;

    request_serviced(0) <= '1' when (lock_request_register(0) = s_acquire and lock_status_register = s_noaccess) 
                                    or (lock_request_register(0) = s_release and lock_status_register = s_hostaccess)
                               else '0';

    request_serviced(1) <= '1' when (lock_request_register(1) = s_acquire and lock_status_register = s_noaccess) 
                                    or (lock_request_register(1) = s_release and lock_status_register = s_deviceaccess)
                               else '0';

    csr_readdata_int(1 downto 0) <= "01" when lock_status_register = s_deviceaccess else
                                    "10" when lock_status_register = s_hostaccess else
                                    "00";
    csr_readdata_int(31 downto 2) <= (others => '0');
    csr_readdata <= csr_readdata_int;

    csr_waitrequest <= '0' when avalon_state = s_write_request_accept or avalon_state = s_read_request_accept else '1';
    csr_readdatavalid <= read_request_reg; -- two cycles after request

end Behavioral;


