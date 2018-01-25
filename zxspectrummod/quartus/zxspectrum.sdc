create_clock -period 40.000 -name clk25 [get_ports {CLKREF}]
derive_pll_clocks
