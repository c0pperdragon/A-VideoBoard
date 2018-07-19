create_clock -period 40.00 -name clkref [get_ports {CLK25}]
create_clock -period 20.000 -name clkpixel6 [get_registers {out_clk}]
derive_pll_clocks
