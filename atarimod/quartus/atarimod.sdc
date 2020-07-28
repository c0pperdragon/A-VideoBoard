create_clock -period 40.000 -name clk25 [get_ports {CLK25}]
create_clock -period 70.000 -name clksync [get_registers {ClockMultiplier:multi|counter0[3]}]
derive_pll_clocks

