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
		
		-- additional inputs from the ZX Spectrum
		ZX_D     : in std_logic_vector(7 downto 0);
		ZX_CAS   : in std_logic;
		ZX_IOREQ : in std_logic;
		ZX_WR    : in std_logic		
	);	
end entity;


architecture immediate of ZXSpectrumMod is
	
   component PLL is
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
	end component;

	signal CLK224 : std_logic;
	signal CLKPIXEL : std_logic;
--	signal CLK8 : std_logic;	


begin		
	-- internally create a high frequency to derive everything else from
	highfrequency: PLL port map ( CLKREF, CLK224 );

	-- regenerate the 7 mhz pixel clock from the partially available cpu clock
	process (CLK224)
	variable in_cpu : std_logic;
	variable prev_cpu : std_logic;
	
	variable cnt: integer range 0 to 31 := 0;	
	variable tmp_cnt: std_logic_vector(4 downto 0);
	variable out_clkpixel : std_logic := '0';
	begin
		if rising_edge(CLK224) then
			tmp_cnt := std_logic_vector(to_unsigned(cnt,5));
			out_clkpixel := tmp_cnt(4);			
			
			if in_cpu='1' and prev_cpu='0' then
				cnt := 17;
			else
				cnt := cnt+1;			
			end if;
			
			prev_cpu := in_cpu;
			in_cpu := CPUCLK;						
		end if;
		CLKPIXEL <= out_clkpixel;
	end process;
	
	
	
	process (CLKPIXEL) 
	
	constant black:  integer := 16#4e10#;
	constant blue:   integer := 16#5ecd#;
	constant red:    integer := 16#815f#;
	constant purple: integer := 16#7297#;
	constant green:  integer := 16#8d47#;
	constant cyan:   integer := 16#caa0#;
	constant yellow: integer := 16#d834#;
	constant white:  integer := 16#fe10#;
	
	variable in_sync:  std_logic := '0';
	variable in_bright: std_logic := '0';
	variable in_upos:  std_logic := '0';
	variable in_uneg:  std_logic := '0';
	variable in_vpos:  std_logic := '0';
	variable in_vneg:  std_logic := '0';

	variable cnt: integer range 0 to 1023 := 0;
	variable syncdetected: boolean := false;
	variable even : boolean := false;
		
	variable out_col: integer range 0 to 65535;
	variable tmp_col: std_logic_vector(15 downto 0);
	
	begin
		if rising_edge(CLKPIXEL) then

		   -- compute outgoing signals
			if syncdetected then
				if cnt < 21 or in_sync='1' then
					out_col := 0 + 16*32 + 16;  -- sync
				else
					out_col := black;
				end if;
			else
				if in_vneg='1' then           -- left table column
					if even then
						if in_upos='1' then
							out_col := green;
						else
							out_col := cyan; 
						end if;
					else
						if in_uneg='1' then
							out_col := purple;
						else
							out_col := red; 
						end if;
					end if;
				elsif in_vpos='1' then         -- right table column
					if even then
						if in_uneg='1' then
							out_col := purple;
						else
							out_col := red; 
						end if;
					else
						if in_upos='1' then
							out_col := green;
						else
							out_col := cyan; 
						end if;
					end if;
				else                           -- middle table column
					if in_upos='1' then
						out_col := yellow;
					elsif in_uneg='1' then
						out_col := blue;
					else					
						if in_bright='1' then
							out_col := white;
						else
							out_col := black;
						end if;			
					end if;				
				end if;			
			end if;
					
			-- progress counters and state machine --
			if syncdetected then
				if cnt < 67 then
					cnt := cnt+1;
				elsif in_sync='0' then
					syncdetected := false;
				elsif cnt<1023 then
					cnt := cnt+1;
				end if;
			else
				if in_sync='1' then
					syncdetected := true;
					cnt := 0;
					even := not even;
				elsif cnt > 700 then
					even := false;
				end if;
			end if;
			
			in_bright := BRIGHT;
			in_upos := UPOS;
			in_uneg := UNEG;
			in_vpos := VPOS;
			in_vneg := VNEG;
		end if;

		if falling_edge(CLKPIXEL) then
			in_sync := SYNC;		
		end if;
		
		tmp_col := std_logic_vector(to_unsigned(out_col, 16));		
		Y  <= tmp_col(15 downto 10);
		Pb <= tmp_col(9 downto 5);
		Pr <= tmp_col(4 downto 0);
	end process;

end immediate;

