#*****************************************************************************************
# Vivado (TM) v2023.1 (64-bit)
# ether_adxl_project.tcl: Re-create project with global VHDL-2008 and targeted/filtered XDC
#*****************************************************************************************

set origin_dir "."
set _xil_proj_name_ "ether_adxl_project"

# 1. Create project
create_project ${_xil_proj_name_} ./${_xil_proj_name_} -part xc7a35ticsg324-1L
set obj [current_project]
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj

# 2. Add HDL Sources
add_files -norecurse {
  ./hdl/spi_master/spi_master.vhd
  ./hdl/adxl_controller/adxl345_controller.vhd
  ./hdl/adxl_top/adxl_top.vhd
  ./hdl/adxl_top/top_adxl_debug.vhd
  ./hdl/frame_gen/frame_gen.vhd
  ./hdl/frame_gen/frame_gen_debug.vhd
  ./hdl/mii_phy/crc.vhd
  ./hdl/mii_phy/mii_phy.vhd
  ./hdl/top_eth/top_eth.vhd
  ./hdl/top_eth/top_eth_debug.vhd
  ./hdl/uart/uart_tx.vhd
  ./hdl/top_system/TOP_system.vhd
}

# 3. Add Simulation Files
add_files -fileset sim_1 -norecurse {
  ./sim/tb_frame_gen.vhd
  ./sim/tb_mii_phy.vhd
  ./sim/tb_frame_gen_debug.vhd
  ./sim/tb_top_adxl.vhd
  ./sim/tb_spi_master.vhd
}

# Set ALL VHDL files (Sources + Sim) to VHDL-2008
set_property file_type "VHDL 2008" [get_files *.vhd]

# 4. Add IP
import_ip ./ip/clk_wiz_0/clk_wiz_0.xci

# 5. Add Constraints
add_files -fileset constrs_1 -norecurse {
  ./constraints/arty_a7_adxl_debug.xdc
  ./constraints/arty_eth_only.xdc
  ./constraints/arty_a7_TOP.xdc
}

# Set arty_a7_TOP as the primary target for implementation
set_property target_constrs_file [get_files ./constraints/arty_a7_TOP.xdc] [get_filesets constrs_1]

# Disable secondary debug constraints to avoid conflicts
set_property is_enabled false [get_files ./constraints/arty_a7_adxl_debug.xdc]
set_property is_enabled false [get_files ./constraints/arty_eth_only.xdc]

# 6. Set Top Level
set_property "top" "top_system" [get_filesets sources_1]

puts "INFO: Project created successfully."
puts "INFO: Every .vhd file set to VHDL-2008."
puts "INFO: Target constraints set to arty_a7_TOP.xdc (Debug XDCs disabled)."