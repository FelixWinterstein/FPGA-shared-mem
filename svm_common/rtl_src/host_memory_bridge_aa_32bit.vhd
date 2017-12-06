----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: host_memory_bridge_aa_a0b1c2d3_32bit - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;


       
entity host_memory_bridge_aa_a0b1c2d3_32bit is
    port (
        -- clk and reset
        clock           : in std_logic;
        resetn          : in std_logic;


        -- Avalon ST
        ivalid          : in std_logic;
        iready          : in std_logic;
        ovalid          : out std_logic;
        oready          : out std_logic;

        -- Pass-by-value IO
        ttbr0           : in std_logic_vector(31 downto 0);     -- base address of the first-level translation table of the ARMv7 MMU
        lock_location   : in std_logic_vector(31 downto 0);     -- physical address of the lock location shared between host and device
        va              : in std_logic_vector(31 downto 0);     -- virtual memory address provided by the user kernel
        increment       : in std_logic_vector(31 downto 0);     -- increment
        ret_data        : out std_logic_vector(31 downto 0);    -- returned data

        -- Mem pointers
        mem_pointer0     : in std_logic_vector(63 downto 0);

        -- Avalon MM
        avm_port0_readdata : in std_logic_vector(255 downto 0);
        avm_port0_readdatavalid : in std_logic;
        avm_port0_waitrequest : in std_logic;
        avm_port0_address : out std_logic_vector(31 downto 0);
        avm_port0_read : out std_logic;
        avm_port0_write : out std_logic;
        avm_port0_writeack : in std_logic;
        avm_port0_writedata : out std_logic_vector(255 downto 0);
        avm_port0_byteenable : out std_logic_vector(31 downto 0);
        avm_port0_burstcount : out std_logic_vector(4 downto 0);

        -- Avalon MM
        avm_port1_readdata : in std_logic_vector(255 downto 0);
        avm_port1_readdatavalid : in std_logic;
        avm_port1_waitrequest : in std_logic;
        avm_port1_address : out std_logic_vector(31 downto 0);
        avm_port1_read : out std_logic;
        avm_port1_write : out std_logic;
        avm_port1_writeack : in std_logic;
        avm_port1_writedata : out std_logic_vector(255 downto 0);
        avm_port1_byteenable : out std_logic_vector(31 downto 0);
        avm_port1_burstcount : out std_logic_vector(4 downto 0)
    );
end host_memory_bridge_aa_a0b1c2d3_32bit;

architecture Behavioral of host_memory_bridge_aa_a0b1c2d3_32bit is
 
    constant BYTEENABLE_WIDTH : integer := 32;
    constant IO_DATAWIDTH : integer := 32;

    constant NO_ACCESS : integer := 0;
    constant DEVICE_ACCESS : integer := 1;
    constant HOST_ACCESS : integer := 2;

    type fsm_state is (s_idle,
                       -- acquire lock
                       s_request_lock,
                       s_read_lock_status,
                       s_read_lock_status_done,
                       -- first-level translation table look-up
                       s_read_level0,
                       s_read_level0_done,
                       -- second-level translation table look-up
                       s_read_level1,
                       s_read_level1_done,
                       -- actual read operation
                       s_read_data,
                       s_read_data_done,
                       -- actual write operation
                       s_write_data,
                       -- release lock
                       s_release_lock,
                       -- core done
                       s_done
                      );
    
    signal state : fsm_state;

    signal va_table0_index : std_logic_vector(11 downto 0); 
    signal va_table1_index : std_logic_vector(7 downto 0); 
    signal va_page_index : std_logic_vector(11 downto 0); 

    signal table0_base : std_logic_vector(17 downto 0);
    signal table0_descriptor_addr : std_logic_vector(31 downto 0);    
    signal table0_descriptor_addr_acp : std_logic_vector(31 downto 0);
    signal table0_descriptor : std_logic_vector(31 downto 0);
    signal table0_descriptor_type  : std_logic_vector(1 downto 0);

    signal table1_base : std_logic_vector(21 downto 0);
    signal table1_descriptor_addr : std_logic_vector(31 downto 0); 
    signal table1_descriptor_addr_acp : std_logic_vector(31 downto 0);
    signal table1_descriptor : std_logic_vector(31 downto 0);
    signal table1_descriptor_type  : std_logic_vector(1 downto 0);

    signal page_address : std_logic_vector(19 downto 0);
    signal data_addr : std_logic_vector(31 downto 0); 
    signal data_addr_acp : std_logic_vector(31 downto 0); 

    signal lock_status : std_logic_vector(31 downto 0); 
    signal lock_status_reg : std_logic_vector(31 downto 0);
    signal recv_data : std_logic_vector(IO_DATAWIDTH-1 downto 0); 
    signal increment_reg : std_logic_vector(IO_DATAWIDTH-1 downto 0); 

    signal retval : std_logic;

begin

    fsm_proc: process(clock) 
    begin
        if rising_edge(clock) then
            if resetn = '0' then
                state <= s_idle;                
            else
                if state = s_idle then
                    if ivalid = '1' then
                    -- latch indices when input becomes available
                        va_table0_index <= va(31 downto 20);
                        va_table1_index <= va(19 downto 12);
                        va_page_index <= va(11 downto 0);
                        table0_base <= ttbr0(31 downto 14);
                        increment_reg <= increment;
                        retval <= '0';
                        state <= s_request_lock;
                    end if;
                    -- manage host lock requests                                        
                -- acquire lock
               elsif state = s_request_lock and avm_port1_waitrequest = '0' then 
                    state <= s_read_lock_status;
               elsif state = s_read_lock_status and avm_port1_waitrequest = '0' then 
                    state <= s_read_lock_status_done;
               elsif state = s_read_lock_status_done and avm_port1_readdatavalid = '1' then
                    if lock_status = std_logic_vector(to_unsigned(DEVICE_ACCESS,32)) then
                        state <= s_read_level0;
                    else
                        state <= s_read_lock_status;
                    end if;
                -- first-level translation table look-up
                elsif state = s_read_level0 and avm_port0_waitrequest = '0' then
                    state <= s_read_level0_done;
                elsif state = s_read_level0_done and avm_port0_readdatavalid = '1' and table0_descriptor_type /= "00" then -- 1 gap cycle
                    state <= s_read_level1;
                elsif state = s_read_level0_done and avm_port0_readdatavalid = '1' and table0_descriptor_type = "00" then -- 1 gap cycle
                    retval <= '1'; -- pagefault
                    state <= s_release_lock;
                -- second-level translation table look-up
                elsif state = s_read_level1 and avm_port0_waitrequest = '0' then
                    state <= s_read_level1_done; -- page table walk done       
                elsif state = s_read_level1_done and avm_port0_readdatavalid = '1' and table1_descriptor_type /= "00" then
                    state <= s_read_data; -- issue a read
                elsif state = s_read_level1_done and avm_port0_readdatavalid = '1' and table1_descriptor_type = "00" then
                    retval <= '1'; -- pagefault
                    state <= s_release_lock;
                -- actual read operation
                elsif state = s_read_data and avm_port0_waitrequest = '0' then
                    state <= s_read_data_done;
                elsif state = s_read_data_done and avm_port0_readdatavalid = '1' then         
                    state <= s_write_data;
                -- actual write operation
                elsif state = s_write_data and avm_port0_waitrequest = '0' then
                    state <= s_release_lock;
                -- release lock
                elsif state = s_release_lock and avm_port1_waitrequest = '0' then 
                    state <= s_done;
                -- done
                elsif state = s_done and iready = '1' then -- wait until output data data can be picked up by the kernel
                    state <= s_idle;
                end if; 
            end if;
        end if;
    end process;

    table0_descriptor_addr <= table0_base & va_table0_index & "00";
    table1_descriptor_addr <= table1_base & va_table1_index & "00";
    data_addr <= page_address & va_page_index;

    table0_descriptor_addr_acp <= "1" & table0_descriptor_addr(30 downto 0);
    table1_descriptor_addr_acp <= "1" & table1_descriptor_addr(30 downto 0);
    data_addr_acp <= "1" & data_addr(30 downto 0);

    response_proc: process(clock) 
    variable new_val : unsigned(31 downto 0);
    begin
        if rising_edge(clock) then
            if (state = s_read_level0_done or state = s_read_level0) and avm_port0_readdatavalid = '1' then
                table0_descriptor <= avm_port0_readdata(31 downto 0);                 
            end if;
            if (state = s_read_level1_done or state = s_read_level1) and avm_port0_readdatavalid = '1' then
                table1_descriptor <= avm_port0_readdata(31 downto 0);                 
            end if;
            if (state = s_read_data_done or state = s_read_data) and avm_port0_readdatavalid = '1' then
                new_val := unsigned(avm_port0_readdata(IO_DATAWIDTH-1 downto 0)) + unsigned(increment_reg);
                recv_data <=  std_logic_vector(new_val);
            end if;
        end if;
    end process;    

    lock_response_proc: process(clock) 
    begin
        if rising_edge(clock) then
            if (state = s_read_lock_status_done or state = s_read_lock_status) and avm_port1_readdatavalid = '1' then              
               lock_status_reg <= lock_status;                 
            end if; 
        end if;
    end process; 

    lock_status <= avm_port1_readdata(31 downto 0); 

    -- from table0_descriptor look-up
    table1_base <= table0_descriptor(31 downto 10);
    table0_descriptor_type <= avm_port0_readdata(1 downto 0); -- table0_descriptor, "00" when page fault 

    -- from table0_descriptor look-up
    table1_descriptor_type <= avm_port0_readdata(1 downto 0); -- table1_descriptor, "00" when page fault 
    page_address <= table1_descriptor(31 downto 12);
    

    avm_port0_address <= table0_descriptor_addr_acp when state = s_read_level0 else 
                         table1_descriptor_addr_acp when state = s_read_level1 else
                         data_addr_acp;
    avm_port0_read <= '1' when state = s_read_level0 or state = s_read_level1 or state = s_read_data else '0';    
    avm_port0_write <= '1' when state = s_write_data else '0';
    avm_port0_burstcount <= "00001";
    avm_port0_byteenable <= (others => '1');
    avm_port0_writedata(255 downto IO_DATAWIDTH) <= (others => '0');
    avm_port0_writedata(IO_DATAWIDTH-1 downto 0) <= recv_data;
   
    oready <= '1' when state = s_idle else '0';
    ovalid <= '1' when state = s_done else '0'; -- when state = s_done and iready = '1' else '0';

    ret_data(IO_DATAWIDTH-1 downto 1) <= (others => '0');
    ret_data(0) <= retval;

    
    avm_port1_address <= x"00000004" when state = s_request_lock or state = s_release_lock else x"00000010";
    avm_port1_read <= '1' when state = s_read_lock_status else '0';
    avm_port1_write <= '1' when state = s_request_lock or state = s_release_lock else '0';
    avm_port1_writedata(255 downto 32) <= (others => '0');
    avm_port1_writedata(31 downto 0) <= x"00000001" when state = s_request_lock  else x"00000000";
    avm_port1_byteenable(31 downto 4) <= (others => '0');
    avm_port1_byteenable(3 downto 0) <= (others => '1');
    avm_port1_burstcount <= "00001";



end Behavioral;


