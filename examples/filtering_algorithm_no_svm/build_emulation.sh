#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: build_emulation.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------
export AOCL_BOARD_PACKAGE_ROOT=$ALTERAOCLSDKROOT/board/s5_ref
echo Setting AOCL_BOARD_PACKAGE_ROOT to $AOCL_BOARD_PACKAGE_ROOT
aoc -march=emulator -g -v --profile device/filter_stream_opt1.cl -o sim/filter_stream_opt1.aocx --board s5_ref

export LD_LIBRARY_PATH=$AOCL_BOARD_PACKAGE_ROOT/linux64/lib:$LD_LIBRARY_PATH
make -f Makefile_x86 clean
make -f Makefile_x86
