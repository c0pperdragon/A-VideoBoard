create_clock -period 40.00 -name clkref [get_ports {CLK25}]
create_clock -period 21.000 -name clkpixel6 [get_registers {counter[2]}]
derive_pll_clocks
