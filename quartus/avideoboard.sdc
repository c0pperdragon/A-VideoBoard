create_clock -period 20.000 -name clkref [get_ports {CLKREF}]
derive_pll_clocks
