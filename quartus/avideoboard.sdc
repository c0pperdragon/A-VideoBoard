create_clock -period 20.000 -name clk50 [get_ports {CLK50}]
derive_pll_clocks
