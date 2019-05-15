library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity Settings is	
	port (
		-- reference clock
		CLK: in std_logic;		
		
		-- get notified when CPU writes into the registers
		WRITEADDR : in std_logic_vector(5 downto 0);
		WRITEDATA : in std_logic_vector(7 downto 0);
		WRITEEN : in std_logic;
		
		-- color palette conversion
		QUERYCOLOR : in std_logic_vector(3 downto 0);
		YPBPR : out std_logic_vector(14 downto 0);
		
		-- auxilary settings registers
		SUPPRESSSYNC : out std_logic
	);	
end entity;


architecture immediate of Settings is
	component ram_dual is
	generic
	(
		data_width : integer := 8;
		addr_width : integer := 16
	); 
	port 
	(
		data	: in std_logic_vector(data_width-1 downto 0);
		raddr	: in std_logic_vector(addr_width-1 downto 0);
		waddr	: in std_logic_vector(addr_width-1 downto 0);
		we		: in std_logic := '1';
		rclk	: in std_logic;
		wclk	: in std_logic;
		q		: out std_logic_vector(data_width-1 downto 0)
	);	
	end component;

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

	-- communicate with the ram
	signal ram_wrdata : std_logic_vector(14 downto 0);
	signal ram_wraddress : std_logic_vector(7 downto 0);
	signal ram_we : std_logic;
	
	-- communicate with the flash memory controller
	signal avmm_clock : std_logic;
--	signal avmm_csr_addr: std_logic;
--	signal avmm_csr_read: std_logic;
--	signal avmm_csr_writedata :  std_logic_vector(31 downto 0);
--	signal avmm_csr_write: std_logic;
--	signal avmm_csr_readdata: std_logic_vector(31 downto 0);
	signal avmm_data_addr:  std_logic_vector(11 downto 0) := "000000000000";
	signal avmm_data_read:  std_logic := '0';
--	signal avmm_data_writedata: std_logic_vector(31 downto 0);
--	signal avmm_data_write: std_logic;
	signal avmm_data_readdata: std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
--	signal avmm_data_waitrequest: std_logic;
	signal avmm_data_readdatavalid: std_logic := '1';  
--	signal avmm_data_burstcount: std_logic_vector(1 downto 0);
	signal reset_n : std_logic;
	
	

begin

	ram: ram_dual generic map(data_width => 15, addr_width => 8)
		port map (
			ram_wrdata,
			"0000" & QUERYCOLOR,
			ram_wraddress,
			ram_we,
			CLK,
			CLK,
			YPBPR	
		);

	flash : SETTINGSFLASH port map (
		avmm_clock, 
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
	
	
	------------------ manage user settings (colors and such) 
	process (CLK) 

	-- state machine to read startup-settings
	variable startdelay : integer range 0 to 100000 := 0;
	variable readcursor : integer range 0 to 31 := 0;
	variable readtick : integer range 0 to 3 := 0;
	variable requestingdata : boolean := false;
	variable waitfordata : boolean := false;
	
	-- modification selector and CPU action
	variable in_writeaddr : std_logic_vector(5 downto 0);
	variable in_writedata : std_logic_vector(7 downto 0);
	variable in_writeen : std_logic;
	
	variable auxflags : std_logic_vector(4 downto 0) :="00000";
			
	begin
		if rising_edge(CLK) then
			ram_we <= '0';
		
			-- initial startup-reset
			if startdelay<50000 then
				reset_n <= '0';
				readtick := 0;
				readcursor := 0;
				startdelay := startdelay+1;
			else
				reset_n <= '1';
			end if;			
			
			-- transfer settings into the ram
			if readcursor<17 then
				if readtick=1 then
					if waitfordata and avmm_data_readdatavalid='1' then
						waitfordata := false;
						ram_wraddress <= std_logic_vector(to_unsigned(readcursor,8));
						ram_wrdata <= 
							avmm_data_readdata(12 downto 8)
						 & avmm_data_readdata(20 downto 16)
						 & avmm_data_readdata(28 downto 24);
						if readcursor=16 then
							SUPPRESSSYNC <= avmm_data_readdata(0);
						end if;
						ram_we <= '1';
						readcursor := readcursor+1;
					elsif not requestingdata then
						requestingdata := true;
					else
						requestingdata := false;
						waitfordata := true;
					end if;
				elsif readtick=2 then
					if requestingdata then
						avmm_data_addr <= std_logic_vector(to_unsigned(readcursor,12));
						avmm_data_read <= '1';
					else
						avmm_data_read <= '0';
					end if;
				end if;
			end if;
			
			-- generate lower speed clock to access the flash
			case readtick is
			when 0 =>	readtick := 1;
			when 1 =>	readtick := 2;
							avmm_clock <= '1';
			when 2 =>	readtick := 3;
			when 3 =>	readtick := 0;
							avmm_clock <= '0';
			end case;

			-- CPU wants to write into registers 
			if in_writeen='1' then  
				case to_integer(unsigned(in_writeaddr)) is 
					when 60 => 
						ram_wrdata(14 downto 10) <= in_writedata(4 downto 0);
					when 61 => 
						ram_wrdata(9 downto 5) <= in_writedata(4 downto 0);
					when 62 => 
						ram_wrdata(4 downto 0) <= in_writedata(4 downto 0);
					when 63 => 
						ram_wraddress <= in_writedata;
						ram_we <= '1';					
						if in_writedata = "00010000" then
							SUPPRESSSYNC <= ram_wrdata(10);
						end if;
					when others => null;
				end case;
			end if;		
			
			-- take signals into registers
			in_writeaddr := WRITEADDR;
			in_writedata := WRITEDATA;
			in_writeen := WRITEEN;
		end if;	
	
	end process;
	
end immediate;

