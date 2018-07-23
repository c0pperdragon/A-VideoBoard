-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Converter is	
	port (
		-- reference clock
		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- commuication with the data aquisition
		-- extracted from C64 luma
		CSYNC: in std_logic;		  
		-- drive the ADC
		MCLK: out std_logic;
		VSMP: out std_logic;      
		RSMP: out std_logic;
		SCK: out std_logic;
		SDI: out std_logic;
		SEN: out std_logic;
		-- receive data back from ADC
		OP: in std_logic_vector(7 downto 0);

		-- debug output pins
		TST : out std_logic;       -- test output to show pixel clock
		TST2 : out std_logic       -- test output to show pixel clock
	);	
end entity;


architecture immediate of C64Converter is
	-- toolbox helper functions to transfer cartesian coordinates to polar coordinates
	subtype int8 is integer range 0 to 255;
	function atan2 (xabs:integer range 0 to 63; xpositive:boolean; yabs:integer range 0 to 63; ypositive:boolean) return int8 
	is	
		type T_inv is array (0 to 63) of integer range 0 to 4095;
		constant inv : T_inv := (
			4095,4095,2048,1365,1024,819,683,585,
			512,455,410,372,341,315,293,273,
			256,241,228,216,205,195,186,178,
			171,164,158,152,146,141,137,132,
			128,124,120,117,114,111,108,105,
			102,100,98,95,93,91,89,87,
			85,84,82,80,79,77,76,74,
			73,72,71,69,68,67,66,65
		);
		type T_atan is array(0 to 63) of integer range 0 to 31;
		constant atan : T_atan := (
			0,0,1,1,2,3,3,4,
			5,5,6,6,7,8,8,9,
			9,10,11,11,12,12,13,14,
			14,15,15,16,16,17,17,18,
			18,19,19,20,20,21,21,22,
			22,23,23,24,24,24,25,25,
			26,26,27,27,27,28,28,28,
			29,29,29,30,30,31,31,31
		);		
		variable slope : integer range 0 to 63;
		variable at : integer range 0 to 31;
	begin
		-- determine slope to use and atan
		if xpositive>ypositive then
			slope := (yabs * inv(xabs)) / 64;
		else
			slope := (xabs * inv(yabs)) / 64;
		end if;
		at := atan(slope);
		
		-- determine octant and compute angle (in range 0-255)
		if xabs=yabs then
			if xpositive then 
				if ypositive then return 32; else return 224; end if;
			else
				if ypositive then return 96; else return 160; end if;
			end if;
		elsif xabs>yabs then
			if xpositive then 
				if ypositive then return 0+at; else return 255-at; end if;
			else
				if ypositive then return 128-at; else return 128+at; end if;
			end if;
		else
			if xpositive then 
				if ypositive then return 64-at; else return 192+at; end if;
			else
				if ypositive then return 64+at; else return 192-at; end if;
			end if;
		end if;
	end atan2;
	
	function dsquared (xabs:integer range 0 to 63; yabs:integer range 0 to 63) return int8 
	is
		variable xsq : integer range 0 to 4095;
		variable ysq : integer range 0 to 4095;	
	begin
		xsq := xabs * xabs;
		ysq := yabs * yabs;
		if xsq+ysq>=4096 then
			return 255;
		else	
			return (xsq+ysq) / 16;
		end if;
	end dsquared;


	
	constant pixelfinedelay : integer := 15;		

   component PLL378 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;
   component PLL300 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;
	
	signal CLK48TH : std_logic;          -- high speed clock to derive slower clocks from	
	
	signal CLK : std_logic;              -- internal clock is synced to a 6th of a pixel
	signal SYNCDETECT: boolean;          -- encountered a falling csync. is active once during next CLK
	
begin		
	
	------- recover pixel clock timing from the C64 csync pulse -----	
	pllclk48th: PLL378 port map ( CLK25, CLK48TH);
	
	process (CLK48TH,CSYNC)
		variable in_csync : std_logic_vector(pixelfinedelay downto 0);
		
		variable counter: std_logic_vector(3 downto 0);
		variable out_syncdetect: boolean := false;
		
		variable tmp : integer range 0 to 15;
	begin
		if rising_edge(CLK48TH) then				
			tmp := to_integer(unsigned(counter));
			
			-- stretch clock after encountering a sync edge
			if in_csync(3 downto 0)="0111" then
				out_syncdetect := true;  -- prepare in time for next rising clock
			
				if tmp<8 then
					tmp := 1;
				else
					tmp := 9;
				end if;
				
			-- progress counter normally
			elsif tmp/=11 then
				if tmp=8 then
					out_syncdetect := false;	-- clear directly after the rising clock
				end if;
				
				tmp := tmp+1;				
			else
				tmp := 4;
			end if;
			
			counter := std_logic_vector(to_unsigned(tmp,4));
					
			-- use synchronizer chain to prevent metastability on asynchronous input
			in_csync := CSYNC & in_csync(pixelfinedelay downto 1);			
		end if;	

		
		CLK <= counter(2);		-- use this bit of the counter directly as the output clock 
		SYNCDETECT <= out_syncdetect;	 -- propagate sync detection
		
		TST2 <= in_csync(0);
	end process;
	
	
	-- progress the steps counter
	process (CLK)
		variable in_luma : integer range 0 to 255;
		variable in_chroma : integer range 0 to 255;
		variable in_chr2 : integer range 0 to 255;				

		variable step : integer range 0 to 5 := 0;
		variable hcounter : integer range 0 to 511 := 0;
		variable vcounter : integer range 0 to 511 := 0;
		variable carrierangle : integer range 0 to 255 := 0;
		
		variable chromamax : integer range 0 to 255 := 0;
		variable chromamin : integer range 0 to 255 := 0;
		variable chromaabs : integer range 0 to 63 := 0;
		variable chromapositive : boolean := false;
		variable chr2max : integer range 0 to 255 := 0;
		variable chr2min : integer range 0 to 255 := 0;
		variable chr2abs : integer range 0 to 63 := 0;
		variable chr2positive : boolean := false;
						
		variable out_pixel : std_logic := '0';
		variable out_mclk : std_logic := '0';		
		variable out_vsmp : std_logic := '0';

		variable out_y : integer range 0 to 63;
		variable out_pb : integer range 0 to 31;
		variable out_pr : integer range 0 to 31;		
		
		variable tmp_csync : integer range 0 to 1;
		variable chr2zero : integer range 0 to 255;
		variable chromazero : integer range 0 to 255;
		variable colorangle : integer range 0 to 255;
	begin

		-- operation for every 6th of a pixel
		if rising_edge(CLK) then		
			-- because computation is not fast enough to do everything in one clock, this is
			-- second pipelining stage
			if step=2 then
				-- calculate csync for PAL
				if (vcounter=0 or vcounter=1 or vcounter=2) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then -- short syncs
					tmp_csync := 0;
				elsif (vcounter=3 or vcounter=4) and (hcounter<252-17 or (hcounter>=252 and hcounter<504-34)) then        -- vsyncs
					tmp_csync := 0;
				elsif (vcounter=5) and (hcounter<252-34 or (hcounter>=252 and hcounter<252+17)) then                      -- one vsync, one short sync
					tmp_csync := 0;
				elsif (vcounter=6 or vcounter=7) and (hcounter<17 or (hcounter>=252 and hcounter<252+17)) then            -- short syncs
					tmp_csync := 0; 
				elsif (vcounter>=8) and (hcounter<34) then                                                                -- normal line syncs
					tmp_csync := 0;
				else
					tmp_csync := 1;
				end if;
				-- calculate current angle of the color signal (and take sample of color burst)
				colorangle := atan2(chr2abs, chr2positive, chromaabs, chromapositive);
				-- only show color inside a certain bound area
				if vcounter>40 and vcounter<300 and hcounter>100 and hcounter<480 then
					out_y := tmp_csync*32 + in_luma/8;
					if hcounter>=120 and hcounter<124 then
						out_pb := 1;
						out_pr := 1;
					elsif hcounter>=124 and hcounter<128 then
						out_pb := 31;
						out_pr := 31;
					elsif hcounter>=128 and hcounter<132 then
						out_pb := chromamin/8;
						out_pr := chr2min/8;
					elsif hcounter>=132 and hcounter<136 then
						out_pb := chromamax/8;
						out_pr := chr2max/8;
					else
						if vcounter mod 2 = 0 then
							out_pb := (colorangle - carrierangle)/8; 
						else
							out_pb := (carrierangle - colorangle)/8; 
						end if;
						out_pr := dsquared(chr2abs, chromaabs) / 8;
					end if;
				else
					out_y := tmp_csync*32;
					out_pb := 16;
					out_pr := 16;
				end if;				
				-- take angle of color burst for future comparisons
				if hcounter=70 then 
					carrierangle := colorangle;
				end if;					
			end if;
			-- when all values for a pixel are collected from the ADC, try to make sense of
			-- the values
			if step=1 then   -- this is the exact time when all three values are collected from the same sample		
				-- determine the minimum and maximum values for the chroma and its derivative signal
				if hcounter=40 then
					chromamax := 0;
					chromamin := 255;
					chr2max := 0;
					chr2min := 255;
				elsif hcounter<70 then
					if in_chroma>chromamax then chromamax := in_chroma; end if;
					if in_chroma<chromamin then chromamin := in_chroma; end if;
					if in_chr2<chr2min then chr2min := in_chr2; end if;
					if in_chr2>chr2max then chr2max := in_chr2; end if;			
				end if;	
				-- determine quadrant for chroma signal and make absolute distance values
				chr2zero := (chr2max+chr2min)/2;			
				if in_chr2>=chr2zero then 
					chr2positive := true;
					if in_chr2-chr2zero>=128 then chr2abs := 63; else chr2abs := (in_chr2-chr2zero) / 2; end if;
				else
					chr2positive := false; 
					if chr2zero-in_chr2>=128 then chr2abs := 63; else chr2abs := (chr2zero-in_chr2) / 2; end if;
				end if;
				chromazero := (chromamax+chromamin)/2;			
				if in_chroma>=chromazero then 
					chromapositive := true;
					if in_chroma-chromazero>=128 then chromaabs := 63; else chromaabs := (in_chroma-chromazero) / 2; end if;
				else
					chromapositive := false; 
					if chromazero-in_chroma>=128 then chromaabs := 63; else chromaabs := (chromazero-in_chroma) / 2; end if;
				end if;
			end if;			
		
		
			-- progress step counter (and use the new value in the same CLK)
			if SYNCDETECT then
				step := 0;
				-- progress vertical counter (detect vsync when hcounter contains only half a line)
				if hcounter<300 and vcounter>100 then
					vcounter := 0;
				elsif vcounter<511 then
					vcounter := vcounter+1;
				end if;
				hcounter := 0;		
				carrierangle := 0;		
			else
				-- step through pixel
				if step<5 then 
					step := step+1;
				else	
					step := 0;					
					-- progress horizontal counter
					if hcounter<511 then 
						hcounter := hcounter+1;
					end if;
					carrierangle := carrierangle + 7*16;
				end if;
			end if;
			
			-- generate the clock for the ADC
			if step mod 2 = 0 then
				out_mclk := '1';
			else
				out_mclk := '0';
			end if;
			
			-- generate debug output
			if step<3 then
				out_pixel := '0';
			else
				out_pixel := '1';
			end if;			
			
			-- read in first derivative of CHROMA (on the R analog input)
			if step=0 then
				in_chr2 := to_integer(unsigned(OP));
			-- read in LUM value (on the G analog input)
			elsif step=2 then
				in_luma := to_integer(unsigned(OP));
			-- read in CHROMA value (on the B analog input)
			elsif step=4 then
				in_chroma := to_integer(unsigned(OP));
			end if;
			
		end if;
		
		-- generate VSMP signal with slightly shifted phase
		if falling_edge(CLK) then
			if step=0 then
				out_vsmp := '1';
			else
				out_vsmp := '0';
			end if;
		end if;
		
		
      Y <= std_logic_vector(to_unsigned(out_y,6));
		Pb <= std_logic_vector(to_unsigned(out_pb, 5));		
		Pr <= std_logic_vector(to_unsigned(out_pr, 5));
		
		MCLK <= out_mclk;
		VSMP <= out_vsmp;
		RSMP <= '0';
		
		TST <= out_vsmp;
	end process;

	-- TODO: initialize the ADC
	process (CLK)
		constant numvalues: integer := 6;		
		type T_initvalues is array (0 to numvalues-1) of integer range 0 to 16383;
		constant initvalues : T_initvalues := 
		--   AAAAAADDDDDDDD
		(	2#00010000000000#,          -- software reset 
		   2#00000100000001#,          -- setup register 1: disable CDS
		   2#00001000100001#,          -- setup register 2: use only 8-bit data transfer
			2#00001100000110#,          -- setup register 3: set single ended reference voltage to approx. 1.1V
			2#00100000000000#,          -- setup register 6: disable Reset Level Clamping
			2#10101000000101#           -- set gain for B (chroma input) to 0.8
		);	
	
		variable delay:integer range 0 to 47;   -- delay counter to send data with 1Mhz
		variable r:integer range 0 to numvalues-1 := 0;
		variable stp:integer range 0 to 16*2 := 0;
		
		variable out_sck:std_logic:='0';
		variable out_sdi:std_logic:='0';
		variable out_sen:std_logic:='0';
		
		variable tmp: std_logic_vector(13 downto 0);
		
	begin
		if rising_edge(CLK) then
			if delay<47 then
				delay:=delay+1;
			else
				delay:=0;				
				if stp<16*2 then
					stp := stp+1;
				elsif r<numvalues-1 then
					r := r+1;
					stp := 0;
				end if;
			end if;			
				
			if stp<14*2 then
				tmp := std_logic_vector(to_unsigned(initvalues(r),14));
				out_sdi := tmp(13-stp/2);
			else
				out_sdi := '0';
			end if;

			if stp<14*2 and (stp mod 2=1) then
				out_sck := '1';
			else
				out_sck := '0';
			end if;
			
			if stp=15*2 then
				out_sen := '1';
			else
				out_sen := '0';
			end if;
		end if;
	
	
		SCK <= out_sck;
		SDI <= out_sdi;
		SEN <= out_sen;
	end process;
	
end immediate;
