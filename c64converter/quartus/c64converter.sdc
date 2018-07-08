create_clock -period 12.500 -name clkadc [get_ports {CLKADC}]
derive_pll_clocks
