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
		PHASE       : in std_logic_vector(3 downto 0); 
		
		-- Connections to the real GTIAs pins 
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
	process (CLK,PHASE) 

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
		
	-- registers of the VIC

	-- variables for synchronious operation
	variable hcounter : integer range 0 to 511 := 0;
	variable vcounter : integer range 0 to 511 := 0;
		
	-- registered output 
	variable out_Y  : std_logic_vector(5 downto 0) := "000000";
	variable out_Pb : std_logic_vector(4 downto 0) := "10000";
	variable out_Pr : std_logic_vector(4 downto 0) := "10000";
	
	variable tmp_ypbpr : std_logic_vector(14 downto 0);

	begin
		--------------------- logic -------------------
		if rising_edge(CLK) and PHASE(0)='0' then
			-- output defaults to black (no csync active)
			out_Y  := "100000";
			out_Pb := "10000";
			out_Pr := "10000";

			-- show test pattern
			if vcounter>=100 and vcounter<116 and hcounter>=100 and hcounter<100+16*16 then
				tmp_ypbpr := std_logic_vector(to_unsigned(c64palette((hcounter-100)/16),15));
				out_Y := '1' & tmp_ypbpr(14 downto 10);
				out_Pb := tmp_ypbpr(9 downto 5);
				out_Pr := tmp_ypbpr(4 downto 0);

			-- generate csync for PAL 288p signal (adjusting timing a bit to get screen correctly alligned)
			elsif (vcounter=0 or vcounter=1 or vcounter=2) and (hcounter<16 or (hcounter>=252 and hcounter<252+16)) then  -- short syncs
				out_Y := "000000";
			elsif (vcounter=3 or vcounter=4) and (hcounter<252-16 or (hcounter>=252 and hcounter<504-16)) then       -- vsyncs
				out_Y := "000000";
			elsif (vcounter=5) and (hcounter<252-16 or (hcounter>=252 and hcounter<252+16)) then                     -- one vsync, one short sync
				out_Y := "000000";
			elsif (vcounter=6 or vcounter=7) and (hcounter<16 or (hcounter>=252 and hcounter<252+16)) then           -- short syncs
				out_Y := "000000";
			elsif (vcounter>=8) and (hcounter<32) then                                                               -- normal line syncs
				out_Y := "000000";
			end if;			
			
			-- progress counters
			if hcounter<503 then
				hcounter := hcounter+1;
			else
				hcounter := 0;
				if vcounter < 311 then
					vcounter := vcounter+1;
				else
					vcounter := 0;
				end if;
			end if;
		end if;
		
		-------------------- output signals ---------------------		
		SDTV_Y <= out_y;
		SDTV_Pb <= out_pb;
		SDTV_Pr <= out_pr;				
	end process;
	
end immediate;

