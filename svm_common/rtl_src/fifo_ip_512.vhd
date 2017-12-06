----------------------------------------------------------------------------------
-- Felix Winterstein, Imperial College London, 2016
-- 
-- Module Name: fifo_ip_512 - Behavioral
-- 
-- Revision 1.01
-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
-- 
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY fifo_ip_512 IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (511 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		almost_full		: OUT STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (511 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
END fifo_ip_512;


ARCHITECTURE SYN OF fifo_ip_512 IS


    component fifo_ip_256
	    port
	    (
		    clock		: IN STD_LOGIC ;
		    data		: IN STD_LOGIC_VECTOR (255 DOWNTO 0);
		    rdreq		: IN STD_LOGIC ;
		    sclr		: IN STD_LOGIC ;
		    wrreq		: IN STD_LOGIC ;
		    almost_full		: OUT STD_LOGIC ;
		    empty		: OUT STD_LOGIC ;
		    full		: OUT STD_LOGIC ;
		    q		: OUT STD_LOGIC_VECTOR (255 DOWNTO 0);
		    usedw		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	    );
    end component;

    signal q0 : std_logic_vector(255 downto 0);
    signal q1 : std_logic_vector(255 downto 0);

BEGIN

    fifo_ip_256_inst0 : fifo_ip_256
	    port map
	    (
		    clock => clock,
		    data => data(255 downto 0),
		    rdreq => rdreq,
		    sclr => sclr,
		    wrreq => wrreq,
		    almost_full => almost_full,
		    empty => empty,
		    full => full,
		    q => q0,
		    usedw => usedw
	    );

    fifo_ip_256_inst1 : fifo_ip_256
	    port map
	    (
		    clock => clock,
		    data => data(511 downto 256),
		    rdreq => rdreq,
		    sclr => sclr,
		    wrreq => wrreq,
		    almost_full => open,
		    empty => open,
		    full => open,
		    q => q1,
		    usedw => open
	    );

    q <= q1 & q0;

END SYN;

