library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a GTIA emulation that sniffs all relevant
-- input pins of the GTIA and emulates the internal 
-- behaviour of the GTIA to finally create a YPbPr signal.
-- Output is generated at every falling edge of the CLK

entity GTIA2YPbPr is	
	port (
		-- standard definition YPbPr output
		SDTV_Y:  out std_logic_vector(5 downto 0);	
		SDTV_Pb: out std_logic_vector(4 downto 0); 
		SDTV_Pr: out std_logic_vector(4 downto 0); 
		
		-- synchronous clock and phase of the atari clock cylce
		CLK         : in std_logic;
		PHASE       : in std_logic_vector(1 downto 0); 
		
		-- Connections to the real GTIAs pins 
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		RW          : in std_logic;
		CS          : in std_logic;
		HALT        : in std_logic
	);	
end entity;


architecture immediate of GTIA2YPbPr is
begin
	process (CLK,PHASE) 

  	type T_ataripalette is array (0 to 255) of integer range 0 to 32767;
   constant ataripalette : T_ataripalette := (
		  16#0210#,16#0a10#,16#1210#,16#1a10#,16#2210#,16#2a10#,16#3210#,16#3a10#,16#4210#,16#4a10#,16#4e10#,16#5a10#,16#5e10#,16#5e10#,16#6610#,16#6e10#,
        16#09f3#,16#11d4#,16#15b4#,16#1d94#,16#2574#,16#2d54#,16#3134#,16#3915#,16#40f5#,16#44d5#,16#4cd5#,16#58d5#,16#5cd5#,16#5cd5#,16#64d4#,16#68d4#,
        16#09f4#,16#0dd5#,16#15b5#,16#1995#,16#2175#,16#2956#,16#3136#,16#3936#,16#4136#,16#4936#,16#4d56#,16#5936#,16#5d36#,16#5d55#,16#6555#,16#6954#,
        16#09f4#,16#0df5#,16#11f5#,16#19f5#,16#21f5#,16#29f5#,16#31f5#,16#39f5#,16#41f5#,16#49f5#,16#4df5#,16#55f5#,16#5df5#,16#5df5#,16#65f4#,16#69f4#,
        16#0a72#,16#0e73#,16#1294#,16#1a94#,16#2294#,16#2a94#,16#3294#,16#3a94#,16#4294#,16#4a94#,16#4e94#,16#5a94#,16#5e94#,16#5e94#,16#6674#,16#6e73#,
        16#0af0#,16#0f11#,16#1312#,16#1b12#,16#2312#,16#2b12#,16#3312#,16#3b12#,16#4312#,16#4b12#,16#4ef2#,16#56d2#,16#5ab2#,16#5ab2#,16#6292#,16#6a72#,
        16#0b4e#,16#0f6e#,16#136f#,16#1b8f#,16#238f#,16#2b8f#,16#336f#,16#374f#,16#3f2f#,16#4710#,16#4ef0#,16#52d0#,16#56d0#,16#5ab0#,16#6290#,16#6a70#,
        16#0b6e#,16#0f8e#,16#138d#,16#1b8d#,16#238c#,16#2b8d#,16#336d#,16#374d#,16#3f2d#,16#470d#,16#4aed#,16#52ce#,16#56ce#,16#5aae#,16#5e8e#,16#666e#,
        16#0b2f#,16#134d#,16#174c#,16#1b4c#,16#234b#,16#2b6b#,16#336b#,16#3b4b#,16#3f2b#,16#470b#,16#4eec#,16#52cc#,16#5aac#,16#5aac#,16#628c#,16#6a6c#,
        16#0aae#,16#0ecd#,16#16cc#,16#1acb#,16#22ea#,16#2aea#,16#32ea#,16#3aea#,16#42ea#,16#4aea#,16#4eea#,16#56ca#,16#5aab#,16#5e8b#,16#628b#,16#6a6b#,
        16#0a0e#,16#120d#,16#162c#,16#1a2b#,16#222b#,16#2a2b#,16#322b#,16#3a2b#,16#422b#,16#462b#,16#4e2b#,16#562b#,16#5e2b#,16#5e2b#,16#662b#,16#6e2b#,
        16#09ee#,16#0dce#,16#15ad#,16#19ac#,16#218c#,16#258c#,16#318c#,16#358c#,16#3d8c#,16#458c#,16#4d8c#,16#558c#,16#5d8c#,16#5d8c#,16#658c#,16#6d8c#,
        16#09ee#,16#0dce#,16#15ae#,16#1d8e#,16#256e#,16#294e#,16#312e#,16#390e#,16#3d0e#,16#450e#,16#4d0e#,16#550e#,16#5d0e#,16#5d0e#,16#650e#,16#6cee#,
        16#09ef#,16#11d0#,16#15b0#,16#1d90#,16#2570#,16#2d50#,16#3130#,16#3911#,16#40f1#,16#48d1#,16#4cb1#,16#54b1#,16#5c91#,16#5c91#,16#6491#,16#6c91#,
        16#09f2#,16#11d2#,16#19b2#,16#1d92#,16#2572#,16#2d53#,16#3533#,16#3913#,16#40f3#,16#48d3#,16#4cb3#,16#5493#,16#5c93#,16#5c93#,16#6493#,16#6c93#,
        16#09f3#,16#11d3#,16#19b3#,16#2194#,16#2574#,16#2d54#,16#3534#,16#3d14#,16#40f5#,16#48d5#,16#50d5#,16#58d5#,16#5cd5#,16#60d5#,16#64d4#,16#6cd3#
    );	
	
	-- visible screen area
	constant topedge    : integer := 45;
	constant bottomedge : integer := 285;
	constant leftedge   : integer := 45; 
	constant rightedge  : integer := 217;
	
	-- registers of the GTIA
	variable HPOSP0 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP1 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP2 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP3 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM0 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM1 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM2 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM3 : std_logic_vector (7 downto 0) := "00000000";
	variable SIZEP0 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP1 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP2 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP3 : std_logic_vector (1 downto 0) := "00";
	variable SIZEM  : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP0 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP1 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP2 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP3 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFM  : std_logic_vector (7 downto 0) := "00000000";
	variable COLPM0 : std_logic_vector (7 downto 1) := "0001100";
	variable COLPM1 : std_logic_vector (7 downto 1) := "0010100";
	variable COLPM2 : std_logic_vector (7 downto 1) := "0011100";
	variable COLPM3 : std_logic_vector (7 downto 1) := "0010000";
	variable COLPF0 : std_logic_vector (7 downto 1) := "0100010";
	variable COLPF1 : std_logic_vector (7 downto 1) := "1100110";
	variable COLPF2 : std_logic_vector (7 downto 1) := "0110100";
	variable COLPF3 : std_logic_vector (7 downto 1) := "0111111";
	variable COLBK  : std_logic_vector (7 downto 1) := "0000000";
	variable PRIOR  : std_logic_vector (7 downto 0) := "00000000";
	variable VDELAY : std_logic_vector (7 downto 0) := "00000000";
	variable GRACTL : std_logic_vector (2 downto 0) := "000";

	-- variables for synchronious operation
	variable hcounter : integer range 0 to 227 := 0;
	variable vcounter : integer range 0 to 511 := 0;
	variable highres : std_logic := '0';
	variable command : std_logic_vector(2 downto 0) := "000";
	variable prevcommand : std_logic_vector(2 downto 0) := "000";
	variable prevrw: std_logic := '0';
	variable prevhalt: std_logic := '0';
	
	-- variables for player and missile display
	variable ticker_p0 : integer range 0 to 15 := 15;
	variable ticker_p1 : integer range 0 to 15 := 15;
	variable ticker_p2 : integer range 0 to 15 := 15;
	variable ticker_p3 : integer range 0 to 15 := 15;
	variable ticker_m0 : integer range 0 to 3 := 3;
	variable ticker_m1 : integer range 0 to 3 := 3;
	variable ticker_m2 : integer range 0 to 3 := 3;
	variable ticker_m3 : integer range 0 to 3 := 3;
		
	-- delayed p/m data
	variable GRAFP0_DELAYED : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP1_DELAYED : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP2_DELAYED : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP3_DELAYED : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFM_DELAYED  : std_logic_vector (7 downto 0) := "00000000";	
	
	-- temporary variables
	variable tmp_colorlines : std_logic_vector(8 downto 0);
	variable tmp_colorlines_res0 : std_logic_vector(8 downto 0);
	variable tmp_colorlines_res1 : std_logic_vector(8 downto 0);
	variable tmp_colorlines_res2 : std_logic_vector(8 downto 0);
	variable tmp_colorlines_res3 : std_logic_vector(8 downto 0);
	variable tmp_bgcolor : std_logic_vector(7 downto 0);
	variable tmp_4bitvalue : std_logic_vector(3 downto 0);
	variable tmp_odd : boolean;
	variable tmp_x : integer range 0 to 255;
	variable tmp_y : integer range 0 to 511;	
	variable tmp_color : std_logic_vector(7 downto 0);	
	variable tmp_ypbpr : std_logic_vector(14 downto 0);
	
	-- registered output 
	variable csync : std_logic := '1';
	variable color : std_logic_vector(7 downto 0) := "00000000";
	variable overridelum : std_logic_vector(1 downto 0) := "00";
	
	variable out_Y  : std_logic_vector(5 downto 0) := "000000";
	variable out_Pb : std_logic_vector(4 downto 0) := "10000";
	variable out_Pr : std_logic_vector(4 downto 0) := "10000";
	
	
		-- test, if it is now necessary to increment player/missile pixel counter
		function needpixelstep (hpos:std_logic_vector(7 downto 0); size: std_logic_vector(1 downto 0)) return boolean is
		variable x:std_logic_vector(1 downto 0);
		begin
			x := std_logic_vector(to_unsigned(hcounter,2));
			case size is 
			when "00" => return true;               -- single size
			when "01" => return x(0)=hpos(0);       -- double size
			when "10" => return true;               -- single size
			when "11" => return x=hpos(1 downto 0); -- 4 times size
			end case;
		end needpixelstep;			

	begin
		--------------------- logic for antic input -------------------
		if rising_edge(CLK) and PHASE="10" then
			-- default color lines to show no color at all (only black)
			overridelum := "00";
			tmp_colorlines := "000000000";
						
			-- compose the 4bit pixel value that is used in GTIA modes (peeking ahead for next antic command)
			if (hcounter mod 2) = 1 then
				tmp_4bitvalue := command(1 downto 0) & AN(1 downto 0);
				if PRIOR(7 downto 6)="10" and command(2)='1' and AN(2)='0' and tmp_4bitvalue/="0000" then  -- background color command in 9-color mode
					tmp_4bitvalue := "1000";
				end if;
			else 
				tmp_4bitvalue := prevcommand(1 downto 0) & command(1 downto 0);
				if PRIOR(7 downto 6)="10" and prevcommand(2)='1' and command(2)='0' and tmp_4bitvalue/="0000" then -- background color command in 9-color mode
					tmp_4bitvalue := "1000";
				end if;
			end if;
			
			
			-- chose proper background color for special color interpretation modes
			case PRIOR(7 downto 6) is
			when "00" =>    -- standard background color
				tmp_bgcolor := COLBK & "0";
			when "01"  =>   -- single hue, 16 luminances
				tmp_bgcolor(7 downto 4) := COLBK(7 downto 4);
				tmp_bgcolor(3 downto 0) := (COLBK(3 downto 1) & '0') or tmp_4bitvalue;
			when "10" =>   -- indexed color look up 
				tmp_bgcolor := COLBK & "0";
			when "11" =>   -- 16 hues, single luminance
				tmp_bgcolor(7 downto 4) := COLBK(7 downto 4) or tmp_4bitvalue;
				tmp_bgcolor(3 downto 0) := COLBK(3 downto 1) & "1";
			end case;

			----- process previously read antic command ---
			if command(2) = '1' then	 -- playfield command
				-- interpret bits according to gtia mode				
				case PRIOR(7 downto 6) is
				when "00" =>   -- 4-color playfield or 1.5-color highres
					if highres='0' then
						tmp_colorlines(4 + to_integer(unsigned(command(1 downto 0)))) := '1';
					else
						tmp_colorlines(6) := '1';
						overridelum := command(1 downto 0);				
					end if;
				when "01"  =>   -- single hue, 16 luminances, imposed on background
					tmp_colorlines(8) := '1';
				when "10" =>   -- indexed color look up 
					case tmp_4bitvalue is
					when "0000" => tmp_colorlines(0) := '1';
					when "0001" => tmp_colorlines(1) := '1';
					when "0010" => tmp_colorlines(2) := '1';
					when "0011" => tmp_colorlines(3) := '1';
					when "0100" => tmp_colorlines(4) := '1';
					when "0101" => tmp_colorlines(5) := '1';
					when "0110" => tmp_colorlines(6) := '1';
					when "0111" => tmp_colorlines(7) := '1';
					when "1000" => tmp_colorlines(8) := '1';
					when "1001" => tmp_colorlines(8) := '1';
					when "1010" => tmp_colorlines(8) := '1';
					when "1011" => tmp_colorlines(8) := '1';
					when "1100" => tmp_colorlines(4) := '1';
					when "1101" => tmp_colorlines(5) := '1';
					when "1110" => tmp_colorlines(6) := '1';
					when "1111" => tmp_colorlines(7) := '1';
					end case;
				when "11"  =>   -- 16 hues, single luminance, imposed on background
					tmp_colorlines(8) := '1';
				end case;
			elsif command(1) = '1' then  -- blank command (setting/clearing highres)
				highres := command(0);
			elsif  command(0) = '1' then  -- vsync command
			   -- has no effect here, will influence pixel counter 
			else                          -- background color
				if PRIOR(7 downto 6)="10" then 
					case tmp_4bitvalue is
					when "0000" => tmp_colorlines(0) := '1';
					when "0001" => tmp_colorlines(1) := '1';
					when "0010" => tmp_colorlines(2) := '1';
					when "0011" => tmp_colorlines(3) := '1';
					when "0100" => tmp_colorlines(4) := '1';
					when "0101" => tmp_colorlines(5) := '1';
					when "0110" => tmp_colorlines(6) := '1';
					when "0111" => tmp_colorlines(7) := '1';
					when "1000" => tmp_colorlines(8) := '1';
					when "1001" => tmp_colorlines(8) := '1';
					when "1010" => tmp_colorlines(8) := '1';
					when "1011" => tmp_colorlines(8) := '1';
					when "1100" => tmp_colorlines(4) := '1';
					when "1101" => tmp_colorlines(5) := '1';
					when "1110" => tmp_colorlines(6) := '1';
					when "1111" => tmp_colorlines(7) := '1';
					end case;
				else
					tmp_colorlines(8) := '1';					
				end if;
			end if;

	      -- determine which part of players and missiles are visible
			if ticker_p0<8 and  GRAFP0(7-ticker_p0)='1' then
				tmp_colorlines(0) := '1';
			end if;
			if ticker_p1<8 and GRAFP1(7-ticker_p1)='1' then
				tmp_colorlines(1) := '1';
			end if;
			if ticker_p2<8 and GRAFP2(7-ticker_p2)='1' then
				tmp_colorlines(2) := '1';
			end if;
			if ticker_p3<8 and GRAFP3(7-ticker_p3)='1' then
				tmp_colorlines(3) := '1';
			end if;
			if ticker_m0<2 and GRAFM(0 + (1-ticker_m0))='1' then
			   if PRIOR(4)='1' then
					tmp_colorlines(7) := '1';
				else 
					tmp_colorlines(0) := '1';
				end if;
			end if;
			if ticker_m1<2 and GRAFM(2 + (1-ticker_m1))='1' then
			   if PRIOR(4)='1' then
					tmp_colorlines(7) := '1';
				else 
					tmp_colorlines(1) := '1';
				end if;
			end if;
			if ticker_m2<2 and GRAFM(4 + (1-ticker_m2))='1' then
			   if PRIOR(4)='1' then
					tmp_colorlines(7) := '1';
				else 
					tmp_colorlines(2) := '1';
				end if;
			end if;
			if ticker_m3<2 and GRAFM(6 + (1-ticker_m3))='1' then
			   if PRIOR(4)='1' then
					tmp_colorlines(7) := '1';
				else 
					tmp_colorlines(3) := '1';
				end if;
			end if;
				
		   -- trigger start of display of players and missiles ---			
			if hcounter=to_integer(unsigned(HPOSP0)) then 
				ticker_p0 := 0;
			elsif ticker_p0<8 and needpixelstep(HPOSP0,SIZEP0(1 downto 0)) then 
				ticker_p0 := ticker_p0 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSP1)) then 
				ticker_p1 := 0;
			elsif ticker_p1<8 and needpixelstep(HPOSP1,SIZEP1(1 downto 0)) then 
				ticker_p1 := ticker_p1 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSP2)) then 
				ticker_p2 := 0;
			elsif ticker_p2<8 and needpixelstep(HPOSP2,SIZEP2(1 downto 0)) then 
				ticker_p2 := ticker_p2 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSP3)) then 
				ticker_p3 := 0;
			elsif ticker_p3<8 and needpixelstep(HPOSP3,SIZEP3(1 downto 0)) then 
				ticker_p3 := ticker_p3 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSM0)) then 
				ticker_m0 := 0;
			elsif ticker_m0 < 2 and needpixelstep(HPOSM0,SIZEM(1 downto 0)) then 
				ticker_m0 := ticker_m0 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSM1)) then 
				ticker_m1 := 0;
			elsif ticker_m1 < 2 and needpixelstep(HPOSM1,SIZEM(3 downto 2)) then 
				ticker_m1 := ticker_m1 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSM2)) then 
				ticker_m2 := 0;
			elsif ticker_m2 < 2 and needpixelstep(HPOSM2,SIZEM(5 downto 4)) then 
				ticker_m2 := ticker_m2 + 1;
			end if;
			if hcounter=to_integer(unsigned(HPOSM3)) then 
				ticker_m3 := 0;
			elsif ticker_m3 < 2 and needpixelstep(HPOSM3,SIZEM(7 downto 6)) then 
				ticker_m3 := ticker_m3 + 1;
			end if;
			
					
		   -- apply priorities by suppressing specific color lines

			-- everything else cancels background immediately
			if tmp_colorlines(7 downto 0) /= "00000000" then
				tmp_colorlines(8) := '0';
			end if;
			
			-- apply cancelation according to priority bits (works in parallel)
			tmp_colorlines_res0 := tmp_colorlines;
			if PRIOR(0)='1' then 
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res0(3 downto 2) := "00"; end if;
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res0(5 downto 4) := "00"; end if;
				if tmp_colorlines(3 downto 2)/="00" then tmp_colorlines_res0(5 downto 4) := "00"; end if;
				if tmp_colorlines(3 downto 2)/="00" then tmp_colorlines_res0(7 downto 6) := "00"; end if;
			end if;
			tmp_colorlines_res1 := tmp_colorlines;
			if PRIOR(1)='1' then 
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res1(3 downto 2) := "00"; end if;
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res1(5 downto 4) := "00"; end if;
				if tmp_colorlines(7 downto 6)/="00" then tmp_colorlines_res1(3 downto 2) := "00"; end if;
			end if;
			tmp_colorlines_res2 := tmp_colorlines;
			if PRIOR(2)='1' then 
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res2(3 downto 2) := "00"; end if;
				if tmp_colorlines(5 downto 4)/="00" then tmp_colorlines_res2(1 downto 0) := "00"; end if;
				if tmp_colorlines(7 downto 6)/="00" then tmp_colorlines_res2(1 downto 0) := "00"; end if;
				if tmp_colorlines(7 downto 6)/="00" then tmp_colorlines_res2(3 downto 2) := "00"; end if;
			end if;
			tmp_colorlines_res3 := tmp_colorlines;
			if PRIOR(3)='1' then 
				if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines_res3(3 downto 2) := "00"; end if;
				if tmp_colorlines(3 downto 2)/="00" then tmp_colorlines_res3(7 downto 6) := "00"; end if;
				if tmp_colorlines(5 downto 4)/="00" then tmp_colorlines_res3(1 downto 0) := "00"; end if;
				if tmp_colorlines(5 downto 4)/="00" then tmp_colorlines_res3(7 downto 6) := "00"; end if;
			end if; 			
			tmp_colorlines := tmp_colorlines_res0 and tmp_colorlines_res1 and tmp_colorlines_res2 and tmp_colorlines_res3;
			
			-- apply final cancelation to the "surviving" color lines
			if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines(3 downto 2) := "00"; end if;
			if tmp_colorlines(1 downto 0)/="00" then tmp_colorlines(7 downto 6) := "00"; end if;
			if tmp_colorlines(5 downto 4)/="00" then tmp_colorlines(3 downto 2) := "00"; end if;
			if tmp_colorlines(7 downto 6)/="00" then tmp_colorlines(5 downto 4) := "00"; end if;
			-- only one playfield color will be shown 
			if tmp_colorlines(7)/='0' then tmp_colorlines(6) := '0'; end if;
			if PRIOR(5)='0' then  -- no multicolor players allowed
				if tmp_colorlines(0)/='0' then tmp_colorlines(1) := '0'; end if;
				if tmp_colorlines(2)/='0' then tmp_colorlines(3) := '0'; end if;
			end if;
			
			-- simulate the 'wired or' that mixes together all bits of 
			-- all still selected color lines
			color := "00000000";
			-- constrain color generation to screen boundaries
			if hcounter>=leftedge and hcounter<rightedge and vcounter>=topedge and vcounter<bottomedge then
				if tmp_colorlines(0)='1' then	color := color or (COLPM0 & "0"); end if;
				if tmp_colorlines(1)='1' then	color := color or (COLPM1 & "0"); end if;
				if tmp_colorlines(2)='1' then	color := color or (COLPM2 & "0"); end if;
				if tmp_colorlines(3)='1' then color := color or (COLPM3 & "0"); end if;
				if tmp_colorlines(4)='1' then	color := color or (COLPF0 & "0"); end if;
				if tmp_colorlines(5)='1' then	color := color or (COLPF1 & "0"); end if;
				if tmp_colorlines(6)='1' then	color := color or (COLPF2 & "0"); end if;
				if tmp_colorlines(7)='1' then	color := color or (COLPF3 & "0"); end if;
				if tmp_colorlines(8)='1' then	color := color or tmp_bgcolor;    end if;
			else
				overridelum := "00";
			end if ;
			
			-- generate csync for PAL 288p signal (adjusting timing a bit to get screen correctly alligned) 	
			if hcounter>0 then
				tmp_x := hcounter - 1;
				tmp_y := vcounter + 4;
			else
				tmp_x := 227;
				tmp_y := vcounter + 4 - 1;
			end if;
			if tmp_y>=312 then
				tmp_y := tmp_y-312;
			end if;
			if (tmp_y=0 or tmp_y=1 or tmp_y=2) and (tmp_x<8 or (tmp_x>=114 and tmp_x<114+8)) then        -- short syncs
				csync := '0';
			elsif (tmp_y=3 or tmp_y=4) and (tmp_x<114-16 or (tmp_x>=114 and tmp_x<228-16)) then          -- vsyncs
				csync := '0';
			elsif (tmp_y=5) and (tmp_x<114-16 or (tmp_x>=114 and tmp_x<114+8)) then                      -- one vsync, one short sync
				csync := '0';
			elsif (tmp_y=6 or tmp_y=7) and (tmp_x<8 or (tmp_x>=114 and tmp_x<114+8)) then                -- short syncs
				csync := '0';
			elsif (tmp_y>=8) and (tmp_x<16) then                                                         -- normal line syncs
				csync := '0';
			else
				csync := '1';
			end if;
			
			----- count horizontal and vertical pixels (vsync according to command)
			if command="001" and vcounter>128 then 
				hcounter := 2;               -- because of this tweak, there will be 2 pixels in the 312th row 
				vcounter := 0;               -- (but because the lines start with sync all the same, it makes no difference)
 			else 
				if hcounter<227 then
					hcounter := hcounter+1;
				else 
					hcounter := 0;
					if vcounter< 511 then 
						vcounter := vcounter+1;
					end if;
				end if;			
			end if;
			
			----- receive next antic command ----
			prevcommand := command;
			command := AN;
		end if;
		
		
		------------ select output color for both halves of the atari clock ---------
		if rising_edge(CLK) and (PHASE="11" or PHASE="01") then
			if csync='0' then
				out_y := "000000";
				out_pb := "10000";
				out_pr := "10000";
			else			
				tmp_color := color;
				if (PHASE="01" and overridelum(0)='1') or (PHASE="11" and overridelum(1)='1')  then
					tmp_color(3 downto 0) := COLPF1(3 downto 1) & "0";  
				end if;				
				tmp_ypbpr := std_logic_vector(to_unsigned(ataripalette(to_integer(unsigned(tmp_color))), 15));			
				out_y(5) := '1';
				out_y(4 downto 0) := tmp_ypbpr(14 downto 10);
				out_pb := tmp_ypbpr(9 downto 5);
				out_pr := tmp_ypbpr(4 downto 0);
			end if;
		end if;		
		
		
		--------------------- logic for the cpu/data bus -------------------			
		if rising_edge(CLK) and PHASE="00" then
			----- let CPU write to the registers (at second clock where rw is asserted) --
			if (CS='0') and (RW='0') and (prevrw='0') then
				case A is
					when "00000" => HPOSP0 := D;
					when "00001" => HPOSP1 := D;
					when "00010" => HPOSP2 := D;
					when "00011" => HPOSP3 := D;
					when "00100" => HPOSM0 := D;
					when "00101" => HPOSM1 := D;
					when "00110" => HPOSM2 := D;
					when "00111" => HPOSM3 := D;				
					when "01000" => SIZEP0 := D(1 downto 0);
					when "01001" => SIZEP1 := D(1 downto 0);
					when "01010" => SIZEP2 := D(1 downto 0);
					when "01011" => SIZEP3 := D(1 downto 0);
					when "01100" => SIZEM  := D;
					when "01101" => GRAFP0 := D;
					when "01110" => GRAFP1 := D;
					when "01111" => GRAFP2 := D;
					when "10000" => GRAFP3 := D;
					when "10001" => GRAFM  := D;					
					when "10010" => COLPM0 := D(7 downto 1);
					when "10011" => COLPM1 := D(7 downto 1);
					when "10100" => COLPM2 := D(7 downto 1);
					when "10101" => COLPM3 := D(7 downto 1);
					when "10110" => COLPF0 := D(7 downto 1);
					when "10111" => COLPF1 := D(7 downto 1);
					when "11000" => COLPF2 := D(7 downto 1);
					when "11001" => COLPF3 := D(7 downto 1);
					when "11010" => COLBK  := D(7 downto 1);
					when "11011" => PRIOR  := D;
					when "11100" => VDELAY := D;
					when "11101" => GRACTL := D(2 downto 0);
					when "11110" => 
					when "11111" => 
				end case;
			end if;	
			prevrw := RW; 
		end if;
		
		if rising_edge(CLK) and PHASE="00" then
			if prevhalt='0' and vcounter>=topedge and vcounter<bottomedge then
				tmp_odd := (vcounter mod 2) = 0;
			
				-- transfer dma player/missile data into registers
				if GRACTL(0)='1' and hcounter=3 then
					if VDELAY(0)='0' or tmp_odd then
						GRAFM(1 downto 0) := D(1 downto 0);
					else
						GRAFM(1 downto 0) := GRAFM_DELAYED(1 downto 0);
						GRAFM_DELAYED(1 downto 0) := D(1 downto 0);
					end if;
					if VDELAY(1)='0' or tmp_odd then
						GRAFM(3 downto 2) := D(3 downto 2);
					else
						GRAFM(3 downto 2) := GRAFM_DELAYED(3 downto 2);
						GRAFM_DELAYED(3 downto 2) := D(3 downto 2);
					end if;
					if VDELAY(2)='0' or tmp_odd then
						GRAFM(5 downto 4) := D(5 downto 4);
					else
						GRAFM(5 downto 4) := GRAFM_DELAYED(5 downto 4);
						GRAFM_DELAYED(5 downto 4) := D(5 downto 4);
					end if;
					if VDELAY(3)='0' or tmp_odd then
						GRAFM(7 downto 6) := D(7 downto 6);
					else
						GRAFM(7 downto 6) := GRAFM_DELAYED(7 downto 6);
						GRAFM_DELAYED(7 downto 6) := D(7 downto 6);
					end if;
				end if;				
				if GRACTL(1)='1' and hcounter=7 then
					if VDELAY(4)='0' or tmp_odd then
						GRAFP0 := D;
					else  
						GRAFP0 := GRAFP0_DELAYED;
						GRAFP0_DELAYED := D;
					end if;
				end if;
				if GRACTL(1)='1' and hcounter=9 then
					if VDELAY(5)='0' or tmp_odd then 
						GRAFP1 := D;
					else  
						GRAFP1 := GRAFP1_DELAYED;
						GRAFP1_DELAYED := D;
					end if;
				end if;
				if GRACTL(1)='1' and hcounter=11 then
					if VDELAY(6)='0' or tmp_odd then
						GRAFP2 := D;
					else 
						GRAFP2 := GRAFP2_DELAYED;
						GRAFP2_DELAYED := D;
					end if;
				end if;
				if GRACTL(1)='1' and hcounter=13 then
					if VDELAY(7)='0' or tmp_odd then 
						GRAFP3 := D;
					else
						GRAFP3 := GRAFP3_DELAYED;
						GRAFP3_DELAYED := D;
					end if;
				end if;
			end if;
			
			prevhalt := HALT;
		end if;		
		
		
		-------------------- output signals ---------------------		
		SDTV_Y <= out_y;
		SDTV_Pb <= out_pb;
		SDTV_Pr <= out_pr;				
	end process;
	
end immediate;

