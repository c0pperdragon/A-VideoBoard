library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
package Settings_pkg is
	type t_palette is array(0 to 15) of std_logic_vector(14 downto 0);
end package;


library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.Settings_pkg.all;

entity Settings is	
	port (
		-- reference clock
		CLK25: in std_logic;		
		
		-- get notified when CPU writes into the registers
		WRITEADDR : in std_logic_vector(5 downto 0);
		WRITEDATA : in std_logic_vector(7 downto 0);
		WRITEEN : in std_logic;
		
		-- settings output signals
		PALETTE: out t_palette
	);	
end entity;


architecture immediate of Settings is
	-- communicate with the flash memory controller
	signal CLK6_25 : std_logic;
--	signal avmm_csr_addr: std_logic;
--	signal avmm_csr_read: std_logic;
--	signal avmm_csr_writedata :  std_logic_vector(31 downto 0);
--	signal avmm_csr_write: std_logic;
--	signal avmm_csr_readdata: std_logic_vector(31 downto 0);
	signal avmm_data_addr:  std_logic_vector(11 downto 0) := "000000000000";
	signal avmm_data_read:  std_logic := '0';
--	signal avmm_data_writedata: std_logic_vector(31 downto 0);
--	signal avmm_data_write: std_logic;
	signal avmm_data_readdata: std_logic_vector(31 downto 0);
--	signal avmm_data_waitrequest: std_logic;
	signal avmm_data_readdatavalid: std_logic;  
--	signal avmm_data_burstcount: std_logic_vector(1 downto 0);
	signal reset_n : std_logic;
	

	component SETTINGSFLASH is
	port (
		clock                   : in  std_logic                     := '0';             --    clk.clk
		avmm_csr_addr           : in  std_logic                     := '0';             --    csr.address
		avmm_csr_read           : in  std_logic                     := '0';             --       .read
		avmm_csr_writedata      : in  std_logic_vector(31 downto 0) := (others => '0'); --       .writedata
		avmm_csr_write          : in  std_logic                     := '0';             --       .write
		avmm_csr_readdata       : out std_logic_vector(31 downto 0);                    --       .readdata
		avmm_data_addr          : in  std_logic_vector(11 downto 0) := (others => '0'); --   data.address
		avmm_data_read          : in  std_logic                     := '0';             --       .read
		avmm_data_writedata     : in  std_logic_vector(31 downto 0) := (others => '0'); --       .writedata
		avmm_data_write         : in  std_logic                     := '0';             --       .write
		avmm_data_readdata      : out std_logic_vector(31 downto 0);                    --       .readdata
		avmm_data_waitrequest   : out std_logic;                                        --       .waitrequest
		avmm_data_readdatavalid : out std_logic;                                        --       .readdatavalid
		avmm_data_burstcount    : in  std_logic_vector(1 downto 0)  := (others => '0'); --       .burstcount
		reset_n                 : in  std_logic                     := '0'              -- nreset.reset_n
	);
	end component;	

begin

	flash : SETTINGSFLASH port map (
		CLK6_25, 
		'0', -- avmm_csr_addr           : in  std_logic
		'0', -- avmm_csr_read           : in  std_logic
		"00000000000000000000000000000000", -- avmm_csr_writedata      : in  std_logic_vector(31 downto 0) 
		'0', -- avmm_csr_write          : in  std_logic   
		open, -- avmm_csr_readdat       : out std_logic_vector(31 downto 0)
		avmm_data_addr,        --       : in  std_logic_vector(11 downto 0) := (others => '0'); --   data.address
		avmm_data_read,        --       : in  std_logic                     := '0';             --       .read
		"00000000000000000000000000000000", -- avmm_data_writedata     : in  std_logic_vector(31 downto 0) := (others => '0'); --       .writedata
		'0', -- avmm_data_write         : in  std_logic                     := '0';             --       .write
		avmm_data_readdata,    --       : out std_logic_vector(31 downto 0);                    --       .readdata
		open, -- avmm_data_waitrequest   : out std_logic;                                        --       .waitrequest
		avmm_data_readdatavalid,  --     : out std_logic;                                        --       .readdatavalid
		"01", -- avmm_data_burstcount    : in  std_logic_vector(1 downto 0)  := (others => '0'); --       .burstcount
		reset_n        --                : in  std_logic                     := '0'              -- nreset.reset_n
	);
	
	--- divide refernce clock to get a slower clock for the flash memory controller
	process (CLK25)
		variable counter : std_logic_vector(1 downto 0) := "00";
	begin
		if rising_edge(CLK25) then		
			counter := std_logic_vector(unsigned(counter)+1);
		end if;
		CLK6_25 <= counter(1);
	end process;
	
	
	------------------ manage user settings (colors and such) 
	process (CLK6_25) 
	type T_settings is array (0 to 47) of std_logic_vector(4 downto 0);
	variable settings : T_settings := ( others => "00000" ); 

	-- state machine to read startup-settings
	variable startdelay : integer range 0 to 100000 := 0;
	variable readcursor : integer range 0 to 16 := 0;
	variable readtick : integer range 0 to 7 := 0;	
	
	-- modification selector and CPU action
	variable selected : integer range 0 to 15 := 1;
	variable in_writeaddr : std_logic_vector(5 downto 0);
	variable in_writedata : std_logic_vector(7 downto 0);
	variable in_writeen : std_logic;
	
	-- temporary flags to write to registers 
	variable regwriteaddr : integer range 0 to 63;
	variable regwritedata : std_logic_vector(4 downto 0);
	variable laterwritedata : std_logic_vector(9 downto 0);
		
	begin
		if rising_edge(CLK6_25) then
			regwriteaddr := 63;  -- not writing to any register yet
			regwritedata := "00000";		
		
			-- read boot-up settings
			if startdelay<100000 then
				if startdelay<50000 then
					reset_n <= '0';
				else
					reset_n <= '1';
				end if;
				startdelay := startdelay+1;
			elsif readcursor<16 then
				case readtick is
				when 0 => 
					readtick:=1;
				when 1 => 
					readtick:=2;
				when 2 => 
					readtick := 3;
				when 3 =>
					readtick := 4;
				when 4 =>
					avmm_data_addr <= std_logic_vector(to_unsigned(readcursor,12));
					avmm_data_read <= '1';
					readtick := 5;
				when 5 =>
					avmm_data_read <= '0';
					if avmm_data_readdatavalid='1' then
						regwriteaddr := readcursor*3;
						regwritedata := avmm_data_readdata(12 downto 8);
						laterwritedata := avmm_data_readdata(20 downto 16) & avmm_data_readdata(28 downto 24);
						readtick := 6;
					end if;
				when 6 =>
					regwriteaddr := readcursor*3+1;
					regwritedata := laterwritedata(9 downto 5);				
					readtick := 7;					
				when 7 => 
					regwriteaddr := readcursor*3+2;
					regwritedata := laterwritedata(4 downto 0);				
					readtick:=0;
					readcursor := readcursor+1;
				end case;
			end if;
		
			-- monitor when the CPU writes into registers 
			if in_writeen='1' then  
				case to_integer(unsigned(in_writeaddr)) is 
					when 60 => 
						regwriteaddr := selected*3;
						regwritedata := in_writedata(4 downto 0);					
					when 61 => 
						regwriteaddr := selected*3 + 1;
						regwritedata := in_writedata(4 downto 0);					
					when 62 => 
						regwriteaddr := selected*3 + 2;
						regwritedata := in_writedata(4 downto 0);					
					when 63 => 
						selected := to_integer(unsigned(in_writedata(3 downto 0)));
					when others => null;
				end case;
			end if;		
			
			-- finally transfer data to register
			if regwriteaddr<48 then
				settings(regwriteaddr) := regwritedata;
			end if;
			
			-- take signals into registers
			in_writeaddr := WRITEADDR;
			in_writedata := WRITEDATA;
			in_writeen := WRITEEN;
		end if;	
	
		-- generate palette signals from registers 
		palette(0) <= "000001000010000";
		palette(1) <= settings(3) & settings(4) & settings(5);
		palette(2) <= settings(6) & settings(7) & settings(8);
		palette(3) <= settings(9) & settings(10) & settings(11);
		palette(4) <= settings(12) & settings(13) & settings(14);
		palette(5) <= settings(15) & settings(16) & settings(17);
		palette(6) <= settings(18) & settings(19) & settings(20);
		palette(7) <= settings(21) & settings(22) & settings(23);
		palette(8) <= settings(24) & settings(25) & settings(26);
		palette(9) <= settings(27) & settings(28) & settings(29);
		palette(10) <= settings(30) & settings(31) & settings(32);
		palette(11) <= settings(33) & settings(34) & settings(35);
		palette(12) <= settings(36) & settings(37) & settings(38);
		palette(13) <= settings(39) & settings(40) & settings(41);
		palette(14) <= settings(42) & settings(43) & settings(44);
		palette(15) <= settings(45) & settings(46) & settings(47);
	end process;
	
end immediate;

