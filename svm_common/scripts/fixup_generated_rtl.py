#!/usr/bin/env python

#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: fixup_generated_rtl.py
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------


import argparse
import os
import sys
import subprocess
import shutil
import hashlib
import re

debug = True

SVM_DATA_WIDTH = 128
SVM_ADDR_WIDTH = 32
SVM_BYTEENABLE_WIDTH = 16
SVM_BURSTCOUNT_WIDTH = 5
AVM_PORTS_PER_LSU = 3

# parse all kernel modules in the generated RTL file
def getKernels(project):
    kernels = []
    with open(os.path.join(project, project + '.v'), 'r') as handle:
        lines = handle.readlines()

    for line in lines:
        if line.startswith('module') and line.rstrip().endswith('_sys_cycle_time'):
            kernel_name = re.match('.*\s*module\s*([A-Za-z_0-9]*?)_sys_cycle_time', line, re.S|re.I)
            kernels.append(kernel_name.group(1))

    handle.close()
    return kernels


# return all ports of an avm bus
def getAvmSubPorts():
    avm_subports = [ ("output","enable",0), ("output","read",0), ("output","write",0), ("output","burstcount",SVM_BURSTCOUNT_WIDTH), ("output","address",SVM_ADDR_WIDTH ), ("output","writedata",SVM_DATA_WIDTH),
                     ("output","byteenable",SVM_BYTEENABLE_WIDTH), ("input","waitrequest",0), ("input","readdata",SVM_DATA_WIDTH), ("input","readdatavalid",0), ("input","writeack",0)]

    return avm_subports


# modify the ..._system.v file
def modifyKernelSystemVerilogFile(project,kernels):

    with open(os.path.join(project, project + '_system.v'), 'r') as handle:
        lines = handle.readlines()

    if debug:
        print "File opened for parsing %r" % handle

    new_lines = []

    total_num_lsus = 0
    total_num_lsus_atomic = 0

    for kernel in kernels:
        new_lines = []
        in_module = 0
        in_port_list = 0
        in_component = 0
        num_lsus = 0
        num_lsus_atomic = 0
        prev_line = ""        
        # iterate over lines
        for line in lines:             
            if re.match('\s*module\s*{0}_system\s*\n'.format(project), line, re.S) != None:
                in_module=1
            if in_module == 1 and re.match('\s*endmodule\s*\n', line, re.S) != None:
                inmodule=0
            if in_module == 1 and re.match('\s*{0}_top_wrapper\s+{0}\s*\n'.format(kernel), line, re.S) != None:
                in_component=1
            if in_component == 1 and re.match('\s*\);\s*\n', line, re.S) != None:
                in_component=0
            # FIXME: re-include lock service ports
            if in_component == 1 and re.match('\s*\.avm_efi_{0}_[0-9]+_host_memory_bridge_[a-z]+_?[a-z]*_[0-9]+bit_host_memory_bridge_?[a-z]*_a0b1c2d3_[a-z]+_[0-9]+bit_[0-9]+_inst0_enable.+\n'.format(kernel), line, re.S) != None:                
                num_lsus = num_lsus + 1
            # if in_component == 1 and re.match('\s*\.avm_efi_{0}_[0-9]+_host_memory_bridge_[a-z]+_?[a-z]*_[0-9]+bit_host_memory_bridge_?[a-z]*_a0b1c2d3_[a-z]+_[0-9]+bit_1_inst0_enable.+\n'.format(kernel), line, re.S) != None:                
                # num_lsus_atomic = num_lsus_atomic + 1

        if debug:
            print "Number of SVM LSU instantiations in kernel %s: %d" % (kernel,num_lsus)
            print "Number of atomic SVM LSU instantiations in kernel %s: %d" % (kernel,num_lsus_atomic)
        
        in_module = 0
        in_port_list = 0
        in_body = 0
        hit_first_blank_line_of_body = 0
        in_component = 0
        in_lsu_ic_top_genericmap = 0
        prev_line = ""
        # iterate over lines again
        for line in lines: 
            if re.match('\s*module\s*{0}_system\s*\n'.format(project), line, re.S) != None:
                in_module=1
            if in_module == 1 and re.match('\s*endmodule\s*\n', line, re.S) != None:
                inmodule=0
            if in_module == 1 and re.match('\s*\(\s*\n', line, re.S) != None and re.match('\s*module\s*{0}_system\s*\n'.format(project), prev_line, re.S) != None:
                in_port_list = 1
            if in_port_list == 1 and re.match('\s*\);\s*\n', line, re.S) != None:                
                in_port_list = 0  
                # remove previous line    
                new_lines.pop()
                # modify it 
                prev_line = prev_line.rstrip('\n') + ',\n'
                # and re-append
                new_lines.append(prev_line)    
    
                # add new ports                
                for i in range(num_lsus):
                    new_lines.append("    // AVM avm_svm_port_" + str(i) + "_rw\n")
                    avm_sub_ports = getAvmSubPorts()
                    for direction,port_name,width in avm_sub_ports:
                        if width == 0:
                            l = "    "+ direction + " logic avm_svm_port_" + str(i) + "_rw_" + port_name + ",\n"
                        else:
                            l = "    "+ direction + " logic [" + str(width-1) + ":" + str(0) + "] avm_svm_port_" + str(i) + "_rw_" + port_name + ",\n"
                        new_lines.append(l) 

                for i in range(num_lsus_atomic):
                    new_lines.append("    // AVM avm_lockservice_port_" + str(i) + "_rw\n")
                    avm_sub_ports = getAvmSubPorts()
                    for direction,port_name,width in avm_sub_ports:
                        if width == 0:
                            l = "    "+ direction + " logic avm_lockservice_port_" + str(i) + "_rw_" + port_name + ",\n"
                        else:
                            l = "    "+ direction + " logic [" + str(width-1) + ":" + str(0) + "] avm_lockservice_port_" + str(i) + "_rw_" + port_name + ",\n"
                        new_lines.append(l) 

                l=new_lines.pop()
                l = l.rstrip(',\n') + '\n'
                new_lines.append(l)  
                in_body = 1

            if in_module == 1 and in_body == 1:
                logic_def = re.match('\s*(logic\s+\[?[0-9]*:?[0-9]*\]?\s*avm_kernel_wr_[a-z]+\s*)\[([0-9]+)\];\s*\n', prev_line, re.S|re.I)
                if logic_def != None:
                    # remove previous line    
                    new_lines.pop()
                    # modify it 
                    prev_line = "   " + logic_def.group(1) + "[" + str(int(logic_def.group(2))-num_lsus-num_lsus_atomic) + "];\n"
                        # and re-append
                    new_lines.append(prev_line)  

            if in_module == 1 and in_body == 1 and hit_first_blank_line_of_body == 0 and re.match('\s*\n', line, re.S) != None:
                hit_first_blank_line_of_body = 1
                svm_bus_counter = 0
                lockservice_counter = 0
                for i in range(num_lsus):
                    new_lines.append("\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_enable;\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_read;\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_write;\n")
                    new_lines.append("  wire [4:0] avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_burstcount;\n")
                    new_lines.append("  wire [30:0] avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_address;\n")
                    new_lines.append("  wire [255:0] avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_writedata;\n")
                    new_lines.append("  wire [31:0] avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_byteenable;\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_waitrequest;\n")
                    new_lines.append("  wire [255:0] avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_readdata;\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_readdatavalid;\n")
                    new_lines.append("  wire avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_writeack;\n")
                    new_lines.append("\n")
                    new_lines.append("  bus_adaption\n")
                    new_lines.append("  #(\n")
                    new_lines.append("      .ENABLE_ACP (1),\n")
                    new_lines.append("      .INPUT_DATAWDTH (256),\n")
                    new_lines.append("      .INPUT_ADDRWDTH  (31),\n")
                    new_lines.append("      .INPUT_BYTEENWDTH (32),\n")
                    new_lines.append("      .INPUT_BURSTCOUNT (5),\n")
                    new_lines.append("      .OUTPUT_DATAWDTH (" + str(SVM_DATA_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_ADDRWDTH (" + str(SVM_ADDR_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_BYTEENWDTH (" + str(SVM_BYTEENABLE_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_BURSTCOUNT (" + str(SVM_BURSTCOUNT_WIDTH) + ")\n")
                    new_lines.append("  )\n")
                    new_lines.append("  bus_adaption_kernel_top" + str(i) + "\n")
                    new_lines.append("  (\n")
                    new_lines.append("      .avm_port_in_enable (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_enable),\n")
                    new_lines.append("      .avm_port_in_readdata (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_readdata),\n")
                    new_lines.append("      .avm_port_in_readdatavalid (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_readdatavalid),\n")
                    new_lines.append("      .avm_port_in_waitrequest (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_waitrequest),\n")
                    new_lines.append("      .avm_port_in_address (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_address),\n")
                    new_lines.append("      .avm_port_in_read (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_read),\n")
                    new_lines.append("      .avm_port_in_write (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_write),\n")
                    new_lines.append("      .avm_port_in_writeack (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_writeack),\n")
                    new_lines.append("      .avm_port_in_writedata (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_writedata),\n")
                    new_lines.append("      .avm_port_in_byteenable (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_byteenable),\n")
                    new_lines.append("      .avm_port_in_burstcount (avm_kernel_bus_adaption_" + str(svm_bus_counter) + "_burstcount),\n")
                    new_lines.append("\n")
                    new_lines.append("      .avm_port_out_enable ( avm_svm_port_" + str(i) + "_rw_enable),\n")
                    new_lines.append("      .avm_port_out_readdata (avm_svm_port_" + str(i) + "_rw_readdata),\n")
                    new_lines.append("      .avm_port_out_readdatavalid (avm_svm_port_" + str(i) + "_rw_readdatavalid),\n")
                    new_lines.append("      .avm_port_out_waitrequest (avm_svm_port_" + str(i) + "_rw_waitrequest),\n")
                    new_lines.append("      .avm_port_out_address (avm_svm_port_" + str(i) + "_rw_address),\n")
                    new_lines.append("      .avm_port_out_read (avm_svm_port_" + str(i) + "_rw_read),\n")
                    new_lines.append("      .avm_port_out_write (avm_svm_port_" + str(i) + "_rw_write),\n")
                    new_lines.append("      .avm_port_out_writeack (avm_svm_port_" + str(i) + "_rw_writeack),\n")
                    new_lines.append("      .avm_port_out_writedata (avm_svm_port_" + str(i) + "_rw_writedata),\n")
                    new_lines.append("      .avm_port_out_byteenable (avm_svm_port_" + str(i) + "_rw_byteenable),\n")
                    new_lines.append("      .avm_port_out_burstcount (avm_svm_port_" + str(i) + "_rw_burstcount)\n")
                    new_lines.append("  );\n")
                    new_lines.append("\n")
                    svm_bus_counter = svm_bus_counter + 1

                for i in range(num_lsus_atomic):
                    new_lines.append("\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_enable;\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_read;\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_write;\n")
                    new_lines.append("  wire [4:0] avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_burstcount;\n")
                    new_lines.append("  wire [30:0] avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_address;\n")
                    new_lines.append("  wire [255:0] avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_writedata;\n")
                    new_lines.append("  wire [31:0] avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_byteenable;\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_waitrequest;\n")
                    new_lines.append("  wire [255:0] avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_readdata;\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_readdatavalid;\n")
                    new_lines.append("  wire avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_writeack;\n")
                    new_lines.append("\n")
                    new_lines.append("  bus_adaption\n")
                    new_lines.append("  #(\n")
                    new_lines.append("      .ENABLE_ACP (0),\n")
                    new_lines.append("      .INPUT_DATAWDTH (256),\n")
                    new_lines.append("      .INPUT_ADDRWDTH  (31),\n")
                    new_lines.append("      .INPUT_BYTEENWDTH (32),\n")
                    new_lines.append("      .INPUT_BURSTCOUNT (5),\n")
                    new_lines.append("      .OUTPUT_DATAWDTH (" + str(SVM_DATA_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_ADDRWDTH (" + str(SVM_ADDR_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_BYTEENWDTH (" + str(SVM_BYTEENABLE_WIDTH) + "),\n")
                    new_lines.append("      .OUTPUT_BURSTCOUNT (" + str(SVM_BURSTCOUNT_WIDTH) + ")\n")
                    new_lines.append("  )\n")
                    new_lines.append("  bus_adaption_lockservice_top" + str(i) + "\n")
                    new_lines.append("  (\n")
                    new_lines.append("      .avm_port_in_enable (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_enable),\n")
                    new_lines.append("      .avm_port_in_readdata (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_readdata),\n")
                    new_lines.append("      .avm_port_in_readdatavalid (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_readdatavalid),\n")
                    new_lines.append("      .avm_port_in_waitrequest (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_waitrequest),\n")
                    new_lines.append("      .avm_port_in_address (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_address),\n")
                    new_lines.append("      .avm_port_in_read (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_read),\n")
                    new_lines.append("      .avm_port_in_write (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_write),\n")
                    new_lines.append("      .avm_port_in_writeack (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_writeack),\n")
                    new_lines.append("      .avm_port_in_writedata (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_writedata),\n")
                    new_lines.append("      .avm_port_in_byteenable (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_byteenable),\n")
                    new_lines.append("      .avm_port_in_burstcount (avm_lockservice_bus_adaption_" + str(lockservice_counter) + "_burstcount),\n")
                    new_lines.append("\n")
                    new_lines.append("      .avm_port_out_enable ( avm_lockservice_port_" + str(i) + "_rw_enable),\n")
                    new_lines.append("      .avm_port_out_readdata (avm_lockservice_port_" + str(i) + "_rw_readdata),\n")
                    new_lines.append("      .avm_port_out_readdatavalid (avm_lockservice_port_" + str(i) + "_rw_readdatavalid),\n")
                    new_lines.append("      .avm_port_out_waitrequest (avm_lockservice_port_" + str(i) + "_rw_waitrequest),\n")
                    new_lines.append("      .avm_port_out_address (avm_lockservice_port_" + str(i) + "_rw_address),\n")
                    new_lines.append("      .avm_port_out_read (avm_lockservice_port_" + str(i) + "_rw_read),\n")
                    new_lines.append("      .avm_port_out_write (avm_lockservice_port_" + str(i) + "_rw_write),\n")
                    new_lines.append("      .avm_port_out_writeack (avm_lockservice_port_" + str(i) + "_rw_writeack),\n")
                    new_lines.append("      .avm_port_out_writedata (avm_lockservice_port_" + str(i) + "_rw_writedata),\n")
                    new_lines.append("      .avm_port_out_byteenable (avm_lockservice_port_" + str(i) + "_rw_byteenable),\n")
                    new_lines.append("      .avm_port_out_burstcount (avm_lockservice_port_" + str(i) + "_rw_burstcount)\n")
                    new_lines.append("  );\n")
                    new_lines.append("\n")
                    lockservice_counter = lockservice_counter + 1
 
            if in_module == 1 and re.match('\s*{0}_top_wrapper\s+{0}\s*\n'.format(kernel), line, re.S) != None:
                in_component=1

            if in_component == 1:
                # modify portmaps referring to svm ports
                svm_portmap = re.match('\s*\.avm_efi_{0}_([0-9]+)_host_memory_bridge(_[a-z]+)(_?[a-z]*)_([0-9]+)bit_host_memory_bridge(_?[a-z]*)_a0b1c2d3(_[a-z]+)_[0-9]+bit_([0-9]+)_inst0_([a-z]+).+\n'.format(kernel), prev_line, re.S|re.I)
                if svm_portmap != None:
                    # remove previous line    
                    new_lines.pop()
                    # modify it 
                    if svm_portmap.group(6) == "0": # kernel svm port
                        prev_line = "       .avm_efi_" + kernel + "_" + svm_portmap.group(1) + "_host_memory_bridge" + svm_portmap.group(2) + svm_portmap.group(3) + "_" + svm_portmap.group(4) + "bit_host_memory_bridge" + svm_portmap.group(5) + "_a0b1c2d3"+ svm_portmap.group(2) + "_" + svm_portmap.group(4) + "bit_" + svm_portmap.group(7) + "_inst0_" + svm_portmap.group(8) + "(avm_kernel_bus_adaption_" + str(int(svm_portmap.group(1)) * AVM_PORTS_PER_LSU + int(svm_portmap.group(7))) + "_" + svm_portmap.group(8) + "),\n"
                    else: # lock server port
                        # FIXME: re-include lock service
                        # prev_line = "       .avm_efi_" + kernel + "_" + svm_portmap.group(1) + "_host_memory_bridge" + svm_portmap.group(2) + svm_portmap.group(3) + "_" + svm_portmap.group(4) + "bit_host_memory_bridge" + svm_portmap.group(5) + "_a0b1c2d3" + svm_portmap.group(2)+ "_" + svm_portmap.group(4) + "bit_" + svm_portmap.group(7) + "_inst0_" + svm_portmap.group(8) + "(avm_lockservice_bus_adaption_" + svm_portmap.group(1) + "_" + svm_portmap.group(8) + "),\n"
                        prev_line = "       .avm_efi_" + kernel + "_" + svm_portmap.group(1) + "_host_memory_bridge" + svm_portmap.group(2) +svm_portmap.group(3) + "_" + svm_portmap.group(4) + "bit_host_memory_bridge" + svm_portmap.group(5) + "_a0b1c2d3" + svm_portmap.group(2) + "_" + svm_portmap.group(4) + "bit_" + svm_portmap.group(7) + "_inst0_" + svm_portmap.group(8) + "(avm_kernel_bus_adaption_" + str(int(svm_portmap.group(1)) * AVM_PORTS_PER_LSU + int(svm_portmap.group(7))) + "_" + svm_portmap.group(8) + "),\n"
                    # and re-append
                    new_lines.append(prev_line)  

            if in_component == 1 and re.match('\s*\);\s*\n', line, re.S) != None:
                in_component=0     

            if in_module == 1 and re.match('\s*lsu_ic_top\s*\n', prev_line, re.S) != None and re.match('\s*#\(\s*\n', line, re.S) != None:
                in_lsu_ic_top_genericmap = 1

            if in_lsu_ic_top_genericmap == 1:
                lsu_ic_top_genericmap = re.match('\s*\.NUM_WR_PORT\s*\(([0-9]+)\)(,?)\s*\n', prev_line, re.S|re.I)
                if lsu_ic_top_genericmap:
                    # remove previous line    
                    new_lines.pop()
                    # modify it 
                    prev_line = "       .NUM_WR_PORT(" + str(int(lsu_ic_top_genericmap.group(1))-num_lsus-num_lsus_atomic) + ")" + lsu_ic_top_genericmap.group(2) + "\n" 
                    # and re-append
                    new_lines.append(prev_line)  

            new_lines.append(line)
            prev_line = line
        lines = new_lines
        total_num_lsus = total_num_lsus + num_lsus
        total_num_lsus_atomic = total_num_lsus_atomic + num_lsus_atomic


    
    # reiterate through new lines again
    lines = new_lines

    for kernel in kernels:
        new_lines = []
        in_module = 0
        in_component = 0
        in_lsu_ic_top_genericmap = 0
        prev_line = ""

        # iterate over lines again
        for line in lines: 
            if re.match('\s*module\s*{0}_system\s*\n'.format(project), line, re.S) != None:
                in_module=1
            if in_module == 1 and re.match('\s*endmodule\s*\n', line, re.S) != None:
                inmodule=0

            if in_module == 1 and re.match('\s*{0}_top_wrapper\s+{0}\s*\n'.format(kernel), line, re.S) != None:
                in_component=1

            if in_component == 1:
                # modify portmaps referring to normal ports
                normal_portmap = re.match('\s*(\.avm_local_bb[0-9]+_st_.+)\s*\((avm_kernel_wr_[a-z]+)\[([0-9]+)\]\)(,?)\s*\n', prev_line, re.S|re.I)
                if normal_portmap != None:
                    # sanity check: svm-related indices in port array must start from 0 
                    if int(normal_portmap.group(3))-total_num_lsus-total_num_lsus_atomic < 0:
                        raise NameError('SVM-related indices in port array must start from 0')
                    # remove previous line    
                    new_lines.pop()
                    # modify it 
                    prev_line = "       " + normal_portmap.group(1) + "(" + normal_portmap.group(2) + "[" + str(int(normal_portmap.group(3))-total_num_lsus-total_num_lsus_atomic) + "])" + normal_portmap.group(4) + "\n"
                    # and re-append
                    new_lines.append(prev_line)  

            if in_component == 1 and re.match('\s*\);\s*\n', line, re.S) != None:
                in_component=0       

            new_lines.append(line)
            prev_line = line
        lines = new_lines

        
    with open(os.path.join(project, project + '_system.v'), 'w') as handle:
        for line in new_lines:
            handle.write(line)

    handle.close
    return total_num_lsus, total_num_lsus_atomic


# modify the ..._system_hw.tcl file
def modifyKernelSystemTclFile(project,kernels,num_lsu_instances,num_lsu_atomic_instances):

    with open(os.path.join(project, project + '_system_hw.tcl'), 'r') as handle:
        lines = handle.readlines()

    if debug:
        print "File opened for parsing %r" % handle

    new_lines = []

    prev_line = ""
    in_quartus_file_set = 0
    in_sim_verilog_file_set = 0

    # iterate over lines
    for line in lines: 
        if re.match('\s*add_fileset\s+QUARTUS_SYNTH\s+QUARTUS_SYNTH\s+\"\"\s+\"\"\n', line, re.S) != None:
            in_quartus_file_set = 1
            # add new ports
            for i in range(num_lsu_instances):
                new_lines.append("### AVM avm_svm_port_" + str(i) + "_rw\n")
                new_lines.append("add_interface avm_svm_port_" + str(i) + "_rw avalon start\n") 
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw associatedClock clock_reset\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw burstOnBurstBoundariesOnly false\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw doStreamReads false\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw doStreamWrites false\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw linewrapBursts false\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw readWaitTime 0\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw ASSOCIATED_CLOCK clock_reset\n")
                new_lines.append("set_interface_property avm_svm_port_" + str(i) + "_rw ENABLED true\n")

                avm_sub_ports = getAvmSubPorts()
                for direction,port_name,width in avm_sub_ports:
                    if port_name != "enable" and port_name != "writeack":
                        if width == 0:
                            l = "add_interface_port avm_svm_port_" + str(i) + "_rw avm_svm_port_" + str(i) + "_rw_"+ port_name + " " + port_name + " " + direction.capitalize() + " " + str(1) + "\n"
                        else:
                            l = "add_interface_port avm_svm_port_" + str(i) + "_rw avm_svm_port_" + str(i) + "_rw_"+ port_name + " " + port_name + " " + direction.capitalize() + " " + str(width) + "\n"
                        new_lines.append(l) 

                new_lines.append("\n") 

            for i in range(num_lsu_atomic_instances):
                new_lines.append("### AVM avm_lockservice_port_" + str(i) + "_rw\n")
                new_lines.append("add_interface avm_lockservice_port_" + str(i) + "_rw avalon start\n") 
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw associatedClock clock_reset\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw burstOnBurstBoundariesOnly false\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw doStreamReads false\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw doStreamWrites false\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw linewrapBursts false\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw readWaitTime 0\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw ASSOCIATED_CLOCK clock_reset\n")
                new_lines.append("set_interface_property avm_lockservice_port_" + str(i) + "_rw ENABLED true\n")

                avm_sub_ports = getAvmSubPorts()
                for direction,port_name,width in avm_sub_ports:
                    if port_name != "enable" and port_name != "writeack":
                        if width == 0:
                            l = "add_interface_port avm_lockservice_port_" + str(i) + "_rw avm_lockservice_port_" + str(i) + "_rw_"+ port_name + " " + port_name + " " + direction.capitalize() + " " + str(1) + "\n"
                        else:
                            l = "add_interface_port avm_lockservice_port_" + str(i) + "_rw avm_lockservice_port_" + str(i) + "_rw_"+ port_name + " " + port_name + " " + direction.capitalize() + " " + str(width) + "\n"
                        new_lines.append(l) 

                new_lines.append("\n") 

        """   
        if in_quartus_file_set == 1 and re.match('\n', line, re.S) != None:
            in_quartus_file_set = 0
            new_lines.append("add_fileset_file buswidth_adaption.vhd VHDL PATH buswidth_adaption.vhd TOP_LEVEL_FILE\n"

        if re.match('\s*add_fileset\s+SIM_VERILOG\s+SIM_VERILOG\s+\"\"\s+\"\"\n', line, re.S) != None:
            in_sim_verilog_file_set = 1            
        """

        prev_line = line
        new_lines.append(line)

    """
    if in_sim_verilog_file_set == 1:
        new_lines.append("add_fileset_file buswidth_adaption.vhd VHDL PATH buswidth_adaption.vhd TOP_LEVEL_FILE\n"
    """    

    # write new file
    with open(os.path.join(project, project + '_system_hw.tcl'), 'w') as handle:
        for line in new_lines:
            handle.write(line)

    handle.close



parser = argparse.ArgumentParser()
parser.add_argument('cl_file', help = 'path to kernel code (.cl) file')
args = parser.parse_args()

if os.path.isfile(args.cl_file) and os.path.splitext(args.cl_file)[1] == '.cl':
	proj = os.path.splitext(os.path.basename(args.cl_file))[0]
else:
	sys.exit('Unrecognised file type')

self_dir = os.path.dirname(os.path.realpath(__file__))

# parse all kernel modules in the generated RTL file
kernels = getKernels(proj)
print "Detected kernels:"
for kernel in kernels:
    print kernel

# modify the ..._system.v file
num_lsu_instances, num_lsu_atomic_instances = modifyKernelSystemVerilogFile(proj,kernels)

# modify the ..._system_hw.tcl file
modifyKernelSystemTclFile(proj,kernels,num_lsu_instances,num_lsu_atomic_instances)

# copy AXI security bridge IP into project folder
if not os.path.exists(os.path.join(proj, 'ip')):
    os.makedirs(os.path.join(proj, 'ip'))
if not os.path.exists(os.path.join(proj, 'ip','axi_cache_secruity_bridge')):
    os.makedirs(os.path.join(proj, 'ip','axi_cache_secruity_bridge'))
shutil.copyfile(os.path.join(self_dir, '..', 'rtl_src', 'axi_cache_secruity_bridge', 'AXI_cache_secruity_bridge_hw.tcl'), os.path.join(proj, 'ip','axi_cache_secruity_bridge','AXI_cache_secruity_bridge_hw.tcl'))
shutil.copyfile(os.path.join(self_dir, '..', 'rtl_src', 'axi_cache_secruity_bridge', 'axi_cache_secruity_bridge.v'), os.path.join(proj, 'ip','axi_cache_secruity_bridge','axi_cache_secruity_bridge.v'))

# copy lock server into project folder
if not os.path.exists(os.path.join(proj, 'ip','lock_server')):
    os.makedirs(os.path.join(proj, 'ip','lock_server'))
shutil.copyfile(os.path.join(self_dir, '..', 'rtl_src', 'lock_server', 'lock_server_hw.tcl'), os.path.join(proj, 'ip','lock_server','lock_server_hw.tcl'))
shutil.copyfile(os.path.join(self_dir, '..', 'rtl_src', 'lock_server', 'lock_server.vhd') , os.path.join(proj, 'ip','lock_server','lock_server.vhd'))

# run tcl scripts to modify Qsys system
shutil.copyfile(os.path.join(self_dir, '..', 'scripts', 'iface.tcl') , os.path.join(proj, 'iface.tcl'))
shutil.copyfile(os.path.join(self_dir, '..', 'scripts', 'svm_system.tcl'), os.path.join(proj, 'svm_system.tcl'))
os.chdir(proj)


subprocess.call('qsys-script --script=iface.tcl', shell = True)
subprocess.call('qsys-script --script=svm_system.tcl ' + proj + ' ' + str(num_lsu_instances) + ' ' + str(num_lsu_atomic_instances) , shell = True)

os.remove('iface.tcl')
os.remove('svm_system.tcl')
os.chdir(self_dir)



"""
for module in modules:
    kernel=module.group(1)
    moduleContents = re.match('.*\n\s*module\s*({0})\s*?\((.*?)\)\;(.*?)\nendmodule'.format(kernel), handle.read(), re.S|re.I)
    moduleInfo['name'] = kernel
    ports=moduleContents.group(2)
    body=moduleContents.group(3)
    portMap = re.match('.*\n\s*{0}_top_wrapper\s+{0}\s*?\((.*?)\)\;'.format(proj), body, re.S|re.I)
    print portMap.group(1)

"""
