-- running on A-Video board Rev.2

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity Sniffer is	
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
		GPIO2_6: in std_logic;
		
		-- debug output
--		GPIO2_8: out std_logic;
		GPIO2_10: out std_logic
	);	
end entity;


architecture immediate of Sniffer is
	-- synchronous clock for most of the circuit
	signal CLK     : std_logic;                     -- 15.763977 MHz
		
	-- SDTV signals
	signal SDTV_Y   : std_logic_vector(5 downto 0);
	signal SDTV_Pb  : std_logic_vector(4 downto 0);
	signal SDTV_Pr  : std_logic_vector(4 downto 0);
	
	-- sniff memory control
	signal sramdata      : std_logic_vector (1 downto 0);
	signal sramrdaddress : std_logic_vector (15 downto 0);
	signal sramwraddress : std_logic_vector (15 downto 0);
	signal sramwren      : std_logic;
	signal sramq         : std_logic_vector (1 downto 0);

   component ClockMultiplier is
	port (
		-- reference clock
		CLK25: in std_logic;		
		-- C64 cpu clock
		PHI0: in std_logic;
		
		-- x16 times output clock
		CLK: out std_logic
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

	component SniffRAM IS
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0)
	);
	END component;

	
begin		
	clkmulti: ClockMultiplier port map ( CLK25, GPIO1(1), CLK );
	
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
		
	sniff: SniffRAM port map (
		CLK,
		sramdata,
		sramrdaddress,
		sramwraddress,
		sramwren,
		sramq
	);
		
	--------- transform the SDTV into a EDTV signal by line doubling (if selected by jumper)
	process (CLK, GPIO2_4, GPIO2_6) 
		constant ramsize: integer := 49152;  -- number of 2-bit words
		constant clocksperbit : integer := 137; -- for 115200 baud
		
		variable phase: integer range 0 to 15 := 0;         -- phase inside of the cycle
		variable sniffcounter : integer range 0 to 65535 := ramsize;
		variable sendcounter : integer range 0 to 65535 := ramsize;
		variable bitdelay : integer range 0 to clocksperbit := 0;
		variable sendbytephase : integer range 0 to 31 := 0;
		variable linelength : integer range 0 to 127 := 0;
	
		variable hcnt : integer range 0 to 1023 := 0;
		variable vcnt : integer range 0 to 511 := 0;
		variable needvsync : boolean := false;
		
		variable trigger : std_logic := '0';
		variable prevtrigger : std_logic := '0';
		
		variable tmp_txdata : std_logic_vector(7 downto 0);
	begin
		if rising_edge(CLK) then


			-- sending
			sramrdaddress <= std_logic_vector(to_unsigned(sendcounter,16)); 
			GPIO2_10 <='1';  -- idle serial signal (or stop bits)
			if sendcounter<ramsize then
				if sendbytephase=0 or sendbytephase=11 then 
					GPIO2_10 <= '0';  -- start bit
				elsif sendbytephase<9 then
					tmp_txdata := "001100" & sramq;
					GPIO2_10 <= tmp_txdata(sendbytephase-1);  -- data bit
				elsif sendbytephase>=12 and sendbytephase<20 then
					tmp_txdata := "00001010";        -- new line	
					GPIO2_10 <= tmp_txdata(sendbytephase-12);			
				end if;
				-- progress send protocol
				if bitdelay<clocksperbit-1 then
					bitdelay := bitdelay+1;
				else
					bitdelay := 0;
					if (sendbytephase<10 and linelength/=62)
					or (sendbytephase<22 and linelength=62) then
						sendbytephase := sendbytephase+1;
					else
						if sendbytephase>15 then
							linelength := 0;
						else
							linelength := linelength+1;
						end if;
						sendbytephase := 0;
						sendcounter := sendcounter+1;
					end if;
				end if;				
			end if;

			-- sniffing
			sramdata <= "00";
			sramwraddress <= "0000000000000000";
			sramwren <= '0';		
			if phase=10 and sniffcounter<ramsize then
				if GPIO1(3)='0' then -- AEC active
					sramdata <= "00";
				elsif GPIO1(5)='0' and GPIO1(6)='0' then  -- RW='0' and CS='0'
					sramdata <= "10";
				else
					sramdata <= "01";
				end if;
				sramwraddress <= std_logic_vector(to_unsigned(sniffcounter,16));
				sramwren <= '1';
				sniffcounter := sniffcounter+1;
			end if;
			
			-- trigger sniffing and sending at correct point in screen
			if hcnt=0 and vcnt=0 and trigger/=prevtrigger then
				prevtrigger := trigger;
				
				sniffcounter := 0;
				sendcounter := 0;
				sendbytephase := 0;
				bitdelay := 100;
				linelength := 0;
			end if;
					
			-- progress counters and detect start of frame 
			if SDTV_Y(5)='0' and hcnt>1000 then
				hcnt := 0;
				if needvsync then 
					vcnt := 0;
					needvsync := false;
				elsif vcnt<511 then
					vcnt := vcnt+1;
				end if;
			elsif hcnt<1023 then
				-- a sync in the middle of a scanline: start sniffing
				if hcnt=200 and SDTV_Y(5)='0' and vcnt>50 then
					needvsync := true;
				end if;
				hcnt := hcnt+1;
			end if;
			
			-- progress the phase
			if phase>12 and GPIO1(1)='0' then
				phase:=0;
			elsif phase<15 then
				phase:=phase+1;
			end if;
			
			-- read trigger signal
			trigger := GPIO2_6;
		end if;

		
		-- pass out SDTV signal unchanged
		Y  <= SDTV_Y;
		Pb <= SDTV_Pb;
		Pr <= SDTV_Pr;
	
	end process;
	
end immediate;

