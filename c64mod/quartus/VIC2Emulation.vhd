library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a VIC emulation that sniffs all relevant
-- input/output pins of the VIC and emulates the internal 
-- behaviour of the VIC to finally create a YPbPr signal.
-- Output is generated at every falling edge of the CLK

entity VIC2Emulation is	
	port (
		-- standard definition color output
		COLOR: out std_logic_vector(3 downto 0);
		CSYNC: out std_logic;
		
		-- synchronous clock of 16 times the c64 clock cycle
		CLK         : in std_logic;
		
		-- Connections to the real GTIAs pins 
		PHI0        : in std_logic;
		DB          : in std_logic_vector(11 downto 0);
		A           : in std_logic_vector(5 downto 0);
		RW          : in std_logic; 
		CS          : in std_logic; 
		AEC         : in std_logic
	);	
end entity;


architecture immediate of VIC2Emulation is
begin
	process (CLK) 

	-- visible screen area
	constant totalvisiblewidth : integer := 390;
	constant totalvisibleheight : integer := 270;
	
	-- registers of the VIC and their default values
  	type T_spritex is array (0 to 7) of std_logic_vector(8 downto 0);
	variable spritex : T_spritex := 
	( "000000000","000000000","000000000","000000000","000000000","000000000","000000000","000000000");	
	variable ECM:              std_logic := '0';
	variable BMM:              std_logic := '0';
	variable DEN:              std_logic := '1';
	variable RSEL:             std_logic := '0'; -- '1';
	variable MCM:              std_logic := '0';
	variable CSEL:             std_logic := '0'; -- '1';
	variable XSCROLL:          std_logic_vector(2 downto 0) := "000";
	variable spritepriority:   std_logic_vector(7 downto 0) := "00000000";
	variable spritemulticolor: std_logic_vector(7 downto 0) := "00000000";
	variable doublewidth:      std_logic_vector(7 downto 0) := "00000000";
	variable bordercolor:      std_logic_vector(3 downto 0) := "0000"; -- "1110";
	variable backgroundcolor0: std_logic_vector(3 downto 0) := "0000"; -- "0110";
	variable backgroundcolor1: std_logic_vector(3 downto 0) := "0000"; -- "0001";
	variable backgroundcolor2: std_logic_vector(3 downto 0) := "0000"; -- "0010";
	variable backgroundcolor3: std_logic_vector(3 downto 0) := "0000"; -- "0011";
	variable spritemulticolor0:std_logic_vector(3 downto 0) := "0000"; -- "0100";
	variable spritemulticolor1:std_logic_vector(3 downto 0) := "0000";
	type T_spritecolor is array (0 to 7) of std_logic_vector(3 downto 0);
--	variable spritecolor: T_spritecolor := ( "0001", "0010", "0011", "0100", "0101", "0110", "0111", "1100" );
	variable spritecolor: T_spritecolor := ( "0000", "0000", "0000", "0000", "0000", "0000", "0000", "0000" );
	
	-- registering the inputs
	variable in_phi0: std_logic; 
	variable in_db: std_logic_vector(11 downto 0);
	variable in_a:  std_logic_vector(5 downto 0);
	variable in_rw: std_logic; 
	variable in_cs: std_logic; 
	variable in_aec: std_logic; 
	
	-- variables for synchronious operation
	variable phase: integer range 0 to 15 := 0;         -- phase inside of the cycle
	variable cycle : integer range 0 to 63 := 0;        -- cpu cycle
	variable displayline: integer range 0 to 511 := 0;  -- VIC-II line numbering

	type T_videomatrix is array (0 to 39) of std_logic_vector(11 downto 0);
	variable videomatrix : T_videomatrix;
	variable pixelpattern : std_logic_vector(27 downto 0);
	variable mainborderflipflop : std_logic := '0';
	variable verticalborderflipflop : std_logic := '0';
	variable videomatrixage : integer range 0 to 8 := 8;
	
	type T_spritedata is array (0 to 7) of std_logic_vector(24 downto 0);
	variable spritedata : T_spritedata;
	type T_spriterendering is array (0 to 7) of integer range 0 to 5; 
	variable spriterendering : T_spriterendering := (0,0,0,0,0,0,0,0);
	variable firstspritereadaddress : std_logic_vector(1 downto 0);	
		
	variable syncdetect_ok : boolean := false;
	variable syncdetect_cycle : integer range 0 to 63 := 0;
	variable ramrefreshpattern : std_logic_vector(9 downto 0) := "0000000000";
		
	-- registered output 
	variable out_color  : std_logic_vector(3 downto 0) := "0000";
	variable out_csync : std_logic := '0';

	-- temporary stuff
	variable hcounter : integer range 0 to 511;      -- pixel in current scan line
	variable vcounter : integer range 0 to 511 := 0; -- current scan line 
	variable xcoordinate : integer range 0 to 1023;   -- x-position in sprite coordinates
	variable tmp_c : std_logic_vector(3 downto 0);
	variable tmp_isforeground : boolean;
	variable tmp_ypbpr : std_logic_vector(14 downto 0);
	variable tmp_vm : std_logic_vector(11 downto 0);
	variable tmp_pixelindex : integer range 0 to 511;
	variable tmp_hscroll : integer range 0 to 7;
	variable tmp_lefthit : boolean;
	variable tmp_tophit : boolean;
	variable tmp_righthit: boolean;
	variable tmp_bottomhit: boolean;
	variable tmp_bit : std_logic;
	variable tmp_2bit : std_logic_vector(1 downto 0);
	variable tmp_3bit : std_logic_vector(2 downto 0);
	
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
			if xcoordinate>=112 then
				xcoordinate := xcoordinate-112;
			else
				xcoordinate := xcoordinate+(504-112);
			end if;
			
			-- generate pixel output (as soon as sync was found)	
			if (phase mod 2) = 0 then   
			
				-- output defaults to black (no csync active)
				out_color  := "0000";
				out_csync := '1';
	
				-- area where any color is shown (including border)
				if hcounter>=92 and hcounter<92+totalvisiblewidth 
				and vcounter>=34 and vcounter<34+totalvisibleheight then
				
					-- main screen area color processing
					tmp_c := backgroundcolor0;		
					tmp_isforeground := false;
					
					if cycle>=18 and cycle<58 and DEN='1' then
						tmp_hscroll := to_integer(unsigned(XSCROLL));
						tmp_pixelindex := (cycle-17) * 8 + phase/2 - tmp_hscroll;

						-- access the correct video matrix cell
						if tmp_pixelindex>=8 and videomatrixage<8 then
							tmp_vm := videomatrix((tmp_pixelindex-8)/8);
						else
							tmp_vm := "000000000000";
						end if;
						
						-- extract relevant bit or 2 bits from bitmap data
						tmp_bit := pixelpattern(19 + tmp_hscroll);
						tmp_2bit(1) := pixelpattern(19 + tmp_hscroll + tmp_pixelindex mod 2);
						tmp_2bit(0) := pixelpattern(18 + tmp_hscroll + tmp_pixelindex mod 2);
						
						-- set color depending on graphics/text mode
						tmp_3bit(2) := ECM;
						tmp_3bit(1) := BMM;
						tmp_3bit(0) := MCM;
						case tmp_3bit is  
						when "000" =>   -- standard text mode
							if tmp_bit='1' then
								tmp_c := tmp_vm(11 downto 8);
								tmp_isforeground := true;
							end if;
						when "001" =>   -- multicolor text mode
							if tmp_vm(11)='0' then
								if tmp_bit='1' then
									tmp_c := "0" & tmp_vm(10 downto 8);
									tmp_isforeground := true;
								end if;
							else
								case tmp_2bit is
								when "00" => tmp_c := backgroundcolor0;
								when "01" => tmp_c := backgroundcolor1;
								when "10" => tmp_c := backgroundcolor2;
								             tmp_isforeground := true;
								when "11" => tmp_c := "0" & tmp_vm(10 downto 8);
								             tmp_isforeground := true;
								end case;
							end if;
						when "010" =>  -- standard bitmap mode
							if tmp_bit='0' then
								tmp_c := tmp_vm(3 downto 0);
							else
								tmp_c := tmp_vm(7 downto 4);
								tmp_isforeground := true;
							end if;
						when "011" =>  -- multicolor bitmap mode
							case tmp_2bit is
							when "00" => tmp_c := backgroundcolor0;
							when "01" => tmp_c := tmp_vm(7 downto 4);
							when "10" => tmp_c := tmp_vm(3 downto 0);
											 tmp_isforeground := true;
							when "11" => tmp_c := tmp_vm(11 downto 8);
							             tmp_isforeground := true;
							end case;
						when "100" =>  -- ECM text mode
							if tmp_bit='1' then
								tmp_c := tmp_vm(11 downto 8);
								tmp_isforeground := true;
							else
								case tmp_vm(7 downto 6) is
								when "00" => tmp_c := backgroundcolor0;
								when "01" => tmp_c := backgroundcolor1;
								when "10" => tmp_c := backgroundcolor2;
								when "11" => tmp_c := backgroundcolor3;
								end case;								
							end if;
						when "101" =>  -- Invalid text mode
							tmp_c := "0000";
							if tmp_vm(11)='0' then
								if tmp_bit='1' then
									tmp_isforeground := true;
								end if;
							else
								if tmp_2bit="10" or tmp_2bit="11" then	
									tmp_isforeground := true;
								end if;
							end if;							
						when "110" =>  -- Invalid bitmap mode 1
							tmp_c := "0000";
							if tmp_bit='1' then
								tmp_isforeground := true;
							end if;
						when "111" =>  -- Invalid bitmap mode 2
							tmp_c := "0000";
							if tmp_2bit="10" or tmp_2bit="11" then
								tmp_isforeground := true;
							end if;
						end case;						
					end if;
					
					-- overlay with sprite graphics
					for SP in 7 downto 0 loop
						if ((not tmp_isforeground) or spritepriority(SP)='0') 
						and (spriterendering(SP)<4) 
						then
							if spritemulticolor(SP)='1' then								
								tmp_2bit := spritedata(SP)(23 downto 22);
								if (doublewidth(SP)='0' and spriterendering(SP) mod 2 = 1) 
								or (doublewidth(SP)='1' and spriterendering(SP) / 2 = 1)
								then
									tmp_2bit := spritedata(SP)(24 downto 23);
								end if;
								case tmp_2bit is
								when "00" => 
								when "01" => tmp_c := spritemulticolor0;
								when "10" => tmp_c := spritecolor(SP);
								when "11" => tmp_c := spritemulticolor1;
								end case;
							else
								if spritedata(SP)(23)='1' then
									tmp_c := spritecolor(SP);						
								end if;
							end if;
						end if;
					end loop;
					
					-- overlay with border 
					if mainborderflipflop='1' then
						tmp_c := bordercolor;
					end if;
					
					-- generate the YPbPr signal using a fixed palette
					out_color := tmp_c;
	
				-- generate csync for PAL 288p signal
				elsif (vcounter=0) and (hcounter<37 or (hcounter>=252 and hcounter<252+18)) then                    -- normal sync, short sync
					out_csync := '0';
				elsif (vcounter=1 or vcounter=2) and (hcounter<18 or (hcounter>=252 and hcounter<252+18)) then      -- short syncs
					out_csync := '0';
				elsif (vcounter=3 or vcounter=4) and (hcounter<252-18 or (hcounter>=252 and hcounter<504-18)) then  -- vsyncs
					out_csync := '0';
				elsif (vcounter=5) and (hcounter<252-18 or (hcounter>=252 and hcounter<252+18)) then                -- one vsync, one short sync
					out_csync := '0';
				elsif (vcounter=6 or vcounter=7) and (hcounter<18 or (hcounter>=252 and hcounter<252+18)) then      -- short syncs
					out_csync := '0';
				elsif (vcounter>=8) and (hcounter<37) then                                                          -- normal syncs
					out_csync := '0';
				end if;			
			end if;
			
			-- per-pixel modifications of internal registers and flags
			if (phase mod 2)=0 then
				-- shift pixels along through buffers
				pixelpattern := pixelpattern(26 downto 0) & '0';
				
				-- border flipflops management
				if CSEL='0' then    
					tmp_lefthit := xcoordinate=31;
					tmp_righthit := xcoordinate=335;
				else
					tmp_lefthit := xcoordinate=24;
					tmp_righthit := xcoordinate=344;
				end if;
				if RSEL='0' then
					tmp_tophit := displayline=55;
					tmp_bottomhit := displayline=247;
				else
					tmp_tophit := displayline=51;
					tmp_bottomhit := displayline=251;
				end if;
				if tmp_righthit then mainborderflipflop:='1'; end if;
				if tmp_lefthit and verticalborderflipflop='0' then mainborderflipflop:='0'; end if;
--				if tmp_bottomhit and cycle=63 then verticalborderflipflop:='1'; end if;
--				if tmp_tophit and cycle=63 and DEN='1' then verticalborderflipflop:='0'; end if;
--				if tmp_lefthit and tmp_bottomhit then verticalborderflipflop:='1'; end if;
--				if tmp_lefthit and tmp_tophit and DEN='1' then verticalborderflipflop:='0'; end if;
				if tmp_bottomhit then verticalborderflipflop:='1'; end if;
				if tmp_tophit and DEN='1' then verticalborderflipflop:='0'; end if;
				
				-- progress sprite rendering on every pixel 
				for SP in 0 to 7 loop
					if spriterendering(SP)<4 then
						if spriterendering(SP) mod 2 = 1 or doublewidth(SP)='0' then
							spritedata(SP) := spritedata(SP)(23 downto 0) & '0';
						end if;
					end if;
					case spriterendering(SP) is
					when 0 => spriterendering(SP) := 1;
					when 1 => spriterendering(SP) := 2;
					when 2 => spriterendering(SP) := 3;
					when 3 => spriterendering(SP) := 0;
					when 4 => 
						if xcoordinate=to_integer(unsigned(spritex(SP))) then
							spriterendering(SP):=0;
						end if;
					when others =>
					end case;
					
					if cycle=58 then
						spriterendering(SP) := 5;
					end if;
				end loop;
			end if;
			
						
			-- data from memory
			if phase=14 then   -- receive during a CPU-blocking cycle
				-- video matrix read
				if cycle>=15 and cycle<55 then
					if in_aec='0' then 
						videomatrix(cycle-15) := in_db;
						videomatrixage := 0;
					end if;
				end if;
				-- sprite DMA read
				for SP in 0 to 7 loop
					if (SP<3 and cycle=SP*2+58) or (SP>=3 and cycle=SP*2-5) then
						spritedata(SP)(23 downto 16) := in_db(7 downto 0);
					elsif (SP<3 and cycle=SP*2+59) or (SP>=3 and cycle=SP*2-4) then
						spritedata(SP)(7 downto 0) := in_db(7 downto 0);
					end if;
				end loop;
			end if;
			if phase=7 then                -- received in first half of cycle
				-- pixel pattern read
				if cycle>=16 and cycle<56 then
					pixelpattern(7 downto 0) := in_db(7 downto 0);
				end if;
				-- sprite DMA read
				for SP in 0 to 7 loop
					if (SP<3 and cycle=SP*2+59) or (SP>=3 and cycle=SP*2-4) then
						spritedata(SP)(15 downto 8) := in_db(7 downto 0);
					end if;
				end loop;
			end if;
			
			-- detect if there was a real sprite read (when the
			-- read address did change between individual bytes)
			-- set rendering to ready
			-- (very short time slot were address is stable)
			if phase=9 then
				if in_aec='0' then -- only when having done DMA
					if cycle=58 or cycle=60 or cycle=62 or cycle=1 
					or cycle=3 or cycle=5 or cycle=7 or cycle=9 then
						firstspritereadaddress := in_a(1 downto 0);
					end if;
					for SP in 0 to 7 loop
						if (SP<3 and cycle=SP*2+59) or (SP>=3 and cycle=SP*2-4) then
							if firstspritereadaddress /= in_a(1 downto 0) then
								spriterendering(SP) := 4;
							end if;
						end if;
					end loop;
				end if;
			end if;
			
			-- CPU writes into registers 
			-- (very short time slot were address is stable)
			if phase=9 and in_aec='1' and in_rw='0' and in_cs='0' then  
				case to_integer(unsigned(in_a)) is 
					when 0  => spritex(0)(7 downto 0) := in_db(7 downto 0);
					when 2  => spritex(1)(7 downto 0) := in_db(7 downto 0);
					when 4  => spritex(2)(7 downto 0) := in_db(7 downto 0);
					when 6  => spritex(3)(7 downto 0) := in_db(7 downto 0);
					when 8  => spritex(4)(7 downto 0) := in_db(7 downto 0);
					when 10 => spritex(5)(7 downto 0) := in_db(7 downto 0);
					when 12 => spritex(6)(7 downto 0) := in_db(7 downto 0);
					when 14 => spritex(7)(7 downto 0) := in_db(7 downto 0);
					when 16 => spritex(0)(8) := in_db(0);
					           spritex(1)(8) := in_db(1);
								  spritex(2)(8) := in_db(2);
								  spritex(3)(8) := in_db(3);
								  spritex(4)(8) := in_db(4);
								  spritex(5)(8) := in_db(5);
								  spritex(6)(8) := in_db(6);
								  spritex(7)(8) := in_db(7);
					when 17 => ECM := in_db(6);
	                       BMM := in_db(5);
								  DEN := in_db(4);
								  RSEL:= in_db(3);
					when 22 => MCM := in_db(4);
					           CSEL := in_db(3);
								  XSCROLL := in_db(2 downto 0);
					when 27 => spritepriority := in_db(7 downto 0);
					when 28 => spritemulticolor := in_db(7 downto 0);
					when 29 => doublewidth := in_db(7 downto 0);
					when 32 => bordercolor := in_db(3 downto 0);
					when 33 => backgroundcolor0 := in_db(3 downto 0);
					when 34 => backgroundcolor1 := in_db(3 downto 0);
					when 35 => backgroundcolor2 := in_db(3 downto 0);
					when 36 => backgroundcolor3 := in_db(3 downto 0);
					when 37 => spritemulticolor0 := in_db(3 downto 0);
					when 38 => spritemulticolor1 := in_db(3 downto 0);
					when 39 => spritecolor(0) := in_db(3 downto 0);
					when 40 => spritecolor(1) := in_db(3 downto 0);
					when 41 => spritecolor(2) := in_db(3 downto 0);
					when 42 => spritecolor(3) := in_db(3 downto 0);
					when 43 => spritecolor(4) := in_db(3 downto 0);
					when 44 => spritecolor(5) := in_db(3 downto 0);
					when 45 => spritecolor(6) := in_db(3 downto 0);
					when 46 => spritecolor(7) := in_db(3 downto 0);
					when others => null;
				end case;
			end if;

			-- progress horizontal and vertical counters
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
					if videomatrixage<8 then 
						videomatrixage := videomatrixage+1;
					end if;
				end if;
			end if;

			-- try to find the dram refresh pattern to sync the output 
			if phase=1 then
				case syncdetect_cycle is
				when 11 => ramrefreshpattern(9 downto 8) := in_a(1 downto 0);
				when 12 => ramrefreshpattern(7 downto 6) := in_a(1 downto 0);
				when 13 => ramrefreshpattern(5 downto 4) := in_a(1 downto 0);
				when 14 => ramrefreshpattern(3 downto 2) := in_a(1 downto 0);
				when 15 => ramrefreshpattern(1 downto 0) := in_a(1 downto 0);
				when 16 => 
					if ramrefreshpattern = "1110010011" 
					or ramrefreshpattern = "1001001110"
					or ramrefreshpattern = "0100111001"
					or ramrefreshpattern = "0011100100"
					then
						syncdetect_ok := true;  -- have detected the refresh pattern
					elsif syncdetect_ok then
						syncdetect_ok := false; -- not detected for 1. time 
						-- detect the top of the frame anomaly (when in sync)
						if ramrefreshpattern = "1111111111" then
							displayline := 311;
							cycle := 16;								
						end if;
					else 
						syncdetect_cycle := 17;  -- two missdetecions: search for sync
					end if;
				when others =>
				end case;
				if syncdetect_cycle<63 then 
					syncdetect_cycle := syncdetect_cycle+1;
				else
					syncdetect_cycle := 1;
				end if;
			end if;
			
			-- progress the phase
			if phase>12 and in_phi0='0' then
				phase:=0;
			elsif phase<15 then
				phase:=phase+1;
			end if;

			-- take input into registers
			in_phi0 := PHI0;
			in_db := DB;
			in_a := A;
			in_rw := RW; 
			in_cs := CS; 
			in_aec := AEC;			
		-- end of synchronous logic
		end if;		
		
		-------------------- output signals ---------------------		
		COLOR <= out_color;
		CSYNC <= out_csync;
	end process;
	
end immediate;

