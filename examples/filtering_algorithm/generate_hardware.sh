#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: generate_hardware.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------

aoc -v --board c5soc -l ../../svm_common/rtl_src/custom_library.aoclib filter_stream_opt1.aoco -o bin/filter_stream_opt1.aocx
