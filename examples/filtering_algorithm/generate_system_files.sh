#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: generate_system_files.sh
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------
CL_FILE=device/filter_stream_opt1.cl
aoc -s -v -g --profile --board c5soc -l ../../svm_common/rtl_src/custom_library.aoclib $CL_FILE
../../svm_common/scripts/fixup_generated_rtl.py $CL_FILE
../../svm_common/scripts/postprocess_scripts.py $CL_FILE
