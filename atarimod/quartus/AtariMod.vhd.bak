-- running on D-Video board 

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package DVideo2HDMI_pkg is
	-- for each mode:  
	--    h_sync h_bp h_addr h_fp h_imagestart
   --    v_sync v_bp v_addr v_fp v_imagestart	
	type videotiming is array(0 to 9) of integer;
	type videotimings is array(natural range <>) of videotiming;
	
		
	-- for each mode a stream of 144 configuration bits of the PLL
   type pllconfigurations is array(natural range <>) of unsigned(143 downto 0);
end package;



library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.DVideo2HDMI_pkg.all;

entity DVideo2HDMI is	
	generic ( 
		 timings:videotimings;
		 configurations:pllconfigurations;
		 vstretch:boolean
	);
	port (
	   -- default clocking and reset
		CLK50: in std_logic;	
      RST: in std_logic;
		
	   -- HDMI interface
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic; 
      adv7513_hs : out std_logic; 
      adv7513_vs : out std_logic;
      adv7513_clk : out std_logic;
      adv7513_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7513_de : out std_logic;
	
		-- DVideo input -----
		DVID_CLK    : in std_logic;
		DVID_REFCLK : in std_logic;
		DVID_HSYNC  : in std_logic;
		DVID_VSYNC  : in std_logic;
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0);
		
		-- debugging output ---
		DEBUG0 : out std_logic;
		DEBUG1 : out std_logic
	);	
end entity;


architecture immediate of DVideo2HDMI is

   component PLL is
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		configupdate		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		scanclk		: IN STD_LOGIC  := '1';
		scanclkena		: IN STD_LOGIC  := '0';
		scandata		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC ;
		scandataout		: OUT STD_LOGIC ;
		scandone		: OUT STD_LOGIC 
	);
	end component;


	component SyncRAM is
    Generic (
           ADDRESSWIDTH: natural := 8; 
           DATAWIDTH: natural := 8
    );
    Port ( 
		data		: IN STD_LOGIC_VECTOR (DATAWIDTH-1 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (ADDRESSWIDTH-1 DOWNTO 0);
		rdclock		: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (ADDRESSWIDTH-1 DOWNTO 0);
		wrclock		: IN STD_LOGIC  := '1';
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (DATAWIDTH-1 DOWNTO 0)
    );
	end component;
	
	function hexdigit(i:integer) return integer is 
	begin 
		if i<=9 then
			return i+48;
		else
			return i+55;
		end if;
	end hexdigit;

	
	constant numres : integer := timings'length;
	signal resolution : integer range 0 to numres;
	
	signal pll_areset         : std_logic;
	signal pll_configupdate   : std_logic;
	signal pll_scanclkena     : std_logic;
	signal pll_scandata       : std_logic;
	                    -- incomming data (already aligned with CLK50)	
	signal in_available : std_logic;
	signal in_rgb : std_logic_vector(11 downto 0);
	signal in_hsync : std_logic;
	signal in_vsync : std_logic;
	
	signal clkpixel : std_logic;         -- pixel clock to drive HDMI 
	signal clkpixellocked : std_logic;
	signal framestart : std_logic;       -- signals the first part of an incomming video frame  
	
	signal ram_data: STD_LOGIC_VECTOR (11 DOWNTO 0);
	signal ram_rdaddress: STD_LOGIC_VECTOR (13 DOWNTO 0);
	signal ram_wraddress : STD_LOGIC_VECTOR (13 DOWNTO 0);
	signal ram_wren : STD_LOGIC;
	signal ram_q : STD_LOGIC_VECTOR (11 DOWNTO 0);
	
	
begin		
	pixelclockgenerator: PLL 
	port map (
		pll_areset, 
		pll_configupdate,
		DVID_REFCLK, 
		CLK50,
		pll_scanclkena, 
		pll_scandata,
		clkpixel,
		clkpixellocked,
		open,
		open
	);
   videoram1 : SyncRAM generic map (14,12)
	port map(
		ram_data, 
	   ram_rdaddress,
		clkpixel, 
	   ram_wraddress, 
		CLK50, 
		ram_wren,
		ram_q
	);
	
	
	-- Program to set up the pixel clock PLL according to the current screenmode.
	process (CLK50)
	
	variable programmedres : integer range 0 to numres := numres;
	variable b : integer range 0 to 1023 := 1000;  -- idle state

	variable out_configupdate : std_logic := '0';
	variable out_areset : std_logic := '0';
	variable out_scanclkena : std_logic := '0';
	variable out_scandata : std_logic := '0';
	begin
		if rising_edge(CLK50) then
			out_configupdate := '0';
			out_areset := '0';
			out_scandata := '0';
			out_scanclkena := '0';

			if b<1023 then
				b := b+1;
			elsif resolution /= programmedres then
				programmedres := resolution;
				b := 0;
			end if;

			if b<=144 then
				out_scanclkena := '1';
			end if;
			
			if b>=1 and b<=144 then
				out_scandata := std_logic(configurations(programmedres)(b-1)); 
			end if;
			
			if b=150 then
				out_configupdate := '1';
			end if;
			
			if b=300 then
				out_areset := '1';
			end if;
			
		end if;
		
		pll_configupdate <= out_configupdate;
		pll_areset <= out_areset;
		pll_scanclkena <= out_scanclkena;
		pll_scandata <= out_scandata;
	end process;
	
	
  -- clock in the DVID data on every edge 
  -- delay signals to get a zero-hold time trigger on DVID_CLK 
  process (CLK50) 
  variable a0 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b0 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a1 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b1 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a2 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b2 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a3 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b3 : std_logic_vector(14 downto 0) := "000000000000000";
  variable level : std_logic := '0';
  
  variable data : std_logic_vector(13 downto 0) := "00000000000000";
  variable available : std_logic := '0';
  begin
		-- only on rising edge, check what DVID_CLK edge has happened
		if rising_edge(CLK50) then
			if a2(14)=b1(14) and b1(14)/=level then
				level := b1(14);
				data := b3(13 downto 0);
				available := '1';
			elsif a1(14)=b1(14) and b1(14)/=level then
				level := b1(14);
				data := a3(13 downto 0);
				available := '1';
			else
				available := '0';
			end if;
		end if;
  
		-- pipe next data in with 100MHz sample rate
		if rising_edge(CLK50) then
			b3 := b2;
			b2 := b1;
			b1 := b0;
			a3 := a2;
			a2 := a1;
			a1 := a0;
			a0 := DVID_CLK & DVID_HSYNC & DVID_VSYNC & DVID_RGB;			
		end if;		
	   if falling_edge(CLK50) then
			b0 := DVID_CLK & DVID_HSYNC & DVID_VSYNC & DVID_RGB;
      end if;

		in_available <= available;
		in_hsync <= data(13);
		in_vsync <= data(12);
		in_rgb <= data(11 downto 0);
  end process; 
			
			
  ------------------- process the pixel stream ------------------------
  process (CLK50)	    
	-- visible range:  400x270 (PAL),  400x240 (NTSC)	
	variable x : integer range 0 to 1023 := 0;
	variable y : integer range 0 to 511 := 0;
	
	variable out_framestart : std_logic := '0';
	variable out_ramdata : std_logic_vector(11 downto 0) := (others => '0');
	variable out_ramwren : std_logic := '0';
	variable out_ramwraddress : std_logic_vector(13 downto 0) := (others => '0');
	
	begin	
		if rising_edge(CLK50) then
			out_ramwren := '0';
			
			-- process whenever there is new incomming data  
			if in_available='1' then
				
				-- detect frame start and notify the HDMI signal generator
				if  x+y*384 >= timings(resolution)(5) + 1 
				and x+y*384 < timings(resolution)(5) + 8  then 
					out_framestart := '1';
				else
					out_framestart := '0';
				end if;
									 
				-- sync signals reset the counter
				if in_vsync='1' then 
					y:= 0;
					x:= 0;
					
				elsif in_hsync='1' then
					if x>0 then 
						y := y+1;
					end if;
					x:=0;
	
				-- receive pixel, and if visible, store it
				else 
					if x<384 and y<270 then
						out_ramdata := std_logic_vector(in_rgb);
						out_ramwren := '1';
						out_ramwraddress := std_logic_vector(to_unsigned(
							((x+y*384) mod 16384), 
							14));
						
						x := x+1;
					end if;
				end if;
			end if;	
	
		end if;   
		
		-- put registers on output lines
		framestart <= out_framestart;
		ram_data <= out_ramdata;	
		ram_wren <= out_ramwren; 
		ram_wraddress <= out_ramwraddress(13 downto 0);
	end process;	
	
	
	------------------- create the output hdmi video signals ----------------------
	process (clkpixel) 	
	variable x : integer range 0 to 4095 := 0; 
	variable y : integer range 0 to 2047 := 0;
		
	variable in_framestart : std_logic := '0';
	
   variable out_hs : std_logic := '0';
	variable out_vs : std_logic := '0';
	variable out_rgb : std_logic_vector (11 downto 0) := (others => '0');
	variable out_de : std_logic := '0';

	variable pixelphase : integer range 0 to 3;	
	variable pixeladdress : integer range 0 to 16384-1;	
	variable linephase : integer range 0 to 8;
	variable lineaddress : integer range 0 to 16384-1;
	variable insidepixelbuffer : std_logic;
	variable insidepixelbuffer2 : std_logic;
	variable insidepixelbuffer3 : std_logic;

	variable h_sync : integer;
	variable h_bp : integer;
	variable h_addr : integer;
	variable h_fp : integer;   
	variable h_imagestart : integer;
	variable v_sync : integer;
	variable v_bp : integer;
	variable v_addr : integer;
	variable v_fp : integer;
	variable firstlineaddress : integer;
	
	begin

		
		if rising_edge(clkpixel) and clkpixellocked='1'  then		
			-- provide ram address in next clock

			-- calculate the timings values according to the table
			h_sync := timings(resolution)(0);
			h_bp := timings(resolution)(1);
			h_addr := timings(resolution)(2);
			h_fp := timings(resolution)(3);
			h_imagestart := h_sync + h_bp + timings(resolution)(4);
			firstlineaddress := timings(resolution)(5);
			v_sync := timings(resolution)(6);
			v_bp := timings(resolution)(7);
			v_addr := timings(resolution)(8);
			v_fp := timings(resolution)(9);
		
			-- write output signals to registers 
			if y<v_sync then
				out_vs := '1';
			else 
			   out_vs := '0';
			end if;
			if x<h_sync then
				out_hs := '1';
			else 
			   out_hs := '0';
			end if;
			if  x>=h_sync+h_bp and x<h_sync+h_bp+h_addr
			and y>=v_sync+v_bp and y<v_sync+v_bp+v_addr then
				out_de := '1';
				if insidepixelbuffer3='1' then
					out_rgb := ram_q;				
				else
					out_rgb := (others=>'0');
				end if;
			else
				out_de := '0';
				out_rgb := (others=>'0');
			end if;
   				
--			-- pipelining info
			insidepixelbuffer3 := insidepixelbuffer2;
			insidepixelbuffer2 := insidepixelbuffer;
			insidepixelbuffer := '0';
			if x>=h_imagestart and x<h_imagestart+384*4 then
				insidepixelbuffer := '1';
			end if;
			
			-- counters for low-res pixels
			if x=h_imagestart then
				pixeladdress := lineaddress;
				pixelphase := 0;
			elsif pixelphase<3 then
				pixelphase := pixelphase+1;
			else
				pixelphase := 0;
				pixeladdress := (pixeladdress+1) mod 16384;
			end if;
			if x=0 then
				if y=v_sync+v_bp then
					lineaddress := firstlineaddress mod 16384;
					linephase := 0;
				else
					if linephase<3 then
						linephase := linephase+1;
					elsif linephase<8 and vstretch then
						if linephase=3 then
							lineaddress := (lineaddress + 384) mod 16384;
						end if;
						linephase := linephase+1;							
					else
						linephase := 0;
						lineaddress := (lineaddress + 384) mod 16384;
					end if;
				end if;
			end if;
			
			-- continue with next high-res pixel in next clock		
			if y=v_sync+v_bp-4 and x=0 and in_framestart='0' then --   and false then
					-- stop progression here until framestart signal 			
			elsif x < h_sync+h_bp+h_addr+h_fp - 1 then
				x := x+1;
			else 
				if y  < v_sync+v_bp+v_addr+v_fp-1 then
					x := 0;
					y := y+1;
				else
					x := 0;
					y := 0;						
				end if;
			end if;		
			
			in_framestart := framestart;			
	
		end if;
	
      adv7513_clk <= clkpixel; 
      adv7513_hs <= out_hs; 
      adv7513_vs <= out_vs;
      adv7513_de <= out_de;
		adv7513_d <= 	  out_rgb(11 downto 8) 
							& out_rgb(11 downto 8)
							& out_rgb(7 downto 4)
							& out_rgb(7 downto 4)
							& out_rgb(3 downto 0)
							& out_rgb(3 downto 0);			

		ram_rdaddress <= std_logic_vector(to_unsigned(pixeladdress,14));
		
		DEBUG0 <= out_hs;
	end process;

	
	
	-- Control program to initialize the HDMI transmitter and
	-- to retrieve monitor configuration data to select 
	-- correct screen resolution. 
	-- The process implements a serial program with subroutine calls
	-- using a big state machine.
	process (CLK50)
		-- configuration data
		type T_CONFIGPAIR is array(0 to 1) of integer range 0 to 255;
		type T_CONFIGDATA is array(natural range <>) of T_CONFIGPAIR;
		constant CONFIGDATA : T_CONFIGDATA := (
                    -- power registers
--				(16#41#, 2#01000000#), -- power down to reset everything
				(16#41#, 2#00000000#), -- power down inactive
				(16#D6#, 2#11000000#), -- HPD is always high
				
                    -- fixed registers
				(16#98#, 16#03#), 
				(16#9A#, 16#e0#), 
				(16#9C#, 16#30#),
				(16#9D#, 16#01#),
				(16#A2#, 16#A4#),
				(16#A3#, 16#A4#),
				(16#E0#, 16#D0#),
				(16#F9#, 16#00#),
				
				                 -- force to DVI mode
				(16#AF#, 16#00#),  

  				                 -- video input and output format
				(16#15#, 16#00#),-- inputID = 1 (standard)
				                 -- 0x16[7]   = 0b0  .. Output format = 4x4x4
								     -- 0x16[5:4] = 0b11 .. color depth = 8 bit
									  -- 0x16[3:2] = 0x00 .. input style undefined
									  -- 0x16[1]   = 0b0  .. DDR input edge
									  -- 0x16[0]   = 0b0  .. output color space = RGB
				(16#16#, 16#30#),		
				
				                 -- edid address (slave address=3F)
				(16#43#, 2#01111110#),
				
				                 -- various unused options - force to default
				(16#17#, 16#00#), 		
				(16#18#, 16#00#),  -- output color space converter disable 		
				(16#48#, 16#00#),
				(16#BA#, 16#60#),
				(16#D0#, 16#30#),
				(16#40#, 16#00#),
				(16#41#, 16#00#),
				(16#D5#, 16#00#),
				(16#FB#, 16#00#),
				(16#3B#, 16#00#)
	  );
	
	
		-- implement the program counter with states
		type t_pc is (
			main0,main1,main2,main3,main10,main11,main12,main13,main14,main15,main16,main17,main99,
			i2c0,i2c1,i2c2,i2c3,i2c3a,i2c4,i2c5,i2c6,i2c7,i2c8,i2c9,
			i2c10,i2c11,i2c12,i2c13,i2c14,i2c16,i2c17,i2c18,i2c19,
			i2c20,i2c21,i2c99,i2c100,i2c101,
			i2cpulse0,i2cpulse1,i2cpulse2,
			uart0,uart1,uart2,
			delay0,delay1,
			millis0,millis1
		);
		variable pc : t_pc := main0;
	  	
		variable main_i:integer range 0 to 255;
		variable main_edid_hor:  unsigned(11 downto 0);
		variable main_edid_vert: unsigned(11 downto 0);
		
		-- subroutine: uart	
		variable uart_retadr:t_pc;   
		variable uart_data:unsigned(7 downto 0);         -- data to send
		variable uart_i:integer range 0 to 11;        
		
		-- subroutine: i2cwrite
		variable i2c_retadr : t_pc;
		variable i2c_address : unsigned(6 downto 0);
		variable i2c_register : unsigned(7 downto 0);
		variable i2c_data : unsigned(7 downto 0);
		variable i2c_rw : std_logic;  -- '0'=w
		variable i2c_error : unsigned(7 downto 0);
		variable i2c_i : integer range 0 to 7;

		-- subroute i2cpulse
		variable i2cpulse_retadr : t_pc;
		variable i2cpulse_sda : std_logic;
		
		-- subroutine: delay
		variable delay_retadr:t_pc;
		variable delay_micros:integer range 0 to 1000;  -- microseconds to delay
		variable delay_i:integer range 0 to 1000*50;

		-- subroutine: millis
		variable millis_retadr:t_pc;
		variable millis_millis:integer range 0 to 1000;  -- microseconds to delay
		variable millis_i:integer range 0 to 1000*50;
		
		-- output signal buffers 
		variable out_tx : std_logic := '1';
		variable out_scl : std_logic := '1';
		variable out_sda : std_logic := '1';
		variable out_resolution : integer range 0 to numres-1;
		
	begin

		-- synchronious program execution
		if rising_edge(CLK50) then
			case pc is
			
			-- main routine
			when main0 =>
				main_i := 0;
				pc := millis0;
				millis_millis := 200;  -- wait 200 millis before start
				millis_retadr := main1;
			-- program the hdmi transmitter registers
			when main1 =>
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(CONFIGDATA(main_i)(0),8);
				i2c_data := to_unsigned(CONFIGDATA(main_i)(1),8);
				i2c_rw := '0';			
				i2c_retadr := main2;	
			when main2 =>
				if i2c_error/="00000000" then
					pc := uart0;
					uart_data := i2c_error; 
					uart_retadr := main99;
				else
					pc := main3;
				end if;
			when main3 =>
				if main_i<CONFIGDATA'LENGTH-1 then
					main_i := main_i + 1;
					pc := main1;
				else
					main_i := 0;
					pc := main10;
				end if;
			-- read out EDID memory
			when main10 =>
				pc := i2c0;
				i2c_address := to_unsigned(16#3F#,7); -- to_unsigned(16#39#,7);
				i2c_register := to_unsigned(main_i,8);
				i2c_rw := '1';			
				i2c_retadr := main11;
			when main11 =>
				if i2c_error/="00000000" then
					pc := uart0;
					uart_data := i2c_error; 
					uart_retadr := main99;
				else				
					-- memorize native resolution info
					if main_i=54+2 then
						main_edid_hor(7 downto 0) := i2c_data;
					elsif main_i=54+4 then
						main_edid_hor(11 downto 8) := i2c_data(7 downto 4);
					elsif main_i=54+5 then
						main_edid_vert(7 downto 0) := i2c_data;
					elsif main_i=54+7 then
						main_edid_vert(11 downto 8) := i2c_data(7 downto 4);
					end if;
					pc := uart0;
					uart_data := to_unsigned(hexdigit(to_integer(i2c_data(7 downto 4))),8);
					uart_retadr := main12;
				end if;
			when main12 =>
				pc := uart0;
				uart_data := to_unsigned(hexdigit(to_integer(i2c_data(3 downto 0))),8);
				uart_retadr := main13;
			when main13 =>
				pc := uart0;
				if (main_i mod 16) = 15 then 
					uart_data := to_unsigned(10,8);
				else
					uart_data := to_unsigned(32,8);
				end if;
				uart_retadr := main14;			
			when main14 =>
				if main_i < 127 then
					main_i := main_i + 1;
					pc := main10;
				else
					pc := uart0;
					uart_data := to_unsigned(10,8);
					uart_retadr := main15;			
				end if;
			when main15 =>
				-- decide which resolution to use
				out_resolution := numres-1;
				for i in 0 to numres-2 loop
					if  to_integer(main_edid_hor)=timings(i)(2) 
					and to_integer(main_edid_vert)=timings(i)(8) then
						out_resolution := i;
					end if;
				end loop;
				pc := main99;
			when main16 =>  
				-- toggle the re-read bit
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(16#C9#,8);
				i2c_data := to_unsigned(2#00000011#,8);
				i2c_rw := '0';			
				i2c_retadr := main17;
			when main17 =>  -- toggle the re-read bit
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(16#C9#,8);
				i2c_data := to_unsigned(2#00010011#,8);
				i2c_rw := '0';			
				i2c_retadr := main99;
				
			-- wait a bit before polling the EDID again
			when main99 =>
				pc := millis0;
				millis_millis := 1000;
				millis_retadr := main10;   
					
			-- uart transmit
			when uart0 =>
				out_tx := '0'; -- start bit
				uart_i := 0;
				pc := delay0;
				delay_micros := 104;  -- delay setting for for 9600 baud
				delay_retadr := uart1;
			when uart1 =>
				out_tx := uart_data(uart_i);  -- data bits
				pc := delay0;
				if uart_i<7 then 
					uart_i := uart_i+1;
					delay_retadr := uart1;
				else 
					delay_retadr := uart2;
				end if;	
			when uart2 =>
				out_tx := '1'; -- stop bit and idle level
				pc := delay0;
				delay_retadr := uart_retadr;				
			
			-- i2c transfer
			when i2c0 =>
				delay_micros := 3;   -- configure i2c step speed (ca. 100k bit/s)
				i2c_error := to_unsigned(0,8);
				out_sda := '0';    	-- start condition 1  
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c1;
			when i2c1 =>
				out_sda := '0';       -- start condition 2
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2c2;
				i2c_i := 6;
			when i2c2 =>
				out_sda := i2c_address(i2c_i);   -- sending address
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c2;
				else
					i2cpulse_retadr := i2c3;
				end if;
			when i2c3 =>                         
				out_sda := '0';               -- write mode 
				pc := i2cpulse0;
				i2cpulse_retadr := i2c3a;
			when i2c3a =>                         
				out_sda := '1';              -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c4;
			when i2c4 =>   
				if i2cpulse_sda='0' then    -- ack received
					i2c_i := 7;
					pc := i2c5;
				else
					i2c_error := to_unsigned(69,8);  -- 'E'
					pc := i2c99;
				end if;
			when i2c5 =>
				out_sda := i2c_register(i2c_i);   -- sending register number
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c5;
				else
					i2cpulse_retadr := i2c6;
				end if;
			when i2c6 =>
				out_sda := '1';                  -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c7;
			when i2c7 =>
				if i2cpulse_sda='0' then         -- received ack
					i2c_i := 7;
					if i2c_rw='0' then     
						pc := i2c8;   -- set register
					else
						pc := i2c11;  -- read register
					end if;
				else
					i2c_error :=  to_unsigned(70,8);  -- 'F'
					pc := i2c99;
				end if;
			when i2c8 =>
				out_sda := i2c_data(i2c_i);     -- sending data
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c8;
				else
					i2cpulse_retadr := i2c9;
				end if;
			when i2c9 => 
				out_sda := '1';                  -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c10;
			when i2c10 =>
				if i2cpulse_sda='0' then         -- received ack
					pc := i2c99;
				else
					i2c_error :=  to_unsigned(71,8);  -- 'G'
					pc := i2c99;
				end if;
				
			when i2c11 =>	                 
				out_sda := '1';                  -- restart condition 1
				out_scl := '0';                  
				pc := delay0;
				delay_retadr := i2c12;
			when i2c12 =>	                 
				out_sda := '1';                  -- restart condtion 2
				out_scl := '1';                 
				pc := delay0;
				delay_retadr := i2c13;
			when i2c13 =>	                 
				out_sda := '0';                  -- restart condition 3
				out_scl := '1';                 
				pc := delay0;
				delay_retadr := i2c14;
			when i2c14 =>	                 
				out_sda := '0';                  -- restart condition 4
				out_scl := '0';                 
				pc := delay0;
				delay_retadr := i2c16;
				i2c_i := 6;
			when i2c16 =>
				out_sda := i2c_address(i2c_i);   -- sending address
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c16;
				else
					i2cpulse_retadr := i2c17;
				end if;
			when i2c17 =>                         
				out_sda := '1';               -- read mode 
				pc := i2cpulse0;
				i2cpulse_retadr := i2c18;
			when i2c18 =>                         
				out_sda := '1';              -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c19;
			when i2c19 =>   
				if i2cpulse_sda='0' then     -- ack received
					i2c_i := 7;
					pc := i2c20;
				else
					i2c_error := to_unsigned(82,8);  -- 'R'
					pc := i2c99;
				end if;
			when i2c20 =>
				out_sda := '1';              -- let slave send data
				pc := i2cpulse0;
				i2cpulse_retadr := i2c21;
			when i2c21 =>
				i2c_data(i2c_i) := i2cpulse_sda;    -- reive data
				if i2c_i>0 then
					i2c_i := i2c_i-1;
					pc := i2c20;
				else
					out_sda := '1';                -- send final nack 
					pc := i2cpulse0;
					i2cpulse_retadr := i2c99;
				end if;
								
			when i2c99 =>
				out_sda := '0';                  -- end condition 1
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2c100;
			when i2c100 =>
				out_sda := '0';                  -- end condition 2
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c101;
			when i2c101 =>
				out_sda := '1';                  -- end condition 3
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c_retadr;
				
			-- perform a single i2c clock
			when i2cpulse0 =>
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2cpulse1;				
			when i2cpulse1 =>
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2cpulse2;
			when i2cpulse2 =>
				if adv7513_scl='1' then  -- proceed if slave does not stretch the clock
					i2cpulse_sda := adv7513_sda;  -- sample data at correct time
					out_scl := '0';
					pc := delay0;
					delay_retadr := i2cpulse_retadr;
				else 
					pc := delay0;					
					delay_retadr := i2cpulse2;
				end if;
			
			-- delay
			when delay0 =>
				delay_i := delay_micros * 50;
				pc := delay1;
			when delay1 =>
				if delay_i>0 then
					delay_i := delay_i -1;
				else
					pc := delay_retadr;
				end if;
				
			-- millis
			when millis0 =>
				millis_i := millis_millis;
				pc := millis1;
			when millis1 =>
				pc := delay0;
				delay_micros := 1000;
				if millis_i>0 then
					millis_i := millis_i-1;
					delay_retadr := millis1;
				else
					delay_retadr := millis_retadr;
				end if;
				
			end case;
		end if;

	   -- async logic: set output signals according to registers
--		DEBUG <= out_tx;
		if out_scl='0' then adv7513_scl <= '0'; else adv7513_scl <= 'Z'; end if; 
		if out_sda='0' then adv7513_sda <= '0'; else adv7513_sda <= 'Z'; end if; 
		resolution <= out_resolution;	
			
	end process;

--	
--	-- simple LED blinker with 1 1000th of the clock frequency	
--	process (clkpixel) 
--	variable x : std_logic := '0';
--	variable cnt : integer range 0 to 499;
--	
--	begin
--		if rising_edge(clkpixel) then
--			if cnt<499 then
--				cnt := cnt+1;
--			else 
--				cnt := 0;
--				x := not x;
--			end if;
--		end if;
--		
--		DEBUG1 <= x;
--	end process;

	process (DVID_VSYNC)	
	begin
			DEBUG1 <= DVID_VSYNC;
	end process;
	
end immediate;


