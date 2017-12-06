----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: host_memory_bridge_a0b1c2d3_32bit_rw - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity host_memory_bridge_a0b1c2d3_32bit_rw is
    generic (
        READ : integer := 1;
        KERNEL_SIDE_MEM_LATENCY : integer := 160;
        MEMORY_SIDE_MEM_LATENCY : integer := 131
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
        write_data      : in std_logic_vector(31 downto 0);     -- data to be written into memory
        read_data       : out std_logic_vector(4*32-1 downto 0); -- data read from memory + profiling

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
end host_memory_bridge_a0b1c2d3_32bit_rw;

architecture Behavioral of host_memory_bridge_a0b1c2d3_32bit_rw is
 

    constant PROFILE : integer := 1;
    constant USE_CACHING : integer := 1;

    constant LSU_STYLE : string := "BURST-COALESCED";

    -- depth of delay fifos
    constant LOG_REQUESTS_IN_FLIGHT : integer := 10;



    component fifo_ip_32
        port
        (
            clock           : in std_logic ;
            data            : in std_logic_vector (31 downto 0);
            rdreq           : in std_logic ;
            wrreq           : in std_logic ;
            almost_full     : out std_logic ;
            empty           : out std_logic ;
            full            : out std_logic ;
            q               : out std_logic_vector (31 downto 0);
            usedw           : out std_logic_vector (LOG_REQUESTS_IN_FLIGHT-1 downto 0)
        );
    end component;


    component lsu_top
    generic (
        AWIDTH : integer;
        WIDTH_BYTES : integer;
        WIDTH : integer;
        MWIDTH_BYTES : integer;
        MWIDTH : integer;
        WRITEDATAWIDTH_BYTES : integer;
        WRITEDATAWIDTH : integer;
        ALIGNMENT_BYTES : integer;
        READ : integer;
        ATOMIC : integer;
        ATOMIC_WIDTH : integer;
        BURSTCOUNT_WIDTH : integer;
        KERNEL_SIDE_MEM_LATENCY : integer;
        MEMORY_SIDE_MEM_LATENCY : integer;
        USE_WRITE_ACK : integer;
        ENABLE_BANKED_MEMORY : integer;
        ABITS_PER_LMEM_BANK : integer;
        NUMBER_BANKS : integer;
        LMEM_ADDR_PERMUTATION_STYLE : integer;
        INTENDED_DEVICE_FAMILY : string;
        USEINPUTFIFO : integer;
        USEOUTPUTFIFO : integer;
        USECACHING : integer;
        CACHESIZE : integer;
        FORCE_NOP_SUPPORT : integer;
        HIGH_FMAX : integer;
        ADDRSPACE : integer;
        STYLE : string;
        USE_BYTE_EN : integer;
        PROFILE_ADDR_TOGGLE : integer;
        ACL_PROFILE : integer;
        ACL_PROFILE_INCREMENT_WIDTH : integer;
        INPUTFIFO_USEDW_MAXBITS : integer
    );
    port
    (
        clock : in std_logic;
        clock2x : in std_logic;
	    resetn : in std_logic;
	    flush : in std_logic;
	    stream_base_addr : in std_logic_vector(AWIDTH-1 downto 0);
	    stream_size : in std_logic_vector(31 downto 0);
	    stream_reset : in std_logic;
	    o_stall : out std_logic;
	    i_valid : in std_logic;
	    i_address : in std_logic_vector(AWIDTH-1 downto 0);
	    i_writedata : in std_logic_vector(WIDTH-1 downto 0);
	    i_cmpdata : in std_logic_vector(WIDTH-1 downto 0);
	    i_predicate : in std_logic;
	    i_bitwiseor : in std_logic_vector(AWIDTH-1 downto 0);
	    i_byteenable : in std_logic_vector(WIDTH_BYTES-1 downto 0);
	    i_stall : in std_logic;
	    o_valid : out std_logic;
	    o_readdata : out std_logic_vector(WIDTH-1 downto 0);
	    o_input_fifo_depth : out std_logic_vector(INPUTFIFO_USEDW_MAXBITS-1 downto 0);
	    o_writeack : out std_logic;
	    i_atomic_op : in std_logic_vector(ATOMIC_WIDTH-1 downto 0);
	    o_active : out std_logic;
	    avm_address : out std_logic_vector(AWIDTH-1 downto 0);
	    avm_read : out std_logic;
	    avm_enable : out std_logic;
	    avm_readdata : in std_logic_vector(WRITEDATAWIDTH-1 downto 0);
	    avm_write : out std_logic;
	    avm_writeack : in std_logic;
	    avm_burstcount : out std_logic_vector(BURSTCOUNT_WIDTH-1 downto 0);
	    avm_writedata : out std_logic_vector(WRITEDATAWIDTH-1 downto 0);
	    avm_byteenable : out std_logic_vector(WRITEDATAWIDTH_BYTES-1 downto 0);
	    avm_waitrequest : in std_logic;
	    avm_readdatavalid : in std_logic;
	    profile_bw : out std_logic;
	    profile_bw_incr : out std_logic_vector(ACL_PROFILE_INCREMENT_WIDTH-1 downto 0);
	    profile_total_ivalid : out std_logic;
	    profile_total_req : out std_logic;
	    profile_i_stall_count : out std_logic;
	    profile_o_stall_count : out std_logic;
	    profile_avm_readwrite_count : out std_logic;
	    profile_avm_burstcount_total : out std_logic;
	    profile_avm_burstcount_total_incr : out std_logic_vector(ACL_PROFILE_INCREMENT_WIDTH-1 downto 0);
	    profile_req_cache_hit_count : out std_logic;
	    profile_extra_unaligned_reqs : out std_logic;
	    profile_avm_stall : out std_logic
    );
    end component;

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
    signal recv_data : std_logic_vector(31 downto 0); 

    signal retval : std_logic;

    signal tlb_wr_en : std_logic;
    signal tlb_pa_in : std_logic_vector(19 downto 0);


    signal rdreq_va1 : std_logic;
    signal wrreq_va1 : std_logic;
    signal fifo_full_va1 : std_logic;
    signal fifo_dout_va1: std_logic_vector(31 downto 0);

    signal rdreq_va2 : std_logic;
    signal wrreq_va2 : std_logic;  
    signal fifo_dout_va2: std_logic_vector(31 downto 0);


    signal start : std_logic;
    signal r_start : std_logic_vector(3 downto 0);

    signal read_pt_level0_stall_in : std_logic;
    signal read_pt_level0_stall_out : std_logic;
    signal read_pt_level0_ovalid : std_logic;
    signal read_pt_level0_ivalid : std_logic;
    signal avm_write_data_0_int : std_logic_vector(31 downto 0); 
    signal avm_byteenable_0_int : std_logic_vector(3 downto 0);

    signal read_pt_level1_stall_in : std_logic;
    signal read_pt_level1_stall_out : std_logic;
    signal read_pt_level1_ovalid : std_logic;
    signal read_pt_level1_ivalid : std_logic;
    signal avm_write_data_1_int : std_logic_vector(31 downto 0); 
    signal avm_byteenable_1_int : std_logic_vector(3 downto 0);

    signal rw_stall_in : std_logic;
    signal rw_stall_out : std_logic;
    signal rw_ovalid : std_logic;
    signal rw_ivalid : std_logic;
    signal avm_write_data_2_int : std_logic_vector(31 downto 0); 
    signal avm_byteenable_2_int : std_logic_vector(3 downto 0);

    -- profiling
    signal read_pt_level0_profile_avm_stall : std_logic;
    signal read_pt_level0_profile_i_stall_count : std_logic;
    signal read_pt_level1_profile_avm_stall : std_logic;
    signal read_pt_level1_profile_i_stall_count : std_logic;
    signal rw_profile_avm_stall : std_logic;
    signal rw_profile_i_stall_count : std_logic;

    signal read_pt_level0_profile_avm_stall_c : unsigned(15 downto 0);
    signal read_pt_level0_profile_i_stall_count_c : unsigned(15 downto 0);
    signal read_pt_level1_profile_avm_stall_c : unsigned(15 downto 0);
    signal read_pt_level1_profile_i_stall_count_c : unsigned(15 downto 0);
    signal rw_profile_avm_stall_c : unsigned(15 downto 0);
    signal rw_profile_i_stall_count_c : unsigned(15 downto 0);


begin



    start_proc: process(clock) 
    begin
        if rising_edge(clock) then
            if resetn = '0' then
                r_start <= "0001";
            elsif ivalid = '1' and r_start /= "1000" then
                r_start(3 downto 1) <= r_start(2 downto 0);
                r_start(0) <= '0'; 
            end if;
        end if;
    end process;

    start <= '1' when r_start = "0100" or r_start = "0010" else '0';


    lsu_top_read_pt_level0_inst : lsu_top
    generic map (
        AWIDTH => 32,                               -- Address width (32-bits for Avalon)
        WIDTH_BYTES => 4,                           -- Width of the request (bytes)
        WIDTH => 32,                                -- Width of the request in bits
        MWIDTH_BYTES => 4,                          -- Width of the global memory bus (bytes)
        MWIDTH => 32,                               -- Width of the global memory bus in bits
        WRITEDATAWIDTH_BYTES => 4,                 -- Width of the readdata/writedata signals, may be larger than MWIDTH_BYTES for atomics
        WRITEDATAWIDTH => 32,                      -- Width of the readdata/writedata signals in bits
        ALIGNMENT_BYTES => 4,                       -- Request address alignment (bytes)
        READ => 1,                                  -- Read or write?
        ATOMIC => 0,                                -- Atomic?
        ATOMIC_WIDTH => 3,                          -- Width of operation operation indices
        BURSTCOUNT_WIDTH => 5,                      -- Determines max burst size
        KERNEL_SIDE_MEM_LATENCY => 160,               -- Effective Latency in cycles as seen by the kernel pipeline
        MEMORY_SIDE_MEM_LATENCY => 131,               -- Latency in cycles between LSU and memory
        USE_WRITE_ACK => 0,                         -- Enable the write-acknowledge signal
        ENABLE_BANKED_MEMORY => 0,                  -- Flag enables address permutation for banked local memory config
        ABITS_PER_LMEM_BANK => 0,                   -- Used when permuting lmem address bits to stride across banks
        NUMBER_BANKS => 1,                          -- Number of memory banks - used in address permutation (1-disable)
        LMEM_ADDR_PERMUTATION_STYLE => 0,           -- Type of address permutation (currently unused)
        INTENDED_DEVICE_FAMILY => "Cyclone V",
        USEINPUTFIFO => 0,                          -- specific to lsu_pipelined
        USEOUTPUTFIFO => 1,                         -- specific to lsu_pipelined
        USECACHING => USE_CACHING,
        CACHESIZE => 1024,
        FORCE_NOP_SUPPORT => 0,                     -- Stall free pipeline doesn't want the NOP fifo
        HIGH_FMAX => 1,                             -- Enable optimizations for high Fmax
        ADDRSPACE => 1,                             -- Verilog readability and parsing only - no functional purpose
        STYLE => LSU_STYLE,
        USE_BYTE_EN => 0,
        PROFILE_ADDR_TOGGLE => 0,
        ACL_PROFILE => PROFILE,                           -- Set to 1 to enable stall/valid profiling
        ACL_PROFILE_INCREMENT_WIDTH => 32,
        INPUTFIFO_USEDW_MAXBITS => 8                -- Performance monitor signals
    )
    port map
    (
        clock => clock,
        clock2x => clock2x,
	    resetn => resetn,
	    flush => start,
	    stream_base_addr => (others => '0'),
	    stream_size => (others => '0'),
	    stream_reset => '0',
	    o_stall => read_pt_level0_stall_out,
	    i_valid => read_pt_level0_ivalid,
	    i_address =>  table0_descriptor_addr_acp,
	    i_writedata => (others => '0'),
	    i_cmpdata => (others => '0'),
	    i_predicate => '0',
	    i_bitwiseor => (others => '0'),
	    i_byteenable => (others => '1'),
	    i_stall => read_pt_level0_stall_in,
	    o_valid => read_pt_level0_ovalid,
	    o_readdata => table0_descriptor,
	    o_input_fifo_depth => open,
	    o_writeack => open,
	    i_atomic_op => (others => '0'),
	    o_active => open,
	    avm_address => avm_port0_address,
	    avm_read => avm_port0_read,
	    avm_enable => open,
	    avm_readdata => avm_port0_readdata(31 downto 0),
	    avm_write => avm_port0_write,
	    avm_writeack => avm_port0_writeack,
	    avm_burstcount => avm_port0_burstcount,
	    avm_writedata => avm_write_data_0_int,
	    avm_byteenable => avm_byteenable_0_int,
	    avm_waitrequest => avm_port0_waitrequest,
	    avm_readdatavalid => avm_port0_readdatavalid,
	    profile_bw => open,
	    profile_bw_incr => open,
	    profile_total_ivalid => open,
	    profile_total_req => open,
	    profile_i_stall_count => read_pt_level0_profile_i_stall_count,
	    profile_o_stall_count => open,
	    profile_avm_readwrite_count => open,
	    profile_avm_burstcount_total => open,
	    profile_avm_burstcount_total_incr => open,
	    profile_req_cache_hit_count => open,
	    profile_extra_unaligned_reqs => open,
	    profile_avm_stall => read_pt_level0_profile_avm_stall
    );

    avm_port0_writedata(31 downto 0) <= avm_write_data_0_int;
    avm_port0_writedata(255 downto 32) <= (others => '0');

    avm_port0_byteenable(3 downto 0) <= avm_byteenable_0_int;
    avm_port0_byteenable(31 downto 4) <= (others => '0');

    read_pt_level0_stall_in <= read_pt_level1_stall_out;
    read_pt_level0_ivalid <= ivalid;


    -- fifo to delay va from ivalid to read_pt_level0_ovalid
    wrreq_va1 <= read_pt_level0_ivalid and not read_pt_level0_stall_out;
    rdreq_va1 <= read_pt_level1_ivalid and not read_pt_level1_stall_out;

    fifo_ip_inst_va1 : fifo_ip_32
        port map
        (
            clock => clock,
            data => va,
            rdreq => rdreq_va1,
            wrreq => wrreq_va1,
            almost_full => open,
            empty => open,
            full => fifo_full_va1,
            q => fifo_dout_va1,
            usedw => open
        ); 



    lsu_top_read_pt_level1_inst : lsu_top
    generic map (
        AWIDTH => 32,                               -- Address width (32-bits for Avalon)
        WIDTH_BYTES => 4,                           -- Width of the request (bytes)
        WIDTH => 32,                                -- Width of the request in bits
        MWIDTH_BYTES => 4,                          -- Width of the global memory bus (bytes)
        MWIDTH => 32,                               -- Width of the global memory bus in bits
        WRITEDATAWIDTH_BYTES => 4,                 -- Width of the readdata/writedata signals, may be larger than MWIDTH_BYTES for atomics
        WRITEDATAWIDTH => 32,                      -- Width of the readdata/writedata signals in bits
        ALIGNMENT_BYTES => 4,                       -- Request address alignment (bytes)
        READ => 1,                                  -- Read or write?
        ATOMIC => 0,                                -- Atomic?
        ATOMIC_WIDTH => 3,                          -- Width of operation operation indices
        BURSTCOUNT_WIDTH => 5,                      -- Determines max burst size
        KERNEL_SIDE_MEM_LATENCY => 160,               -- Effective Latency in cycles as seen by the kernel pipeline
        MEMORY_SIDE_MEM_LATENCY => 131,               -- Latency in cycles between LSU and memory
        USE_WRITE_ACK => 0,                         -- Enable the write-acknowledge signal
        ENABLE_BANKED_MEMORY => 0,                  -- Flag enables address permutation for banked local memory config
        ABITS_PER_LMEM_BANK => 0,                   -- Used when permuting lmem address bits to stride across banks
        NUMBER_BANKS => 1,                          -- Number of memory banks - used in address permutation (1-disable)
        LMEM_ADDR_PERMUTATION_STYLE => 0,           -- Type of address permutation (currently unused)
        INTENDED_DEVICE_FAMILY => "Cyclone V",
        USEINPUTFIFO => 0,                          -- specific to lsu_pipelined
        USEOUTPUTFIFO => 1,                         -- specific to lsu_pipelined
        USECACHING => USE_CACHING,
        CACHESIZE => 1024,
        FORCE_NOP_SUPPORT => 0,                     -- Stall free pipeline doesn't want the NOP fifo
        HIGH_FMAX => 1,                             -- Enable optimizations for high Fmax
        ADDRSPACE => 1,                             -- Verilog readability and parsing only - no functional purpose
        STYLE => LSU_STYLE,
        USE_BYTE_EN => 0,
        PROFILE_ADDR_TOGGLE => 0,
        ACL_PROFILE => PROFILE,                     -- Set to 1 to enable stall/valid profiling
        ACL_PROFILE_INCREMENT_WIDTH => 32,
        INPUTFIFO_USEDW_MAXBITS => 8                -- Performance monitor signals
    )
    port map
    (
        clock => clock,
        clock2x => clock2x,
	    resetn => resetn,
	    flush => start,
	    stream_base_addr => (others => '0'),
	    stream_size => (others => '0'),
	    stream_reset => '0',
	    o_stall => read_pt_level1_stall_out,
	    i_valid => read_pt_level1_ivalid,
	    i_address =>  table1_descriptor_addr_acp,
	    i_writedata => (others => '0'),
	    i_cmpdata => (others => '0'),
	    i_predicate => '0',
	    i_bitwiseor => (others => '0'),
	    i_byteenable => (others => '1'),
	    i_stall => read_pt_level1_stall_in,
	    o_valid => read_pt_level1_ovalid,
	    o_readdata => table1_descriptor,
	    o_input_fifo_depth => open,
	    o_writeack => open,
	    i_atomic_op => (others => '0'),
	    o_active => open,
	    avm_address => avm_port1_address,
	    avm_read => avm_port1_read,
	    avm_enable => open,
	    avm_readdata => avm_port1_readdata(31 downto 0),
	    avm_write => avm_port1_write,
	    avm_writeack => avm_port1_writeack,
	    avm_burstcount => avm_port1_burstcount,
	    avm_writedata => avm_write_data_1_int,
	    avm_byteenable => avm_byteenable_1_int,
	    avm_waitrequest => avm_port1_waitrequest,
	    avm_readdatavalid => avm_port1_readdatavalid,
	    profile_bw => open,
	    profile_bw_incr => open,
	    profile_total_ivalid => open,
	    profile_total_req => open,
	    profile_i_stall_count => read_pt_level1_profile_i_stall_count,
	    profile_o_stall_count => open,
	    profile_avm_readwrite_count => open,
	    profile_avm_burstcount_total => open,
	    profile_avm_burstcount_total_incr => open,
	    profile_req_cache_hit_count => open,
	    profile_extra_unaligned_reqs => open,
	    profile_avm_stall => read_pt_level1_profile_avm_stall
    );

    avm_port1_writedata(31 downto 0) <= avm_write_data_1_int;
    avm_port1_writedata(255 downto 32) <= (others => '0');

    avm_port1_byteenable(3 downto 0) <= avm_byteenable_1_int;
    avm_port1_byteenable(31 downto 4) <= (others => '0');

    read_pt_level1_stall_in <= rw_stall_out;
    read_pt_level1_ivalid <= read_pt_level0_ovalid;



    -- fifo to delay fifo_dout_va1 from read_pt_level1_ivalid to read_pt_level1_ovalid
    wrreq_va2 <= read_pt_level1_ivalid and not read_pt_level1_stall_out;
    rdreq_va2 <= rw_ivalid and not rw_stall_out;

    fifo_ip_inst_va2 : fifo_ip_32
        port map
        (
            clock => clock,
            data => fifo_dout_va1,
            rdreq => rdreq_va2,
            wrreq => wrreq_va2,
            almost_full => open,
            empty => open,
            full => open,
            q => fifo_dout_va2,
            usedw => open
        ); 


    lsu_top_rw_inst : lsu_top
    generic map (
        AWIDTH => 32,                               -- Address width (32-bits for Avalon)
        WIDTH_BYTES => 4,                           -- Width of the request (bytes)
        WIDTH => 32,                                -- Width of the request in bits
        MWIDTH_BYTES => 4,                          -- Width of the global memory bus (bytes)
        MWIDTH => 32,                               -- Width of the global memory bus in bits
        WRITEDATAWIDTH_BYTES => 4,                 -- Width of the readdata/writedata signals, may be larger than MWIDTH_BYTES for atomics
        WRITEDATAWIDTH => 32,                      -- Width of the readdata/writedata signals in bits
        ALIGNMENT_BYTES => 4,                       -- Request address alignment (bytes)
        READ => READ,                               -- Read or write?
        ATOMIC => 0,                                -- Atomic?
        ATOMIC_WIDTH => 3,                          -- Width of operation operation indices
        BURSTCOUNT_WIDTH => 5,                      -- Determines max burst size
        KERNEL_SIDE_MEM_LATENCY => KERNEL_SIDE_MEM_LATENCY,               -- Effective Latency in cycles as seen by the kernel pipeline
        MEMORY_SIDE_MEM_LATENCY => MEMORY_SIDE_MEM_LATENCY,               -- Latency in cycles between LSU and memory
        USE_WRITE_ACK => 0,                         -- Enable the write-acknowledge signal
        ENABLE_BANKED_MEMORY => 0,                  -- Flag enables address permutation for banked local memory config
        ABITS_PER_LMEM_BANK => 0,                   -- Used when permuting lmem address bits to stride across banks
        NUMBER_BANKS => 1,                          -- Number of memory banks - used in address permutation (1-disable)
        LMEM_ADDR_PERMUTATION_STYLE => 0,           -- Type of address permutation (currently unused)
        INTENDED_DEVICE_FAMILY => "Cyclone V",
        USEINPUTFIFO => 0,                          -- specific to lsu_pipelined
        USEOUTPUTFIFO => 1,                         -- specific to lsu_pipelined
        USECACHING => 0,
        CACHESIZE => 1024,
        FORCE_NOP_SUPPORT => 0,                     -- Stall free pipeline doesn't want the NOP fifo
        HIGH_FMAX => 1,                             -- Enable optimizations for high Fmax
        ADDRSPACE => 1,                             -- Verilog readability and parsing only - no functional purpose
        STYLE => LSU_STYLE,
        USE_BYTE_EN => 0,
        PROFILE_ADDR_TOGGLE => 0,
        ACL_PROFILE => PROFILE,                     -- Set to 1 to enable stall/valid profiling
        ACL_PROFILE_INCREMENT_WIDTH => 32,
        INPUTFIFO_USEDW_MAXBITS => 8                -- Performance monitor signals
    )
    port map
    (
        clock => clock,
        clock2x => clock2x,
	    resetn => resetn,
	    flush => start,
	    stream_base_addr => (others => '0'),
	    stream_size => (others => '0'),
	    stream_reset => '0',
	    o_stall => rw_stall_out,
	    i_valid => rw_ivalid,
	    i_address =>  data_addr_acp,
	    i_writedata => write_data,
	    i_cmpdata => (others => '0'),
	    i_predicate => '0',
	    i_bitwiseor => (others => '0'),
	    i_byteenable => (others => '1'),
	    i_stall => rw_stall_in,
	    o_valid => rw_ovalid,
	    o_readdata => recv_data,
	    o_input_fifo_depth => open,
	    o_writeack => open,
	    i_atomic_op => (others => '0'),
	    o_active => open,
	    avm_address => avm_port2_address,
	    avm_read => avm_port2_read,
	    avm_enable => open,
	    avm_readdata => avm_port2_readdata(31 downto 0),
	    avm_write => avm_port2_write,
	    avm_writeack => avm_port2_writeack,
	    avm_burstcount => avm_port2_burstcount,
	    avm_writedata => avm_write_data_2_int,
	    avm_byteenable => avm_byteenable_2_int,
	    avm_waitrequest => avm_port2_waitrequest,
	    avm_readdatavalid => avm_port2_readdatavalid,
	    profile_bw => open,
	    profile_bw_incr => open,
	    profile_total_ivalid => open,
	    profile_total_req => open,
	    profile_i_stall_count => rw_profile_i_stall_count,
	    profile_o_stall_count => open,
	    profile_avm_readwrite_count => open,
	    profile_avm_burstcount_total => open,
	    profile_avm_burstcount_total_incr => open,
	    profile_req_cache_hit_count => open,
	    profile_extra_unaligned_reqs => open,
	    profile_avm_stall => rw_profile_avm_stall
    );

    avm_port2_writedata(31 downto 0) <= avm_write_data_2_int;
    avm_port2_writedata(255 downto 32) <= (others => '0');

    avm_port2_byteenable(3 downto 0) <= avm_byteenable_2_int;
    avm_port2_byteenable(31 downto 4) <= (others => '0');

    rw_stall_in <= not iready;
    rw_ivalid <= read_pt_level1_ovalid;



    va_table0_index <= va(31 downto 20);
    va_table1_index <= fifo_dout_va1(19 downto 12); -- delayed version of va
    va_page_index <= fifo_dout_va2(11 downto 0); -- delayed version of va
    table0_base <= ttbr0(31 downto 14);
    table1_base <= table0_descriptor(31 downto 10);
    page_address <= table1_descriptor(31 downto 12);

    table0_descriptor_addr <= table0_base & va_table0_index & "00";
    table1_descriptor_addr <= table1_base & va_table1_index & "00";
    data_addr <= page_address & va_page_index;

    table0_descriptor_addr_acp <= "1" & table0_descriptor_addr(30 downto 0);
    table1_descriptor_addr_acp <= "1" & table1_descriptor_addr(30 downto 0);
    data_addr_acp <= "1" & data_addr(30 downto 0);


    ovalid <= rw_ovalid;
    oready <= (not read_pt_level0_stall_out) and (not fifo_full_va1); -- accept new data form kernel pipeline if pt_level0 not stalling and fifo not full

    read_data(1*32-1 downto 0*32) <= recv_data;

    gen_no_profiling : if PROFILE = 0 generate

        read_data(2*32-1 downto 1*32) <= (others => '0');
        read_data(3*32-1 downto 2*32) <= (others => '0');
        read_data(4*32-1 downto 3*32) <= (others => '0');

    end generate gen_no_profiling;


    gen_profiling : if PROFILE = 1 generate

        profiling_proc: process(clock) 
        begin
            if rising_edge(clock) then

                if resetn = '0' then
                    read_pt_level0_profile_avm_stall_c      <= to_unsigned(0,16);
                    read_pt_level0_profile_i_stall_count_c  <= to_unsigned(0,16);
                else
                    if read_pt_level0_profile_avm_stall = '1' then
                        read_pt_level0_profile_avm_stall_c      <= read_pt_level0_profile_avm_stall_c + 1;
                    end if;
                    if read_pt_level0_profile_i_stall_count = '1' then
                        read_pt_level0_profile_i_stall_count_c  <= read_pt_level0_profile_i_stall_count_c + 1;
                    end if;
                end if;
                
                if resetn = '0' then
                    read_pt_level1_profile_avm_stall_c      <= to_unsigned(0,16);
                    read_pt_level1_profile_i_stall_count_c  <= to_unsigned(0,16);
                else
                    if read_pt_level1_profile_avm_stall = '1' then
                        read_pt_level1_profile_avm_stall_c      <= read_pt_level1_profile_avm_stall_c + 1;
                    end if;
                    if read_pt_level1_profile_i_stall_count = '1' then
                        read_pt_level1_profile_i_stall_count_c  <= read_pt_level1_profile_i_stall_count_c + 1;
                    end if;
                end if;

                if resetn = '0' then
                    rw_profile_avm_stall_c                <= to_unsigned(0,16);
                    rw_profile_i_stall_count_c            <= to_unsigned(0,16);
                else
                    if rw_profile_avm_stall = '1' then
                        rw_profile_avm_stall_c                <= rw_profile_avm_stall_c + 1;
                    end if;
                    if rw_profile_i_stall_count = '1' then
                        rw_profile_i_stall_count_c            <= rw_profile_i_stall_count_c + 1;
                    end if;
                end if;

            end if;
        end process;

        read_data(2*32-1 downto 1*32) <= std_logic_vector(read_pt_level0_profile_avm_stall_c) & std_logic_vector(read_pt_level0_profile_i_stall_count_c);
        read_data(3*32-1 downto 2*32) <= std_logic_vector(read_pt_level1_profile_avm_stall_c) & std_logic_vector(read_pt_level1_profile_i_stall_count_c);
        read_data(4*32-1 downto 3*32) <= std_logic_vector(rw_profile_avm_stall_c) & std_logic_vector(rw_profile_i_stall_count_c);

    end generate gen_profiling;


end Behavioral;





