#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: init_opencl_env.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------
echo "ALTERAOCLSDKROOT: $ALTERAOCLSDKROOT"
BSP=c5soc
echo "BSP: $BSP"
export AOCL_BOARD_PACKAGE_ROOT=$ALTERAOCLSDKROOT/board/$BSP
echo "AOCL_BOARD_PACKAGE_ROOT: $AOCL_BOARD_PACKAGE_ROOT"
export LD_LIBRARY_PATH=$ALTERAOCLSDKROOT/host/linux64/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$AOCL_BOARD_PACKAGE_ROOT/arm32/lib:$LD_LIBRARY_PATH # for c5soc
export PATH=$ALTERAOCLSDKROOT/bin:$PATH
export QUARTUS_ROOTDIR_OVERRIDE=$ALTERAOCLSDKROOT/../quartus
export PATH=$QUARTUS_ROOTDIR_OVERRIDE/bin:$PATH
