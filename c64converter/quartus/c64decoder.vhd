library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Decoder is	
	port (
		-- reference clock
		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- interface to the data aquisition
		CLKADC: out std_logic;
		LUMA: in std_logic_vector(7 downto 0);	
		CHROMA: in std_logic_vector(7 downto 0);
		
		-- user interface
		KEYS : in std_logic_vector(2 downto 0);  -- active low
		
		TST : out std_logic
	);	
end entity;


architecture immediate of C64Decoder is
	subtype int3 is integer range 0 to 7;
	subtype int4 is integer range 0 to 15;
	subtype int5 is integer range 0 to 31;
	subtype int6 is integer range 0 to 63;
	subtype int7 is integer range 0 to 127;
	subtype int8 is integer range 0 to 255;
	subtype int9 is integer range 0 to 511;
	subtype int12 is integer range 0 to 4095;
	subtype sint8 is integer range -128 to 127;
	subtype sint9 is integer range -256 to 255;
	subtype sint16 is integer range -32768 to 32767;
	subtype sint24 is integer range -8388608 to 8388607;
	
	-- global signals and constants to tie processes together ---	
	
	signal CLK48TH : std_logic;          -- high speed clock to derive slower clocks from		
	signal DELAY48TH : std_logic;        -- rising edge signals request to delay the base clock
	signal CLK12TH : std_logic;          -- internal clock is synced to a 12th of a pixel
	
	signal CLKPIXEL : std_logic;         -- clock when a pixel is ready for computation
	signal SYNCSTART : std_logic; -- is '1' once when falling csync was detected
	signal LUMPIXEL : int8;     -- luma value for a pixel
	signal CHROMPIXEL : int8;  -- chroma value for a pixel
	signal DCPIXEL : sint9;     -- delta chroma value for a pixel (1. derivative)

	type T_REGISTERS is array (0 to 15) of int8;
	constant REG_VISUALMODE  : integer := 0;
--	constant REG_HIGHPASS    : integer := 1; 
	constant REG_LUMSAMPLE   : integer := 2;
	constant REG_CHROMSAMPLE : integer := 3;
--	constant REG_CHROMAZERO  : integer := 4;
	constant REG_DARKGRAY    : integer := 5;
	constant REG_MEDIUMGRAY  : integer := 6;
	constant REG_LIGHTGRAY   : integer := 7;
	constant REG_THREASHOLD0 : integer := 8;
	constant REG_THREASHOLD1 : integer := 9;
	constant REG_THREASHOLD2 : integer := 10;
	constant REG_THREASHOLD3 : integer := 11;
	constant REG_THREASHOLD4 : integer := 12;
	constant REG_THREASHOLD5 : integer := 13;
	constant REG_THREASHOLD6 : integer := 14;
	constant REG_THREASHOLD7 : integer := 15;
	
	signal REGISTERS : T_REGISTERS; 
	signal SELECTEDREGISTER : int4;		

	constant synclevel : integer := 55;
	
--   signal triggerdump : std_logic;
--
--	signal dumpdata : STD_LOGIC_VECTOR(15 downto 0);
--	signal dumprdaddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
--	signal dumpwraddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
--	signal dumpq : STD_LOGIC_VECTOR (15 DOWNTO 0);

	-- clock generator PLL
   component PLL378 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;

--   component DUMPRAM is
--	PORT
--	(
--		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
--		rdaddress		: IN STD_LOGIC_VECTOR (12 DOWNTO 0);
--		rdclock		: IN STD_LOGIC ;
--		wraddress		: IN STD_LOGIC_VECTOR (12 DOWNTO 0);
--		wrclock		: IN STD_LOGIC  := '1';
--		wren		: IN STD_LOGIC  := '0';
--		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
--	);
--	end component;
	
	-- toolbox function for showing digits on the screen
	function digitpixel(value: int4; x:int3; y:int3) return boolean
	is
		type T_bitmap is array (0 to 16*8-1) of std_logic_vector(7 downto 0);
		constant bitmap : T_bitmap := 
		(	"00000000","00111100","01100110","01101110","01110110","01100110","00111100","00000000",	
			"00000000","00011000","00111000","00011000","00011000","00011000","01111110","00000000",		
			"00000000","00111100","01100110","00001100","00011000","00110000","01111110","00000000",		
			"00000000","01111110","00001100","00011000","00001100","01100110","00111100","00000000",		
			"00000000","00001100","00011100","00111100","01101100","01111110","00001100","00000000",		
			"00000000","01111110","01100000","01111100","00000110","01100110","00111100","00000000",		
			"00000000","00111100","01100000","01111100","01100110","01100110","00111100","00000000",		
			"00000000","01111110","00000110","00001100","00011000","00110000","00110000","00000000",		
			"00000000","00111100","01100110","00111100","01100110","01100110","00111100","00000000",		
			"00000000","00111100","01100110","00111110","00000110","00001100","00111000","00000000",		
			"00000000","00011000","00111100","01100110","01100110","01111110","01100110","00000000",		
			"00000000","01111100","01100110","01111100","01100110","01100110","01111100","00000000",		
			"00000000","00111100","01100110","01100000","01100000","01100110","00111100","00000000",		
			"00000000","01111000","01101100","01100110","01100110","01101100","01111000","00000000",		
			"00000000","01111110","01100000","01111100","01100000","01100000","01111110","00000000",		
			"00000000","01111110","01100000","01111100","01100000","01100000","01100000","00000000"		
	   );
		variable b : std_logic_vector(7 downto 0);
	begin	
		b := bitmap(value*8+y);
		return b(7-x)='1';
	end digitpixel;


begin		

	pllclk48th: PLL378 port map ( CLK25, CLK48TH);
--	dmpram : DUMPRAM port map 
--	(	dumpdata,
--		dumprdaddress,
--		CLK12TH,
--		dumpwraddress,
--		CLK12TH,
--		'1',
--		dumpq
--	);
		
	process (CLK48TH)
	variable counter:std_logic_vector(1 downto 0) := "00";
	variable in_delay:std_logic := '0';
	variable prev_delay:std_logic := '0';	
	begin
		if rising_edge(CLK48TH) then
			if in_delay='1' and prev_delay='0' then
				-- stall the clock
			else
				-- progress normally
				if counter="00" then counter := "01"; 
				elsif counter="01" then counter := "10";
				elsif counter="10" then counter := "11";
				else counter := "00";
				end if;
			end if;
			
			prev_delay := in_delay;
			in_delay := DELAY48TH;			
		end if;
	
		CLK12TH <= counter(1);
	end process;
	
	
	
	process (CLK12TH)
	variable prev_lum : int8;
	variable in_lum : int8;	
	variable prev_crm : int8;	
	variable in_crm : int8;	
	
	variable needdelay : int4 := 0;
	variable delayrequest : std_logic := '0';
	variable subpixelcounter : int4 := 0;	
	variable syncrunning : int4 := 0;

	variable store_lumpixel : int8;
	variable store_chrompixel0 : int8;
	variable store_chrompixel1 : int8;
		
	variable out_clkpixel : std_logic := '0';
	variable out_syncstart: std_logic;
	variable out_lumpixel : int8;
	variable out_chrompixel : int8;
	variable out_dcpixel : sint8;
	
	variable diff : int7;
	variable diff2 : int7;
	begin
		if falling_edge(CLK12TH) then
			-- request additional tiny delays from the fast base clock
			if delayrequest='1' then
				delayrequest := '0';
			elsif needdelay>0 then
				needdelay := needdelay-1;
				delayrequest := '1';
			end if;
			
			-- take samples at correct times
			if subpixelcounter=REGISTERS(REG_LUMSAMPLE) mod 16 then
				store_lumpixel := (in_lum + prev_lum) / 2;
			end if;
			if subpixelcounter=REGISTERS(REG_CHROMSAMPLE) mod 16 then
				store_chrompixel0 := prev_crm;
				store_chrompixel1 := in_crm;
			end if;
						
			-- pass input values to lower clocked process (with enough setup time)
			if subpixelcounter=0 then
				out_lumpixel := store_lumpixel;
				out_chrompixel := store_chrompixel1; -- (store_chrompixel0 + store_chrompixel1)/2;
				out_dcpixel := store_chrompixel1 - store_chrompixel0;
				out_dcpixel := out_dcpixel + out_dcpixel + out_dcpixel + out_dcpixel/2;
				if syncrunning>0 then
					out_syncstart := '1';
				else
					out_syncstart := '0';
				end if;
			end if;

			-- count through the samples that belong to a single pixel
			if subpixelcounter<11 then				
				subpixelcounter:=subpixelcounter+1;				
				if subpixelcounter = 6 then
					out_clkpixel := '0';
				end if;
			else
				subpixelcounter := 0;
				out_clkpixel := '1';
			end if;
			
									
			-- detected falling sync. estimate time when the threashold was passed
			-- and compute delay that needs to be injected 
			if in_lum<=synclevel and prev_lum>synclevel and syncrunning=0 then
				subpixelcounter := 0;
				out_clkpixel := '0';
				syncrunning := 15; 
					
				diff := prev_lum - in_lum;
				diff2 := prev_lum - synclevel;
				if diff2 <= diff/4 then
					needdelay := 0 + 8;
				elsif	diff2 <= diff/2 then
					needdelay := 1 + 8;
				elsif diff2 <= diff/2 + diff/4 then
					needdelay := 2 + 8;
				else
					needdelay := 3 + 8;
				end if;
				
			-- let the sync inhib time pass
			elsif syncrunning > 0 then
				syncrunning := syncrunning -1;
			end if;	
						
			-- take next samples
			prev_lum := in_lum;
			in_lum := to_integer(unsigned(LUMA));
			prev_crm := in_crm;
			in_crm := to_integer(unsigned(CHROMA));
		end if;	
		
		DELAY48TH <= delayrequest;
		CLKADC <= CLK12TH;		
		
		CLKPIXEL <= out_clkpixel;
		SYNCSTART <= out_syncstart;
		LUMPIXEL <= out_lumpixel;
		CHROMPIXEL <= out_chrompixel;
		DCPIXEL <= out_dcpixel;

		TST <= out_clkpixel;	 	   
	end process;	

	
	
	process (CLKPIXEL)
		variable hcounter : int9 := 0;
		variable vcounter : int9 := 0;
	
		variable timesincesync : int9 := 0;
		variable foundshortsyncs : int5 := 0;
		variable blacklevel : int8;
		variable blacklevelaccu : integer range 0 to 524287 := 0;
		variable chromlevel : int8;
		variable chromlevelaccu : integer range 0 to 524287 := 0;
		type T_ref is array (0 to 15) of sint9;
		variable refchrom : T_ref;
		variable refdc : T_ref;
		
		variable tmp_lum : int8;
		variable tmp_chrom : sint9;
		variable redscore : sint16;
		variable cyanscore : sint16;
		variable purplescore : sint16;
		variable greenscore : sint16;
		variable bluescore : sint16;
		variable yellowscore : sint16;
		variable orangescore : sint16;
		variable brownscore : sint16;
		variable col : int4;
		
		variable tst: int4;
		variable tmps8: sint8;
		variable dumpdelay : integer range 0 to 63 := 0;
		variable dumpcounter : integer range 0 to 511 := 0;
		variable out_triggerdump : std_logic;
		
		variable out_csync : std_logic;
		variable out_y : int5;	
		variable out_pb : int5;
		variable out_pr : int5;		

		type T_paletteline is array (0 to 15) of int5;
		constant palettey : T_paletteline := 
		(0,  31, 5,  28, 14, 16,  2, 27, 19,  9, 19,  6, 14, 26, 13, 23);
		constant palettepb : T_paletteline := 
		(16, 16, 13, 16, 21, 12, 26,  8, 11, 11, 13, 16, 16,  8, 26, 16);
		constant palettepr : T_paletteline := 
		(16, 16, 24, 11, 22,  4, 14, 17, 21, 18, 24, 16, 16, 12,  6, 16);
		constant monopalettey : T_paletteline := 
		(0,  31, 8,  22, 12, 18,  4, 26, 12,  4, 18,  8, 14, 26, 14, 22);
	begin
	
		if rising_edge(CLKPIXEL) then
			-- scale luma and chroma to base levels
			if LUMPIXEL<blacklevel then
				tmp_lum := 0;
			else
				tmp_lum := LUMPIXEL - blacklevel;
			end if;
			tmp_chrom := CHROMPIXEL - chromlevel;

			-- generate output signal
			out_csync := '1';
			out_y := 0;			
			out_pb := 16;
			out_pr := 16;
				
			-- usable screen area
			if hcounter>=112 and hcounter<=460 and vcounter>=40 and vcounter<280 then			
				
				-- normal color operation mode
				if REGISTERS(REG_VISUALMODE)=0 or REGISTERS(REG_VISUALMODE)=1 then	
					-- calculate all color hit scores 
					if vcounter mod 2 = 0 then	-- even lines
						redscore := tmp_chrom*refchrom(3) + DCPIXEL*refdc(3);		
						cyanscore := tmp_chrom*refchrom(11) + DCPIXEL*refdc(11);
						purplescore := tmp_chrom*refchrom(5) + DCPIXEL*refdc(5);
						greenscore := tmp_chrom*refchrom(4) + DCPIXEL*refdc(4);
						bluescore := tmp_chrom*refchrom(0) + DCPIXEL*refdc(0);
						yellowscore := tmp_chrom*refchrom(8) + DCPIXEL*refdc(8);
						orangescore := tmp_chrom*refchrom(1) + DCPIXEL*refdc(1);
						brownscore := tmp_chrom*refchrom(8) + DCPIXEL*refdc(8);
					else  -- odd lines
						redscore := tmp_chrom*refchrom(8) + DCPIXEL*refdc(8);		
						cyanscore := tmp_chrom*refchrom(0) + DCPIXEL*refdc(0);
						purplescore := tmp_chrom*refchrom(6) + DCPIXEL*refdc(6);
						greenscore := tmp_chrom*refchrom(14) + DCPIXEL*refdc(14);
						bluescore := tmp_chrom*refchrom(11) + DCPIXEL*refdc(11);
						yellowscore := tmp_chrom*refchrom(3) + DCPIXEL*refdc(3);
						orangescore := tmp_chrom*refchrom(1) + DCPIXEL*refdc(1);
						brownscore := tmp_chrom*refchrom(10) + DCPIXEL*refdc(10);
					end if;					
					
					-- huge decision tree to determine the correct color
					if tmp_lum < REGISTERS(REG_THREASHOLD3) then
						if tmp_lum < REGISTERS(REG_THREASHOLD1) then
							if tmp_lum < REGISTERS(REG_THREASHOLD0) then
								-- black
								col := 0;		
							else
								-- blue or brown
								if bluescore >= brownscore then 
									col := 6;
								else  
									col := 9;
								end if;
							end if;
						else
							if tmp_lum < REGISTERS(REG_THREASHOLD2) then
								-- red or dark grey
								if redscore >= 16*REGISTERS(REG_DARKGRAY) then
									col := 2;
								else
									col := 11;
								end if;
							else
								-- purple or orange
								if purplescore >= orangescore then
									col := 4;
								else
									col := 8;
								end if;
							end if;						
						end if;
					else
						if tmp_lum < REGISTERS(REG_THREASHOLD5) then
							if tmp_lum < REGISTERS(REG_THREASHOLD4) then
								-- light blue or medium grey
								if bluescore > 16*REGISTERS(REG_MEDIUMGRAY) then
									col := 14;
								else 
									col := 12;
								end if;
							else
								-- light red or green
								if redscore > greenscore then
									col := 10;
								else
									col := 5;
								end if;
							end if;
						else
							if tmp_lum < REGISTERS(REG_THREASHOLD6) then
								-- cyan or light grey
								if cyanscore > 16*REGISTERS(REG_LIGHTGRAY) then
									col := 3;
								else
									col := 15;
								end if;
							elsif tmp_lum < REGISTERS(REG_THREASHOLD7) then
								-- yellow or light green
								if yellowscore>greenscore then
									col := 7;
								else
									col := 13;
								end if;
							else
								-- white
								col:= 1;
							end if;						
						end if;					
					end if;
		
					if REGISTERS(REG_VISUALMODE)=0 then
						out_y := palettey(col);
						out_pb := palettepb(col);
						out_pr := palettepr(col);
					else
						out_y := monopalettey(col);					
					end if;
					
				-- luminance calibration only
				elsif REGISTERS(REG_VISUALMODE)=2 then
					if tmp_lum>170 then
						out_y := 31;
					else
						out_y := (tmp_lum + tmp_lum/2) / 8;
					end if;
					
				-- chroma calibration only
				elsif REGISTERS(REG_VISUALMODE)=3 then
					if tmp_chrom<-128 then
						out_y := 0;
					elsif tmp_chrom>127 then
						out_y := 31;
					else	
						out_y := (tmp_chrom+128)/8;
					end if;
					
				-- fine chroma calibration
				elsif REGISTERS(REG_VISUALMODE)=4 then
					if tmp_chrom>15 then
						out_y := 31;
					elsif tmp_chrom<-16 then
						out_y := 0;
					else
						out_y := 16 + tmp_chrom;
					end if;
					
				-- dc calibration	
				elsif REGISTERS(REG_VISUALMODE)=5 then
					out_y := (128 + DCPIXEL) / 8;

					-- test color positions	
				elsif REGISTERS(REG_VISUALMODE)=6 then
					if vcounter=41 then
						out_y := (128 + refchrom(REGISTERS(1))) / 8;
					elsif vcounter=43 then
						out_y := (128 + tmp_chrom) / 8;
					elsif vcounter=47 then
						out_y := (128 + refdc(REGISTERS(1))) / 8;
					elsif vcounter=49 then
						out_y := (128 + DCPIXEL) / 8;
					elsif vcounter>=60 and vcounter mod 2 = 1 then	-- even lines
						redscore := tmp_chrom*refchrom(REGISTERS(1) mod 16) + DCPIXEL*refdc(REGISTERS(1) mod 16) ;
						if redscore>0 then
							if redscore>=8192 then
								out_y := 31;
							else
								out_y := redscore/256;
							end if;
						end if;
					end if;
				end if;				
				
			-- show register values
			elsif vcounter>=290 and vcounter<298 and hcounter>=128 and hcounter<128+8 then
				if digitpixel(SELECTEDREGISTER,hcounter-128,vcounter-290) then
					out_y := 18;
				end if;					
			elsif vcounter>=290 and vcounter<298 and hcounter>=144 and hcounter<144+8 then
				if digitpixel(REGISTERS(SELECTEDREGISTER)/16,hcounter-144,vcounter-290) then
					out_y := 18;
				end if;					
			elsif vcounter>=290 and vcounter<298 and hcounter>=152 and hcounter<152+8 then
				if digitpixel(REGISTERS(SELECTEDREGISTER) mod 16,hcounter-152,vcounter-290) then
					out_y := 18;
				end if;					
				
			-- calculate csync for PAL
			elsif (vcounter=0 or vcounter=1 or vcounter=2) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then -- short syncs
				out_csync := '0';
			elsif (vcounter=3 or vcounter=4) and (hcounter<252-17 or (hcounter>=252 and hcounter<504-34)) then        -- vsyncs
				out_csync := '0';
			elsif (vcounter=5) and (hcounter<252-34 or (hcounter>=252 and hcounter<252+17)) then                      -- one vsync, one short sync
				out_csync := '0';
			elsif (vcounter=6 or vcounter=7) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then            -- short syncs
				out_csync := '0'; 
			elsif (vcounter>=8) and (hcounter<34) then                                                                -- normal line syncs
				out_csync := '0';
			end if;
						
			-- accumulate black levels of large screen area
			if vcounter>=40 and vcounter<40+128 and hcounter>=48 and hcounter<48+16 then
				blacklevelaccu := blacklevelaccu + LUMPIXEL;
				chromlevelaccu := chromlevelaccu + CHROMPIXEL;
			elsif vcounter=20 and hcounter=0 then
				blacklevel := blacklevelaccu / 2048;
				blacklevelaccu := 0;
				chromlevel := chromlevelaccu / 2048;
				chromlevelaccu := 0;
			end if;
			
			-- cycle the chroma and dc reference values 
			tmps8 := refchrom(0);
			for I in 0 to 14 loop refchrom(I) := refchrom(I+1); end loop; 
			refchrom(15):=tmps8;
			tmps8 := refdc(0);
			for I in 0 to 14 loop refdc(I) := refdc(I+1); end loop; 
			refdc(15):=tmps8;
			-- during the color burst take reference samples for future comparisions
			if hcounter>=48 and hcounter<48+16 then
				refchrom(0) := tmp_chrom;
				refdc(0) := DCPIXEL;
			end if;
			
			-- progress position counters
			if hcounter<503 then
				hcounter := hcounter+1;			
			end if;			
		
			-- detect the sync signal edge and adjust counters
			if SYNCSTART='1' then
				if hcounter>375 then
					hcounter := 0;
					if vcounter<311 then
						vcounter:=vcounter+1;
					else
						vcounter:=0;
					end if;
				end if;
				if timesincesync<375 then
					if foundshortsyncs<31 then
						foundshortsyncs := foundshortsyncs+1;
					end if;
				else
					foundshortsyncs := 0;
				end if;
				if foundshortsyncs = 5 then
					vcounter := 0;
				end if;
				timesincesync:=0;
			elsif timesincesync<511 then
				timesincesync := timesincesync+1;
			end if;
		end if;
	
		
		Y <= out_csync & std_logic_vector(to_unsigned(out_y,5));
		Pb <= std_logic_vector(to_unsigned(out_pb, 5));
		Pr <= std_logic_vector(to_unsigned(out_pr, 5));
		
--		triggerdump <= out_triggerdump;
	end process;

	
	
	------ manage the settings registers 
	process (CLKPIXEL)
		variable delay:integer range 0 to 131071;   -- delay counter to handle input with only 50 Hz
		
		variable selected:int4 := 0;  -- currently selected register to change
		variable regs:T_REGISTERS := 
		(	0,         -- 0 REQ_VISUALMODE
			16#9B#,    -- 1 
			16#05#,    -- 2 REG_LUMSAMPLE	 	   
			16#0A#,    -- 3 REG_CHROMSAMPLE	 	   
			16#72#,    -- 4 
			16#49#,    -- 5 REG_DARKGRAY 
	      16#34#,    -- 6 REG_MEDIUMGRAY
	      16#E0#,    -- 7 REG_LIGHTGRAY
			16#0F#,    -- 8 REG_THREASHOLD0
			16#2E#,    -- 9 REG_THREASHOLD1
			16#39#,    -- A REG_THREASHOLD2
			16#42#,    -- B REG_THREASHOLD3
			16#53#,    -- C REG_THREASHOLD4
			16#59#,    -- D REG_THREASHOLD5
			16#82#,    -- E REG_THREASHOLD6
			16#9C#     -- F REG_THREASHOLD7
		);
		variable keys_in : std_logic_vector(2 downto 0) := "000";
		variable keys_prev : std_logic_vector(2 downto 0) := "000";		
	begin
		if rising_edge(CLKPIXEL) then
			if delay<131071 then
				delay:=delay+1;
			else
				delay:=0;
				
				-- press increase key
				if keys_in(2)='0' and keys_prev(2)='1' then
					regs(selected) := regs(selected)+1;
				end if;
				-- press decrease key
				if keys_in(1)='0' and keys_prev(1)='1' then
					regs(selected) := regs(selected)-1;
				end if;
				-- pressed select key
				if keys_in(0)='0' and keys_prev(0)='1' then
					selected := selected+1;				
				end if;				
				
				keys_prev := keys_in;
				keys_in := KEYS;
			end if;			
		end if;
		
		REGISTERS <= regs;
		SELECTEDREGISTER <= selected;
	end process;
	
	
--	-- output a dump of the samples via serial protocol 
--	process (CLK12TH, triggerdump)
--		variable readcursor : integer range 0 to 8191 := 8191;
--		variable writecursor : integer range 0 to 8191 := 8191;
--		variable writebit : integer range 0 to 21 := 0; -- two bytes, 1 start, 2 stop bits each
--		variable writedelay : integer range 0 to 819 := 0;  -- to get 115200 baud
--		
--		variable d : std_logic_vector(15 downto 0);
--		
--		variable out_data: std_logic_vector(15 downto 0);
--		variable out_bit : std_logic;
--		
--		variable in_trigger : std_logic := '0';
--		variable prev_trigger : std_logic := '0';  
--	begin
--		if rising_edge(CLK12TH) then
--			d := dumpq;
--         if writecursor=0 then
--				d := "1111111111111111";
--			end if;
--			
--			if writebit<11 then -- first byte
--				if writebit=0 then
--					out_bit := '0';  -- start bit
--				elsif writebit<=8 then  -- 1 .. 8
--					out_bit := d(writebit-1); -- LSB first
--				else			
--					out_bit := '1';  -- stop bit(s)
--				end if;
--			else   -- second byte
--				if writebit=11 then
--					out_bit := '0';  -- start bit
--				elsif writebit<=19 then  -- 12 .. 19
--					out_bit := d(8+writebit-12); -- LSB first
--				else			
--					out_bit := '1';  -- stop bit(s)
--				end if;			
--			end if;
--			
--			if readcursor<8191 then
--				readcursor := readcursor+1;
--			end if;
--				
--			if writedelay<819 then
--				writedelay := writedelay+1;
--			else
--				writedelay := 0;
--				if writebit<21 then
--					writebit:=writebit+1;
--				elsif writecursor<5999 then
--					writebit:=0;
--					writecursor:=writecursor+1;
--				end if;
--			end if;
--			
--			if in_trigger='1' and prev_trigger='0' then
--				readcursor := 0;
--				writecursor := 0;
--				writebit := 0;
--				writedelay := 0;
--			end if;
--		
--		
--			prev_trigger := in_trigger;
--			in_trigger := triggerdump;
--			
--			out_data := CHROMA & LUMA;
--		end if;
--
--		dumpdata <= out_data;
--		dumprdaddress <= std_logic_vector(to_unsigned(writecursor,13));
--		dumpwraddress <= std_logic_vector(to_unsigned(readcursor,13));
--		
--		TST <= '0'; -- out_bit;
--	end process;
		
end immediate;
