create_clock -period 10.00 -name clkref [get_ports {CLK100}]
create_clock -period 125.0 -name pixelclock [get_registers {out_clock}]


