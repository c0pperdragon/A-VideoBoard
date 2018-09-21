create_clock -period 40.00 -name clkref [get_ports {CLK25}]
create_clock -period 10.50 -name clk12th [get_registers {counter[1]}]
create_clock -period 125.0 -name clkpixel [get_registers {out_clkpixel}]
derive_pll_clocks
