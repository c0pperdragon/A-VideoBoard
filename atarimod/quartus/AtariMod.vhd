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
		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- Connections to the real GTIAs pins 
		PHI2        : in std_logic;
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		RW          : in std_logic;
		CS          : in std_logic;
		HALT        : in std_logic
	);	
	end component;
	
begin		
	gtia: GTIA2YPbPr
	port map (
		Y, Pb, Pr,		
		NOT GPIO1(2),          -- PHI2
		NOT (
		GPIO1(15 downto 15)    -- A4
		& GPIO1(17)            -- A3
		& GPIO1(19)            -- A2
		& GPIO1(20)            -- A1
		& GPIO1(18)),          -- A0
		NOT (
		GPIO1(10 downto 10)    -- D0
		& GPIO1(12)            -- D1
		& GPIO1(14)            -- D2
		& GPIO1(16)            -- D3
		& GPIO1(13)            -- D4
		& GPIO1(11)            -- D5
		& GPIO1(9)             -- D6
		& GPIO1(7)),           -- D7
		NOT (
		GPIO1(4 downto 4)      -- AN2
		& GPIO1(6)             -- AN1
		& GPIO1(8)),           -- AN0
		NOT GPIO1(5), 			  -- RW
		NOT GPIO1(3),          -- CS
		NOT GPIO1(1) 			  -- HALT
	);	
end immediate;


