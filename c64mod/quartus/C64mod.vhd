-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Mod is	
	port (
		-- reference clock
		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing VIC-II pins comming to the GPIO1
		GPIO1: in std_logic_vector(20 downto 1);	
		
		-- read output mode settings 
		GPIO2_4: in std_logic;
		GPIO2_5: in std_logic;
		GPIO2_6: in std_logic
		
--		-- debug output
--		GPIO2_8: out std_logic;
--		GPIO2_10: out std_logic
	);	
end entity;


architecture immediate of C64Mod is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;                     -- 15.763977 MHz
		
	-- SDTV signals
	signal COLOR   : std_logic_vector(3 downto 0);
	signal CSYNC   : std_logic;

	-- video memory control
	signal vramrdaddress0 : std_logic_vector (9 downto 0);
	signal vramrdaddress1 : std_logic_vector (9 downto 0);
	signal vramwraddress : std_logic_vector (9 downto 0);
	signal vramq0        : std_logic_vector (3 downto 0);
	signal vramq1        : std_logic_vector (3 downto 0);
	
   component ClockMultiplier is
	port (
		-- reference clock
		CLK25: in std_logic;		
		-- C64 cpu clock
		PHI0: in std_logic;
		
		-- x16 times output clock
		CLK: out std_logic
	);	
	end component;
	
   component VIC2Emulation is
	port (
		-- standard definition color output
		COLOR: out std_logic_vector(3 downto 0);
		CSYNC: out std_logic;
		
		-- synchronous clock and phase of the c64 clock cylce
		CLK         : in std_logic;
		
		-- Connections to the real GTIAs pins 
		PHI0        : in std_logic;
		DB          : in std_logic_vector(11 downto 0);
		A           : in std_logic_vector(5 downto 0);
		RW          : in std_logic; 
		CS          : in std_logic; 
		AEC         : in std_logic;
		
		-- selector to choose PAL(=1) or NTSC(=0) variant
		PAL         : in std_logic
	);	
	end component;

	component VideoRAM is
	port (
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
	end component;
	
	
begin		
	clkmulti: ClockMultiplier port map ( CLK25, GPIO1(20), CLK );
	
	vic: VIC2Emulation port map (
		COLOR,
		CSYNC,
		CLK,
		GPIO1(20),                                   -- PHI0		
		GPIO1(9 downto 9) & GPIO1(10) & GPIO1(11) & GPIO1(12)   
		& GPIO1(1) & GPIO1(2) & GPIO1(3) & GPIO1(4)
		& GPIO1(5) & GPIO1(6) & GPIO1(7) & GPIO1(8), -- DB		
	   GPIO1(9 downto 9) & GPIO1(10) & GPIO1(11)  & GPIO1(12)
		& GPIO1(13) & GPIO1(14),                     -- A
		GPIO1(16),                                   -- RW 
		GPIO1(15),                                   -- CS 
		GPIO1(18),                                   -- AEC
		'1' -- PAL
--		'0' -- NTSC
	);	

	vram0: VideoRAM port map (
		CLK,
		COLOR,
		vramrdaddress0,
		vramwraddress,
		'1',
		vramq0		
	);
	vram1: VideoRAM port map (
		CLK,
		COLOR,
		vramrdaddress1,
		vramwraddress,
		'1',
		vramq1
	);
		
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper)
	process (CLK, GPIO2_4, GPIO2_5, GPIO2_6) 
		variable hcnt : integer range 0 to 1023 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable needvsync : boolean := false;
		
		variable col0: integer range 0 to 15;
		variable col1: integer range 0 to 15;
		variable val0 : integer range 0 to 31;
		variable val1 : integer range 0 to 31;
		variable usehighres : boolean; 
		variable usescanlines : boolean;

		constant hfix : integer := 1;
		
		variable EDTV_YPbPr : std_logic_vector(14 downto 0);
		variable EDTV_CSYNC : std_logic;
		
	-- palette as specified by
	-- https://www.c64-wiki.de/wiki/Farbe but with darker luminance
  	type T_c64palette is array (0 to 15) of integer range 0 to 32767;
   constant c64palette : T_c64palette := 
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
--	-- palette as specified by
--	-- https://en.wikipedia.org/wiki/List_of_8-bit_computer_hardware_graphics    
--  	type T_c64palette is array (0 to 15) of integer range 0 to 32767;
--   constant c64palette : T_c64palette := 
--	(	 0 *1024 + (16+0)*32 + (16+0),  -- black
--		31 *1024 + (16+0)*32 + (16+0),  -- white
--		10 *1024 + (16-2)*32 + (16+4),  -- red
--		19 *1024 + (16+4)*32 + (16-9),  -- cyan			
--		12 *1024 + (16+4)*32 + (16+4),  -- purple
--		16 *1024 + (16-5)*32 + (16-5),  -- green
--		 8 *1024 + (16+4)*32 + (16+0),  -- blue
--		23 *1024 + (16-3)*32 + (16+0),  -- yellow
--		12 *1024 + (16-4)*32 + (16+4),  -- orange
--		 8 *1024 + (16-3)*32 + (16+2),  -- brown		 
--		16 *1024 + (16-3)*32 + (16+7),  -- light red
--		10 *1024 + (16+0)*32 + (16+0),  -- dark gray
--		15 *1024 + (16+0)*32 + (16+0),  -- medium gray
--		23 *1024 + (16-8)*32 + (16-8),  -- light green
--		15 *1024 + (16+7)*32 + (16+0),  -- light blue
--		19 *1024 + (16+0)*32 + (16+0)   -- light gray		
--	); 
--	-- the palette "Colodore", converted to YPbPr   
--	(	 0*1024 + 16*32 + 16,  -- black
--		31*1024 + 16*32 + 16,  -- white
--		 9*1024 + 14*32 + 20,  -- red
--		22*1024 + 17*32 + 10,  -- cyan		
--		12*1024 + 19*32 + 20,  -- purple
--		16*1024 + 11*32 + 11,  -- green
--		 7*1024 + 22*32 + 16,  -- blue
--		27*1024 +  8*32 + 17,  -- yellow
--		11*1024 + 12*32 + 20,  -- orange
--		 7*1024 + 12*32 + 18,  -- brown		 
--		16*1024 + 14*32 + 21,  -- light red
--		 9*1024 + 16*32 + 16,  -- dark gray
--		15*1024 + 16*32 + 16,  -- medium gray
--		27*1024 + 11*32 + 11,  -- light green
--		15*1024 + 23*32 + 14,  -- light blue
--		22*1024 + 16*32 + 16   -- light gray		
--	); 
		type T_lumadjustment is array (0 to 31) of integer range 0 to 31;
		constant scanlineboost : T_lumadjustment := 
		(	 0,  1,  2, 4,  5,  6,  8,  9,  10, 11, 13, 14, 15, 17, 18, 20, 
			21, 22, 23, 24, 25, 26, 27, 28, 28, 29, 29, 30, 30, 31, 31, 31
		);	
		constant scanlinedarken : T_lumadjustment := 
		(	 0,  1,  2, 3,  3,  4,  4,  5,  5,  6,   6,  7,  8,  9,  9, 10, 
			11, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 23, 25, 26, 27
		);			                           -- W+C     W+Y

	begin
		-- handle jumper configuration
		usehighres := GPIO2_4='0' or GPIO2_5='0' or GPIO2_6='0';
		usescanlines := GPIO2_5='0' or GPIO2_6='0';
	
		if rising_edge(CLK) then
		
			EDTV_YPbPr := "000000000000000";
			EDTV_CSYNC := '1';
			
			-- generate EDTV output signal (with syncs and all)
			if vcnt=0 or (vcnt=1 and hcnt<504) then	  -- 3 EDTV lines with vsync	
				if (hcnt>=hfix and hcnt<hfix+504-37) or (hcnt>=hfix+504 and hcnt<hfix+2*504-37) then 
					EDTV_CSYNC := '0';
				end if;
			else
				-- use scanline effect
				if usescanlines then
					-- construct bright line
					if hcnt<505 then
						col0 := to_integer(unsigned(vramq0));
						val0 := c64palette(col0) / 1024;
						val0 := scanlineboost(val0);
						EDTV_YPbPr(14 downto 10) := std_logic_vector(to_unsigned((val0), 5));
						val0 := (c64palette(col0) / 32) mod 32;
						EDTV_YPbPr(9 downto 5) := std_logic_vector(to_unsigned((val0), 5));
						val0 := c64palette(col0) mod 32;
						EDTV_YPbPr(4 downto 0) := std_logic_vector(to_unsigned((val0), 5));
					-- construct scanline darkening from both adjacent lines
					else  
						col0 := to_integer(unsigned(vramq0));
						col1 := to_integer(unsigned(vramq1));
						val0 := c64palette(col0) / 1024;
						val1 := c64palette(col1) / 1024;
						val0 := scanlinedarken((val0+val1)/2);
						EDTV_YPbPr(14 downto 10) := std_logic_vector(to_unsigned((val0), 5));
						val0 := (c64palette(col0) / 32) mod 32;
						val1 := (c64palette(col1) / 32) mod 32;										
						EDTV_YPbPr(9 downto 5) := std_logic_vector(to_unsigned((val0+val1) / 2, 5));
						val0 := c64palette(col0) mod 32;
						val1 := c64palette(col1) mod 32;									
						EDTV_YPbPr(4 downto 0) := std_logic_vector(to_unsigned((val0+val1) / 2, 5));
					end if;
				-- normal scanline color
				else
					col0 := to_integer(unsigned(vramq0));
					EDTV_YPbPr := std_logic_vector(to_unsigned(c64palette(col0),15));
				end if;				
				-- two normal EDTV line syncs
				if (hcnt>=hfix and hcnt<hfix+37) or (hcnt>=hfix+504 and hcnt<hfix+504+37) then  
					EDTV_CSYNC := '0';
				end if;

			end if;
			
			-- progress counters and detect sync
			if CSYNC='0' and hcnt>1000 then
				hcnt := 0;
				if needvsync then 
					vcnt := 0;
					needvsync := false;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<1023 then
				-- a sync in the middle of a scanline: starts the vsync sequence
				if hcnt=200 and CSYNC='0' and vcnt>50 then
					needvsync := true;
				end if;
				hcnt := hcnt+1;
			end if;

			-- if highres is not selected, fall back to plain SDTV
			if not usehighres then
				col0 := to_integer(unsigned(COLOR));
				EDTV_YPbPr := std_logic_vector(to_unsigned(c64palette(col0),15));			
				EDTV_CSYNC := CSYNC;
			end if;
			
		end if;

		Y  <= EDTV_CSYNC & EDTV_YPbPr(14 downto 10);
		Pb <= EDTV_YPbPr(9 downto 5);
		Pr <= EDTV_YPbPr(4 downto 0);
		
		-- compute VideoRAM write position (write in buffer one line ahead)
		vramwraddress <= std_logic_vector(to_unsigned(hcnt/2 + ((vcnt+1) mod 2)*512, 10));
		-- compute VideoRAM read positions to fetch two adjacent lines
		if hcnt<504 then
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt + ((vcnt+1) mod 2)*512, 10));
		else
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt-504 + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt-504 + ((vcnt+1) mod 2)*512, 10));
		end if;
		
	end process;
		

end immediate;

