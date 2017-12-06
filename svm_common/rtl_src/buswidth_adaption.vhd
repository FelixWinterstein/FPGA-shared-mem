----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: bus_adaption - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;


       
entity bus_adaption is
    generic (
        ENABLE_ACP : integer := 1;
        -- Avalon MM in
        INPUT_DATAWDTH : integer := 256;
        INPUT_ADDRWDTH : integer := 32;
        INPUT_BYTEENWDTH : integer := 32;
        INPUT_BURSTCOUNT : integer := 5;
        -- Avalon MM out
        OUTPUT_DATAWDTH : integer := 32;
        OUTPUT_ADDRWDTH : integer := 32;
        OUTPUT_BYTEENWDTH : integer := 4;
        OUTPUT_BURSTCOUNT : integer := 5
    );
    port (
        -- Avalon MM in
        avm_port_in_enable : in std_logic;
        avm_port_in_readdata : out std_logic_vector(INPUT_DATAWDTH-1 downto 0);
        avm_port_in_readdatavalid : out std_logic;
        avm_port_in_waitrequest : out std_logic;
        avm_port_in_address : in std_logic_vector(INPUT_ADDRWDTH-1 downto 0);
        avm_port_in_read : in std_logic;
        avm_port_in_write : in std_logic;
        avm_port_in_writeack : out std_logic;
        avm_port_in_writedata : in std_logic_vector(INPUT_DATAWDTH-1 downto 0);
        avm_port_in_byteenable : in std_logic_vector(INPUT_BYTEENWDTH-1 downto 0);
        avm_port_in_burstcount : in std_logic_vector(INPUT_BURSTCOUNT-1 downto 0);

        -- Avalon MM out
        avm_port_out_enable : out std_logic;
        avm_port_out_readdata : in std_logic_vector(OUTPUT_DATAWDTH-1 downto 0);
        avm_port_out_readdatavalid : in std_logic;
        avm_port_out_waitrequest : in std_logic;
        avm_port_out_address : out std_logic_vector(OUTPUT_ADDRWDTH-1 downto 0);
        avm_port_out_read : out std_logic;
        avm_port_out_write : out std_logic;
        avm_port_out_writeack : in std_logic;
        avm_port_out_writedata : out std_logic_vector(OUTPUT_DATAWDTH-1 downto 0);
        avm_port_out_byteenable : out std_logic_vector(OUTPUT_BYTEENWDTH-1 downto 0);
        avm_port_out_burstcount : out std_logic_vector(OUTPUT_BURSTCOUNT-1 downto 0)
    );
end bus_adaption;

architecture Behavioral of bus_adaption is
 
    signal avm_port_in_readdata_int : std_logic_vector(INPUT_DATAWDTH-1 downto 0);
    signal avm_port_out_address_int : std_logic_vector(OUTPUT_ADDRWDTH-1 downto 0);
    signal avm_port_out_writedata_int : std_logic_vector(OUTPUT_DATAWDTH-1 downto 0);
    signal avm_port_out_byteenable_int : std_logic_vector(OUTPUT_BYTEENWDTH-1 downto 0);
    signal avm_port_out_burstcount_int : std_logic_vector(OUTPUT_BURSTCOUNT-1 downto 0);

begin

    -- 1 bit signals
    avm_port_in_readdatavalid <= avm_port_out_readdatavalid;
    avm_port_in_waitrequest <= avm_port_out_waitrequest;
    avm_port_in_writeack <= avm_port_out_writeack;
    avm_port_out_enable <= avm_port_in_enable;
    avm_port_out_read <= avm_port_in_read;
    avm_port_out_write <= avm_port_in_write;    



    -- data bus   
    avm_port_in_readdata_int(INPUT_DATAWDTH-1 downto OUTPUT_DATAWDTH) <= (others => '0');
    avm_port_in_readdata_int(OUTPUT_DATAWDTH-1 downto 0) <= avm_port_out_readdata;
    avm_port_in_readdata <= avm_port_in_readdata_int;       

    avm_port_out_writedata_int <= avm_port_in_writedata(OUTPUT_DATAWDTH-1 downto 0);
    avm_port_out_writedata <= avm_port_out_writedata_int;



    -- byteenable
    avm_port_out_byteenable_int <= avm_port_in_byteenable(OUTPUT_BYTEENWDTH-1 downto 0);
    avm_port_out_byteenable <= avm_port_out_byteenable_int;



    -- address
    G_ILTO : if INPUT_ADDRWDTH < OUTPUT_ADDRWDTH generate
        G_ACP: if ENABLE_ACP = 1 generate
            avm_port_out_address_int(OUTPUT_ADDRWDTH-1) <= '1'; -- set msb of output address to enable ACP in ARMv7 core
        end generate G_ACP;
        G_NO_ACP: if ENABLE_ACP = 0 generate
            avm_port_out_address_int(OUTPUT_ADDRWDTH-1) <= '0'; -- clear msb of output address to disable ACP in ARMv7 core
        end generate G_NO_ACP;
        avm_port_out_address_int(OUTPUT_ADDRWDTH-2 downto INPUT_ADDRWDTH) <= (others => '0');
        avm_port_out_address_int(INPUT_ADDRWDTH-1 downto 0) <= avm_port_in_address;
        avm_port_out_address <= avm_port_out_address_int;
    end generate G_ILTO;

    G_IEQO : if INPUT_ADDRWDTH = OUTPUT_ADDRWDTH generate
        avm_port_out_address <=  avm_port_in_address;
    end generate G_IEQO;



    -- burst count
    --FIXME: adaption
    avm_port_out_burstcount_int <= avm_port_in_burstcount;
    avm_port_out_burstcount <= avm_port_out_burstcount_int;


end Behavioral;
