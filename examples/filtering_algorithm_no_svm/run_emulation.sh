#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: run_emulation.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------
export AOCL_BOARD_PACKAGE_ROOT=$ALTERAOCLSDKROOT/board/s5_ref
export LD_LIBRARY_PATH=$AOCL_BOARD_PACKAGE_ROOT/linux64/lib:$LD_LIBRARY_PATH
PWD=`pwd`
cd sim
CL_CONTEXT_EMULATOR_DEVICE_ALTERA=1 ./host
cd $PWD
