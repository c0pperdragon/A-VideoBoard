create_clock -period 40.000 -name clkref [get_ports {CLKREF}]
derive_pll_clocks
