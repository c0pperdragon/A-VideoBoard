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
		GPIO2_6: in std_logic;
		
		-- debug output
		GPIO2_8: out std_logic;
		GPIO2_10: out std_logic
	);	
end entity;


architecture immediate of C64Mod is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;                     -- 15.763977 MHz
		
	-- SDTV signals
	signal SDTV_Y   : std_logic_vector(5 downto 0);
	signal SDTV_Pb  : std_logic_vector(4 downto 0);
	signal SDTV_Pr  : std_logic_vector(4 downto 0);

	-- video memory control
	signal vramrdaddress0 : std_logic_vector (9 downto 0);
	signal vramrdaddress1 : std_logic_vector (9 downto 0);
	signal vramwraddress : std_logic_vector (9 downto 0);
	signal vramq0        : std_logic_vector (14 downto 0);
	signal vramq1        : std_logic_vector (14 downto 0);
	
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
	
   component VIC2YPbPr is
	port (
		-- standard definition YPbPr output
		SDTV_Y:  out std_logic_vector(5 downto 0);	
		SDTV_Pb: out std_logic_vector(4 downto 0); 
		SDTV_Pr: out std_logic_vector(4 downto 0); 
		
		-- synchronous clock and phase of the c64 clock cylce
		CLK         : in std_logic;
		
		-- Connections to the real GTIAs pins 
		PHI0        : in std_logic;
		DB          : in std_logic_vector(11 downto 0);
		A           : in std_logic_vector(5 downto 0);
		RW          : in std_logic; 
		CS          : in std_logic; 
		AEC         : in std_logic; 
		BA          : in std_logic
	);	
	end component;

	component VideoRAM is
	port (
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (14 DOWNTO 0)
	);
	end component;
	
	
begin		
	clkmulti: ClockMultiplier port map ( CLK25, GPIO1(1), CLK );
	
	vic: VIC2YPbPr port map (
		SDTV_Y,
		SDTV_Pb,
		SDTV_Pr,
		CLK,
		GPIO1(1),                                 -- PHI0
		GPIO1(12 downto 9) & GPIO1(20 downto 13), -- DB
	   GPIO1(12 downto 7),                       -- A
		GPIO1(5),                                 -- RW 
		GPIO1(6),                                 -- CS 
		GPIO1(3),                                 -- AEC
		GPIO1(4)                                  -- BA
	);	

	vram0: VideoRAM port map (
		CLK,
		SDTV_Y(4 downto 0) & SDTV_Pb & SDTV_Pr,
		vramrdaddress0,
		vramwraddress,
		'1',
		vramq0		
	);
	vram1: VideoRAM port map (
		CLK,
		SDTV_Y(4 downto 0) & SDTV_Pb & SDTV_Pr,
		vramrdaddress1,
		vramwraddress,
		'1',
		vramq1
	);
		
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper)
	process (CLK, GPIO2_4, GPIO2_6, SDTV_Y, SDTV_Pb, SDTV_Pr) 
		variable hcnt : integer range 0 to 1023 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable needvsync : boolean := false;
		
		variable val0 : integer range 0 to 31;
		variable val1 : integer range 0 to 31;
		variable usehighres : boolean; 
		variable usescanlines : boolean;

		constant hfix : integer := 1;
		
		variable EDTV_Y   : std_logic_vector(5 downto 0);
		variable EDTV_Pb  : std_logic_vector(4 downto 0);
		variable EDTV_Pr  : std_logic_vector(4 downto 0);
		
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
		usehighres := GPIO2_4='0' or GPIO2_6='0';
		usescanlines := GPIO2_6='0';
	
		if rising_edge(CLK) then
		
			-- generate EDTV output signal (with syncs and all)
			if vcnt=0 or (vcnt=1 and hcnt<504) then	  -- 3 EDTV lines with sync	
				EDTV_Y := "100000";
				EDTV_Pb := "10000";
				EDTV_Pr := "10000";
				if (hcnt>=hfix and hcnt<hfix+504-37) or (hcnt>=hfix+504 and hcnt<hfix+2*504-37) then 
					EDTV_Y(5) := '0';
				end if;
			else
				-- use scanline effect
				if usescanlines then
					-- construct bright line
					if hcnt<505 then
						val0 := to_integer(unsigned(vramq0(14 downto 10)));
						val0 := scanlineboost(val0);
						EDTV_Y := "1" & std_logic_vector(to_unsigned((val0), 5));
						EDTV_Pb := vramq0(9 downto 5);
						EDTV_Pr := vramq0(4 downto 0);
					-- construct scanline darkening from both adjacent lines
					else  
						val0 := to_integer(unsigned(vramq0(14 downto 10)));
						val1 := to_integer(unsigned(vramq1(14 downto 10)));
						val0 := scanlinedarken((val0+val1)/2);
						EDTV_Y := "1" & std_logic_vector(to_unsigned((val0), 5));
						val0 := to_integer(unsigned(vramq0(9 downto 5)));
						val1 := to_integer(unsigned(vramq1(9 downto 5)));										
						EDTV_Pb := std_logic_vector(to_unsigned((val0+val1) / 2, 5));
						val0 := to_integer(unsigned(vramq0(4 downto 0)));
						val1 := to_integer(unsigned(vramq1(4 downto 0)));										
						EDTV_Pr := std_logic_vector(to_unsigned((val0+val1) / 2, 5));
					end if;
				-- normal scanline color
				else
					EDTV_Y := "1" & vramq0(14 downto 10);
					EDTV_Pb := vramq0(9 downto 5);
					EDTV_Pr := vramq0(4 downto 0);
				end if;				
				-- two normal EDTV line syncs
				if (hcnt>=hfix and hcnt<hfix+37) or (hcnt>=hfix+504 and hcnt<hfix+504+37) then  
					EDTV_Y(5) := '0';
				end if;

			end if;
			
			-- progress counters and detect sync
			if SDTV_Y(5)='0' and hcnt>1000 then
				hcnt := 0;
				if needvsync then 
					vcnt := 0;
					needvsync := false;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<1023 then
				-- a sync in the middle of a scanline: starts the vsync sequence
				if hcnt=200 and SDTV_Y(5)='0' and vcnt>50 then
					needvsync := true;
				end if;
				hcnt := hcnt+1;
			end if;

			-- if highres is not selected, fall back to plain SDTV
			if not usehighres then
				EDTV_Y  := SDTV_Y;
				EDTV_Pb := SDTV_Pb;
				EDTV_Pr := SDTV_Pr;
			end if;
			
		end if;

		Y  <= EDTV_Y;
		Pb <= EDTV_Pb;
		Pr <= EDTV_Pr;
		
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
	
	-- debug output
	process (GPIO1)
	begin
		GPIO2_8  <= GPIO1(8); -- A(1)
		GPIO2_10 <= GPIO1(1); -- PHI0
	end process;
	

end immediate;

