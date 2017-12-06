#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: lock_server_hw
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------

# 
# request TCL package from ACDS 16.0
# 
package require -exact qsys 16.0


# 
# module AXI_cache_secruity_bridge
# 
set_module_property DESCRIPTION ""
set_module_property NAME lock_server
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR FW
set_module_property DISPLAY_NAME "Lock Server"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false

set_module_property VALIDATION_CALLBACK validate_me

# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL lock_server
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file lock_server.vhd VHDL PATH lock_server.vhd TOP_LEVEL_FILE


add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL lock_server
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file lock_server.vhd VERILOG PATH lock_server.vhd TOP_LEVEL_FILE

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL lock_server
set_fileset_property SIM_VHDL ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VHDL ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file lock_server.vhd VERILOG PATH lock_server.vhd TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter NUMBER_OF_HOST_THREADS INTEGER 1 "Number of host supported threads"
set_parameter_property NUMBER_OF_HOST_THREADS DEFAULT_VALUE 1
set_parameter_property NUMBER_OF_HOST_THREADS DISPLAY_NAME "Number of host threads"
set_parameter_property NUMBER_OF_HOST_THREADS TYPE INTEGER
set_parameter_property NUMBER_OF_HOST_THREADS UNITS None
set_parameter_property NUMBER_OF_HOST_THREADS ALLOWED_RANGES 1:1
set_parameter_property NUMBER_OF_HOST_THREADS DESCRIPTION "Number of host supported threads"
set_parameter_property NUMBER_OF_HOST_THREADS HDL_PARAMETER true

add_parameter NUMBER_OF_DEVICE_THREADS INTEGER 1 "Number of device supported threads"
set_parameter_property NUMBER_OF_DEVICE_THREADS DEFAULT_VALUE 1
set_parameter_property NUMBER_OF_DEVICE_THREADS DISPLAY_NAME "Number of device threads"
set_parameter_property NUMBER_OF_DEVICE_THREADS TYPE INTEGER
set_parameter_property NUMBER_OF_DEVICE_THREADS UNITS None
set_parameter_property NUMBER_OF_DEVICE_THREADS ALLOWED_RANGES 1:1
set_parameter_property NUMBER_OF_DEVICE_THREADS DESCRIPTION "Number of device supported threads"
set_parameter_property NUMBER_OF_DEVICE_THREADS HDL_PARAMETER true

# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1



# 
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink CMSIS_SVD_VARIABLES ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""

add_interface_port reset_sink resetn reset_n Input 1


# 
# connection point avalon_csr_slave
# 
add_interface avalon_csr_slave avalon end
set_interface_property avalon_csr_slave addressUnits WORDS
set_interface_property avalon_csr_slave associatedClock clock
set_interface_property avalon_csr_slave associatedReset reset_sink
set_interface_property avalon_csr_slave bitsPerSymbol 8
set_interface_property avalon_csr_slave burstOnBurstBoundariesOnly false
set_interface_property avalon_csr_slave burstcountUnits WORDS
set_interface_property avalon_csr_slave explicitAddressSpan 0
set_interface_property avalon_csr_slave holdTime 0
set_interface_property avalon_csr_slave linewrapBursts false
set_interface_property avalon_csr_slave maximumPendingReadTransactions 1
set_interface_property avalon_csr_slave maximumPendingWriteTransactions 0
set_interface_property avalon_csr_slave readLatency 0
set_interface_property avalon_csr_slave readWaitTime 0
set_interface_property avalon_csr_slave setupTime 0
set_interface_property avalon_csr_slave timingUnits Cycles
set_interface_property avalon_csr_slave ENABLED true
set_interface_property avalon_csr_slave EXPORT_OF ""
set_interface_property avalon_csr_slave PORT_NAME_MAP ""
set_interface_property avalon_csr_slave CMSIS_SVD_VARIABLES ""
set_interface_property avalon_csr_slave SVD_ADDRESS_GROUP ""

add_interface_port avalon_csr_slave csr_address address Input 3
add_interface_port avalon_csr_slave csr_write write Input 1
add_interface_port avalon_csr_slave csr_read read Input 1
add_interface_port avalon_csr_slave csr_writedata writedata Input 32
add_interface_port avalon_csr_slave csr_byteenable byteenable Input 4
add_interface_port avalon_csr_slave csr_readdata readdata Output 32
add_interface_port avalon_csr_slave csr_waitrequest waitrequest Output 1
add_interface_port avalon_csr_slave csr_readdatavalid readdatavalid Output 1
set_interface_assignment avalon_csr_slave embeddedsw.configuration.isFlash 0
set_interface_assignment avalon_csr_slave embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avalon_csr_slave embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avalon_csr_slave embeddedsw.configuration.isPrintableDevice 0

proc validate_me {}  {
  if { ([get_parameter_value NUMBER_OF_HOST_THREADS] > 1) || ([get_parameter_value NUMBER_OF_HOST_THREADS] < 1) }  {
    send_message Error "The currently supported number of host threads is 1."
  }
  
  if { ([get_parameter_value NUMBER_OF_DEVICE_THREADS] > 1) || ([get_parameter_value NUMBER_OF_DEVICE_THREADS] < 1) }  {
    send_message Error "The currently supported number of device threads is 1."
  }  

}
