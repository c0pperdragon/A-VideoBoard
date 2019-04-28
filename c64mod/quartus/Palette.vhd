library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Storage for the color palette of the C64.
-- This is implements the lookup-table as well the feature
-- to modify the platte prgrammatically and store 
-- it persistently (using a MAX 10 specific feature).
-- 

entity Palette is	
	port (
		-- synchronous clock of 16 times the c64 clock cycle
		CLK  : in std_logic;

		-- one of 16 color values 
		COLOR: in std_logic_vector(3 downto 0);
		
		-- RGB color 
		YPBPR: out std_logic_vector(14 downto 0)
	);	
end entity;


architecture immediate of Palette is
begin

	-- main signal processing and video logic
	process (CLK) 
	
			-- palette as specified by
		-- https://www.c64-wiki.de/wiki/Farbe but with darker luminance
		type T_c64palette is array (0 to 15) of integer range 0 to 32767;
		constant defaultpalette : T_c64palette := 
		(	 0 *1024 + 16*32 + 16,
			31 *1024 + 16*32 + 16,
			10 *1024 + 13*32 + 24,
			19 *1024 + 16*32 + 11,
			12 *1024 + 21*32 + 22,
			16 *1024 + 12*32 + 4,
			8  *1024 + 26*32 + 14,
			23 *1024 + 8*32 + 17,
			12 *1024 + 11*32 + 21,
			8  *1024 + 11*32 + 18,
			16 *1024 + 13*32 + 24,
			10 *1024 + 16*32 + 16,
			15 *1024 + 16*32 + 16,
			23 *1024 + 8*32 + 12,
			15 *1024 + 26*32 + 6,
			19 *1024 + 16*32 + 16	
		); 
		
		variable c : integer range 0 to 15;
		
	begin
		if (rising_edge(CLK)) then
			c := to_integer(unsigned(COLOR));
			YPBPR <= std_logic_vector(to_unsigned(defaultpalette(c),15));
		end if;
	end process;
	
end immediate;

