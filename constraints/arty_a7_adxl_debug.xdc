set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {leds[0]}] 
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {leds[1]}] 
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {leds[2]}] 
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {leds[3]}] 

set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports reset_n]


set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_tx_pin]


set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports ja_sclk] 
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports ja_mosi]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports ja_miso]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports ja_cs]