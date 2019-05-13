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
	signal PAL     : std_logic;         -- 0=NTSC, 1=PAL (detected by frequency)
	signal CLK     : std_logic;         -- 16 times CPU clock
	
	-- SDTV signals
	signal COLOR   : std_logic_vector(3 downto 0);	
	signal QUERYCOLOR : std_logic_vector(3 downto 0);
	signal YPBPR   : std_logic_vector(14 downto 0);
	signal CSYNC   : std_logic;

	-- video memory control
	signal vramrdaddress0 : std_logic_vector (9 downto 0);
	signal vramrdaddress1 : std_logic_vector (9 downto 0);
	signal vramwraddress : std_logic_vector (9 downto 0);
	signal vramq0        : std_logic_vector (14 downto 0);
	signal vramq1        : std_logic_vector (14 downto 0);
	
	-- current user settings (palette and such)
	signal settings_writeaddr : std_logic_vector(5 downto 0) := "000000";
	signal settings_writedata : std_logic_vector(7 downto 0) := "00000000";
	signal settings_writeen : std_logic := '0';
	
   component ClockMultiplier is
	port (
		-- reference clock
		CLK25: in std_logic;		
		-- C64 cpu clock
		PHI0: in std_logic;
		-- 0: use input frequency for NTSC
		-- 1: use input frequency for PAL
		PAL: in std_logic;
		
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
	
	
	component ram_dual is
	generic
	(
		data_width : integer := 8;
		addr_width : integer := 16
	); 
	port 
	(
		data	: in std_logic_vector(data_width-1 downto 0);
		raddr	: in std_logic_vector(addr_width-1 downto 0);
		waddr	: in std_logic_vector(addr_width-1 downto 0);
		we		: in std_logic := '1';
		rclk	: in std_logic;
		wclk	: in std_logic;
		q		: out std_logic_vector(data_width-1 downto 0)
	);	
	end component;

	component Settings is
	port (
		-- reference clock
		CLK: in std_logic;		
		
		-- get notified when CPU writes into the registers
		WRITEADDR : in std_logic_vector(5 downto 0);
		WRITEDATA : in std_logic_vector(7 downto 0);
		WRITEEN : in std_logic;
		
		-- settings output signals
		QUERYCOLOR : in std_logic_vector(3 downto 0);
		YPBPR : out std_logic_vector(14 downto 0)
	);	
	end component;
	
	
begin		
	clkmulti: ClockMultiplier port map ( CLK25, GPIO1(20), PAL, CLK );
	
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
      PAL
	);	 

	vram0: ram_dual generic map(data_width => 15, addr_width => 10)
		port map (
			YPBPR,
			vramrdaddress0,
			vramwraddress,
			'1',
			CLK,
			CLK,
			vramq0		
		);
	vram1: ram_dual generic map(data_width => 15, addr_width => 10)
		port map (
			YPBPR,
			vramrdaddress1,
			vramwraddress,
			'1',
			CLK,
			CLK,
			vramq1		
		);
		
	settings0: Settings 
		port map(
			CLK,
			settings_writeaddr,
			settings_writedata,
			settings_writeen,
			QUERYCOLOR,
			YPBPR
		);
		
	
	--------- measure CPU frequency and detect if it is a PAL or NTSC machine -------
	process (CLK25, GPIO1)
		variable in_phi0 : std_logic_vector(3 downto 0);
		variable out_pal : std_logic := '1';
		variable countcpu : integer range 0 to 2000 := 0;
		variable countclk25 : integer range 0 to 25000 := 0;
	begin
		if rising_edge(CLK25) then
			if in_phi0="0011" then
				countcpu := countcpu+1;
			end if;
			if countclk25/=24999 then
				countclk25 := countclk25+1;
			else
				if countcpu<1004 then
					out_pal := '1';
				else 
					out_pal := '0';
				end if;
				countclk25 := 0;			
				countcpu := 0;
			end if;
			in_phi0 := in_phi0(2 downto 0) & GPIO1(20);
		end if;
		PAL <= out_pal;
	end process;
	
	------- implement the delay for the digital signal path and eventually create YPbPr 
	process (CLK)
		-- delayed color signal (to bring analog and digital path in sync)
		variable delay1   : std_logic_vector(3 downto 0);	
		variable delay2   : std_logic_vector(3 downto 0);	
		variable delay3   : std_logic_vector(3 downto 0);	
		variable delay4   : std_logic_vector(3 downto 0);
	begin
		if rising_edge(CLK) then
			QUERYCOLOR <= delay4;
			delay4 := delay3;	
			delay3 := delay2;	
			delay2 := delay1;	
			delay1 := COLOR;	
		end if;
	end process;
		
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper) 
	process (CLK) 
		variable hcnt : integer range 0 to 2047 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable needvsync : boolean := false;
		
		variable val0 : integer range 0 to 31;
		variable val1 : integer range 0 to 31;
		variable usehighres : boolean; 
		variable usescanlines : boolean;
		variable lpixel : integer range 0 to 2047;
		
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
	
		if rising_edge(CLK) then
			-- jumper configuration
			usehighres := GPIO2_4='0' or GPIO2_5='0' or GPIO2_6='0';
			usescanlines := GPIO2_5='0' or GPIO2_6='0';

			-- determine hsync position
			lpixel := 504;
			if PAL='0' then
				lpixel := 520;
			end if;
		
			-- if highres is not selected, just use plain SDTV
			if not usehighres then
				Y(5) <= CSYNC;
				Y(4 downto 0) <= YPBPR(14 downto 10);
				Pb <= YPBPR(9 downto 5);
				Pr <= YPBPR(4 downto 0);
				
			-- generate EDTV output signal (with syncs and all)
			else 
				-- 3 EDTV lines with vsync	
				if vcnt=0 or (vcnt=1 and hcnt<lpixel) then	  
					if (hcnt<lpixel-37) or (hcnt>=lpixel and hcnt<2*lpixel-37) then
						Y(5) <= '0';
					else
						Y(5) <= '1';				
					end if;
					Pb <= "00000";
					Pr <= "00000";			
				-- normal EDTV lines with line syncs
				else
					-- compute the sync signals
					if hcnt<37 or (hcnt>=lpixel and hcnt<lpixel+37) then  
						Y(5) <= '0';
					else
						Y(5) <= '1';
					end if;
				
					-- use scanline effect
					if usescanlines then
						-- construct bright line
						if hcnt<lpixel then
							val0 := to_integer(unsigned(vramq0(14 downto 10)));
							val0 := scanlineboost(val0);
							Y(4 downto 0) <= std_logic_vector(to_unsigned((val0), 5));
							Pb <= vramq0(9 downto 5);
							Pr <= vramq0(4 downto 0);
						-- construct scanline darkening from both adjacent lines
						else  
							val0 := to_integer(unsigned(vramq0(14 downto 10)));
							val1 := to_integer(unsigned(vramq1(14 downto 10)));
							val0 := scanlinedarken((val0+val1)/2);
							Y(4 downto 0) <= std_logic_vector(to_unsigned((val0), 5));
							val0 := to_integer(unsigned(vramq0(9 downto 5)));
							val1 := to_integer(unsigned(vramq1(9 downto 5)));								
							Pb <= std_logic_vector(to_unsigned((val0+val1) / 2, 5));
							val0 := to_integer(unsigned(vramq0(4 downto 0)));
							val1 := to_integer(unsigned(vramq1(4 downto 0)));						
							Pr <= std_logic_vector(to_unsigned((val0+val1) / 2, 5));
						end if;
					-- normal scanline color
					else
						Y(4 downto 0) <= vramq0(14 downto 10);
						Pb <= vramq0(9 downto 5);
						Pr <= vramq0(4 downto 0);
					end if;	
					
				end if;
			end if;
			
			-- progress counters and detect sync
			if CSYNC='0' and hcnt>1004 then
				hcnt := 0;
				if needvsync then 
					vcnt := 0;
					needvsync := false;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<2047 then
				-- a sync in the middle of a scanline: starts the vsync sequence
				if hcnt=200 and CSYNC='0' and vcnt>50 then
					needvsync := true;
				end if;
				hcnt := hcnt+1;
			end if;
			
		end if;
		
		-- compute VideoRAM write position (write in buffer one line ahead)
		vramwraddress <= std_logic_vector(to_unsigned(hcnt/2 + ((vcnt+1) mod 2)*512, 10));
		-- compute VideoRAM read positions to fetch two adjacent lines
		if hcnt<lpixel then
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt + ((vcnt+1) mod 2)*512, 10));
		else
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt-lpixel + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt-lpixel + ((vcnt+1) mod 2)*512, 10));
		end if;
		
	end process;
		

	------- listen to CPU activity and forward register change to Settings
	process (CLK) 
	
	-- monitor the CPU actions
	variable phase: integer range 0 to 15 := 0;
	variable in_phi0: std_logic; 
	variable in_db: std_logic_vector(11 downto 0);
	variable in_a:  std_logic_vector(5 downto 0);
	variable in_rw: std_logic; 
	variable in_cs: std_logic; 
	variable in_aec: std_logic; 
	
	variable writedetected : std_logic := '0';
	
	begin
		-- monitor when the CPU writes into registers and forward info to the settings manager
		if rising_edge(CLK) then

			if phase=9 and in_aec='1' and in_rw='0' and in_cs='0' then  
				settings_writeaddr <= in_a;
				settings_writedata <= in_db(7 downto 0);
				settings_writeen <= '1';
			else
				settings_writeen <= '0';
			end if;
			
			-- progress the phase
			if phase>12 and in_phi0='0' then
				phase:=0;
			elsif phase<15 then
				phase:=phase+1;
			end if;			
			
			-- take signals into registers
			in_phi0 := GPIO1(20);
			in_db := GPIO1(9 downto 9) & GPIO1(10) & GPIO1(11) & GPIO1(12)   
						& GPIO1(1) & GPIO1(2) & GPIO1(3) & GPIO1(4)
						& GPIO1(5) & GPIO1(6) & GPIO1(7) & GPIO1(8);
			in_a := GPIO1(9 downto 9) & GPIO1(10) & GPIO1(11)  & GPIO1(12)
					& GPIO1(13) & GPIO1(14);
			in_rw := GPIO1(16); 
			in_cs := GPIO1(15); 
			in_aec := GPIO1(18);					
		end if;	
	end process;
		
end immediate;

