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

	-- using the palette "Colodore", converted to YPbPr   
  	type T_c64palette is array (0 to 15) of integer range 0 to 32767;
   constant c64palette : T_c64palette := 
	(	 0*1024 + 16*32 + 16,  -- black
		31*1024 + 16*32 + 16,  -- white
		 9*1024 + 14*32 + 20,  -- red
		22*1024 + 17*32 + 10,  -- cyan		
		12*1024 + 19*32 + 20,  -- purple
		16*1024 + 11*32 + 11,  -- green
		 7*1024 + 22*32 + 16,  -- blue
		27*1024 +  8*32 + 17,  -- yellow
		11*1024 + 12*32 + 20,  -- orange
		 7*1024 + 12*32 + 18,  -- brown		 
		16*1024 + 14*32 + 21,  -- light red
		 9*1024 + 16*32 + 16,  -- dark gray
		15*1024 + 16*32 + 16,  -- medium gray
		27*1024 + 11*32 + 11,  -- light green
		15*1024 + 23*32 + 14,  -- light blue
		22*1024 + 16*32 + 16   -- light gray		
	); 
	-- visible screen area
	constant totalvisiblewidth : integer := 390;
	constant totalvisibleheight : integer := 270;
	
	-- registers of the VIC and their default values
  	type T_spritex is array (0 to 7) of std_logic_vector(8 downto 0);
	variable spritex : T_spritex := 
	( "000000000","000000000","000000000","000000000","000000000","000000000","000000000","000000000");	
  	type T_spritey is array (0 to 7) of std_logic_vector(7 downto 0);
	variable spritey : T_spritey := 
	( "00000000","00000000","00000000","00000000","00000000","00000000","00000000","00000000");	
	variable ECM:              std_logic := '0';
	variable BMM:              std_logic := '0';
	variable DEN:              std_logic := '1';
	variable RSEL:             std_logic := '1';
--	variable YSCROLL:          std_logic_vector(2 downto 0) := "011";
	variable spriteenable:     std_logic_vector(7 downto 0) := "00000000";
	variable MCM:              std_logic := '0';
	variable CSEL:             std_logic := '1';
	variable XSCROLL:          std_logic_vector(2 downto 0) := "000";
--	variable doubleheight:     std_logic_vector(7 downto 0) := "00000000";
	variable spritepriority:   std_logic_vector(7 downto 0) := "00000000";
	variable spritemulticolor: std_logic_vector(7 downto 0) := "00000000";
	variable doublewidth:      std_logic_vector(7 downto 0) := "00000000";
	variable bordercolor:      std_logic_vector(3 downto 0) := "1110";
	variable backgroundcolor0: std_logic_vector(3 downto 0) := "0110";
	variable backgroundcolor1: std_logic_vector(3 downto 0) := "0001";
	variable backgroundcolor2: std_logic_vector(3 downto 0) := "0010";
	variable backgroundcolor3: std_logic_vector(3 downto 0) := "0011";
	variable spritemulticolor0:std_logic_vector(3 downto 0) := "0100";
	variable spritemulticolor1:std_logic_vector(3 downto 0) := "0000";
	type T_spritecolor is array (0 to 7) of std_logic_vector(3 downto 0);
	variable spritecolor: T_spritecolor := ( "0001", "0010", "0011", "0100", "0101", "0110", "0111", "1100" );
	
	-- variables for synchronious operation
	variable phase: integer range 0 to 15 := 0;         -- phase inside of the cycle
	variable cycle : integer range 0 to 63 := 0;        -- cpu cycle
	variable displayline: integer range 0 to 511 := 0;  -- VIC-II line numbering

	type T_videomatrix is array (0 to 39) of std_logic_vector(11 downto 0);
	variable videomatrix : T_videomatrix;
	variable pixelpattern : std_logic_vector(27 downto 0);
	variable mainborderflipflop : std_logic := '0';
	variable verticalborderflipflop : std_logic := '0';
	
	variable expansionflipflop : std_logic_vector(7 downto 0) := "00000000";
	variable delayedspriteenable: std_logic_vector(7 downto 0) := "00000000";
	variable spriteactive: std_logic_vector(7 downto 0) := "00000000";
--	type T_mcbase is array(0 to 7) of integer range 0 to 63;
--	variable mcbase : T_mcbase := (0,0,0,0,0,0,0,0);
	type T_spritedata is array (0 to 7) of std_logic_vector(24 downto 0);
	variable spritedata : T_spritedata;
	type T_spriterendering is array (0 to 7) of integer range 0 to 5; 
	variable spriterendering : T_spriterendering := (0,0,0,0,0,0,0,0);
		
	variable noAECrunlength : integer range 0 to 32767 := 0;
	variable didinitialsync : boolean := false;
		
	-- registered output 
	variable out_Y  : std_logic_vector(5 downto 0) := "000000";
	variable out_Pb : std_logic_vector(4 downto 0) := "10000";
	variable out_Pr : std_logic_vector(4 downto 0) := "10000";

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
			if (phase mod 2) = 0 and didinitialsync then   
			
				-- output defaults to black (no csync active)
				out_Y  := "100000";
				out_Pb := "10000";
				out_Pr := "10000";
	
				-- area where any color is shown (including border)
				if hcounter>=92 and hcounter<92+totalvisiblewidth 
				and vcounter>=34 and vcounter<34+totalvisibleheight then
				
					-- main screen area color processing
					tmp_c := backgroundcolor0;		
					tmp_isforeground := false;
					
					if cycle>=18 and cycle<58 then
						tmp_hscroll := to_integer(unsigned(XSCROLL));
						tmp_pixelindex := (cycle-17) * 8 + phase/2 - tmp_hscroll;

						-- access the correct video matrix cell
						if tmp_pixelindex>=8 then
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
					tmp_ypbpr := std_logic_vector(to_unsigned
					( c64palette(to_integer(unsigned(tmp_c))),15 ));
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
				if tmp_bottomhit and cycle=63 then verticalborderflipflop:='1'; end if;
				if tmp_tophit and cycle=63 and DEN='1' then verticalborderflipflop:='0'; end if;
				if tmp_lefthit and tmp_bottomhit then verticalborderflipflop:='1'; end if;
				if tmp_lefthit and tmp_tophit and DEN='1' then verticalborderflipflop:='0'; end if;
				if tmp_lefthit and verticalborderflipflop='0' then mainborderflipflop:='0'; end if;
				
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
				end loop;
			end if;
			
			-- handle cycle-depending sprite trigger
			if phase=7 then
				for SP in 0 to 7 loop
					if cycle=55 then
						delayedspriteenable(SP) := spriteenable(SP);
					elsif cycle=56 then
						delayedspriteenable(SP) := delayedspriteenable(SP) or spriteenable(SP);
					elsif cycle=58 then
						if delayedspriteenable(SP)='1' 
						and std_logic_vector(to_unsigned(displayline mod 256,8))=spritey(SP) then
							spriteactive(SP) := '1';
						end if;
						if spriteenable(SP)='0' then
							spriteactive(SP) := '0';
						end if;
					end if;
				end loop;
			end if;
						
			-- data from memory
			if phase=14 then   -- receive during a CPU-blocking cycle
				-- video matrix read
				if cycle>=15 and cycle<55 then
					if AEC='0' then 
						videomatrix(cycle-15) := DB;
					elsif displayline=248 then
						videomatrix(cycle-15) := "000000000000";
					end if;
				end if;
				-- sprite DMA read
				for SP in 0 to 7 loop
					if (SP<3 and cycle=SP*2+58) or (SP>=3 and cycle=SP*2-5) then
						spritedata(SP)(23 downto 16) := DB(7 downto 0);
						spriterendering(SP) := 5;
					elsif (SP<3 and cycle=SP*2+59) or (SP>=3 and cycle=SP*2-4) then
						spritedata(SP)(7 downto 0) := DB(7 downto 0);
						if AEC='0' and spriteactive(SP)='1' then
							spriterendering(SP) := 4;
						else
							spriterendering(SP) := 5;
							spriteactive(SP) := '0';
						end if;
					end if;
				end loop;
			end if;
			
			if phase=7 then                -- received in first half of cycle
				-- pixel pattern read
				if cycle>=16 and cycle<56 then
					pixelpattern(7 downto 0) := DB(7 downto 0);
				end if;
				-- sprite DMA read
				for SP in 0 to 7 loop
					if (SP<3 and cycle=SP*2+59) or (SP>=3 and cycle=SP*2-4) then
						spritedata(SP)(15 downto 8) := DB(7 downto 0);
					end if;
				end loop;
			end if;
			
			-- CPU writes into registers (very short time slot were address is stable)
			if phase=10 and AEC='1' and RW='0' and CS='0' then  
				case to_integer(unsigned(A)) is 
					when 0  => spritex(0)(7 downto 0) := DB(7 downto 0);
					when 1  => spritey(0)(7 downto 0) := DB(7 downto 0);
					when 2  => spritex(1)(7 downto 0) := DB(7 downto 0);
					when 3  => spritey(1)(7 downto 0) := DB(7 downto 0);
					when 4  => spritex(2)(7 downto 0) := DB(7 downto 0);
					when 5  => spritey(2)(7 downto 0) := DB(7 downto 0);
					when 6  => spritex(3)(7 downto 0) := DB(7 downto 0);
					when 7  => spritey(3)(7 downto 0) := DB(7 downto 0);
					when 8  => spritex(4)(7 downto 0) := DB(7 downto 0);
					when 9  => spritey(4)(7 downto 0) := DB(7 downto 0);
					when 10 => spritex(5)(7 downto 0) := DB(7 downto 0);
					when 11 => spritey(5)(7 downto 0) := DB(7 downto 0);
					when 12 => spritex(6)(7 downto 0) := DB(7 downto 0);
					when 13 => spritey(6)(7 downto 0) := DB(7 downto 0);
					when 14 => spritex(7)(7 downto 0) := DB(7 downto 0);
					when 15 => spritey(7)(7 downto 0) := DB(7 downto 0);
					when 16 => spritex(0)(8) := DB(0);
					           spritex(1)(8) := DB(1);
								  spritex(2)(8) := DB(2);
								  spritex(3)(8) := DB(3);
								  spritex(4)(8) := DB(4);
								  spritex(5)(8) := DB(5);
								  spritex(6)(8) := DB(6);
								  spritex(7)(8) := DB(7);
					when 17 => ECM := DB(6);
	                       BMM := DB(5);
								  DEN := DB(4);
								  RSEL:= DB(3);
--								  YSCROLL := DB(2 downto 0);
					when 21 => spriteenable := DB(7 downto 0);
					when 22 => MCM := DB(4);
					           CSEL := DB(3);
								  XSCROLL := DB(2 downto 0);
--					when 23 => doubleheight := DB(7 downto 0);
					when 27 => spritepriority := DB(7 downto 0);
					when 28 => spritemulticolor := DB(7 downto 0);
					when 29 => doublewidth := DB(7 downto 0);
					when 32 => bordercolor := DB(3 downto 0);
					when 33 => backgroundcolor0 := DB(3 downto 0);
					when 34 => backgroundcolor1 := DB(3 downto 0);
					when 35 => backgroundcolor2 := DB(3 downto 0);
					when 36 => backgroundcolor3 := DB(3 downto 0);
					when 37 => spritemulticolor0 := DB(3 downto 0);
					when 38 => spritemulticolor1 := DB(3 downto 0);
					when 39 => spritecolor(0) := DB(3 downto 0);
					when 40 => spritecolor(1) := DB(3 downto 0);
					when 41 => spritecolor(2) := DB(3 downto 0);
					when 42 => spritecolor(3) := DB(3 downto 0);
					when 43 => spritecolor(4) := DB(3 downto 0);
					when 44 => spritecolor(5) := DB(3 downto 0);
					when 45 => spritecolor(6) := DB(3 downto 0);
					when 46 => spritecolor(7) := DB(3 downto 0);
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

