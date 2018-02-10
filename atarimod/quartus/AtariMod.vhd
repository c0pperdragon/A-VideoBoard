-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity AtariMod is	
	port (
		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing GTIA pins comming inverted to the GPIO1
		GPIO1: in std_logic_vector(20 downto 1)	
	);	
end entity;


architecture immediate of AtariMod is

   component GTIA2YPbPr is
	port (
		-- digital YPbPr output for two pixels at once
		CSYNC:  out std_logic;                      -- sync signal
		YPbPr0: out std_logic_vector(14 downto 0);	-- color for first half of the clock
		YPbPr1: out std_logic_vector(14 downto 0); -- color for second half of the clock
		
		-- Connections to the real GTIAs pins 
		CLK         : in std_logic;
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		RW          : in std_logic;
		CS          : in std_logic;
		HALT        : in std_logic
	);	
	end component;
	
	signal CSYNC    : std_logic;
	signal YPbPr0   : std_logic_vector(14 downto 0);
	signal YPbPr1   : std_logic_vector(14 downto 0);

	
begin		
	gtia: GTIA2YPbPr
	port map (
		CSYNC,
		YPbPr0,
		YPbPr1,
		NOT GPIO1(19),         -- CLK
		NOT (
		GPIO1(6 downto 6)      -- A4
		& GPIO1(4)             -- A3
		& GPIO1(2)             -- A2
		& GPIO1(1)             -- A1
		& GPIO1(3)),           -- A0
		NOT (
		GPIO1(14 downto 14)    -- D7
		& GPIO1(12)            -- D6
		& GPIO1(10)            -- D5
		& GPIO1(8)             -- D4
		& GPIO1(5)             -- D3
		& GPIO1(7)             -- D2
		& GPIO1(9)             -- D1
		& GPIO1(11)),          -- D0
		NOT (
		GPIO1(17 downto 17)    -- AN2
		& GPIO1(15)            -- AN1
		& GPIO1(13)),          -- AN0
		NOT GPIO1(16),			  -- RW
		NOT GPIO1(18),         -- CS
		NOT GPIO1(20) 			  -- HALT
	);	
	
	process (GPIO1,CSYNC,YPbPr0,YPbPr1) 
	begin
		Y(5) <= CSYNC;
		if GPIO1(19)='0' then  
			Y(4 downto 0) <= YPbPr0(14 downto 10);
			Pb(4 downto 0) <= YPbPr0(9 downto 5);
			Pr(4 downto 0) <= YPbPr0(4 downto 0);			
		else
			Y(4 downto 0) <= YPbPr1(14 downto 10);
			Pb(4 downto 0) <= YPbPr1(9 downto 5);
			Pr(4 downto 0) <= YPbPr1(4 downto 0);					
		end if;			
	end process;

end immediate;

