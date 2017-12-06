----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: host_memory_bridge_a0b1c2d3_ld_512bit - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;



entity host_memory_bridge_a0b1c2d3_ld_512bit is
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
        va              : in std_logic_vector(31 downto 0);     -- virtual memory address provided by the user kernel
        read_data       : out std_logic_vector(512+511 downto 0); -- data read from memory + profiling

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

        avm_port1_readdata : in std_logic_vector(255 downto 0);
        avm_port1_readdatavalid : in std_logic;
        avm_port1_waitrequest : in std_logic;
        avm_port1_address : out std_logic_vector(31 downto 0);
        avm_port1_read : out std_logic;
        avm_port1_write : out std_logic;
        avm_port1_writeack : in std_logic;
        avm_port1_writedata : out std_logic_vector(255 downto 0);
        avm_port1_byteenable : out std_logic_vector(31 downto 0);
        avm_port1_burstcount : out std_logic_vector(4 downto 0);

        avm_port2_readdata : in std_logic_vector(255 downto 0);
        avm_port2_readdatavalid : in std_logic;
        avm_port2_waitrequest : in std_logic;
        avm_port2_address : out std_logic_vector(31 downto 0);
        avm_port2_read : out std_logic;
        avm_port2_write : out std_logic;
        avm_port2_writeack : in std_logic;
        avm_port2_writedata : out std_logic_vector(255 downto 0);
        avm_port2_byteenable : out std_logic_vector(31 downto 0);
        avm_port2_burstcount : out std_logic_vector(4 downto 0);

        clock2x           : in std_logic
    );
end host_memory_bridge_a0b1c2d3_ld_512bit;

architecture Structural of host_memory_bridge_a0b1c2d3_ld_512bit is

    component host_memory_bridge_a0b1c2d3_512bit_rw
    generic (
        READ : integer := 1;
        KERNEL_SIDE_MEM_LATENCY : integer := 160;
        MEMORY_SIDE_MEM_LATENCY : integer := 131;
        ACTUAL_NUMBER_OF_32BIT_WORDS : integer := 16
    );
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
        va              : in std_logic_vector(31 downto 0);     -- virtual memory address provided by the user kernel
        write_data      : in std_logic_vector(511 downto 0);     -- data to be written into memory
        read_data       : out std_logic_vector(512+511 downto 0); -- data read from memory + profiling

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

        avm_port1_readdata : in std_logic_vector(255 downto 0);
        avm_port1_readdatavalid : in std_logic;
        avm_port1_waitrequest : in std_logic;
        avm_port1_address : out std_logic_vector(31 downto 0);
        avm_port1_read : out std_logic;
        avm_port1_write : out std_logic;
        avm_port1_writeack : in std_logic;
        avm_port1_writedata : out std_logic_vector(255 downto 0);
        avm_port1_byteenable : out std_logic_vector(31 downto 0);
        avm_port1_burstcount : out std_logic_vector(4 downto 0);

        avm_port2_readdata : in std_logic_vector(255 downto 0);
        avm_port2_readdatavalid : in std_logic;
        avm_port2_waitrequest : in std_logic;
        avm_port2_address : out std_logic_vector(31 downto 0);
        avm_port2_read : out std_logic;
        avm_port2_write : out std_logic;
        avm_port2_writeack : in std_logic;
        avm_port2_writedata : out std_logic_vector(255 downto 0);
        avm_port2_byteenable : out std_logic_vector(31 downto 0);
        avm_port2_burstcount : out std_logic_vector(4 downto 0);

        clock2x           : in std_logic
    );
    end component;


    component host_memory_bridge_a0b1c2d3_512bit_rw_tm
    generic (
        READ : integer := 1;
        KERNEL_SIDE_MEM_LATENCY : integer := 160;
        MEMORY_SIDE_MEM_LATENCY : integer := 131;
        ACTUAL_NUMBER_OF_32BIT_WORDS : integer := 16
    );
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
        va              : in std_logic_vector(31 downto 0);     -- virtual memory address provided by the user kernel
        write_data      : in std_logic_vector(511 downto 0);     -- data to be written into memory
        read_data       : out std_logic_vector(512+511 downto 0); -- data read from memory + profiling

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

        clock2x           : in std_logic
    );
    end component;


    component host_memory_bridge_a0b1c2d3_512bit_rw_burst
    generic (
        READ : integer := 1;
        KERNEL_SIDE_MEM_LATENCY : integer := 160;
        MEMORY_SIDE_MEM_LATENCY : integer := 131;
        ACTUAL_NUMBER_OF_32BIT_WORDS : integer := 16
    );
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
        va              : in std_logic_vector(31 downto 0);     -- virtual memory address provided by the user kernel
        write_data      : in std_logic_vector(511 downto 0);     -- data to be written into memory
        read_data       : out std_logic_vector(512+511 downto 0); -- data read from memory + profiling

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

        avm_port1_readdata : in std_logic_vector(255 downto 0);
        avm_port1_readdatavalid : in std_logic;
        avm_port1_waitrequest : in std_logic;
        avm_port1_address : out std_logic_vector(31 downto 0);
        avm_port1_read : out std_logic;
        avm_port1_write : out std_logic;
        avm_port1_writeack : in std_logic;
        avm_port1_writedata : out std_logic_vector(255 downto 0);
        avm_port1_byteenable : out std_logic_vector(31 downto 0);
        avm_port1_burstcount : out std_logic_vector(4 downto 0);

        avm_port2_readdata : in std_logic_vector(255 downto 0);
        avm_port2_readdatavalid : in std_logic;
        avm_port2_waitrequest : in std_logic;
        avm_port2_address : out std_logic_vector(31 downto 0);
        avm_port2_read : out std_logic;
        avm_port2_write : out std_logic;
        avm_port2_writeack : in std_logic;
        avm_port2_writedata : out std_logic_vector(255 downto 0);
        avm_port2_byteenable : out std_logic_vector(31 downto 0);
        avm_port2_burstcount : out std_logic_vector(4 downto 0);

        clock2x           : in std_logic
    );
    end component;



begin

    host_memory_bridge_a0b1c2d3_512bit_rw_burst_inst : host_memory_bridge_a0b1c2d3_512bit_rw_burst
        generic map (
            READ => 1,
            KERNEL_SIDE_MEM_LATENCY => 160,
            MEMORY_SIDE_MEM_LATENCY => 131,
            ACTUAL_NUMBER_OF_32BIT_WORDS => 14
        )
        port map (
            clock => clock,
            resetn => resetn,
            ivalid => ivalid,
            iready => iready,
            ovalid => ovalid,
            oready => oready,
            ttbr0 => ttbr0,
            va => va,
            write_data => (others => '0'),
            read_data => read_data,
            mem_pointer0 => mem_pointer0,
            avm_port0_readdata => avm_port0_readdata,
            avm_port0_readdatavalid => avm_port0_readdatavalid,
            avm_port0_waitrequest => avm_port0_waitrequest,
            avm_port0_address => avm_port0_address,
            avm_port0_read => avm_port0_read,
            avm_port0_write => avm_port0_write,
            avm_port0_writeack => avm_port0_writeack,
            avm_port0_writedata => avm_port0_writedata,
            avm_port0_byteenable => avm_port0_byteenable,
            avm_port0_burstcount => avm_port0_burstcount,
            avm_port1_readdata => avm_port1_readdata,
            avm_port1_readdatavalid => avm_port1_readdatavalid,
            avm_port1_waitrequest => avm_port1_waitrequest,
            avm_port1_address => avm_port1_address,
            avm_port1_read => avm_port1_read,
            avm_port1_write => avm_port1_write,
            avm_port1_writeack => avm_port1_writeack,
            avm_port1_writedata => avm_port1_writedata,
            avm_port1_byteenable => avm_port1_byteenable,
            avm_port1_burstcount => avm_port1_burstcount,
            avm_port2_readdata => avm_port2_readdata,
            avm_port2_readdatavalid => avm_port2_readdatavalid,
            avm_port2_waitrequest => avm_port2_waitrequest,
            avm_port2_address => avm_port2_address,
            avm_port2_read => avm_port2_read,
            avm_port2_write => avm_port2_write,
            avm_port2_writeack => avm_port2_writeack,
            avm_port2_writedata => avm_port2_writedata,
            avm_port2_byteenable => avm_port2_byteenable,
            avm_port2_burstcount => avm_port2_burstcount,
            clock2x => clock2x
        );



end Structural;









       





