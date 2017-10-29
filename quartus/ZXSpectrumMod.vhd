library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity ZXSpectrumMod is	
	port (
		-- external oscillator
		CLKREF : in std_logic;
				
		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);
		
		-- using GPIO only for input
		GPIO1    : in std_logic_vector(13 downto 0);
		GPIO2    : in std_logic_vector(7 downto 0);

	   -- debugging pin
		TSTOUT : out std_logic;
		TSTOUT2 : out std_logic
	);	
end entity;


architecture immediate of ZXSpectrumMod is
	
   component PLL112 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;
	
	component ZXVideoRAM is
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (12 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (12 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component;
	

	signal CLK112 : std_logic;
	
	signal ram_data      : STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal ram_rdaddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
	signal ram_wraddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
	signal ram_wren		: STD_LOGIC;
	signal ram_q		   : STD_LOGIC_VECTOR (15 DOWNTO 0);
	
	signal D : std_logic_vector(7 downto 0);
	signal CAS : std_logic;
	signal IOREQ : std_logic;
	signal WR : std_logic;
	
	signal BORDER : std_logic_vector(2 downto 0);
	

begin		
	highfrequency: PLL112 port map ( CLKREF, CLK112 );
	videoram: ZXVideoRAM port map (CLK112, ram_data, ram_rdaddress, ram_wraddress, ram_wren, ram_q);
	
	--------- mapping of the GPIO pins to the ZX Spectrum signals
	process (GPIO1,GPIO2)
	begin
		D(0) <= GPIO1(1);
		D(1) <= GPIO1(9);
		D(2) <= GPIO1(11);
		D(3) <= GPIO1(13);
		D(4) <= GPIO2(1);
		D(5) <= GPIO2(3);
		D(6) <= GPIO2(5);
		D(7) <= GPIO2(7);
		CAS   <= GPIO1(3);
	   IOREQ <= GPIO1(5);
	   WR    <= GPIO1(7);
	end process;
		
		
--	process (CLK112)
--	variable writecursor : integer range 0 to 8191 := 0;
--	begin
--		if rising_edge(CLK112) then
--			if writecursor<6143 then
--				writecursor:=writecursor+1;
--			end if;
--		end if;	
--		ram_data <= std_logic_vector(to_unsigned(writecursor,16));
--		ram_wraddress <= std_logic_vector(to_unsigned(writecursor,13));
--		ram_wren <= '1';
--	end process;
	
	--------- listening to the ULA and reading data into video ram
	process (CLK112) 
	
	-- variables for understanding the ULA signals
	variable in_cas:  std_logic_vector(4 downto 0) := "00000";		
	variable cas_islow : boolean := false;
	variable cas_falling : boolean := false;
	
	variable firstedgedetected : boolean := false;
	variable timesincefallingedge : integer range 0 to 255;
	variable timesincedata: integer range 0 to 16383;
	
	-- writing into the video ram
	variable wren : std_logic := '0';
	variable writecursor : integer range 0 to 8191 := 0;
	variable firstbyte : std_logic_vector(7 downto 0) := "00000000";
	variable secondbyte : std_logic_vector(7 downto 0) := "00000000";	
	
	variable outpulsecounter : integer range 0 to 127 := 0;	
	variable out_tst : std_logic := '0';		

	
	begin
		if rising_edge(CLK112) then	
			wren := '0';			
		
			-- produce test signal
			if outpulsecounter>0 then
				outpulsecounter := outpulsecounter-1;
				out_tst := '1';
			else
				out_tst := '0';
			end if;

			-- detect edges of CAS and remove possible glitches 
			cas_falling := false;
			if in_cas="11111" then
				cas_islow := false;
			elsif in_cas="00000" then
				if not cas_islow then
					cas_falling := true;
				end if;
				cas_islow := true;
			end if;
			in_cas := in_cas(3 downto 0) & CAS;
			
			
			-- process glitch-free edges (with a 35ns delay)
			if cas_falling then
				
				-- ULA will make CAS access with 300ns intervall (use anything betweem 200ns and 400ns here)
				if firstedgedetected and timesincefallingedge > 22 and timesincefallingedge < 45 then
					firstedgedetected := false;
					
					if timesincedata<16383 then						
						writecursor := writecursor+1;
					else
						writecursor := 0;
					end if;
					wren := '1';
					
					timesincedata := 0;
					
					outpulsecounter := 30;
				else
					firstedgedetected := true;
				end if;				
				
				timesincefallingedge := 0;
				
			else
		
				-- ram content should be here 35+150ns after falling edge of CAS
				if cas_islow and timesincefallingedge=10 then
					if firstedgedetected then
						firstbyte := D;
					else
						secondbyte := D;
						wren := '1';
					end if;
				end if;
			
				if timesincefallingedge<255 then
					timesincefallingedge := timesincefallingedge+1;
				end if;
			end if;
			
			-- measure data flow to detect start of frame
			if timesincedata<16383 then
				timesincedata := timesincedata+1;
			end if;
			
		end if;
		
		
		ram_data <= secondbyte & firstbyte;
		ram_wraddress <= std_logic_vector(to_unsigned(writecursor,13));		
		ram_wren <= wren;
		
		
		TSTOUT <= out_tst;
		if cas_islow then
			TSTOUT2 <= '0';
		else
			TSTOUT2 <= '1';
		end if;
	end process;
	
	
	------- listening to the CPU if it sets the border color 
	process (CLK112)
	
	variable in_wr: std_logic := '0';
	variable timedown: integer range 0 to 255 := 0;
	variable isiowrite : boolean;
	
	variable out_border: std_logic_vector(2 downto 0) := "001";
	begin
		if rising_edge(CLK112) then
		
			-- check what happens on any wr request
			if in_wr='0' then
			   if timedown=5 then
					if IOREQ='0' then
						isiowrite := true;
					end if;
				end if;
				if timedown<255 then
					timedown:=timedown+1;
				end if;
			-- after rising wr may take the data from the bus
			else
				if isiowrite then  -- check if iowrite was detected previously				
					out_border := D(2 downto 0);
				end if;				
				timedown := 0;
				isiowrite := false;
			end if;
			
			in_wr := WR;
		end if;
	
		BORDER <= out_border;
	end process;
	
	
	------- generate the YPbPr signal from the video ram image
	process (CLK112)

	constant sync:   integer := 0 + 16*32 + 16;
  	type T_zxpalette is array (0 to 15) of integer range 0 to 65535;
   constant zxpalette : T_zxpalette := (
	   -- black  -- blue   -- red    -- purple -- green  -cyan     -- yellow -- white
		16#8210#, 16#8ed1#, 16#99bb#, 16#a6da#, 16#b547#, 16#ca83#, 16#d494#, 16#ce10#,   -- dim
		16#8210#, 16#9792#, 16#b17e#, 16#b31e#, 16#d124#, 16#e284#, 16#e8b4#, 16#fe10#    -- bright
   );	
	
	constant w: integer := 448;  -- (64.00 microseconds -> 15.625kHz)
	constant h: integer := 312;  -- (19968 microseconds -> 50.0801Hz)
	constant vheight: integer := 192;
	constant vstart:  integer := 74;
	constant hstart: integer := 124;
	constant borderthickness: integer := 32;
	
	variable subpixel: integer range 0 to 15 := 0;
	variable cx: integer range 0 to w-1 := 0;
	variable cy: integer range 0 to h-1 := 0;	
	variable frame: integer range 0 to 31 := 0;
	variable px: integer range 0 to 7;
	variable foreground: integer range 0 to 7;
	variable background: integer range 0 to 7;
	variable bright: integer range 0 to 1;
	variable out_rdaddress : integer range 0 to 8191;
	variable out_ypbpr: integer range 0 to 65535 := 0;	
	
	variable tmp_col:std_logic_vector(15 downto 0);
	
	begin
		if rising_edge(CLK112) then
		
			-- idle black
			out_ypbpr := zxpalette(0);

			-- compute sync pulses
			if cy<3 and (cx<2*7 or (cx>=32*7 and cx<34*7)) then             -- short syncs
				out_ypbpr := sync;
			end if;
			if (cy=3 or cy=4) and (cx<30*7 or (cx>=32*7 and cx<62*7)) then  -- long syncs
				out_ypbpr := sync;
			end if;
			if cy=5 and (cx<30*7 or (cx>=32*7 and cx<34*7)) then            -- one long, one short sync
				out_ypbpr := sync;
			end if;
			if (cy=6 or cy=7) and (cx<2*7 or (cx>=32*7 and cx<34*7)) then   -- short syncs
				out_ypbpr := sync;
			end if;
			if (cy>=8) and (cx<4*7) then                                    -- normal syncs
				out_ypbpr := sync;
			end if;
			
			-- compute image
			if cx>=hstart and cx<hstart+256 and cy>=vstart and cy<vstart+vheight then
				px := (cx-hstart) mod 8;				
				foreground := to_integer(unsigned(ram_q(10 downto 8)));
				background := to_integer(unsigned(ram_q(13 downto 11)));
				bright := to_integer(unsigned(ram_q(14 downto 14)));
				if ram_q(15)='1' and frame>=16 then
					foreground := to_integer(unsigned(ram_q(13 downto 11)));
					background := to_integer(unsigned(ram_q(10 downto 8)));
				end if;
				
				if ram_q(7-px)='1' then
					out_ypbpr := zxpalette(foreground+bright*8);
				else
					out_ypbpr := zxpalette(background+bright*8);
				end if;
				
			-- apply border color
			elsif cx>=hstart-borderthickness and cx<hstart+256+borderthickness 
			  and cy>=vstart-borderthickness and cy<vstart+vheight+borderthickness then
				out_ypbpr := zxpalette(to_integer(unsigned(BORDER)));
			end if;
			
			-- determine from where to read next video data word
			out_rdaddress := cy-vstart;
			out_rdaddress := out_rdaddress*32 + (cx+8-hstart) / 8 - 1;	
			if (cx+8-hstart) mod 8=7 and subpixel>=13 then
				out_rdaddress := out_rdaddress+1;
			end if;
			
			-- progress horizontal and vertical counters
			if subpixel<15 then
				subpixel := subpixel+1;
			else
				subpixel := 0;
				if cx<w-1 then
					cx:=cx+1;
				else
					cx:=0;
					if cy<h-1 then
						cy:=cy+1;
					else
						cy:=0;
						frame := frame+1;
					end if;
				end if;
			end if;
		end if;
		
		-- send output signal to lines
		tmp_col := std_logic_vector(to_unsigned(out_ypbpr, 16));		
		Y  <= tmp_col(15 downto 10);
		Pb <= tmp_col(9 downto 5);
		Pr <= tmp_col(4 downto 0);
		
		-- fetch data for next pixel
		ram_rdaddress <= std_logic_vector(to_unsigned(out_rdaddress, 13));			
			
	end process;
	

end immediate;

