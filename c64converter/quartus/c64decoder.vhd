library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Decoder is	
	port (
		-- input from the data aquisition
		CLKADC: in std_logic;
		LUMA: in std_logic_vector(7 downto 0);	
		CHROMA: in std_logic_vector(7 downto 0);
		
		-- output for further processing
		VSYNC: out boolean;   -- true when beginning a new frame
		HSYNC: out boolean;   -- true when beginning a new line		
		LUMINANCE: out integer range 0 to 255;   -- luma value 
		CHROMAPHASE: out integer range 0 to 255;  -- chroma angle relative to the color burst 
		CHROMAENERGY: out integer range 0 to 255;
		
		-- debugging signal
		CHROMAANGLE: out integer range 0 to 255; -- current angle of the chroma signal
		CHROMAX : out integer range 0 to 63;
		CHROMAXPOSITIVE : out boolean;
		CHROMAXD : out integer range 0 to 63;
		ChROMAXDPOSITIVE : out boolean
	);	
end entity;


architecture immediate of C64Decoder is

signal SIG_CHROMAANGLE: integer range 0 to 255;	
signal SIG_SUBCARRIER: integer range 0 to 255;	

begin		

	
	-- use the input luminance to determine horizontal and vertical syncs
	-- calculate the chroma phase by using the color burst as reference
	process (CLKADC)
		variable l_in : integer range 0 to 255 := 0;
		
		variable hcounter : integer range 0 to 65535 := 0;
		variable vcounter : integer range 0 to 511 := 0;
		
		variable samplecounter : integer range 0 to 2097151;
		variable samples205: integer range 0 to 2097151 := 0; -- determine number of samples in 205 lines
		variable subcarrier: integer range 0 to 4194303 := 0; -- subcarrier simulation
				
		variable out_vsync : boolean := false;
		variable out_hsync : boolean := false;
		variable out_luminance2 : integer range 0 to 255 := 0;
		variable out_luminance3 : integer range 0 to 255 := 0;
		variable out_luminance4 : integer range 0 to 255 := 0;
		
	begin	
		if rising_edge(CLKADC) then
			
			-- produce output sync signals 
			out_hsync := false;
			out_vsync := false;
			if hcounter = 0 then
				out_hsync := true;
				if vcounter = 1 then
					out_vsync := true;
				end if;
			end if;			
			
			
			-- generate the subcarrier signal 
			if hcounter=536 then
				subcarrier := SIG_CHROMAANGLE * 8192; -- use the color burst to sync subcarrier
			else
				subcarrier := subcarrier + 116235; -- twice the subcarrier ticks in 205 lines
				if subcarrier >= 2*samples205 then
					subcarrier := subcarrier-2*samples205;
				end if;
			end if;
			
			-- count and memorize the number of samples in 205 lines (should be near 2^21 in total)
			if hcounter=1 and vcounter=215 then
				samples205 := samplecounter;
			end if;
			if hcounter=1 and vcounter=10 then				
				samplecounter :=0;
			else
				samplecounter := samplecounter+1;
			end if;

			-- detect start of lines and synchronize horizontal 80mhz counter			
			if l_in<50 and hcounter>4000 then
				hcounter := 0;
				vcounter := vcounter+1;				
			elsif l_in<50 and hcounter=1600 then
				vcounter := 0;
			else
				hcounter := hcounter+1;				
			end if;		
								
			-- compute luminance value and push through pipeline
			out_luminance4 := out_luminance3;
			out_luminance3 := out_luminance2;
			if l_in<76 then
				out_luminance2 := 0;
			else
				out_luminance2 := (l_in-76);
			end if;					
		
			-- sampling input luma		
			l_in := to_integer(unsigned(LUMA));
		end if;		
		
		-- output for further processing
		HSYNC <= out_hsync;
		VSYNC <= out_vsync;
		LUMINANCE <= out_luminance4;
		SIG_SUBCARRIER <= subcarrier / 8192;
		
		-- debug output

	end process;

		
		
	-- decoding the current angle of the chroma signal wave
	process (CLKADC)		
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
		constant chroma_center:integer := 124;
	
		variable c_next : integer range 0 to 255 := 0;			
		variable c_in : integer range 0 to 255 := 0;
		variable c_prev : integer range 0 to 255 := 0;
		
		variable x : integer range 0 to 63;
		variable xpositive : boolean;
		variable xd : integer range 0 to 63;
		variable xdpositive : boolean;
		
		variable slope : integer range 0 to 63;
		variable baseangle : integer range 0 to 255;
		variable use_negatively : boolean;
		variable energy1: integer range 0 to 4095;
		variable energy2: integer range 0 to 4095;
		
		variable phase : integer range 0 to 255;
		variable angle : integer range 0 to 255;
		variable energy: integer range 0 to 255;		
		
		variable tmp: integer range 0 to 255;
	begin
	
		if rising_edge(CLKADC) then
			
			-- stage 4: calculate chroma angle	
			if use_negatively then 
				angle := baseangle - atan(slope);
			else
				angle := baseangle + atan(slope);
			end if;
			-- use the subcarrier in combination with the current ANGLE to extract the PHASE			
			phase := angle - SIG_SUBCARRIER;
			
			-- stage 4: pass on chroma energy 
			energy := energy1 / 16;
			
			-- stage 3: compute x/xd slope values and prepare next computations
			slope := 0;
			use_negatively := false;
			if x=xd then
				if xpositive then 
					if xdpositive then baseangle:=32; else baseangle:=224; end if;
				else
					if xdpositive then baseangle:=96; else baseangle:=160; end if;
				end if;
			elsif x>xd then
				slope := (xd * inv(x)) / 64;
				if xpositive then 
					if xdpositive then baseangle:=0; else baseangle:=255; use_negatively:=true; end if;
				else
					if xdpositive then baseangle:=128; use_negatively:=true; else baseangle:=128; end if;
				end if;
			else
				slope := (x * inv(xd)) / 64;
				if xpositive then 
					if xdpositive then baseangle:=64; use_negatively:=true; else baseangle:=192; end if;
				else
					if xdpositive then baseangle:=64; else baseangle:=192; use_negatively:=true; end if;
				end if;
			end if;			
			-- stage 3: calculate the chroma energy
			energy1 := x*x;
			energy2 := xd*xd;
			if energy1+energy2<=4095 then
				energy1 := energy1 + energy2;
			else
				energy1 := 4095;
			end if;
			
			-- stage 2: compute and scale the x,xd values
			if c_in>=chroma_center then 
				xpositive := true;
				if c_in-chroma_center>=128 then
					x := 63;
				else
					x := (c_in-chroma_center) / 2;
				end if;
			else
				xpositive := false;
				if chroma_center-c_in>=128 then
					x := 63;
				else
					x := (chroma_center-c_in) / 2;
				end if;
			end if;
			
			if c_next>=c_prev then 
				xdpositive := false;
				tmp := c_next-c_prev;
			else
				xdpositive := true;
				tmp := c_prev-c_next;
			end if;
			if tmp<=92 then
				xd := (tmp*11)/16;
			else	
				xd := 63;
			end if;
							
			-- stage 1: sample input data 
			c_prev := c_in;
			c_in := c_next;
			c_next := to_integer(unsigned(CHROMA));			
		end if;
		
		-- output
		CHROMAANGLE <= angle;
		SIG_CHROMAANGLE <= angle;		
		CHROMAENERGY <= energy;
		CHROMAPHASE <= phase;
		-- debug output
		CHROMAX <= x;
		CHROMAXPOSITIVE <= xpositive;
		CHROMAXD <= xd;
		ChROMAXDPOSITIVE <= xdpositive;
	
	end process;	

end immediate;