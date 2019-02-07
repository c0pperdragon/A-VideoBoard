

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity ClockMultiplier is	
	port (
		-- reference clock
		CLK25: in std_logic;		
		-- C64 cpu clock
		PHI0: in std_logic;
		-- 0: use input frequency for NTSC
		-- 1: use input frequency for PAL
		PAL: in std_logic;
		
		-- x16 times output clock
		CLK: out std_logic
	);	
end entity;


architecture immediate of ClockMultiplier is
	-- high-speed clock to generate synchronous clock from. this is done
	-- with 4 coupled signals that are 0,45,90,135 degree phase shifted to give
	-- 8 usable edges.
	signal CLKA : std_logic;  
	signal CLKB : std_logic;
	signal CLKC : std_logic;
	signal CLKD : std_logic;

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
   component PLL262 is
	PORT
	(
		inclk0 : IN STD_LOGIC ;
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		c2		: OUT STD_LOGIC ;
		c3		: OUT STD_LOGIC 
	);
	end component;
		
begin		
	subdividerpll: PLL252 port map ( CLK25, CLKA, CLKB, CLKC, CLKD );   -- use with PAL
--	subdividerpll: PLL252 port map ( CLK25, CLKA, CLKB, CLKC, CLKD );   -- use with NTSC
	
	-- generate the 16 times CPU clock
	process (PHI0, CLKA, CLKB, CLKC, CLKD)
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
	
		if rising_edge(CLKA) then
			if in0_clk='0' and prev0_clk='1' then 
				counter0 := reset; 
			else
				counter0 := counter0+1;
			end if;
			prev0_clk := in0_clk;
			in0_clk := PHI0;  
		end if;
		if rising_edge(CLKB) then
			if in1_clk='0' and prev1_clk='1' then 
				counter1 := reset; 
			else
				counter1 := counter1+1;
			end if;
			prev1_clk := in1_clk;
			in1_clk := PHI0;  
		end if;
		if rising_edge(CLKC) then
			if in2_clk='0' and prev2_clk='1' then 
				counter2 := reset; 
			else
				counter2 := counter2+1;
			end if;
			prev2_clk := in2_clk;
			in2_clk := PHI0;  
		end if;
		if rising_edge(CLKD) then
			if in3_clk='0' and prev3_clk='1' then 
				counter3 := reset; 
			else
				counter3 := counter3+1;
			end if;
			prev3_clk := in3_clk;
			in3_clk := PHI0;  
		end if;
		if falling_edge(CLKA) then
			if in4_clk='0' and prev4_clk='1' then 
				counter4 := reset; 
			else
				counter4 := counter4+1;
			end if;
			prev4_clk := in4_clk;
			in4_clk := PHI0;  
		end if;
		if falling_edge(CLKB) then
			if in5_clk='0' and prev5_clk='1' then 
				counter5 := reset; 
			else
				counter5 := counter5+1;
			end if;
			prev5_clk := in5_clk;
			in5_clk := PHI0;  
		end if;
		if falling_edge(CLKC) then
			if in6_clk='0' and prev6_clk='1' then 
				counter6 := reset; 
			else
				counter6 := counter6+1;
			end if;
			prev6_clk := in6_clk;
			in6_clk := PHI0;  
		end if;
		if falling_edge(CLKD) then
			if in7_clk='0' and prev7_clk='1' then 
				counter7 := reset; 
			else
				counter7 := counter7+1;
			end if;
			prev7_clk := in7_clk;
			in7_clk := PHI0;  
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
	end process;

end immediate;

