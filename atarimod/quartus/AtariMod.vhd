-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity AtariMod is	
	port (
		-- reference clock
		CLK25:  in std_logic;

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing GTIA pins comming inverted to the GPIO1
		GPIO1: in std_logic_vector(20 downto 1);	
		
		-- read jumper settings (and provide a GND for jumpers)
		GPIO2_10: out std_logic;
		GPIO2_9: in std_logic;
		GPIO2_8: in std_logic
	);	
end entity;


architecture immediate of AtariMod is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;   
	signal PHASE   : std_logic_vector(1 downto 0);
	
	-- high-speed clock to generate synchronous clock from. this is done
	-- with two coupled signals that are 90 degree phase shifted to give
	-- 4 usable edges with at total frequency of 3,546895 x 64 x 4 Mhz	
	signal CLK227A  : std_logic;
	signal CLK227B : std_logic;
	
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
	
   component PLL227 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		      : OUT STD_LOGIC; 
		c1		      : OUT STD_LOGIC 
	);
	end component;
	
	
   component GTIA2YPbPr is
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
	subdividerpll: PLL227 port map ( CLK25, CLK227A, CLK227B );
	
	gtia: GTIA2YPbPr port map (
		SDTV_Y,
		SDTV_Pb,
		SDTV_Pr,
		CLK,
		PHASE,
		NOT (
		GPIO1(6 downto 6)      -- A4
		& GPIO1(4)             -- A3
		& GPIO1(2)             -- A2
		& GPIO1(1)             -- A1
		& GPIO1(3)),           -- A0
		NOT (
		GPIO1(14 downto 14)    -- D7
		& GPIO1(12)            -- D6
		& GPIO1(10)            -- D5
		& GPIO1(8)             -- D4
		& GPIO1(5)             -- D3
		& GPIO1(7)             -- D2
		& GPIO1(9)             -- D1
		& GPIO1(11)),          -- D0
		NOT (
		GPIO1(17 downto 17)    -- AN2
		& GPIO1(15)            -- AN1
		& GPIO1(13)),          -- AN0
		NOT GPIO1(16),			  -- RW
		NOT GPIO1(18),         -- CS
		NOT GPIO1(20) 			  -- HALT
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
	
	
	------------ create a 4x atari clock to drive the rest of the circuit	-----------------
	process (GPIO1, CLK227A, CLK227B)
		variable counter0 : integer range 0 to 63 := 0;
		variable in0_invclk : std_logic := '0'; -- inverted atari clock
		variable counter1 : integer range 0 to 63 := 0;
		variable in1_invclk : std_logic := '0'; -- inverted atari clock		
		variable counter2 : integer range 0 to 63 := 0;
		variable in2_invclk : std_logic := '0'; -- inverted atari clock		
		variable counter3 : integer range 0 to 63 := 0;
		variable in3_invclk : std_logic := '0'; -- inverted atari clock		
		
		variable out_phase : std_logic_vector(1 downto 0);

		variable bits : std_logic_vector(5 downto 0);
	begin
		-- Sample the atari clock on the falling and on the rising edge
		-- of the coupled clocks. This should add only 1.2ns of jitter.
		if rising_edge(CLK227A) then
			-- compute the atari clock phase (with huge setup-time)
			bits := std_logic_vector(to_unsigned(counter0+6,6));
			out_phase := bits(5 downto 4);
			
			if (counter0/8) /= 0 then
				counter0 := counter0+1;
			elsif in0_invclk='0' then
				counter0 := 8;
			end if;						
			in0_invclk := GPIO1(19);
		end if;
		if rising_edge(CLK227B) then
			if (counter1/8) /= 0 then
				counter1 := counter1+1;
			elsif in1_invclk='0' then
				counter1 := 8;
			end if;						
			in1_invclk := GPIO1(19);
		end if;
		if falling_edge(CLK227A) then
			if (counter2/8) /= 0 then
				counter2 := counter2+1;
			elsif in2_invclk='0' then
				counter2 := 8;
			end if;						
			in2_invclk := GPIO1(19);
		end if;
		if falling_edge(CLK227B) then
			if (counter3/8) /= 0 then
				counter3 := counter3+1;
			elsif in3_invclk='0' then
				counter3 := 8;
			end if;						
			in3_invclk := GPIO1(19);
		end if;
		
      -- merge clock counters asynchronously
		bits:= std_logic_vector
		(	   to_unsigned(counter0,6) or to_unsigned(counter1,6) 
		   or to_unsigned(counter2,6) or to_unsigned(counter3,6)
		);
		CLK <= bits(3);
		PHASE <= out_phase;

--		TEST(0) <= not GPIO1(19);	-- true atari clock
--		TEST(1) <= bits(3);
--		TEST(3 downto 2) <= out_phase;     
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
		usenoscanlines := not GPIO2_9;
	
		if rising_edge(CLK) then
		
			-- generate EDTV output signal (with syncs and all)
			if vcnt<3 then			  -- 6 EDTV lines with sync	
				Y <= "100000";
				Pb <= "10000";
				Pr <= "10000";
				if hcnt<144*4-33 or (hcnt>=114*4 and hcnt<228*4-33) then  -- two EDTV vsyncs
					Y(5) <= '0';
				end if;
			else
				-- get color from buffer
				Y <= "1" & vramq0(14 downto 10);
				Pb <= vramq0(9 downto 5);
				Pr <= vramq0(4 downto 0);
				 -- construct scanline darkening from both adjacent lines
				if hcnt>=2*228 and usenoscanlines='0' then  
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
				if hcnt<33 or (hcnt>=114*4 and hcnt<114*4+33) then  
					Y(5) <= '0';
				end if;
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
			if SDTV_Y(5)='0' and hcnt>4*220 then
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
		if hcnt<228*2 then
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt + ((vcnt+1) mod 2)*512, 10));
		else
			vramrdaddress0 <= std_logic_vector(to_unsigned(hcnt-228*2 + (vcnt mod 2)*512, 10));
			vramrdaddress1 <= std_logic_vector(to_unsigned(hcnt-228*2 + ((vcnt+1) mod 2)*512, 10));
		end if;
		
	end process;
	

end immediate;

