library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a GTIA emulation that sniffs all relevant
-- input pins of the GTIA and emulates the internal 
-- behaviour of the GTIA to finally create a YPbPr signal.

entity GTIA2YPbPr is	
	port (
		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- Connections to the real GTIAs pins 
		PHI2        : in std_logic;
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
	process (PHI2) 

  	type T_ataripalette is array (0 to 255) of integer range 0 to 65535;
   constant ataripalette : T_ataripalette := (
        16#8210#,16#8a10#,16#9210#,16#9a10#,16#a210#,16#aa10#,16#b210#,16#ba10#,16#c610#,16#ce10#,16#d610#,16#de10#,16#e610#,16#ee10#,16#f610#,16#fe10#,
        16#8dd2#,16#95b3#,16#9994#,16#9d95#,16#a575#,16#a956#,16#ad37#,16#b538#,16#b919#,16#c0fa#,16#c4da#,16#ccf9#,16#d138#,16#d957#,16#e175#,16#e594#,
        16#89f3#,16#8df4#,16#8dd6#,16#91d7#,16#95b8#,16#99ba#,16#99bb#,16#9d9c#,16#a19d#,16#a57f#,16#a57f#,16#b17e#,16#bd9c#,16#c5ba#,16#d1b8#,16#d9d6#,
        16#8a13#,16#8e14#,16#9235#,16#9637#,16#9a38#,16#9a39#,16#9e3a#,16#a23b#,16#a63c#,16#aa3e#,16#ae5f#,16#b63d#,16#c23b#,16#ca3a#,16#d238#,16#de36#,
        16#8a53#,16#8e54#,16#9275#,16#9696#,16#9a97#,16#9eb8#,16#a2d9#,16#a6da#,16#aafc#,16#af1d#,16#b31e#,16#befc#,16#c6da#,16#ceb9#,16#d697#,16#e275#,
        16#8a52#,16#8e72#,16#9293#,16#92b4#,16#96d4#,16#9af5#,16#9f16#,16#a337#,16#a357#,16#a778#,16#ab99#,16#b778#,16#bf37#,16#cb16#,16#d2d4#,16#deb3#,
        16#8670#,16#8a91#,16#8ab1#,16#8ed1#,16#8f11#,16#9331#,16#9351#,16#9771#,16#9792#,16#9bb2#,16#9bd2#,16#a7b2#,16#b371#,16#bf31#,16#cb11#,16#d6d1#,
        16#866f#,16#8a8f#,16#8aae#,16#8ece#,16#8eee#,16#932d#,16#934d#,16#976c#,16#978c#,16#9bac#,16#9bcb#,16#a7ac#,16#b36c#,16#bf2d#,16#caee#,16#d6ce#,
        16#8e4e#,16#926d#,16#968c#,16#9a8b#,16#9eab#,16#a2ca#,16#aae9#,16#aee8#,16#b307#,16#b726#,16#bb46#,16#c327#,16#cae8#,16#d2c9#,16#daab#,16#e28c#,
        16#922d#,16#9a2c#,16#a24a#,16#aa49#,16#ae68#,16#b666#,16#be65#,16#c284#,16#ca83#,16#d2a1#,16#daa0#,16#dea2#,16#e284#,16#e666#,16#ea68#,16#ee4a#,
        16#920d#,16#9a0c#,16#9deb#,16#a5e9#,16#ade8#,16#b1e7#,16#b9e6#,16#bde5#,16#c5e4#,16#cde2#,16#d1c1#,16#d5e3#,16#dde5#,16#e1e6#,16#e5e8#,16#edea#,
        16#91cd#,16#95cc#,16#9dab#,16#a18a#,16#a989#,16#ad68#,16#b547#,16#b946#,16#c124#,16#c503#,16#cd02#,16#d124#,16#d946#,16#dd67#,16#e589#,16#e9ab#,
        16#91ce#,16#99ae#,16#a18d#,16#a56c#,16#ad4c#,16#b52b#,16#b90a#,16#c0e9#,16#c8c9#,16#cca8#,16#d487#,16#d8a8#,16#dce9#,16#e50a#,16#e94c#,16#ed6d#,
        16#95b0#,16#9d8f#,16#a56f#,16#ad4f#,16#b50f#,16#bcef#,16#c4cf#,16#ccaf#,16#d48e#,16#dc6e#,16#e44e#,16#e86e#,16#e8af#,16#ecef#,16#f10f#,16#f54f#,
        16#95b1#,16#9d91#,16#a572#,16#ad52#,16#b532#,16#bcf3#,16#c4d3#,16#ccb4#,16#d494#,16#dc74#,16#e455#,16#e474#,16#e8b4#,16#ecf3#,16#f132#,16#f152#,
        16#8dd2#,16#95b3#,16#9994#,16#9d95#,16#a575#,16#a956#,16#ad37#,16#b538#,16#b919#,16#c0fa#,16#c4da#,16#ccf9#,16#d138#,16#d957#,16#e175#,16#e594#	
	 );	
	constant sync : integer := 0 + 16*32 + 16;
	
	-- visible screen area
	constant topedge    : integer := 42;
	constant bottomedge : integer := 282;
	constant leftedge   : integer := 41; 
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
	variable prevhalt : std_logic := '0';
	
	variable tmp_colorlines : std_logic_vector(8 downto 0);
	variable tmp_colorlines_res : std_logic_vector(8 downto 0);
	variable tmp_bgcolor : std_logic_vector(7 downto 0);
	variable tmp_4bitvalue : std_logic_vector(3 downto 0);
	variable tmp_color : std_logic_vector(7 downto 0);
	variable tmp_odd : boolean;
	variable tmp_ypbpr : std_logic_vector(15 downto 0);

	-- variables for player and missile display
	variable ticker_p0 : integer range 0 to 15 := 15;
	variable ticker_p1 : integer range 0 to 15 := 15;
	variable ticker_p2 : integer range 0 to 15 := 15;
	variable ticker_p3 : integer range 0 to 15 := 15;
	variable ticker_m0 : integer range 0 to 3 := 3;
	variable ticker_m1 : integer range 0 to 3 := 3;
	variable ticker_m2 : integer range 0 to 3 := 3;
	variable ticker_m3 : integer range 0 to 3 := 3;
	
	-- used for async operation in both halves of the clock --
	variable out_csync : std_logic  := '0';
	variable out_color : std_logic_vector(7 downto 0) := "00000000";
	variable out_overridelum : std_logic_vector(1 downto 0) := "00";
	
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
		if falling_edge(PHI2) then
			out_overridelum := "00";

			-- default color lines to show no color at all (only black)
			tmp_colorlines := "000000000";
			tmp_bgcolor := COLBK & "0";
			if PRIOR(7 downto 6)="11" then  -- single lum/16 hues mode makes background darkest
				tmp_bgcolor(3 downto 1) := "000";
			end if;
			
			-- compose the 4bit pixel value that is used in GTIA modes (peeking ahead for next antic command)
			if (hcounter mod 2) = 1 then
				tmp_4bitvalue := command(1 downto 0) & AN(1 downto 0);
			else 
				tmp_4bitvalue := prevcommand(1 downto 0) & command(1 downto 0);
			end if;

			----- process previously read antic command ---
			if command(2) = '1' then	 -- playfield command
				-- interpret bits according to gtia mode				
				case PRIOR(7 downto 6) is
				when "00" =>   -- 4-color playfield or 1.5-color highres
					if highres='0' then
						tmp_colorlines(4 + to_integer(unsigned(command(1 downto 0)))) := '1';
					else
						tmp_colorlines(6) := '1';
						out_overridelum := command(1 downto 0);
					end if;
				when "01"  =>   -- single hue, 16 luminances, imposed on background
					tmp_colorlines(8) := '1';
					tmp_bgcolor(3 downto 1) := COLBK(3 downto 1) or tmp_4bitvalue(3 downto 1);
					tmp_bgcolor(0) := tmp_4bitvalue(0);
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
					tmp_bgcolor(7 downto 4) := COLBK(7 downto 4) or tmp_4bitvalue;
					tmp_bgcolor(3 downto 0) := COLBK(3 downto 1) & "1";
				end case;
			elsif command(1) = '1' then  -- blank command (setting/clearing highres)
				highres := command(0);
			elsif  command(0) = '1' then  -- vsync command
			   -- has no effect here, will influence pixel counter 
			else                          -- background color
				tmp_colorlines(8) := '1';
				case PRIOR(7 downto 6) is
				when "00" =>    -- standard background color
				when "01"  =>   -- single hue, 16 luminances
				when "10" =>   -- indexed color look up 
					tmp_bgcolor := COLPM0 & "0";
				when "11" =>   -- 16 hues, single luminance
				tmp_bgcolor(3 downto 0) := "0000"; 	-- force luminance to 0
				end case;
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
			
					
		   -- apply priorities by suppressing correct color lines

			-- everything else cancels background
			if tmp_colorlines(7 downto 0) /= "00000000" then
				tmp_colorlines(8) := '0';
			end if;
			-- normally every PM cancels PM with higher index
			if PRIOR(5)='0' then
				if tmp_colorlines(0)='1' then
					tmp_colorlines(3 downto 1) := "000";
				elsif tmp_colorlines(1)='1' then
					tmp_colorlines(3 downto 2) := "00";			
				elsif tmp_colorlines(2)='1' then
					tmp_colorlines(3) := '0';			
				end if;
			-- in player multicolor mode, PM0/PM1 and PM2/PM3 each can coexist
			else 
				if tmp_colorlines(0)='1' or tmp_colorlines(1)='1' then
					tmp_colorlines(3 downto 2) := "00";
				end if;
			end if;
			-- normally playfield color lines can not be concurrently visible,
			-- but when 5th player is present, it cancels other colors
			if tmp_colorlines(7)='1' then
				tmp_colorlines(6 downto 4) := "000";
			end if;
			
			-- apply cancelation according to priority bits
			tmp_colorlines_res := tmp_colorlines;
			if PRIOR(0)='1' then
				-- PM cancels playfield
				if tmp_colorlines(3 downto 0) /= "0000" then
					tmp_colorlines_res(7 downto 4) := "0000";
				end if;
			end if;
			if PRIOR(1)='1' then 
				-- PM0/PM1 cancel playfield,  playfield cancels PM2/PM3
				if tmp_colorlines(1 downto 0) /= "00" then
					tmp_colorlines_res(7 downto 4) := "0000";
				end if;
				if tmp_colorlines(7 downto 4) /= "0000" then
					tmp_colorlines_res(3 downto 2) := "00";
				end if;
			end if;
			if PRIOR(2)='1' then 
				-- playfield cancels PM
				if tmp_colorlines(7 downto 4) /= "0000" then
					tmp_colorlines_res(3 downto 0) := "0000";
				end if;			
			end if;
			if PRIOR(3)='1' then 
				-- playfield 0/1 cancels PM, PM cancels playfield 2/3
				if tmp_colorlines(5 downto 4) /= "00" then
					tmp_colorlines_res(3 downto 0) := "0000";
				end if;			
				if tmp_colorlines(3 downto 0) /= "0000" then
					tmp_colorlines_res(7 downto 6) := "00";
				end if;			
			end if;
			
			-- simulate the 'wired or' that mixes together all bits of 
			-- all selected color lines
			out_color := "00000000";
			-- constrain color generation to screen boundaries
			if hcounter>=leftedge and hcounter<rightedge and vcounter>=topedge and vcounter<bottomedge then
				if tmp_colorlines_res(0)='1' then	out_color := out_color or (COLPM0 & "0"); end if;
				if tmp_colorlines_res(1)='1' then	out_color := out_color or (COLPM1 & "0"); end if;
				if tmp_colorlines_res(2)='1' then	out_color := out_color or (COLPM2 & "0"); end if;
				if tmp_colorlines_res(3)='1' then	out_color := out_color or (COLPM3 & "0"); end if;
				if tmp_colorlines_res(4)='1' then	out_color := out_color or (COLPF0 & "0"); end if;
				if tmp_colorlines_res(5)='1' then	out_color := out_color or (COLPF1 & "0"); end if;
				if tmp_colorlines_res(6)='1' then	out_color := out_color or (COLPF2 & "0"); end if;
				if tmp_colorlines_res(7)='1' then	out_color := out_color or (COLPF3 & "0"); end if;
				if tmp_colorlines_res(8)='1' then	out_color := out_color or tmp_bgcolor;    end if;
			else
				out_overridelum := "00";
			end if ;
			
			-- generate sync --
			out_csync := '0';
			if (vcounter<3 or vcounter=6 or vcounter=7) and (hcounter<9 or (hcounter>=114 and hcounter<114+9)) then     -- short syncs
				out_csync := '1';
			end if;
			if (vcounter=3 or vcounter=4) and (hcounter<105 or (hcounter>=114 and hcounter<114+105)) then           -- field syncs
				out_csync := '1';
			end if;
			if vcounter=5 and (hcounter<105 or (hcounter>=114 and hcounter<114+9)) then                      -- one field sync, one short sync
				out_csync := '1';
			end if;
			if (vcounter>=8) and (hcounter<18) then                                               -- normal line syncs
				out_csync := '1';
			end if;
			

			----- count horizontal and vertical pixels (vsync according to command)
			if command="001" then 
				hcounter := 1;
				vcounter := 0;
			else 
				if hcounter<227 then
					hcounter := hcounter+1;
				else 
					hcounter := 0;
					if vcounter<511 then 
						vcounter := vcounter+1;
					end if;
				end if;			
			end if;
			
			----- receive next antic command ----
			prevcommand := command;
			command := AN;
		end if;
		
		
		--------------------- logic for the cpu/data bus -------------------			
		if rising_edge(PHI2) then
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
			
			-- receive player/missile data via DMA
			if prevhalt='0' then
				tmp_odd := (vcounter mod 2) = 1;
				if GRACTL(1)='1' then
					if hcounter=3*2+1 and (VDELAY(4)='0' or tmp_odd) then
						GRAFP0 := D;
					end if;
					if hcounter=4*2+1 and (VDELAY(5)='0' or tmp_odd) then
						GRAFP1 := D;
					end if;
					if hcounter=5*2+1 and (VDELAY(6)='0' or tmp_odd) then
						GRAFP2 := D;
					end if;
					if hcounter=6*2+1 and (VDELAY(7)='0' or tmp_odd) then
						GRAFP3 := D;
					end if;
				end if;
				if GRACTL(0)='1' then
					if hcounter=1*2+1 then
						if VDELAY(0)='0' or tmp_odd then
							GRAFM(1 downto 0) := D(1 downto 0);
						end if;
						if VDELAY(1)='0' or tmp_odd then
							GRAFM(3 downto 2) := D(3 downto 2);
						end if;
						if VDELAY(2)='0' or tmp_odd then
							GRAFM(5 downto 4) := D(5 downto 4);
						end if;
						if VDELAY(3)='0' or tmp_odd then
							GRAFM(7 downto 6) := D(7 downto 6);
						end if;
					end if;
				end if;
			end if;
			prevhalt := HALT;
	
		end if;
		
		
		-------------------- asynchronous logic ---------------------
		-- select color value for proper half of the clock
		tmp_color := out_color;
		if PHI2='0' and out_overridelum(1)='1' then
			tmp_color(3 downto 0) := COLPF1(3 downto 1) & "0";  
		elsif PHI2='1' and out_overridelum(0)='1' then
			tmp_color(3 downto 0) := COLPF1(3 downto 1) & "0";  
		end if;		
		tmp_ypbpr := std_logic_vector(to_unsigned(ataripalette(to_integer(unsigned(tmp_color))), 16));	
		if out_csync='1' then
			tmp_ypbpr := std_logic_vector(to_unsigned(sync, 16));
		end if;
		
		Y <= tmp_ypbpr(15 downto 10);
		Pb <= tmp_ypbpr(9 downto 5);
		Pr <= tmp_ypbpr(4 downto 0);
				
	end process;
	
end immediate;

