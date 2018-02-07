create_clock -period 100.000 -name clkatari [get_ports {GPIO1(2)}]
derive_pll_clocks
