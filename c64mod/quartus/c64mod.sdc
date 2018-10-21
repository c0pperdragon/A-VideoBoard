create_clock -period 40.00 -name clkref [get_ports {CLK25}]
derive_pll_clocks

