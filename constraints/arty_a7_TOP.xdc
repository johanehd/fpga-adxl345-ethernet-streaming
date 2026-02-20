set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk_100M]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk_100M]


# reset_btn BTN0 (D9)
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports reset_btn]


set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {leds[0]}] 
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {leds[1]}] 
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {leds[2]}] 
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {leds[3]}] 

## ADXL345 SPI (Pmod JA)
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports ja_sclk] 
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports ja_mosi]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports ja_miso]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports ja_cs]

## ethernet PHY (MII interface)
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports eth_ref_clk]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports eth_rstn]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports eth_tx_en]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {eth_txd[0]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {eth_txd[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {eth_txd[2]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {eth_txd[3]}]