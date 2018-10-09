library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a VIC emulation that sniffs all relevant
-- input/output pins of the VIC and emulates the internal 
-- behaviour of the VIC to finally create a YPbPr signal.
-- Output is generated at every falling edge of the CLK

entity VIC2YPbPr is	
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
end entity;


architecture immediate of VIC2YPbPr is
begin
	process (CLK) 

  	type T_c64palette is array (0 to 15) of integer range 0 to 32767;
   constant c64palette : T_c64palette := 
	(	 0*1024 + 16*32 + 16,  -- black
		31*1024 + 16*32 + 16,  -- white
		 5*1024 + 13*32 + 24,  -- red
		28*1024 + 16*32 + 11,  -- cyan
		14*1024 + 21*32 + 22,  -- purple
		16*1024 + 12*32 + 4,   -- green
		 2*1024 + 26*32 + 4,   -- blue
		27*1024 +  8*32 + 17,  -- yellow
		19*1024 + 11*32 + 21,  -- orange
		 9*1024 + 11*32 + 18,  -- brown
		19*1024 + 13*32 + 24,  -- light red
		 6*1024 + 16*32 + 16,  -- dark gray
		14*1024 + 16*32 + 16,  -- medium gray
		26*1024 +  8*32 + 12,  -- light green
		13*1024 + 26*32 +  6,  -- light blue
		23*1024 + 16*32 + 16   -- light gray		
	); 
	-- visible screen area
	constant totalvisiblewidth : integer := 390;
	constant totalvisibleheight : integer := 270;
	
	-- registers of the VIC and their default values
	variable sprite0x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite0y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite1x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite1y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite2x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite2y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite3x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite3y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite4x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite4y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite5x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite5y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite6x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite6y:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite7x:         std_logic_vector(7 downto 0) := "00000000";
	variable sprite7y:         std_logic_vector(7 downto 0) := "00000000";
	variable spritexhighbits:  std_logic_vector(7 downto 0) := "00000000";
	variable control1:         std_logic_vector(7 downto 0) := "00011011";
	variable spriteactive:     std_logic_vector(7 downto 0) := "00000000";
	variable control2:         std_logic_vector(7 downto 0) := "11001000";
	variable doubleheight:     std_logic_vector(7 downto 0) := "00000000";
	variable spritepriority:   std_logic_vector(7 downto 0) := "00000000";
	variable spritemulticolor: std_logic_vector(7 downto 0) := "00000000";
	variable doublewidth:      std_logic_vector(7 downto 0) := "00000000";
	variable bordercolor:      std_logic_vector(3 downto 0) := "1110";
	variable backgroundcolor:  std_logic_vector(3 downto 0) := "0110";
	variable backgroundcolor1: std_logic_vector(3 downto 0) := "0001";
	variable backgroundcolor2: std_logic_vector(3 downto 0) := "0010";
	variable backgroundcolor3: std_logic_vector(3 downto 0) := "0011";
	variable spritecolor1:     std_logic_vector(3 downto 0) := "0100";
	variable spritecolor2:     std_logic_vector(3 downto 0) := "0000";
	variable sprite0color:     std_logic_vector(3 downto 0) := "0001";
	variable sprite1color:     std_logic_vector(3 downto 0) := "0010";
	variable sprite2color:     std_logic_vector(3 downto 0) := "0011";
	variable sprite3color:     std_logic_vector(3 downto 0) := "0100";
	variable sprite4color:     std_logic_vector(3 downto 0) := "0101";
	variable sprite5color:     std_logic_vector(3 downto 0) := "0110";
	variable sprite6color:     std_logic_vector(3 downto 0) := "0111";
	variable sprite7color:     std_logic_vector(3 downto 0) := "1100";
	
	
	-- variables for synchronious operation
	variable phase: integer range 0 to 15 := 0;         -- phase inside of the cycle
	variable cycle : integer range 0 to 63 := 0;        -- cpu cycle
	variable displayline: integer range 0 to 511 := 0;  -- VIC-II line numbering

	type T_videomatrix is array (0 to 39) of std_logic_vector(11 downto 0);
	variable videomatrix : T_videomatrix;
	variable pixelpattern : std_logic_vector(26 downto 0);
	variable mainborderflipflop : std_logic := '0';
	variable verticalborderflipflop : std_logic := '0';
		
	variable noAECrunlength : integer range 0 to 32767 := 0;
	variable didinitialsync : boolean := false;
		
	-- registered output 
	variable out_Y  : std_logic_vector(5 downto 0) := "000000";
	variable out_Pb : std_logic_vector(4 downto 0) := "10000";
	variable out_Pr : std_logic_vector(4 downto 0) := "10000";

	-- temporary stuff
	variable hcounter : integer range 0 to 511;      -- pixel in current scan line
	variable vcounter : integer range 0 to 511 := 0; -- current scan line 
	variable xcoordinate : integer range 0 to 511;   -- x-position in sprite coordinates
	variable tmp_c : integer range 0 to 15;
	variable tmp_ypbpr : std_logic_vector(14 downto 0);
	variable tmp_vm : std_logic_vector(11 downto 0);
	variable tmp_pixelindex : integer range 0 to 511;
	variable tmp_hscroll : integer range 0 to 7;
	variable tmp_lefthit : boolean;
	variable tmp_tophit : boolean;
	variable tmp_righthit: boolean;
	variable tmp_bottomhit: boolean;
		
	begin
		-- synchronous logic -------------------
		if rising_edge(CLK) then
			-- convert from C64 cycle/lines  to  hcounter,vcounter for generating syncs and such 
			vcounter := displayline+18;
			hcounter := (cycle-1)*8 + phase/2;
			if hcounter>=8 then
				hcounter:=hcounter-8;
			else
				hcounter:=hcounter+504-8;
				vcounter:=vcounter-1;
			end if;
			if vcounter>=312 then vcounter := vcounter-312;	end if;
			-- coordinates for sprite display and the border engine
			xcoordinate := cycle*8 - 7 + phase/2;
			if xcoordinate>=14*8 then
				xcoordinate := xcoordinate-14*8;
			else
				xcoordinate := 0;
			end if;
			
			-- generate pixel output (as soon as sync was found)	
			if (phase mod 2) = 0 and didinitialsync then   
			
				-- output defaults to black (no csync active)
				out_Y  := "100000";
				out_Pb := "10000";
				out_Pr := "10000";
	
				-- area where any color is shown (including border)
				if hcounter>=92 and hcounter<92+totalvisiblewidth 
				and vcounter>=34 and vcounter<34+totalvisibleheight then
				
					-- main screen area color processing
					tmp_c := to_integer(unsigned(backgroundcolor));					
					if cycle>=18 and cycle<58 then
						tmp_hscroll := to_integer(unsigned(control2(2 downto 0)));
						tmp_pixelindex := (cycle-17) * 8 + phase/2 - tmp_hscroll;
						if tmp_pixelindex>=8 then
							tmp_vm := videomatrix((tmp_pixelindex-8)/8);
						else
							tmp_vm := "000000000000";
						end if;
						
						if pixelpattern(19 + tmp_hscroll)='1' then
							tmp_c := to_integer(unsigned(tmp_vm(11 downto 8)));
						end if;
					end if;
					
					-- overlay with border 
					if mainborderflipflop='1' then
						tmp_c := to_integer(unsigned(bordercolor));
					end if;
					
					-- generate the YPbPr signal using a fixed palette
					tmp_ypbpr := std_logic_vector(to_unsigned(c64palette(tmp_c),15));
					out_Y := '1' & tmp_ypbpr(14 downto 10);
					out_Pb := tmp_ypbpr(9 downto 5);
					out_Pr := tmp_ypbpr(4 downto 0);
	
				-- generate csync for PAL 288p signal
				elsif (vcounter=0) and (hcounter<37 or (hcounter>=252 and hcounter<252+18)) then                    -- normal sync, short sync
					out_Y := "000000";
				elsif (vcounter=1 or vcounter=2) and (hcounter<18 or (hcounter>=252 and hcounter<252+18)) then      -- short syncs
					out_Y := "000000";
				elsif (vcounter=3 or vcounter=4) and (hcounter<252-18 or (hcounter>=252 and hcounter<504-18)) then  -- vsyncs
					out_Y := "000000";
				elsif (vcounter=5) and (hcounter<252-18 or (hcounter>=252 and hcounter<252+18)) then                -- one vsync, one short sync
					out_Y := "000000";
				elsif (vcounter=6 or vcounter=7) and (hcounter<18 or (hcounter>=252 and hcounter<252+18)) then      -- short syncs
					out_Y := "000000";
				elsif (vcounter>=8) and (hcounter<37) then                                                          -- normal syncs
					out_Y := "000000";
				end if;			
			end if;
			
			-- per-pixel modifications of internal registers and flags
			if (phase mod 2)=0 then
				-- shift pixels along through buffers
				pixelpattern := pixelpattern(25 downto 0) & '0';
				
				-- border flipflops management
				if control2(3)='0' then    -- CSEL bit
					tmp_lefthit := xcoordinate=31;
					tmp_righthit := xcoordinate=335;
				else
					tmp_lefthit := xcoordinate=24;
					tmp_righthit := xcoordinate=344;
				end if;
				if control1(3)='0' then    -- RSEL bit
					tmp_tophit := displayline=55;
					tmp_bottomhit := displayline=247;
				else
					tmp_tophit := displayline=51;
					tmp_bottomhit := displayline=251;
				end if;
				if tmp_righthit then mainborderflipflop:='1'; end if;
				if tmp_bottomhit and cycle=63 then verticalborderflipflop:='1'; end if;
				if tmp_tophit and cycle=63 and control1(4)='1' then verticalborderflipflop:='0'; end if;
				if tmp_lefthit and tmp_bottomhit then verticalborderflipflop:='1'; end if;
				if tmp_lefthit and tmp_tophit and control1(4)='1' then verticalborderflipflop:='0'; end if;
				if tmp_lefthit and verticalborderflipflop='0' then mainborderflipflop:='0'; end if;
			end if;
						
			-- data from memory
			if phase=15 and AEC='0' then   -- received while blocking CPU
				if cycle>=15 and cycle<55 then
					videomatrix(cycle-15) := DB;
				end if;
			end if;
			if phase=7 then                -- received in first half of cycle
				if cycle>=16 and cycle<56 then
					pixelpattern(7 downto 0) := DB(7 downto 0);
				end if;
			end if;
			
			-- CPU writes into registers (very short time slot were address is stable)
			if phase=10 and AEC='1' and RW='0' and CS='0' then  
				case to_integer(unsigned(A)) is 
					when 0  => sprite0x := DB(7 downto 0);
					when 1  => sprite0y := DB(7 downto 0);
					when 2  => sprite1x := DB(7 downto 0);
					when 3  => sprite1y := DB(7 downto 0);
					when 4  => sprite2x := DB(7 downto 0);
					when 5  => sprite2y := DB(7 downto 0);
					when 6  => sprite3x := DB(7 downto 0);
					when 7  => sprite3y := DB(7 downto 0);
					when 8  => sprite4x := DB(7 downto 0);
					when 9  => sprite4y := DB(7 downto 0);
					when 10 => sprite5x := DB(7 downto 0);
					when 11 => sprite5y := DB(7 downto 0);
					when 12 => sprite6x := DB(7 downto 0);
					when 13 => sprite6y := DB(7 downto 0);
					when 14 => sprite7x := DB(7 downto 0);
					when 15 => sprite7y := DB(7 downto 0);
					when 16 => spritexhighbits := DB(7 downto 0);
					when 17 => control1 := DB(7 downto 0);
					when 21 => spriteactive := DB(7 downto 0);
					when 22 => control2 := DB(7 downto 0);
					when 23 => doubleheight := DB(7 downto 0);
					when 27 => spritepriority := DB(7 downto 0);
					when 28 => spritemulticolor := DB(7 downto 0);
					when 29 => doublewidth := DB(7 downto 0);
					when 32 => bordercolor := DB(3 downto 0);
					when 33 => backgroundcolor := DB(3 downto 0);
					when 34 => backgroundcolor1 := DB(3 downto 0);
					when 35 => backgroundcolor2 := DB(3 downto 0);
					when 36 => backgroundcolor3 := DB(3 downto 0);
					when 37 => spritecolor1 := DB(3 downto 0);
					when 38 => spritecolor2 := DB(3 downto 0);
					when 39 => sprite0color := DB(3 downto 0);
					when 40 => sprite1color := DB(3 downto 0);
					when 41 => sprite2color := DB(3 downto 0);
					when 42 => sprite3color := DB(3 downto 0);
					when 43 => sprite4color := DB(3 downto 0);
					when 44 => sprite5color := DB(3 downto 0);
					when 45 => sprite6color := DB(3 downto 0);
					when 46 => sprite7color := DB(3 downto 0);
					when others => null;
				end case;
			end if;

			-- progress counters
			if phase=15 then
				if cycle<63 then
					cycle := cycle+1;
				else
					cycle := 1;
					if displayline < 311 then
						displayline := displayline+1;
					else
						displayline := 0;
					end if;
				end if;
			end if;
			
			-- do the initial sync by checking the AES line after startup
			-- at the first AEC occurence after a specific (big) amount of 
			-- no AEC happening, this means the C64 has started up with default screen
			-- in this situation, we once know the horizontal and vertical beam position
			if phase=14 and not didinitialsync then
				if AEC='0' then
					if noAECrunlength = (312-200+7)*63 + (63-40) then
						displayline := 51;
						cycle := 15;	
						didinitialsync := true;
					end if;
					noAECrunlength := 0;	
				else
					if noAECrunlength<32767 then
						noAECrunlength := noAECrunlength+1;
					end if;
				end if;
			end if;
			
			-- progress the phase
			if phase>12 and PHI0='0' then
				phase:=0;
			elsif phase<15 then
				phase:=phase+1;
			end if;
				
			
		-- end of synchronous logic
		end if;		
		
		-------------------- output signals ---------------------		
		SDTV_Y <= out_y;
		SDTV_Pb <= out_pb;
		SDTV_Pr <= out_pr;				
	end process;
	
end immediate;

