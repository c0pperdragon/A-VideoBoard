-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity C64Mod is	
	port (
		-- reference clock
		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing VIC-II pins comming to the GPIO1
		GPIO1: in std_logic_vector(20 downto 1);	
		
		-- read output mode settings 
		GPIO2_4: in std_logic;
		GPIO2_6: in std_logic
		
--		-- debug output
--		GPIO2_8: out std_logic;
--		GPIO2_10: out std_logic
	);	
end entity;


architecture immediate of C64Mod is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;                     -- 15.763977 MHz
	
	-- high-speed clock to generate synchronous clock from. this is done
	-- with 4 coupled signals that are 0,45,90,135 degree phase shifted to give
	-- 8 usable edges.
	signal CLK252A : std_logic;  -- 504.447288 Mhz
	signal CLK252B : std_logic;
	signal CLK252C : std_logic;
	signal CLK252D : std_logic;
	
	-- SDTV signals
	signal SDTV_Y   : std_logic_vector(5 downto 0);
	signal SDTV_Pb  : std_logic_vector(4 downto 0);
	signal SDTV_Pr  : std_logic_vector(4 downto 0);

	-- video memory control
	signal vramrdaddress0 : std_logic_vector (9 downto 0);
	signal vramrdaddress1 : std_logic_vector (9 downto 0);
	signal vramwraddress : std_logic_vector (9 downto 0);
	signal vramq0        : std_logic_vector (14 downto 0);
	signal vramq1        : std_logic_vector (14 downto 0);
	
   component PLL252 is
	PORT
	(
		inclk0 : IN STD_LOGIC ;
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		c2		: OUT STD_LOGIC ;
		c3		: OUT STD_LOGIC 
	);
	end component;
	
	
   component VIC2YPbPr is
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
	end component;

	component VideoRAM is
	port (
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (14 DOWNTO 0)
	);
	end component;
	
	
begin		
	subdividerpll: PLL252 port map ( CLK25, CLK252A, CLK252B, CLK252C, CLK252D );
	
	vic: VIC2YPbPr port map (
		SDTV_Y,
		SDTV_Pb,
		SDTV_Pr,
		CLK,
		GPIO1(1),                                 -- PHI0
		GPIO1(12 downto 9) & GPIO1(20 downto 13), -- DB
	   GPIO1(12 downto 7),                       -- A
		GPIO1(5),                                 -- RW 
		GPIO1(6),                                 -- CS 
		GPIO1(3),                                 -- AEC
		GPIO1(4)                                  -- BA
	);	

	vram0: VideoRAM port map (
		CLK,
		SDTV_Y(4 downto 0) & SDTV_Pb & SDTV_Pr,
		vramrdaddress0,
		vramwraddress,
		'1',
		vramq0		
	);
	vram1: VideoRAM port map (
		CLK,
		SDTV_Y(4 downto 0) & SDTV_Pb & SDTV_Pr,
		vramrdaddress1,
		vramwraddress,
		'1',
		vramq1
	);
	
	
	------------ create a 16x C64 clock to drive the rest of the circuit	-----------------
	process (GPIO1, CLK252A, CLK252B, CLK252C, CLK252D)
		-- having 8 versions of the circuit running slightly 
		-- time-shifted
		variable counter0 : integer range 0 to 15 := 0;
		variable counter1 : integer range 0 to 15 := 0;
		variable counter2 : integer range 0 to 15 := 0;
		variable counter3 : integer range 0 to 15 := 0;
		variable counter4 : integer range 0 to 15 := 0;
		variable counter5 : integer range 0 to 15 := 0;
		variable counter6 : integer range 0 to 15 := 0;
		variable counter7 : integer range 0 to 15 := 0;
		variable in0_clk : std_logic := '0'; 
		variable in1_clk : std_logic := '0'; 		
		variable in2_clk : std_logic := '0'; 		
		variable in3_clk : std_logic := '0'; 		
		variable in4_clk : std_logic := '0'; 
		variable in5_clk : std_logic := '0'; 		
		variable in6_clk : std_logic := '0'; 		
		variable in7_clk : std_logic := '0'; 		
		variable prev0_clk : std_logic := '0';
		variable prev1_clk : std_logic := '0';		
		variable prev2_clk : std_logic := '0';		
		variable prev3_clk : std_logic := '0';	
		variable prev4_clk : std_logic := '0';
		variable prev5_clk : std_logic := '0';		
		variable prev6_clk : std_logic := '0';		
		variable prev7_clk : std_logic := '0';	
			
		variable bits : std_logic_vector(3 downto 0);
		constant reset: integer := 4;
	begin
	
		if rising_edge(CLK252A) then
			if in0_clk='0' and prev0_clk='1' then 
				counter0 := reset; 
			else
				counter0 := counter0+1;
			end if;
			prev0_clk := in0_clk;
			in0_clk := GPIO1(1);  
		end if;
		if rising_edge(CLK252B) then
			if in1_clk='0' and prev1_clk='1' then 
				counter1 := reset; 
			else
				counter1 := counter1+1;
			end if;
			prev1_clk := in1_clk;
			in1_clk := GPIO1(1);  
		end if;
		if rising_edge(CLK252C) then
			if in2_clk='0' and prev2_clk='1' then 
				counter2 := reset; 
			else
				counter2 := counter2+1;
			end if;
			prev2_clk := in2_clk;
			in2_clk := GPIO1(1);  
		end if;
		if rising_edge(CLK252D) then
			if in3_clk='0' and prev3_clk='1' then 
				counter3 := reset; 
			else
				counter3 := counter3+1;
			end if;
			prev3_clk := in3_clk;
			in3_clk := GPIO1(1);  
		end if;
		if falling_edge(CLK252A) then
			if in4_clk='0' and prev4_clk='1' then 
				counter4 := reset; 
			else
				counter4 := counter4+1;
			end if;
			prev4_clk := in4_clk;
			in4_clk := GPIO1(1);  
		end if;
		if falling_edge(CLK252B) then
			if in5_clk='0' and prev5_clk='1' then 
				counter5 := reset; 
			else
				counter5 := counter5+1;
			end if;
			prev5_clk := in5_clk;
			in5_clk := GPIO1(1);  
		end if;
		if falling_edge(CLK252C) then
			if in6_clk='0' and prev6_clk='1' then 
				counter6 := reset; 
			else
				counter6 := counter6+1;
			end if;
			prev6_clk := in6_clk;
			in6_clk := GPIO1(1);  
		end if;
		if falling_edge(CLK252D) then
			if in7_clk='0' and prev7_clk='1' then 
				counter7 := reset; 
			else
				counter7 := counter7+1;
			end if;
			prev7_clk := in7_clk;
			in7_clk := GPIO1(1);  
		end if;
		
      -- merge clock counters asynchronously
		bits:= std_logic_vector
		(	   to_unsigned(counter0,4) 
			or to_unsigned(counter1,4) 
		   or to_unsigned(counter2,4) 
			or to_unsigned(counter3,4)
			or to_unsigned(counter4,4) 
		   or to_unsigned(counter5,4) 
			or to_unsigned(counter6,4)
			or to_unsigned(counter7,4)
		);
		
		CLK <= bits(3);
--		GPIO2_8 <= bits(3);
--		GPIO2_10 <= GPIO1(1);
	end process;
	
	
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper)
	process (CLK, GPIO2_4, GPIO2_6) 
		variable hcnt : integer range 0 to 1023 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable needvsync : boolean := false;
		
		variable val0 : integer range 0 to 63;
		variable val1 : integer range 0 to 63;
		variable usehighres : boolean; 
		variable usescanlines : boolean;
	begin
		-- handle jumper configuration
		usehighres := GPIO2_4='0' or GPIO2_6='0';
		usescanlines := GPIO2_6='0';
	
		if rising_edge(CLK) then
		
			-- generate EDTV output signal (with syncs and all)
			if vcnt=0 or (vcnt=1 and hcnt<504) then	  -- 3 EDTV lines with sync	
				Y <= "100000";
				Pb <= "10000";
				Pr <= "10000";
				if hcnt<504-37 or (hcnt>=504 and hcnt<2*504-37) then 
					Y(5) <= '0';
				end if;
			else
				 -- construct scanline darkening from both adjacent lines
				if hcnt>=504 and usescanlines then  
					val0 := to_integer(unsigned(vramq0(14 downto 10)));
					val1 := to_integer(unsigned(vramq1(14 downto 10)));					
					Y <= "1" & std_logic_vector(to_unsigned((val0+val1) / 4, 5));
					val0 := to_integer(unsigned(vramq0(9 downto 5)));
					val1 := to_integer(unsigned(vramq1(9 downto 5)));										
					Pb <= std_logic_vector(to_unsigned((val0+val1) / 2, 5));
					val0 := to_integer(unsigned(vramq0(4 downto 0)));
					val1 := to_integer(unsigned(vramq1(4 downto 0)));										
					Pr <= std_logic_vector(to_unsigned((val0+val1) / 2, 5));
				-- normal scanline color
				else
					Y <= "1" & vramq0(14 downto 10);
					Pb <= vramq0(9 downto 5);
					Pr <= vramq0(4 downto 0);
				end if;				
				-- two normal EDTV line syncs
				if hcnt<37 or (hcnt>=504 and hcnt<504+37) then  
					Y(5) <= '0';
				end if;
				
				-- Y <= "100000";
			end if;
			
			-- progress counters and detect sync
			if SDTV_Y(5)='0' and hcnt>1000 then
				hcnt := 0;
				if needvsync then 
					vcnt := 0;
					needvsync := false;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<1023 then
				-- a sync in the middle of a scanline: starts the vsync sequence
				if hcnt=200 and SDTV_Y(5)='0' and vcnt>50 then
					needvsync := true;
				end if;
				hcnt := hcnt+1;
			end if;

			-- if highres is not selected, fall back to plain SDTV
			if not usehighres then
				Y  <= SDTV_Y;
				Pb <= SDTV_Pb;
				Pr <= SDTV_Pr;
			end if;
			
		end if;
		
		-- compute VideoRAM write position (write in buffer one line ahead)
		vramwraddress <= std_logic_vector(to_unsigned(hcnt/2 + ((vcnt+1) mod 2)*512, 10));
		-- compute VideoRAM read positions to fetch two adjacent lines
		if hcnt<504 then
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt + ((vcnt+1) mod 2)*512, 10));
		else
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt-504 + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt-504 + ((vcnt+1) mod 2)*512, 10));
		end if;
		
	end process;
	

end immediate;

