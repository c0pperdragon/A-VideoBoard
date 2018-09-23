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
		
		-- read jumper settings (and provide a GND for jumpers)
		GPIO2_10: out std_logic;
		GPIO2_9: in std_logic;
		GPIO2_8: in std_logic
	);	
end entity;


architecture immediate of C64Mod is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;                     -- 15.763977 MHz
	signal PHASE   : std_logic_vector(3 downto 0);  -- 16 phases give one C64 clock
	
	-- high-speed clock to generate synchronous clock from. this is done
	-- with two coupled signals that are 90 degree phase shifted to give
	-- 4 usable edges with at total frequency of 15.7639 x 16 x 4 Mhz	
	signal CLK252A : std_logic;  -- 252.223644 Mhz
	signal CLK252B : std_logic;
	
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
		inclk0		: IN STD_LOGIC  := '0';
		c0		      : OUT STD_LOGIC; 
		c1		      : OUT STD_LOGIC 
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
		PHASE       : in std_logic_vector(3 downto 0); 
		
		-- Connections to the real GTIAs pins 
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
	subdividerpll: PLL252 port map ( CLK25, CLK252A, CLK252B );
	
	vic: VIC2YPbPr port map (
		SDTV_Y,
		SDTV_Pb,
		SDTV_Pr,
		CLK,
		PHASE,
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
	process (GPIO1, CLK252A, CLK252B)
		variable counter0 : integer range 0 to 255 := 0;
		variable in0_clk : std_logic := '0'; -- sampling c64 clock
		variable counter1 : integer range 0 to 255 := 0;
		variable in1_clk : std_logic := '0'; -- sampling c64 clock		
		variable counter2 : integer range 0 to 255 := 0;
		variable in2_clk : std_logic := '0'; -- sampling c64 clock		
		variable counter3 : integer range 0 to 255 := 0;
		variable in3_clk : std_logic := '0'; -- sampling c64 clock		
		
		variable out_phase : std_logic_vector(3 downto 0);

		variable bits : std_logic_vector(7 downto 0);
	begin
		-- Sample the c64 clock on the falling and on the rising edge
		-- of the coupled clocks. This should add only 1ns of jitter.
		if rising_edge(CLK252A) then
			-- compute the c64 clock phase (with huge setup-time)
			bits := std_logic_vector(to_unsigned(counter0+14,8));
			out_phase := bits(7 downto 4);
			
			if counter0<248 then
				counter0 := counter0+1;
			elsif in0_clk='0' then
				counter0 := 0;
			end if;						
			in0_clk := GPIO1(1);
		end if;
		if rising_edge(CLK252B) then
			if counter1<248 then
				counter1 := counter1+1;
			elsif in1_clk='0' then
				counter1 := 0;
			end if;						
			in1_clk := GPIO1(1);
		end if;
		if falling_edge(CLK252A) then
			if counter2<248 then
				counter2 := counter2+1;
			elsif in2_clk='0' then
				counter2 := 0;
			end if;						
			in2_clk := GPIO1(1);
		end if;
		if falling_edge(CLK252B) then
			if counter3<248 then
				counter3 := counter3+1;
			elsif in3_clk='0' then
				counter3 := 0;
			end if;						
			in3_clk := GPIO1(1);
		end if;
		
      -- merge clock counters asynchronously
		bits:= std_logic_vector
		(	   to_unsigned(counter0,8) or to_unsigned(counter1,8) 
		   or to_unsigned(counter2,8) or to_unsigned(counter3,8)
		);
		CLK <= bits(3);
		PHASE <= out_phase;
	end process;
	
	
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper)
	process (CLK,GPIO2_8,GPIO2_9) 
		variable hcnt : integer range 0 to 1023 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable shortsyncs : integer range 0 to 3 := 0;
		
		variable val0 : integer range 0 to 63;
		variable val1 : integer range 0 to 63;
		variable uselowres : std_logic; 
		variable usenoscanlines : std_logic;
	begin
		-- handle jumper configuration
		GPIO2_10 <= '0';    -- provide GND ond pin 10
		uselowres := not GPIO2_8; 
		usenoscanlines := '0'; -- not GPIO2_9;
	
		if rising_edge(CLK) then
		
			-- generate EDTV output signal (with syncs and all)
			if vcnt<3 then			  -- 6 EDTV lines with sync	
				Y <= "100000";
				Pb <= "10000";
				Pr <= "10000";
				if hcnt<504-33 or (hcnt>=504 and hcnt<2*504-33) then  -- two EDTV vsyncs
					Y(5) <= '0';
				end if;
			else
				-- get color from buffer
				Y <= "1" & vramq0(14 downto 10);
				Pb <= vramq0(9 downto 5);
				Pr <= vramq0(4 downto 0);
				 -- construct scanline darkening from both adjacent lines
				if hcnt>=504 and usenoscanlines='0' then  
					val0 := to_integer(unsigned(vramq0(14 downto 10)));
					val1 := to_integer(unsigned(vramq1(14 downto 10)));					
					Y(4 downto 0) <= std_logic_vector(to_unsigned((val0+val1) / 4, 5));
					val0 := to_integer(unsigned(vramq0(9 downto 5)));
					val1 := to_integer(unsigned(vramq1(9 downto 5)));										
					Pb <= std_logic_vector(to_unsigned((val0+val1) / 4 + 8, 5));
					val0 := to_integer(unsigned(vramq0(4 downto 0)));
					val1 := to_integer(unsigned(vramq1(4 downto 0)));										
					Pr <= std_logic_vector(to_unsigned((val0+val1) / 4 + 8, 5));
				end if;				
				-- two normal EDTV line syncs
				if hcnt<32 or (hcnt>=504 and hcnt<504+32) then  
					Y(5) <= '0';
				end if;
				
				-- Y <= "100000";
			end if;
			
			-- look for short sync pulses at start of line (to know when next frame starts)
			if hcnt=48 then   -- here only on a short sync line, the sync is already off
				if SDTV_Y(5)='1' and shortsyncs<3 then
					shortsyncs := shortsyncs+1;
				else
					shortsyncs := 0;
				end if;
			end if;
			
			-- progress counters and detect sync
			if SDTV_Y(5)='0' and hcnt>1000 then
				hcnt := 0;
				if shortsyncs=3 then 
					vcnt := 0;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<1023 then
				hcnt := hcnt+1;
			end if;
	
	
			-- if selected, fall back to plain SDTV
			if uselowres='1' then
				Y  <= SDTV_Y;
				Pb <= SDTV_Pb;
				Pr <= SDTV_Pr;
			end if;
		end if;
		
		-- compute VideoRAM write position (write in buffer one line ahead)
		vramwraddress <= std_logic_vector(to_unsigned(hcnt/2 - 2 + ((vcnt+1) mod 2)*512, 10));
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

