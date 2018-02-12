create_clock -period 282.000 -name clkatari [get_ports {GPIO1[19]}]
create_clock -period 40.000 -name clk25 [get_ports {CLK25}]
derive_pll_clocks
