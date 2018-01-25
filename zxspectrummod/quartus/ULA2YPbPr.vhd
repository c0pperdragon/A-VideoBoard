library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity ULA2YPbPr is	
	port (
--		-- external oscillator
		CLKREF : in std_logic;
				
		-- digital YPbPr output
		Y: out std_logic_vector(5 downto 0);
		Pb: out std_logic_vector(4 downto 0);
		Pr: out std_logic_vector(4 downto 0);

		-- sniffing ULA pins
		D : in std_logic_vector(7 downto 0);
		CAS : in std_logic;
		IOREQ : in std_logic;
		WR : in std_logic		
	);	
end entity;


architecture immediate of ULA2YPbPr is
	
   component PLL112 is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;
	component PLL112_224 IS
	port
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC 
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
	

	signal CLK224 : std_logic;
	signal CLK112 : std_logic;
	signal CLK7 : std_logic;
	
	signal slow7mhz : std_logic;
	signal fast7mhz : std_logic;
	
	signal ram_data      : STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal ram_rdaddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
	signal ram_wraddress : STD_LOGIC_VECTOR (12 DOWNTO 0);
	signal ram_wren		: STD_LOGIC;
	signal ram_q		   : STD_LOGIC_VECTOR (15 DOWNTO 0);
				
	signal BORDER : std_logic_vector(2 downto 0);
	signal inframetrigger : std_logic;
	
begin		
	highfrequency: PLL112_224 port map ( CLKREF, CLK112, CLK224 );
	videoram: ZXVideoRAM port map (CLK112, ram_data, ram_rdaddress, ram_wraddress, ram_wren, ram_q);

	
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
	
	-- signals to sync the output image generator
	variable out_inframe : std_logic := '0';
	
	begin
		if rising_edge(CLK112) then	
			wren := '0';			
		
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
						
						-- signal to output signal generator that the frame end is detected
						if writecursor=0 then
							out_inframe := '1';
						elsif writecursor=32*156 then
							out_inframe := '0';
						end if;

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
		
		-- write to internal video ram
		ram_data <= secondbyte & firstbyte;
		ram_wraddress <= std_logic_vector(to_unsigned(writecursor mod 32,13));		
		ram_wren <= wren;

		inframetrigger <= out_inframe;
	end process;
	
	
	------- listening to the CPU if it sets the border color 
	process (CLK112)
	
	variable in_wr: std_logic := '0';
	variable timedown: integer range 0 to 255 := 0;
	variable isiowrite : boolean;
	
	variable out_border: std_logic_vector(2 downto 0) := "111";
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
	
	
	-- generate 7MHz output clock with the possibility to fine-tune the speed 
	process (CLK224) 
	variable cnt: integer range 0 to 32 := 0;
	variable tmp_cnt: std_logic_vector(5 downto 0);
	begin
		if rising_edge(CLK224) then
			if (cnt=30 and slow7mhz='1') or (cnt=31 and fast7mhz='0') or (cnt=32) then
				cnt := 0;
			else
				cnt := cnt+1;
			end if;
		end if;	
		tmp_cnt := std_logic_vector(to_unsigned(cnt,6));
		CLK7 <= tmp_cnt(4);
	end process;
	
	-- tune the 7mhz clock to match the incomming frame rate
	process (CLK7)
	constant halfframe : integer := 448*312/2;
	
	variable out_slow7mhz: std_logic := '0';
	variable out_fast7mhz: std_logic := '0';
	
	variable f1: std_logic := '0';
	variable f2: std_logic := '0';
	
	variable frametime : integer range -1000000 to 1000000 := 0;
	variable speedup :   integer range -1000000 to 1000000 := 0;
	variable accu :      integer range -1000000 to 1000000 := 0;
	begin 
		if rising_edge(CLK7) then
			-- speed up or slow down the incomming clock
			out_slow7mhz := '0';
			out_fast7mhz := '0';
			accu := accu + speedup;
			if accu >= halfframe then
				accu := accu - halfframe;
				out_fast7mhz := '1';
			elsif accu <= -halfframe then
				accu := accu + halfframe;
				out_slow7mhz := '1';
			end if;
			-- compute the speedup value according to currently being behind / ahead
			if f1 /= f2 then					
				frametime := frametime + 1 - halfframe;
				if frametime<-1000 or frametime>1000 then
					frametime := 0;
					speedup := 0;
				else
					speedup := frametime * 32;
				end if;
			else
				frametime := frametime+1;				
			end if;
			f2 := f1;
			f1 := inframetrigger;
		end if;
		
		slow7mhz <= out_slow7mhz;
		fast7mhz <= out_fast7mhz;
	end process;
		
	
	------- generate the YPbPr signal from the video ram image
	process (CLK7)

	constant sync:   integer := 0 + 16*32 + 16;
  	type T_zxpalette is array (0 to 15) of integer range 0 to 65535;
   constant zxpalette : T_zxpalette := (
	   -- black  -- blue   -- red    -- purple -- green  -cyan     -- yellow -- white
		16#8210#,16#8b4e#,16#99ba#,16#a2d8#,16#ad48#,16#b666#,16#c0d2#,16#ce10#,   -- dim
		16#8210#,16#93ed#,16#a57f#,16#b77d#,16#c8a3#,16#daa0#,16#ec13#,16#fe10#    -- bright
   );	
	
	variable f1: std_logic := '0';
	variable f2: std_logic := '0';
	
	constant w: integer := 448;    -- (64.00 microseconds -> 15.625kHz)
	constant h: integer := 312;    -- (19968 microseconds -> 50.0801Hz)
	constant vheight: integer := 192;
	constant vstart:  integer := 74;
	constant hstart: integer := 124;
	constant borderthickness: integer := 32;
	
	variable cx: integer range 0 to 511 := 0;
	variable cy: integer range 0 to 511 := 0;	
	variable frame: integer range 0 to 31 := 0;
	variable px: integer range 0 to 7;
	variable foreground: integer range 0 to 7;
	variable background: integer range 0 to 7;
	variable bright: integer range 0 to 1;
	variable out_rdaddress : integer range 0 to 8191;
	variable out_ypbpr: integer range 0 to 65535 := 0;	
	
	variable out_outframe: std_logic := '0';
	
	variable tmp_col:std_logic_vector(15 downto 0);
	
	begin
		if rising_edge(CLK7) then
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
			out_rdaddress := out_rdaddress*32 + (cx+1-hstart) / 8;
--			if (cx+8-hstart) mod 8=7 and subx>=13 then
--				out_rdaddress := out_rdaddress+1;
--			end if;
			
			
			if cy>=vstart and cy<vstart+h/2 then 
				out_outframe := '1';
			else
				out_outframe := '0';
			end if;

					
			-- detect edge input screen start and force output in sync
			if f1='1' and f2='0' and (cy/=vstart or cx<hstart-110 or cx>hstart-10) then
				cy := vstart;
				cx := hstart - 50;
			else
				-- progress horizontal and vertical counters
				if cx<w-1 then
					cx := cx+1;
				else
					cx:=0;
					if cy<h-1 then 
						cy:=cy+1;
					else
						cy := 0;
						frame := frame+1;
					end if;
				end if;			
			end if;
			f2 := f1;
			f1 := inframetrigger;	
		end if;
		
		-- send output signal to lines
		tmp_col := std_logic_vector(to_unsigned(out_ypbpr, 16));		
		Y  <= tmp_col(15 downto 10);
		Pb <= tmp_col(9 downto 5);
		Pr <= tmp_col(4 downto 0);
		
		-- fetch data for next pixel
		ram_rdaddress <= std_logic_vector(to_unsigned(out_rdaddress mod 32, 13));			
			
	end process;
	

end immediate;

