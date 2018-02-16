-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity AtariMod is	
	port (
		-- reference clock
		CLK25:  in std_logic;
		TEST : out std_logic_vector(3 downto 0); 

		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing GTIA pins comming inverted to the GPIO1
		GPIO1: in std_logic_vector(20 downto 1)	
	);	
end entity;


architecture immediate of AtariMod is
	-- various clocks
	signal CLK     : std_logic;   -- synchronous clock for most of the circuit
	signal PHASE   : std_logic_vector(1 downto 0);
	signal CLK228  : std_logic;	-- highspeed clock to generate synch clock from
	-- SDTV signals
	signal SDTV_Y   : std_logic_vector(5 downto 0);
	signal SDTV_Pb  : std_logic_vector(4 downto 0);
	signal SDTV_Pr  : std_logic_vector(4 downto 0);
	-- EDTV signals
--	signal EDTV_CSYNC : std_logic;
--	signal EDTV_YPbPr : std_logic_vector(14 downto 0);	
--	-- signals from the SDTV to the EDTV
--	signal linetrigger : std_logic_vector (5 downto 0);
--	-- video memory control
--	signal vramrdaddress : std_logic_vector (8 downto 0);
--	signal vramwraddress : std_logic_vector (8 downto 0);
--	signal vramq         : std_logic_vector (29 downto 0);
	
   component PLL228 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		      : OUT STD_LOGIC 
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

	
	
begin		
	-- building blocks
	fastpll: PLL228 port map ( CLK25, CLK228 );
	
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
--	vram: VideoRAM port map (
--		YPbPr0 & YPbPr1,
--		vramrdaddress,
--		CLK25, -- CLK108,
--		vramwraddress,
--		CLKATARI,
--		'1',
--		vramq		
--	);
	
	
	-- create a 4x atari clock to drive the rest of the circuit	
	process (GPIO1, CLK228)
		variable counter0 : integer range 0 to 63 := 0;
		variable in0_invclk : std_logic := '0'; -- inverted atari clock
		variable counter1 : integer range 0 to 63 := 0;
		variable in1_invclk : std_logic := '0'; -- inverted atari clock		
		
		variable out_phase : std_logic_vector(1 downto 0);

		variable bits0 : std_logic_vector(5 downto 0);
		variable bits1 : std_logic_vector(5 downto 0);	
		variable tmp : integer range 0 to 63;
	begin
		-- Sample the atari clock on the falling and on the rising edge
		-- of the highspeed clock. This should add only 2.3ns of jitter.
		if rising_edge(CLK228) then
			-- compute the clock phase (with huge setup-time)
			tmp := counter0+6;
			bits0 := std_logic_vector(to_unsigned(tmp,6));
			out_phase := bits0(5 downto 4);
			
			if (counter0/8) /= 0 then
				counter0 := counter0+1;
			elsif in0_invclk='0' then
				counter0 := 8;
			end if;						
			in0_invclk := GPIO1(19);
		end if;
		if falling_edge(CLK228) then
			if (counter1/8) /= 0 then
				counter1 := counter1+1;
			elsif in1_invclk='0' then
				counter1 := 8;
			end if;						
			in1_invclk := GPIO1(19);
		end if;
		
      -- merge both clock counters asynchronously
		bits0:= std_logic_vector(to_unsigned(counter0,6));
		bits1:= std_logic_vector(to_unsigned(counter1,6));
		CLK <= bits0(3) or bits1(3);		
		PHASE <= out_phase;

		TEST(0) <= not GPIO1(19);	-- true atari clock
		TEST(1) <= bits0(3) or bits1(3);			
		TEST(3 downto 2) <= out_phase;     
	end process;
	
	
	-- select the correct signal to send to the output 
	process (SDTV_Y,SDTV_Pb,SDTV_Pr) -- ,EDTV_CSYNC,EDTV_YPbPr) 
	begin
		-- use SDTV
		Y  <= SDTV_Y;
		Pb <= SDTV_Pb;
		Pr <= SDTV_Pr;
		
--		-- use EDTV
--		Y(5) <= EDTV_CSYNC;
--		Y(4 downto 0) <= EDTV_YPbPr(14 downto 10);
--		Pb(4 downto 0) <= EDTV_YPbPr(9 downto 5);
--		Pr(4 downto 0) <= EDTV_YPbPr(4 downto 0);					
	end process;
	
--	-- collect the SDTV YPbr signal into the buffer
--	process (CLKATARI)
--		variable hcounter : integer range 0 to 255 := 0;
--		variable vcounter : integer range 0 to 511 := 0;
--		variable numshortsyncs : integer range 0 to 7 := 0;
--		variable out_linetrigger : std_logic_vector(5 downto 0) := "000000";
--	begin
--		if rising_edge(CLKATARI) then
--		   -- trigger the start of EDTV line output
--			out_linetrigger := "000000";
--			if vcounter<2 then 							 
--				if hcounter=0 then
--					out_linetrigger := "010000";		 -- vsync
--				elsif hcounter=114 then
--					out_linetrigger := "100000";      -- vsync
--				end if;
--			elsif vcounter=2 then                   -- vsync and then normal line (black)
--				if hcounter=0 then
--					out_linetrigger := "010000";
--				elsif hcounter=114 then
--					out_linetrigger := "000100";
--				end if;				
--			elsif vcounter mod 2 = 1 then 
--				if hcounter=0 then
--					out_linetrigger := "000001";
--				elsif hcounter=114 then
--					out_linetrigger := "000010";
--				end if;			
--			else
--				if hcounter=0 then
--					out_linetrigger := "000100";
--				elsif hcounter=114 then
--					out_linetrigger := "001000";				
--				end if;
--			end if;
--						
--			-- detect start of lines and progress counters
--			if CSYNC='0' and hcounter>224 then
--				hcounter := 0;
--				if numshortsyncs>=3 then
--					vcounter := 0;
--				elsif vcounter < 511 then
--					vcounter := vcounter+1;
--				end if;
--			elsif hcounter<255 then
--				-- count short syncs - will detect framestart early
--				if hcounter=10 then
--					if CSYNC='1' then
--						numshortsyncs := numshortsyncs+1;
--					else
--						numshortsyncs := 0;
--					end if;
--				end if;	
--				hcounter := hcounter+1;
--			end if;
--		
--		end if;
--		-- compute the address where to write the data
--		vramwraddress <= std_logic_vector(to_unsigned(hcounter + (vcounter mod 2)*256, 9));		
--		-- send line start trigger to EDVT output generator
--		linetrigger <= out_linetrigger;
--		
--	end process;
	
--	-- generate the EDTV YPbPr signal from the buffer
--	process (CLK108)
--		variable x : integer range 0 to 4095 := 0;
--		variable activeline: std_logic_vector(5 downto 0) := "000000";	
--		variable in_linetrigger: std_logic_vector(5 downto 0) := "000000";
--		
--		variable out_csync: std_logic := '1';
--		variable out_ypbpr: std_logic_vector(14 downto 0);
--		
--	begin
--		if rising_edge(CLK108) then
--			-- create the output signal
--			out_csync := '1';
--			out_ypbpr := "000001000010000";
--			if activeline(4)='1' or activeline(5)='1' then
--				if x<4*(864-63) then 
--					out_csync := '0';
--				end if;
--			else
--				if x<4*63 then
--					out_csync := '0';
--				else
--					if (x/8) mod 2 = 0 then
--						out_ypbpr := vramq(14 downto 0);
--					else
--						out_ypbpr := vramq(29 downto 15);
--					end if;
--				end if;
--			end if;
--					
--			-- progress position
--			if x<4095 then 
--				x:=x+1;
--			end if;
--		
--			-- check if line trigger happened and start line output
--			if in_linetrigger/="000000" and activeline/=in_linetrigger then
--				activeline := in_linetrigger;
--				x := 0;
--			end if;		
--			in_linetrigger := linetrigger;			
--		end if;
--		
--		-- request propper data from vram for next clock
--		if activeline(1)='1' or activeline(0)='1' then
--			vramrdaddress <= std_logic_vector(to_unsigned((x+2)/16 + 4, 9));
--		else
--			vramrdaddress <= std_logic_vector(to_unsigned((x+2)/16 + 4 + 256, 9));
--		end if;
--		
--		EDTV_CSYNC <= out_csync;
--		EDTV_YPbPr <= out_ypbpr;
--		
--		TEST(2) <= '0';
--		TEST(3) <= out_csync;
--	end process;

end immediate;

