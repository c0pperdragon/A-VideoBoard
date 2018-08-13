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

	
	-- global signals and constants to tie processes together ---	
	
	signal CLK48TH : std_logic;          -- high speed clock to derive slower clocks from		
	signal DELAY48TH : std_logic;        -- rising edge signals request to delay the base clock
	signal CLK12TH : std_logic;          -- internal clock is synced to a 12th of a pixel
	
	signal CLKPIXEL : std_logic;         -- clock when a pixel is ready for computation
	signal SYNCSTART : std_logic; -- is '1' once when falling csync was detected
	signal LUMPIXEL : int8;     -- luma value for a pixel
	signal CHROMPIXEL0 : int8;  -- 1. chroma value for a pixel
	signal CHROMPIXEL1 : int8;  -- 2. chroma value for a pixel

	type T_REGISTERS is array (0 to 15) of int8;
	constant REG_VISUALMODE  : integer := 0;
	constant REG_SYNCDELAY   : integer := 1;
	constant REG_LUMSAMPLE   : integer := 2;
	constant REG_CHROMSAMPLE : integer := 3;
	constant REG_CHROMAZERO  : integer := 4;
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
		(	"00000000",
			"00111100",
			"01100110",
			"01101110",
			"01110110",
			"01100110",
			"00111100",
			"00000000",	
		
			"00000000",
			"00011000",
			"00111000",
			"00011000",
			"00011000",
			"00011000",
			"01111110",
			"00000000",		
			
			"00000000",			
			"00111100",
			"01100110",
			"00001100",
			"00011000",
			"00110000",
			"01111110",
			"00000000",		
			
			"00000000",			
			"01111110",
			"00001100",
			"00011000",
			"00001100",
			"01100110",
			"00111100",
			"00000000",		
			
			"00000000",			
			"00001100",
			"00011100",
			"00111100",
			"01101100",
			"01111110",
			"00001100",
			"00000000",		
			
			"00000000",			
			"01111110",
			"01100000",
			"01111100",
			"00000110",
			"01100110",
			"00111100",
			"00000000",		
			
			"00000000",			
			"00111100",
			"01100000",
			"01111100",
			"01100110",
			"01100110",
			"00111100",
			"00000000",		
			
			"00000000",			
			"01111110",
			"00000110",
			"00001100",
			"00011000",
			"00110000",
			"00110000",
			"00000000",		
			
			"00000000",			
			"00111100",
			"01100110",
			"00111100",
			"01100110",
			"01100110",
			"00111100",
			"00000000",		
			
			"00000000",			
			"00111100",
			"01100110",
			"00111110",
			"00000110",
			"00001100",
			"00111000",
			"00000000",		
			
			"00000000",			
			"00011000",
			"00111100",
			"01100110",
			"01100110",
			"01111110",
			"01100110",
			"00000000",		
			
			"00000000",			
			"01111100",
			"01100110",
			"01111100",
			"01100110",
			"01100110",
			"01111100",
			"00000000",		
			
			"00000000",			
			"00111100",
			"01100110",
			"01100000",
			"01100000",
			"01100110",
			"00111100",
			"00000000",		
			
			"00000000",			
			"01111000",
			"01101100",
			"01100110",
			"01100110",
			"01101100",
			"01111000",
			"00000000",		
			
			"00000000",			
			"01111110",
			"01100000",
			"01111100",
			"01100000",
			"01100000",
			"01111110",
			"00000000",		
			
			"00000000",			
			"01111110",
			"01100000",
			"01111100",
			"01100000",
			"01100000",
			"01100000",
			"00000000"		
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
	
	variable needdelay : int3 := 0;
	variable delayrequest : std_logic := '0';
	variable subpixelcounter : int4 := 0;	
	variable syncrunning : int4 := 0;

	variable store_lumpixel0 : int8;
	variable store_lumpixel1 : int8;
	variable store_chrompixel0 : int8;
	variable store_chrompixel1 : int8;
		
	variable out_clkpixel : std_logic := '0';
	variable out_syncstart: std_logic;
	variable out_lumpixel : int8;
	variable out_chrompixel0 : int8;
	variable out_chrompixel1 : int8;
	
	variable synclevel : integer range 0 to 255;
	variable diff : int7;
	variable diff2 : int7;
	begin
		if rising_edge(CLK12TH) then
			-- request additional tiny delays from the fast base clock
			if delayrequest='1' then
				delayrequest := '0';
			elsif needdelay>0 then
				needdelay := needdelay-1;
				delayrequest := '1';
			end if;
			
			-- take samples at correct times
			if subpixelcounter=REGISTERS(REG_LUMSAMPLE) mod 16 then
				store_lumpixel0 := prev_lum;
				store_lumpixel1 := in_lum;
			end if;
			if subpixelcounter=REGISTERS(REG_CHROMSAMPLE) mod 16 then
				store_chrompixel0 := prev_crm;
				store_chrompixel1 := in_crm;
			end if;
						
			-- pass input values to lower clocked process (with enough setup time)
			if subpixelcounter=0 then
				out_lumpixel := (store_lumpixel0 + store_lumpixel1) / 2;
				out_chrompixel0 := store_chrompixel0;
				out_chrompixel1 := store_chrompixel1;
			end if;

			-- count through the samples that belong to a single pixel
			if subpixelcounter<11 then				
				if subpixelcounter=0 and out_clkpixel='1' then
					out_syncstart:='0';
				end if;
				subpixelcounter:=subpixelcounter+1;				
				if subpixelcounter = 6 then
					out_clkpixel := '0';
				end if;
			else
				subpixelcounter := 0;
				out_clkpixel := '1';
			end if;
			
			-- generate the output sync pulse and let the inhib time pass
			if syncrunning>0 then
				syncrunning := syncrunning-1;
				out_syncstart := '1';
			else
				out_syncstart := '0';
			end if;
									
			-- detected falling sync. estimate time when the threashold was passed
			-- and compute delay that needs to be injected 
			synclevel := REGISTERS(REG_THREASHOLD0);
			if in_lum<=synclevel and prev_lum>synclevel and out_syncstart='0' then
				subpixelcounter := 0;
				out_clkpixel := '0';
				syncrunning := 13; -- out_syncstart := '1';
					
				diff := prev_lum - in_lum;
				diff2 := prev_lum - synclevel;
				if diff2 <= diff/4 then
					needdelay := 0;
				elsif	diff2 <= diff/2 then
					needdelay := 1;
				elsif diff2 <= diff/2 + diff/4 then
					needdelay := 2;
				else
					needdelay := 3;
				end if;
				needdelay := needdelay + (REGISTERS(REG_SYNCDELAY) mod 4);
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
		CHROMPIXEL0 <= out_chrompixel0;
		CHROMPIXEL1 <= out_chrompixel1;

		TST <= out_clkpixel;	 	   
	end process;	

	
	
	process (CLKPIXEL)
		variable hcounter : int9 := 0;
		variable vcounter : int9 := 0;
	
		variable timesincesync : int9 := 0;
		variable foundshortsyncs : int5 := 0;
		
		variable out_csync : integer range 0 to 1;
		variable out_lum : int5;	
		variable out_pb : int5;
		variable out_pr : int5;
		
		variable carrier : int8;
		
		variable dumpdelay : integer range 0 to 63 := 0;
		variable dumpcounter : integer range 0 to 511 := 0;
		variable out_triggerdump : std_logic;
		
	begin
	
		if rising_edge(CLKPIXEL) then
			-- generate output signal
			out_lum := 0;			
			out_csync := 1;
			out_pb := 16;
			out_pr := 16;
			if hcounter>=110 and hcounter<=460 and vcounter>=40 and vcounter<280 then			
				if REGISTERS(REG_VISUALMODE)=0 then	
					if LUMPIXEL < REGISTERS(REG_THREASHOLD4) then
						if LUMPIXEL < REGISTERS(REG_THREASHOLD2) then
							if LUMPIXEL < REGISTERS(REG_THREASHOLD1) then
								out_lum := 0;
							else
								out_lum := 4;
							end if;
						else
							if LUMPIXEL < REGISTERS(REG_THREASHOLD3) then
								out_lum := 8;
							else
								out_lum := 12;
							end if;						
						end if;
					else
						if LUMPIXEL < REGISTERS(REG_THREASHOLD6) then
							if LUMPIXEL < REGISTERS(REG_THREASHOLD5) then
								out_lum := 16;
							else
								out_lum := 20;
							end if;
						else
							if LUMPIXEL < REGISTERS(REG_THREASHOLD7) then
								out_lum := 25;
							else
								out_lum := 31;
							end if;						
						end if;					
					end if;
		
				elsif REGISTERS(REG_VISUALMODE)=1 then
					out_lum := LUMPIXEL/8;
				end if;				
				
			-- show register values
			elsif vcounter>=290 and vcounter<298 and hcounter>=128 and hcounter<128+8 then
				if digitpixel(SELECTEDREGISTER,hcounter-128,vcounter-290) then
					out_lum := 18;
				end if;					
			elsif vcounter>=290 and vcounter<298 and hcounter>=144 and hcounter<144+8 then
				if digitpixel(REGISTERS(SELECTEDREGISTER)/16,hcounter-144,vcounter-290) then
					out_lum := 18;
				end if;					
			elsif vcounter>=290 and vcounter<298 and hcounter>=152 and hcounter<152+8 then
				if digitpixel(REGISTERS(SELECTEDREGISTER) mod 16,hcounter-152,vcounter-290) then
					out_lum := 18;
				end if;					
			end if;				
						
			-- calculate csync for PAL
			if (vcounter=0 or vcounter=1 or vcounter=2) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then -- short syncs
				out_csync := 0;
			elsif (vcounter=3 or vcounter=4) and (hcounter<252-17 or (hcounter>=252 and hcounter<504-34)) then        -- vsyncs
				out_csync := 0;
			elsif (vcounter=5) and (hcounter<252-34 or (hcounter>=252 and hcounter<252+17)) then                      -- one vsync, one short sync
				out_csync := 0;
			elsif (vcounter=6 or vcounter=7) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then            -- short syncs
				out_csync := 0; 
			elsif (vcounter>=8) and (hcounter<34) then                                                                -- normal line syncs
				out_csync := 0;
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
				if foundshortsyncs = 3 then
					vcounter := 0;
				end if;
				timesincesync:=0;
			elsif timesincesync<511 then
				timesincesync := timesincesync+1;
			end if;
		end if;
	
		
		Y <= std_logic_vector(to_unsigned(out_lum+32*out_csync, 6));
		Pb <= std_logic_vector(to_unsigned(out_pb, 5));
		Pr <= std_logic_vector(to_unsigned(out_pr, 5));
		
--		triggerdump <= out_triggerdump;
	end process;

	
	
	------ manage the settings registers 
	process (CLKPIXEL)
		variable delay:integer range 0 to 131071;   -- delay counter to handle input with only 50 Hz
		
		variable selected:int4 := 0;  -- currently selected register to change
		variable regs:T_REGISTERS := 
		(	0,         -- REQ_VISUALMODE
			16#00#,    -- REG_SYNCDELAY
			16#08#,    -- REG_LUMSAMPLE	 	   
			16#09#,    -- REG_CHROMSAMPLE	 	   
			16#70#,    -- REG_CHROMAZERO
			0,
			0,
			0,
			16#40#,     -- REG_THREASHOLD0 (sync level)
			16#75#,     -- REG_THREASHOLD1
			16#8E#,     -- REG_THREASHOLD2
			16#9A#,     -- REG_THREASHOLD3
			16#A8#,     -- REG_THREASHOLD4
			16#C3#,     -- REG_THREASHOLD5
			16#DC#,     -- REG_THREASHOLD6
			16#F5#      -- REG_THREASHOLD7
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
