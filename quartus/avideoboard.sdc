create_clock -period 20.000 -name clk50 [get_ports {REFCLK}]
derive_pll_clocks
