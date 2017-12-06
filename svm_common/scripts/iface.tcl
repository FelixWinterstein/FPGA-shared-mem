#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: iface.tcl
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------

package require -exact qsys 16.0

load_system iface/acl_iface_system.qsys

# create a AXI cache security bridge instance
add_instance AXI_cache_secruity_bridge_0 AXI_cache_secruity_bridge 1.0
set_instance_parameter_value AXI_cache_secruity_bridge_0 {ADDRESS_WIDTH} {32}
set_instance_parameter_value AXI_cache_secruity_bridge_0 {DATA_WIDTH} {128}
set_instance_parameter_value AXI_cache_secruity_bridge_0 {AXUSER_WIDTH} {5}
set_instance_parameter_value AXI_cache_secruity_bridge_0 {ID_WIDTH} {2}

# create a lock server instance
add_instance lock_server_0 lock_server 1.0

# create a clock domain crossing for avm mm
add_instance svm_avalon_clock_crossing altera_avalon_mm_clock_crossing_bridge
#set_instance_parameter_value svm_avalon_clock_crossing USE_AUTO_ADDRESS_WIDTH 1
set_instance_parameter_value svm_avalon_clock_crossing {DATA_WIDTH} {128}
set_instance_parameter_value svm_avalon_clock_crossing {SYMBOL_WIDTH} {8}
set_instance_parameter_value svm_avalon_clock_crossing {ADDRESS_WIDTH} {10}
set_instance_parameter_value svm_avalon_clock_crossing {USE_AUTO_ADDRESS_WIDTH} {1}
set_instance_parameter_value svm_avalon_clock_crossing {ADDRESS_UNITS} {SYMBOLS}
set_instance_parameter_value svm_avalon_clock_crossing {MAX_BURST_SIZE} {16}
set_instance_parameter_value svm_avalon_clock_crossing {COMMAND_FIFO_DEPTH} {32}
set_instance_parameter_value svm_avalon_clock_crossing {RESPONSE_FIFO_DEPTH} {32}
set_instance_parameter_value svm_avalon_clock_crossing {MASTER_SYNC_DEPTH} {2}
set_instance_parameter_value svm_avalon_clock_crossing {SLAVE_SYNC_DEPTH} {2}

# create a clock domain crossing for avm mm
add_instance lock_server_avalon_clock_crossing altera_avalon_mm_clock_crossing_bridge
#set_instance_parameter_value lock_server_avalon_clock_crossing USE_AUTO_ADDRESS_WIDTH 1
set_instance_parameter_value lock_server_avalon_clock_crossing {DATA_WIDTH} {128}
set_instance_parameter_value lock_server_avalon_clock_crossing {SYMBOL_WIDTH} {8}
set_instance_parameter_value lock_server_avalon_clock_crossing {ADDRESS_WIDTH} {10}
set_instance_parameter_value lock_server_avalon_clock_crossing {USE_AUTO_ADDRESS_WIDTH} {1}
set_instance_parameter_value lock_server_avalon_clock_crossing {ADDRESS_UNITS} {SYMBOLS}
set_instance_parameter_value lock_server_avalon_clock_crossing {MAX_BURST_SIZE} {16}
set_instance_parameter_value lock_server_avalon_clock_crossing {COMMAND_FIFO_DEPTH} {32}
set_instance_parameter_value lock_server_avalon_clock_crossing {RESPONSE_FIFO_DEPTH} {32}
set_instance_parameter_value lock_server_avalon_clock_crossing {MASTER_SYNC_DEPTH} {2}
set_instance_parameter_value lock_server_avalon_clock_crossing {SLAVE_SYNC_DEPTH} {2}


# enable f2hps port with 32 bits
set_instance_parameter_value hps {F2S_Width} {3}

# connect AXI cache security bridge axi master to F2H port of HPS
add_connection AXI_cache_secruity_bridge_0.axi_master hps.f2h_axi_slave
set_connection_parameter_value AXI_cache_secruity_bridge_0.axi_master/hps.f2h_axi_slave arbitrationPriority {1}
set_connection_parameter_value AXI_cache_secruity_bridge_0.axi_master/hps.f2h_axi_slave baseAddress {0x0000}
set_connection_parameter_value AXI_cache_secruity_bridge_0.axi_master/hps.f2h_axi_slave defaultConnection {0}

# connect AXI cache security bridge csr slave to mm_bridge_0 (shared lightweight H2F port)
add_connection mm_bridge_0.m0 AXI_cache_secruity_bridge_0.avalon_csr_slave
set_connection_parameter_value mm_bridge_0.m0/AXI_cache_secruity_bridge_0.avalon_csr_slave arbitrationPriority {1}
set_connection_parameter_value mm_bridge_0.m0/AXI_cache_secruity_bridge_0.avalon_csr_slave baseAddress {0x0100}
set_connection_parameter_value mm_bridge_0.m0/AXI_cache_secruity_bridge_0.avalon_csr_slave defaultConnection {0}

# connect AXI cache security bridge axi slave to to svm_avalon_clock_crossing
add_connection svm_avalon_clock_crossing.m0 AXI_cache_secruity_bridge_0.axi_slave
set_connection_parameter_value svm_avalon_clock_crossing.m0/AXI_cache_secruity_bridge_0.axi_slave arbitrationPriority {1}
set_connection_parameter_value svm_avalon_clock_crossing.m0/AXI_cache_secruity_bridge_0.axi_slave baseAddress {0x0000}
set_connection_parameter_value svm_avalon_clock_crossing.m0/AXI_cache_secruity_bridge_0.axi_slave defaultConnection {0}

# connect lock server csr slave to mm_bridge_0 (shared lightweight H2F port)
add_connection mm_bridge_0.m0 lock_server_0.avalon_csr_slave
set_connection_parameter_value mm_bridge_0.m0/lock_server_0.avalon_csr_slave arbitrationPriority {1}
set_connection_parameter_value mm_bridge_0.m0/lock_server_0.avalon_csr_slave baseAddress {0x0000}
set_connection_parameter_value mm_bridge_0.m0/lock_server_0.avalon_csr_slave defaultConnection {0}

# connect lock server avalon csr slave to to lock_server_avalon_clock_crossing
add_connection lock_server_avalon_clock_crossing.m0 lock_server_0.avalon_csr_slave
set_connection_parameter_value lock_server_avalon_clock_crossing.m0/lock_server_0.avalon_csr_slave arbitrationPriority {1}
set_connection_parameter_value lock_server_avalon_clock_crossing.m0/lock_server_0.avalon_csr_slave baseAddress {0x0000}
set_connection_parameter_value lock_server_avalon_clock_crossing.m0/lock_server_0.avalon_csr_slave defaultConnection {0}

# connect clocks
add_connection config_clk.out_clk hps.f2h_axi_clock
add_connection config_clk.out_clk svm_avalon_clock_crossing.m0_clk
add_connection acl_kernel_clk.kernel_clk svm_avalon_clock_crossing.s0_clk
add_connection config_clk.out_clk lock_server_avalon_clock_crossing.m0_clk
add_connection acl_kernel_clk.kernel_clk lock_server_avalon_clock_crossing.s0_clk
add_connection config_clk.out_clk AXI_cache_secruity_bridge_0.clock
add_connection config_clk.out_clk lock_server_0.clock

# connect resets
add_connection kernel_interface.kernel_reset svm_avalon_clock_crossing.s0_reset
add_connection global_reset.out_reset svm_avalon_clock_crossing.m0_reset
add_connection kernel_interface.kernel_reset lock_server_avalon_clock_crossing.s0_reset
add_connection global_reset.out_reset lock_server_avalon_clock_crossing.m0_reset
add_connection global_reset.out_reset AXI_cache_secruity_bridge_0.reset_sink
add_connection global_reset.out_reset lock_server_0.reset_sink


# export slave port of the svm port clock crossing as an interface of acl_iface_system
add_interface svm_avalon_clock_crossing_s0 avalon slave
set_interface_property svm_avalon_clock_crossing_s0 EXPORT_OF svm_avalon_clock_crossing.s0

# export slave port of the lock server clock crossing as an interface of acl_iface_system
add_interface lock_server_avalon_clock_crossing_s0 avalon slave
set_interface_property lock_server_avalon_clock_crossing_s0 EXPORT_OF lock_server_avalon_clock_crossing.s0

save_system
