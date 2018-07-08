-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Converter is	
	port (
--		-- reference clock
--		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- input from the data aquisition
		CLKADC: in std_logic;
		LUMA: in std_logic_vector(7 downto 0);	
		CHROMA: in std_logic_vector(7 downto 0);
--		-- selection switches
--		GPIO2: in std_logic_vector(10 downto 3);

		TST : out std_logic
	);	
end entity;


architecture immediate of C64Converter is

	signal PIXEL : boolean;
	signal HSYNC : boolean;
	signal VSYNC : boolean;
	signal CHROMAANGLE : integer range 0 to 255;
	signal LUMINANCE : integer range 0 to 255;
 
   component C64Decoder is
	port (
		-- input from the data aquisition
		CLKADC: in std_logic;
		LUMA: in std_logic_vector(7 downto 0);	
		CHROMA: in std_logic_vector(7 downto 0);
		
		-- output for further processing
		PIXEL: out boolean;   -- true if new data is ready
		HSYNC: out boolean;   -- true when beginning a new line
		VSYNC: out boolean;   -- true when beginning a new frame
		COLOR: out integer range 0 to 15;  -- C64 color

      -- debug info
		CHROMAANGLE: out integer range 0 to 255;
		LUMINANCE: out integer range 0 to 255
	);	
	end component;
	
begin	
	decoder: C64Decoder port map (
		CLKADC, 
		LUMA,
		CHROMA,
		PIXEL,
		HSYNC,
		VSYNC,
		open,   -- COLOR
		CHROMAANGLE,
		LUMINANCE		
	);	
	
	process (CHROMAANGLE)
	begin	
		Pr <= "10000"; -- std_logic_vector(to_unsigned(CHROMAANGLE/8,5));
		Pb <= "10000";
	end process;
					
	process (CLKADC)			
		variable hcount : integer range 0 to 65535 := 0;
		variable vcount : integer range 0 to 511 := 0;		
		
      variable y_out : integer range 0 to 63 := 0;	
		
		variable csync : boolean;
	begin
	
		if rising_edge(CLKADC) then
			-- compute csync signals 
			if (vcount=0 or vcount=1 or vcount=2) and (hcount<180 or (hcount>=2565 and hcount<2745)) then        -- short syncs
				csync := true;
			elsif (vcount=3 or vcount=4) and (hcount<2205 or (hcount>=2565 and hcount<4770)) then          -- vsyncs
				csync := true;
			elsif (vcount=5) and (hcount<2205 or (hcount>=2565 and hcount<2745)) then                      -- one vsync, one short sync
				csync := true;
			elsif (vcount=6 or vcount=7) and (hcount<180 or (hcount>=2565 and hcount<2745)) then                -- short syncs
				csync := true;
			elsif (vcount>=8) and (hcount<260) then                                                         -- normal line syncs
				csync := true;
			else
				csync := false;
			end if;			
				
			-- combine csync with luminance
			if csync then
				y_out := 0;
			else
				y_out := 32 + LUMINANCE/8;
			end if;
				
			-- progress counters
			if HSYNC then
				hcount := 0;
				if VSYNC then
					vcount := 0;
				else
					vcount := vcount+1;
				end if;
			else
				hcount := hcount+1;
			end if;			
		end if;
	
      Y <= std_logic_vector(to_unsigned(y_out,6));
      tst <= '0';	    
	
	end process;	

end immediate;
