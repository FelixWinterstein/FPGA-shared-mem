#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: generate_hardware.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------
aoc -g -v --profile device/filter_stream_opt1.cl -o bin/filter_stream_opt1.aocx --board c5soc
