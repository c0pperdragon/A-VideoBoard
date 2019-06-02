create_clock -period 40.00 -name clkref [get_ports {CLK25}]
create_clock -period 120.000 -name clksync [get_registers {clkmulti|counter0[3]}]
derive_pll_clocks

