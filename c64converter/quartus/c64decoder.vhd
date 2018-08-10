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

	constant synclevel: integer := 70;

	
	-- global signals and constants to tie processes together ---	
	
	signal CLK48TH : std_logic;          -- high speed clock to derive slower clocks from		
	signal DELAY48TH : std_logic;        -- rising edge signals request to delay the base clock
	signal CLK12TH : std_logic;          -- internal clock is synced to a 12th of a pixel
	
	signal CLKPIXEL : std_logic;         -- clock when a pixel is ready for computation
	signal LUMPIXEL : int8;  -- luma value for a pixel
	signal CRM1PIXEL : int8; -- 1. chroma value for a pixel
	signal CRM2PIXEL : int8; -- 2. chroma value for a pixel

	type T_REGISTERS is array (0 to 7) of int8;
	constant REG_VISUALMODE : integer := 0;
--	constant REG_SYNCLEVEL : integer := 1;
	constant REG_SAMPLEDELAY : integer := 2;
	constant REG_CHROMAZERO  : integer := 3;
	
	signal REGISTERS : T_REGISTERS; 
	signal sELECTEDREGISTER : int3;		
	


	-- clock generator PLL
   component PLL378 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;

	
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
	
	-- toolbox functions to compute the phase and energy of a sinus signal, given two
	-- points of defined distance
	function computephase(y1: int8; y2:int8; zerolevel:int8) return int8
	is
		type T_quotient2angle is array (0 to 255) of int6;
		constant quotient2angle : T_quotient2angle := (
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,
			1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
			2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
			2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,
			3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,
			4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,
			6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,
			7,7,7,8,8,8,8,8,8,8,9,9,9,9,9,9,
			9,10,10,10,10,10,10,11,11,11,11,11,12,12,12,12,
			12,13,13,13,13,14,14,14,14,15,15,15,16,16,16,16,
			17,17,17,18,18,18,19,19,20,20,20,21,21,22,22,23,
			23,24,24,25,25,26,26,27,27,28,29,29,30,31,31,32,
			33,33,34,35,36,37,37,38,39,40,41,42,43,44,45,46,
			47,48,49,50,51,52,53,54,55,56,58,59,60,61,62,63	);
		variable abs1:int8;
		variable abs2:int8;		
		variable pos1:boolean;
		variable pos2:boolean;
		variable absbigger:int8;
		variable abssmaller:int8;
		variable quot:int8;
		variable angle:int6;
	begin		
		-- determine absolute values and memorize signs
		if y1>=zerolevel then
			pos1:=true;
			abs1:=y1-zerolevel;
		else
			pos1:=false;
			abs1:=zerolevel-y1;
		end if;
		if y2>=zerolevel then
			pos2:=true;
			abs2:=y2-zerolevel;
		else
			pos2:=false;
			abs2:=zerolevel-y2;
		end if;
				
		-- determine the quotient and look up the angle 
		if y1=y2 then
			if pos2 then 
				return 64;
			else
				return 192;
			end if;
		elsif abs1=abs2 then
			if pos2 then 
				return 0;
			else
				return 0128;
			end if;
		else
			if abs2>abs1 then
				absbigger := abs2;
				abssmaller := abs1;
			else		
				absbigger := abs1;
				abssmaller := abs2;
			end if;
			quot := (abssmaller*128) / absbigger;		
			if pos1=pos2 then
				quot := 128 + quot;
			else
				quot := 127 - quot;
			end if;
			angle := quotient2angle(quot);		
			-- determine the quadrant
			if abs2>abs1 then		
				if pos2 then
					return angle;
				else
					return 128+angle;
				end if;
			else			
				if pos1 then
					return 128-angle;
				else
					return  256-angle;
				end if;
			end if;		
		end if;		
	end computephase;	
	
	function computeenergy(y1: int8; y2:int8; zerolevel:int8) return int8	
	is
		variable abs2:int8;		
		variable difference:int8;
		variable tmp1:integer range 0 to 65535;
		variable tmp2:integer range 0 to 65535;
	begin
		-- determine absolute values
		if y2>=zerolevel then
			abs2:=y2-zerolevel;
		else
			abs2:=zerolevel-y2;
		end if;		
		-- compute the energy
		if y1>=y2 then
			difference := y1-y2;
		else
			difference := y2-y1;
		end if;
		tmp1 := abs2*abs2;
		tmp2 := difference*difference*11;
		return (tmp1+tmp2) / 256;	
	end computeenergy;


begin		

	pllclk48th: PLL378 port map ( CLK25, CLK48TH);
	
		
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
	variable diff : int7;
	variable diff2 : int7;
	variable in_crm : int8;	
	
	variable needdelay : int6 := 0;
	variable delayrequest : std_logic := '0';
	variable subpixelcounter : int4 := 0;	
		
	variable out_clkpixel : std_logic := '0';
	variable out_lumpixel : int8;
	variable out_crm1pixel : int8;
	variable out_crm2pixel : int8;
	
	begin
		if rising_edge(CLK12TH) then
			-- request additional delays from the fast base clock
			if delayrequest='1' then
				delayrequest := '0';
			elsif needdelay>0 then
				needdelay := needdelay-1;
				delayrequest := '1';
			end if;
			
			-- take samples at correct times
			if subpixelcounter=11 then
				out_crm2pixel := in_crm;
			elsif subpixelcounter=10 then
				out_lumpixel := in_lum;
				out_crm1pixel := in_crm;
			end if;

			-- count through the samples that belong to a single pixel
			if needdelay>=4 then
				needdelay := needdelay-4;
			else
				if subpixelcounter<11 then				
					subpixelcounter:=subpixelcounter+1;				
					if subpixelcounter = 6 then
						out_clkpixel := '1';
					end if;
				else
					subpixelcounter := 0;
					out_clkpixel := '0';
				end if;									
			end if;
									
			-- detected falling sync. estimate time when the threashold was passed
			-- and compute delay that needs to be injected 
			if in_lum<=synclevel and prev_lum>synclevel then
				needdelay := REGISTERS(REG_SAMPLEDELAY) mod 64;
				subpixelcounter := 6;
				out_clkpixel := '0';
				
				diff := prev_lum - in_lum;
				diff2 := prev_lum - synclevel;
				if diff2 <= diff/4 then
					needdelay := needdelay + 0;
				elsif	diff2 <= diff/2 then
					needdelay := needdelay + 1;
				elsif diff2 <= diff/2 + diff/4 then
					needdelay := needdelay + 2;
				else
					needdelay := needdelay + 3;
				end if;
			end if;			
						
			-- take next samples
			prev_lum := in_lum;
			in_lum := to_integer(unsigned(LUMA));
			in_crm := to_integer(unsigned(CHROMA));
		end if;	
		
		DELAY48TH <= delayrequest;
		CLKADC <= CLK12TH;		
		
		CLKPIXEL <= out_clkpixel;
		LUMPIXEL <= out_lumpixel;
		CRM1PIXEL <= out_crm1pixel;
		CRM2PIXEL <= out_crm2pixel;
	end process;	

	
	
	process (CLKPIXEL)
		variable hcounter : int9 := 0;
		variable vcounter : int9 := 0;
	
		variable syncduration : int9 := 0;
		variable foundshortsyncs : int5 := 0;
		variable out_csync : integer range 0 to 1;
		variable out_lum : int5;	
		variable out_pb : int5;
		variable out_pr : int5;
		
		variable carrier : int8;
	begin
	
		if rising_edge(CLKPIXEL) then
			-- generate output signal
			out_lum := 0;			
			out_csync := 1;
			out_pb := 16;
			out_pr := 16;
			if hcounter>=110 and hcounter<=460 and vcounter>=40 and vcounter<280 then			
				if REGISTERS(REG_VISUALMODE)=0 then			
					out_lum := LUMPIXEL/8;
				elsif REGISTERS(REG_VISUALMODE)=1 then
					carrier := (hcounter*9*16) mod 256;
					out_lum := LUMPIXEL/8;
					out_pb := (computephase(CRM1PIXEL,CRM2PIXEL, REGISTERS(REG_CHROMAZERO)) - carrier) / 8;
					out_pr := computeenergy(CRM1PIXEL,CRM2PIXEL, REGISTERS(REG_CHROMAZERO)) / 8;					
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
		
			-- detect the horizontal sync and adjust horizontal counter
			if LUMPIXEL<=synclevel then
				-- falling edge of csync
				if syncduration=0 then	 
					if foundshortsyncs=2 and vcounter>50 then
						-- force counters to the vsync point
						vcounter := 0;
						hcounter := 0;
					else
						if hcounter<50 then
							hcounter := 0;
						elsif hcounter>450 then
							hcounter := 0;	
							if vcounter<511 then
								vcounter := vcounter+1;
							end if;
						end if;
					end if;
					syncduration := 1;
				elsif syncduration<511 then
					syncduration := syncduration+1;					
				end if;				
				-- rising edge of csync: try to detect the short syncs
			elsif syncduration>0 then
				if syncduration>10 and syncduration<25 then					
					if foundshortsyncs<31  then
						foundshortsyncs := foundshortsyncs+1;
					end if;
				else	
					foundshortsyncs := 0;
				end if;
				syncduration := 0;
			end if;
		end if;
	
		
		Y <= std_logic_vector(to_unsigned(out_lum+32*out_csync, 6));
		Pb <= std_logic_vector(to_unsigned(out_pb, 5));
		Pr <= std_logic_vector(to_unsigned(out_pr, 5));
		
		TST <= '0'; --CLKPIXEL; 
	end process;

	
	
	------ manage the settings registers 
	process (CLKPIXEL)
		variable delay:integer range 0 to 131071;   -- delay counter to handle input with only 50 Hz
		
		variable selected:int3 := 0;  -- currently selected register to change
		variable regs:T_REGISTERS := 
		(	0,         -- REQ_VISUALMODE
			16#40#,    -- REG_SYNCLEVEL
			16#13#,    -- REG_SAMPLEDELAY	 	   
			16#70#,    -- REG_CHROMAZERO
			0, 
			0,
			0,
			0
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
	
		
end immediate;
