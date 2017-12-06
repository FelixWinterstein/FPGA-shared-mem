/**********************************************************************
* Felix Winterstein, Imperial College London, 2016
*
* File: host_memory_bridge.h
*
* Revision 1.01
* Additional Comments: distributed under an Apache-2.0 license, see LICENSE
*
**********************************************************************/

uint2 ddr_memory_bridge_32bit_ld (__global int* p0, uint index)
{
    return 0;
}

uint2 ddr_memory_bridge_32bit_st (__global int* p0, uint index, uint write_data)
{
    return 0;
}


uint4 host_memory_bridge_ld_32bit (__global int *p0,  uint ttbr0, uint va)
{
    return 0;
}

uint4 host_memory_bridge_st_32bit (__global int *p0,  uint ttbr0, uint va, uint write_data)
{
    return 0;
}



ulong16 host_memory_bridge_ld_512bit (__global int *p0,  uint ttbr0, uint va)
{
    return 0;
}



uint host_memory_bridge_aa_32bit (__global int *p0, svm_pointer_t ttbr0, svm_pointer_t lock_location, svm_pointer_t va, uint increment)
{
    return 0;
}
